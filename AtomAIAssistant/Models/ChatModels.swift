//
//  ChatModels.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 27/02/26.
//

import Foundation
import SwiftUI

enum ChatRole: String, CaseIterable {
    case user, assistant, system
}

struct ChatMessage: Identifiable, Hashable {
    let id = UUID()
    let role: ChatRole
    let text: String
    let date: Date = Date()
    var source: [SourceReference]?
    var markDownString: LocalizedStringKey {
        return LocalizedStringKey(text)
    }
}


extension ChatRole {
    var bubbleColor: Color {
        switch self {
        case .user:      return Color("UserBubble")
        case .assistant: return Color("AssistantBubble")
        case .system:    return Color("SystemBubble")
        }
    }
}

extension ChatMessage {
    func toChatTurn() -> ChatTurn {
        .init(role: role, text: text)
    }
}
