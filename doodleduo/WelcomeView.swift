//
//  WelcomeView.swift
//  doodleduo
//
//  Created by Anthony Verruijt on 16/11/2025.
//

import SwiftUI

struct WelcomeView: View {
    var startAction: () -> Void = {}
    @Environment(\.colorScheme) private var colorScheme
    @State private var heroPulse = false
    
    private var palette: WelcomePalette {
        WelcomePalette(colorScheme: colorScheme)
    }
    
    var body: some View {
        ZStack {
            AuraBackground(pulsing: heroPulse, palette: palette)
                .ignoresSafeArea()
    
            VStack(spacing: 18) {
                HeroCard(isPulsing: heroPulse, palette: palette)
                CopyBlock()
                FeatureChips()
                CTAButtons(palette: palette, startAction: startAction)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 28)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaPadding(.vertical, 32)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                heroPulse = true
            }
        }
    }
}

// MARK: - Sections

private struct HeroCard: View {
    let isPulsing: Bool
    let palette: WelcomePalette
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 44, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: palette.heroGradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 44, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.55), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.15), radius: 28, y: 18)
                .overlay(alignment: .bottom) {
                    LinearGradient(
                        colors: [.white.opacity(0.2), .clear],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                    .frame(height: 90)
                }
            
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.4))
                        .blur(radius: 26)
                        .frame(width: 210, height: 210)
                        .scaleEffect(isPulsing ? 1.05 : 0.97)
                        .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: isPulsing)
                    
                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 210, maxHeight: 210)
                        .shadow(color: palette.heroShadow.opacity(0.6), radius: 20, y: 10)
                        .padding(.top, 6)
                }
                
                Text("doodleduo")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .textCase(.lowercase)
                    .foregroundStyle(palette.heroNameColor)
                
                Text("two tiny hearts, one shared farm")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.lowercase)
            }
            .padding(.vertical, 32)
            .padding(.horizontal, 28)
            .overlay {
                AnimatedHeartsOverlay(palette: palette)
                    .padding(.horizontal, 40)
                    .padding(.top, 40)
            }
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))
        .shadow(color: palette.heroShadow.opacity(0.35), radius: 28, y: 18)
    }
}

private struct CopyBlock: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("live cozy doodles for couples")
                .font(.title3.weight(.bold))
                .multilineTextAlignment(.center)
            Text("sketch love notes, leave tiny dares, toss love pings, and level up a gentle farm that mirrors your vibe.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 6)
        .textCase(.lowercase)
    }
}

private struct FeatureChips: View {
    let features: [(String, String)] = [
        ("realtime board", "pencil.tip"),
        ("cozy farm", "leaf"),
        ("widget hearts", "sparkles"),
        ("hardcore streak", "flame"),
        ("daily prompts", "calendar"),
        ("love pings", "heart.circle")
    ]
    
    private let columns = [
        GridItem(.flexible(minimum: 110), spacing: 12),
        GridItem(.flexible(minimum: 110), spacing: 12),
        GridItem(.flexible(minimum: 110), spacing: 12)
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(features, id: \.0) { item in
                Label(item.0, systemImage: item.1)
                    .font(.footnote.weight(.medium))
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                    )
            }
        }
    }
}

private struct CTAButtons: View {
    let palette: WelcomePalette
    let startAction: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Button {
                startAction()
            } label: {
                Label("start your duo journey", systemImage: "heart.circle.fill")
                    .font(.headline.weight(.bold))
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryCTAStyle(gradient: palette.ctaGradient))
        }
    }
}

// MARK: - Reusable helpers

private struct AnimatedHeartsOverlay: View {
    struct HeartSpec: Identifiable {
        let id = UUID()
        let startX: CGFloat
        let amplitude: CGFloat
        let speed: Double
        let delay: Double
        let scale: CGFloat
        let colorIndex: Int
    }
    
    let palette: WelcomePalette
    
