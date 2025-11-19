//
//  StatBadge.swift
//  doodleduo
//
//  Created by Codex on 27/11/2025.
//

import SwiftUI

struct StatBadge: View {
    let icon: String
    let label: String
    let value: String
    var gradient: [Color] = [.white.opacity(0.9), .white.opacity(0.7)]
    var glowColor: Color = .white
    var showFire: Bool = false
    var animateHeart: Bool = false
    var symbolColor: Color = .white
    
    @State private var heartBeat = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(symbolColor)
                    .scaleEffect(animateHeart ? (heartBeat ? 1.15 : 0.9) : 1)
                    .animation(
                        animateHeart ? .easeInOut(duration: 1.1).repeatForever(autoreverses: true) : .default,
                        value: heartBeat
                    )
                Text(value)
                    .font(.callout.monospacedDigit().weight(.semibold))
            }
            Text(label.uppercased())
                .font(.caption2.weight(.medium))
                .tracking(0.35)
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .foregroundStyle(.white)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.25), lineWidth: 0.8)
                )
        )
        .shadow(color: glowColor.opacity(0.35), radius: 16, y: 10)
        .overlay(alignment: .topTrailing) {
            if showFire {
                FireEmber()
                    .offset(x: 12, y: -10)
            }
        }
        .overlay(alignment: .topLeading) {
            if animateHeart {
                HeartPulse(color: symbolColor)
                    .offset(x: -10, y: -10)
            }
        }
        .onAppear {
            if animateHeart {
                heartBeat = true
            }
        }
    }
}

struct FireEmber: View {
    @State private var flicker = false
    @State private var sparkRise = false
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.0, green: 0.8, blue: 0.4).opacity(0.9),
                            Color(red: 1.0, green: 0.4, blue: 0.1).opacity(0.4)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 22
                    )
                )
                .frame(width: 42, height: 42)
                .blur(radius: flicker ? 8 : 4)
                .scaleEffect(flicker ? 1.15 : 0.85)
            
            Circle()
                .fill(Color.white.opacity(0.8))
                .frame(width: 6, height: 6)
                .offset(x: flicker ? -4 : 4, y: flicker ? -6 : -2)
                .blur(radius: 0.8)
            
            Circle()
                .fill(Color.white.opacity(0.5))
                .frame(width: 3, height: 3)
                .offset(x: sparkRise ? 6 : -6, y: sparkRise ? -22 : -4)
                .blur(radius: 0.5)
        }
        .onAppear {
            flicker = true
            sparkRise = true
        }
        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: flicker)
        .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: sparkRise)
    }
}

struct HeartPulse: View {
    let color: Color
    @State private var ripple = false
    
    var body: some View {
        Circle()
            .stroke(color.opacity(0.6), lineWidth: 1.2)
            .frame(width: 22, height: 22)
            .scaleEffect(ripple ? 1.5 : 0.8)
            .opacity(ripple ? 0 : 0.8)
            .onAppear {
                ripple = true
            }
            .animation(.easeOut(duration: 1.8).repeatForever(autoreverses: false), value: ripple)
    }
}
