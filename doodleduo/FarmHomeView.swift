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

                VStack(alignment: .leading, spacing: 16) {
                    header(for: date, isDaytime: isDaytime)
                        .padding(.horizontal, 20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer()
                }
                .padding(.top, safeTop + 72)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .animation(.spring(response: 0.6, dampingFraction: 0.85), value: isDaytime)
            .ignoresSafeArea()
            .overlay(alignment: .top) {
                timeDisplay(for: date)
                    .padding(.top, max(safeTop + 32, 68))
            }
        }
        .ignoresSafeArea()
    }
    
    private func backgroundImage(isDaytime: Bool) -> some View {
        Image(isDaytime ? "farmday" : "farmnight")
            .resizable()
            .scaledToFill()
    }
    
    @ViewBuilder
    private func header(for date: Date, isDaytime: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
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
            
            StatBadge(
                icon: "flame.fill",
                label: "streak",
                value: "\(streakScore)",
                gradient: [
                    Color(red: 1.0, green: 0.66, blue: 0.27),
                    Color(red: 1.0, green: 0.39, blue: 0.19),
                    Color(red: 0.85, green: 0.18, blue: 0.22)
                ],
                glowColor: Color(red: 1.0, green: 0.45, blue: 0.2),
                showFire: true,
                symbolColor: Color(red: 1.0, green: 0.74, blue: 0.28)
            )
            
            if let names = duoNames {
                DuoNamesRow(left: names.left, right: names.right)
                    .transition(.opacity.combined(with: .move(edge: .leading)))
                
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
    }
    
    private var affectionScore: Int {
        let score = sessionManager.metrics?.loveEnergy ?? 0
        print("🐔 Love Energy:", score, "Metrics:", sessionManager.metrics as Any)
        return score
    }

    private var streakScore: Int {
        let score = sessionManager.metrics?.currentStreak ?? 0
        print("🔥 Streak:", score)
        return score
    }
    
    @ViewBuilder
    private func timeDisplay(for date: Date) -> some View {
        Text(date.formatted(.dateTime.hour().minute()))
            .font(.system(size: 44, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.6), radius: 18, y: 8)
            .scaleEffect(clockPulse ? 1.02 : 0.98)
            .animation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true), value: clockPulse)
            .frame(maxWidth: .infinity, alignment: .center)
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
            let unlockedAnimals = farm.unlockedAnimals
            let _ = print("🐔 Farm loaded! Animals:", unlockedAnimals)

            // Position animals on the farm
            ZStack {
                ForEach(Array(unlockedAnimals.enumerated()), id: \.offset) { index, animalName in
                    AnimalView(name: animalName, isSleeping: false)
                        .position(animalPosition(for: animalName, index: index, screenWidth: screenWidth, screenHeight: screenHeight))
                }
            }
        } else {
            let _ = print("❌ Farm is NIL - no data loaded!")
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

    private func isDaytime(date: Date) -> Bool {
        let hour = calendar.component(.hour, from: date)
        return hour >= 6 && hour < 19
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

#Preview {
    FarmHomeView()
}
