import Foundation
import Observation

@Observable
class AppState: @unchecked Sendable {
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

    // onboarding (persisted via UserDefaults)
    var hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }

    // tab bar
    var selectedTab = 0

    // Action Button triggered launch
    var launchedFromActionButton = false
}
