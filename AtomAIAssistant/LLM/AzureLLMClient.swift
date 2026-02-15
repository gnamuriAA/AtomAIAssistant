//
//  AzureLLMClient.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 09/02/26.
//

import Foundation
import Combine

final class AzureLLMClient: ObservableObject, ChatProvider {
    @Published var isGenerating: Bool = false
    @Published var generatedResponse: String = ""

    let endpoint: URL
    let deployment: String
    let apiKey: String
    let apiVersion: String

    init(endpoint: URL, deployment: String, apiKey: String, apiVersion: String) {
        self.endpoint = endpoint
        self.deployment = deployment
        self.apiKey = apiKey
        self.apiVersion = apiVersion
        self.isGenerating = isGenerating
        self.generatedResponse = generatedResponse
    }
    
    struct Response: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                let role: String
                let content: String
            }

            let message: Message
        }

        let choices: [Choice]
    }

    func chat(system: String, user: String) async throws -> String {
        isGenerating = true
        var url = endpoint
        url.append(path: "openai/deployments/\(deployment)/chat/completions")
        
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "api-version", value: apiVersion)]
        let finalURL = comps.url!
        
        var request = URLRequest(url: finalURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "api-key")
        
        let body: [String: Any] = [
            "temperature": 0.2,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "AzureChatClient",
                          code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: msg])
        }
        
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        isGenerating = false
        generatedResponse = decoded.choices.first?.message.content ?? ""
        return generatedResponse
    }
}
