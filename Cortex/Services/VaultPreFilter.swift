import Foundation

struct VaultPreFilter {

    static func filter(transcript: String, index: [VaultFileIndex], maxCandidates: Int = 15) -> [VaultFileIndex] {
        let keywords = extractKeywords(from: transcript)
        guard !keywords.isEmpty else {
            // no keywords — return first maxCandidates by path order
            return Array(index.prefix(maxCandidates))
        }

        var scores: [(file: VaultFileIndex, score: Int)] = []

        for file in index {
            var score = 0

            for kw in keywords {
                let kwLower = kw.lowercased()

                // baseName match — strongest signal (weight 10)
                if file.baseName.lowercased().contains(kwLower) {
                    score += 10
                }

                // folder match (weight 5)
                if file.folder.lowercased().contains(kwLower) {
                    score += 5
                }

                // tag match (weight 4)
                for tag in file.tags {
                    if tag.lowercased().contains(kwLower) {
                        score += 4
                        break
                    }
                }

                // heading match (weight 3)
                for heading in file.headings {
                    if heading.lowercased().contains(kwLower) {
                        score += 3
                        break
                    }
                }
            }

            if score > 0 {
                scores.append((file, score))
            }
        }

        // sort by score descending
        scores.sort { $0.score > $1.score }

        // folder diversity cap — max 5 files from same folder
        var folderCounts: [String: Int] = [:]
        var results: [VaultFileIndex] = []

        for entry in scores {
            let folder = entry.file.folder
            let count = folderCounts[folder, default: 0]
            if count < 5 {
                results.append(entry.file)
                folderCounts[folder] = count + 1
            }
            if results.count >= maxCandidates { break }
        }

        // min-5 padding — if fewer than 5 scored, add unscored files
        if results.count < 5 {
            let existing = Set(results.map { $0.relativePath })
            for file in index {
                if !existing.contains(file.relativePath) {
                    results.append(file)
                    if results.count >= 5 { break }
                }
            }
        }

        return results
    }

    static func extractKeywords(from transcript: String) -> [String] {
        // split on non-alphanumeric, filter short words and stop words
        let words = transcript
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 3 }
            .map { $0.lowercased() }

        let stopWords: Set<String> = [
            "the", "and", "for", "that", "this", "with", "from", "have",
            "been", "will", "would", "could", "should", "about", "into",
            "just", "like", "also", "some", "than", "then", "when", "what",
            "which", "their", "there", "they", "them", "these", "those",
            "very", "more", "most", "only", "other", "such", "each",
            "make", "made", "want", "need", "going", "thing", "things",
            "really", "actually", "basically", "probably", "something"
        ]

        return words.filter { !stopWords.contains($0) }
    }
}
