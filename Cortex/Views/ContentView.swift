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
            Color(hex: "0A0E1A")
                .ignoresSafeArea()

            if !appState.isVaultConnected {
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
                            .tint(Color(hex: "3B82F6"))
                        Text(pipeline.currentStep)
                            .font(.caption)
                            .foregroundColor(Color(hex: "94A3B8"))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(hex: "111827").opacity(0.95))
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
                .foregroundColor(Color(hex: "0EA5E9"))
            Text(message)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(Color(hex: "F1F5F9"))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(hex: "1A2235"))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(hex: "1E293B"), lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .padding(.top, 60)
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

}
