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
    let vectorScore: Float          // cosine score from stage 1
    let embedding: [Float]          // decoded once, reused
    var finalScore: Float = 0

}

class RetrieverModel {
    private var modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func cosineSimilarityAccelerate(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return -1 }

        var dot: Float = 0
        vDSP_dotpr(a, 1, b, 1, &dot, vDSP_Length(a.count))

        var a2: Float = 0
        var b2: Float = 0
        vDSP_svesq(a, 1, &a2, vDSP_Length(a.count))
        vDSP_svesq(b, 1, &b2, vDSP_Length(b.count))

        let denom = sqrt(a2) * sqrt(b2)
        return denom > 0 ? (dot / denom) : -1
    }
    
    @MainActor
    func topK(for questionEmbedding: [Float], question: String, n: Int = 6) throws -> [RetrievedChunk] {
        let vectorCandidates = try retrieveTopN(for: questionEmbedding, n: 250)
        let lexicalCandidates = try retrieveTopByLexical(question: question, n: 120)
        
        var merged: [Int: RetrievedChunk] = [:]
        for c in vectorCandidates { merged[c.record.persistentModelID.hashValue] = c }
        for c in lexicalCandidates {
            if let existing = merged[c.record.persistentModelID.hashValue] {
                if c.vectorScore > existing.vectorScore {
                    merged[c.record.persistentModelID.hashValue] = c
                }
            } else {
                merged[c.record.persistentModelID.hashValue] = c
            }
        }
        
        let candidates = Array(merged.values)
        
        let hybrid = HybridReranker()
        // Optional diversity:
        let reranker = MMRReranker(base: hybrid, lambda: 0.75)
        
        return reranker.rerank(query: question, candidates: candidates, topK: n)
        
    }
   
    @MainActor
    private func retrieveTopN(for questionEmbedding: [Float], n: Int = 250) throws -> [RetrievedChunk] {
        let predicate: Predicate<ChunkRecord>? = #Predicate { $0.embeddings != nil }
        let desc = FetchDescriptor<ChunkRecord>(predicate: predicate)
        let all = try modelContext.fetch(desc)
        guard !all.isEmpty else { return [] }

        var scored: [RetrievedChunk] = []
        scored.reserveCapacity(all.count)

        for r in all {
            guard let data = r.embeddings else { continue }
            let vec = dataToFloats(data)
            let s = cosineSimilarityAccelerate(questionEmbedding, vec)
            if s.isNaN || s.isInfinite { continue } // skip invalid
            scored.append(RetrievedChunk(record: r, vectorScore: s, embedding: vec))
        }

        scored.sort { $0.vectorScore > $1.vectorScore }
        if scored.count > n { scored = Array(scored.prefix(n)) }
        return scored
    }

    @MainActor
    private func retrieveTopByLexical(question: String, n: Int = 120) throws -> [RetrievedChunk] {
        let desc = FetchDescriptor<ChunkRecord>()
        let all = try modelContext.fetch(desc)
        
        guard !all.isEmpty else { return [] }
        
        let hybrid = HybridReranker()
        let lexical = LexicalScorer()
        
        var tmp: [(ChunkRecord, Float)] = []
        tmp.reserveCapacity(all.count)
        
        for r in all {
            let text = r.embeddingText
            let header = r.headerPath
            let s = lexical.score(query: question, chunkText: text, header: header)
            
            if s >= 0.10 { tmp.append((r, s)) }
        }
        
        tmp.sort { $0.1 > $1.1 }
        
        if tmp.count > n {
            tmp = Array(tmp.prefix(n))
        }

        return tmp.map { RetrievedChunk(record: $0.0, vectorScore: 0, embedding: []) }
    }
}
