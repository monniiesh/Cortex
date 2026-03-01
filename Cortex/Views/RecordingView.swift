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
            Theme.bg
                .ignoresSafeArea()

            VStack(spacing: 48) {
                Spacer()

                // waveform area with pulsing glow
                ZStack {
                    // glow ring
                    Circle()
                        .fill(Theme.accent.opacity(0.15))
                        .frame(width: pulseAnimation ? 280 : 240, height: pulseAnimation ? 280 : 240)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulseAnimation)

                    Circle()
                        .fill(Theme.accent.opacity(0.08))
                        .frame(width: pulseAnimation ? 320 : 260, height: pulseAnimation ? 320 : 260)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true).delay(0.2), value: pulseAnimation)

                    // outer glow ring
                    Circle()
                        .fill(Theme.accent.opacity(0.04))
                        .frame(width: pulseAnimation ? 360 : 300, height: pulseAnimation ? 360 : 300)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true).delay(0.4), value: pulseAnimation)

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
                    .foregroundColor(Theme.textPrimary)

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
                    .foregroundColor(Theme.textSecondary)

                Spacer()
            }
        }
    }

    private func waveBar(idx: Int) -> some View {
        let amplitude = audioService.currentAmplitude
        // dual-harmonic noise for organic waveform
        let phase = Float(idx) / Float(barCount)
        let noise = abs(sin(phase * .pi * 3 + amplitude * 10))
        let secondary = abs(cos(phase * .pi * 5 + amplitude * 6)) * 0.3
        let combined = min(1, noise + secondary)
        let height = max(4, CGFloat(amplitude * combined) * 70 + 4)

        return RoundedRectangle(cornerRadius: 2.5)
            .fill(
                LinearGradient(
                    colors: [Theme.accent, Theme.accentGlow],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .frame(width: 4, height: height)
            .shadow(color: Theme.glowShadow, radius: CGFloat(amplitude) * 4, y: 0)
            .animation(.easeInOut(duration: 0.06), value: audioService.currentAmplitude)
    }

    private var formattedDuration: String {
        let total = Int(audioService.recordingDuration)
        let mins = total / 60
        let secs = total % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    private func stopAndSave() {
        Theme.Haptic.medium()
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
