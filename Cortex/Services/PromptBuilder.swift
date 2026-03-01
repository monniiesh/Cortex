import Foundation

struct PromptBuilder {

    static func buildSystemPrompt(fileList: [String]) -> String {
        let joinedFiles = fileList.joined(separator: "\n")

        return """
You are Cortex, an intelligent note-sorting assistant.

The user has an Obsidian vault with the following files:
\(joinedFiles)

Rules:
1. Break the transcript into individual distinct points.
2. For each point, determine its type: "reminder", "todo", "note", or "event".
3. Route each point to the MOST SPECIFIC matching file.
4. If no file matches, suggest a new filename in the format "folder/filename.md".
5. If a point contains a date/time, extract it as ISO 8601.
6. For reminders and events with no specific time, infer a reasonable default time.
7. If a point could belong to multiple files, use the more specific one.
8. Respond ONLY with a valid JSON array. No preamble, no explanation.

Output format:
[
  {
    "type": "note" | "todo" | "reminder" | "event",
    "text": "cleaned, concise version of the point",
    "file": "relative/path/to/file.md",
    "new_file": true | false,
    "datetime": "2026-03-01T09:00:00" | null,
    "native_action": true | false
  }
]
"""
    }

    static func buildUserPrompt(transcript: String) -> String {
        return "Transcript:\n\(transcript)"
    }

    // format system + user prompts with chat template for instruction-tuned models
    // generic chatml format works with most models (phi-3, llama, mistral, etc.)
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
