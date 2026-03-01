import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(VaultBookmarkService.self) private var vaultBookmark
    @Environment(LLMService.self) private var llmService

    @AppStorage("defaultReminderHour") private var reminderHour = 9
    @AppStorage("defaultReminderMinute") private var reminderMinute = 0

    @State private var showVaultPicker = false
    @State private var showReconnectConfirm = false

    var vaultFolderName: String {
        vaultBookmark.vaultURL?.lastPathComponent ?? "Not connected"
    }

    var reminderTimeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(from: DateComponents(hour: reminderHour, minute: reminderMinute)) ?? Date()
            },
            set: { newDate in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                reminderHour = comps.hour ?? 9
                reminderMinute = comps.minute ?? 0
            }
        )
    }

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()

                List {
                    // VAULT
                    Section(header: Text("VAULT").foregroundColor(Theme.textSecondary)) {
                        HStack(spacing: 12) {
                            Image(systemName: "folder.fill")
                                .foregroundColor(Theme.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Connected Vault")
                                    .foregroundColor(Theme.textPrimary)
                                Text(vaultFolderName)
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(vaultBookmark.vaultURL != nil ? Theme.success : Theme.textSecondary)
                        }
                        .listRowBackground(Theme.card)

                        Button {
                            showReconnectConfirm = true
                        } label: {
                            Text("Reconnect Vault")
                                .foregroundColor(Theme.accent)
                        }
                        .listRowBackground(Theme.card)
                    }

                    // DEFAULTS
                    Section(header: Text("DEFAULTS").foregroundColor(Theme.textSecondary)) {
                        DatePicker(
                            "Default Reminder Time",
                            selection: reminderTimeBinding,
                            displayedComponents: .hourAndMinute
                        )
                        .foregroundColor(Theme.textPrimary)
                        .listRowBackground(Theme.card)
                    }

                    // AI MODEL
                    Section(header: Text("AI MODEL").foregroundColor(Theme.textSecondary)) {
                        HStack(spacing: 12) {
                            Image(systemName: "cpu")
                                .foregroundColor(Theme.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("On-device LLM")
                                    .foregroundColor(Theme.textPrimary)
                                Text(llmService.isModelLoaded ? "Model loaded" : "Model not loaded")
                                    .font(.caption)
                                    .foregroundColor(llmService.isModelLoaded ? Theme.success : Theme.textSecondary)
                            }
                        }
                        .listRowBackground(Theme.card)
                    }

                    // ABOUT
                    Section(header: Text("ABOUT").foregroundColor(Theme.textSecondary)) {
                        HStack(spacing: 12) {
                            Image(systemName: "info.circle")
                                .foregroundColor(Theme.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Cortex")
                                    .foregroundColor(Theme.textPrimary)
                                Text("Version \(appVersion)")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                        .listRowBackground(Theme.card)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showVaultPicker) {
                VaultPickerView()
            }
            .alert("Reconnect Vault?", isPresented: $showReconnectConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Choose New Vault") {
                    showVaultPicker = true
                }
            }
        }
    }
}
