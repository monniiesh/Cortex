import Foundation
import Observation

@Observable
class VaultScannerService: @unchecked Sendable {

    var folders: [VaultFolder] = []
    var fileIndex: [VaultFileIndex] = []
    var isScanning = false
    var lastScanDate: Date?

    func scan(vaultURL: URL) {
        isScanning = true

        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let (built, index) = performScan(vaultURL: vaultURL)

            DispatchQueue.main.async { [self] in
                self.folders = built
                self.fileIndex = index
                self.lastScanDate = Date()
                self.isScanning = false
            }
        }
    }

    func scanAsync(vaultURL: URL) async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                let (built, index) = performScan(vaultURL: vaultURL)

                DispatchQueue.main.async { [self] in
                    self.folders = built
                    self.fileIndex = index
                    self.lastScanDate = Date()
                    self.isScanning = false
                    continuation.resume()
                }
            }
        }
    }

    func allFiles() -> [VaultFile] {
        folders.flatMap { $0.files }
    }

    func fileList() -> [String] {
        allFiles().map { $0.relativePath }
    }

    // MARK: - Private

    private func performScan(vaultURL: URL) -> ([VaultFolder], [VaultFileIndex]) {
        let coordinator = NSFileCoordinator()
        var coordError: NSError?
        var built: [VaultFolder] = []
        var index: [VaultFileIndex] = []

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

                // build file index — read first 4KB for metadata
                let fileIdx = buildFileIndex(fileURL: fileURL, relativePath: rel, folder: groupKey == "/" ? "" : groupKey)
                index.append(fileIdx)
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

        return (built, index)
    }

    private func buildFileIndex(fileURL: URL, relativePath: String, folder: String) -> VaultFileIndex {
        let baseName = fileURL.deletingPathExtension().lastPathComponent

        // read first 4KB
        var content = ""
        if let handle = try? FileHandle(forReadingFrom: fileURL) {
            let data = handle.readData(ofLength: 4096)
            handle.closeFile()
            content = String(data: data, encoding: .utf8) ?? ""
        }

        let lines = content.components(separatedBy: .newlines)

        var headings: [String] = []
        var tags: [String] = []
        var summary = ""
        var inFrontmatter = false
        var pastFrontmatter = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // frontmatter detection
            if trimmed == "---" {
                if !pastFrontmatter {
                    inFrontmatter = !inFrontmatter
                    if !inFrontmatter { pastFrontmatter = true }
                    continue
                }
            }
            if inFrontmatter { continue }

            // headings (h1-h3)
            if trimmed.hasPrefix("# ") || trimmed.hasPrefix("## ") || trimmed.hasPrefix("### ") {
                let headingText = trimmed.drop(while: { $0 == "#" || $0 == " " })
                if !headingText.isEmpty {
                    headings.append(String(headingText))
                }
            }

            // tags — words starting with # that aren't heading markers
            let words = trimmed.components(separatedBy: .whitespaces)
            for word in words {
                if word.hasPrefix("#") && word.count > 1 && !word.hasPrefix("##") {
                    let tag = word.trimmingCharacters(in: CharacterSet.alphanumerics.inverted.union(CharacterSet(charactersIn: "#")).subtracting(CharacterSet(charactersIn: "#")))
                    if !tag.isEmpty && tag != "#" {
                        tags.append(tag)
                    }
                }
            }

            // summary — first non-empty, non-heading, non-frontmatter line
            if summary.isEmpty && !trimmed.isEmpty && !trimmed.hasPrefix("#") {
                summary = String(trimmed.prefix(80))
            }
        }

        return VaultFileIndex(
            relativePath: relativePath,
            baseName: baseName,
            folder: folder,
            headings: Array(headings.prefix(5)),
            tags: Array(Set(tags).prefix(10)),
            summary: summary
        )
    }
}
