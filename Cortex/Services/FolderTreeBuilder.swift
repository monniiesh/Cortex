import Foundation

struct FolderTreeBuilder {

    static func buildTree(folders: [VaultFolder]) -> String {
        guard !folders.isEmpty else { return "(empty vault)" }

        var lines: [String] = []

        for folder in folders.sorted(by: { $0.name < $1.name }) {
            let isRoot = folder.name == "/"
            if !isRoot {
                lines.append("\(folder.name)/")
            }
            for file in folder.files {
                let prefix = isRoot ? "" : "  "
                lines.append("\(prefix)\(file.name)")
            }
        }

        return lines.joined(separator: "\n")
    }
}
