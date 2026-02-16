//
//  ChatViewModel.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 08/02/26.
//

import Foundation
import SwiftData
import Combine
import Network
import UIKit
import SwiftUI

final class ChatViewModel: ObservableObject {
    private var ragGenerationModel: RAGGenerationModel = RAGGenerationModel(pdfs: AvailableMarkdown.allCases)
    private(set) var qaService: QAService?
    private var modelContext: ModelContext?
    private let embeddingClient: EmbeddingProvider
    private(set) var chatProvider: ChatProvider
    private(set) var azureChatProvider: ChatProvider
    @Published var messages: [ChatMessage] = [
        .init(role: .assistant, text: "Ask me anything about the uploaded documents!")
    ]
    @Published var hasUpdatedQAService: Bool = false
    @Published var showImporter = false
    @Published var selectedPDF: URL?
    @Published var isUploading: Bool = false
    @Published var isAnswering: Bool = false
    private var sessionID = UUID()
    @Published private(set) var isOnline: Bool = true
    @Published private(set) var currentInterface: NWInterface.InterfaceType?
    @Published private(set) var statusText: String = "Checking…"
    private var cancellables = Set<AnyCancellable>()
    private let monitor = NetworkMonitor.shared
    private let azureClient = AzureDocumentIntelligenceClient(endpoint: "https://aa-genai-train-foundry.cognitiveservices.azure.com/", apiKey: azureAPIKey)
    private let apiClient: AtomAIAssistantClient
    let quickQuestionsModel: QuickQuestionModel
    @Published var quickQuestions: [QuickQuestion] = []
    private let appsToLaunch: [String: (bundleId: String, paramKey: String)] = ["safe": ("aa-techops-safe", "AC="), "atom": ("com.aa.techopsmobility.atom", ""), "osp": ("aa-techops-osp", "ospappurl=https://osp.maverick.aa.com/usersafeoiladd/")]
    private var speechRecognizer = SpeechRecognizer()
    @Published var input: String = ""
    @Published private(set) var isListening: Bool = false
    @Published private(set) var isStoppedDueToSilence = false
    @Published private(set) var isSpeaking: Bool = false

    init() {
        embeddingClient = AppleEmbeddingClient()
        azureChatProvider = AppleLLMClient(instruction: PromptBuilder.systemPrompt())
        chatProvider = AzureLLMClient(endpoint: URL(string: "https://aa-genai-train-foundry.cognitiveservices.azure.com/")!, deployment: "gpt-4o", apiKey: azureAPIKey, apiVersion: "2024-12-01-preview")
        apiClient = AtomAIAssistantClient()
        quickQuestionsModel = QuickQuestionModel()
        
        speechRecognizer.$transcript
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                guard !value.isEmpty else {
                    return
                }
                self?.input = value
            }
            .store(in: &cancellables)

        speechRecognizer.$isListening
            .receive(on: DispatchQueue.main)
            .sink { [weak self] listening in
                self?.isListening = listening
            }
            .store(in: &cancellables)

        speechRecognizer.$isStoppedDueToSilence
            .receive(on: DispatchQueue.main)
            .sink { [weak self] dueToSilence in
                self?.isStoppedDueToSilence = dueToSilence
            }
            .store(in: &cancellables)

