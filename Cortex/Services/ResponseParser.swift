import Foundation

struct ResponseParser {

    struct ParsedItem: Codable {
        var type: String
        var text: String
        var files: [String]
        var newPath: String?
        var datetime: String?
        var nativeAction: Bool

        enum CodingKeys: String, CodingKey {
            case type, text, files
            case newPath = "new_path"
            case datetime
            case nativeAction = "native_action"
        }
    }

    static func parse(jsonString: String) -> [ParsedItem] {
        guard let data = jsonString.data(using: .utf8) else {
            print("Error: could not encode jsonString to data")
            return fallbackItem(raw: jsonString)
        }

        // tier 1 — strict decode
        do {
            let items = try JSONDecoder().decode([ParsedItem].self, from: data)
            return items
        } catch {
            print("Error: strict parse failed — \(error)")
        }

        // tier 2 — lenient: extract first [ to last ]
        if let firstBracket = jsonString.firstIndex(of: "["),
           let lastBracket = jsonString.lastIndex(of: "]") {
            let extracted = String(jsonString[firstBracket...lastBracket])
            if let extractedData = extracted.data(using: .utf8) {
                do {
                    let items = try JSONDecoder().decode([ParsedItem].self, from: extractedData)
                    return items
                } catch {
                    print("Error: lenient parse failed — \(error)")
                }
            }
        }

        // tier 3 — fallback
        print("Error: all parse tiers failed, returning raw fallback item")
        return fallbackItem(raw: jsonString)
    }

    private static func fallbackItem(raw: String) -> [ParsedItem] {
        return [
            ParsedItem(
                type: "note",
                text: raw,
                files: ["tasks/unprocessed.md"],
                newPath: nil,
                datetime: nil,
                nativeAction: false
            )
        ]
    }
}
