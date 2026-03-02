import SwiftUI

struct HomeView: View {
    @Environment(VaultScannerService.self) private var vaultScanner
    @Environment(VaultBookmarkService.self) private var vaultBookmark
    @Environment(AppState.self) private var appState

    @State private var hasScanned = false

    // 2-column grid
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // show pending banner when queue has stuff
                        if appState.pendingCount > 0 {
                            queueBanner
                        }

                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(Array(vaultScanner.folders.enumerated()), id: \.element.path) { idx, folder in
                                NavigationLink(value: FolderNav(path: folder.path)) {
                                    FolderCardLabel(folder: folder)
                                }
                                .buttonStyle(CardPressStyle())
                                .opacity(hasScanned ? 1 : 0)
                                .offset(y: hasScanned ? 0 : 20)
                                .animation(Theme.spring.delay(Double(idx) * 0.05), value: hasScanned)
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Vault")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationDestination(for: FolderNav.self) { nav in
                // look up by path (stable across rescans, unlike UUID)
                if let folder = vaultScanner.folders.first(where: { $0.path == nav.path }) {
                    FolderDetailView(folder: folder)
                }
            }
            .onAppear {
                triggerScanIfNeeded()
            }
        }
    }

    // queue status banner — waveform icon + pending count
    private var queueBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform")
                .foregroundColor(Theme.accent)
            Text("\(appState.pendingCount) recording\(appState.pendingCount == 1 ? "" : "s") pending")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
            Spacer()
        }
        .padding(12)
        .background(Theme.card)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.divider, lineWidth: 1)
        )
    }

    private func triggerScanIfNeeded() {
        guard !hasScanned, !vaultScanner.isScanning else { return }
        guard let url = vaultBookmark.loadBookmarkURL() else { return }
        vaultScanner.scan(vaultURL: url)
        hasScanned = true
    }
}

// stable nav value — avoids String conflict with FolderDetailView
struct FolderNav: Hashable {
    let path: String
}

// button style that drives the press animation — doesn't steal taps from NavigationLink
struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .shadow(color: Theme.cardShadow, radius: configuration.isPressed ? 2 : 6, y: configuration.isPressed ? 1 : 3)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(Theme.springSnappy, value: configuration.isPressed)
    }
}

struct FolderCardLabel: View {
    let folder: VaultFolder

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: iconName(for: folder.name))
                .font(.title2)
                .foregroundColor(Theme.accent)

            Spacer()

            Text(folder.name)
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)

            Text("\(folder.files.count) file\(folder.files.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .background(Theme.card)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.divider, lineWidth: 1)
        )
    }

    private func iconName(for name: String) -> String {
        let lower = name.lowercased()
        if lower == "/" || lower == "root" { return "doc.text.fill" }
        if lower.contains("personal") { return "person.fill" }
        if lower.contains("work") { return "briefcase.fill" }
        if lower.contains("task") { return "checklist" }
        return "folder.fill"
    }
}
