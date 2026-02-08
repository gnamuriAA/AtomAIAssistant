//
//  ChatViewModel.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 08/02/26.
//

import Foundation
import SwiftData
import Combine

final class ChatViewModel: ObservableObject {
    private var ragGenerationModel: RAGGenerationModel = RAGGenerationModel(pdfs: AvailableMarkdown.allCases)
    private(set) var qaService: QAService?
    private var modelContext: ModelContext?
    private let embeddingClient: EmbeddingProvider
    private(set) var chatProvider: ChatProvider
    @Published var messages: [ChatMessage] = [
        .init(role: .assistant, text: "Ask me anything about the uploaded documents!")
    ]
    @Published var hasUpdatedQAService: Bool = false

    init() {
        embeddingClient = AppleEmbeddingClient()
        chatProvider = AppleLLMClient(instruction: PromptBuilder.systemPrompt())
    }

    func configureContext(modelContext: ModelContext) {
        qaService = QAService(modelContext: modelContext, embeddingsClient: embeddingClient)
        ragGenerationModel.configureContext(context: modelContext)
        self.modelContext = modelContext
        ragGenerationModel = RAGGenerationModel(pdfs: AvailableMarkdown.allCases, multiPDFEmbeddingPipeline: MultiPDFEmbeddingPipeLine(chunker: PDFMarkdownChunkingProvider(), indexer: ChunkEmbeddingIndexer(client: embeddingClient, modelContext: modelContext)))
        hasUpdatedQAService = true
    }

    @MainActor
    func generateEmbeddingsAndStoreLocally(progress: @escaping (DetailedEmbeddingProgress) -> Void) async throws {
        try await ragGenerationModel.generateEmbeddings(progress: progress)
    }

    func deleteSavedData() throws {
        guard let modelContext else {
            return
        }

        try modelContext.delete(model: ChunkRecord.self)
    }
}

enum ChatRole: String, CaseIterable {
    case user, assistant, system
}

struct ChatMessage: Identifiable, Hashable {
    let id = UUID()
    let role: ChatRole
    let text: String
    let date: Date = Date()
}
