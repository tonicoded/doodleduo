//
//  OnboardingQuestionScreens.swift
//  doodleduo
//
//  Created by Anthony Verruijt on 16/11/2025.
//

import SwiftUI
import UserNotifications

struct InterestSurveyView: View {
    let options: [InterestOption] = InterestOption.defaults
    @State private var selectedIDs: Set<InterestOption.ID> = []
    let onContinue: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color(red: 0.06, green: 0.05, blue: 0.05) : Color(red: 0.99, green: 0.97, blue: 0.95)
    }
    
    private var cardColor: Color {
        colorScheme == .dark ? Color(red: 0.14, green: 0.12, blue: 0.12) : Color.white
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 16)
            Text("what part of doodleduo makes you smile?")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .textCase(.lowercase)
                .padding(.horizontal, 24)
            
            VStack(spacing: 12) {
                ForEach(options) { option in
                    let isSelected = selectedIDs.contains(option.id)
                    Button {
                        if isSelected {
                            selectedIDs.remove(option.id)
                        } else {
                            selectedIDs.insert(option.id)
                        }
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: option.icon)
                                .font(.headline)
                            Text(option.title)
                                .font(.callout.weight(.semibold))
                                .textCase(.lowercase)
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color(red: 0.42, green: 0.27, blue: 0.23))
                            }
                        }
                        .foregroundStyle(.primary)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(isSelected ? Color(red: 0.95, green: 0.9, blue: 0.86).opacity(colorScheme == .dark ? 0.4 : 1) : cardColor.opacity(colorScheme == .dark ? 0.95 : 1))
                                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.08), radius: 14, y: 8)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            
            Button {
                onContinue()
            } label: {
                Text("continue")
                    .font(.headline)
                    .textCase(.lowercase)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(selectedIDs.isEmpty ? Color.gray.opacity(0.3) : Color(red: 0.42, green: 0.27, blue: 0.23))
                    )
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 24)
            .buttonStyle(.plain)
            .disabled(selectedIDs.isEmpty)
            Spacer()
        }
        .background(backgroundColor.ignoresSafeArea())
    }
}

struct NotificationPromptView: View {
    @State private var isRequesting = false
    let onDone: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color(red: 0.05, green: 0.04, blue: 0.05) : Color(red: 0.99, green: 0.97, blue: 0.95)
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 24)
            Image(systemName: "app.badge.fill")
                .font(.system(size: 70))
                .foregroundStyle(Color(red: 0.42, green: 0.27, blue: 0.23))
                .padding(26)
                .background(
                    Circle()
                        .fill(Color.white.opacity(colorScheme == .dark ? 0.15 : 1))
                        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.6 : 0.15), radius: 24, y: 12)
                )
            
            VStack(spacing: 10) {
                Text("want doodle reminders?")
                    .font(.title2.bold())
                    .textCase(.lowercase)
                    .multilineTextAlignment(.center)
                Text("love notes, new drawings, and streak boosts arrive right away if you let us nudge you.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .textCase(.lowercase)
                    .padding(.horizontal, 32)
            }
            
            VStack(spacing: 12) {
                Button {
                    requestPermission()
                } label: {
                    Text(isRequesting ? "asking apple…" : "turn on notifications")
                        .font(.headline)
                        .textCase(.lowercase)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .fill(Color(red: 0.42, green: 0.27, blue: 0.23))
                        )
                        .foregroundStyle(.white)
                }
                .disabled(isRequesting)
                
                Button {
                    onDone()
                } label: {
                    Text("maybe later")
                        .font(.subheadline.weight(.semibold))
                        .textCase(.lowercase)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 36)
            Spacer()
        }
        .background(backgroundColor.ignoresSafeArea())
    }
    
    private func requestPermission() {
        guard !isRequesting else { return }
        isRequesting = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
            DispatchQueue.main.async {
                isRequesting = false
                onDone()
            }
        }
    }
}

struct InterestOption: Identifiable, Equatable {
    let id = UUID()
    let icon: String
    let title: String
    
    static let defaults: [InterestOption] = [
        .init(icon: "heart.text.square", title: "sending love notes and doodles"),
        .init(icon: "hand.draw", title: "drawing together in real time"),
        .init(icon: "leaf", title: "growing our tiny farm"),
        .init(icon: "square.grid.2x2", title: "pinning widgets on our phones"),
        .init(icon: "calendar", title: "staying on top of streaks")
    ]
}
