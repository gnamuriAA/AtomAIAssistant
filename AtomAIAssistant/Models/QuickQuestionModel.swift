//
//  QuickQuestionModel.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 16/02/26.
//

import Combine
import Foundation

final class QuickQuestionModel: ObservableObject {
    @Published var questions: [QuickQuestion] = []
    private var cancellables = Set<AnyCancellable>()
    @Published var isOnline: Bool = false {
        didSet {
            if isOnline {
                questions = onlineQuickQuestion
            } else {
                questions = offlineQuickQuestion
            }
        }
    }

    init() {}
}

private extension QuickQuestionModel {
    var offlineQuickQuestion: [QuickQuestion] {
        [
            QuickQuestion(iconName: "apps.ipad", question: "iPad accessories", title: "iPad Accessories"),
            QuickQuestion(iconName: "pencil.circle", question: "What is the price of Apple Pencil?", title: "Pencil Price"),
            QuickQuestion(iconName: "text.document", question: "If the order has been full invoiced, will it be converted in coupa?", title: "COUPA Support")
        ]
    }
    
    var onlineQuickQuestion: [QuickQuestion] {
        [
            QuickQuestion(iconName: "camera.fill", question: "How do I use the camera on the iPad?", title: "iPad Camera"),
            QuickQuestion(iconName: "wifi", question: "How do I connect to Wi-Fi?", title: "Wi-Fi Setup"),
            QuickQuestion(iconName: "airplane.up.forward.app.fill", question: "What are the quick start steps?", title: "Quick Start")
        ]
    }
}

struct QuickQuestion: Identifiable, Hashable {
    let id = UUID()
    let iconName: String
    let question: String
    let title: String
}
