//
//  RetrievalReranker.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 10/02/26.
//

import NaturalLanguage
import Foundation

protocol Reranker {
    func rerank(query: String, candidates: [RetrievedChunk], topK: Int) -> [RetrievedChunk]
}

struct SimpleTokenizer {
    private let tokenizer = NLTokenizer(unit: .word)

    func tokens(_ text: String) -> [String] {
        let lower = text.lowercased()
        tokenizer.string = lower

        var out: [String] = []
        tokenizer.enumerateTokens(in: lower.startIndex..<lower.endIndex) { range, _ in
            let t = String(lower[range])
                .trimmingCharacters(in: .punctuationCharacters.union(.whitespacesAndNewlines))
            if t.count >= 2 { out.append(t) }
            return true
        }
        return out
    }
}

struct LexicalScorer {
    private let tok = SimpleTokenizer()

    func score(query: String, chunkText: String, header: String? = nil) -> Float {
        let qTokens = tok.tokens(query)
        let cTokens = tok.tokens(chunkText)

        if qTokens.isEmpty || cTokens.isEmpty { return 0 }

        let qSet = Set(qTokens)
        let cSet = Set(cTokens)

        let overlap = Float(qSet.intersection(cSet).count)
        let recall = overlap / Float(max(qSet.count, 1))          // how much of query is covered
        let precision = overlap / Float(max(cSet.count, 1))       // how “focused” chunk is

        // basic f-score-ish blend
        let base = (2 * precision * recall) / max(precision + recall, 1e-6)

        // phrase bonus (quick heuristic)
        let qLower = query.lowercased()
        let cLower = chunkText.lowercased()
        let phraseBonus: Float = cLower.contains(qLower) && qLower.count >= 8 ? 0.15 : 0

        // header bonus
        var headerBonus: Float = 0
        if let header = header?.lowercased(), !header.isEmpty {
            let hTokens = Set(tok.tokens(header))
            let hOverlap = Float(qSet.intersection(hTokens).count)
            headerBonus = min(0.20, 0.05 * hOverlap)
        }

        return min(1.0, base + phraseBonus + headerBonus)
    }
}

func minMaxNormalize(_ xs: [Float]) -> [Float] {
    guard let minV = xs.min(), let maxV = xs.max(), maxV > minV else {
        return Array(repeating: 0.5, count: xs.count) // all equal
    }
    return xs.map { ($0 - minV) / (maxV - minV) }
}

final class HybridReranker: Reranker {
    private let lexical = LexicalScorer()

    // tune these
    var wVector: Float = 0.65
    var wLexical: Float = 0.30
    var wMeta: Float = 0.05

    func rerank(query: String, candidates: [RetrievedChunk], topK: Int) -> [RetrievedChunk] {
        guard !candidates.isEmpty else { return [] }

        // 1) compute lexical + meta
        let vecScores = candidates.map { $0.vectorScore }
        let vecNorm = minMaxNormalize(vecScores)

        var lexScores: [Float] = []
        lexScores.reserveCapacity(candidates.count)

        var metaScores: [Float] = []
        metaScores.reserveCapacity(candidates.count)

        for c in candidates {
            // Adjust these fields to your ChunkRecord schema:
            let text = c.record.embeddingText
            let header = c.record.headerPath
            let lex = lexical.score(query: query, chunkText: text, header: header)
            lexScores.append(lex)

            // Example metadata boosts:
            var meta: Float = 0
            if !header.isEmpty, queryMatchesHeaderTokens(query: query, headerPath: header) {
                meta += 0.10
            }
            // If you have pageNumber, docId, etc., add more signals:
            // meta += ...
            metaScores.append(min(1.0, meta))
        }

        let lexNorm = minMaxNormalize(lexScores)
        let metaNorm = minMaxNormalize(metaScores)

        // 2) combine into finalScore
        var out = candidates
        for i in out.indices {
            out[i].finalScore =
                wVector * vecNorm[i] +
                wLexical * lexNorm[i] +
                wMeta * metaNorm[i]
        }

        out.sort { $0.finalScore > $1.finalScore }
        return Array(out.prefix(topK))
    }

    func queryMatchesHeaderTokens(query: String, headerPath: String) -> Bool {
        let tokenizer = SimpleTokenizer()
        let qTokens = Set(tokenizer.tokens(query))
        
        let segments = headerSegments(from: headerPath)
        for segment in segments {
            let hTokens = Set(tokenizer.tokens(segment))
            if !qTokens.intersection(hTokens).isEmpty {
                return true
            }
        }
        return false
    }

    func headerSegments(from headerPath: String) -> [String] {
        headerPath
            .lowercased()
            .split(separator: "/")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 3 }
    }
}
