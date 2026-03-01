import SwiftUI
import SwiftData

struct SearchView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var searchText = ""
    @State private var results: [VaultItem] = []
    @State private var filterType: ContentType? = nil
    @State private var debounceTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                VStack(spacing: 0) {
                    searchField
                    filterChips
                    if results.isEmpty && !searchText.isEmpty {
                        emptyState
                    } else {
                        resultsList
                    }
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Theme.textSecondary)
            TextField("Search items...", text: $searchText)
                .foregroundColor(Theme.textPrimary)
                .autocorrectionDisabled()
                .onChange(of: searchText) { _, newValue in
                    debounceSearch(query: newValue)
                }
        }
        .padding(12)
        .background(Theme.searchField)
        .cornerRadius(Theme.cardRadius)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(label: "All", isActive: filterType == nil) {
                    filterType = nil
                    performSearch()
                }
                ForEach(ContentType.allCases, id: \.self) { type in
                    FilterChip(label: type.rawValue.capitalized, isActive: filterType == type) {
                        filterType = type
                        performSearch()
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 10)
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(results) { item in
                    SearchResultRow(item: item)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var emptyState: some View {
        VStack {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .font(.largeTitle)
                .foregroundColor(Theme.textSecondary)
            Text("No results found")
                .foregroundColor(Theme.textSecondary)
                .padding(.top, 8)
            Spacer()
        }
    }

    private func debounceSearch(query: String) {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            if !Task.isCancelled {
                performSearch()
            }
        }
    }

    private func performSearch() {
        guard !searchText.isEmpty else {
            results = []
            return
        }
        let query = searchText
        var descriptor = FetchDescriptor<VaultItem>(
            sortBy: [SortDescriptor(\VaultItem.createdAt, order: .reverse)]
        )
        if let typeFilter = filterType {
            let typeRawFilter = typeFilter.rawValue
            descriptor.predicate = #Predicate {
                $0.text.localizedStandardContains(query) && $0.typeRaw == typeRawFilter
            }
        } else {
            descriptor.predicate = #Predicate {
                $0.text.localizedStandardContains(query)
            }
        }
        descriptor.fetchLimit = 50
        results = (try? modelContext.fetch(descriptor)) ?? []
    }
}

struct FilterChip: View {
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isActive ? .white : Theme.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isActive ? Theme.accent : Theme.card)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isActive ? Color.clear : Theme.divider, lineWidth: 1)
                )
        }
    }
}

struct SearchResultRow: View {
    let item: VaultItem

    private var typeIcon: String {
        switch item.type {
        case .note: return "note.text"
        case .todo: return "checklist"
        case .reminder: return "bell.fill"
        case .event: return "calendar"
        }
    }

    private var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: item.createdAt, relativeTo: Date.now)
    }

    private var firstTargetFile: String? {
        item.targetFiles.first.flatMap { $0.isEmpty ? nil : $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: typeIcon)
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
                Text(item.type.rawValue.uppercased())
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
                Spacer()
                Text(relativeDate)
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
            }
            Text(item.text)
                .font(.body)
                .foregroundColor(Theme.textPrimary)
                .lineLimit(3)
            if let file = firstTargetFile {
                Text(file)
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .padding(12)
        .background(Theme.card)
        .cornerRadius(Theme.cardRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius)
                .stroke(Theme.divider, lineWidth: 1)
        )
    }
}
