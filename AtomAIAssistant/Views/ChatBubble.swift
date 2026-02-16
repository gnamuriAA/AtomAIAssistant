//
//  ChatBubble.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 08/02/26.
//

import SwiftUI

struct ChatBubble: View {
    @ObservedObject var viewModel: ChatViewModel
    let message: ChatMessage
    var isUser: Bool { message.role == .user }
    @State private var showSources = false

    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .bottom) {
                if isUser {  Spacer(minLength: 40) }
                if !isUser {
                    speakButton
                }
                Text(message.markDownString)
                    .font(.body)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .foregroundStyle(isUser ? .white : .primary)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(message.role.bubbleColor)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isUser ? .clear : Color(.separator), lineWidth: 0.5)
                    }
                    .frame(maxWidth: 400, alignment: isUser ? .trailing : .leading)
                if isUser {
                    speakButton
                }
                if !isUser { Spacer(minLength: 40) }
            }
            
            if let source = message.source {
                SourcePanelView(sources: source, isExpanded: $showSources) { reference in
                    open(source: reference)
                }
                .frame(maxWidth: 400, alignment: .leading)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 2)
    }

    var speakButton: some View {
        Button {
            viewModel.startSpeaking(text: message.text)
        } label: {
            Image(systemName: "microphone")
                .resizable()
                .frame(width: 15, height: 15)
        }
        .disabled(viewModel.isAnswering || viewModel.isListening)
    }
    
    private func open(source: SourceReference) {
        print("Called source: \(source.fileName)")
    }

}
