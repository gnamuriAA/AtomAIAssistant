//
//  QAService.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 08/02/26.
//

import SwiftData
import Foundation

final class QAService {
    private let embeddingsClient: EmbeddingProvider
    private let retriever: RetrieverModel

    init(modelContext: ModelContext, embeddingsClient: EmbeddingProvider) {
        self.embeddingsClient = embeddingsClient
        self.retriever = RetrieverModel(modelContext: modelContext)
    }

    func answer(_ question: String, chatClient: ChatProvider) async -> String {
        do {
            // 1.Embed Question
            let qVec = try await QuestionVectorGeneration.getVector(with: embeddingsClient, question: question)
            
            // 2. Retrieve Chunks
            let top = try retriever.topK(for: qVec)
            if top.isEmpty {
                return "Not found in the provided PDFs."
            }
            
            // 3. Build Prompt
            let system = PromptBuilder.systemPrompt()
            let user = PromptBuilder.userPrompt(question: question, chunks: top)
            
            // 4. LLM Answer
            let answer = try await chatClient.chat(system: system, user: user)
            return answer.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }
}

