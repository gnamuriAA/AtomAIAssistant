//
//  ChatInputComposerView.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 01/03/26.
//

import SwiftUI

public struct ChatInputComposerView: View {
    enum TrailingMode {
        case compact, expanded, recording
    }
    
    private var placeholder: String = "Ask anything"
    private var showAvatarInExpanded = true
    
    @Binding var text: String
    @Binding var isStoppedDueToSilence: Bool
    @Binding var isSpeaking: Bool
    var onSendText: ((String) -> Void)
    var onTapPlus: () -> Void
    var onStartVoice: () -> Void
    var onStopSpeaking: () -> Void
    var onStopVoice: () -> Void
    var onInlineMic: () -> Void
    @State private var phase: CGFloat = 0.0
    @State private var animateWave: Bool = false

    private var shouldDisableSpeakerButton: Bool {
        if mode == .expanded {
            if isSpeaking {
                return false
            }
            return true
        }
        return false
    }

    public init(text: Binding<String>, isStoppedDueToSilence: Binding<Bool>, isSpeaking: Binding<Bool>, onSendText: @escaping (String) -> Void, onTapPlus: @escaping () -> Void, onStartVoice: @escaping () -> Void, onStopSpeaking: @escaping () -> Void, onStopVoice: @escaping () -> Void, onInlineMic: @escaping () -> Void) {
        self._text = text
        self._isStoppedDueToSilence = isStoppedDueToSilence
        self.onSendText = onSendText
        self.onTapPlus = onTapPlus
        self.onStartVoice = onStartVoice
        self.onStopVoice = onStopVoice
        self.onInlineMic = onInlineMic
        self.onStopSpeaking = onStopSpeaking
        self._isSpeaking = isSpeaking
    }

    @FocusState private var isFocused: Bool
    @State private var mode: TrailingMode = .compact
    
    @State private var usingRealMicLevel = true
    @State private var simulatedLevel: CGFloat = 0.2
    @State private var isAnimating = false
    
    private let barHeight: CGFloat = 56
    private let pillRadius: CGFloat = 22
    
    public var body: some View {
        VStack {
            if showAvatarInExpanded, mode == .expanded {
                Image("assistantAvatar")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 64)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
                    .transition(.scale.combined(with: .opacity))
                    .scaleEffect(isAnimating ? 1.0 : 1.2)
                    .animation(
                        Animation.linear(duration: 1.2) // speed
                            .repeatForever(autoreverses: true),
                        value: isAnimating
                    )
                    .onAppear {
                        isAnimating = true
                    }
            }
            VStack(spacing: 14) {
                Divider()
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
            .onChange(of: isStoppedDueToSilence, { oldValue, newValue in
                if isStoppedDueToSilence {
                    withAnimation {
                        if mode == .recording {
                            mode = .compact
                        } else {
                            sendIfNeeded()
                        }
                    }
                }
            })
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
        .onChange(of: isFocused) { oldValue, newValue in
            // Optional: if focusing the text should collapse expanded
            if newValue, mode == .expanded {
                withAnimation { mode = .compact }
            }
        }
    }

    private var rightComposerView: some View {
            Group {
                switch mode {
                case .compact:
                    CircleButton(symbol: text.isEmpty ? "waveform" : "arrow.up", fg: AnyShapeStyle(.white), bg: AnyShapeStyle(.black), size: 44) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onStartVoice()
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
                onStopVoice()
            }
            
            LevelMeterPill(isAnimating: $animateWave)
                .frame(maxWidth: .infinity)
                .animation(.easeInOut, value: simulatedLevel)
                .onAppear {
                    Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { _ in
                        phase -= 0.01 // Move wave to the left
                    }
                }
                .onChange(of: text) { oldValue, newValue in
                    animateWave = !newValue.isEmpty
                    if animateWave {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            animateWave = false
                        }
                    }
                }
            
            CircleButton(symbol: "arrow.up", fg: AnyShapeStyle(.white), bg: AnyShapeStyle(.black), size: 44) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation { mode = .compact }
            }
            .disabled(text.isEmpty)
            .opacity(text.isEmpty ? 0.5 : 1.0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 10, y: 2)
    }

    var expandedControlsRow: some View {
        HStack(spacing: 12) {
            CircleButton(symbol: mode == .expanded ? "speaker.slash" : "mic.fill",
                         fg: AnyShapeStyle(.white),
                         bg: AnyShapeStyle(.black),
                         size: 40) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                // TODO: - This should be muting the from user side, if mode is expand then we need to mute
                if mode == .expanded {
                    onStopSpeaking()
                } else {
                    onStartVoice()
                }
            }
                         .disabled(shouldDisableSpeakerButton)
            
            CircleButton(symbol: "xmark", fg: AnyShapeStyle(.white), bg: AnyShapeStyle(.black), size: 40) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation { mode = .compact }
                onStopVoice()
            }
        }
    }

    func enterRecording() {
        withAnimation { mode = .recording }
    }

    private func sendIfNeeded() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSendText(trimmed)
        text.removeAll()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
            if mode == .recording {
                mode = .compact
            }
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
    ChatInputComposerView(text: .constant(""), isStoppedDueToSilence: .constant(false), isSpeaking: .constant(false), onSendText: {_ in }, onTapPlus: {}, onStartVoice: {}, onStopSpeaking: {}, onStopVoice: {}, onInlineMic: {})
}
