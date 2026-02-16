//
//  AtomAIAssistantClient.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 16/02/26.
//

import Foundation

class AtomAIAssistantClient {
    let baseURL: URL
    let session: URLSession
    
    init(baseURL: URL = URL(string: "https://atom-assistant-ai-dev.maverick.aa.com")!) {
        self.baseURL = baseURL
        self.session = URLSession.shared
    }

    // MARK: - Full Response (Non-Streaming)
    func ask(
        query: String,
        sessionId: String,
        topK: Int = 20,
        topN: Int = 5
    ) async throws -> AskResponse {
        guard let url = URL(string: "\(baseURL.absoluteString)/ask") else {
            throw AtomAssistantError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let request = AskRequest(
            query: query,
            sessionId: sessionId,
            topK: topK,
            topN: topN
        )
        
        do {
            let encoder = JSONEncoder()
            urlRequest.httpBody = try encoder.encode(request)
        } catch {
            throw AtomAssistantError.decodingError(error)
        }
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AtomAssistantError.invalidResponse
        }
        
        guard 200..<300 ~= httpResponse.statusCode else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AtomAssistantError.httpError(
                statusCode: httpResponse.statusCode,
                message: errorMessage
            )
        }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(AskResponse.self, from: data)
        } catch {
            throw AtomAssistantError.decodingError(error)
        }
    }
}

enum APIError: Error {
    case invalidResponse
    case decodingError
    case networkError(Error)
}


enum AtomAssistantError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case httpError(statusCode: Int, message: String)
    case decodingError(Error)
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code, let message):
            return "HTTP \(code): \(message)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
}
