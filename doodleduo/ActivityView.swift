//
//  ActivityView.swift
//  doodleduo
//
//  Created by Claude Code on 17/11/2025.
//

import SwiftUI
import UIKit
import PencilKit

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
    
    var body: some View {
        NavigationStack {
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
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.large)
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
                    icon: "flame.fill",
                    label: "streak",
                    value: "\(sessionManager.metrics?.currentStreak ?? 0)",
                    gradient: [
                        Color(red: 1.0, green: 0.66, blue: 0.27),
                        Color(red: 1.0, green: 0.39, blue: 0.19),
                        Color(red: 0.85, green: 0.18, blue: 0.22)
                    ],
                    glowColor: Color(red: 1.0, green: 0.45, blue: 0.2),
                    showFire: false,
                    symbolColor: Color(red: 1.0, green: 0.74, blue: 0.28)
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
    
    private var doodleStudioCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("live doodle studio", systemImage: "sparkles")
                .font(.headline)
                .foregroundColor(.primary)
            Text("Open a shared whiteboard and sketch with \(sessionManager.partnerName ?? "your partner") in real time.")
                .font(.callout)
                .foregroundColor(.secondary)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Status")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(sessionManager.partnerName == nil ? "waiting for partner" : "connected")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                }
                Spacer()
                Button {
                    showingDoodleSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "pencil.and.outline")
                        Text("open board")
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(CozyPalette.warmPink))
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .disabled(sessionManager.partnerName == nil)
                .opacity(sessionManager.partnerName == nil ? 0.6 : 1)
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(CozyPalette.cardBackground(for: colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(CozyPalette.warmPink.opacity(0.2), lineWidth: 1)
                )
        )
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
            
            if activities.isEmpty && !isLoading {
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
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("quick gestures")
                        .font(.headline)
                    Text("Send a little burst of love before the feed.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if sendingActivity {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(CozyPalette.warmPink)
                }
            }
            
            HStack(spacing: 14) {
                QuickActionButton(
                    icon: "💖",
                    tint: DuoActivity.ActivityType.ping.color,
                    action: sendPing,
                    isActive: lastSentType == .ping,
                    isDisabled: sessionManager.partnerName == nil || sendingActivity
                )
                
                QuickActionButton(
                    icon: "🤗",
                    tint: DuoActivity.ActivityType.hug.color,
                    action: sendHug,
                    isActive: lastSentType == .hug,
                    isDisabled: sessionManager.partnerName == nil || sendingActivity
                )
                
                QuickActionButton(
                    icon: "😘",
                    tint: DuoActivity.ActivityType.kiss.color,
                    action: sendKiss,
                    isActive: lastSentType == .kiss,
                    isDisabled: sessionManager.partnerName == nil || sendingActivity
                )
                
                Spacer(minLength: 0)
            }
            
            Button {
                showingNoteSheet = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "square.and.pencil")
                        .font(.body.weight(.semibold))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Write a note")
                            .font(.body.weight(.semibold))
                        Text("A thoughtful message earns love points")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [CozyPalette.softLavender, CozyPalette.mintGreen],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .shadow(color: CozyPalette.softLavender.opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(sessionManager.partnerName == nil || sendingActivity)
            .opacity(sessionManager.partnerName == nil ? 0.6 : 1)
            
            if sessionManager.partnerName == nil {
                Text("Invite your partner to unlock gestures and notes.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("Gestures post straight into latest moments above.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(CozyPalette.cardBackground(for: colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.primary.opacity(0.03), lineWidth: 1)
                )
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
        guard let roomId = sessionManager.currentRoomID,
              let userId = authService.currentUser?.id,
              let session = authService.session else { return }
        
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
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response creating activity")
                return
            }
            
            if httpResponse.statusCode >= 400 {
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ Create activity error:", httpResponse.statusCode, errorBody)
                return
            }
            
            print("✅ Activity created successfully")
            
            // Refresh activities and metrics
            await loadActivitiesSafely()
            try? await sessionManager.refreshMetrics()
            
        } catch {
            print("❌ Error sending activity:", error)
        }
    }
    
    private func loadActivitiesSafely() async {
        // Cancel any existing loading task
        loadingTask?.cancel()
        
        // Create new task
        loadingTask = Task {
            await loadActivities()
        }
        
        await loadingTask?.value
    }
    
    private func refreshActivitiesSafely() async {
        // Don't show loading spinner for refresh
        guard !isLoading else { return }
        
        // Cancel any existing loading task
        loadingTask?.cancel()
        
        // Create new task
        loadingTask = Task {
            await loadActivitiesInternal()
        }
        
        await loadingTask?.value
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
              let session = authService.session else { return }
        
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
                    activities = []
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
        
        // Save to widget store
        DoodleWidgetStore.shared.saveReceivedDoodle(
            imageData: imageData,
            fromPartner: partnerName,
            activityDate: doodle.createdAt
        )
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
        
        // Check if this activity is recent (within last 20 minutes for debugging)
        let timeSinceActivity = Date().timeIntervalSince(activity.createdAt)
        print("⏰ Most recent partner activity: \(activity.type) from \(timeSinceActivity/60) minutes ago")
        
        if timeSinceActivity <= 1200 { // 20 minutes for debugging
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
        let trimmed = activity.content.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? activity.type.icon : trimmed
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

#Preview {
    ActivityView(
        sessionManager: CoupleSessionManager.preview,
        authService: AuthService()
    )
}
