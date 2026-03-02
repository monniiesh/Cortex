import Foundation
import Observation
import llama

protocol LLMServiceProtocol {
    var isModelLoaded: Bool { get }
    var modelPath: String? { get }
    func loadModel(from path: String) async throws
    func generate(prompt: String, grammar: String?) async throws -> String
    func unloadModel()
}

// Sendable wrapper for C pointers (just integer addresses, safe to send)
private struct Ptr: @unchecked Sendable {
    let raw: OpaquePointer
}

@Observable
class LLMService: LLMServiceProtocol, @unchecked Sendable {

    var isModelLoaded = false
    var modelPath: String?

    private var model: OpaquePointer?
    private var context: OpaquePointer?

    static let defaultGrammarJSON = """
root ::= "[" ws item ("," ws item)* ws "]"
item ::= "{" ws
  "\\"type\\"" ws ":" ws type "," ws
  "\\"text\\"" ws ":" ws string "," ws
  "\\"files\\"" ws ":" ws filearray "," ws
  "\\"new_path\\"" ws ":" ws (string | "null") "," ws
  "\\"datetime\\"" ws ":" ws (string | "null") "," ws
  "\\"native_action\\"" ws ":" ws boolean
ws "}"
type ::= "\\"note\\"" | "\\"todo\\"" | "\\"reminder\\"" | "\\"event\\""
boolean ::= "true" | "false"
string ::= "\\"" ([^"\\\\] | "\\\\" .)* "\\""
filearray ::= "[" ws "]" | "[" ws fileid ("," ws fileid)* ws "]"
fileid ::= "\\"f" [0-9] "\\"" | "\\"f1" [0-9] "\\""
ws ::= " "?
"""

    func loadModel(from path: String) async throws {
        let result: (model: Ptr, ctx: Ptr) = try await Task.detached(priority: .userInitiated) {
            var modelParams = llama_model_default_params()
            modelParams.n_gpu_layers = 99

            guard let loadedModel = llama_load_model_from_file(path, modelParams) else {
                throw LLMError.modelLoadFailed("could not load model from \(path)")
            }

            var ctxParams = llama_context_default_params()
            ctxParams.n_ctx = 4096
            ctxParams.n_threads = 4

            guard let loadedCtx = llama_new_context_with_model(loadedModel, ctxParams) else {
                llama_free_model(loadedModel)
                throw LLMError.contextInitFailed
            }

            return (Ptr(raw: loadedModel), Ptr(raw: loadedCtx))
        }.value

        self.model = result.model.raw
        self.context = result.ctx.raw
        self.modelPath = path
        self.isModelLoaded = true
    }

