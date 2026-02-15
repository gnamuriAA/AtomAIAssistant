//
//  ChatHolderView.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 08/02/26.
//

import SwiftUI
internal import UniformTypeIdentifiers

struct ChatHolderView: View {
    @State private var input: String = ""
    @Binding var messages: [ChatMessage]
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject var embedProgress: GlobalEmbeddingProgressViewModel
    @FocusState private var sendIsFocused: Bool
    
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
                    ForEach(messages) { message in
                        ChatBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding(.vertical, 8)
            }
            .onChange(of: messages.count) { oldValue, newValue in
                scrollToBottom(proxy)
            }
        }
        .background(Color(.systemGroupedBackground))
        .onTapGesture {
            sendIsFocused = false
        }
    }

    private var composer: some View {
        HStack(spacing: 10) {
            Button {
                viewModel.showImporter = true
            } label: {
                Image(systemName: "doc.on.doc")
            }
            if viewModel.isUploading {
                ProgressView("Uploading & saving the markdown..")
            } else {
                TextField("Ask from PDFs...", text: $input, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                    .focused($sendIsFocused)
                
                
                Button {
                    sendIsFocused = false
                    send()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 28))
                }
                .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            if let last = messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    private func send() {
        let question = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !question.isEmpty else { return }
        
        input = ""
        
        messages.append(.init(role: .user, text: question))
        
        Task {
            let response = await viewModel.answer(for: question, history: messages.map{ $0.toChatTurn() })
            await MainActor.run {
                messages.append(.init(role: .assistant, text: response))
            }
        }
    }
}
