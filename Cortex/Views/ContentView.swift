import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(AudioRecordingService.self) private var audioService
    @Environment(VaultBookmarkService.self) private var vaultBookmarkService

    @State private var showVaultPicker = false

    var body: some View {
        ZStack {
            Color(hex: "0A0E1A")
                .ignoresSafeArea()

            if appState.showRecordingUI {
                RecordingView()
            } else if !appState.isVaultConnected {
                vaultSetupView
            } else {
                idleView
            }
        }
        .sheet(isPresented: $showVaultPicker) {
            VaultPickerView()
        }
        .onChange(of: appState.launchedFromActionButton) { _, triggered in
            if triggered && appState.isVaultConnected {
                startRecording()
                appState.launchedFromActionButton = false
            }
        }
    }

    private var vaultSetupView: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "folder.badge.plus")
                .font(.system(size: 64))
                .foregroundColor(Color(hex: "3B82F6"))

            VStack(spacing: 12) {
                Text("Connect Your Vault")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(hex: "F1F5F9"))

                Text("Select your Obsidian vault folder to get started.")
                    .font(.subheadline)
                    .foregroundColor(Color(hex: "94A3B8"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button {
                showVaultPicker = true
            } label: {
                Text("Choose Vault Folder")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(hex: "3B82F6"))
                    .cornerRadius(14)
                    .padding(.horizontal, 40)
            }

            Spacer()
        }
    }

    private var idleView: some View {
        VStack(spacing: 40) {
            Spacer()

            VStack(spacing: 16) {
                Text("Cortex")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(Color(hex: "F1F5F9"))

                if let folderName = appState.vaultFolderName {
                    Text("Vault: \(folderName)")
                        .font(.subheadline)
                        .foregroundColor(Color(hex: "94A3B8"))
                }
            }

            Button {
                startRecording()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color(hex: "111827"))
                        .frame(width: 120, height: 120)

                    Circle()
                        .strokeBorder(Color(hex: "3B82F6"), lineWidth: 2)
                        .frame(width: 120, height: 120)

                    Image(systemName: "mic.fill")
                        .font(.system(size: 44))
                        .foregroundColor(Color(hex: "3B82F6"))
                }
            }

            Text("Press Action Button or tap to record")
                .font(.footnote)
                .foregroundColor(Color(hex: "94A3B8"))

            Spacer()

            if appState.pendingCount > 0 {
                Text("\(appState.pendingCount) item\(appState.pendingCount == 1 ? "" : "s") pending")
                    .font(.caption)
                    .foregroundColor(Color(hex: "94A3B8"))
                    .padding(.bottom, 24)
            }
        }
    }

    private func startRecording() {
        audioService.setupAudioSession()
        audioService.startRecording()
        appState.isRecording = true
        appState.showRecordingUI = true
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
