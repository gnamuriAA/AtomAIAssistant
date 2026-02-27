//
//  LLGenerationModel.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 27/02/26.
//

import Foundation

final class LLGenerationModel {
    private(set) var appleChatProvider: ChatProvider
    private(set) var azureChatProvider: ChatProvider
    private(set) var qaService: QAService?

    init(qaService: QAService) {
        appleChatProvider = AppleLLMClient(instruction: PromptBuilder.systemPrompt())
        azureChatProvider = AzureLLMClient(endpoint: URL(string: "https://aa-genai-train-foundry.cognitiveservices.azure.com/")!, deployment: "gpt-4o", apiKey: azureAPIKey, apiVersion: "2024-12-01-preview")
        self.qaService = qaService
    }

    func answerFromLocal(for query: String, history: [ChatTurn]) async -> String {
        guard let qaService else {
            return "QA Service not ready yet. Please wait a moment and try again."
        }
        var triedWithAppleLLM = true
        do {
            var response = try await qaService.answer(query, chatClient: appleChatProvider, history: history)
            if response.llmResponse == "Apple Intelligence is not available on this device or region." {
                triedWithAppleLLM = false
                response = try  await qaService.answer(query, chatClient: azureChatProvider, history: history)
                
            }
            return response.llmResponse
        } catch {
            if triedWithAppleLLM {
                do {
                    let response = try  await qaService.answer(query, chatClient: azureChatProvider, history: history)
                    return response.llmResponse
                } catch {
                    guard let rawResults = try? await qaService.getRawAnswers(question: query) else {
                        return "Failed to load answer vectors chunks from local store. Please try again later."
                    }
                    let filteredRecords = rawResults.filter { $0.finalScore >= 0.88 }.sorted(by: { $0.finalScore > $1.finalScore })
                    let textToReturn = filteredRecords.map { $0.record.embeddingText }.joined(separator: "\n")
                    let normalizedText = NormaliseText.normalizeText(textToReturn)
                    return textToReturn.isEmpty ? "No relevant answers found." : normalizedText
                }
            }
        }
        return "Failed to load answer from both Apple Intelligence and Azure OpenAI. Please try again later."
    }
}
