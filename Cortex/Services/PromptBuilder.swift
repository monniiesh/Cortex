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

        // when no candidates match, tell the LLM explicitly
        let candidateSection: String
        if candidates.isEmpty {
            candidateSection = """
            Candidate files: (none)
            Use "new_path" for every item.
            """
        } else {
            candidateSection = """
            Candidate files:
            \(candidateLines)
            """
        }

        return """
You are Cortex, a note-sorting assistant.

Vault structure:
\(folderTree)

\(candidateSection)
Rules:
1. Split transcript into separate points.
2. "todo" ONLY for explicit buy/get/pick-up requests. Everything else is "note". Do NOT infer actions — "VHO research" is ONE note, NOT a note + a "research" todo. "Batman is good" is ONE note, NOT a note + a "watch movie" todo.
3. Route to candidate files by ID (f0, f1, etc.) only if the EXACT topic matches.
4. No candidate match → set files to [] and use "new_path". Format: "Category/subject.md". NEVER use generic names (Index, Notes, tools, Misc). Different subjects need different files even in the same category.
5. Text format: item name + brief context in parentheses. Examples: "JJK (recommended anime)", "Batman (good movie)", "QC Super (VHO network tool)". Keep it short but include what it IS.
6. If user says "{topic} research", file = "{topic}.md". Name the file after the RESEARCH SUBJECT, not the tool mentioned.
7. Group similar items into ONE file. Tools go in "tools.md", groceries in "grocery.md", anime in "anime.md". Do NOT create a separate file per item.
8. Extract datetime as ISO 8601 when present.
9. Output ONLY a JSON array.

Example:
Input: "buy butter also jjk is a recommended anime and batman is a good movie and vho research on qc super network tool and neofetch is a good tool"
[{"type":"todo","text":"butter","files":[],"new_path":"Lists/grocery.md","datetime":null,"native_action":false},{"type":"note","text":"JJK (recommended anime)","files":[],"new_path":"Entertainment/anime.md","datetime":null,"native_action":false},{"type":"note","text":"Batman (good movie)","files":[],"new_path":"Entertainment/movies.md","datetime":null,"native_action":false},{"type":"note","text":"QC Super (VHO network tool)","files":[],"new_path":"Research/vho.md","datetime":null,"native_action":false},{"type":"note","text":"neofetch (good tool)","files":[],"new_path":"Tools/tools.md","datetime":null,"native_action":false}]
"""
    }

    static func buildUserPrompt(transcript: String) -> String {
        return "Transcript:\n\(transcript)\nExtract EVERY distinct topic. Do NOT stop after the first one."
    }

    static func buildRetryUserPrompt(transcript: String, alreadyCaptured: [String], uncoveredKeywords: [String]) -> String {
        let captured = alreadyCaptured.enumerated()
            .map { "\($0.offset + 1). \($0.element)" }
            .joined(separator: "\n")
        let hint = uncoveredKeywords.isEmpty ? ""
            : "\nUncovered words: \(uncoveredKeywords.prefix(8).joined(separator: ", ")). Process a topic with these words."
        return """
        Transcript:
        \(transcript)

        Already captured (DO NOT repeat):
        \(captured)
        \(hint)
        """
    }

    static func formatChatPrompt(systemPrompt: String, userPrompt: String) -> String {
        return """
<|im_start|>system
\(systemPrompt)<|im_end|>
<|im_start|>user
\(userPrompt)<|im_end|>
<|im_start|>assistant
"""
    }
}
