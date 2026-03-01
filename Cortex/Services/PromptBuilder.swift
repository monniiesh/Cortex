import Foundation

struct PromptBuilder {

    // V2 — candidate-based prompt with file IDs
    static func buildSystemPrompt(candidates: [VaultFileIndex], folderTree: String) -> String {
        var candidateLines = ""
        for (idx, c) in candidates.enumerated() {
            let id = "f\(idx)"
            var parts: [String] = [c.relativePath]
            if !c.summary.isEmpty { parts.append(c.summary) }
            if !c.tags.isEmpty { parts.append("Tags: \(c.tags.joined(separator: " "))") }
            candidateLines += "\(id): \(parts.joined(separator: " — "))\n"
        }

        return """
You are Cortex, an intelligent note-sorting assistant.

Vault structure:
\(folderTree)

Candidate files:
\(candidateLines)
Rules:
1. Break the transcript into individual distinct points.
2. For each point, determine its type: "reminder", "todo", "note", or "event".
3. Route each point to candidate files using their IDs (f0, f1, f2, etc.).
4. If a point belongs in multiple files, list ALL relevant IDs in the "files" array (most specific first). Most items have 1 file. Use 2+ only when content genuinely belongs in multiple places.
5. If no candidate file matches, set files to [] and provide a path in "new_path" (format: "folder/filename.md").
6. If a point contains a date/time, extract it as ISO 8601.
7. For reminders and events with no specific time, infer a reasonable default time.
8. Respond ONLY with a valid JSON array. No preamble, no explanation.

Output format:
[
  {
    "type": "note" | "todo" | "reminder" | "event",
    "text": "cleaned, concise version of the point",
    "files": ["f0", "f3"],
    "new_path": null,
    "datetime": "2026-03-01T09:00:00" | null,
    "native_action": true | false
  }
]
"""
    }

    static func buildUserPrompt(transcript: String) -> String {
        return "Transcript:\n\(transcript)"
    }

    static func formatChatPrompt(systemPrompt: String, userPrompt: String) -> String {
        return """
<|system|>
\(systemPrompt)
<|end|>
<|user|>
\(userPrompt)
<|end|>
<|assistant|>
"""
    }
}
