//
//  FarmHomeView.swift
//  doodleduo
//
//  Created by Codex on 25/11/2025.
//

import SwiftUI

struct FarmHomeView: View {
    @ObservedObject private var sessionManager: CoupleSessionManager
    private let calendar = Calendar.autoupdatingCurrent
    @State private var clockPulse = false
    @State private var showGameOver = false
    @State private var cachedSnapshots: [AnimalHealthSnapshot] = []

    init(sessionManager: CoupleSessionManager) {
        _sessionManager = ObservedObject(wrappedValue: sessionManager)
    }

    #if DEBUG
    init() {
        _sessionManager = ObservedObject(wrappedValue: .preview)
    }
    #endif

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            content(for: context.date)
        }
        .onAppear {
            clockPulse = true
            checkGameOver()
        }
        .onChange(of: sessionManager.farm?.farmHealth?.isDead) { _, isDead in
            if isDead == true {
                showGameOver = true
            }
        }
        .onChange(of: sessionManager.isGameOver) { _, isGameOver in
            showGameOver = isGameOver
        }
    }
    
    @ViewBuilder
    private func content(for date: Date) -> some View {
        let isDaytime = isDaytime(date: date)
        GeometryReader { proxy in
            let safeTop = proxy.safeAreaInsets.top
            ZStack {
                backgroundImage(isDaytime: isDaytime)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .overlay(colorWash(forDaytime: isDaytime))
                    .overlay(gradientOverlay(forDaytime: isDaytime))
                    .ignoresSafeArea()

                // Animals layer
                animalLayers(screenWidth: proxy.size.width, screenHeight: proxy.size.height)

                VStack(alignment: .center, spacing: 0) {
                    // Combined header with time, stats, and names
                    VStack(spacing: 20) {
                        // Time display at the top center
                        timeDisplay(for: date)
                        
                        // Stats row
                        HStack(spacing: 12) {
                            StatBadge(
                                icon: "heart.fill",
                                label: "love points",
                                value: "\(affectionScore)",
                                gradient: [
                                    Color(red: 0.98, green: 0.63, blue: 0.71),
                                    Color(red: 0.93, green: 0.27, blue: 0.36)
                                ],
                                glowColor: Color(red: 0.93, green: 0.27, blue: 0.36),
                                animateHeart: true,
                                symbolColor: Color(red: 1.0, green: 0.82, blue: 0.88)
                            )

                            SurvivalBadge(
                                timeText: survivalTimeText,
                                gradient: [
                                    Color(red: 1.0, green: 0.72, blue: 0.58),
                                    Color(red: 0.99, green: 0.63, blue: 0.32)
                                ],
                                glowColor: Color(red: 0.99, green: 0.63, blue: 0.32)
                            )
                        }
                        
                        // User names and room label
                        VStack(spacing: 8) {
                            if let names = duoNames {
                                DuoNamesRow(left: names.left, right: names.right)
                                    .transition(.opacity.combined(with: .move(edge: .leading)))
                            }
                            
                            if let label = roomLabel {
                                Text(label.lowercased())
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.85))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(Color.black.opacity(0.2))
                                            .overlay(
                                                Capsule()
                                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                            )
                                    )
                                    .shadow(color: .black.opacity(0.2), radius: 10, y: 6)
                                    .transition(.opacity.combined(with: .move(edge: .leading)))
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity)
                    .padding(.top, safeTop + 60)
                    
                    Spacer()
                    
                    // Ecosystem health monitoring at bottom
                    VStack(spacing: 0) {
                        EcosystemHealthView(sessionManager: sessionManager)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 100) // Add more bottom padding to clear tab bar
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .animation(.spring(response: 0.6, dampingFraction: 0.85), value: isDaytime)
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .fullScreenCover(isPresented: $showGameOver) {
            if sessionManager.metrics != nil {
                GameOverView(
                    survivalDuration: survivalTimeText,
                    bestRunDuration: bestRunText,
                    onRestart: {
                        await sessionManager.restartFarm()
                    }
                )
            }
        }
    }
    
    private func backgroundImage(isDaytime: Bool) -> some View {
        Image(isDaytime ? "farmday" : "farmnight")
            .resizable()
            .scaledToFill()
    }
    
    
    private var affectionScore: Int {
        let score = sessionManager.metrics?.loveEnergy ?? 0
        print("🐔 Love Energy:", score, "Metrics:", sessionManager.metrics as Any)
        return score
    }

    private var survivalTimeText: String {
        guard let farm = sessionManager.farm else { 
            return "0d 0h 0m"
        }
        
        let survivalStart = sessionManager.survivalStartDate ?? farm.createdAt
        let now = Date()
        let elapsed = now.timeIntervalSince(survivalStart)
        
        let days = Int(elapsed / (24 * 3600))
        let hours = Int((elapsed.truncatingRemainder(dividingBy: 24 * 3600)) / 3600)
        let minutes = Int((elapsed.truncatingRemainder(dividingBy: 3600)) / 60)
        
        let result = "\(days)d \(hours)h \(minutes)m"
        print("📅 Real survival time:", result)
        return result
    }

    private var bestRunText: String? {
        guard let longest = sessionManager.metrics?.longestStreak, longest > 0 else {
            return nil
        }
        return formattedDuration(days: longest)
    }

    private func formattedDuration(days: Int) -> String {
        let hours = days * 24
        let dayComponent = hours / 24
        return "\(dayComponent)d 0h 0m"
    }
    
    private func timeDisplay(for date: Date) -> some View {
        Text(date.formatted(.dateTime.hour().minute()))
            .font(.system(size: 44, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.45), radius: 14, y: 6)
            .scaleEffect(clockPulse ? 1.02 : 0.98)
            .animation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true), value: clockPulse)
    }
    
    private var duoNames: (left: String, right: String?)? {
        let me = friendlyName(from: sessionManager.myDisplayName)
        let partner = friendlyName(from: sessionManager.partnerName)
        if me == nil && partner == nil {
            return nil
        }
        if let me, let partner {
            return (me, partner)
        }
        if let me {
            return (me, nil)
        }
        if let partner {
            return (partner, nil)
        }
        return nil
    }
    
    private func colorWash(forDaytime isDaytime: Bool) -> some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: isDaytime
                    ? [Color.white.opacity(0.0), Color.white.opacity(0.15)]
                    : [Color.black.opacity(0.12), Color.black.opacity(0.32)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }
    
    private func gradientOverlay(forDaytime isDaytime: Bool) -> some View {
        LinearGradient(
            colors: [
                Color.black.opacity(isDaytime ? 0.2 : 0.32),
                Color.black.opacity(isDaytime ? 0.35 : 0.42),
                Color.black.opacity(isDaytime ? 0.55 : 0.48)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    private func pseudoMetric(from text: String?, range: ClosedRange<Int>) -> Int {
        guard let text = text, !text.isEmpty else { return range.lowerBound }
        let span = max(range.upperBound - range.lowerBound + 1, 1)
        var accumulator = 0
        for scalar in text.unicodeScalars {
            accumulator = (accumulator * 31 + Int(scalar.value)) % span
        }
        return range.lowerBound + accumulator
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
    
    private var roomLabel: String? {
        guard let name = sessionManager.roomName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else {
            return nil
        }
        return name
    }

    @ViewBuilder
    private func animalLayers(screenWidth: CGFloat, screenHeight: CGFloat) -> some View {
        if let farm = sessionManager.farm {
            let newSnapshots = animalHealthSnapshots(for: farm)

            // Only update cached snapshots if they've actually changed
            let _ = updateCachedSnapshotsIfNeeded(newSnapshots)

            ZStack {
                ForEach(Array(cachedSnapshots.enumerated()), id: \.1.id) { index, snapshot in
                    let position = animalPosition(for: snapshot.id, index: index, screenWidth: screenWidth, screenHeight: screenHeight)

                    AnimalView(
                        name: snapshot.id,
                        isSleeping: false,
                        healthSnapshot: snapshot
                    )
                    .equatable()
                    .position(position)
                }
            }
        }
    }

    private func updateCachedSnapshotsIfNeeded(_ newSnapshots: [AnimalHealthSnapshot]) {
        // Check if snapshots have actually changed (using Equatable)
        let hasChanged = cachedSnapshots.count != newSnapshots.count ||
            zip(cachedSnapshots, newSnapshots).contains(where: { $0 != $1 })

        if hasChanged {
            print("🔄 Updating cached snapshots: \(newSnapshots.map { "\($0.id): \($0.formattedHealth)" })")
            DispatchQueue.main.async {
                cachedSnapshots = newSnapshots
            }
        }
    }

    private func animalPosition(for animal: String, index: Int, screenWidth: CGFloat, screenHeight: CGFloat) -> CGPoint {
        // Position animals in the lower half of the screen
        let baseY = screenHeight * 0.65
        let spacing: CGFloat = 100

        switch animal {
        case "chicken":
            return CGPoint(x: screenWidth * 0.3, y: baseY)
        case "sheep":
            return CGPoint(x: screenWidth * 0.6, y: baseY + 20)
        case "pig":
            return CGPoint(x: screenWidth * 0.45, y: baseY + 40)
        case "horse":
            return CGPoint(x: screenWidth * 0.7, y: baseY - 10)
        default:
            // Fallback positioning for additional animals
            let xPos = screenWidth * 0.3 + CGFloat(index % 3) * spacing
            let yPos = baseY + CGFloat(index / 3) * 60
            return CGPoint(x: xPos, y: yPos)
        }
    }

    private func animalHealthSnapshots(for farm: DuoFarm) -> [AnimalHealthSnapshot] {
        let animals = farm.unlockedAnimals.compactMap { AnimalCatalog.animal(byID: $0) }
        guard !animals.isEmpty else { return [] }

        // ONLY use animal health from ecosystem if it has actual data loaded from database
        // Don't show animals with default 100% health while waiting for database
        if let ecosystem = sessionManager.ecosystem, !ecosystem.animalHealthMap.isEmpty {
            // Deduplicate health records per animal type, preferring the BEST health (highest HP)
            // This ensures we show the correct animal even if there are duplicates in the database
            let latestHealthByType: [String: AnimalHealth] = ecosystem.animalHealthMap.values.reduce(into: [:]) { result, health in
                if let existing = result[health.animalType] {
                    // Prefer higher HP; if equal, take the fresher feed time
                    if health.hoursUntilDeath > existing.hoursUntilDeath ||
                        (abs(health.hoursUntilDeath - existing.hoursUntilDeath) < 0.001 && health.lastFedAt > existing.lastFedAt) {
                        result[health.animalType] = health
                    }
                } else {
                    result[health.animalType] = health
                }
            }

            return animals.map { info in
                if let animalHealth = latestHealthByType[info.id] {
                    return AnimalHealthSnapshot(
                        info: info,
                        accentColor: accentColor(for: info.id),
                        healthPercentage: animalHealth.healthPercentage,
                        hoursRemaining: animalHealth.hoursUntilDeath,
                        lastCareDate: animalHealth.lastFedAt
                    )
                } else {
                    // Animal hasn't been initialized yet, show as full health
                    return AnimalHealthSnapshot(
                        info: info,
                        accentColor: accentColor(for: info.id),
                        healthPercentage: 1.0,
                        hoursRemaining: 24.0,
                        lastCareDate: Date()
                    )
                }
            }
        } else {
            // Fallback to old system if ecosystem not loaded yet
            guard let farmHealth = farm.farmHealth else { return [] }
            
            let penaltyStep = 0.08
            let hoursStep = 1.2

            return animals.enumerated().map { index, info in
                let penalty = Double(index) * penaltyStep
                let adjustedHealth = max(0.05, min(1.0, farmHealth.healthPercentage - penalty))
                let adjustedHours = max(0, farmHealth.hoursUntilDeath - Double(index) * hoursStep)

                return AnimalHealthSnapshot(
                    info: info,
                    accentColor: accentColor(for: info.id),
                    healthPercentage: adjustedHealth,
                    hoursRemaining: adjustedHours,
                    lastCareDate: farmHealth.lastActivityAt
                )
            }
        }
    }

    private func accentColor(for animalID: String) -> Color {
        switch animalID {
        case "chicken":
            return Color(red: 1.0, green: 0.82, blue: 0.41)
        case "sheep":
            return Color(red: 0.76, green: 0.86, blue: 0.98)
        case "pig":
            return Color(red: 0.98, green: 0.68, blue: 0.74)
        case "horse":
            return Color(red: 0.73, green: 0.58, blue: 0.92)
        case "duck":
            return Color(red: 0.99, green: 0.79, blue: 0.45)
        case "goat":
            return Color(red: 0.65, green: 0.86, blue: 0.62)
        case "cow":
            return Color(red: 0.9, green: 0.85, blue: 0.77)
        default:
            return Color(red: 0.82, green: 0.72, blue: 0.95)
        }
    }

    private func isDaytime(date: Date) -> Bool {
        let hour = calendar.component(.hour, from: date)
        return hour >= 6 && hour < 19
    }

    private func checkGameOver() {
        if sessionManager.isGameOver {
            showGameOver = true
            return
        }

        if let farmHealth = sessionManager.farm?.farmHealth, farmHealth.isDead {
            showGameOver = true
        }
    }
}

private struct DuoNamesRow: View {
    let left: String
    let right: String?
    private let heartColor = Color(red: 0.93, green: 0.27, blue: 0.36)

    var body: some View {
        HStack(spacing: 10) {
            Text(left.lowercased())
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
            Image(systemName: "heart.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(heartColor)
            if let right {
                Text(right.lowercased())
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.25))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.2), radius: 14, y: 8)
    }
}

#if DEBUG
#Preview {
    FarmHomeView(sessionManager: .preview)
}
#endif
