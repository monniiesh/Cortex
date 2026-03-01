import Foundation
import SwiftData

@Model
class VaultItem {
    var id: UUID
    var typeRaw: String
    var text: String
    var targetFile: String
    var wasNewFile: Bool
    var datetime: Date?
    var nativeActionCreated: Bool
    var sourceRecordingID: UUID
    var createdAt: Date
    var isCompleted: Bool

    var type: ContentType {
        get { ContentType(rawValue: typeRaw) ?? .note }
        set { typeRaw = newValue.rawValue }
    }

    init(
        type: ContentType,
        text: String,
        targetFile: String,
        wasNewFile: Bool = false,
        datetime: Date? = nil,
        nativeActionCreated: Bool = false,
        sourceRecordingID: UUID,
        createdAt: Date = Date.now,
        isCompleted: Bool = false
    ) {
        self.id = UUID()
        self.typeRaw = type.rawValue
        self.text = text
        self.targetFile = targetFile
        self.wasNewFile = wasNewFile
        self.datetime = datetime
        self.nativeActionCreated = nativeActionCreated
        self.sourceRecordingID = sourceRecordingID
        self.createdAt = createdAt
        self.isCompleted = isCompleted
    }
}
