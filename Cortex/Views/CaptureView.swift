import SwiftUI

struct CaptureView: View {
    @Environment(AppState.self) private var appState
    @Environment(AudioRecordingService.self) private var audioService

    @State private var breathe = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                VStack(spacing: 16) {
                    Text("Cortex")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.textPrimary)

                    if let folderName = appState.vaultFolderName {
                        Text("Vault: \(folderName)")
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                    }
                }

                // mic button
                Button {
                    startRecording()
                } label: {
                    ZStack {
                        // breathing glow
                        Circle()
                            .fill(Theme.accent.opacity(0.1))
                            .frame(width: breathe ? 140 : 124, height: breathe ? 140 : 124)
                            .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: breathe)

                        Circle()
                            .fill(Theme.card)
                            .frame(width: 120, height: 120)

                        Circle()
                            .strokeBorder(Theme.accent, lineWidth: 2)
                            .frame(width: 120, height: 120)

                        Image(systemName: "mic.fill")
                            .font(.system(size: 44))
                            .foregroundColor(Theme.accent)
                    }
                }
                .disabled(!audioService.micPermissionGranted)

                Text("Press Action Button or tap to record")
                    .font(.footnote)
                    .foregroundColor(Theme.textSecondary)

                Spacer()
            }
        }
        .onAppear { breathe = true }
    }

    private func startRecording() {
        Theme.Haptic.heavy()
        audioService.startRecording()
        appState.isRecording = true
        appState.showRecordingUI = true
    }
}
