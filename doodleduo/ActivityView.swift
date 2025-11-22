//
//  ActivityView.swift
//  doodleduo
//
//  Created by Claude Code on 17/11/2025.
//

import SwiftUI
import UIKit
import PencilKit
import WidgetKit

struct ActivityView: View {
    @ObservedObject var sessionManager: CoupleSessionManager
    @ObservedObject var authService: AuthService
    @ObservedObject private var photoManager = PhotoManager.shared
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var newNote: String = ""
    @State private var activities: [DuoActivity] = []
    @State private var isLoading = false
    @State private var loadingTask: Task<Void, Never>?
    @State private var liveUpdateTimer: Timer?
    @State private var sendingActivity = false
    @State private var lastSentType: DuoActivity.ActivityType?
    @State private var timeUpdateTimer: Timer?
    @State private var currentTime = Date()
    @State private var currentPage = 0
    private let activitiesPerPage = 10
    @State private var showingNoteSheet = false
    @State private var showingDoodleSheet = false
    @State private var showingVoiceSheet = false
    @State private var loadErrorMessage: String?
    
    var body: some View {
        ZStack {
            CozyPalette.background(for: colorScheme)
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    headerView
                    doodleStudioCard
                    quickActionsCard
                    activityFeedSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 36)
            }
        }
        .sheet(isPresented: $showingNoteSheet) {
            NoteComposerSheet(
                newNote: $newNote,
                sendingActivity: $sendingActivity,
                onSend: {
                    sendNote()
                    showingNoteSheet = false
                },
                onCancel: {
                    showingNoteSheet = false
                    newNote = ""
                }
            )
        }
        .sheet(isPresented: $showingDoodleSheet) {
            LiveDoodleSheet(
                partnerName: friendlyName(from: sessionManager.partnerName) ?? sessionManager.partnerName ?? "partner",
                accentColor: CozyPalette.warmPink,
                onSend: { drawing in
                    await sendDoodleDrawing(drawing)
                },
                onCancel: {
                    showingDoodleSheet = false
                }
            )
        }
        .sheet(isPresented: $showingVoiceSheet) {
            VoiceMessageSheet(
                partnerName: friendlyName(from: sessionManager.partnerName) ?? sessionManager.partnerName ?? "partner",
                onSend: { audioData, duration in
                    await sendVoiceMessage(audioData, duration: duration)
                },
                onCancel: {
                    showingVoiceSheet = false
                }
            )
        }
        .task {
            await loadActivitiesSafely()
            startLiveUpdates()
            startTimeUpdates()
        }
        .onAppear {
            Task {
                await loadActivitiesSafely()
                try? await sessionManager.refreshMetrics()
                await photoManager.refreshPartnerPhoto()
            }
        }
        .onDisappear {
            loadingTask?.cancel()
            liveUpdateTimer?.invalidate()
            timeUpdateTimer?.invalidate()
        }
    }
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let partnerName = sessionManager.partnerName {
                HStack(spacing: 10) {
                    Image(systemName: "heart.circle.fill")
                        .font(.title2)
                        .foregroundColor(CozyPalette.warmPink)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("you & \(friendlyName(from: partnerName) ?? partnerName)")
                            .font(.headline.weight(.semibold))
                        Text("room \(sessionManager.roomID ?? "—")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    liveBadge
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
            }
            
            HStack(spacing: 12) {
                StatBadge(
                    icon: "heart.fill",
                    label: "love energy",
                    value: "\(sessionManager.metrics?.loveEnergy ?? 0)",
                    gradient: [
                        Color(red: 0.98, green: 0.63, blue: 0.71),
                        Color(red: 0.93, green: 0.27, blue: 0.36)
                    ],
                    glowColor: Color(red: 0.93, green: 0.27, blue: 0.36),
                    animateHeart: false,
                    symbolColor: Color(red: 1.0, green: 0.82, blue: 0.88)
                )
                
                StatBadge(
                    icon: "calendar.badge.clock",
                    label: "days survived",
                    value: survivalTimeText,
                    gradient: [
                        Color(red: 0.67, green: 0.91, blue: 0.76),
                        Color(red: 0.41, green: 0.73, blue: 0.93)
                    ],
                    glowColor: Color(red: 0.45, green: 0.77, blue: 0.76),
                    symbolColor: Color(red: 0.24, green: 0.53, blue: 0.82)
                )
            }
        }
    }
    
    private var liveBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.green)
                .frame(width: 10, height: 10)
                .shadow(color: .green, radius: 4)
            Text("live")
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.black.opacity(0.15)))
    }

    private var survivalTimeText: String {
        guard let farm = sessionManager.farm else {
            return "0d 0h 0m"
        }

        let elapsed = Date().timeIntervalSince(farm.createdAt)
        let days = Int(elapsed / (24 * 3600))
        let hours = Int((elapsed.truncatingRemainder(dividingBy: 24 * 3600)) / 3600)
        let minutes = Int((elapsed.truncatingRemainder(dividingBy: 3600)) / 60)
        return "\(days)d \(hours)h \(minutes)m"
    }
    
    private var doodleStudioCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [CozyPalette.mintGreen, CozyPalette.mintGreen.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                        .shadow(color: CozyPalette.mintGreen.opacity(0.4), radius: 12, y: 6)
                    
                    Image(systemName: "paintpalette.fill")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("creative studio")
                        .font(.title2.weight(.bold))
                        .foregroundColor(.primary)
                    Text("Collaborate on digital artwork together")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(sessionManager.partnerName != nil ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                        Text("Status")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Text(sessionManager.partnerName == nil ? "Waiting for partner" : "Ready to create")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                VStack(spacing: 8) {
                    Button {
                        showingDoodleSheet = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "paintbrush.fill")
                                .font(.body.weight(.bold))
                            Text("draw")
                                .font(.body.weight(.bold))
                                .lineLimit(1)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [CozyPalette.mintGreen, CozyPalette.mintGreen.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: RoundedRectangle(cornerRadius: 25, style: .continuous)
                        )
                        .shadow(color: CozyPalette.mintGreen.opacity(0.4), radius: 8, y: 4)
                    }
                    .buttonStyle(.plain)
                    .disabled(sessionManager.partnerName == nil)
                    .opacity(sessionManager.partnerName == nil ? 0.6 : 1)
                    
                    Text("+10 pts")
                        .font(.caption.weight(.bold))
                        .foregroundColor(CozyPalette.mintGreen)
                }
            }
            
            // Feature highlights
            HStack(spacing: 20) {
                featureItem(icon: "arrow.clockwise", text: "Live sync")
                featureItem(icon: "paintbrush.pointed", text: "Brushes")
                featureItem(icon: "square.and.arrow.down", text: "Share")
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(CozyPalette.cardBackground(for: colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(CozyPalette.mintGreen.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.08), radius: 20, y: 10)
        )
    }
    
    private func featureItem(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(CozyPalette.mintGreen)
            Text(text)
                .font(.caption.weight(.medium))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
    
    private var activityFeedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("latest moments")
                        .font(.headline)
                    Text(activities.isEmpty ? "No updates yet" : "Updated \(currentTime, format: .dateTime.hour().minute())")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if hasMorePages {
                    Button("more") {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            currentPage += 1
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
                }
            }
            
            if isLoading && activities.isEmpty {
                loadingStateView
            } else if let loadErrorMessage, activities.isEmpty {
                errorStateView(message: loadErrorMessage)
            } else if activities.isEmpty {
                emptyStateView
            } else {
                VStack(spacing: 12) {
                    ForEach(paginatedActivities) { activity in
                        SimpleActivityCard(
                            activity: activity,
                            currentUserName: sessionManager.myDisplayName ?? "you",
                            partnerName: sessionManager.partnerName ?? "partner",
                            currentUserId: authService.currentUser?.id,
                            currentTime: currentTime,
                            photoManager: photoManager
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(CozyPalette.cardBackground(for: colorScheme))
                .shadow(color: .black.opacity(0.05), radius: 20, y: 10)
        )
    }
    
    
    private var paginatedActivities: [DuoActivity] {
        let endIndex = min((currentPage + 1) * activitiesPerPage, activities.count)
        return Array(activities.prefix(endIndex))
    }
    
    private var hasMorePages: Bool {
        return activities.count > (currentPage + 1) * activitiesPerPage
    }
    
    private var quickActionsCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("express yourself")
                        .font(.title2.weight(.bold))
                    Text("Share emotions and moments with your partner")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if sendingActivity {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(CozyPalette.warmPink)
                }
            }
            
            // Main gesture actions
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                EnhancedActionButton(
                    icon: "💖",
                    label: "ping",
                    points: "+2",
                    tint: DuoActivity.ActivityType.ping.color,
                    action: sendPing,
                    isActive: lastSentType == .ping,
                    isDisabled: sessionManager.partnerName == nil || sendingActivity
                )
                
                EnhancedActionButton(
                    icon: "🤗",
                    label: "hug",
                    points: "+3",
                    tint: DuoActivity.ActivityType.hug.color,
                    action: sendHug,
                    isActive: lastSentType == .hug,
                    isDisabled: sessionManager.partnerName == nil || sendingActivity
                )
                
                EnhancedActionButton(
                    icon: "😘",
                    label: "kiss",
                    points: "+4",
                    tint: DuoActivity.ActivityType.kiss.color,
                    action: sendKiss,
                    isActive: lastSentType == .kiss,
                    isDisabled: sessionManager.partnerName == nil || sendingActivity
                )
                
                EnhancedActionButton(
                    icon: "💝",
                    label: "surprise",
                    points: "+5",
                    tint: Color.purple,
                    action: sendSurprise,
                    isActive: lastSentType == .ping,
                    isDisabled: sessionManager.partnerName == nil || sendingActivity
                )
            }
            
            // Additional gesture row
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                EnhancedActionButton(
                    icon: "🌟",
                    label: "sparkle",
                    points: "+3",
                    tint: Color.yellow,
                    action: sendSparkle,
                    isActive: false,
                    isDisabled: sessionManager.partnerName == nil || sendingActivity
                )
                
                EnhancedActionButton(
                    icon: "🎉",
                    label: "celebrate",
                    points: "+4",
                    tint: Color.orange,
                    action: sendCelebrate,
                    isActive: false,
                    isDisabled: sessionManager.partnerName == nil || sendingActivity
                )
                
                EnhancedActionButton(
                    icon: "☕",
                    label: "coffee",
                    points: "+2",
                    tint: Color.brown,
                    action: sendCoffee,
                    isActive: false,
                    isDisabled: sessionManager.partnerName == nil || sendingActivity
                )
                
                EnhancedActionButton(
                    icon: "🌙",
                    label: "goodnight",
                    points: "+3",
                    tint: Color.indigo,
                    action: sendGoodnight,
                    isActive: false,
                    isDisabled: sessionManager.partnerName == nil || sendingActivity
                )
            }
            
            Divider()
                .background(Color.white.opacity(0.2))
            
            // Enhanced action buttons
            VStack(spacing: 12) {
                Button {
                    showingNoteSheet = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "square.and.pencil")
                            .font(.title3.weight(.semibold))
                            .frame(width: 24, height: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Write a love note")
                                .font(.body.weight(.bold))
                            Text("Share your thoughts and feelings (+5 pts)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.85))
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.95, green: 0.39, blue: 0.8),
                                        Color(red: 0.8, green: 0.4, blue: 0.9)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .shadow(color: Color(red: 0.95, green: 0.39, blue: 0.8).opacity(0.4), radius: 12, x: 0, y: 6)
                }
                .buttonStyle(.plain)
                .disabled(sessionManager.partnerName == nil || sendingActivity)
                .opacity(sessionManager.partnerName == nil ? 0.6 : 1)
                
                Button {
                    showingVoiceSheet = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "mic.fill")
                            .font(.title3.weight(.semibold))
                            .frame(width: 24, height: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Send voice message")
                                .font(.body.weight(.bold))
                            Text("Record a sweet message (+8 pts)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.85))
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.4, green: 0.8, blue: 0.9),
                                        Color(red: 0.3, green: 0.6, blue: 0.8)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .shadow(color: Color(red: 0.4, green: 0.8, blue: 0.9).opacity(0.4), radius: 12, x: 0, y: 6)
                }
                .buttonStyle(.plain)
                .disabled(sessionManager.partnerName == nil || sendingActivity)
                .opacity(sessionManager.partnerName == nil ? 0.6 : 1)
            }
            
            if sessionManager.partnerName == nil {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(Color.orange)
                    Text("Invite your partner to unlock all expressions")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.green)
                    Text("All expressions unlocked! Share the love ✨")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(CozyPalette.cardBackground(for: colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.08), radius: 20, y: 10)
        )
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 14) {
            Text("💝")
                .font(.system(size: 64))
            Text("start your first moment")
                .font(.title3.weight(.semibold))
            Text("Send a doodle, ping, or note to watch your farm sparkle.")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            if let roomId = sessionManager.roomID, sessionManager.partnerName == nil {
                Text("share room code \(roomId) to begin together")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var loadingStateView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
            Text("Loading shared moments…")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }
    
    private func errorStateView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "icloud.slash")
                .font(.system(size: 44))
                .foregroundStyle(Color.orange)
            Text("Can’t reach Supabase")
                .font(.headline)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            Button {
                Task { await loadActivitiesSafely() }
            } label: {
                Text("Try again")
                    .font(.callout.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }
    
    private func sendPing() {
        Task {
            await sendActivityWithFeedback(type: .ping, content: "sent a love ping 💖")
        }
    }
    
    private func sendHug() {
        Task {
            await sendActivityWithFeedback(type: .hug, content: "sent a virtual hug 🤗")
        }
    }
    
    private func sendKiss() {
        Task {
            await sendActivityWithFeedback(type: .kiss, content: "blew a kiss 😘")
        }
    }
    
    private func sendSurprise() {
        Task {
            await sendActivityWithFeedback(type: .note, content: "sent you a surprise! 💝")
        }
    }
    
    private func sendSparkle() {
        Task {
            await sendActivityWithFeedback(type: .note, content: "sprinkled some magic ✨")
        }
    }
    
    private func sendCelebrate() {
        Task {
            await sendActivityWithFeedback(type: .note, content: "is celebrating with you! 🎉")
        }
    }
    
    private func sendCoffee() {
        Task {
            await sendActivityWithFeedback(type: .note, content: "wants to have coffee with you ☕")
        }
    }
    
    private func sendGoodnight() {
        Task {
            await sendActivityWithFeedback(type: .note, content: "wishes you sweet dreams 🌙")
        }
    }
    
    private func sendNote() {
        let noteText = newNote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !noteText.isEmpty else { return }
        
        Task {
            await sendActivityWithFeedback(type: .note, content: noteText)
            
            await MainActor.run {
                newNote = ""
            }
        }
    }
    
    private func sendVoiceMessage(_ audioData: Data, duration: TimeInterval) async {
        // Store audio data as base64 with metadata
        let base64Audio = audioData.base64EncodedString()
        let content = "voice_message:\(String(format: "%.0f", duration)):\(base64Audio)"
        
        await sendActivityWithFeedback(type: .note, content: content)
        
        await MainActor.run {
            showingVoiceSheet = false
        }
    }
    
    private func sendActivityWithFeedback(type: DuoActivity.ActivityType, content: String) async {
        await MainActor.run {
            sendingActivity = true
            lastSentType = type
        }
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        await sendActivity(type: type, content: content)
        
        // Success feedback
        await MainActor.run {
            sendingActivity = false
            
            // Clear the last sent type after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                lastSentType = nil
            }
        }
        
        let successFeedback = UINotificationFeedbackGenerator()
        successFeedback.notificationOccurred(.success)
    }
    
    private func sendDoodleDrawing(_ drawing: PKDrawing) async {
        guard !drawing.bounds.isEmpty else { return }
        let image = await MainActor.run { () -> UIImage in
            let expanded = drawing.bounds.insetBy(dx: -24, dy: -24)
            return drawing.image(from: expanded, scale: currentScreenScale())
        }
        guard let data = image.pngData() else { return }
        
        
        let base64 = data.base64EncodedString()
        await sendActivityWithFeedback(type: .doodle, content: "data:image/png;base64,\(base64)")
    }
    
    private func startLiveUpdates() {
        liveUpdateTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            Task {
                await loadActivitiesSafely()
                try? await sessionManager.refreshMetrics()
            }
        }
    }
    
    private func sendActivity(type: DuoActivity.ActivityType, content: String) async {
        print("🚀 Attempting to send \(type) activity")
        print("📍 currentRoomID:", sessionManager.currentRoomID?.uuidString ?? "nil")
        print("👤 currentUser:", authService.currentUser?.id.uuidString ?? "nil")
        print("🔑 session exists:", authService.session != nil ? "yes" : "no")
        
        guard let roomId = sessionManager.currentRoomID,
              let userId = authService.currentUser?.id,
              let session = authService.session else {
            print("❌ Missing required data for activity:")
            print("   roomId:", sessionManager.currentRoomID?.uuidString ?? "nil")
            print("   userId:", authService.currentUser?.id.uuidString ?? "nil") 
            print("   session:", authService.session != nil ? "exists" : "nil")
            return
        }
        
        do {
            // Create activity in database
            let environment = SupabaseEnvironment.makeCurrent()
            var request = URLRequest(url: environment.restURL.appendingPathComponent("duo_activities"))
            request.httpMethod = "POST"
            request.allHTTPHeaderFields = environment.headers(accessToken: session.accessToken)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("return=representation", forHTTPHeaderField: "Prefer")
            
            let payload = [
                "room_id": roomId.uuidString,
                "author_id": userId.uuidString,
                "activity_type": type.rawValue,
                "content": content,
                "love_points_earned": type.lovePointsValue
            ] as [String : Any]
            
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            
            print("📡 Making request to:", request.url?.absoluteString ?? "nil")
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response creating activity")
                return
            }
            
            print("📨 Response status:", httpResponse.statusCode)
            
            if httpResponse.statusCode >= 400 {
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ Create activity error:", httpResponse.statusCode, errorBody)
                return
            }
            
            let responseBody = String(data: data, encoding: .utf8) ?? "No response body"
            print("✅ Activity created successfully - Response:", responseBody)
            
            // Refresh activities and metrics
            await loadActivitiesSafely()
            try? await sessionManager.refreshMetrics()
            
            // Reset animal health timers due to activity
            await MainActor.run {
                sessionManager.onActivitySent()
            }
            
        } catch {
            print("❌ Error sending activity:", error)
        }
    }
    
    private func loadActivitiesSafely() async {
        // If already loading, wait for it to complete instead of cancelling
        if let existingTask = loadingTask {
            print("🔄 Already loading activities, waiting for completion...")
            await existingTask.value
            return
        }
        
        // Create new task
        loadingTask = Task {
            await loadActivities()
        }
        
        await loadingTask?.value
        loadingTask = nil
    }
    
    private func refreshActivitiesSafely() async {
        // Don't show loading spinner for refresh
        guard !isLoading else { return }
        
        // If already loading, wait for it to complete instead of cancelling
        if let existingTask = loadingTask {
            print("🔄 Already loading activities, waiting for completion...")
            await existingTask.value
            return
        }
        
        // Create new task
        loadingTask = Task {
            await loadActivitiesInternal()
        }
        
        await loadingTask?.value
        loadingTask = nil
    }
    
    private func loadActivities() async {
        await MainActor.run {
            isLoading = true
        }
        
        await loadActivitiesInternal()
        
        await MainActor.run {
            isLoading = false
        }
    }
    
    private func loadActivitiesInternal() async {
        guard let roomId = sessionManager.currentRoomID,
              let session = authService.session else {
            print("❌ Cannot load activities - missing roomId or session")
            print("   roomId:", sessionManager.currentRoomID?.uuidString ?? "nil")
            print("   session:", authService.session != nil ? "exists" : "nil")
            await MainActor.run {
                loadErrorMessage = "Sign in and pair up to see your shared feed."
            }
            return
        }

        print("🔄 Loading activities for room:", roomId.uuidString)
        
        await MainActor.run {
            loadErrorMessage = nil
        }

        do {
            // Fetch activities from database
            let environment = SupabaseEnvironment.makeCurrent()
            var components = URLComponents(url: environment.restURL.appendingPathComponent("duo_activities"), resolvingAgainstBaseURL: false)
            components?.queryItems = [
                URLQueryItem(name: "room_id", value: "eq.\(roomId.uuidString)"),
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "order", value: "created_at.desc"),
                URLQueryItem(name: "limit", value: "50")
            ]

            guard let url = components?.url else {
                print("❌ Failed to build activities URL")
                return
            }

            print("📡 Fetching activities from:", url.absoluteString)

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.allHTTPHeaderFields = environment.headers(accessToken: session.accessToken)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response loading activities")
                return
            }
            
            if httpResponse.statusCode >= 400 {
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ Load activities error:", httpResponse.statusCode, errorBody)
                return
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let fetchedActivities = try decoder.decode([ActivityResponse].self, from: data)
            let duoActivities = fetchedActivities.map { response in
                DuoActivity(
                    id: response.id,
                    roomId: response.room_id,
                    authorId: response.author_id,
                    type: DuoActivity.ActivityType(rawValue: response.activity_type) ?? .ping,
                    content: response.content,
                    lovePointsEarned: response.love_points_earned,
                    createdAt: response.created_at
                )
            }
            
            await MainActor.run {
                // Only update if this task wasn't cancelled
                if !Task.isCancelled {
                    activities = duoActivities
                    currentTime = Date()
                    loadErrorMessage = nil
                    
                    // Update widget with latest partner doodle
                    updateWidgetWithLatestPartnerDoodle(duoActivities)
                    
                    // Check for new partner activities and send notifications
                    checkForNewPartnerActivities(duoActivities)
                }
            }
            
            print("✅ Loaded \(duoActivities.count) activities")
            
        } catch {
            // Don't log cancelled errors as errors
            if !Task.isCancelled {
                print("❌ Error loading activities:", error)
                await MainActor.run {
                    loadErrorMessage = "We couldn’t refresh the feed. Tap retry."
                }
            }
        }
    }
    
    private func friendlyName(from raw: String?) -> String? {
        guard let value = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        if let at = value.firstIndex(of: "@") {
            let prefix = value[..<at]
            if !prefix.isEmpty {
                return String(prefix)
            }
        }
        return value
    }
    
    private func updateWidgetWithLatestPartnerDoodle(_ activities: [DuoActivity]) {
        // Find the most recent doodle from partner (not current user)
        guard let currentUserId = authService.currentUser?.id else { 
            print("❌ No currentUserId for widget update")
            return 
        }
        
        let partnerDoodles = activities.filter { activity in
            activity.type == .doodle && activity.authorId != currentUserId
        }
        
        print("🎨 Found \(partnerDoodles.count) partner doodles for widget update")
        
        guard let doodle = partnerDoodles.first,
              let partnerName = sessionManager.partnerName else { 
            print("🎨 No partner doodles found or missing partnerName")
            return 
        }
        
        print("🎨 Updating widget with doodle from \(partnerName)")
        
        // Extract base64 image data
        var payload = doodle.content
        if let comma = doodle.content.firstIndex(of: ",") {
            payload = String(doodle.content[doodle.content.index(after: comma)...])
        }
        
        guard let imageData = Data(base64Encoded: payload) else { 
            print("❌ Failed to decode doodle image data")
            return 
        }
        
        print("✅ Saving doodle to widget store (\(imageData.count) bytes)")
        print("🎨 Doodle details - Partner: \(partnerName), Date: \(doodle.createdAt)")
        
        // Save to widget store
        DoodleWidgetStore.shared.saveReceivedDoodle(
            imageData: imageData,
            fromPartner: partnerName,
            activityDate: doodle.createdAt,
            activityID: doodle.id
        )
        
        // Force widget refresh
        print("🔄 Force refreshing widget timeline")
        WidgetCenter.shared.reloadTimelines(ofKind: "LatestDoodleWidget")
    }
    
    private func checkForNewPartnerActivities(_ activities: [DuoActivity]) {
        guard let currentUserId = authService.currentUser?.id,
              let partnerName = sessionManager.partnerName else { 
            print("❌ Missing currentUserId or partnerName for notifications")
            return 
        }
        
        print("🔍 Checking \(activities.count) activities for notifications (currentUserId: \(currentUserId))")
        
        // Get the most recent partner activity
        let partnerActivities = activities.filter { activity in
            activity.authorId != currentUserId
        }
        
        print("📝 Found \(partnerActivities.count) partner activities")
        
        guard let activity = partnerActivities.first else { 
            print("🔕 No partner activities found")
            return 
        }
        
        // For doodles we already trigger a push & widget refresh via Supabase, so skip duplicate local notification
        if activity.type == .doodle {
            print("🔔 Skipping local notification for doodle – push is handled via Supabase trigger")
            return
        }

        // Check if this activity is recent (within last 5 minutes only)
        let timeSinceActivity = Date().timeIntervalSince(activity.createdAt)
        print("⏰ Most recent partner activity: \(activity.type) from \(timeSinceActivity/60) minutes ago")
        
        // Only send notifications for very recent activities (5 minutes) to avoid duplicates
        if timeSinceActivity <= 300 { // 5 minutes
            print("✅ Sending notification for recent partner activity: \(activity.type)")
            // This is a recent activity from partner - send notification
            NotificationManager.shared.sendPartnerActivityNotification(
                partnerName: partnerName,
                activityType: activity.type,
                activityContent: activity.content,
                activityID: activity.id
            )
        } else {
            print("⏰ Activity too old (\(timeSinceActivity/60) minutes), skipping notification")
        }
    }
    
    private func startTimeUpdates() {
        timeUpdateTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            Task {
                await MainActor.run {
                    // Update current time to trigger timeAgo recalculation
                    currentTime = Date()
                }
            }
        }
    }
}

