//
//  QuickQuestionView.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 16/02/26.
//

import SwiftUI

struct QuickQuestionView: View {
    var question: QuickQuestion
    @Binding var isDisabled: Bool
    var action: (String) -> Void = {_ in }

    // Tweak these to match your brand
    private let strokeColor = Color(#colorLiteral(red: 0.086, green: 0.192, blue: 0.373, alpha: 1)) // deep navy
    private let fillLight  = Color(#colorLiteral(red: 0.953, green: 0.966, blue: 0.988, alpha: 1)) // very light blue
    private let fillDark   = Color(#colorLiteral(red: 0.122, green: 0.141, blue: 0.192, alpha: 1)).opacity(0.35)

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button {
            action(question.question)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: question.iconName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(strokeColor)
                Text(question.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(strokeColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(scheme == .dark ? fillDark : fillLight)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(strokeColor, lineWidth: 1.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(question.title))
        .disabled(isDisabled)
    }
}