    private let hearts: [HeartSpec] = [
        .init(startX: 0.2, amplitude: 18, speed: 8, delay: 0.1, scale: 1.0, colorIndex: 0),
        .init(startX: 0.45, amplitude: 22, speed: 9.5, delay: 0.4, scale: 0.9, colorIndex: 1),
        .init(startX: 0.65, amplitude: 26, speed: 7.3, delay: 0.7, scale: 1.1, colorIndex: 2),
        .init(startX: 0.85, amplitude: 18, speed: 6.4, delay: 0.2, scale: 0.8, colorIndex: 3),
        .init(startX: 0.35, amplitude: 24, speed: 10.2, delay: 0.85, scale: 0.7, colorIndex: 4)
    ]
    
    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                ZStack {
                    ForEach(hearts) { heart in
                        HeartShape()
                            .fill(heartColor(for: heart).opacity(0.75))
                            .frame(width: 20 * heart.scale, height: 18 * heart.scale)
                            .position(position(for: heart, in: proxy.size, time: time))
                            .opacity(opacity(for: heart, time: time))
                            .blur(radius: 0.4)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
    
    private func normalizedProgress(for heart: HeartSpec, time: Double) -> Double {
        let raw = time / heart.speed + heart.delay
        return raw - floor(raw)
    }
    
    private func position(for heart: HeartSpec, in size: CGSize, time: Double) -> CGPoint {
        let progress = normalizedProgress(for: heart, time: time)
        let y = size.height * (1 - progress)
        let xBase = size.width * heart.startX
        let drift = sin(progress * .pi * 2) * heart.amplitude
        return CGPoint(x: xBase + drift, y: y)
    }
    
    private func opacity(for heart: HeartSpec, time: Double) -> Double {
        let progress = normalizedProgress(for: heart, time: time)
        let fadeIn = min(progress / 0.25, 1)
        let fadeOut = min((1 - progress) / 0.25, 1)
        return fadeIn * fadeOut
    }
    
    private func heartColor(for heart: HeartSpec) -> Color {
        guard !palette.heartColors.isEmpty else { return .pink }
        return palette.heartColors[heart.colorIndex % palette.heartColors.count]
    }
}

private struct HeartShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        path.move(to: CGPoint(x: width / 2, y: height))
        path.addCurve(
            to: CGPoint(x: 0, y: height / 3),
            control1: CGPoint(x: width / 2, y: height * 0.8),
            control2: CGPoint(x: 0, y: height * 0.6)
        )
        path.addArc(
            center: CGPoint(x: width / 4, y: height / 3),
            radius: width / 4,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addArc(
            center: CGPoint(x: width * 3 / 4, y: height / 3),
            radius: width / 4,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addCurve(
            to: CGPoint(x: width / 2, y: height),
            control1: CGPoint(x: width, y: height * 0.6),
            control2: CGPoint(x: width / 2, y: height * 0.8)
        )
        return path
    }
}

private struct PrimaryCTAStyle: ButtonStyle {
    let gradient: [Color]
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: (gradient.last ?? .black).opacity(0.35),
                            radius: configuration.isPressed ? 6 : 16,
                            y: 12)
            )
            .foregroundStyle(.white)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.32, dampingFraction: 0.85), value: configuration.isPressed)
    }
}

private struct AuraBackground: View {
    let pulsing: Bool
    let palette: WelcomePalette
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: palette.backgroundGradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            Circle()
                .fill(palette.topGlow)
                .frame(width: 420, height: 420)
                .blur(radius: 120)
                .offset(x: pulsing ? -80 : -40, y: -260)
                .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: pulsing)
            
            Circle()
                .fill(palette.bottomGlow)
                .frame(width: 360, height: 360)
                .blur(radius: 140)
                .offset(x: pulsing ? 120 : 80, y: 240)
                .animation(.easeInOut(duration: 3.6).repeatForever(autoreverses: true), value: pulsing)
        }
    }
}

private struct WelcomePalette {
    let backgroundGradient: [Color]
    let topGlow: Color
    let bottomGlow: Color
    let heroGradient: [Color]
    let heroShadow: Color
    let heroNameColor: Color
    let ctaGradient: [Color]
    let heartColors: [Color]
    
    init(colorScheme: ColorScheme) {
        if colorScheme == .dark {
            backgroundGradient = [
                Color(red: 0.05, green: 0.04, blue: 0.03),
                Color(red: 0.09, green: 0.07, blue: 0.06),
                Color(red: 0.14, green: 0.11, blue: 0.09)
            ]
            topGlow = Color.white.opacity(0.08)
            bottomGlow = Color(red: 0.42, green: 0.28, blue: 0.2).opacity(0.6)
            heroGradient = [
                Color(red: 0.19, green: 0.16, blue: 0.14),
                Color(red: 0.24, green: 0.2, blue: 0.18),
                Color(red: 0.29, green: 0.24, blue: 0.21)
            ]
            heroShadow = Color.black
            heroNameColor = Color(red: 0.98, green: 0.94, blue: 0.9)
            ctaGradient = [
                Color(red: 0.6, green: 0.39, blue: 0.32),
                Color(red: 0.45, green: 0.28, blue: 0.24)
            ]
            heartColors = [
                Color(red: 0.94, green: 0.58, blue: 0.58),
                Color(red: 0.87, green: 0.49, blue: 0.53),
                Color(red: 0.76, green: 0.42, blue: 0.47),
                Color(red: 0.84, green: 0.57, blue: 0.5),
                Color(red: 0.95, green: 0.68, blue: 0.58)
            ]
        } else {
            backgroundGradient = [
                Color(red: 0.97, green: 0.95, blue: 0.94),
                Color(red: 0.93, green: 0.91, blue: 0.95),
                Color(red: 0.89, green: 0.92, blue: 0.96)
            ]
            topGlow = Color.white.opacity(0.3)
            bottomGlow = Color(red: 0.93, green: 0.82, blue: 0.74).opacity(0.45)
            heroGradient = [
                Color(red: 0.97, green: 0.95, blue: 0.94),
                Color(red: 0.92, green: 0.88, blue: 0.94),
                Color(red: 0.88, green: 0.9, blue: 0.95)
            ]
            heroShadow = Color(red: 0.39, green: 0.25, blue: 0.23)
            heroNameColor = Color(red: 0.39, green: 0.25, blue: 0.23)
            ctaGradient = [
                Color(red: 0.89, green: 0.53, blue: 0.63),
                Color(red: 0.68, green: 0.46, blue: 0.73)
            ]
            heartColors = [
                Color(red: 0.98, green: 0.62, blue: 0.73),
                Color(red: 0.92, green: 0.52, blue: 0.78),
                Color(red: 0.78, green: 0.54, blue: 0.86),
                Color(red: 0.84, green: 0.66, blue: 0.94),
                Color(red: 0.94, green: 0.69, blue: 0.82)
            ]
        }
    }
}

#Preview {
    WelcomeView()
        .environment(\.colorScheme, .light)
}
