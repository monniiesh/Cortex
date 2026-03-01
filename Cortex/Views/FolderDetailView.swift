import SwiftUI
import SwiftData

struct FolderDetailView: View {
    let folder: VaultFolder

    @Environment(\.modelContext) private var modelContext
    @State private var itemCounts: [String: Int] = [:]

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            List {
                ForEach(folder.files) { file in
                    NavigationLink(value: file.relativePath) {
                        FileRow(file: file, itemCount: itemCounts[file.relativePath] ?? 0)
                    }
                    .listRowBackground(Theme.card)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(folder.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationDestination(for: String.self) { path in
            FileDetailView(relativePath: path, fileName: displayName(path))
        }
        .onAppear { loadItemCounts() }
    }

    // batch fetch — one query instead of N per file
    private func loadItemCounts() {
        guard let all = try? modelContext.fetch(FetchDescriptor<VaultItem>()) else { return }
        let paths = Set(folder.files.map { $0.relativePath })
        var counts: [String: Int] = [:]
        for item in all {
            for p in item.targetFiles where paths.contains(p) {
                counts[p, default: 0] += 1
            }
        }
        itemCounts = counts
    }

    private func displayName(_ path: String) -> String {
        (path as NSString).lastPathComponent.replacingOccurrences(of: ".md", with: "")
    }
}

struct FileRow: View {
    let file: VaultFile
    let itemCount: Int

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text((file.relativePath as NSString).lastPathComponent.replacingOccurrences(of: ".md", with: ""))
                    .font(.body)
                    .foregroundStyle(Theme.textPrimary)

                if itemCount > 0 {
                    Text("\(itemCount) item\(itemCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.vertical, 4)
    }
}
