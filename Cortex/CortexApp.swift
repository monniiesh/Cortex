import SwiftUI
import SwiftData

@main
struct CortexApp: App {
    @State private var appState = AppState()
    @State private var audioService = AudioRecordingService()
    @State private var vaultBookmarkService = VaultBookmarkService()
    @State private var vaultScanner = VaultScannerService()
    @State private var backgroundTaskService = BackgroundTaskService()
    @Environment(\.scenePhase) private var scenePhase

    let modelContainer: ModelContainer

    init() {
        let container = try! ModelContainer(for: RecordingQueueItem.self, VaultItem.self)
        self.modelContainer = container

        // register background tasks at launch (iOS requires this before app finishes launching)
        let bgService = BackgroundTaskService()
        bgService.registerTasks()
        _backgroundTaskService = State(initialValue: bgService)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(audioService)
                .environment(vaultBookmarkService)
                .environment(vaultScanner)
                .onOpenURL { url in
                    // Action Button configured to open cortex://record
                    if url.scheme == "cortex" && url.host == "record" {
                        appState.launchedFromActionButton = true
                    }
                }
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    handleScenePhaseChange(from: oldPhase, to: newPhase)
                }
        }
        .modelContainer(modelContainer)
    }

    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            // restore vault connection on launch
            if let url = vaultBookmarkService.loadBookmarkURL() {
                appState.isVaultConnected = true
                appState.vaultFolderName = url.lastPathComponent
            } else {
                appState.isVaultConnected = vaultBookmarkService.hasVaultFolder
            }
            // setup audio session once (permission is requested here, not on every record)
            audioService.setupAudioSession()
        case .background:
            if appState.isRecording {
                if let url = audioService.stopRecording() {
                    // save queue item so the recording isn't lost
                    let item = RecordingQueueItem(audioFileName: url.lastPathComponent)
                    modelContainer.mainContext.insert(item)
                    try? modelContainer.mainContext.save()
                }
                appState.isRecording = false
                appState.showRecordingUI = false
                // schedule background processing for the new recording
                backgroundTaskService.scheduleProcessing()
            }
        default:
            break
        }
    }
}
