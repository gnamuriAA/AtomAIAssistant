//
//  MultiPDFEmbeddingPipeLine.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 08/02/26.
//

import Foundation
import SwiftData

protocol MarkdownChunkingProvider {
    func chunkMarkdown(at url: URL, docName: String) async throws -> [EmbedChunk]
}

final class MultiPDFEmbeddingPipeLine {
    private let chunker: MarkdownChunkingProvider
    private let indexer: ChunkEmbeddingIndexer

    init(chunker: MarkdownChunkingProvider, indexer: ChunkEmbeddingIndexer) {
        self.chunker = chunker
        self.indexer = indexer
    }

    @MainActor
    func processAllPDFs(pdfURLs: [URL],
                        batchSize: Int = 16,
                        maxTextChars: Int = 1800,
                        onDocStart: ((String) -> Void)? = nil,
                        onDocDone: ((String, Int) -> Void)? = nil,
                        onProgress: ((DetailedEmbeddingProgress) -> Void)? = nil) async throws {
        for url in pdfURLs {
            let docName = makeDocName(from: url)
            onDocStart?(docName)
            if !indexer.hasAlreadyStoredEmbedding(for: docName) {
                let embedChunks = try await chunker.chunkMarkdown(at: url, docName: docName)
                
                try await indexer.indexEmbedChunks(embedChunks: embedChunks, batchSize: batchSize, maxTextChars: maxTextChars, onProgress: onProgress)
            }
        }
    }

    private func makeDocName(from url: URL) -> String {
        return url.deletingPathExtension().lastPathComponent
    }
}

final class PDFMarkdownChunkingProvider: MarkdownChunkingProvider {
    func chunkMarkdown(at url: URL, docName: String) async throws -> [EmbedChunk] {
        let markdownString = try String(contentsOf: url, encoding: .utf8)
        let parsedChunks = MarkdownToChunks.generateChunks(from: markdownString, docName: docName)
        let parsedChunker = ParsedChunker()
        return parsedChunker.makeEmbedChunks(from: parsedChunks)
    }
}
