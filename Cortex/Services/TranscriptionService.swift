import Speech
import Observation

@Observable
class TranscriptionService {

    var isAuthorized = false

    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                let granted = status == .authorized
                DispatchQueue.main.async {
                    self.isAuthorized = granted
                }
                continuation.resume(returning: granted)
            }
        }
    }

    func transcribe(audioURL: URL) async throws -> String {
        guard isAuthorized else {
            throw TranscriptionError.authDenied
        }

        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")),
              recognizer.isAvailable else {
            throw TranscriptionError.recognizerUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false

        return try await withCheckedThrowingContinuation { continuation in
            var hasResumed = false

            recognizer.recognitionTask(with: request) { result, error in
                guard !hasResumed else { return }

                if let error {
                    hasResumed = true
                    print("Error: transcription failed: \(error)")
                    continuation.resume(throwing: error)
                    return
                }

                guard let result, result.isFinal else { return }

                hasResumed = true
                let text = result.bestTranscription.formattedString
                if text.isEmpty {
                    continuation.resume(throwing: TranscriptionError.noResult)
                } else {
                    continuation.resume(returning: text)
                }
            }
        }
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
            return "Speech recognizer unavailable for this locale or device"
        case .noResult:
            return "No transcription result returned"
        }
    }
}