// MARK: - Farm-Style Custom Components


struct CleanStatCard: View {
    let value: String
    let label: String
    let icon: String
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 4) {
            Text(icon)
                .font(.title2)
            
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundColor(.primary)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(CozyPalette.cardBackground(for: colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct CleanActionButton: View {
    let icon: String
    let label: String
    let isActive: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(icon)
                    .font(.title2)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(isActive ? Color.blue.opacity(0.2) : Color.clear)
                            .overlay(
                                Circle()
                                    .stroke(isActive ? Color.blue : Color.primary.opacity(0.3), lineWidth: 2)
                            )
                    )
                    .scaleEffect(isActive ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3), value: isActive)
                
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(.plain)
    }
}

struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    let glowColor: Color
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Text(icon)
                    .font(.title2)
                Text(value)
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)
            }
            
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.2))
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct EpicActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let points: String
    let isActive: Bool
    let isSending: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: isActive ? [color, color.opacity(0.6)] : [color.opacity(0.8), color.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                        .shadow(color: color.opacity(0.4), radius: isActive ? 15 : 8, x: 0, y: isActive ? 8 : 4)
                        .scaleEffect(isSending ? 1.1 : (isActive ? 1.05 : 1.0))
                        .animation(.bouncy(duration: 0.6), value: isActive)
                        .animation(.spring(response: 0.4), value: isSending)
                    
                    if isSending && isActive {
                        // Sending animation
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.6), lineWidth: 2)
                            .frame(width: 50, height: 50)
                            .scaleEffect(1.2)
                            .opacity(0.0)
                            .animation(.easeOut(duration: 0.8).repeatForever(autoreverses: false), value: isSending)
                    }
                    
                    Text(icon)
                        .font(.title2)
                        .scaleEffect(isActive ? 1.2 : 1.0)
                        .rotationEffect(.degrees(isActive ? 10 : 0))
                        .animation(.bouncy(duration: 0.6), value: isActive)
                }
                
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.primary)
                
                Text(points)
                    .font(.caption2.weight(.bold))
                    .foregroundColor(color)
                    .opacity(0.8)
            }
        }
        .disabled(isSending)
        .scaleEffect(isSending ? 0.95 : 1.0)
        .animation(.spring(response: 0.4), value: isSending)
    }
}

