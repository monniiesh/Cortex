import Foundation
import SwiftData

@Model
class VaultItem {
    var id: UUID
    var typeRaw: String
    var text: String
    var targetFilesRaw: String
    var wasNewFile: Bool
    var datetime: Date?
    var nativeActionCreated: Bool
    var sourceRecordingID: UUID
    var createdAt: Date
    var isCompleted: Bool
    var contentHash: String

    var type: ContentType {
        get { ContentType(rawValue: typeRaw) ?? .note }
        set { typeRaw = newValue.rawValue }
    }

    var targetFiles: [String] {
        get {
            guard let data = targetFilesRaw.data(using: .utf8),
                  let arr = try? JSONDecoder().decode([String].self, from: data)
            else { return [] }
            return arr
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let str = String(data: data, encoding: .utf8) {
                targetFilesRaw = str
            }
        }
    }

    // backward compat — first file in the list
    var targetFile: String {
        targetFiles.first ?? ""
    }

    init(
        type: ContentType,
        text: String,
        targetFiles: [String],
        wasNewFile: Bool = false,
        datetime: Date? = nil,
        nativeActionCreated: Bool = false,
        sourceRecordingID: UUID,
        contentHash: String,
        createdAt: Date = Date.now,
        isCompleted: Bool = false
    ) {
        self.id = UUID()
        self.typeRaw = type.rawValue
        self.text = text
        self.wasNewFile = wasNewFile
        self.datetime = datetime
        self.nativeActionCreated = nativeActionCreated
        self.sourceRecordingID = sourceRecordingID
        self.contentHash = contentHash
        self.createdAt = createdAt
        self.isCompleted = isCompleted
        if let data = try? JSONEncoder().encode(targetFiles),
           let str = String(data: data, encoding: .utf8) {
            self.targetFilesRaw = str
        } else {
            self.targetFilesRaw = "[]"
        }
    }
}
