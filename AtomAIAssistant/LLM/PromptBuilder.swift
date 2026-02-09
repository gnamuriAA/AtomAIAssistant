//
//  PromptBuilder.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 08/02/26.
//

import Foundation

struct ChatTurn {
    let role: ChatRole
    let text: String
}

struct PromptBuilder {
    
    static func systemPrompt() -> String {
                    """
                    You are a strict, context‑bound assistant.

                    RULES:
                    - Answer ONLY using the provided PDF CONTEXT.
                    - If a detail is not explicitly present in the context, state:
                      “The answer is not available in the provided PDF context.”
                    - Do NOT infer, assume, or generate unsupported information.
                    - Do NOT cite if no source is available.
                    - Keep responses factual and concise.
                    - MUST append at the end of the response with:
                        (PDF: <PDF>, page <page>)

                    """
    }

    static func userPrompt(question: String, chunks: [RetrievedChunk], history: [ChatTurn], maxHistoryChars: Int = 4000) -> String {
        let context = chunks.enumerated().map { idx, item in
            let r = item.record
            return """
                [Context \(idx + 1)] (PDF: \(r.docName), page \(r.pageNumber))
                \(r.embeddingText)
                """
        }.joined(separator: "\n\n")
        
        var running = 0
        var kept: [String] = []
        for turn in history.reversed() {
            let role = (turn.role == .user) ? "User" : "Assistant"
            let block = "\(role): \(turn.text)"
            let len = block.count
            if running + len > maxHistoryChars { break }
            kept.append(block)
            running += len
        }
        
        let historyText = kept.reversed().joined(separator: "\n")
        
        return """
            PREVIOUS MESSAGES (for continuity; still must obey PDF-only rule):
            \(historyText.isEmpty ? "None" : historyText)
            
            CONTEXT:
            \(context)
            
            QUESTION:
            \(question)
            """
    }
}
