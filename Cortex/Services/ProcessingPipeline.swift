import Foundation
import Observation
import SwiftData

@MainActor
@Observable
class ProcessingPipeline: @unchecked Sendable {

    var isProcessing = false
    var currentStep = ""

    func processAllPending(
        context: ModelContext,
        vaultBookmark: VaultBookmarkService,
        vaultScanner: VaultScannerService,
        transcriptionService: TranscriptionService,
        llmService: LLMService,
        appState: AppState,
        eventKitService: EventKitService
    ) async {
        let descriptor = FetchDescriptor<RecordingQueueItem>(
            predicate: #Predicate { $0.statusRaw == "pending" }
        )

        let items: [RecordingQueueItem]
        do {
            items = try context.fetch(descriptor)
        } catch {
            print("Error: failed to fetch pending items: \(error)")
            return
        }

        guard !items.isEmpty else { return }

        isProcessing = true
        appState.pendingCount = items.count

        var sortedItemCount = 0

        for item in items {
            do {
                // [1] TRANSCRIBE
                item.status = .transcribing
                currentStep = "Transcribing..."

                let transcript = try await transcriptionService.transcribe(audioURL: item.audioFileURL)
                // free Whisper memory before loading Phi-3
                transcriptionService.unloadModel()

                item.transcript = transcript
                item.status = .processing
                currentStep = "Scanning vault..."

                // [2] PRE-LLM: scan vault, build index, pre-filter, folder tree
                guard let vaultURL = vaultBookmark.loadBookmarkURL() else {
                    throw NSError(domain: "ProcessingPipeline", code: 1, userInfo: [NSLocalizedDescriptionKey: "No vault URL available"])
                }

                await vaultScanner.scanAsync(vaultURL: vaultURL)

                let fileList = vaultScanner.fileList()
                let fileIndex = vaultScanner.fileIndex
                let candidates = VaultPreFilter.filter(transcript: transcript, index: fileIndex)
                let folderTree = FolderTreeBuilder.buildTree(folders: vaultScanner.folders)

                // V2 prompt — candidates may be empty for new vaults (LLM uses new_path)
                let systemPrompt = PromptBuilder.buildSystemPrompt(candidates: candidates, folderTree: folderTree)

                // load model if needed
                if !llmService.isModelLoaded {
                    currentStep = "Loading model..."
                    if let modelPath = Bundle.main.paths(forResourcesOfType: "gguf", inDirectory: nil).first {
                        try await llmService.loadModel(from: modelPath)
                    } else {
                        throw NSError(domain: "ProcessingPipeline", code: 2, userInfo: [NSLocalizedDescriptionKey: "No .gguf model found in bundle"])
                    }
                }

                // [3] CLASSIFY — multi-pass extraction
                // Phi-3 mini often stops after 1 item. We retry with "already captured"
                // hints until coverage is sufficient or no new items are found.
                currentStep = "Classifying..."
                var allParsedItems: [ResponseParser.ParsedItem] = []
                var capturedTexts: [String] = []
                let maxPasses = 2

                let transcriptKW = Set(VaultPreFilter.extractKeywords(from: transcript))
                var consecutiveDups = 0

                for pass in 0 ..< maxPasses {
                    // compute uncovered keywords for retry hint
                    let capturedKW = Set(capturedTexts.flatMap {
                        VaultPreFilter.extractKeywords(from: $0)
                    })
                    let uncovered = Array(transcriptKW.subtracting(capturedKW))

                    let userPrompt: String
                    if pass == 0 {
                        userPrompt = PromptBuilder.buildUserPrompt(transcript: transcript)
                    } else {
                        userPrompt = PromptBuilder.buildRetryUserPrompt(
                            transcript: transcript,
                            alreadyCaptured: capturedTexts,
                            uncoveredKeywords: uncovered
                        )
                    }
                    let prompt = PromptBuilder.formatChatPrompt(
                        systemPrompt: systemPrompt, userPrompt: userPrompt
                    )

                    let response = try await llmService.generate(
                        prompt: prompt, grammar: LLMService.defaultGrammarJSON
                    )
                    let newItems = ResponseParser.parse(jsonString: response)

                    // collect only genuinely new items (dedup by keyword overlap)
                    var addedNew = false
                    for item in newItems {
                        let isDup = capturedTexts.contains { existing in
                            Self.textOverlap(existing, item.text) > 0.5
                        }
                        if !isDup {
                            allParsedItems.append(item)
                            capturedTexts.append(item.text)
                            addedNew = true
                        }
                    }

                    // update coverage
                    let nowCapturedKW = Set(capturedTexts.flatMap {
                        VaultPreFilter.extractKeywords(from: $0)
                    })
                    let covered = transcriptKW.intersection(nowCapturedKW).count
                    let coverage = transcriptKW.isEmpty ? 1.0
                        : Double(covered) / Double(transcriptKW.count)

                    print("DEBUG : pass \(pass + 1) — \(newItems.count) items, \(allParsedItems.count) total, coverage \(String(format: "%.0f", coverage * 100))%, uncovered: \(uncovered.prefix(5))")

                    // stop if coverage is good (lowered from 0.5 — shorter text format covers fewer keywords)
                    if coverage >= 0.3 { break }

                    // stop after 2 consecutive passes with no new items
                    consecutiveDups = addedNew ? 0 : consecutiveDups + 1
                    if consecutiveDups >= 2 { break }
                }

                // [4] POST-LLM: resolve IDs, dedup, route, write
                currentStep = "Writing to vault..."
                let parsedItems = allParsedItems

                let sourceID = item.id
                var recentEntries: [RecentEntry] = []

                for parsed in parsedItems {
                    let contentType = ContentType(rawValue: parsed.type) ?? .note
                    let hash = MultiWritableItem.computeHash(text: parsed.text, type: contentType)

                    // dedup check
                    if isDuplicate(contentHash: hash, sourceRecordingID: sourceID, context: context) {
                        print("Skipping duplicate item: \(parsed.text)")
                        continue
                    }

                    let dt = parseDateString(parsed.datetime)

                    // resolve file IDs to paths (0-indexed: f0 = candidates[0])
                    var resolvedFiles: [String] = []
                    for fileId in parsed.files {
                        if fileId.hasPrefix("f"), let idx = Int(String(fileId.dropFirst())) {
                            if idx >= 0 && idx < candidates.count {
                                resolvedFiles.append(candidates[idx].relativePath)
                            } else {
                                print("Error: invalid file ID '\(fileId)' (out of range) — skipping")
                            }
                        } else {
                            // direct path from fallback parser (e.g. "tasks/unprocessed.md")
                            resolvedFiles.append(fileId)
                        }
                    }

                    // add new_path if provided and non-empty
                    if let newPath = parsed.newPath,
                       !newPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        resolvedFiles.append(newPath)
                    }

                    // safety: if nothing resolved, fall back to unprocessed
                    if resolvedFiles.isEmpty {
                        resolvedFiles = ["tasks/unprocessed.md"]
                    }

                    // route through VaultRouter for validation + dedup
                    let targets = VaultRouter.routeMultiple(suggestedFiles: resolvedFiles, availableFiles: fileList)

                    let writable = MultiWritableItem(
                        type: contentType,
                        text: parsed.text,
                        targets: targets,
                        datetime: dt,
                        contentHash: hash
                    )

                    let writtenFiles = try VaultWriter.writeMulti(item: writable, vaultURL: vaultURL)

                    // EventKit — non-blocking, only for reminder/event with datetime
                    var didCreateNativeAction = false
                    if parsed.nativeAction && dt == nil {
                        print("Error: nativeAction=true for '\(parsed.text)' but datetime unparseable — skipping EventKit")
                    }
                    if parsed.nativeAction, let eventDate = dt {
                        switch contentType {
                        case .reminder:
                            didCreateNativeAction = await eventKitService.createReminder(title: parsed.text, dueDate: eventDate)
                        case .event:
                            didCreateNativeAction = await eventKitService.createEvent(title: parsed.text, startDate: eventDate)
                        default:
                            break
                        }
                    }

                    let anyNew = targets.contains { $0.isNew }

                    let vaultItem = VaultItem(
                        type: contentType,
                        text: parsed.text,
                        targetFiles: writtenFiles,
                        wasNewFile: anyNew,
                        datetime: dt,
                        nativeActionCreated: didCreateNativeAction,
                        sourceRecordingID: sourceID,
                        contentHash: hash
                    )
                    context.insert(vaultItem)

                    recentEntries.append(RecentEntry(
                        type: contentType,
                        text: parsed.text,
                        targetFiles: writtenFiles,
                        datetime: dt
                    ))

                    sortedItemCount += 1
                }

                // [4] RECENT.MD — batch write for this recording (non-fatal)
                if !recentEntries.isEmpty {
                    do {
                        try VaultWriter.appendToRecent(entries: recentEntries, vaultURL: vaultURL)
                    } catch {
                        print("Error: recent.md write failed (non-fatal): \(error)")
                    }
                }

                // [5] FINALIZE
                item.status = .done

                do {
                    try context.save()
                } catch {
                    print("Error: failed to save context after processing item: \(error)")
                }

            } catch {
                print("Error: failed to process recording \(item.id): \(error)")
                item.status = .failed
                item.errorMessage = error.localizedDescription
                do {
                    try context.save()
                } catch {
                    print("Error: failed to save failed status: \(error)")
                }
            }
        }