// MARK: - Simple Components

struct ProfilePhotoView: View {
    let isCurrentUser: Bool
    let activityType: DuoActivity.ActivityType
    @ObservedObject var photoManager: PhotoManager
    
    var body: some View {
        ZStack {
            // Glassy background circle
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 50, height: 50)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                )
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.6),
                                    Color.white.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
            
            // Profile content
            if let profileImage = isCurrentUser ? photoManager.userProfilePhoto : photoManager.partnerProfilePhoto {
                Image(uiImage: profileImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 42, height: 42)
                    .clipShape(Circle())
            } else {
                // Fallback to activity emoji
                Text(activityType.icon)
                    .font(.title3)
                    .foregroundColor(activityType.color)
            }
        }
    }
}


private func currentScreenScale() -> CGFloat {
    if let scale = UIApplication.shared.connectedScenes
        .compactMap({ ($0 as? UIWindowScene)?.screen.scale })
        .first {
        return scale
    }
    return 2.0
}

struct QuickActionButton: View {
    let icon: String
    let tint: Color
    let action: () -> Void
    let isActive: Bool
    let isDisabled: Bool
    
    var body: some View {
        Button(action: action) {
            Text(icon)
                .font(.title2)
                .frame(width: 54, height: 54)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    tint.opacity(isDisabled ? 0.35 : 0.95),
                                    tint.opacity(isDisabled ? 0.25 : 0.65)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.25), lineWidth: 1)
                        )
                        .shadow(color: tint.opacity(isActive ? 0.45 : 0.2), radius: isActive ? 10 : 6, x: 0, y: isActive ? 8 : 4)
                )
                .scaleEffect(isActive ? 1.08 : 1.0)
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isActive)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.6 : 1.0)
    }
}

