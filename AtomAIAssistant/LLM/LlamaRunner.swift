//
//  LlamaRunner.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 13/02/26.
//

import Foundation

final class LlamaRunner {
    private var model: OpaquePointer?
    private var ctx: OpaquePointer?
    private var vocab: OpaquePointer?

    private var cancelled = false
    private let lock = NSLock()
    private var pos: Int32 = 0

    deinit { unload() }

    // MARK: - Lifecycle

    func load(modelURL: URL,
              contextTokens: UInt32 = 2048,
              threads: Int32 = 6) throws {

        unload() // allow reload safely

        llama_backend_init()

        // Model
        var mparams = llama_model_default_params()
        // Most recent llama.cpp builds auto-pick Metal if compiled with LLAMA_METAL=ON.
        // Some builds expose gpu layers; if present in your headers you can set it here.

        guard let m = llama_load_model_from_file(modelURL.path, mparams) else {
            throw NSError(domain: "LlamaRunner", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to load model: \(modelURL.lastPathComponent)"])
        }
        model = m

        // Vocab handle (newer API)
        vocab = llama_model_get_vocab(m)

        // Context
        var cparams = llama_context_default_params()
        cparams.n_ctx = contextTokens
        cparams.n_threads = threads
        cparams.n_threads_batch = threads

        guard let c = llama_new_context_with_model(m, cparams) else {
            throw NSError(domain: "LlamaRunner", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to create llama context"])
        }
        ctx = c
    }

    func unload() {
        lock.lock()
        defer { lock.unlock() }

        cancelled = true

        if let c = ctx { llama_free(c) }
        if let m = model { llama_free_model(m) }

        ctx = nil
        model = nil
        vocab = nil

        llama_backend_free()
    }

    func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }

    // MARK: - Generation

    struct GenerationConfig {
        var maxNewTokens: Int = 256
        var temperature: Float = 0.7
        var topP: Float = 0.9
        var topK: Int32 = 40
        var repeatPenalty: Float = 1.05
    }

    /// Streams text pieces as they are generated.
    func generate(prompt: String,
                  config: GenerationConfig = .init(),
                  onText: @escaping (String) -> Void) throws {

        guard let ctx, let vocab else {
            throw NSError(domain: "LlamaRunner", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "Model not loaded"])
        }

        lock.lock()
        cancelled = false
        lock.unlock()

        // 1) Tokenize prompt
        var tokenBuf = [llama_token](repeating: 0, count: 16_384)
        let promptBytes = Int32(prompt.utf8.count)

        let nPrompt = llama_tokenize(
            vocab,
            prompt,
            promptBytes,
            &tokenBuf,
            Int32(tokenBuf.count),
            true,   // add_bos
            false   // special
        )

        if nPrompt <= 0 {
            throw NSError(domain: "LlamaRunner", code: 4,
                          userInfo: [NSLocalizedDescriptionKey: "Tokenization failed"])
        }

        var tokens = Array(tokenBuf.prefix(Int(nPrompt)))

        // 2) Evaluate prompt tokens
        try eval(tokens: tokens)

        // 3) Build sampler chain
        let sampler = llama_sampler_chain_init(llama_sampler_chain_default_params())
        defer { llama_sampler_free(sampler) }

        // Repeat penalty (if available in your version)
        // Some llama.cpp versions have llama_sampler_init_penalties(...) with more args.
        // If this doesn't compile for your headers, remove it.
        llama_sampler_chain_add(sampler, llama_sampler_init_top_k(config.topK))
        llama_sampler_chain_add(sampler, llama_sampler_init_top_p(config.topP, 1))
        llama_sampler_chain_add(sampler, llama_sampler_init_temp(config.temperature))
        llama_sampler_chain_add(sampler, llama_sampler_init_dist(0))

        // 4) Generate loop
        for _ in 0..<config.maxNewTokens {
            if isCancelled() { break }

            let t = llama_sampler_sample(sampler, ctx, -1)

            if t == llama_token_eos(vocab) { break }

            if let piece = tokenToString(vocab: vocab, token: t) {
                onText(piece)
            }

            try eval(tokens: [t])
        }
    }

    private func isCancelled() -> Bool {
        lock.lock()
        let c = cancelled
        lock.unlock()
        return c
    }

    /// Decode/evaluate tokens
    private func eval(tokens: [llama_token]) throws {
        guard let ctx else { return }

        var batch = llama_batch_init(Int32(tokens.count), 0, 1)
        defer { llama_batch_free(batch) }

        batch.n_tokens = Int32(tokens.count)

        for i in 0..<tokens.count {
            batch.token[i] = tokens[i]
            batch.pos[i] = pos + Int32(i)
            batch.n_seq_id[i] = 1
            batch.seq_id[i]![0] = 0
            batch.logits[i] = (i == tokens.count - 1) ? 1 : 0
        }

        let rc = llama_decode(ctx, batch)
        if rc != 0 {
            throw NSError(domain: "LlamaRunner", code: 10,
                          userInfo: [NSLocalizedDescriptionKey: "llama_decode failed: \(rc)"])
        }

        pos += Int32(tokens.count)
    }

    private func tokenToString(vocab: OpaquePointer, token: llama_token) -> String? {
        // dynamic buffer (tokens can exceed 256 sometimes)
        var buf = [CChar](repeating: 0, count: 4096)
        let n = llama_token_to_piece(vocab, token, &buf, Int32(buf.count), 0, false)
        guard n > 0 else { return nil }
        return String(cString: buf)
    }
}

enum QwenPrompt {
    static func chat(system: String, user: String) -> String {
        // Qwen chat/instruct style (works well for Qwen-family GGUF Instruct models)
        return """
        <|im_start|>system
        \(system)
        <|im_end|>
        <|im_start|>user
        \(user)
        <|im_end|>
        <|im_start|>assistant
        """
    }
}
