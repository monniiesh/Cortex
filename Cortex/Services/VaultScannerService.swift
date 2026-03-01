import Foundation
import Observation

@Observable
class VaultScannerService {

    var folders: [VaultFolder] = []
    var isScanning = false
    var lastScanDate: Date?

    func scan(vaultURL: URL) {
        isScanning = true

        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let coordinator = NSFileCoordinator()
            var coordError: NSError?
            var built: [VaultFolder] = []

            coordinator.coordinate(readingItemAt: vaultURL, options: [], error: &coordError) { coordURL in
                let fm = FileManager.default
                guard let enumerator = fm.enumerator(
                    at: coordURL,
                    includingPropertiesForKeys: [.nameKey, .isDirectoryKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                ) else {
                    print("Error: could not create enumerator for vault at \(coordURL)")
                    return
                }

                var grouped: [String: [VaultFile]] = [:]

                for case let fileURL as URL in enumerator {
                    guard fileURL.pathExtension == "md" else { continue }

                    let rel = fileURL.path.replacingOccurrences(of: coordURL.path + "/", with: "")
                    let parts = rel.components(separatedBy: "/")
                    let groupKey = parts.count > 1 ? parts[0] : "/"

                    let file = VaultFile(name: fileURL.lastPathComponent, relativePath: rel)
                    grouped[groupKey, default: []].append(file)
                }

                for (key, files) in grouped {
                    let folderPath = key == "/" ? "" : key
                    built.append(VaultFolder(name: key, path: folderPath, files: files))
                }
                built.sort { $0.name < $1.name }
            }

            if let err = coordError {
                print("Error: NSFileCoordinator error during vault scan: \(err)")
            }

            // update @Observable on main thread
            DispatchQueue.main.async { [self] in
                self.folders = built
                self.lastScanDate = Date()
                self.isScanning = false
            }
        }
    }

    func allFiles() -> [VaultFile] {
        folders.flatMap { $0.files }
    }

    func fileList() -> [String] {
        allFiles().map { $0.relativePath }
    }
}