struct EnhancedActionButton: View {
    let icon: String
    let label: String
    let points: String
    let tint: Color
    let action: () -> Void
    let isActive: Bool
    let isDisabled: Bool
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: isActive ? [tint, tint.opacity(0.7)] : [tint.opacity(isDisabled ? 0.4 : 0.8), tint.opacity(isDisabled ? 0.3 : 0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 60)
                        .shadow(
                            color: tint.opacity(isActive ? 0.5 : 0.25), 
                            radius: isActive ? 12 : 6, 
                            x: 0, 
                            y: isActive ? 8 : 4
                        )
                        .scaleEffect(isActive ? 1.05 : 1.0)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isActive)
                    
                    Text(icon)
                        .font(.title2)
                        .scaleEffect(isActive ? 1.1 : 1.0)
                        .animation(.spring(response: 0.4), value: isActive)
                }
                
                VStack(spacing: 2) {
                    Text(label)
                        .font(.caption.weight(.bold))
                        .foregroundColor(.primary)
                    
                    Text(points)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(tint)
                        .opacity(0.8)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.6 : 1.0)
    }
}

// MARK: - Activity Models

struct DuoActivity: Identifiable, Hashable {
    let id: UUID
    let roomId: UUID
    let authorId: UUID
    let type: ActivityType
    let content: String
    let lovePointsEarned: Int
    let createdAt: Date
    
