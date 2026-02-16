//
//  ScorePill.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 16/02/26.
//

import SwiftUI

struct ScorePill: View {
    let score: Double? // 0...1
    
    var body: some View {
        let percent = Int((score ?? 0) * 100)
        HStack(spacing: 6) {
            Circle()
                .fill(scoreColor)
                .frame(width: 8, height: 8)
            Text("\(percent)%")
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(.primary)
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            Capsule()
                .fill(Color.secondary.opacity(0.15))
        )
        .accessibilityLabel("Match score \(percent) percent")
    }
    
    private var scoreColor: Color {
        guard let s = score else { return .gray }
        switch s {
        case ..<0.5: return .orange
        case ..<0.7: return .yellow
        case ..<0.9: return .green
        default:     return .blue
        }
    }
}

struct PdfChip: View {
    var body: some View {
        Text("PDF")
            .font(.caption2.weight(.bold))
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.blue.opacity(0.12))
            )
            .foregroundStyle(.blue)
            .accessibilityHidden(true)
    }
}
