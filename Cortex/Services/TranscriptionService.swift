import Foundation
import WhisperKit
import Observation

@Observable
class TranscriptionService: @unchecked Sendable {

    var isAuthorized = true
    var isModelReady = false

    private var whisperKit: WhisperKit?

    func requestAuthorization() async -> Bool {
        // WhisperKit only needs microphone — handled by AudioRecordingService
        isAuthorized = true
        return true
    }

    func transcribe(audioURL: URL) async throws -> String {
        // lazy-init on first call (downloads model from HuggingFace if not cached)
        if whisperKit == nil {
            whisperKit = try await WhisperKit(model: "openai_whisper-large-v3-v20240930_626MB")
            isModelReady = true
        }

        guard let kit = whisperKit else {
            throw TranscriptionError.recognizerUnavailable
        }

        let results = try await kit.transcribe(audioPath: audioURL.path)
        let text = results.map { $0.text }.joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else {
            throw TranscriptionError.noResult
        }

        return text
    }

    func unloadModel() {
        whisperKit = nil
        isModelReady = false
    }
}

enum TranscriptionError: Error, LocalizedError {
    case authDenied
    case recognizerUnavailable
    case noResult

    var errorDescription: String? {
        switch self {
        case .authDenied:
            return "Speech recognition authorization denied"
        case .recognizerUnavailable:
            return "Speech model unavailable"
        case .noResult:
            return "No transcription result returned"
        }
    }
}