    enum ActivityType: String, Codable, CaseIterable {
        case ping
        case note
        case hug
        case kiss
        case doodle
        
        var icon: String {
            switch self {
            case .ping: return "💖"
            case .note: return "💌"
            case .hug: return "🤗"
            case .kiss: return "😘"
            case .doodle: return "🎨"
            }
        }
        
        var color: Color {
            switch self {
            case .ping: return CozyPalette.warmPink
            case .note: return CozyPalette.softLavender
            case .hug: return CozyPalette.warmOrange
            case .kiss: return CozyPalette.cozyPeach
            case .doodle: return CozyPalette.mintGreen
            }
        }
        
        var lovePointsValue: Int {
            switch self {
            case .ping: return 2
            case .note: return 5
            case .hug: return 3
            case .kiss: return 4
            case .doodle: return 10
            }
        }
    }
}

struct ActivityResponse: Decodable {
    let id: UUID
    let room_id: UUID
    let author_id: UUID
    let activity_type: String
    let content: String
    let love_points_earned: Int
    let created_at: Date
}

struct SimpleActivityCard: View {
    let activity: DuoActivity
    let currentUserName: String
    let partnerName: String
    let currentUserId: UUID?
    let currentTime: Date
    @ObservedObject var photoManager: PhotoManager
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var audioPlayer = AudioPlayer()
    
