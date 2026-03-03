//
//  AskAssistantIntent.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 03/03/26.
//

import AppIntents
import SwiftUI

struct AskAssistantIntent: AppIntent {
    static var title: LocalizedStringResource = "Ask Assistant"
    static var description = IntentDescription(
        "Ask any question to the in‑app assistant.",
        categoryName: "Assistant"
    )

    // This allows Siri to suggest and match natural utterances better.
    static var openAppWhenRun: Bool = false  // set true if you ALWAYS want to open the app

    @Parameter(title: "Question")
    var question: String

    // If you want a nicer transcription in Siri’s UI:
    static var parameterSummary: some ParameterSummary {
        Summary("Ask question to ATOM assistant: \(\.$question)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let askedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let answer = try await AskAssistantAPI.ask(question: askedQuestion)

        return .result(
            dialog: "Here's what I found",
            view: AssistantSnipperView(title: askedQuestion, answer: answer)
        )
    }
}

struct AssistantShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
              intent: AskAssistantIntent(),
              phrases: [
                "Ask \(.applicationName)",
                "\(.applicationName) question"
              ],
              shortTitle: "Ask Assistant",
              systemImageName: "mic.and.signal.meter"
          )

    }
}


struct AskAssistantAPI {
    static let sessionIdKey = UUID().uuidString
    static func ask(question: String) async throws -> String {
        let client = AtomAIAssistantClient()
        let response = try await client.ask(query: question, sessionId: sessionIdKey)
        return response.answer
    }
}

struct AssistantSnipperView: View {
    let title: String
    let answer: String
    var sources: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "atom")
                    .resizable()
                    .frame(width: 20, height: 20)
                
                Text(title.isEmpty ? "Answer" : title)
                    .font(.headline)
                
                Spacer()
            }
            
            Divider()
            
            markdownText(answer)
            
            if let sources {
                Divider()
                Text(sources)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
        }
        .padding()
    }

    @ViewBuilder
    private func markdownText(_ text: String) -> some View {
        if let attributedString = try? AttributedString(markdown: text) {
            Text(attributedString)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(text)
                .font(.subheadline)
        }
    }
}
