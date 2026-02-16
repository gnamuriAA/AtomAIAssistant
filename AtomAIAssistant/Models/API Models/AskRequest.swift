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
}

struct SourceReference: Codable, Hashable {
    let text: String
    let source_type: String
    let metadata: MetaData
    let relevance_score: Double
    
    var score: Double {
        relevance_score
    }

    var page: Int? {
        metadata.page_number
    }

    var fileName: String {
        metadata.file_name
    }
}

struct MetaData: Codable, Hashable {
    let source_type: String
    let file_name: String
    let segment_index: Int?
    let start_time: Double?
    let end_time: Double?
    let page_number: Int?
    let content_type: String?
}
