//
//  GameOverView.swift
//  doodleduo
//
//  Game over screen when all animals die
//

import SwiftUI

struct GameOverView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    let survivalDuration: String
    let bestRunDuration: String?
    let onRestart: () async -> Void

    @State private var isRestarting = false

    var body: some View {
        ZStack {
            // Dark overlay background
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Skull emoji
                Text("💀")
                    .font(.system(size: 80))
                    .padding(.top, 40)

                VStack(spacing: 8) {
                    Text("game over")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("all animals have perished")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                }

                // Stats card
                VStack(spacing: 16) {
                    statRow(icon: "calendar", label: "farm lasted", value: survivalDuration)

                    if let bestRunDuration, bestRunDuration != survivalDuration {
                        Divider()
                            .background(Color.white.opacity(0.2))

                        statRow(icon: "trophy.fill", label: "best run", value: bestRunDuration, highlight: true)
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.black.opacity(0.4))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(0.3), radius: 20, y: 10)

                // Message
                VStack(spacing: 8) {
                    Text("starting fresh with chicken")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.8))

                    Text("keep your farm alive by staying active!")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.horizontal, 32)
                .multilineTextAlignment(.center)

                Spacer()

                // Restart button
                Button {
                    restart()
                } label: {
                    HStack(spacing: 8) {
                        if isRestarting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.body.weight(.semibold))
                        }
                        Text(isRestarting ? "restarting..." : "start over")
                            .font(.headline.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 16)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 1.0, green: 0.72, blue: 0.58),
                                        Color(red: 0.99, green: 0.63, blue: 0.32)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: Color(red: 0.99, green: 0.63, blue: 0.32).opacity(0.4), radius: 20, y: 10)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isRestarting)
                .opacity(isRestarting ? 0.7 : 1.0)
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 32)
        }
        .interactiveDismissDisabled()
    }

    @ViewBuilder
    private func statRow(icon: String, label: String, value: String, highlight: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(highlight ? Color(red: 0.99, green: 0.63, blue: 0.32) : Color.white.opacity(0.7))
                .frame(width: 32)

            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.8))

            Spacer()

            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(highlight ? Color(red: 0.99, green: 0.63, blue: 0.32) : .white)
                .monospacedDigit()
        }
    }

    private func restart() {
        isRestarting = true
        Task {
            await onRestart()
            await MainActor.run {
                isRestarting = false
                dismiss()
            }
        }
    }
}

#Preview {
    GameOverView(survivalDuration: "3d 12h 4m", bestRunDuration: "5d 0h 0m", onRestart: {
        try? await Task.sleep(nanoseconds: 1_000_000_000)
    })
}
