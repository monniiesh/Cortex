import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @Environment(AudioRecordingService.self) private var audioService

    @State private var currentPage = 0
    @State private var showVaultPicker = false

    private let totalPages = 3

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    vaultPage.tag(1)
                    micPage.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // page indicator + action button
                VStack(spacing: 24) {
                    HStack(spacing: 8) {
                        ForEach(0 ..< totalPages, id: \.self) { idx in
                            Circle()
                                .fill(idx == currentPage ? Theme.accent : Theme.divider)
                                .frame(width: 8, height: 8)
                                .animation(Theme.spring, value: currentPage)
                        }
                    }

                    Button {
                        handleAction()
                    } label: {
                        Text(buttonTitle)
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.accent)
                            .cornerRadius(14)
                    }
                    .padding(.horizontal, 40)
                }
                .padding(.bottom, 60)
            }
        }
        .sheet(isPresented: $showVaultPicker) {
            VaultPickerView()
        }
    }

    private var buttonTitle: String {
        switch currentPage {
        case 0: return "Get Started"
        case 1: return appState.isVaultConnected ? "Continue" : "Connect Vault"
        case 2: return "Start Using Cortex"
        default: return "Continue"
        }
    }

    private func handleAction() {
        switch currentPage {
        case 0:
            withAnimation(Theme.spring) { currentPage = 1 }
        case 1:
            if appState.isVaultConnected {
                withAnimation(Theme.spring) { currentPage = 2 }
            } else {
                showVaultPicker = true
            }
        case 2:
            audioService.requestMicrophonePermission { _ in
                DispatchQueue.main.async {
                    appState.hasCompletedOnboarding = true
                }
            }
        default:
            break
        }
    }

    // page 1: welcome
    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(Theme.accent)
            Text("Welcome to Cortex")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(Theme.textPrimary)
            Text("Record your thoughts. Cortex transcribes, classifies, and routes them to your Obsidian vault automatically.")
                .font(.body)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
            Spacer()
        }
    }

    // page 2: vault connection
    private var vaultPage: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: appState.isVaultConnected ? "checkmark.circle.fill" : "folder.badge.plus")
                .font(.system(size: 80))
                .foregroundColor(appState.isVaultConnected ? Theme.success : Theme.accent)
            Text("Connect Your Vault")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(Theme.textPrimary)
            Text(appState.isVaultConnected
                 ? "Connected to \(appState.vaultFolderName ?? "vault")"
                 : "Select your Obsidian vault folder. Cortex reads your file structure and routes notes intelligently.")
                .font(.body)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
            Spacer()
        }
    }

    // page 3: mic permission
    private var micPage: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "mic.fill")
                .font(.system(size: 80))
                .foregroundColor(Theme.accent)
            Text("Microphone Access")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(Theme.textPrimary)
            Text("Cortex needs microphone access to record your voice notes. All processing happens on-device — nothing leaves your phone.")
                .font(.body)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
            Spacer()
        }
    }
}
