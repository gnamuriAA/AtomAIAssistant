//
//  AppleLLMClient.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 08/02/26.
//

import FoundationModels
import Foundation
import Combine

protocol ChatProvider {
    func chat(system: String, user: String) async throws -> String
}

final class AppleLLMClient: ObservableObject, ChatProvider {
    @Published var isGenerating: Bool = false
    @Published var generatedResponse: String = ""
    
    var modelSession: LanguageModelSession
    
    init(instruction: String) {
        modelSession = LanguageModelSession(instructions: instruction)
    }
    
    func chat(system: String, user: String) async throws -> String {
        isGenerating = true
        guard SystemLanguageModel.default.isAvailable else {
            isGenerating = false
            generatedResponse = "Apple Intelligence is not available on this device or region."
            return "Apple Intelligence is not available on this device or region."
        }
        isGenerating = false
//        do {
            let response = try await modelSession.respond(to: user)
            generatedResponse = response.content
//        } catch {
//            modelSession = LanguageModelSession(instructions: system)
//            let response = try await modelSession.respond(to: user)
//            return response.content
//        }
        return generatedResponse
    }
}

