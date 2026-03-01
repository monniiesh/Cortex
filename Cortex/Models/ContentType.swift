import Foundation

enum ContentType: String, Codable, CaseIterable {
    case note
    case todo
    case reminder
    case event
}

enum ProcessingStatus: String, Codable {
    case pending
    case transcribing
    case processing
    case done
    case failed
}
