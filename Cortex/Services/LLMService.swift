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
class LLMService: LLMServiceProtocol {

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
ws ::= [ \\t\\n]*
"""

    func loadModel(from path: String) async throws {
        let result: (model: Ptr, ctx: Ptr) = try await Task.detached(priority: .userInitiated) {
            var modelParams = llama_model_default_params()
            modelParams.n_gpu_layers = 99

            guard let loadedModel = llama_load_model_from_file(path, modelParams) else {
                throw LLMError.modelLoadFailed("could not load model from \(path)")
            }

            var ctxParams = llama_context_default_params()
            ctxParams.n_ctx = 2048
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

            // tokenize prompt
            let maxTokens = 2048
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

            // set up sampler chain
            let sparams = llama_sampler_chain_default_params()
            let sampler = llama_sampler_chain_init(sparams)
            defer { llama_sampler_free(sampler) }

            llama_sampler_chain_add(sampler, llama_sampler_init_temp(0.8))
            llama_sampler_chain_add(sampler, llama_sampler_init_dist(42))

            // apply grammar if provided
            if let grammarStr = grammar {
                let grammarCStr = grammarStr.cString(using: .utf8)!
                let rootName = "root".cString(using: .utf8)!
                if let gs = llama_sampler_init_grammar(mdl, grammarCStr, rootName) {
                    llama_sampler_chain_add(sampler, gs)
                }
            }

            let eosToken = llama_token_eos(mdl)
            var output = ""
            var nCurr = Int(nTokens)
            let maxGenTokens = 1024
            var piece = [CChar](repeating: 0, count: 32)

            while nCurr < Int(nTokens) + maxGenTokens {
                let nextToken = llama_sampler_sample(sampler, ctx, Int32(nCurr - 1))

                if nextToken == eosToken { break }

                let pieceLen = llama_token_to_piece(mdl, nextToken, &piece, Int32(piece.count), 0, false)
                if pieceLen > 0 {
                    let s = String(bytes: piece.prefix(Int(pieceLen)).map { UInt8(bitPattern: $0) }, encoding: .utf8) ?? ""
                    output += s
                }

                llama_sampler_accept(sampler, nextToken)

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

                nCurr += 1
            }

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
