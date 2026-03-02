import AVFoundation
import Observation

@Observable
class AudioRecordingService: @unchecked Sendable {

    var isRecording = false
    var currentAmplitude: Float = 0
    var recordingDuration: TimeInterval = 0
    var audioRecorder: AVAudioRecorder?
    var micPermissionGranted = false

    private var meteringTimer: Timer?
    private var currentFileURL: URL?

    func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            print("Error: failed to configure audio session: \(error)")
        }
        requestMicrophonePermission { [weak self] granted in
            DispatchQueue.main.async {
                self?.micPermissionGranted = granted
            }
            if !granted {
                print("Error: microphone permission denied")
            }
        }
    }

    func startRecording() {
        guard micPermissionGranted else {
            print("Error: microphone permission not yet granted")
            return
        }

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let filename = "recording_\(formatter.string(from: Date())).m4a"
        let fileURL = docs.appendingPathComponent(filename)
        currentFileURL = fileURL

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            let recorder = try AVAudioRecorder(url: fileURL, settings: settings)
            recorder.isMeteringEnabled = true
            recorder.record()
            audioRecorder = recorder
            isRecording = true
            recordingDuration = 0
            startMeteringTimer()
        } catch {
            print("Error: failed to start recording: \(error)")
        }
    }

    func stopRecording() -> URL? {
        audioRecorder?.stop()
        stopMeteringTimer()
        isRecording = false
        currentAmplitude = 0
        let url = currentFileURL
        currentFileURL = nil
        audioRecorder = nil
        return url
    }

    private func startMeteringTimer() {
        meteringTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, let recorder = self.audioRecorder else { return }
            recorder.updateMeters()
            let db = recorder.averagePower(forChannel: 0)
            // normalize -160...0 dB to 0...1
            let normalized = max(0, min(1, (db + 160) / 160))
            self.currentAmplitude = normalized
            self.recordingDuration = recorder.currentTime
        }
    }

    private func stopMeteringTimer() {
        meteringTimer?.invalidate()
        meteringTimer = nil
    }

    func requestMicrophonePermission(completion: @escaping @Sendable (Bool) -> Void) {
        AVAudioApplication.requestRecordPermission { granted in
            completion(granted)
        }
    }
}