    private var isCurrentUser: Bool {
        guard let currentUserId = currentUserId else { return false }
        return activity.authorId == currentUserId
    }
    
    private var authorName: String {
        if isCurrentUser {
            return currentUserName
        } else {
            return partnerName
        }
    }
    
    private var timeAgo: String {
        let elapsed = max(0, currentTime.timeIntervalSince(activity.createdAt))
        if elapsed < 60 {
            return "just now"
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: activity.createdAt, relativeTo: currentTime)
    }
    
    private var doodleImage: UIImage? {
        guard activity.type == .doodle else { return nil }
        let payload: String
        if let comma = activity.content.firstIndex(of: ",") {
            payload = String(activity.content[activity.content.index(after: comma)...])
        } else {
            payload = activity.content
        }
        guard let data = Data(base64Encoded: payload) else { return nil }
        return UIImage(data: data)
    }
    
    private var plainContent: String {
        guard activity.type != .doodle else { return "Shared a doodle" }
        
        // Handle voice messages
        if isVoiceMessage {
            let duration = voiceMessageDuration ?? 0
            return "🎙️ Voice message (\(String(format: "%.0f", duration))s)"
        }
        
        let trimmed = activity.content.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? activity.type.icon : trimmed
    }
    
    private var isVoiceMessage: Bool {
        activity.content.hasPrefix("voice_message:")
    }
    
