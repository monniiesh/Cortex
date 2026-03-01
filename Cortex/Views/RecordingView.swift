import SwiftUI
import SwiftData

struct RecordingView: View {
    @Environment(AppState.self) private var appState
    @Environment(AudioRecordingService.self) private var audioService
    @Environment(\.modelContext) private var modelContext

    @State private var pulseAnimation = false

    private let barCount = 30

    var body: some View {
        ZStack {
            Color(hex: "0A0E1A")
                .ignoresSafeArea()

            VStack(spacing: 48) {
                Spacer()

                // waveform area with pulsing glow
                ZStack {
                    // glow ring
                    Circle()
                        .fill(Color(hex: "3B82F6").opacity(0.15))
                        .frame(width: pulseAnimation ? 280 : 240, height: pulseAnimation ? 280 : 240)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulseAnimation)

                    Circle()
                        .fill(Color(hex: "3B82F6").opacity(0.08))
                        .frame(width: pulseAnimation ? 320 : 260, height: pulseAnimation ? 320 : 260)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true).delay(0.2), value: pulseAnimation)

                    // waveform bars inside circle
                    HStack(alignment: .center, spacing: 3) {
                        ForEach(0 ..< barCount, id: \.self) { idx in
                            waveBar(idx: idx)
                        }
                    }
                    .frame(width: 200, height: 80)
                    .clipShape(Rectangle())
                }
                .frame(width: 320, height: 320)
                .onAppear {
                    pulseAnimation = true
                }

                // duration
                Text(formattedDuration)
                    .font(.system(size: 48, weight: .thin, design: .monospaced))
                    .foregroundColor(Color(hex: "F1F5F9"))

                // stop button
                Button {
                    stopAndSave()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.15))
                            .frame(width: 80, height: 80)

                        Circle()
                            .strokeBorder(Color.red, lineWidth: 2)
                            .frame(width: 80, height: 80)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.red)
                            .frame(width: 28, height: 28)
                    }
                }

                Text("Tap to stop recording")
                    .font(.footnote)
                    .foregroundColor(Color(hex: "94A3B8"))

                Spacer()
            }
        }
    }

    private func waveBar(idx: Int) -> some View {
        let amplitude = audioService.currentAmplitude
        // give each bar a slightly different height based on amplitude + position
        let phase = Float(idx) / Float(barCount)
        let noise = abs(sin(phase * 12.0 + amplitude * 8.0))
        let height = max(4, CGFloat(amplitude * noise) * 60 + 4)

        return RoundedRectangle(cornerRadius: 2)
            .fill(Color(hex: "3B82F6"))
            .frame(width: 4, height: height)
            .animation(.easeInOut(duration: 0.08), value: audioService.currentAmplitude)
    }

    private var formattedDuration: String {
        let total = Int(audioService.recordingDuration)
        let mins = total / 60
        let secs = total % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    private func stopAndSave() {
        if let url = audioService.stopRecording() {
            let filename = url.lastPathComponent
            let item = RecordingQueueItem(audioFileName: filename)
            modelContext.insert(item)
            try? modelContext.save()
        }
        appState.isRecording = false
        appState.showRecordingUI = false
    }
}
