//
//  RetrieverModel.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 08/02/26.
//

import Accelerate
import Foundation
import SwiftData

struct RetrievedChunk: Identifiable {
    let id = UUID()
    let record: ChunkRecord
    let score: Float
}

class RetrieverModel {
    private var modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func cosineSimilarityAccelerate(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else {
            return -1
        }

        var dot: Float = 0
        vDSP_dotpr(a, 1, b, 1, &dot, vDSP_Length(a.count))
        
        var a2: Float = 0
        vDSP_dotpr(a, 1, a, 1, &a2, vDSP_Length(a.count))

        var b2: Float = 0
        vDSP_dotpr(b, 1, b, 1, &b2, vDSP_Length(b.count))

        let denom = sqrt(a2) * sqrt(b2)
        return denom == 0 ? -1 : dot / denom
    }

    @MainActor func topK(for questionEmbedding: [Float], k: Int = 6) throws -> [RetrievedChunk] {
        let predicate: Predicate<ChunkRecord>?
//        if let selectedDoc {
//            predicate = #Predicate { $0.embeddings != nil && $0.docName == selectedDoc }
//        } else {
            predicate = #Predicate { $0.embeddings != nil }
//        }
        
        let desc = FetchDescriptor<ChunkRecord>(predicate: predicate)

        let all = try modelContext.fetch(desc)
        guard !all.isEmpty else { return [] }
        
        var scored: [RetrievedChunk] = []
        scored.reserveCapacity(all.count)

        for r in all {
            guard let data = r.embeddings else { continue }
            let vec = dataToFloats(data)
            let score = cosineSimilarityAccelerate(questionEmbedding, vec)
            print("text \(r.embeddingText) and score: \(score)")
            scored.append(RetrievedChunk(record: r, score: score))
        }
        
        scored.sort { $0.score > $1.score }
        return Array(scored.prefix(k))
    }
}
