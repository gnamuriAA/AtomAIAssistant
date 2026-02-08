//
//  PromptBuilder.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 08/02/26.
//

import Foundation

struct PromptBuilder {
    
    static func systemPrompt() -> String {
                    """
                    You are a helpful assistant.
                    
                    RULES:
                    - Answer ONLY using the provided CONTEXT from PDFs.
                    - If the answer is not found, reply exactly:
                    "Not Found in the provided PDFs."
                    - Always cite sources as:
                    (PDF: <docName>, page <pageNumber>)
                    """
    }

    static func userPrompt(question: String, chunks: [RetrievedChunk]) -> String {
        let context = chunks.enumerated().map { idx, item in
            let r = item.record
            return """
                [Context \(idx + 1)] (PDF: \(r.docName), page \(r.pageNumber))
                \(r.embeddingText)
                """
        }.joined(separator: "\n\n")
        
        return """
            CONTEXT:
            \(context)
            
            QUESTION:
            \(question)
            """
    }
}
