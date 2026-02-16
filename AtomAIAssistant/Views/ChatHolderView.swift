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
                    ForEach(viewModel.messages) { message in
                        ChatBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding(.vertical, 8)
            }
            .onChange(of: viewModel.messages.count) { oldValue, newValue in
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

            quickQuestions

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
                    .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isAnswering)
                }
            }
            .padding(.top, 6)
            
            Text(viewModel.statusText)
                .font(.footnote)
                .bold()
                .padding(.leading, 4)
                .foregroundStyle(viewModel.isOnline ? Color(.systemBlue) : Color.red)
        }
        .padding()
        .background(Color(.systemBackground))
    }

    private var quickQuestions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(viewModel.quickQuestions) { question in
                    QuickQuestionView(question: question, isDisabled: $viewModel.isUploading) { question in
                        input = question
                        send()
                    }
                }
            }
            .padding(.vertical, 6)
            .padding(.leading, 6)
        }
    }
    
    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            if let last = viewModel.messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    private func send() {
        let question = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !question.isEmpty else { return }
        
        input = ""
        Task {
            await viewModel.answer(for: question)
        }
    }
}
