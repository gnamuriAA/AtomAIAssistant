//
//  GlobalEmbeddingProgressViewModel.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 08/02/26.
//

import SwiftUI
import Combine

@MainActor
final class GlobalEmbeddingProgressViewModel: ObservableObject {
    @Published var progress: DetailedEmbeddingProgress? = nil
    @Published var isVisible: Bool = false
    
    func update(_ progress: DetailedEmbeddingProgress) {
        self.progress = progress
        isVisible = (progress.phase != .done)
        print("Progress for phase \(progress.phase.rawValue) and isVisible \(isVisible)")
        
        if progress.phase == .done {
            // Hide after a short moment so user sees "Done"
            
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 900_000_000)
                self.isVisible = false
                self.progress = nil
            }
        }
    }

    func hideNow() {
        isVisible = false
        progress = nil
    }
}
