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
            if model.hasUpdatedQAService, model.qaService != nil {
                if embedProgress.isVisible, let progress = embedProgress.progress {
                    Group {
                        Spacer()
                        EmbeddingProgressBanner(progress: progress)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        Spacer()
                    }
                } else {
                    header

                    ChatHolderView(viewModel: model, embedProgress: embedProgress)
                        .environmentObject(embedProgress)
                }
            } else {
                Text("Failed to load chat service")
            }
        }
        .background(
            model.isOnline ? Color(.systemGroupedBackground) : Color.red.opacity(0.1)
        )
    }

    private var header: some View {
        VStack {
            Text("Atom AI Assistant")
                .font(.largeTitle)
        }
    }

}
