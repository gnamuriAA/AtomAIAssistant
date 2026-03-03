//
//  TextToSpeechAudioModel.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 03/03/26.
//

import AVFoundation
import Combine

final class TextToSpeechAudioModel: NSObject, ObservableObject {

    private var player: AVAudioPlayer?
    @Published var isPlaying = false

    override init() {
        player = AVAudioPlayer()
        super.init()
    }

    func speak(_ url: URL) {
        configureAudioSession()
        do {
            if self.isPlaying {
                stop()
            }
            self.player = try AVAudioPlayer(contentsOf: url)
            self.player?.prepareToPlay()
            self.player?.delegate = self
            self.player?.play()
            isPlaying = true
        } catch {
            print("Unable to load AVPlayer \(error)")
        }
    }

    func stop() {
        self.player?.stop()
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set AVAudioSessions with: \(error)")
        }
    }

    deinit {
        player = nil
    }
}

extension TextToSpeechAudioModel: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
    }
}
