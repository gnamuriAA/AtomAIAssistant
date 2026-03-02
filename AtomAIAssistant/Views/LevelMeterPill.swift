//
//  LevelMeterPill.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 02/03/26.
//

import SwiftUI

struct LevelMeterPill: View {
    var barWidth: CGFloat = 4
    var barCorner: CGFloat = 2
    var barSpacing: CGFloat = 4
    var minHeight: CGFloat = 6
    var maxHeight: CGFloat = 24
    var foreground: Color = .secondary
    @Binding var isAnimating: Bool

    @State private var barHeights: [CGFloat] = []
    @State private var timer: Timer?

    var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width - 36
            let barCount = max(1, Int((availableWidth + barSpacing) / (barWidth + barSpacing)))
            let pill = RoundedRectangle(cornerRadius: geometry.size.height / 2, style: .continuous)
            ZStack {
                pill.fill(Color(.secondarySystemFill))
                HStack(spacing: barSpacing) {
                    ForEach(0..<barCount, id: \.self) { i in
                        Rectangle()
                            .fill(foreground.opacity(0.9))
                            .frame(width: barWidth, height: barHeights.indices.contains(i) ? barHeights[i] : minHeight)
                            .cornerRadius(barCorner)
                            .frame(maxHeight: .infinity, alignment: .center)
                            .animation(.easeInOut(duration: 0.2), value: barHeights)
                    }
                }
                .padding(.horizontal, 18)
            }
            .onAppear {
                barHeights = Array(repeating: minHeight, count: barCount)
                if isAnimating {
                    startTimer(barCount)
                }
            }
            .onChange(of: isAnimating) { old, newValue in
                if newValue {
                    // Start animating: reset heights and start timer
                    stopTimer()
                    barHeights = Array(repeating: minHeight, count: barCount)
                    startTimer(barCount)
                } else {
                    // Stop animating: stop timer and reset heights
                    stopTimer()
                    barHeights = Array(repeating: minHeight, count: barCount)
                }
            }
            .onDisappear {
                stopTimer()
            }
        }
        .frame(height: 40)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(.white.opacity(0.35), lineWidth: 0.5)
        )
    }

    private func startTimer(_ barCount: Int) {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                barHeights = (0..<barCount).map { _ in
                    CGFloat.random(in: minHeight...maxHeight)
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
