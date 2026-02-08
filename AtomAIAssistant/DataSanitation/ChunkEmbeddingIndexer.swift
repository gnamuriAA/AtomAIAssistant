//
//  ChunkEmbeddingIndexer.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 08/02/26.
//

import Foundation
import SwiftData

protocol EmbeddingProvider {
    func embed(texts: [String]) async throws -> [[Float]]
    func embed(text: String) async throws -> [Float]
}

final class ChunkEmbeddingIndexer {
    private let client: EmbeddingProvider
    private let modelContext: ModelContext

    init(client: EmbeddingProvider, modelContext: ModelContext) {
        self.client = client
        self.modelContext = modelContext
    }

    func hasAlreadyStoredEmbedding(for docName: String) -> Bool {
        let predicate: Predicate<ChunkRecord>? = #Predicate { $0.embeddings != nil && $0.docName == docName }
        
        let desc = FetchDescriptor<ChunkRecord>(predicate: predicate)
        do {
            let all = try modelContext.fetch(desc)
            return all.count > 0
        } catch {
            print("Failed to fetch data to check if already stored or not")
        }
        return false
    }
    
    @MainActor
    func index(parsedChunks: [ParsedChunk], batchSize: Int = 16, maxTextChars: Int = 1800, onProgress: ((DetailedEmbeddingProgress) -> Void)? = nil) async throws {
        var records = [ChunkRecord]()
        records.reserveCapacity(parsedChunks.count)
        
        var perPageCounter: [String: [Int: Int]] = [:]
        
        for (idx, c) in parsedChunks.enumerated() {
            guard let full = EmbeddingTextBuilder.build(from: c) else { continue }
            let trimmed = String(full.prefix(maxTextChars))
            
            var pageMap = perPageCounter[c.docName, default: [:]]
            let pageIndex = pageMap[c.page, default: 1]
            pageMap[c.page] = pageIndex + 1
            perPageCounter[c.docName] = pageMap
            
            let header = c.headerPath.joined(separator: " / ")
            
            let rec = ChunkRecord(docName: c.docName,
                                  pageNumber: c.page,
                                  chunkIndexOnPage: pageIndex,
                                  kindRaw: c.kind.rawValue,
                                  headerPath: header,
                                  embeddingText: trimmed)
            modelContext.insert(rec)
            records.append(rec)
            
            if idx % 10 == 0 || idx == parsedChunks.count - 1 {
                onProgress?(
                    DetailedEmbeddingProgress(phase: .inserting,
                                              completed: idx + 1,
                                              total: parsedChunks.count,
                                              docName: c.docName,
                                              pageNumber: c.page,
                                              chunkIndexOnPage: pageIndex,
                                              batchStart: nil, batchEnd: nil, batchSize: nil)
                )
            }
        }
        
        onProgress?(
            DetailedEmbeddingProgress(phase: .saving,
                                      completed: records.count,
                                      total: records.count,
                                      docName: records.last?.docName,
                                      pageNumber: records.last?.pageNumber,
                                      chunkIndexOnPage: records.last?.chunkIndexOnPage,
                                      batchStart: nil, batchEnd: nil, batchSize: nil)
        )
        try modelContext.save()
        
        var completed = 0
        var i = 0
        
        while i < records.count {
            let end = min(i + batchSize, records.count)
            let batch = Array(records[i..<end])
            let inputs = batch.map(\.embeddingText)
            
            let first = batch.first
            onProgress?(
                DetailedEmbeddingProgress(phase: .embedding,
                                          completed: completed,
                                          total: records.count,
                                          docName: first?.docName,
                                          pageNumber: first?.pageNumber,
                                          chunkIndexOnPage: first?.chunkIndexOnPage,
                                          batchStart: i, batchEnd: end, batchSize: batch.count)
            )
            let vectors: [[Float]] = try await Task.detached(priority: .userInitiated) {
                try await self.client.embed(texts: inputs)
            }.value
            
            guard vectors.count == inputs.count else {
                throw NSError(domain: "ChunkEmbeddingIndexer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mismatch in embeddings count"])
            }
            guard vectors.allSatisfy({!$0.isEmpty}) else {
                throw NSError(domain: "ChunkEmbeddingIndexer", code: 2, userInfo: [NSLocalizedDescriptionKey: "Empty embeddings"])
            }
            for j in 0..<batch.count {
                let rec = batch[j]
                let vec = vectors[j]
                rec.embeddings = floatsToData(vec)
            }
            // add progress for .saving
            onProgress?(
                DetailedEmbeddingProgress(phase: .saving,
                                          completed: completed,
                                          total: records.count,
                                          docName: first?.docName,
                                          pageNumber: first?.pageNumber,
                                          chunkIndexOnPage: first?.chunkIndexOnPage,
                                          batchStart: i, batchEnd: end, batchSize: batch.count)
            )
            try modelContext.save()
            completed += batch.count
            onProgress?(
                DetailedEmbeddingProgress(phase: .saving,
                                          completed: completed,
                                          total: records.count,
                                          docName: first?.docName,
                                          pageNumber: first?.pageNumber,
                                          chunkIndexOnPage: first?.chunkIndexOnPage,
                                          batchStart: i, batchEnd: end, batchSize: batch.count)
            )
            i = end
        }
        onProgress?(
            DetailedEmbeddingProgress(phase: .done,
                                      completed: records.count,
                                      total: records.count,
                                      docName: nil,
                                      pageNumber: nil,
                                      chunkIndexOnPage: nil,
                                      batchStart: nil, batchEnd: nil, batchSize: nil)
        )
    }
}
fileprivate func floatsToData(_ floats: [Float]) -> Data {
    floats.withUnsafeBufferPointer { buffer in
        Data(buffer: buffer)
    }
}

func dataToFloats(_ data: Data) -> [Float] {
    let count = data.count / MemoryLayout<Float>.size
    return data.withUnsafeBytes { rawPtr in
        let ptr = rawPtr.bindMemory(to: Float.self)
        return Array(ptr[0..<count])
    }
}
