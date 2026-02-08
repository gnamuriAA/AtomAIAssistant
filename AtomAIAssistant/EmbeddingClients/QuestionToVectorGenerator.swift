//
//  QuestionToVectorGenerator.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 08/02/26.
//

import Foundation

class QuestionVectorGeneration {
    static func getVector(with client: EmbeddingProvider, question: String) async throws -> [Float] {
        try await client.embed(text: question)
    }
}
