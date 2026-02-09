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

final class AppleLLMClient: ChatProvider {
    var modelSession: LanguageModelSession
    
    init?(instruction: String) {
        guard SystemLanguageModel.default.isAvailable else {
            return nil
        }
        modelSession = LanguageModelSession(instructions: instruction)
    }
    
    func chat(system: String, user: String) async throws -> String {
        guard SystemLanguageModel.default.isAvailable else {
            return "Apple Intelligence is not available on this device or region."
        }
        do {
            let response = try await modelSession.respond(to: user)
            return response.content
        } catch {
            modelSession = LanguageModelSession(instructions: system)
            let response = try await modelSession.respond(to: user)
            return response.content
        }
    }
}

