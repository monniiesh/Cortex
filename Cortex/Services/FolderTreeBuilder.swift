import Foundation

struct FolderTreeBuilder {

    static func buildTree(folders: [VaultFolder]) -> String {
        guard !folders.isEmpty else { return "(empty vault)" }

        var lines: [String] = []

        for folder in folders.sorted(by: { $0.name < $1.name }) {
            let name = folder.name == "/" ? "(root)" : folder.name + "/"
            let count = folder.files.count
            lines.append("\(name) (\(count) file\(count == 1 ? "" : "s"))")
        }

        return lines.joined(separator: "\n")
    }
}
