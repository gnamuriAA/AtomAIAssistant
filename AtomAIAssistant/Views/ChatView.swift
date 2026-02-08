//
//  ChatView.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 08/02/26.
//

import SwiftUI

struct ChatView: View {
    @ObservedObject var model: ChatViewModel
    @ObservedObject var embedProgress: GlobalEmbeddingProgressViewModel
    
    var body: some View {
        VStack {
            if model.hasUpdatedQAService, let qaService = model.qaService {
                if embedProgress.isVisible, let progress = embedProgress.progress {
                    Group {
                        Spacer()
                        EmbeddingProgressBanner(progress: progress)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        Spacer()
                    }
                } else {

                    header

                    NavigationStack {
                        ChatHolderView(messages: $model.messages, qaService: qaService, chatClient: model.chatProvider)
                            .environmentObject(embedProgress)
                    }
                }
            } else {
                Text("Failed to load chat service")
            }
        }
    }
}

private var header: some View {
    VStack {
        Text("Atom AI Assistant")
            .font(.largeTitle)
    }
}
