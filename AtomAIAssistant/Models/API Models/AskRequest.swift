//
//  AskRequest.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 16/02/26.
//

import Foundation

struct AskRequest: Codable {
    let query: String
    let session_id: String
    let top_k: Int?
    let top_n: Int?
    
    init(query: String, sessionId: String, topK: Int = 20, topN: Int = 5) {
        self.query = query
        self.session_id = sessionId
        self.top_k = topK
        self.top_n = topN
    }
}

struct AskResponse: Codable {
    let answer: String
    let sources: [SourceReference]
    let session_id: String

    var formattedString: String {
        var formattedString: String = answer
        let fileName = sources.map { "\($0.metadata.file_name)" }
        if !fileName.isEmpty {
            formattedString += "\n\nSources: \(fileName)"
        }

        let pageNumber = sources.compactMap { $0.metadata.page_number }
        if !pageNumber.isEmpty {
            var pageNumbers = "Found in page(s): "
            pageNumbers += pageNumber.map { "\($0) " }.joined(separator: ", ")
            formattedString += "\n\n\(pageNumbers)"
        }

        return formattedString
    }
}

struct SourceReference: Codable {
    let text: String
    let source_type: String
    let metadata: MetaData
    let relevance_score: Double
    
    var score: Double {
        relevance_score * 100
    }
}

struct MetaData: Codable {
    let source_type: String
    let file_name: String
    let segment_index: Int?
    let start_time: Double?
    let end_time: Double?
    let page_number: Int?
    let content_type: String?
}