        speechRecognizer.$isSpeaking
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.isSpeaking = value
            }
            .store(in: &cancellables)
        
        monitor.$isConnected
            .combineLatest(monitor.$interfaceType)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected, iface in
                guard let self else { return }
                self.isOnline = isConnected
                self.currentInterface = iface
                quickQuestionsModel.isOnline = isConnected
                quickQuestions = quickQuestionsModel.questions

                if isConnected {
                    let ifaceName = iface.map(String.init(describing:)) ?? "network"
                    self.statusText = "Connected via \(ifaceName)"
                } else {
                    self.statusText = "Offline"
                }
            }
            .store(in: &cancellables)
        
        monitor.startMonitoring()
    }

    func startListening() {
        speechRecognizer.startRecording()
    }

    func stopListening() {
        speechRecognizer.stopRecording()
    }
    
    func startSpeaking(text: String) {
        speechRecognizer.speak(text: text)
    }

    func stopSpeaking() {
        speechRecognizer.stopSpeaking()
    }

    func configureContext(modelContext: ModelContext) {
        qaService = QAService(modelContext: modelContext, embeddingsClient: embeddingClient)
        ragGenerationModel.configureContext(context: modelContext)
        self.modelContext = modelContext
        ragGenerationModel = RAGGenerationModel(pdfs: AvailableMarkdown.allCases, multiPDFEmbeddingPipeline: MultiPDFEmbeddingPipeLine(chunker: PDFMarkdownChunkingProvider(), indexer: ChunkEmbeddingIndexer(client: embeddingClient, modelContext: modelContext)))
        hasUpdatedQAService = true
    }

    @MainActor
    func generateEmbeddingsAndStoreLocally(progress: @escaping (DetailedEmbeddingProgress) -> Void) async throws {
        try await ragGenerationModel.generateEmbeddings(progress: progress)
    }

    func deleteSavedData() throws {
        guard let modelContext else {
            return
        }

        try modelContext.delete(model: ChunkRecord.self)
    }

    func upload(_ url: URL, progress: @escaping (DetailedEmbeddingProgress) -> Void) async throws {
        isUploading = true

        Task {
            do {
                let didStart = url.startAccessingSecurityScopedResource()
                defer { if didStart { url.stopAccessingSecurityScopedResource() } }
                
                let md = try await azureClient.analyzeToMarkdown(fileURL: url, contentType: "application/pdf")
                let mdURL = try azureClient.saveMarkdown(md, fileName: "\(selectedPDF?.lastPathComponent.replacingOccurrences(of: ".pdf", with: "") ?? "NewDocument").md")
                try await ragGenerationModel.generateEmbedding(for: mdURL, progress: progress)
                await MainActor.run {
                    isUploading = false
                }
            } catch {
                await MainActor.run {
                    isUploading = false
                }
            }
        }
    }

    func answer(for query: String) async {
        messages.append(.init(role: .user, text: query))
        stopListening()
        isAnswering = true
        if let launchCommand = parseLaunchCommand(query), appsToLaunch.keys.contains(launchCommand.appName.lowercased()) {
            if let string = appsToLaunch[launchCommand.appName.lowercased()], let url = URL(string: "\(string.bundleId)://\((launchCommand.rawParams == nil) ? "" : (string.paramKey + launchCommand.rawParams!))") {
                var messageText = "Launching **\(launchCommand.appName.capitalized)**"
                if let params = launchCommand.rawParams {
                    messageText += " with params: **\(params)**"
                }
                messages.append(.init(role: .system, text: messageText))
                UIApplication.shared.open(url) { status in
                    if status {
                        var updatedMessageText = "Successfully launched **\(launchCommand.appName.capitalized)** application "
                        if let params = launchCommand.rawParams {
                            updatedMessageText += " with params: **\(params)**"
                        }
                        DispatchQueue.main.async {
                            self.input = ""
                            self.messages.removeLast()
                            self.messages.append(.init(role: .system, text: updatedMessageText))
                            self.isAnswering = false
                        }
                    }
                }
            } else {
                messages.append(.init(role: .system, text: "Cannot Launching \(launchCommand.appName) with params: \(launchCommand.rawParams ?? "none") as this is not configured."))
                isAnswering = false
            }
        } else {
            if isOnline {
                do {
                    let askResponse = try await answerWithAPI(question: query, sessionId: sessionID.uuidString)
                    messages.append(.init(role: .assistant, text: askResponse.answer, source: askResponse.sources))
                    isAnswering = false
                } catch {
                    messages.append(.init(role: .system, text: "Failed to get answer from API. Please try again later. \(error.localizedDescription)"))
                    isAnswering = false
                }
            } else {
                let response = await answerFromLocal(for: query, history: messages.map { $0.toChatTurn() })
                messages.append(.init(role: .assistant, text: response))
                isAnswering = false
            }
        }
    }

    private func doesQuestionToLaunchApp(question: String) -> [String] {
        let syncedApps = Set(question.components(separatedBy: " ")).union(appsToLaunch.keys)
        return Array(syncedApps)
    }
}

