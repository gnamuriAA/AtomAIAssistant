//
//  TypingIndicatorView.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 16/02/26.
//

import SwiftUI

struct TypingIndicatorView: View {
    @State private var phase: CGFloat = 0

    private let dotCount = 3
    private let dotSize: CGFloat = 8
    private let dotSpacing: CGFloat = 6
    private let animationDuration: Double = 0.9

    var body: some View {
        HStack(spacing: dotSpacing) {
            ForEach(0..<dotCount, id: \.self) { i in
                Circle()
                    .fill(Color.primary.opacity(0.6))
                    .frame(width: dotSize, height: dotSize)
                    .scaleEffect(scale(for: i))
                    .animation(
                        .easeInOut(duration: animationDuration)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.15),
                        value: phase
                    )
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.12))
        )
        .onAppear { phase = 1 }
    }

    private func scale(for index: Int) -> CGFloat {
        // Create a slight staggered pulse
        let base: CGFloat = 0.7
        return base + 0.3 * (phase == 0 ? 0 : 1)
    }
}
