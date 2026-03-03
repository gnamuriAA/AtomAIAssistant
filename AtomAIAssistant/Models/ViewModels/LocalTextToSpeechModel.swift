//
//  LocalTextToSpeechModel.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 02/03/26.
//

import Combine
import Foundation

final class AzureTTSAPIService: ObservableObject {
    private let endpoint = "https://aa-genai-train-foundry.cognitiveservices.azure.com/openai/deployments/gpt-4.1-nano/audio/speech?api-version=2024-12-01-preview"

        static let shared = AzureTTSAPIService()

        func checkIfUserCompleteUrlExists() -> URL? {
            let fileManager = FileManager.default
            let destinationURL = fileManager.temporaryDirectory.appendingPathComponent("file_user_completed.mp3")
            if fileManager.fileExists(atPath: destinationURL.path) {
                return destinationURL
            } else {
                return nil
            }
        }

        func generateSpeech(from text: String, path: String = "file") async throws -> URL {
            guard let url = URL(string: endpoint) else {
                throw NSError(domain: "Failed to get the endpoint", code: 1001)
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
//            request.addValue("Bearer \(azureAPIKey)", forHTTPHeaderField: "Authorization")
            request.setValue(azureAPIKey, forHTTPHeaderField: "api-key")
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String: Any] = [
                "model": "gpt-4o-mini-tts",
                "voice": "alloy",
                "format": "mp3",
                "text": text,
                "input": text
            ]

            request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
            let (downloadedURL, response) = try await URLSession.shared.download(for: request)
            
            print("response is \(response)")
            let fileManager = FileManager.default
            let destinationURL = fileManager.temporaryDirectory.appendingPathComponent("\(path).mp3")
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.moveItem(at: downloadedURL, to: destinationURL)
            return  destinationURL
        }
}
