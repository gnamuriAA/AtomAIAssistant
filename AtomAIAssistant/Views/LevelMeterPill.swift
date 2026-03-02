//
//  LevelMeterPill.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 02/03/26.
//

import SwiftUI

struct LevelMeterPill: View {
    var barCount: Int = 44
    var barWidth: CGFloat = 4
    var barCorner: CGFloat = 2
    var barSpacing: CGFloat = 4
    var minHeight: CGFloat = 6
    var maxHeight: CGFloat = 18
    var foreground: Color = .secondary
    
    var level: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            let pill = RoundedRectangle(cornerRadius: geometry.size.height / 2, style: .continuous)
            
            ZStack {
                pill.fill(Color(.secondarySystemFill))
                HStack(spacing: barSpacing) {
                    ForEach(0..<barCount, id: \.self) { index in
                        let phase = CGFloat(index) / CGFloat(max(1, barCount - 1))
                        let wave = sin(phase * .pi * 2) + (level * 6.0)
                        let heightFactor = abs(wave)
                        let h = minHeight + (maxHeight - minHeight) * heightFactor
                        
                        RoundedRectangle(cornerRadius: barCorner, style: .continuous)
                            .fill(foreground.opacity(0.9))
                            .frame(width: barWidth, height: h)
                            .frame(maxHeight: .infinity, alignment: .center)
                    }
                }
                .padding(.horizontal, 18)
            }
        }
        .frame(height: 40)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(.white.opacity(0.35), lineWidth: 0.5)
        )
    }
}

#Preview {
    LevelMeterPill(level: 0.2)
}
