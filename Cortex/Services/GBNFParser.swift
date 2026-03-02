import Foundation
import llama

// minimal GBNF parser — converts GBNF grammar text into llama_grammar_element rules
// for use with llama_grammar_init / llama_sample_grammar
struct GBNFParser {

    private var rules: [[llama_grammar_element]] = []
    private var symbols: [String: UInt32] = [:]

    private mutating func symId(_ name: String) -> UInt32 {
        if let id = symbols[name] { return id }
        let id = UInt32(rules.count)
        symbols[name] = id
        rules.append([])
        return id
    }

    private mutating func subRule() -> UInt32 {
        let id = UInt32(rules.count)
        rules.append([])
        return id
    }

    private func el(_ type: llama_gretype, _ value: UInt32) -> llama_grammar_element {
        llama_grammar_element(type: type, value: value)
    }

    private func cv(_ ch: Character) -> UInt32 {
        UInt32(ch.unicodeScalars.first!.value)
    }

    // MARK: - Public

    mutating func parse(_ grammar: String) -> OpaquePointer? {
        // split into rule definitions, joining continuation lines
        var defs: [(String, String)] = []
        for line in grammar.components(separatedBy: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.isEmpty { continue }
            if let r = t.range(of: "::=") {
                let name = t[..<r.lowerBound].trimmingCharacters(in: .whitespaces)
                let body = String(t[r.upperBound...])
                defs.append((name, body))
            } else if !defs.isEmpty {
                defs[defs.count - 1].1 += " " + t
            }
        }
        guard !defs.isEmpty else { return nil }

        // first pass: register all named rules
        for (name, _) in defs { _ = symId(name) }

        // second pass: parse bodies
        for (name, body) in defs {
            let id = Int(symbols[name]!)
            let c = Array(body)
            var p = 0
            var e: [llama_grammar_element] = []
            parseAlts(c, &p, &e)
            e.append(el(LLAMA_GRETYPE_END, 0))
            rules[id] = e
        }

        return buildGrammar()
    }

    // MARK: - Alternates / Sequence

    private func ws(_ c: [Character], _ p: inout Int) {
        while p < c.count && (c[p] == " " || c[p] == "\t") { p += 1 }
    }

    private mutating func parseAlts(_ c: [Character], _ p: inout Int, _ out: inout [llama_grammar_element]) {
        ws(c, &p)
        parseSeq(c, &p, &out)
        while p < c.count {
            ws(c, &p)
            guard p < c.count && c[p] == "|" else { break }
            p += 1; ws(c, &p)
            out.append(el(LLAMA_GRETYPE_ALT, 0))
            parseSeq(c, &p, &out)
        }
    }

    private mutating func parseSeq(_ c: [Character], _ p: inout Int, _ out: inout [llama_grammar_element]) {
        while p < c.count {
            ws(c, &p)
            guard p < c.count else { break }
            if c[p] == "|" || c[p] == ")" { break }

            let mark = out.count

            switch c[p] {
            case "\"":
                parseLit(c, &p, &out)
            case "[":
                parseCharClass(c, &p, &out)
            case "(":
                p += 1
                let groupStart = out.count
                parseAlts(c, &p, &out)
                if p < c.count && c[p] == ")" { p += 1 }
                // wrap groups containing ALT in a sub-rule so the ALT
                // doesn't split the parent rule's sequence
                let groupElems = Array(out[groupStart...])
                if groupElems.contains(where: { $0.type == LLAMA_GRETYPE_ALT }) {
                    out.removeSubrange(groupStart...)
                    let wrapId = subRule()
                    rules[Int(wrapId)] = groupElems + [el(LLAMA_GRETYPE_END, 0)]
                    out.append(el(LLAMA_GRETYPE_RULE_REF, wrapId))
                }
            case ".":
                p += 1
                // any char = "not null"
                out.append(el(LLAMA_GRETYPE_CHAR_NOT, 0))
            default:
                if c[p].isLetter || c[p] == "_" || c[p] == "-" {
                    parseRef(c, &p, &out)
                } else {
                    return
                }
            }

            // quantifier?
            ws(c, &p)
            guard p < c.count, c[p] == "*" || c[p] == "+" || c[p] == "?" else { continue }
            let q = c[p]; p += 1

            var sub = Array(out[mark...])
            out.removeSubrange(mark...)

            // if sub contains ALT, wrap in its own rule first
            if sub.contains(where: { $0.type == LLAMA_GRETYPE_ALT }) {
                let wrapId = subRule()
                rules[Int(wrapId)] = sub + [el(LLAMA_GRETYPE_END, 0)]
                sub = [el(LLAMA_GRETYPE_RULE_REF, wrapId)]
            }

            let id = subRule()
            switch q {
            case "*":
                // sub ::= content sub | (empty)
                rules[Int(id)] = sub + [el(LLAMA_GRETYPE_RULE_REF, id), el(LLAMA_GRETYPE_ALT, 0), el(LLAMA_GRETYPE_END, 0)]
            case "+":
                // sub ::= content sub | content
                rules[Int(id)] = sub + [el(LLAMA_GRETYPE_RULE_REF, id), el(LLAMA_GRETYPE_ALT, 0)] + sub + [el(LLAMA_GRETYPE_END, 0)]
            case "?":
                // sub ::= content | (empty)
                rules[Int(id)] = sub + [el(LLAMA_GRETYPE_ALT, 0), el(LLAMA_GRETYPE_END, 0)]
            default:
                break
            }
            out.append(el(LLAMA_GRETYPE_RULE_REF, id))
        }
    }

