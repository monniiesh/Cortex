import Foundation
import Observation

@Observable
class VaultBookmarkService: @unchecked Sendable {

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
                options: [],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(bookmark, forKey: bookmarkKey)
        } catch {
            print("Error: failed to save vault bookmark: \(error)")
        }
    }

    func loadBookmarkURL() -> URL? {
        // already resolved
        if let vaultURL { return vaultURL }

        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            guard url.startAccessingSecurityScopedResource() else {
                print("Error: failed to start security-scoped access for vault URL")
                return nil
            }

            if isStale {
                // re-save while access is active (don't go through saveBookmark which does its own start/stop)
                do {
                    let freshBookmark = try url.bookmarkData(
                        options: [],
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )
                    UserDefaults.standard.set(freshBookmark, forKey: bookmarkKey)
                } catch {
                    print("Error: failed to refresh stale bookmark: \(error)")
                }
            }

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
