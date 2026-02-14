//
//  OllamaLLMClient.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 12/02/26.
//

import Foundation
import Combine

final class OllamaLLMClient: NSObject, ChatProvider, ObservableObject {
    private let runner = LlamaRunner()
    @Published var isGenerating: Bool = false
    @Published var generatedResponse: String = ""

    override init() {
        super.init()
        loadModel()
    }
    
    func loadModel() {
        guard let url = Bundle.main.url(forResource: "Qwen3-1.7B-Q8_0", withExtension: "gguf") else {
            print("Model file not found in bundle.")
            return
        }
        do {
            try runner.load(modelURL: url, contextTokens: 2048, threads: 6)
        } catch {
            print("Failed to load model: \(error.localizedDescription)")
        }
    }

    func chat(system: String, user: String) async throws -> String {
        let prompt = QwenPrompt.llama32Prompt(
                    system: system,
                    user: user)
        return try await withCheckedThrowingContinuation { continuation in
            var result = ""
            do {
                try self.runner.generate(prompt: prompt) { chunk in
                    self.generatedResponse += chunk
                    result += chunk
                }
                continuation.resume(returning: result)
            } catch {
                self.generatedResponse += "\n\nError: \(error.localizedDescription)"
                result += "\n\nError: \(error.localizedDescription)"
                continuation.resume(throwing: error)
            }
        }
//        Task.detached { [weak self] in
//            guard let self else { return }
//            
//            do {
//                try self.runner.generate(prompt: prompt) { chunk in
//                    Task { @MainActor in
//                        self.generatedResponse += chunk
//                    }
//                }
//            } catch {
//                Task { @MainActor in
//                    self.generatedResponse += "\n\nError: \(error.localizedDescription)"
//                }
//            }
//            
//            Task { @MainActor in
//                self.isGenerating = false
//            }
//        }        
    }
}
