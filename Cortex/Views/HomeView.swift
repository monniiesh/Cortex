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
                Color(hex: "0A0E1A").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // show pending banner when queue has stuff
                        if appState.pendingCount > 0 {
                            queueBanner
                        }

                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(vaultScanner.folders) { folder in
                                NavigationLink(value: FolderNav(path: folder.path)) {
                                    FolderCard(folder: folder)
                                }
                                .buttonStyle(.plain)
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
                .foregroundColor(Color(hex: "3B82F6"))
            Text("\(appState.pendingCount) recording\(appState.pendingCount == 1 ? "" : "s") pending")
                .font(.subheadline)
                .foregroundColor(Color(hex: "94A3B8"))
            Spacer()
        }
        .padding(12)
        .background(Color(hex: "111827"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "1E293B"), lineWidth: 1)
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

struct FolderCard: View {
    let folder: VaultFolder

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: iconName(for: folder.name))
                .font(.title2)
                .foregroundColor(Color(hex: "3B82F6"))

            Spacer()

            Text(folder.name)
                .font(.headline)
                .foregroundColor(Color(hex: "F1F5F9"))
                .lineLimit(1)

            Text("\(folder.files.count) file\(folder.files.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundColor(Color(hex: "94A3B8"))
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .background(Color(hex: "111827"))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "1E293B"), lineWidth: 1)
        )
    }

    // pick a SF symbol based on folder name — falls back to generic folder
    private func iconName(for name: String) -> String {
        let lower = name.lowercased()
        if lower == "/" || lower == "root" { return "doc.text.fill" }
        if lower.contains("personal") { return "person.fill" }
        if lower.contains("work") { return "briefcase.fill" }
        if lower.contains("task") { return "checklist" }
        return "folder.fill"
    }
}
