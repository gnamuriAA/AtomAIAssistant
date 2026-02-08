//
//  AtomAIAssistantApp.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 08/02/26.
//

import SwiftUI
import SwiftData

@main
struct AtomAIAssistantApp: App {
    @StateObject var viewModel = ChatViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
        }
        .modelContainer(for: ChunkRecord.self)
    }
}
