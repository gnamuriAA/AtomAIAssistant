//
//  AppleLLMClient.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 08/02/26.
//

import FoundationModels
import Foundation

protocol ChatProvider {
    func chat(system: String, user: String) async throws -> String
}

final class OnDeviceLLMClient: ChatProvider {
    let modelSession: LanguageModelSession
    
    init(instruction: String) {
        modelSession = LanguageModelSession(instructions: instruction)
    }
    
    func chat(system: String, user: String) async throws -> String {
        guard SystemLanguageModel.default.isAvailable else {
            print("Apple Intelligence is not available on this device or region.")
            return "Apple Intelligence is not available on this device or region."
        }
        let newModelSession = LanguageModelSession(instructions: system)
        do {
            let response = try await newModelSession.respond(to: user)
            return response.content
        } catch {
            return error.localizedDescription
        }
    }
}

