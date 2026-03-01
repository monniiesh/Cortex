import Foundation

struct WritableItem {
    let type: ContentType
    let text: String
    let targetFile: String
    let datetime: Date?
    let isNewFile: Bool
}

struct VaultWriter {

    static func write(item: WritableItem, vaultURL: URL) throws {
        let fileURL = vaultURL.appendingPathComponent(item.targetFile)
        let content = formatContent(type: item.type, text: item.text, datetime: item.datetime)

        var coordError: NSError?
        var writeError: Error?
        let coordinator = NSFileCoordinator(filePresenter: nil)

        coordinator.coordinate(writingItemAt: fileURL, options: .forMerging, error: &coordError) { coordURL in
            do {
                // create parent directories + file inside coordinator for safety
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

        if let err = coordError {
            throw err
        }
        if let err = writeError {
            throw err
        }
    }

    private static func formatContent(type: ContentType, text: String, datetime: Date?) -> String {
        switch type {
        case .note:
            return "- \(text)\n"
        case .todo:
            return "- [ ] \(text)\n"
        case .reminder, .event:
            if let dt = datetime {
                let formatted = dateFormatter.string(from: dt)
                return "- [ ] 📅 \(formatted) \(text)\n"
            } else {
                return "- [ ] \(text)\n"
            }
        }
    }

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm"
        df.locale = Locale(identifier: "en_US_POSIX")
        return df
    }()
}
