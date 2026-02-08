//
//  ChatBubble.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 08/02/26.
//

import SwiftUI

struct ChatBubble: View {
    let message: ChatMessage
    var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom) {
            if isUser {  Spacer(minLength: 40) }

            Text(message.text)
                .font(.body)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .foregroundStyle(isUser ? .white : .primary)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(isUser ? Color.accentColor : Color(.secondarySystemBackground))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(isUser ? .clear : Color(.separator), lineWidth: 0.5)
                }
                .frame(maxWidth: 320, alignment: isUser ? .trailing : .leading)
            
            if !isUser { Spacer(minLength: 40) }
        }
        .padding(.horizontal)
        .padding(.vertical, 2)
    }
}
