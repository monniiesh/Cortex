import Foundation
import Observation
import SwiftData

@MainActor
@Observable
class ProcessingPipeline {

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
                // transcribe
                item.status = .transcribing
                currentStep = "Transcribing..."

                let transcript = try await transcriptionService.transcribe(audioURL: item.audioFileURL)

                item.transcript = transcript
                item.status = .processing
                currentStep = "Classifying..."

                // get vault URL
                guard let vaultURL = vaultBookmark.loadBookmarkURL() else {
                    throw NSError(domain: "ProcessingPipeline", code: 1, userInfo: [NSLocalizedDescriptionKey: "No vault URL available"])
                }

                // scan vault — await actual completion (no 800ms guessing)
                await vaultScanner.scanAsync(vaultURL: vaultURL)

                let fileList = vaultScanner.fileList()
                let systemPrompt = PromptBuilder.buildSystemPrompt(fileList: fileList)
                let userPrompt = PromptBuilder.buildUserPrompt(transcript: transcript)
                // apply chat template for instruction-tuned models
                let combinedPrompt = PromptBuilder.formatChatPrompt(systemPrompt: systemPrompt, userPrompt: userPrompt)

                // load model if needed
                if !llmService.isModelLoaded {
                    currentStep = "Loading model..."
                    if let modelPath = Bundle.main.paths(forResourcesOfType: "gguf", inDirectory: nil).first {
                        try await llmService.loadModel(from: modelPath)
                    } else {
                        throw NSError(domain: "ProcessingPipeline", code: 2, userInfo: [NSLocalizedDescriptionKey: "No .gguf model found in bundle"])
                    }
                }

                currentStep = "Classifying..."
                let response = try await llmService.generate(prompt: combinedPrompt, grammar: LLMService.defaultGrammarJSON)

                currentStep = "Writing to vault..."
                let parsedItems = ResponseParser.parse(jsonString: response)

                let sourceID = item.id

                for parsed in parsedItems {
                    let routed = VaultRouter.route(suggestedFile: parsed.file, availableFiles: fileList)
                    let dt = parseDateString(parsed.datetime)
                    let contentType = ContentType(rawValue: parsed.type) ?? .note

                    let writable = WritableItem(
                        type: contentType,
                        text: parsed.text,
                        targetFile: routed.file,
                        datetime: dt,
                        isNewFile: routed.isNew
                    )

                    try VaultWriter.write(item: writable, vaultURL: vaultURL)

                    // EventKit — create native action if flagged and has datetime
                    var didCreateNativeAction = false
                    if parsed.nativeAction && dt == nil {
                        print("Error: nativeAction=true for '\(parsed.text)' but datetime could not be parsed — skipping EventKit")
                    }
                    if parsed.nativeAction, dt != nil {
                        switch contentType {
                        case .reminder:
                            didCreateNativeAction = await eventKitService.createReminder(title: parsed.text, dueDate: dt)
                        case .event:
                            didCreateNativeAction = await eventKitService.createEvent(title: parsed.text, startDate: dt)
                        default:
                            break
                        }
                    }

                    let vaultItem = VaultItem(
                        type: contentType,
                        text: parsed.text,
                        targetFile: routed.file,
                        wasNewFile: routed.isNew,
                        datetime: dt,
                        nativeActionCreated: didCreateNativeAction,
                        sourceRecordingID: sourceID
                    )
                    context.insert(vaultItem)
                    sortedItemCount += 1
                }

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

        // unload model to free ~2GB RAM
        llmService.unloadModel()

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