    func generate(prompt: String, grammar: String?) async throws -> String {
        guard isModelLoaded, let ctx = context, let mdl = model else {
            throw LLMError.modelNotLoaded
        }

        let ctxPtr = Ptr(raw: ctx)
        let mdlPtr = Ptr(raw: mdl)

        return try await Task.detached(priority: .userInitiated) {
            let ctx = ctxPtr.raw
            let mdl = mdlPtr.raw

            // clear KV cache so prior generate() calls don't bleed in
            llama_kv_cache_clear(ctx)

            // parse GBNF grammar if provided
            var grammarPtr: OpaquePointer? = nil
            if let grammarStr = grammar {
                var parser = GBNFParser()
                grammarPtr = parser.parse(grammarStr)
                print("DEBUG : grammar parsed = \(grammarPtr != nil)")
            }
            defer { if let g = grammarPtr { llama_grammar_free(g) } }

            // tokenize prompt
            let maxTokens = 4096
            var tokens = [llama_token](repeating: 0, count: maxTokens)
            let promptCStr = prompt.cString(using: .utf8)!
            let nTokens = llama_tokenize(mdl, promptCStr, Int32(promptCStr.count - 1), &tokens, Int32(maxTokens), true, false)

            if nTokens < 0 {
                throw LLMError.tokenizeFailed
            }

            // set up batch
            var batch = llama_batch_init(Int32(nTokens), 0, 1)
            defer { llama_batch_free(batch) }

            for idx in 0 ..< Int(nTokens) {
                batch.token[idx] = tokens[idx]
                batch.pos[idx] = Int32(idx)
                batch.n_seq_id[idx] = 1
                batch.seq_id[idx]![0] = 0
                batch.logits[idx] = 0
            }
            batch.logits[Int(nTokens) - 1] = 1
            batch.n_tokens = nTokens

            if llama_decode(ctx, batch) != 0 {
                throw LLMError.decodeFailed
            }

            // sampling via low-level C API (StanfordBDHG v0.3.3 doesn't expose sampler chain)
            let nVocabInt = Int(llama_n_vocab(mdl))
            let eosToken = llama_token_eos(mdl)
            let eotToken = llama_token_eot(mdl)
            var output = ""
            var nCurr = Int(nTokens)
            let maxGenTokens = 768
            print("DEBUG : prompt tokens = \(nTokens), max gen = \(maxGenTokens)")
            var piece = [CChar](repeating: 0, count: 32)

            // stable pointer for candidate array (reused each iteration)
            let candidatesPtr = UnsafeMutablePointer<llama_token_data>.allocate(capacity: nVocabInt)
            defer { candidatesPtr.deallocate() }

            // first call uses last token of prompt batch; subsequent calls use batch index 0
            var logitIdx = Int32(nTokens - 1)

            while nCurr < Int(nTokens) + maxGenTokens {
                guard let logitsPtr = llama_get_logits_ith(ctx, logitIdx) else {
                    break
                }

                // fill candidates from logits
                for idx in 0 ..< nVocabInt {
                    candidatesPtr[idx] = llama_token_data(id: Int32(idx), logit: logitsPtr[idx], p: 0)
                }
                var candidatesArray = llama_token_data_array(
                    data: candidatesPtr,
                    size: nVocabInt,
                    sorted: false
                )

                // grammar first (zeros out tokens that violate grammar), then temp + top-p
                if let g = grammarPtr {
                    llama_sample_grammar(ctx, &candidatesArray, g)
                }
                llama_sample_temp(ctx, &candidatesArray, 0.4)
                llama_sample_top_p(ctx, &candidatesArray, 0.9, 1)
                let nextToken = llama_sample_token(ctx, &candidatesArray)

                if nextToken == eosToken || nextToken == eotToken {
                    print("DEBUG : stopped at EOS/EOT after \(nCurr - Int(nTokens)) tokens")
                    break
                }

                // advance grammar state
                if let g = grammarPtr {
                    llama_grammar_accept_token(ctx, g, nextToken)
                }

                let pieceLen = llama_token_to_piece(mdl, nextToken, &piece, Int32(piece.count), false)
                if pieceLen > 0 {
                    let s = String(bytes: piece.prefix(Int(pieceLen)).map { UInt8(bitPattern: $0) }, encoding: .utf8) ?? ""
                    output += s
                }

                // decode next token
                var nextBatch = llama_batch_init(1, 0, 1)
                defer { llama_batch_free(nextBatch) }

                nextBatch.token[0] = nextToken
                nextBatch.pos[0] = Int32(nCurr)
                nextBatch.n_seq_id[0] = 1
                nextBatch.seq_id[0]![0] = 0
                nextBatch.logits[0] = 1
                nextBatch.n_tokens = 1

                if llama_decode(ctx, nextBatch) != 0 {
                    print("Error: llama_decode failed at token \(nCurr)")
                    break
                }

                logitIdx = 0  // all subsequent decodes are single-token batches
                nCurr += 1
            }

            let genCount = nCurr - Int(nTokens)
            if genCount >= maxGenTokens {
                print("DEBUG : hit maxGenTokens limit (\(maxGenTokens))")
            }
            // strip special token text (e.g. <|end|>, <|endoftext|>) from output
            output = output.replacingOccurrences(of: "<\\|[^|]+\\|>", with: "", options: .regularExpression)
            output = output.trimmingCharacters(in: .whitespacesAndNewlines)

            print("DEBUG : generated \(genCount) tokens, output length = \(output.count) chars")
            print("DEBUG : raw output = \(output.prefix(500))")

            return output
        }.value
    }

    func unloadModel() {
        if let ctx = context {
            llama_free(ctx)
        }
        if let mdl = model {
            llama_free_model(mdl)
        }
        context = nil
        model = nil
        modelPath = nil
        isModelLoaded = false
    }
}

enum LLMError: Error, LocalizedError {
    case modelNotLoaded
    case modelLoadFailed(String)
    case contextInitFailed
    case tokenizeFailed
    case decodeFailed

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "LLM model is not loaded"
        case .modelLoadFailed(let msg):
            return "Failed to load model: \(msg)"
        case .contextInitFailed:
            return "Failed to initialize llama context"
        case .tokenizeFailed:
            return "Failed to tokenize prompt"
        case .decodeFailed:
            return "llama_decode returned an error"
        }
    }
}
