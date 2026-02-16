//
//  QuickQuestionModel.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 16/02/26.
//

import Combine

final class QuickQuestionModel: ObservableObject {
    @Published var questions: [String] = []
    private var cancellables = Set<AnyCancellable>()
    @Published var isOnline: Bool = false {
        didSet {
            if isOnline {
                questions = Array(onlineQuickQuestion.keys)
            } else {
                questions = Array(offlineQuickQuestion.keys)
            }
        }
    }

    init() {}

    func getQuestion(for key: String) -> String {
        return onlineQuickQuestion[key] ?? offlineQuickQuestion[key] ?? ""
    }
}

private extension QuickQuestionModel {
    var offlineQuickQuestion: [String: String] {
        ["iPad Accessories": "What are the available iPad accessories?", "Pencil Price" :"What is the price of Apple Pencil?", "COUPA Support": "If the order has been full invoiced, will it be converted in coupa?"]
    }

    var onlineQuickQuestion: [String: String] {
        ["iPad Camera": "How do I use the camera on the iPad?", "Wi-Fi Setup": "How do I connect to Wi-Fi?", "Quick Start": "What are the quick start steps?"]
    }
}
