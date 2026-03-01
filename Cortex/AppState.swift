import Foundation
import Observation

@Observable
class AppState {
    // recording
    var isRecording = false
    var showRecordingUI = false
    var currentAmplitude: Float = 0

    // vault
    var isVaultConnected = false
    var vaultFolderName: String?

    // processing
    var pendingCount = 0
    var lastBannerMessage: String?
    var showBanner = false

    // onboarding
    var hasCompletedOnboarding = false

    // Action Button triggered launch
    var launchedFromActionButton = false
}
