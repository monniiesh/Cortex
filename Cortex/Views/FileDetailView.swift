import SwiftUI
import SwiftData

struct FileDetailView: View {
    let relativePath: String
    let fileName: String

    @Environment(\.modelContext) private var modelContext
    @State private var items: [VaultItem] = []

    private var reminders: [VaultItem] {
        items.filter { $0.type == .reminder || $0.type == .event }
            .sorted { ($0.datetime ?? .distantPast) < ($1.datetime ?? .distantPast) }
    }

    private var todos: [VaultItem] {
        items.filter { $0.type == .todo }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var notes: [VaultItem] {
        items.filter { $0.type == .note }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if !reminders.isEmpty {
                        ContentSection(title: "REMINDERS", items: reminders, relativePath: relativePath)
                    }
                    if !todos.isEmpty {
                        ContentSection(title: "TODOS", items: todos, relativePath: relativePath)
                    }
                    if !notes.isEmpty {
                        ContentSection(title: "NOTES", items: notes, relativePath: relativePath)
                    }
                    if items.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text")
                                .font(.largeTitle)
                                .foregroundStyle(Theme.textSecondary)
                            Text("No items yet")
                                .font(.body)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle(fileName)
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear { fetchItems() }
    }

    private func fetchItems() {
        // wrap in quotes to match exact JSON element boundary
        let quoted = "\"\(relativePath)\""
        let descriptor = FetchDescriptor<VaultItem>(
            predicate: #Predicate { $0.targetFilesRaw.contains(quoted) }
        )
        items = (try? modelContext.fetch(descriptor)) ?? []
    }
}

// MARK: - ContentSection

struct ContentSection: View {
    let title: String
    let items: [VaultItem]
    let relativePath: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.textSecondary)
                .kerning(1.2)

            ForEach(items) { item in
                ItemCard(item: item, relativePath: relativePath)
            }
        }
    }
}

// MARK: - ItemCard

struct ItemCard: View {
    @Bindable var item: VaultItem
    let relativePath: String

    @Environment(VaultBookmarkService.self) private var vaultBookmark

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if item.type == .todo || item.type == .reminder || item.type == .event {
                Button {
                    toggleCheckbox()
                } label: {
                    Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(item.isCompleted ? Theme.accent : Theme.textSecondary)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.text)
                    .font(.body)
                    .foregroundStyle(item.isCompleted ? Theme.textSecondary : Theme.textPrimary)
                    .strikethrough(item.isCompleted)

                if let dt = item.datetime {
                    Text(dt, style: .date)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            Spacer()
        }
        .padding(12)
        .background(Theme.card)
        .cornerRadius(Theme.cardRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius)
                .stroke(Theme.divider, lineWidth: 1)
        )
        .animation(Theme.spring, value: item.isCompleted)
    }

    private func toggleCheckbox() {
        let newState = !item.isCompleted
        item.isCompleted = newState

        // write back to .md file off main thread (fire and forget)
        if let vaultURL = vaultBookmark.loadBookmarkURL() {
            let text = item.text
            let path = relativePath
            Task.detached(priority: .utility) {
                VaultWriter.toggleCheckbox(
                    text: text,
                    isCompleted: newState,
                    inFile: path,
                    vaultURL: vaultURL
                )
            }
        }
    }
}
