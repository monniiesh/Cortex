import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(AudioRecordingService.self) private var audioService
    @Environment(VaultBookmarkService.self) private var vaultBookmarkService
    @Environment(ProcessingPipeline.self) private var pipeline

    @State private var showVaultPicker = false

    var body: some View {
        ZStack {
            Theme.bg
                .ignoresSafeArea()

            if !appState.hasCompletedOnboarding {
                OnboardingView()
            } else if !appState.isVaultConnected {
                vaultSetupView
            } else {
                MainTabView()
            }

            // recording overlay — full-screen, floats above tabs
            if appState.showRecordingUI {
                RecordingView()
                    .transition(.opacity)
                    .zIndex(10)
            }

            // banner notification overlay
            if appState.showBanner, let message = appState.lastBannerMessage {
                VStack {
                    bannerView(message: message)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onAppear {
                            Theme.Haptic.success()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    appState.showBanner = false
                                }
                            }
                        }
                    Spacer()
                }
                .animation(.spring(response: 0.35), value: appState.showBanner)
            }

            // processing status bar
            if pipeline.isProcessing {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(Theme.accent)
                        Text(pipeline.currentStep)
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .cornerRadius(20)
                    .padding(.bottom, 100) // clear tab bar + safe area
                }
            }
        }
        .sheet(isPresented: $showVaultPicker) {
            VaultPickerView()
        }
        .onChange(of: appState.launchedFromActionButton) { _, triggered in
            if triggered && appState.isVaultConnected && audioService.micPermissionGranted {
                audioService.startRecording()
                appState.isRecording = true
                appState.showRecordingUI = true
                appState.launchedFromActionButton = false
            } else if triggered {
                appState.launchedFromActionButton = false
            }
        }
    }

    private func bannerView(message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(Theme.success)
            Text(message)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(Theme.textPrimary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .environment(\.colorScheme, .dark)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Theme.divider, lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .padding(.top, 60)
    }

    private var vaultSetupView: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "folder.badge.plus")
                .font(.system(size: 64))
                .foregroundColor(Theme.accent)

            VStack(spacing: 12) {
                Text("Connect Your Vault")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.textPrimary)

                Text("Select your Obsidian vault folder to get started.")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
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
                    .background(Theme.accent)
                    .cornerRadius(14)
                    .padding(.horizontal, 40)
            }

            Spacer()
        }
    }

}
