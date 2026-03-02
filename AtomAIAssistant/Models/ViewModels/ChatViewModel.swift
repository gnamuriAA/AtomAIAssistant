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
    private var speechCancellables = Set<AnyCancellable>()
    private let monitor = NetworkMonitor.shared
    private let azureClient = AzureDocumentIntelligenceClient(endpoint: "https://aa-genai-train-foundry.cognitiveservices.azure.com/", apiKey: azureAPIKey)
    private let apiClient: AtomAIAssistantClient
    let quickQuestionsModel: QuickQuestionModel
    @Published var quickQuestions: [QuickQuestion] = []
    private let appsToLaunch: [String: (bundleId: String, paramKey: String)] = ["safe": ("aa-techops-safe", "AC="), "atom": ("com.aa.techopsmobility.atom", ""), "osp": ("aa-techops-osp", "ospappurl=https://osp.maverick.aa.com/usersafeoiladd/")]
    private var speechRecognizer: SpeechRecognizer?
    @Published var input: String = ""
    var isListening: Bool {
        guard let speechRecognizer else {
            return false
        }
        return speechRecognizer.isListening
    }
    @Published var isStoppedDueToSilence: Bool = false
    var isSpeaking: Bool {
        guard let speechRecognizer else {
            return false
        }
        return speechRecognizer.isSpeaking
    }

    private var answerGenerationModel: LLGenerationModel?
    @Published var shouldSpeakOnAnswer: Bool = false

    init() {
        embeddingClient = AppleEmbeddingClient()
        apiClient = AtomAIAssistantClient()
        quickQuestionsModel = QuickQuestionModel()
        
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
        initializeSpeechRecognizerr()
        if let speechRecognizer {
            speechRecognizer.startRecording()
        }
        startObservingValues()
    }

    func stopListening() {
        speechRecognizer?.stopRecording()
        stopObservingValues()
        speechRecognizer = nil
    }
    
    func startSpeaking(text: String) {
        initializeSpeechRecognizerr()
        speechRecognizer?.speak(text: text)
    }

    func stopSpeaking() {
        speechRecognizer?.stopSpeaking()
        shouldSpeakOnAnswer = false
    }

    func startListeningAndContinueToSpeak() {
        initializeSpeechRecognizerr()
        speechRecognizer?.startRecording(shouldStopOnUserSilence: false)
        shouldSpeakOnAnswer = true
        startObservingValues()
    }

    private func initializeSpeechRecognizerr() {
        guard speechRecognizer == nil else {
            return
        }
        speechRecognizer = SpeechRecognizer()
    }

    private func startObservingValues() {
        guard let speechRecognizer else {
            return
        }

        speechRecognizer.$transcript
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                guard let self, !value.isEmpty, !self.isSpeaking else {
                    return
                }
                self.input = value
            }
            .store(in: &speechCancellables)

        speechRecognizer.$isStoppedDueToSilence
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.isStoppedDueToSilence = value
            }
            .store(in: &speechCancellables)
    }

    private func stopObservingValues() {
        speechCancellables.forEach { $0.cancel() }
    }
    
    func configureContext(modelContext: ModelContext) {
        qaService = QAService(modelContext: modelContext, embeddingsClient: embeddingClient)
        ragGenerationModel.configureContext(context: modelContext)
        if let qaService {
            answerGenerationModel = LLGenerationModel(qaService: qaService)
        }
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
        if !shouldSpeakOnAnswer {
            stopListening()
        }
        isAnswering = true
        if let launchCommand = LaunchApplicationsWithCommand.parseLaunchCommand(query) {
            messages.append(.init(role: .system, text: launchCommand.message))
            UIApplication.shared.open(launchCommand.url) { status in
                if status {
                    DispatchQueue.main.async {
                        self.input = ""
                        self.messages.removeLast()
                        self.messages.append(.init(role: .system, text: launchCommand.updatedMessage))
                        self.isAnswering = false
                    }
                }
            }
        } else {
            if isOnline {
                do {
                    let askResponse = try await answerWithAPI(question: query, sessionId: sessionID.uuidString)
                    messages.append(.init(role: .assistant, text: askResponse.answer, source: askResponse.sources))
                    isAnswering = false
                    if shouldSpeakOnAnswer {
                        startSpeaking(text: "\(askResponse.answer)")
                        speechRecognizer?.transcript = ""
                    }
                } catch {
                    messages.append(.init(role: .system, text: "Failed to get answer from API. Please try again later. \(error.localizedDescription)"))
                    isAnswering = false
                }
            } else {
                let response = await answerGenerationModel?.answerFromLocal(for: query, history: messages.map { $0.toChatTurn() }) ?? ""
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

let azureAPIKey = ""
