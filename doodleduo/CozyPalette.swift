//
//  CozyPalette.swift
//  doodleduo
//
//  Created by Codex on 23/11/2025.
//

import SwiftUI

enum CozyPalette {
    static let lightBackground = Color(red: 0.99, green: 0.97, blue: 0.96)
    static let darkBackground = Color(red: 0.05, green: 0.05, blue: 0.06)
    static let accent = Color(red: 0.42, green: 0.27, blue: 0.23)
    static let secondaryAccent = Color(red: 0.52, green: 0.32, blue: 0.28)
    static let dangerRed = Color(red: 0.87, green: 0.19, blue: 0.26)
    
    // Activity colors
    static let warmPink = Color(red: 0.96, green: 0.46, blue: 0.65)
    static let warmOrange = Color(red: 0.99, green: 0.63, blue: 0.32)
    static let softLavender = Color(red: 0.78, green: 0.69, blue: 0.95)
    static let cozyPeach = Color(red: 1.0, green: 0.72, blue: 0.58)
    static let mintGreen = Color(red: 0.55, green: 0.89, blue: 0.75)
    static let softGray = Color(red: 0.85, green: 0.85, blue: 0.87)
    
    static func background(for scheme: ColorScheme) -> Color {
        scheme == .dark ? darkBackground : lightBackground
    }
    
    static func cardBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.12) : Color.white.opacity(0.9)
    }
    
    static func accentTint(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white : accent
    }
}
