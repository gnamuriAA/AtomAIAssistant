//
//  EmbeddingChunk.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 08/02/26.
//

import Foundation

struct EmbeddingChunk: Codable, Hashable {
    let id: String
    let page: Int
    let headerPath: [String]
    let kind: ChunkKind
    let text: String
    
    let sourceIndex: Int
}

enum EmbeddingTextBuilder {
    static func build(from record: ParsedChunk) -> String? {
        switch record.kind {
        case .text:
            guard let text = record.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
            return "\(text)"
        case .tableRow:
            guard let columns = record.columns, !columns.isEmpty, let formattedTableString = record.formattedTableString else { return nil }
            return formattedTableString
        case .notice:
            guard let n = record.notice else { return nil }
            let titlePart = n.title.map { "\($0)" } ?? n.severity.rawValue.capitalized
            return "\(titlePart) (\(n.severity.rawValue)): \(n.message)"
        }
    }
}
