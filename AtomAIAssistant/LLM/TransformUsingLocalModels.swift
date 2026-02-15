//
//  TransformUsingLocalModels.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 14/02/26.
//

import Foundation

struct TransformUsingLocalModels {
    private var appleModel: ChatProvider
    private var llamaModel: ChatProvider

    init(appleModel: ChatProvider, llamaModel: ChatProvider) {
        self.appleModel = appleModel
        self.llamaModel = llamaModel
    }

    func load(query: String, history: [ChatTurn], qaService: QAService) async throws -> (llmResponse: String, rawString: String) {
        var result: (llmResponse: String, rawString: String) = ("", "")
        do {
            result = try await qaService.answer(query, chatClient: appleModel, history: history)
            if result.llmResponse.isEmpty {
                throw NSError(domain: "Apple LLM returned an empty response.", code: 1003, userInfo: nil)
            }
            result.llmResponse += "\n Loaded with Apple Models"
        } catch {
            result = try await qaService.answer(query, chatClient: llamaModel, history: history)
            if result.llmResponse.isEmpty {
                throw NSError(domain: "Llama LLM returned an empty response.", code: 1003, userInfo: nil)
            }
            result.llmResponse += "\n Loaded with Llama Models"
        }
        return result
    }
}
