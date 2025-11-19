//
//  BackgroundAudioManager.swift
//  doodleduo
//
//  Created by Anthony Verruijt on 16/11/2025.
//

import Foundation
import AVFoundation
import Combine

final class BackgroundAudioManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    private static let muteKey = "doodleduo.audio.muted"
    private let trackNames = ["bgmusic1", "bgmusic2", "bgmusic3", "bgmusic4", "bgmusic5"]
    
    @Published var isMuted: Bool {
        didSet {
            UserDefaults.standard.set(isMuted, forKey: Self.muteKey)
            applyMute(animated: true)
        }
    }
    
    private var availableTracks: [String] = []
    private var currentTrackIndex: Int = 0
    private var player: AVAudioPlayer?
    private let baseVolume: Float = 0.55
    
    override init() {
        let stored = UserDefaults.standard.object(forKey: Self.muteKey) as? Bool ?? false
        self.isMuted = stored
        super.init()
        availableTracks = loadAvailableTracks()
        if !availableTracks.isEmpty {
            currentTrackIndex = Int.random(in: 0..<availableTracks.count)
        }
        configureSession()
        preparePlayer()
    }
    
    func startIfNeeded() {
        guard let player else { return }
        if !player.isPlaying {
            player.play()
        }
        applyMute(animated: false)
    }
    
    func toggleMute() {
        isMuted.toggle()
    }
    
    private func configureSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("Audio session configuration failed: \(error.localizedDescription)")
        }
    }
    
    private func loadAvailableTracks() -> [String] {
        let bundle = Bundle.main
        return trackNames.filter { bundle.url(forResource: $0, withExtension: "mp3") != nil }
    }
    
    private func preparePlayer() {
        guard !availableTracks.isEmpty else { return }
        currentTrackIndex = currentTrackIndex % availableTracks.count
        let track = availableTracks[currentTrackIndex]
        guard let url = Bundle.main.url(forResource: track, withExtension: "mp3") else {
            advanceTrack()
            return
        }
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.volume = isMuted ? 0 : baseVolume
            player?.prepareToPlay()
        } catch {
            print("Failed to load track \(track): \(error.localizedDescription)")
            advanceTrack()
        }
    }
    
    private func advanceTrack() {
        guard !availableTracks.isEmpty else { return }
        currentTrackIndex = (currentTrackIndex + 1) % availableTracks.count
        preparePlayer()
        if let player, !isMuted {
            player.play()
        }
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        advanceTrack()
    }
    
    private func applyMute(animated: Bool) {
        let targetVolume: Float = isMuted ? 0 : baseVolume
        if animated {
            player?.setVolume(targetVolume, fadeDuration: 0.4)
        } else {
            player?.volume = targetVolume
        }
        if isMuted {
            player?.pause()
        } else {
            player?.play()
        }
    }
}
