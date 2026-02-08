//
//  AppleEmbeddingClient.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 08/02/26.
//

import NaturalLanguage

final class AppleEmbeddingClient: EmbeddingProvider {
    func embed(texts: [String]) async throws -> [[Float]] {
        guard let embedder = NLEmbedding.sentenceEmbedding(for: .english) else {
            throw NSError(domain: "Failed to create NLEmbedding", code: 1001)
        }
        var embeddes = [[Float]]()
        for text in texts {
            guard let embeds = embedder.vector(for: text) else {
                continue
            }
            embeddes.append(embeds.map({ Float($0) }))
        }
        return embeddes
    }

    func embed(text: String) async throws -> [Float] {
        let array = try await embed(texts: [text])
        return array[0]
    }
}
