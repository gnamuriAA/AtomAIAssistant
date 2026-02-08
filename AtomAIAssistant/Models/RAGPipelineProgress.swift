//
//  RAGPipelineProgress.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 08/02/26.
//

import Foundation

enum EmbeddingPhase: String {
    case inserting
    case saving
    case embedding
    case done
}

struct DetailedEmbeddingProgress {
    let phase: EmbeddingPhase
    let completed: Int
    let total: Int
    let docName: String?
    let pageNumber: Int?
    let chunkIndexOnPage: Int?
    let batchStart: Int?
    let batchEnd: Int?
    let batchSize: Int?
}
