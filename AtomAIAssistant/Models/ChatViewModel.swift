//
//  ChatViewModel.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 08/02/26.
//

import Foundation
import SwiftData

final class ChatViewModel {
    private var ragGenerationModel: RAGGenerationModel = RAGGenerationModel(pdfs: AvailableMarkdown.allCases)
    private var qaService: QAService?
    private var modelContext: ModelContext?
    private let embeddingClient: EmbeddingProvider

    init() {
        embeddingClient = AppleEmbeddingClient()
    }

    func configureContext(modelContext: ModelContext) {
        ragGenerationModel.configureContext(context: modelContext)
        qaService = QAService(modelContext: modelContext, embeddingsClient: embeddingClient)
        self.modelContext = modelContext
    }

    @MainActor
    func generateEmbeddingsAndStoreLocally(progress: @escaping (DetailedEmbeddingProgress) -> Void) async throws {
        try await ragGenerationModel.generateEmbeddings(progress: progress)
    }
}
