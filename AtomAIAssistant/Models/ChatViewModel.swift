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
    private(set) var azureChatProvider: ChatProvider
    @Published var messages: [ChatMessage] = [
        .init(role: .assistant, text: "Ask me anything about the uploaded documents!")
    ]
    @Published var hasUpdatedQAService: Bool = false
    @Published var showImporter = false
    @Published var selectedPDF: URL?
    @Published var isUploading: Bool = false
    
    private let azureClient = AzureDocumentIntelligenceClient(endpoint: "https://aa-genai-train-foundry.cognitiveservices.azure.com/", apiKey: azureAPIKey)

    init() {
        embeddingClient = AppleEmbeddingClient()
        azureChatProvider = AppleLLMClient(instruction: PromptBuilder.systemPrompt())
        chatProvider = AzureLLMClient(endpoint: URL(string: "https://aa-genai-train-foundry.cognitiveservices.azure.com/")!, deployment: "gpt-4o", apiKey: azureAPIKey, apiVersion: "2024-12-01-preview")
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

    func upload(_ url: URL, progress: @escaping (DetailedEmbeddingProgress) -> Void) async throws {
        isUploading = true

        Task {
            do {
                let didStart = url.startAccessingSecurityScopedResource()
                defer { if didStart { url.stopAccessingSecurityScopedResource() } }
                
                let md = try await azureClient.analyzeToMarkdown(fileURL: url, contentType: "application/pdf")
                let mdURL = try azureClient.saveMarkdown(md, fileName: "\(selectedPDF?.lastPathComponent.replacingOccurrences(of: ".pdf", with: "") ?? "NewDocument").md")
                try await ragGenerationModel.generateEmbedding(for: mdURL, progress: progress)
                await MainActor.run {
                    isUploading = false
                }
            } catch {
                await MainActor.run {
                    isUploading = false
                }
            }
        }
    }

    func answer(for query: String, history: [ChatTurn]) async  -> String {
        guard let qaService else {
            return "QA Service not ready yet. Please wait a moment and try again."
        }
        var triedWithAppleLLM = true
        do {
            var response = try await qaService.answer(query, chatClient: chatProvider, history: history)
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
                    let filteredRecords = rawResults.filter { $0.finalScore >= 0.8 }
                    let textToReturn = filteredRecords.map { $0.record.embeddingText }.joined(separator: "\n\n")
                    return textToReturn.isEmpty ? "No relevant answers found." : textToReturn
                }
            }
        }
        return "Failed to load answer from both Apple Intelligence and Azure OpenAI. Please try again later."
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

extension ChatMessage {
    func toChatTurn() -> ChatTurn {
        .init(role: role, text: text)
    }
}

let azureAPIKey = ""
