//
//  ChatInitialView.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 03/03/26.
//

import SwiftUI

struct ChatInitialView: View {
    @State private var isSpinning = false
    @ObservedObject var chatViewModel: ChatViewModel
    var action: (String) -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Spacer()
                Image("atom")
                    .resizable()
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(isSpinning ? 360 : 0))
                    .animation(
                        Animation.linear(duration: 1.2) // speed
                            .repeatForever(autoreverses: false),
                        value: isSpinning
                    )
                    .onAppear {
                        isSpinning = true
                    }
                    .padding()
                
                Text("Hello")
                    .foregroundStyle(.secondary)
                    .font(.title)
                    .padding()
                
                Text("What's on your mind?")
                    .foregroundStyle(.primary)
                    .font(.title2)
                    .padding()
                
                QuickQuestions(viewModel: chatViewModel, action: action)
                    .padding(.leading)
                
                Spacer()
            }
            .padding(.leading, 24)
            Spacer()
        }
    }
}
