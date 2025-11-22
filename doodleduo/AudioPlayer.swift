//
//  AudioPlayer.swift
//  doodleduo
//
//  Audio playback functionality for voice messages
//

import Foundation
import AVFoundation
import SwiftUI
import Combine

@MainActor
final class AudioPlayer: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var playbackError: String?
    
    private var audioPlayer: AVAudioPlayer?
    private var playbackTimer: Timer?
    private let audioSession = AVAudioSession.sharedInstance()
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
        } catch {
            print("Failed to set up audio session for playback: \(error)")
        }
    }
    
    func play(audioData: Data) {
        stop() // Stop any current playback
        
        do {
            audioPlayer = try AVAudioPlayer(data: audioData)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            
            duration = audioPlayer?.duration ?? 0
            
            if let player = audioPlayer {
                player.play()
                isPlaying = true
                startPlaybackTimer()
                playbackError = nil
                print("🎵 Started playing voice message, duration: \(duration)s")
            }
        } catch {
            playbackError = "Failed to play audio: \(error.localizedDescription)"
            print("❌ Audio playback error: \(error)")
        }
    }
    
    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        currentTime = 0
        stopPlaybackTimer()
        print("⏹️ Stopped audio playback")
    }
    
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopPlaybackTimer()
    }
    
    func resume() {
        audioPlayer?.play()
        isPlaying = true
        startPlaybackTimer()
    }
    
    private func startPlaybackTimer() {
        stopPlaybackTimer()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor [weak self] in
                self?.updatePlaybackTime()
            }
        }
    }
    
    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    private func updatePlaybackTime() {
        guard let player = audioPlayer else { return }
        currentTime = player.currentTime
    }
}

extension AudioPlayer: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            isPlaying = false
            currentTime = 0
            stopPlaybackTimer()
            print("🎵 Audio playback finished")
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            isPlaying = false
            playbackError = error?.localizedDescription ?? "Audio decode error"
            stopPlaybackTimer()
            print("❌ Audio decode error: \(error?.localizedDescription ?? "unknown")")
        }
    }
}