//
//  SplashView.swift
//  doodleduo
//
//  Created by Anthony Verruijt on 16/11/2025.
//

import SwiftUI

struct SplashView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var progress: CGFloat = 0.25
    @State private var pulse = false
    
    private var gradient: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.05, green: 0.04, blue: 0.03),
                Color(red: 0.09, green: 0.07, blue: 0.06),
                Color(red: 0.13, green: 0.1, blue: 0.09)
            ]
        } else {
            return [
                Color(red: 0.99, green: 0.97, blue: 0.95),
                Color(red: 0.97, green: 0.94, blue: 0.9),
                Color(red: 0.95, green: 0.9, blue: 0.85)
            ]
        }
    }
    
    private var accentColor: Color {
        colorScheme == .dark
        ? Color(red: 0.84, green: 0.59, blue: 0.5)
        : Color(red: 0.89, green: 0.56, blue: 0.54)
    }
    
    var body: some View {
        ZStack {
            LinearGradient(colors: gradient, startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 180, height: 180)
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.5 : 0.2), radius: 20, y: 12)
                    .scaleEffect(pulse ? 1.03 : 0.97)
                    .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: pulse)
                
                VStack(spacing: 6) {
                    Text("doodleduo")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary)
                        .textCase(.lowercase)
                    Text("loading cozy canvas…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .textCase(.lowercase)
                }
                
                SplashProgress(progress: progress, tint: accentColor)
                    .frame(height: 6)
                    .padding(.horizontal, 40)
                    .accessibilityLabel("Loading progress")
                    .accessibilityValue("\(Int(progress * 100)) percent")
                Spacer()
                Text("love-filled sync • realtime doodles")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.lowercase)
                    .padding(.bottom, 32)
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            pulse = true
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                progress = 0.95
            }
        }
    }
}

private struct SplashProgress: View {
    let progress: CGFloat
    let tint: Color
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.35))
                Capsule()
                    .fill(tint)
                    .frame(width: geo.size.width * progress)
                    .shadow(color: tint.opacity(0.4), radius: 8, y: 4)
            }
        }
    }
}

#Preview {
    SplashView()
        .environment(\.colorScheme, .light)
}