private extension ChatViewModel {
    func answerWithAPI(question: String, sessionId: String) async throws -> AskResponse {
        return try await apiClient.ask(query: question, sessionId: sessionId)
    }
}

private extension ChatViewModel {
    func answerFromLocal(for query: String, history: [ChatTurn]) async -> String {
        guard let qaService else {
            return "QA Service not ready yet. Please wait a moment and try again."
        }
        var triedWithAppleLLM = true
        do {
            var response = try await qaService.answer(query, chatClient: chatProvider, history: history)
            if response.llmResponse == "Apple Intelligence is not available on this device or region." {
                triedWithAppleLLM = false
                response = try  await qaService.answer(query, chatClient: azureChatProvider, history: history)
                
            }
            return response.llmResponse
        } catch {
            if triedWithAppleLLM {
                do {
                    let response = try  await qaService.answer(query, chatClient: azureChatProvider, history: history)
                    return response.llmResponse
                } catch {
                    guard let rawResults = try? await qaService.getRawAnswers(question: query) else {
                        return "Failed to load answer vectors chunks from local store. Please try again later."
                    }
                    let filteredRecords = rawResults.filter { $0.finalScore >= 0.8 }.sorted(by: { $0.finalScore > $1.finalScore })
                    let textToReturn = filteredRecords.map { $0.record.embeddingText }.joined(separator: "\n")
                    let normalizedText = NormaliseText.normalizeText(textToReturn)
                    return textToReturn.isEmpty ? "No relevant answers found." : normalizedText
                }
            }
        }
        return "Failed to load answer from both Apple Intelligence and Azure OpenAI. Please try again later."
    }

    private func parseLaunchCommand(_ input: String) -> LaunchCommand? {
        // (?i) -> case-insensitive
        // 1st capture: app name (quoted or unquoted)
        // 2nd capture: params rest (optional)
        let pattern = #"(?i)^\s*launch\s+(?:"([^"]+)"|([^\s]+(?:\s+[^\s]+)*?))\s*(?:\s+with\s+(.*))?\s*$"#
        // Explanation:
        // - ^\s*launch\s+      : starts with "launch"
        // - (?:"([^"]+)"|...)  : either "quoted app name" or multi-word unquoted
        // - (?:\s+with\s+(.*))?: optional "with <params...>" capturing the rest

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(input.startIndex..<input.endIndex, in: input)

        guard let match = regex.firstMatch(in: input, options: [], range: range) else { return nil }

        func group(_ i: Int) -> String? {
            let r = match.range(at: i)
            guard r.location != NSNotFound, let rr = Range(r, in: input) else { return nil }
            return String(input[rr]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Either group 1 (quoted) or 2 (unquoted multi-word)
        let appName = group(1) ?? group(2)
        let params = group(3)

        guard let app = appName, !app.isEmpty else { return nil }
        return LaunchCommand(appName: app, rawParams: params?.isEmpty == true ? nil : params)
    }
}

enum ChatRole: String, CaseIterable {
    case user, assistant, system
}

struct ChatMessage: Identifiable, Hashable {
    let id = UUID()
    let role: ChatRole
    let text: String
    let date: Date = Date()
    var source: [SourceReference]?
    var markDownString: LocalizedStringKey {
        return LocalizedStringKey(text)
    }
}


extension ChatRole {
    var bubbleColor: Color {
        switch self {
        case .user:      return Color("UserBubble")
        case .assistant: return Color("AssistantBubble")
        case .system:    return Color("SystemBubble")
        }
    }
}

extension ChatMessage {
    func toChatTurn() -> ChatTurn {
        .init(role: role, text: text)
    }
}

let azureAPIKey = ""

struct LaunchCommand {
    let appName: String
    let rawParams: String?
}