    private var voiceMessageDuration: TimeInterval? {
        guard isVoiceMessage else { return nil }
        let components = activity.content.components(separatedBy: ":")
        guard components.count >= 3,
              let duration = TimeInterval(components[1]) else { return nil }
        return duration
    }
    
    private var voiceMessageData: Data? {
        guard isVoiceMessage else { return nil }
        let components = activity.content.components(separatedBy: ":")
        guard components.count >= 3 else { return nil }
        let base64String = components[2]
        return Data(base64Encoded: base64String)
    }
    
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Profile photo with glassy effect
            ProfilePhotoView(
                isCurrentUser: isCurrentUser,
                activityType: activity.type,
                photoManager: photoManager
            )
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(authorName)
                        .font(.headline.weight(.medium))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(timeAgo)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("+\(activity.lovePointsEarned)")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.pink)
                        )
                }
                
                if let doodleImage = doodleImage {
                    doodlePreview(image: doodleImage)
                } else if isVoiceMessage {
                    voiceMessagePlayer
                } else {
                    Text(plainContent)
                        .font(.body)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(CozyPalette.cardBackground(for: colorScheme))
        )
    }
    
    private var voiceMessagePlayer: some View {
        HStack(spacing: 12) {
            // Play/pause button
            Button {
                if audioPlayer.isPlaying {
                    audioPlayer.pause()
                } else if let audioData = voiceMessageData {
                    audioPlayer.play(audioData: audioData)
                }
            } label: {
                Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(
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
                    )
                    .shadow(color: Color(red: 0.4, green: 0.8, blue: 0.9).opacity(0.4), radius: 8, y: 4)
            }
            .disabled(voiceMessageData == nil)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("🎙️ Voice message")
                        .font(.body.weight(.medium))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if let duration = voiceMessageDuration {
                        Text("\(String(format: "%.0f", duration))s")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Progress bar
                if audioPlayer.duration > 0 {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 3)
                                .cornerRadius(1.5)
                            
                            // Progress
                            Rectangle()
                                .fill(Color(red: 0.4, green: 0.8, blue: 0.9))
                                .frame(width: geometry.size.width * (audioPlayer.currentTime / audioPlayer.duration), height: 3)
                                .cornerRadius(1.5)
                        }
                    }
                    .frame(height: 3)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.gray.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
        )
        .onAppear {
            // Stop any other audio when this card appears
            if audioPlayer.isPlaying {
                audioPlayer.stop()
            }
        }
    }
    
    private func doodlePreview(image: UIImage) -> some View {
        ZStack(alignment: .bottomTrailing) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            Label("doodle", systemImage: "scribble.variable")
                .font(.caption2.weight(.semibold))
                .padding(8)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(10)
        }
    }
}

// MARK: - Note Composer Sheet

struct NoteComposerSheet: View {
    @Binding var newNote: String
    @Binding var sendingActivity: Bool
    let onSend: () -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Write a sweet note")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("Share what's on your mind... 💭", text: $newNote, axis: .vertical)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(UIColor.secondarySystemGroupedBackground))
                        )
                        .lineLimit(5...10)
                        .font(.body)
                }
                
                Spacer()
            }
            .padding()
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("New Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        onSend()
                        dismiss()
                    }
                    .disabled(newNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || sendingActivity)
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    ActivityView(
        sessionManager: CoupleSessionManager.preview,
        authService: AuthService(managesDeviceTokens: false)
    )
}
#endif