    // MARK: - Literals

    private func parseLit(_ c: [Character], _ p: inout Int, _ out: inout [llama_grammar_element]) {
        p += 1 // skip opening "
        while p < c.count && c[p] != "\"" {
            var val: UInt32
            if c[p] == "\\" && p + 1 < c.count {
                p += 1
                switch c[p] {
                case "n": val = 0x0A
                case "t": val = 0x09
                case "r": val = 0x0D
                case "\\": val = 0x5C
                case "\"": val = 0x22
                default: val = cv(c[p])
                }
            } else {
                val = cv(c[p])
            }
            out.append(el(LLAMA_GRETYPE_CHAR, val))
            p += 1
        }
        if p < c.count { p += 1 } // skip closing "
    }

    // MARK: - Character classes

    private func classChar(_ c: [Character], _ p: inout Int) -> UInt32 {
        if c[p] == "\\" && p + 1 < c.count {
            p += 1
            let val: UInt32
            switch c[p] {
            case "n": val = 0x0A
            case "t": val = 0x09
            case "r": val = 0x0D
            case "\\": val = 0x5C
            case "]": val = 0x5D
            case "[": val = 0x5B
            case "^": val = 0x5E
            case "-": val = 0x2D
            default: val = cv(c[p])
            }
            p += 1
            return val
        }
        let val = cv(c[p])
        p += 1
        return val
    }

    private func parseCharClass(_ c: [Character], _ p: inout Int, _ out: inout [llama_grammar_element]) {
        p += 1 // skip [
        let neg = p < c.count && c[p] == "^"
        if neg { p += 1 }

        var first = true
        while p < c.count && c[p] != "]" {
            let val = classChar(c, &p)
            out.append(el(first ? (neg ? LLAMA_GRETYPE_CHAR_NOT : LLAMA_GRETYPE_CHAR) : LLAMA_GRETYPE_CHAR_ALT, val))
            first = false

            // range?
            if p < c.count && c[p] == "-" && p + 1 < c.count && c[p + 1] != "]" {
                p += 1
                out.append(el(LLAMA_GRETYPE_CHAR_RNG_UPPER, classChar(c, &p)))
            }
        }
        if p < c.count { p += 1 } // skip ]
    }

    // MARK: - Rule references

    private mutating func parseRef(_ c: [Character], _ p: inout Int, _ out: inout [llama_grammar_element]) {
        var name = ""
        while p < c.count && (c[p].isLetter || c[p].isNumber || c[p] == "_" || c[p] == "-") {
            name.append(c[p]); p += 1
        }
        if !name.isEmpty {
            out.append(el(LLAMA_GRETYPE_RULE_REF, symId(name)))
        }
    }

    // MARK: - Build grammar pointer

    private func buildGrammar() -> OpaquePointer? {
        guard !rules.isEmpty else { return nil }

        // allocate element arrays
        var ptrs: [UnsafeMutablePointer<llama_grammar_element>] = []
        for rule in rules {
            let ptr = UnsafeMutablePointer<llama_grammar_element>.allocate(capacity: max(rule.count, 1))
            for (i, e) in rule.enumerated() { ptr[i] = e }
            ptrs.append(ptr)
        }

        // array of pointers
        let arr = UnsafeMutablePointer<UnsafePointer<llama_grammar_element>?>.allocate(capacity: rules.count)
        for i in 0 ..< rules.count { arr[i] = UnsafePointer(ptrs[i]) }

        let g = llama_grammar_init(arr, rules.count, 0)

        // llama_grammar_init copies the data, safe to free
        for ptr in ptrs { ptr.deallocate() }
        arr.deallocate()

        return g
    }
}