        // re-scan vault so HomeView picks up new/modified files
        if let vaultURL = vaultBookmark.loadBookmarkURL() {
            await vaultScanner.scanAsync(vaultURL: vaultURL)
        }

        // only show banner if items were actually sorted
        let count = sortedItemCount
        if count > 0 {
            appState.lastBannerMessage = "\(count) item\(count == 1 ? "" : "s") sorted from your recording"
            appState.showBanner = true
        }
        appState.pendingCount = 0
        isProcessing = false
        currentStep = ""
    }

    // MARK: - Private

    // Jaccard similarity on keywords — used to dedup across LLM passes
    private static func textOverlap(_ a: String, _ b: String) -> Double {
        let kwA = Set(VaultPreFilter.extractKeywords(from: a))
        let kwB = Set(VaultPreFilter.extractKeywords(from: b))
        guard !kwA.isEmpty || !kwB.isEmpty else { return 0 }
        let intersection = kwA.intersection(kwB).count
        let union = kwA.union(kwB).count
        return Double(intersection) / Double(max(union, 1))
    }

    private func isDuplicate(contentHash: String, sourceRecordingID: UUID, context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<VaultItem>(
            predicate: #Predicate {
                $0.contentHash == contentHash && $0.sourceRecordingID == sourceRecordingID
            }
        )
        let count = (try? context.fetchCount(descriptor)) ?? 0
        return count > 0
    }

    private func parseDateString(_ str: String?) -> Date? {
        guard let str else { return nil }
        // try ISO 8601 with timezone first
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: str) { return d }
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: str) { return d }
        // spec format has no timezone: "2026-03-01T09:00:00"
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let d = df.date(from: str) { return d }
        // date-only fallback (returns midnight)
        df.dateFormat = "yyyy-MM-dd"
        return df.date(from: str)
    }
}
