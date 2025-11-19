//
//  DuoMetrics.swift
//  doodleduo
//
//  Created by Claude Code on 17/11/2025.
//

import Foundation

struct DuoMetrics: Codable, Identifiable {
    let roomId: UUID
    var loveEnergy: Int
    var totalDoodles: Int
    var currentStreak: Int
    var longestStreak: Int
    let createdAt: Date

    var id: UUID { roomId }

    enum CodingKeys: String, CodingKey {
        case roomId = "room_id"
        case loveEnergy = "love_energy"
        case totalDoodles = "total_doodles"
        case currentStreak = "current_streak"
        case longestStreak = "longest_streak"
        case createdAt = "created_at"
    }
}

struct DuoFarm: Codable, Identifiable {
    let roomId: UUID
    var unlockedAnimals: [String]
    var farmLevel: Int
    let createdAt: Date

    var id: UUID { roomId }

    enum CodingKeys: String, CodingKey {
        case roomId = "room_id"
        case unlockedAnimals = "unlocked_animals"
        case farmLevel = "farm_level"
        case createdAt = "created_at"
    }
}
