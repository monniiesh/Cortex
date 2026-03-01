import SwiftUI
import SwiftData

@main
struct CortexApp: App {
    @State private var appState = AppState()
    @State private var audioService = AudioRecordingService()
    @State private var vaultBookmarkService = VaultBookmarkService()
    @State private var vaultScanner = VaultScannerService()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(audioService)
                .environment(vaultBookmarkService)
                .environment(vaultScanner)
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    handleScenePhaseChange(from: oldPhase, to: newPhase)
                }
        }
        .modelContainer(for: [RecordingQueueItem.self, VaultItem.self])
    }

    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            if oldPhase == .background || oldPhase == .inactive {
                appState.launchedFromActionButton = true
            }
            // check vault connection
            appState.isVaultConnected = vaultBookmarkService.hasVaultFolder
        case .background:
            if appState.isRecording {
                _ = audioService.stopRecording()
                appState.isRecording = false
                appState.showRecordingUI = false
            }
        default:
            break
        }
    }
}
