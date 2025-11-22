//
//  AnimalCatalog.swift
//  doodleduo
//
//  Animal shop catalog and progression system
//

import Foundation

struct AnimalInfo: Identifiable, Codable {
    let id: String
    let name: String
    let assetName: String
    let cost: Int
    let unlockDay: Int

    var isStarter: Bool {
        cost == 0
    }
}

enum AnimalCatalog {
    static let chicken = AnimalInfo(id: "chicken", name: "Chicken", assetName: "chicken", cost: 0, unlockDay: 0)
    static let sheep = AnimalInfo(id: "sheep", name: "Sheep", assetName: "sheep", cost: 50, unlockDay: 1)
    static let pig = AnimalInfo(id: "pig", name: "Pig", assetName: "pig", cost: 100, unlockDay: 3)
    static let duck = AnimalInfo(id: "duck", name: "Duck", assetName: "duck", cost: 150, unlockDay: 4)
    static let horse = AnimalInfo(id: "horse", name: "Horse", assetName: "horse", cost: 200, unlockDay: 5)
    static let goat = AnimalInfo(id: "goat", name: "Goat", assetName: "goat", cost: 250, unlockDay: 6)
    static let cow = AnimalInfo(id: "cow", name: "Cow", assetName: "cow", cost: 300, unlockDay: 7)

    static let all: [AnimalInfo] = [
        chicken,
        sheep,
        pig,
        duck,
        horse,
        goat,
        cow
    ]

    static func animal(byID id: String) -> AnimalInfo? {
        all.first { $0.id == id }
    }

    static func availableAnimals(forDay day: Int) -> [AnimalInfo] {
        all.filter { $0.unlockDay <= day }
    }

    static func canAfford(_ animal: AnimalInfo, withLovePoints points: Int) -> Bool {
        points >= animal.cost
    }
}

struct FarmHealth: Codable {
    let lastActivityAt: Date
    let hoursUntilDeath: Double

    var healthPercentage: Double {
        max(0, min(1, hoursUntilDeath / 24.0))
    }

    var isHealthy: Bool {
        hoursUntilDeath > 6
    }

    var isDying: Bool {
        hoursUntilDeath <= 6 && hoursUntilDeath > 0
    }

    var isDead: Bool {
        hoursUntilDeath <= 0
    }

    var warningLevel: WarningLevel {
        if hoursUntilDeath > 6 {
            return .none
        } else if hoursUntilDeath > 1 {
            return .warning
        } else {
            return .critical
        }
    }

    enum WarningLevel {
        case none
        case warning
        case critical

        var color: String {
            switch self {
            case .none:
                return "green"
            case .warning:
                return "orange"
            case .critical:
                return "red"
            }
        }

        var message: String {
            switch self {
            case .none:
                return ""
            case .warning:
                return "⚠️ Animals need attention! Send an activity to keep them alive"
            case .critical:
                return "🚨 URGENT! Animals are dying! Send an activity now!"
            }
        }
    }

    static func calculate(from lastActivity: Date) -> FarmHealth {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastActivity)
        let hoursElapsed = elapsed / 3600
        let hoursRemaining = 24.0 - hoursElapsed

        return FarmHealth(
            lastActivityAt: lastActivity,
            hoursUntilDeath: hoursRemaining
        )
    }
}
