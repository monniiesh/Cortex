import Foundation

struct VaultFolder: Identifiable {
    let id: UUID
    let name: String
    let path: String  // relative path from vault root
    var files: [VaultFile]

    init(name: String, path: String, files: [VaultFile] = []) {
        self.id = UUID()
        self.name = name
        self.path = path
        self.files = files
    }
}

struct VaultFile: Identifiable {
    let id: UUID
    let name: String         // e.g. "anime.md"
    let relativePath: String // e.g. "personal/anime.md"

    init(name: String, relativePath: String) {
        self.id = UUID()
        self.name = name
        self.relativePath = relativePath
    }
}

struct VaultFileIndex {
    let relativePath: String   // e.g. "Personal/gym.md"
    let baseName: String       // e.g. "gym"
    let folder: String         // e.g. "Personal" (or "" for root)
    let headings: [String]     // h1-h3 extracted from first 4KB
    let tags: [String]         // #tag words from first 4KB
    let summary: String        // first non-empty line after frontmatter, max 80 chars
}
