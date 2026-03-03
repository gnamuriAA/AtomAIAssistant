//
//  ChatHolderView.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 08/02/26.
//

import SwiftUI
internal import UniformTypeIdentifiers

struct ChatHolderView: View {
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject var embedProgress: GlobalEmbeddingProgressViewModel
    @FocusState private var sendIsFocused: Bool
    @State private var scrollID = UUID()
    
    var body: some View {
        VStack(spacing: .zero) {
            if viewModel.messages.isEmpty {
                ChatInitialView(chatViewModel: viewModel) { askedQuestion in
                    viewModel.input = askedQuestion
                    send()
                }
            } else {
                chatList
            }
            
            Divider()

            if !viewModel.messages.isEmpty {
                QuickQuestions(viewModel: viewModel, axis: .horizontal) { askedQuestion in
                    viewModel.input = askedQuestion
                    send()
                }
                .padding([.top, .leading], 8)
                .padding(.bottom, 12)
            }
            
            ChatInputComposerView(text: $viewModel.input, isStoppedDueToSilence: $viewModel.isStoppedDueToSilence) { textToSend in
                send()
            } onTapPlus: {
                viewModel.showImporter = true
            } onStartVoice: {
                viewModel.startListeningAndContinueToSpeak()
            } onStopVoice: {
                viewModel.stopListening()
                viewModel.stopSpeaking()
            } onInlineMic: {
                viewModel.startListening()
            }
        }
        .fileImporter(isPresented: $viewModel.showImporter, allowedContentTypes: [.pdf], allowsMultipleSelection: false) { result in
            Task { @MainActor in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    viewModel.selectedPDF = url
                    try await viewModel.upload(url) { progress in
                        embedProgress.update(progress)
                    }
                case .failure(let failure):
                    print("Failed to upload")
                }
            }
        }
    }

    private var chatList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(viewModel.messages) { message in
                        ChatBubble(viewModel: viewModel, message: message)
                            .id(message.id)
                    }
                    if viewModel.isAnswering {
                        HStack {
                            TypingIndicatorView()
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .id(scrollID)
                    }
                    
                    if viewModel.isListening {
                        HStack {
                            Spacer()
                            Text(viewModel.input)
                                .foregroundStyle(.secondary)
                                .italic()
                        }
                        .padding(.horizontal, 12)
                        .id(scrollID)
                    }
                }
                .padding(.vertical, 8)
            }
            .onChange(of: viewModel.messages.count) { oldValue, newValue in
                scrollToBottom(proxy)
            }
            .onChange(of: viewModel.isAnswering) { oldValue, newValue in
                scrollToBottom(proxy)
            }
        }
        .background(Color(.systemGroupedBackground))
        .onTapGesture {
            sendIsFocused = false
        }
    }
    
    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.25)) {
            proxy.scrollTo(viewModel.messages.last?.id ?? scrollID, anchor: .bottom)
        }
    }

    private func send() {
        let question = viewModel.input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !question.isEmpty else { return }
        
        viewModel.input = ""
        Task {
            await viewModel.answer(for: question)
        }
    }
}

#Preview {
    ChatHolderView(viewModel: ChatViewModel(), embedProgress: GlobalEmbeddingProgressViewModel())
}

struct QuickQuestions: View {
    @ObservedObject var viewModel: ChatViewModel
    var axis: Axis.Set = .vertical
    var action: (String) -> Void

    var body: some View {
        ScrollView(axis, showsIndicators: false) {
            stackContent(isHStack: axis == .horizontal) {
                ForEach(viewModel.quickQuestions) { question in
                    QuickQuestionView(question: question, isDisabled: $viewModel.isUploading) { question in
                        action(question)
                    }
                }
            }
        }
        .disabled(viewModel.isAnswering)
    }

    @ViewBuilder
    func stackContent(isHStack: Bool, @ViewBuilder content: () -> some View) -> some View {
        if isHStack {
            HStack(spacing: 12) {
                content()
            }
        } else {
            VStack(spacing: 12) {
                content()
            }
            .padding(.vertical, 6)
            .padding(.leading, 6)
        }
    }
}
