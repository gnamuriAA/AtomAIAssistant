//
//  SpeechRecognizer.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 16/02/26.
//

import Speech
import Combine

final class SpeechRecognizer: NSObject, ObservableObject {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
    private var audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var synthesizer = AVSpeechSynthesizer()
    
    // When the audio engine is running and listening for speech input
    @Published var isListening: Bool = false
    
    // Produced output from the speech recognizer, updated in real-time as the user speaks
    @Published var transcript: String = ""
    
    // When the user actually speaks and the synthesizer is producing speech output
    @Published var isSpeaking: Bool = false
    
    @Published var errorForAudioSession: Error?
    
    // When user stopped speaking so we stopped the audio engine due to silence, but we are still in the listening state
    @Published var isStoppedDueToSilence = false
    
    private var silenceTimer: Timer?
    var silenceTime: CGFloat
    
    init(silenceTime: CGFloat = 4.0) {
        self.silenceTime = silenceTime
        super.init()
        speechRecognizer?.delegate = self
        synthesizer.delegate = self
    }
    
    func startRecording() {
        self.transcript = ""
        guard !audioEngine.isRunning, let speechRecognizer else { return }
        
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            return
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                DispatchQueue.main.async {
                    self.transcript = result.bestTranscription.formattedString
                }
                if self.transcript.count != 0 {
                    self.resetSilenceTimer()
                }
            }
            if error != nil || result?.isFinal == true {
                self.stopRecording()
            }
        }
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, when in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
            
            DispatchQueue.main.async {
                self.isListening = true
            }
        } catch {
            print("Audio engine couldn't start.")
        }
        startSilenceTimer()
    }
    
    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        startSilenceTimer()
    }
    private func startSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceTime, repeats: false, block: { _ in
            if !self.transcript.isEmpty {
                self.stopRecording()
                self.isStoppedDueToSilence = true
            } else {
                if self.isSpeaking {
                    self.resetSilenceTimer()
                    self.isStoppedDueToSilence = false
                }
            }
        })
    }
    
    func speak(text: String) {
        stopSpeaking()
        stopRecording()
        configureAudioSession()
        if let voice = AVSpeechSynthesisVoice(language: "en-US") {
            isSpeaking = true
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = voice
            synthesizer.speak(utterance)
        } else {
            isSpeaking = false
            stopRecording()
        }
    }
    
    func stopRecording() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        audioEngine.inputNode.removeTap(onBus: 0)
        silenceTimer?.invalidate()
        isStoppedDueToSilence = false
        
        DispatchQueue.main.async {
            self.isListening = false
        }
    }
    
    func stopRecordingIfAudioEngineRuns() {
        if audioEngine.isRunning {
            stopRecording()
        }
        silenceTimer?.invalidate()
    }
    
    func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
    
    func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            errorForAudioSession = nil
        } catch {
            errorForAudioSession = NSError(domain: "Unfortunately, we are unable to activate your voice session.", code: 121)
        }
    }
}


extension SpeechRecognizer: SFSpeechRecognizerDelegate {
}

extension SpeechRecognizer: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
}
