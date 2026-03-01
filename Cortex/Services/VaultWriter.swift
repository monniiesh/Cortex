import Foundation
import CryptoKit

struct RecentEntry {
    let type: ContentType
    let text: String
    let targetFiles: [String]
    let datetime: Date?
}

struct MultiWritableItem {
    let type: ContentType
    let text: String
    let targets: [RoutedTarget]
    let datetime: Date?
    let contentHash: String

    static func computeHash(text: String, type: ContentType) -> String {
        let input = "\(type.rawValue):\(text)"
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.prefix(8).map { String(format: "%02x", $0) }.joined()
    }
}

struct VaultWriter {

    static func writeMulti(item: MultiWritableItem, vaultURL: URL) throws -> [String] {
        let targets = item.targets
        let allPaths = targets.map { $0.file }
        let fileNames = allPaths.map { wikilinkName(from: $0, allPaths: allPaths) }

        var writtenFiles: [String] = []
        var lastError: Error?

        for (idx, target) in targets.enumerated() {
            var crossLinks: [String] = []
            for (jdx, name) in fileNames.enumerated() {
                if jdx != idx { crossLinks.append("[[\(name)]]") }
            }
            let suffix = crossLinks.isEmpty ? "" : " (see also \(crossLinks.joined(separator: " ")))"

            let content = formatContentWithCrossLink(
                type: item.type, text: item.text, datetime: item.datetime, crossLink: suffix
            )
            let fileURL = vaultURL.appendingPathComponent(target.file)

            do {
                try writeToFile(content: content, fileURL: fileURL)
                writtenFiles.append(target.file)
            } catch {
                print("Error: failed to write to \(target.file): \(error)")
                lastError = error
            }
        }

        if writtenFiles.isEmpty, let err = lastError {
            throw err
        }

        return writtenFiles
    }

    static func appendToRecent(entries: [RecentEntry], vaultURL: URL) throws {
        guard !entries.isEmpty else { return }

        let recentURL = vaultURL.appendingPathComponent("recent.md")
        let todayStr = dateSectionFormatter.string(from: Date())
        let heading = "## \(todayStr)"

        var coordError: NSError?
        var writeError: Error?
        let coordinator = NSFileCoordinator(filePresenter: nil)

        coordinator.coordinate(writingItemAt: recentURL, options: .forMerging, error: &coordError) { coordURL in
            do {
                if !FileManager.default.fileExists(atPath: coordURL.path) {
                    try "# Recent\n\n".write(to: coordURL, atomically: true, encoding: .utf8)
                }

                let existing = try String(contentsOf: coordURL, encoding: .utf8)
                let needsHeading = !existing.contains(heading)

                var block = ""
                if needsHeading {
                    block += "\n\(heading)\n\n"
                }

                for entry in entries {
                    let links = entry.targetFiles.map { file in
                        let name = (file as NSString).lastPathComponent.replacingOccurrences(of: ".md", with: "")
                        return "[[\(name)]]"
                    }
                    let linkStr = links.joined(separator: " ")
                    let prefix = formatRecentPrefix(type: entry.type, datetime: entry.datetime)
                    block += "\(prefix)\(entry.text) → \(linkStr)\n"
                }

                let handle = try FileHandle(forWritingTo: coordURL)
                handle.seekToEndOfFile()
                if let data = block.data(using: .utf8) {
                    handle.write(data)
                }
                handle.closeFile()
            } catch {
                print("Error: VaultWriter failed to write to recent.md: \(error)")
                writeError = error
            }
        }

        if let err = coordError { throw err }
        if let err = writeError { throw err }
    }

    // MARK: - Private

    private static func writeToFile(content: String, fileURL: URL) throws {
        var coordError: NSError?
        var writeError: Error?
        let coordinator = NSFileCoordinator(filePresenter: nil)

        coordinator.coordinate(writingItemAt: fileURL, options: .forMerging, error: &coordError) { coordURL in
            do {
                let parent = coordURL.deletingLastPathComponent()
                if !FileManager.default.fileExists(atPath: parent.path) {
                    try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
                }
                if !FileManager.default.fileExists(atPath: coordURL.path) {
                    try "".write(to: coordURL, atomically: true, encoding: .utf8)
                }

                let handle = try FileHandle(forWritingTo: coordURL)
                handle.seekToEndOfFile()
                if let data = content.data(using: .utf8) {
                    handle.write(data)
                }
                handle.closeFile()
            } catch {
                print("Error: VaultWriter failed to write to \(coordURL.path): \(error)")
                writeError = error
            }
        }

        if let err = coordError { throw err }
        if let err = writeError { throw err }
    }

    private static func wikilinkName(from relativePath: String, allPaths: [String]) -> String {
        let filename = (relativePath as NSString).lastPathComponent
        let baseName = filename.replacingOccurrences(of: ".md", with: "")

        let sameNameCount = allPaths.filter {
            ($0 as NSString).lastPathComponent == filename
        }.count

        if sameNameCount > 1 {
            return relativePath.replacingOccurrences(of: ".md", with: "")
        }

        return baseName
    }

    private static func formatContentWithCrossLink(
        type: ContentType,
        text: String,
        datetime: Date?,
        crossLink: String
    ) -> String {
        switch type {
        case .note:
            return "- \(text)\(crossLink)\n"
        case .todo:
            return "- [ ] \(text)\(crossLink)\n"
        case .reminder, .event:
            if let dt = datetime {
                let formatted = dateFormatter.string(from: dt)
                return "- [ ] 📅 \(formatted) \(text)\(crossLink)\n"
            } else {
                return "- [ ] \(text)\(crossLink)\n"
            }
        }
    }

    private static func formatRecentPrefix(type: ContentType, datetime: Date?) -> String {
        switch type {
        case .note:
            return "- "
        case .todo:
            return "- [ ] "
        case .reminder, .event:
            if let dt = datetime {
                let formatted = dateFormatter.string(from: dt)
                return "- [ ] 📅 \(formatted) "
            }
            return "- [ ] "
        }
    }

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm"
        df.locale = Locale(identifier: "en_US_POSIX")
        return df
    }()

    private static let dateSectionFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.locale = Locale(identifier: "en_US_POSIX")
        return df
    }()
}
