//
//  ChatHolderView.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 08/02/26.
//

import SwiftUI

struct ChatHolderView: View {
    @State private var input: String = ""
    @Binding var messages: [ChatMessage]

    let qaService: QAService
    let chatClient: ChatProvider
    @FocusState private var sendIsFocused: Bool
    
    var body: some View {
        VStack(spacing: .zero) {
            chatList
            
            Divider()
            
            composer
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
            TextField("Ask from PDFs...", text: $input, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
                .focused($sendIsFocused)
            
            Button {
                send()
                sendIsFocused = false
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 28))
            }
            .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
            let response = await qaService.answer(question, chatClient: chatClient)
            await MainActor.run {
                messages.append(.init(role: .assistant, text: response))
            }
        }
    }
}
