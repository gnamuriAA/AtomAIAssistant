//
//  RAGGenerationModel.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 08/02/26.
//

import Foundation
import SwiftData

enum AvailableMarkdown: String, CaseIterable {
    case ipad_accessories

    var url: URL {
        Bundle.main.url(forResource: self.rawValue, withExtension: "md")!
    }
}

final class RAGGenerationModel {
    private var modelContext: ModelContext?
    private var multiPDFEmbeddingPipeline: MultiPDFEmbeddingPipeLine?
    private let embeddingClient: EmbeddingProvider = AppleEmbeddingClient()
    private var pdfURLs: [AvailableMarkdown]

    init(pdfs: [AvailableMarkdown], multiPDFEmbeddingPipeline: MultiPDFEmbeddingPipeLine? = nil) {
        self.pdfURLs = pdfs
        self.multiPDFEmbeddingPipeline = multiPDFEmbeddingPipeline
    }

    @MainActor
    func generateEmbeddings(progress: @escaping (DetailedEmbeddingProgress) -> Void) async throws {
        let urls = AvailableMarkdown.allCases.map { $0.url }
        try await multiPDFEmbeddingPipeline?.processAllPDFs(pdfURLs: urls, onProgress: progress)
    }

    func configureContext(context: ModelContext) {
        self.modelContext = context
    }
}
