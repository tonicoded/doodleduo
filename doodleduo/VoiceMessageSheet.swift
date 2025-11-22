//
//  VoiceMessageSheet.swift
//  doodleduo
//
//  Created by Claude Code
//

import SwiftUI
import AVFoundation
import Combine

struct VoiceMessageSheet: View {
    let partnerName: String
    let onSend: (Data, TimeInterval) async -> Void
    let onCancel: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var audioRecorder = AudioRecorder()
    @State private var isSending = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.4, green: 0.8, blue: 0.9).opacity(0.3),
                        CozyPalette.lightBackground
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 32) {
                    headerView
                    
                    Spacer()
                    
                    recordingInterface
                    
                    Spacer()
                    
                    if audioRecorder.hasRecording {
                        sendButton
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 32)
            }
            .navigationTitle("Voice Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            audioRecorder.requestPermission()
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Text("Record for \(partnerName)")
                .font(.title2.weight(.bold))
                .foregroundColor(.primary)
            
            Text("Tap to start recording, tap again to stop")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var recordingInterface: some View {
        VStack(spacing: 24) {
            // Recording visualizer
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.4, green: 0.8, blue: 0.9),
                                Color(red: 0.3, green: 0.6, blue: 0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .shadow(color: Color(red: 0.4, green: 0.8, blue: 0.9).opacity(0.6), radius: 20, y: 8)
                
                Image(systemName: audioRecorder.isRecording ? "stop.circle.fill" : "mic.fill")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundColor(.white)
            }
            .onTapGesture {
                if audioRecorder.isRecording {
                    audioRecorder.stopRecording()
                } else {
                    audioRecorder.startRecording()
                }
            }
            
            // Recording status
            VStack(spacing: 8) {
                if audioRecorder.isRecording {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(.red)
                            .frame(width: 8, height: 8)
                        Text("Recording...")
                            .font(.callout.weight(.medium))
                            .foregroundColor(.red)
                    }
                } else if audioRecorder.hasRecording {
                    Text("Recording ready to send!")
                        .font(.callout.weight(.medium))
                        .foregroundColor(.green)
                } else {
                    Text("Tap to record")
                        .font(.callout.weight(.medium))
                        .foregroundColor(.secondary)
                }
                
                if let duration = audioRecorder.recordingDuration {
                    Text("\(String(format: "%.1f", duration))s")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var sendButton: some View {
        Button {
            Task {
                await sendRecording()
            }
        } label: {
            HStack(spacing: 8) {
                if isSending {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.body.weight(.bold))
                }
                Text(isSending ? "Sending..." : "Send Voice Message")
                    .font(.body.weight(.bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.4, green: 0.8, blue: 0.9),
                        Color(red: 0.3, green: 0.6, blue: 0.8)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 25, style: .continuous)
            )
            .shadow(color: Color(red: 0.4, green: 0.8, blue: 0.9).opacity(0.5), radius: 12, y: 6)
        }
        .disabled(isSending)
    }
    
    private func sendRecording() async {
        guard let audioData = audioRecorder.getRecordingData(),
              let duration = audioRecorder.recordingDuration else { return }
        
        isSending = true
        await onSend(audioData, duration)
        isSending = false
        
        dismiss()
    }
}

@MainActor
final class AudioRecorder: ObservableObject {
    @Published var isRecording = false
    @Published var hasRecording = false
    @Published var recordingDuration: TimeInterval?
    
    private var audioRecorder: AVAudioRecorder?
    private var audioSession = AVAudioSession.sharedInstance()
    private var recordingURL: URL?
    private var startTime: Date?
    private var timer: Timer?
    
    init() {
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    func requestPermission() {
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { allowed in
                DispatchQueue.main.async {
                    if !allowed {
                        print("Recording permission denied")
                    }
                }
            }
        } else {
            audioSession.requestRecordPermission { allowed in
                DispatchQueue.main.async {
                    if !allowed {
                        print("Recording permission denied")
                    }
                }
            }
        }
    }
    
    func startRecording() {
        guard !isRecording else { return }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        recordingURL = documentsPath.appendingPathComponent("voice_message_\(Date().timeIntervalSince1970).m4a")
        
        guard let url = recordingURL else { return }
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = nil
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            
            isRecording = true
            hasRecording = false
            startTime = Date()
            recordingDuration = 0
            
            // Start timer to update duration
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.updateDuration()
                }
            }
            
            print("🎙️ Started recording")
        } catch {
            print("Failed to start recording: \(error)")
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        timer?.invalidate()
        timer = nil
        
        audioRecorder?.stop()
        isRecording = false
        hasRecording = true
        
        // Calculate final duration
        if let startTime = startTime {
            recordingDuration = Date().timeIntervalSince(startTime)
        }
        
        print("🎙️ Stopped recording, duration: \(recordingDuration ?? 0)s")
    }
    
    private func updateDuration() {
        guard let startTime = startTime else { return }
        recordingDuration = Date().timeIntervalSince(startTime)
    }
    
    func getRecordingData() -> Data? {
        guard let url = recordingURL else { return nil }
        return try? Data(contentsOf: url)
    }
}