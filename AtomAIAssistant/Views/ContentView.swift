//
//  ContentView.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 08/02/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var embedProgress = GlobalEmbeddingProgressViewModel()
    @ObservedObject var viewModel: ChatViewModel
    @State private var shouldDeleteData = true

    var body: some View {
        VStack {
            ChatView(model: viewModel, embedProgress: embedProgress)
        }
        .onAppear {
            viewModel.configureContext(modelContext: modelContext)
            if shouldDeleteData {
                do {
                    try viewModel.deleteSavedData()
                    shouldDeleteData = false
                } catch {
                    print("Failed to delete embeddings \(error)")
                }
            }
            Task {
                do {
                    try await viewModel.generateEmbeddingsAndStoreLocally { progress in
                        embedProgress.update(progress)
                    }
                } catch {
                    print("Failed to generate embedding \(error)")
                }
            }
        }
    }
}
