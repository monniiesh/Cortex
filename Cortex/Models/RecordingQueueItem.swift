import Foundation
import SwiftData

@Model
class RecordingQueueItem {
    var id: UUID
    var audioFileName: String
    var recordedAt: Date
    var statusRaw: String
    var transcript: String?
    var errorMessage: String?

    var status: ProcessingStatus {
        get { ProcessingStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    var audioFileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent(audioFileName)
    }

    init(audioFileName: String, recordedAt: Date = Date()) {
        self.id = UUID()
        self.audioFileName = audioFileName
        self.recordedAt = recordedAt
        self.statusRaw = ProcessingStatus.pending.rawValue
        self.transcript = nil
        self.errorMessage = nil
    }
}
