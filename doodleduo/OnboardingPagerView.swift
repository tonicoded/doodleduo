//
//  OnboardingPagerView.swift
//  doodleduo
//
//  Created by Anthony Verruijt on 16/11/2025.
//

import SwiftUI

struct OnboardingPagerView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var index: Int = 0
    private let slides = OnboardingSlide.loveleeInspired
    let completion: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            TabView(selection: $index) {
                ForEach(Array(slides.enumerated()), id: \.offset) { offset, slide in
                    OnboardingSlideView(slide: slide, darkMode: colorScheme == .dark)
                        .tag(offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(maxHeight: 520)
            pageDots
            primaryButton
                .padding(.horizontal, 32)
            Spacer(minLength: 32)
        }
        .padding(.top, 32)
        .background(OnboardingBackground(dark: colorScheme == .dark).ignoresSafeArea())
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: index)
    }
    
    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<slides.count, id: \.self) { i in
                Circle()
                    .fill(i == index ? Color(red: 0.42, green: 0.27, blue: 0.23) : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
    }
    
    private var primaryButton: some View {
        Button {
            if index < slides.count - 1 {
                withAnimation {
                    index += 1
                }
            } else {
                completion()
            }
        } label: {
            Text(index == slides.count - 1 ? "get started" : "next")
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.42, green: 0.27, blue: 0.23),
                                    Color(red: 0.52, green: 0.32, blue: 0.28)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .foregroundStyle(.white)
                .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .buttonStyle(.plain)
        .shadow(color: Color.black.opacity(0.2), radius: 12, y: 8)
    }
}

private struct OnboardingSlideView: View {
    let slide: OnboardingSlide
    let darkMode: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)
            Image(slide.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 220, height: 220)
                .shadow(color: Color.black.opacity(darkMode ? 0.4 : 0.15), radius: 25, y: 12)
            VStack(spacing: 8) {
                Text(slide.title)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                Text(slide.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 40)
    }
}

private struct OnboardingBackground: View {
    let dark: Bool
    
    var body: some View {
        (dark ? Color(red: 0.07, green: 0.06, blue: 0.05) : Color(red: 0.99, green: 0.97, blue: 0.96))
    }
}

struct OnboardingSlide: Identifiable {
    let id = UUID()
    let assetName: String
    let title: String
    let subtitle: String
    
    static let loveleeInspired: [OnboardingSlide] = [
        .init(
            assetName: "horse",
            title: "meet your cozy farm",
            subtitle: "unlock a barn buddy that wakes up when you doodle together"
        ),
        .init(
            assetName: "chicken",
            title: "draw live with your duo",
            subtitle: "share playful notes, dares, and prompts at the same time"
        ),
        .init(
            assetName: "sheep",
            title: "pin love on widgets",
            subtitle: "streaks and doodles appear right on your homescreen hearts"
        ),
        .init(
            assetName: "pig",
            title: "ready to start doodling?",
            subtitle: "grab your duo code and grow the cutest shared farm"
        )
    ]
}

#Preview {
    OnboardingPagerView { }
}
