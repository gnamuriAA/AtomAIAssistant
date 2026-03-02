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
            chatList
            
            Divider()
            
            composer
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
                LazyVStack(spacing: 4) {
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

    private var composer: some View {
        VStack(alignment: .leading) {
            HStack {
                quickQuestions

                if viewModel.isListening {
                    Button {
                        viewModel.stopListening()
                    } label: {
                        Text("Stop listening")
                        
                        Image(systemName: "microphone.slash")
                            .resizable()
                            .frame(width: 15, height: 15)
                            .foregroundColor(.blue)
                            .foregroundColor(.red)
                    }
                }
                if viewModel.isSpeaking {
                    Button {
                        viewModel.stopSpeaking()
                    } label: {
                        HStack {
                            Text("Stop Speaking")

                            Image(systemName: "microphone.slash")
                                .resizable()
                                .frame(width: 15, height: 15)
                                .foregroundColor(.red)
                        }
                    }
                }
            }

            HStack(spacing: 10) {
                Button {
                    viewModel.showImporter = true
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                if viewModel.isUploading {
                    ProgressView("Uploading & saving the markdown..")
                } else {
                    TextField("Ask from PDFs...", text: $viewModel.input, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...4)
                        .focused($sendIsFocused)
                    HStack {
                        Button {
                            viewModel.startListening()
                            sendIsFocused = false
                        } label: {
                            Image(systemName: "waveform.badge.microphone")
                                .resizable()
                                .frame(width: 30, height: 30)
                        }
                        .disabled(viewModel.isAnswering || viewModel.isListening || viewModel.isSpeaking)

                        Button {
                            send()
                            sendIsFocused = false
                        } label: {
                            Text("Send")
                                .foregroundStyle(.white)
                                .font(.body.bold())
                                .padding(.horizontal)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule(style: .circular)
                                )
                        }
                        .disabled(viewModel.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isAnswering || viewModel.isSpeaking)
                    }
                }
            }
            .padding(.top, 6)
            
            Text(viewModel.statusText)
                .font(.footnote)
                .bold()
                .padding(.leading, 4)
                .foregroundStyle(viewModel.isOnline ? Color(.systemBlue) : Color.red)
        }
    }

    private var quickQuestions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(viewModel.quickQuestions) { question in
                    QuickQuestionView(question: question, isDisabled: $viewModel.isUploading) { question in
                        viewModel.input = question
                        send()
                    }
                }
            }
            .padding(.vertical, 6)
            .padding(.leading, 6)
        }
        .disabled(viewModel.isAnswering)
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
