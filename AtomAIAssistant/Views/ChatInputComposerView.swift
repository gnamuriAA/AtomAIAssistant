//
//  ChatInputComposerView.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 01/03/26.
//

import SwiftUI

struct ChatInputComposerView: View {
    enum TrailingMode {
        case compact, expanded, recording
    }
    
    var placeholder: String = "Ask anything"
    var showAvatarInExpanded = false
    
    var onSendText: ((String) -> Void)
    var onTapPlus: () -> Void
    var onStartVoice: () -> Void
    var onStopVoice: () -> Void
    var onSendVoice: () -> Void
    var onInlineMic: () -> Void
    
    @State private var text: String = ""
    @FocusState private var isFocused: Bool
    @State private var mode: TrailingMode = .compact
    
    @State private var usingRealMicLevel = true
    @State private var simulatedLevel: CGFloat = 0.2
    
    private let barHeight: CGFloat = 56
    private let pillRadius: CGFloat = 22
    
    var body: some View {
        VStack(spacing: 14) {
            // Avatar in expanded mode (like your 2nd screenshot)
            if showAvatarInExpanded, mode == .expanded {
                Image("assistantAvatar") // replace with your asset name
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 64)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
                    .transition(.scale.combined(with: .opacity))
            }
            
            switch mode {
            case .recording:
                recordingBar
            default:
                mainComposerBar
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.9), value: mode)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .onDisappear {
//            stopMeter()
        }
    }
}

// MARK: - Subview
private extension ChatInputComposerView {
    var mainComposerBar: some View {
        HStack(spacing: 12) {
            // Left: +
            CircleButton(symbol: "plus", fg: AnyShapeStyle(.primary), bg: AnyShapeStyle(.ultraThinMaterial), size: 44) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onTapPlus()
            }
            
            // Center: pill field with inline mic
            HStack(spacing: 10) {
                TextField(placeholder, text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .font(.system(size: 17))
                    .foregroundStyle(Color.primary.opacity(text.isEmpty ? 0.6 : 1))
                    .submitLabel(.send)
                    .onSubmit(sendIfNeeded)
                    .onChange(of: text) { oldValue, newValue in
                        withAnimation(.easeInOut) {
                            simulatedLevel = min(1.0, CGFloat(newValue.count) / 20.0)
                        }
                    }

                if mode != .expanded {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        // Enter recording directly from inline mic
                        enterRecording()
                        onInlineMic()
                    } label: {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: pillRadius, style: .continuous)
                    .fill(Color(.secondarySystemFill))
            )
            .overlay(
                RoundedRectangle(cornerRadius: pillRadius)
                    .strokeBorder(.white.opacity(0.35), lineWidth: 0.5)
            )
            .frame(height: barHeight)
            
            // Right: waveform/send in compact, close in expanded
            rightComposerView
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 10, y: 2)
        .onChange(of: isFocused) { isFocused in
            // Optional: if focusing the text should collapse expanded
            if isFocused, mode == .expanded {
                withAnimation { mode = .compact }
            }
        }
    }

    private var rightComposerView: some View {
            Group {
                switch mode {
                case .compact:
                    CircleButton(symbol: text.isEmpty ? "waveform" : "paperplane.fill", fg: AnyShapeStyle(.white), bg: AnyShapeStyle(.black), size: 44) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        if text.isEmpty {
                            withAnimation { mode = .expanded }
                        } else {
                            sendIfNeeded()
                        }
                    }

                case .expanded:
                    expandedControlsRow
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                case .recording:
                    EmptyView()
                }
            }
            .transition(.scale.combined(with: .opacity))
        }
    
    private var recordingBar: some View {
        HStack(spacing: 12) {
            CircleButton(symbol: "stop.fill", fg: AnyShapeStyle(Color.black), bg: AnyShapeStyle(.ultraThinMaterial), size: 44) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation { mode = .compact }
//                onStopVoice()
//                stopMeter()
                // TODO: - Stop button action when inline mic is turned on and this will not read out the received messages.
            }
            
            LevelMeterPill(level: simulatedLevel)
                .frame(maxWidth: .infinity)
            
            CircleButton(symbol: "arrow.up", fg: AnyShapeStyle(.white), bg: AnyShapeStyle(.ultraThinMaterial), size: 44) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation { mode = .compact }
//                onSendVoice()
//                stopMeter()
                // TODO: - Decide to upload the image or show error when there is no text from the voice given by the user.
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 10, y: 2)
    }

    var expandedControlsRow: some View {
        HStack(spacing: 12) {
            CircleButton(symbol: "mic.fill", fg: AnyShapeStyle(.white), bg: AnyShapeStyle(.black), size: 40) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                // TODO: - This should be muting the from user side
//                onStartVoice()
            }
            CircleButton(symbol: "xmark", fg: AnyShapeStyle(.white), bg: AnyShapeStyle(.black), size: 40) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation { mode = .compact }
                // TODO: - close button
            }
        }
    }

    func enterRecording() {
        withAnimation { mode = .recording }
//        if usingRealMicLevels {
//            try? micMonitor.start()  // ensure NSMicrophoneUsageDescription is in Info.plist
//        } else {
//            startSimulatedMeter()
//        }
        onStartVoice()
    }

    private func sendIfNeeded() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSendText(trimmed)
        text.removeAll()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
            mode = .compact
        }
        isFocused = false
        UINotificationFeedbackGenerator().notificationOccurred(.success) // To vibrate the phone on send
    }
}

fileprivate struct CircleButton: View {
    var symbol: String
    var fg: AnyShapeStyle
    var bg: AnyShapeStyle
    var size: CGFloat = 14
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(bg)
                    .frame(width: size, height: size)
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(fg)
            }
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
    }
}

#Preview {
    ChatInputComposerView(onSendText: {_ in }, onTapPlus: {}, onStartVoice: {}, onStopVoice: {}, onSendVoice: {}, onInlineMic: {})
}
