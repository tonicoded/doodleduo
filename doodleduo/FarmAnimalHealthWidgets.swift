//
//  FarmAnimalHealthWidgets.swift
//  doodleduo
//
//  Created by Codex on 02/12/2025.
//

import SwiftUI

struct AnimalHealthSnapshot: Identifiable, Equatable {
    let info: AnimalInfo
    let accentColor: Color
    let healthPercentage: Double
    let hoursRemaining: Double
    let lastCareDate: Date

    var id: String { info.id }
    var displayName: String { info.name }
    var assetName: String { info.assetName }
    var formattedHealth: String { "\(Int(healthPercentage * 100))%" }
    var timeRemainingText: String {
        let hours = max(0, Int(hoursRemaining))
        let minutes = max(0, Int((hoursRemaining - Double(hours)) * 60))
        if hours == 0 { return "\(minutes)m" }
        return "\(hours)h \(minutes)m"
    }

    var mood: Mood {
        switch healthPercentage {
        case 0.7...:
            return .thriving
        case 0.4...0.7:
            return .content
        default:
            return .needsCare
        }
    }

    // Equatable conformance - round health percentage to prevent tiny differences from causing updates
    static func == (lhs: AnimalHealthSnapshot, rhs: AnimalHealthSnapshot) -> Bool {
        lhs.info.id == rhs.info.id &&
        abs(lhs.healthPercentage - rhs.healthPercentage) < 0.001 && // Only consider significant changes
        abs(lhs.hoursRemaining - rhs.hoursRemaining) < 0.01
    }

    enum Mood: String {
        case thriving = "Thriving"
        case content = "Content"
        case needsCare = "Needs care"

        var emoji: String {
            switch self {
            case .thriving:
                return "✨"
            case .content:
                return "🙂"
            case .needsCare:
                return "🥺"
            }
        }
    }
}

struct AnimalHealthBadge: View {
    let snapshot: AnimalHealthSnapshot
    private let barWidth: CGFloat = 88
    private let barHeight: CGFloat = 10
    @State private var displayedProgress: CGFloat = 1.0

    var body: some View {
        Capsule()
            .fill(Color.white.opacity(0.12))
            .frame(width: barWidth, height: barHeight)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(healthColor)
                    .frame(width: barWidth * displayedProgress, height: barHeight)
            }
            .shadow(color: healthColor.opacity(0.35), radius: 4, y: 2)
            .onAppear {
                displayedProgress = progress
            }
            .onChange(of: progress) { oldValue, newValue in
                // Only animate if the change is significant (more than 0.5%)
                let delta = abs(newValue - oldValue)
                if delta > 0.005 {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        displayedProgress = newValue
                    }
                } else {
                    // Update without animation for minor changes (prevents flickering)
                    displayedProgress = newValue
                }
            }
    }

    private var progress: CGFloat {
        CGFloat(max(0.02, min(1.0, snapshot.healthPercentage)))
    }

    private var healthColor: Color {
        let clamped = max(0, min(1, snapshot.healthPercentage))
        // Map 0 -> red, 1 -> green with warm transition
        return Color(
            red: 1.0 - 0.45 * clamped,
            green: 0.35 + 0.55 * clamped,
            blue: 0.2 + 0.3 * clamped
        )
    }
}
