//
//  EmbeddingProgressBanner.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 08/02/26.
//

import SwiftUI

struct EmbeddingProgressBanner: View {
    let progress: DetailedEmbeddingProgress
    
    private var fraction: Double {
        let total = max(progress.total, 1)
        return Double(progress.completed) / Double(total)
    }

    private var title: String {
        switch progress.phase {
        case .inserting:
            return "Preparing data..."
        case .embedding:
            return "Generating embeddings..."
        case .saving:
            return "Saving embeddings..."
        case .done:
            return "Done"
        }
    }

    private var subtitle: String {
        var parts: [String] = []
        parts.append("\(progress.completed)/ \(progress.total)")
        
        if let doc = progress.docName {
            parts.append("\(doc)")
        }
        
        if let pageNumber = progress.pageNumber {
            parts.append("Page \(pageNumber)")
        }

        if let chunk = progress.chunkIndexOnPage {
            parts.append("Chunk \(chunk)")
        }

        if let bs = progress.batchSize, let be = progress.batchEnd {
            parts.append("(\(bs + 1)-\(be))")
        }

        return parts.joined(separator: " • ")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline).bold()
                Spacer()
                Text("\(Int(fraction * 100))%")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            
            ProgressView(value: fraction)

            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(radius: 8, y: 3)
        .padding(.horizontal)
        .padding(.top, 8)
    }
}
