//
//  MMRReranker.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 10/02/26.
//

import Foundation
import Accelerate

final class MMRReranker: Reranker {
    private let base: HybridReranker
    private let lambda: Float

    init(base: HybridReranker, lambda: Float = 0.75) {
        self.base = base
        self.lambda = lambda
    }

    func rerank(query: String, candidates: [RetrievedChunk], topK: Int) -> [RetrievedChunk] {
        // First do hybrid scoring
        var scored = base.rerank(query: query, candidates: candidates, topK: candidates.count)

        guard scored.count > topK else { return scored }

        var selected: [RetrievedChunk] = []
        selected.reserveCapacity(topK)

        // Greedy MMR selection
        while selected.count < topK && !scored.isEmpty {
            var bestIndex = 0
            var bestMMR: Float = -Float.greatestFiniteMagnitude

            for i in scored.indices {
                let cand = scored[i]
                let rel = cand.finalScore

                var redundancy: Float = 0
                if !selected.isEmpty {
                    // max similarity to selected set
                    redundancy = selected.map { cosineFast(cand.embedding, $0.embedding) }.max() ?? 0
                }

                let mmr = lambda * rel - (1 - lambda) * redundancy
                if mmr > bestMMR {
                    bestMMR = mmr
                    bestIndex = i
                }
            }

            selected.append(scored.remove(at: bestIndex))
        }

        return selected
    }

    // Fast cosine using Accelerate (assumes non-empty same length)
    private func cosineFast(_ a: [Float], _ b: [Float]) -> Float {
        var dot: Float = 0
        vDSP_dotpr(a, 1, b, 1, &dot, vDSP_Length(a.count))
        var a2: Float = 0
        var b2: Float = 0
        vDSP_svesq(a, 1, &a2, vDSP_Length(a.count))
        vDSP_svesq(b, 1, &b2, vDSP_Length(b.count))
        let denom = sqrt(a2) * sqrt(b2)
        return denom > 0 ? dot / denom : 0
    }
}
