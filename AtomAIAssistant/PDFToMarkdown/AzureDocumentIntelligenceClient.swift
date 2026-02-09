//
//  AzureDocumentIntelligenceClient.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 09/02/26.
//

import Foundation

enum AzureDocIntelError: Error, LocalizedError {
    case invalidURL
    case missingOperationLocation
    case httpError(status: Int, body: String)
    case pollingFailed(status: String)
    case missingContent
    case jsonDecodeFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid Azure Document Intelligence URL."
        case .missingOperationLocation: return "Missing Operation-Location header in response."
        case .httpError(let status, let body): return "HTTP \(status): \(body)"
        case .pollingFailed(let status): return "Polling failed with status: \(status)"
        case .missingContent: return "Analyze result missing `content`."
        case .jsonDecodeFailed: return "Failed to decode JSON response."
        }
    }
}

struct AzureDocumentIntelligenceClient {
    let endpoint: String          // e.g. "https://<resource-name>.cognitiveservices.azure.com"
    let apiKey: String            // Azure AI Services key
    let apiVersion: String = "2024-11-30"

    /// Analyze a local file (PDF/image) and return Markdown (prebuilt-layout).
    func analyzeToMarkdown(fileURL: URL,
                           contentType: String = "application/pdf",
                           pollIntervalSeconds: Double = 1.0,
                           maxPollAttempts: Int = 120) async throws -> String {

        // Markdown output is supported via outputContentFormat=markdown for Layout.  [oai_citation:1‡Microsoft Learn](https://learn.microsoft.com/en-us/azure/ai-services/document-intelligence/prebuilt/layout?view=doc-intel-4.0.0&utm_source=chatgpt.com)
        let analyzeURLString =
        "\(endpoint)/documentintelligence/documentModels/prebuilt-layout:analyze" +
        "?api-version=\(apiVersion)&outputContentFormat=markdown"

        guard let analyzeURL = URL(string: analyzeURLString) else { throw AzureDocIntelError.invalidURL }

        let fileData = try Data(contentsOf: fileURL)

        var request = URLRequest(url: analyzeURL)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = fileData

        // 1) Submit Analyze request (async). Response contains Operation-Location header.  [oai_citation:2‡Microsoft Learn](https://learn.microsoft.com/en-us/azure/ai-services/document-intelligence/concept/analyze-document-response?view=doc-intel-4.0.0&utm_source=chatgpt.com)
        let (submitData, submitResp) = try await URLSession.shared.data(for: request)

        guard let httpResp = submitResp as? HTTPURLResponse else {
            throw AzureDocIntelError.httpError(status: -1, body: "Non-HTTP response")
        }

        if !(200...299).contains(httpResp.statusCode) {
            let body = String(data: submitData, encoding: .utf8) ?? ""
            throw AzureDocIntelError.httpError(status: httpResp.statusCode, body: body)
        }

        guard let opLoc = httpResp.value(forHTTPHeaderField: "Operation-Location"),
              let opURL = URL(string: opLoc) else {
            throw AzureDocIntelError.missingOperationLocation
        }

        // 2) Poll for result
        for attempt in 1...maxPollAttempts {
            var pollReq = URLRequest(url: opURL)
            pollReq.httpMethod = "GET"
            pollReq.setValue(apiKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")

            let (pollData, pollResp) = try await URLSession.shared.data(for: pollReq)
            guard let pollHttp = pollResp as? HTTPURLResponse else {
                throw AzureDocIntelError.httpError(status: -1, body: "Non-HTTP poll response")
            }

            if !(200...299).contains(pollHttp.statusCode) {
                let body = String(data: pollData, encoding: .utf8) ?? ""
                throw AzureDocIntelError.httpError(status: pollHttp.statusCode, body: body)
            }

            // Response schema includes `status` and (when succeeded) `analyzeResult.content`.  [oai_citation:3‡Microsoft Learn](https://learn.microsoft.com/en-us/rest/api/aiservices/document-models/get-analyze-result?view=rest-aiservices-v4.0+%282024-11-30%29&utm_source=chatgpt.com)
            guard
                let json = try? JSONSerialization.jsonObject(with: pollData) as? [String: Any],
                let status = json["status"] as? String
            else { throw AzureDocIntelError.jsonDecodeFailed }

            if status.lowercased() == "succeeded" {
                if let analyzeResult = json["analyzeResult"] as? [String: Any],
                   let content = analyzeResult["content"] as? String {
                    return content
                } else {
                    throw AzureDocIntelError.missingContent
                }
            }

            if status.lowercased() == "failed" {
                throw AzureDocIntelError.pollingFailed(status: status)
            }

            // still running
            if attempt < maxPollAttempts {
                try await Task.sleep(nanoseconds: UInt64(pollIntervalSeconds * 1_000_000_000))
            } else {
                throw AzureDocIntelError.pollingFailed(status: "timeout")
            }
        }

        throw AzureDocIntelError.pollingFailed(status: "timeout")
    }

    /// Convenience: save markdown to a .md file locally.
    func saveMarkdown(_ markdown: String, fileName: String = "document.md") throws -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let outURL = dir.appendingPathComponent(fileName)
        try markdown.data(using: .utf8)?.write(to: outURL, options: .atomic)
        return outURL
    }
}
