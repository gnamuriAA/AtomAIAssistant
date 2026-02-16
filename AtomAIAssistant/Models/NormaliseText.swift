//
//  NormaliseText.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 16/02/26.
//

import Foundation

enum NormaliseText {
    static func normalizeText(_ input: String) -> String {
        var text = input
        
        // Remove multiple spaces
        text = text.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)

        // Remove weird OCR chars
        text = text.replacingOccurrences(of: #"[^a-zA-Z0-9.,:;?!()/%\-\s]"#, with: "", options: .regularExpression)

        // Trim spaces around punctuation
        text = text.replacingOccurrences(of: #"(\s+)([.,!?])"#,
                                         with: "$2",
                                         options: .regularExpression)

        // Line break normalization
        text = text.replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.contains("DESCRIPTION:") {
            text = text.replacingOccurrences(of: "DESCRIPTION:", with: "")
        }
        if text.contains("PICTURE: ") {
            text = text.replacingOccurrences(of: "PICTURE: ", with: "")
        }
        if text.contains("PRICE:") {
            text = text.replacingOccurrences(of: "PRICE:", with: "Price is ")
        }
        
        if text.contains("PART NUMBER: ") {
            text = text.replacingOccurrences(of: "PART NUMBER: ", with: "Part number is ")
        }
        if text.contains("Columns: DESCRIPTION | PICTURE | PRICE | PART NUMBER") {
            text = text.replacingOccurrences(of: "Columns: DESCRIPTION | PICTURE | PRICE | PART NUMBER", with: "")
        }
        if text.contains("Columns: DESCRIPTION PICTURE PRICE PART NUMBER") {
            text = text.replacingOccurrences(of: "Columns: DESCRIPTION PICTURE PRICE PART NUMBER", with: "")
        }
        if text.contains("Table:") {
            text = text.replacingOccurrences(of: "Table:", with: "")
        }
        if text.contains("Rows:") {
            text = text.replacingOccurrences(of: "Rows:", with: "")
        }
        if text.contains("\n1. ") {
            text = text.replacingOccurrences(of: "\n1. \n", with: "")
        }
//        text = splitIntoParagraphs(text)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func splitIntoParagraphs(_ text: String) -> String {
        let sentences = text.split(separator: ".")
        var result: [String] = []

        var buffer = ""

        for s in sentences {
            var trimmed = s.trimmingCharacters(in: .whitespaces)
            if trimmed.contains("DESCRIPTION:") {
                trimmed = trimmed.replacingOccurrences(of: "DESCRIPTION:", with: "")
            }
            if trimmed.contains("PICTURE: ") {
                trimmed = trimmed.replacingOccurrences(of: "PICTURE: ", with: "")
            }
            if trimmed.contains("PRICE:") {
                trimmed = trimmed.replacingOccurrences(of: "PRICE:", with: "Price is ")
            }
            
            if trimmed.contains("PART NUMBER: ") {
                trimmed = trimmed.replacingOccurrences(of: "PART NUMBER: ", with: "Part number is ")
            }
            if trimmed.contains("Columns: DESCRIPTION | PICTURE | PRICE | PART NUMBER") {
                trimmed = trimmed.replacingOccurrences(of: "Columns: DESCRIPTION | PICTURE | PRICE | PART NUMBER", with: "")
            }
            if trimmed.contains("Columns: DESCRIPTION PICTURE PRICE PART NUMBER") {
                trimmed = trimmed.replacingOccurrences(of: "Columns: DESCRIPTION PICTURE PRICE PART NUMBER", with: "")
            }
            if trimmed.contains("Table:") {
                trimmed = trimmed.replacingOccurrences(of: "Table:", with: "")
            }
            if trimmed.contains("Rows:") {
                trimmed = trimmed.replacingOccurrences(of: "Rows:", with: "")
            }
            if trimmed.contains("\n1. \n") {
                trimmed = trimmed.replacingOccurrences(of: "\n1. \n", with: "")
            }
            
            if trimmed.count < 60 {          // heuristic for sentence length
                buffer += trimmed + ". "
            } else {
                if !buffer.isEmpty {
                    result.append(buffer.trimmingCharacters(in: .whitespaces))
                    buffer = ""
                }
                result.append(trimmed + ".")
            }
        }

        if !buffer.isEmpty {
            result.append(buffer)
        }

        return result.joined(separator: "\n\n")
    }

    private static func makeBulletPoints(_ text: String) -> String {
        let components = text
            .split(separator: ".")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        return components.map { "• " + $0 }.joined(separator: "\n")
    }

}
