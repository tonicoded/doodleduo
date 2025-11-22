//
//  FarmHealthBar.swift
//  doodleduo
//
//  Visual health bar showing time until animals need care
//

import SwiftUI

struct FarmHealthBar: View {
    let farmHealth: FarmHealth

    private var healthColor: Color {
        switch farmHealth.warningLevel {
        case .none:
            return Color(red: 0.55, green: 0.89, blue: 0.75) // mintGreen
        case .warning:
            return Color(red: 0.99, green: 0.63, blue: 0.32) // warmOrange
        case .critical:
            return Color(red: 0.87, green: 0.19, blue: 0.26) // dangerRed
        }
    }

    private var timeText: String {
        let hours = Int(farmHealth.hoursUntilDeath)
        let minutes = Int((farmHealth.hoursUntilDeath - Double(hours)) * 60)

        if farmHealth.isDead {
            return "0h 0m"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: farmHealth.warningLevel == .none ? "heart.fill" : "exclamationmark.triangle.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(healthColor)

                Text(farmHealth.warningLevel == .none ? "animals healthy" : "needs care soon")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))

                Spacer()

                Text(timeText)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(Color.black.opacity(0.25))

                    // Health fill
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    healthColor,
                                    healthColor.opacity(0.7)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * max(0.05, farmHealth.healthPercentage))
                        .overlay(
                            Capsule()
                                .stroke(healthColor.opacity(0.3), lineWidth: 1)
                        )
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: farmHealth.healthPercentage)
                }
            }
            .frame(height: 12)

            if farmHealth.warningLevel != .none {
                Text(farmHealth.warningLevel.message)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(healthColor)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.25))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(healthColor.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }
}

#Preview {
    VStack(spacing: 20) {
        FarmHealthBar(farmHealth: FarmHealth(lastActivityAt: Date().addingTimeInterval(-3600), hoursUntilDeath: 20))
        FarmHealthBar(farmHealth: FarmHealth(lastActivityAt: Date().addingTimeInterval(-18 * 3600), hoursUntilDeath: 5))
        FarmHealthBar(farmHealth: FarmHealth(lastActivityAt: Date().addingTimeInterval(-23 * 3600), hoursUntilDeath: 0.5))
    }
    .padding()
    .background(Color.gray)
}
