import Foundation
import Observation

@Observable
class VaultBookmarkService {

    private let bookmarkKey = "vaultFolderBookmark"
    var vaultURL: URL?

    var hasVaultFolder: Bool {
        UserDefaults.standard.data(forKey: bookmarkKey) != nil
    }

    func saveBookmark(for url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            print("Error: failed to access security-scoped resource")
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let bookmark = try url.bookmarkData(
                options: .minimalBookmark,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(bookmark, forKey: bookmarkKey)
        } catch {
            print("Error: failed to save vault bookmark: \(error)")
        }
    }

    func loadBookmarkURL() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            if isStale {
                saveBookmark(for: url)
            }
            _ = url.startAccessingSecurityScopedResource()
            vaultURL = url
            return url
        } catch {
            print("Error: failed to resolve vault bookmark: \(error)")
            return nil
        }
    }

    func stopAccessing() {
        vaultURL?.stopAccessingSecurityScopedResource()
        vaultURL = nil
    }

    func clearBookmark() {
        stopAccessing()
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
    }
}
