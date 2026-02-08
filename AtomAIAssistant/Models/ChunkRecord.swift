//
//  ChunkRecord.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 08/02/26.
//

import Foundation
import SwiftData

@Model
final class ChunkRecord {
    var id: UUID
    var docName: String
    var pageNumber: Int
    var chunkIndexOnPage: Int
    
    var kindRaw: String
    var headerPath: String
    
    var embeddingText: String
    
    var embeddings: Data?

    init(docName: String, pageNumber: Int, chunkIndexOnPage: Int, kindRaw: String, headerPath: String, embeddingText: String, embeddings: Data? = nil) {
        self.id = UUID()
        self.docName = docName
        self.pageNumber = pageNumber
        self.chunkIndexOnPage = chunkIndexOnPage
        self.kindRaw = kindRaw
        self.headerPath = headerPath
        self.embeddingText = embeddingText
        self.embeddings = embeddings
    }
}
