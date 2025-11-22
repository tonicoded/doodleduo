//
//  SurvivalBadge.swift
//  doodleduo
//
//  Displays real-time survival counter for couples
//

import SwiftUI

struct SurvivalBadge: View {
    let timeText: String
    let gradient: [Color]
    let glowColor: Color
    
    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "clock.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.9))
                
                Text("survived")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.8))
            }
            
            Text(timeText)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                )
        )
        .shadow(color: glowColor.opacity(0.3), radius: 8, y: 4)
        .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
    }
}

#Preview {
    HStack {
        SurvivalBadge(
            timeText: "7d 6h 45m",
            gradient: [
                Color(red: 1.0, green: 0.72, blue: 0.58),
                Color(red: 0.99, green: 0.63, blue: 0.32)
            ],
            glowColor: Color(red: 0.99, green: 0.63, blue: 0.32)
        )
        
        SurvivalBadge(
            timeText: "0d 2h 15m",
            gradient: [
                Color(red: 1.0, green: 0.72, blue: 0.58),
                Color(red: 0.99, green: 0.63, blue: 0.32)
            ],
            glowColor: Color(red: 0.99, green: 0.63, blue: 0.32)
        )
    }
    .padding()
    .background(Color.black)
}