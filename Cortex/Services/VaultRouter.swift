import Foundation

struct RoutedTarget {
    let file: String
    let isNew: Bool
}

struct VaultRouter {

    static func route(suggestedFile: String, availableFiles: [String]) -> (file: String, isNew: Bool) {

        // step 1 — exact match
        for f in availableFiles {
            if f == suggestedFile {
                return (f, false)
            }
        }

        // step 2 — case-insensitive match
        let lowerSuggested = suggestedFile.lowercased()
        for f in availableFiles {
            if f.lowercased() == lowerSuggested {
                return (f, false)
            }
        }

        // step 3 — filename match (last path component)
        let suggestedFilename = (suggestedFile as NSString).lastPathComponent
        if suggestedFile.contains("/") {
            for f in availableFiles {
                let fFilename = (f as NSString).lastPathComponent
                if fFilename.lowercased() == suggestedFilename.lowercased() {
                    return (f, false)
                }
            }
        }

        // step 4 — keyword match
        let baseName = suggestedFilename
            .replacingOccurrences(of: ".md", with: "")
            .lowercased()
        let keywords = baseName
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }

        if !keywords.isEmpty {
            var bestFile = ""
            var bestScore = 0

            for f in availableFiles {
                let fBase = (f as NSString)
                    .lastPathComponent
                    .replacingOccurrences(of: ".md", with: "")
                    .lowercased()
                var score = 0
                for kw in keywords {
                    if fBase.contains(kw) {
                        score += 1
                    }
                }
                if score > bestScore {
                    bestScore = score
                    bestFile = f
                }
            }

            if bestScore > 0 {
                return (bestFile, false)
            }
        }

        // step 5 — no match, treat as new file
        return (suggestedFile, true)
    }

    static func routeMultiple(suggestedFiles: [String], availableFiles: [String]) -> [RoutedTarget] {
        var seen = Set<String>()
        var results: [RoutedTarget] = []

        for suggested in suggestedFiles {
            let resolved = route(suggestedFile: suggested, availableFiles: availableFiles)
            let normalized = resolved.file.lowercased()
            if !seen.contains(normalized) {
                seen.insert(normalized)
                results.append(RoutedTarget(file: resolved.file, isNew: resolved.isNew))
            }
        }

        if results.isEmpty {
            return [RoutedTarget(file: "tasks/unprocessed.md", isNew: true)]
        }

        return results
    }
}
