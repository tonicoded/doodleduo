//
//  PlantCatalog.swift
//  doodleduo
//
//  Plant shop catalog and feeding system for animal care
//

import Foundation

struct PlantInfo: Identifiable, Codable {
    let id: String
    let name: String
    let assetName: String
    let cost: Int
    let nutritionValue: Double // Health restored in percent (0-100)
    let unlockDay: Int
    let description: String

    var feedingBonus: String {
        "+\(Int(nutritionValue)) hp"
    }
}

enum PlantCatalog {
    static let wheat = PlantInfo(
        id: "wheat",
        name: "Wheat",
        assetName: "wheat",
        cost: 30,
        nutritionValue: 20.0,
        unlockDay: 0,
        description: "Basic crop that restores 20hp to a single animal."
    )
    
    static let tomatoes = PlantInfo(
        id: "tomatoes", 
        name: "Tomatoes", 
        assetName: "tomatoes", 
        cost: 55, 
        nutritionValue: 30.0, 
        unlockDay: 3,
        description: "Healthy produce that heals 30hp."
    )
    
    static let potatoes = PlantInfo(
        id: "potatoes", 
        name: "Potatoes", 
        assetName: "potatoes", 
        cost: 80, 
        nutritionValue: 40.0, 
        unlockDay: 5,
        description: "Premium harvest that restores a massive 40hp."
    )

    static let all: [PlantInfo] = [
        wheat,
        tomatoes,
        potatoes
    ]

    static func plant(byID id: String) -> PlantInfo? {
        all.first { $0.id == id }
    }

    static func availablePlants(forDay day: Int) -> [PlantInfo] {
        all.filter { $0.unlockDay <= day }
    }

    static func canAfford(_ plant: PlantInfo, withLovePoints points: Int) -> Bool {
        points >= plant.cost
    }
}

// Enhanced animal health system with individual animal tracking
struct AnimalHealth: Codable, Identifiable, Equatable {
    let id: String // animal ID
    let animalType: String
    var lastFedAt: Date
    var hoursUntilDeath: Double
    var maxHealth: Double { 24.0 } // 24 hours max life

    var healthPercentage: Double {
        max(0, min(1, hoursUntilDeath / maxHealth))
    }

    // Equatable conformance - round health to prevent tiny differences from triggering updates
    static func == (lhs: AnimalHealth, rhs: AnimalHealth) -> Bool {
        lhs.id == rhs.id &&
        lhs.animalType == rhs.animalType &&
        abs(lhs.hoursUntilDeath - rhs.hoursUntilDeath) < 0.01 // Only 0.01 hour difference (~36 seconds)
    }
    
    var isHealthy: Bool {
        hoursUntilDeath > 8.0
    }
    
    var isDying: Bool {
        hoursUntilDeath <= 8.0 && hoursUntilDeath > 2.0
    }
    
    var isCritical: Bool {
        hoursUntilDeath <= 2.0 && hoursUntilDeath > 0
    }
    
    var isDead: Bool {
        hoursUntilDeath <= 0
    }
    
    var statusIcon: String {
        if isDead {
            return "💀"
        } else if isCritical {
            return "🔴"
        } else if isDying {
            return "🟡"
        } else {
            return "🟢"
        }
    }
    
    var warningLevel: AnimalWarningLevel {
        if isDead {
            return .dead
        } else if isCritical {
            return .critical
        } else if isDying {
            return .warning
        } else {
            return .healthy
        }
    }
    
    enum AnimalWarningLevel {
        case healthy
        case warning  
        case critical
        case dead
        
        var message: String {
            switch self {
            case .healthy:
                return "Animals are happy and healthy!"
            case .warning:
                return "⚠️ Animals need plants soon—buy crops in the shop to replenish them."
            case .critical:
                return "🚨 URGENT! Purchase plants now or the farm will collapse."
            case .dead:
                return "💀 Some animals have died from starvation."
            }
        }
    }
    
    static func create(for animalType: String) -> AnimalHealth {
        AnimalHealth(
            id: UUID().uuidString,
            animalType: animalType,
            lastFedAt: Date(),
            hoursUntilDeath: 24.0
        )
    }
    
    static func calculate(from lastActivity: Date) -> AnimalHealth {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastActivity)
        let hoursElapsed = elapsed / 3600
        let hoursRemaining = max(0, 24.0 - hoursElapsed)
        
        return AnimalHealth(
            id: UUID().uuidString,
            animalType: "unknown",
            lastFedAt: lastActivity,
            hoursUntilDeath: hoursRemaining
        )
    }
    
    mutating func feed(with plant: PlantInfo) {
        let now = Date()
        lastFedAt = now
        // Convert nutrition value (percentage) into hours and add to current health
        let healthGainHours = maxHealth * (plant.nutritionValue / 100.0)
        hoursUntilDeath = min(maxHealth, hoursUntilDeath + healthGainHours)
    }
    
    mutating func updateHealth() {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastFedAt)
        let hoursElapsed = elapsed / 3600
        // Don't recalculate from max health - just subtract elapsed time from current health
        hoursUntilDeath = max(0, hoursUntilDeath - hoursElapsed)
        // Update the timestamp
        lastFedAt = now
    }
}

// Farm ecosystem with individual animal tracking
struct FarmEcosystem: Codable {
    let roomId: UUID
    var animalHealthMap: [String: AnimalHealth] = [:]
    var plantInventory: [String: Int] = [:] // plantID : quantity
    var lastUpdatedAt: Date
    
    init(roomId: UUID) {
        self.roomId = roomId
        self.lastUpdatedAt = Date()
    }
    
    var id: UUID { roomId }
    
    var overallHealthPercentage: Double {
        guard !animalHealthMap.isEmpty else { return 1.0 }
        
        let livingAnimals = animalHealthMap.values.filter { !$0.isDead }
        guard !livingAnimals.isEmpty else { return 0.0 }
        
        let totalHealth = livingAnimals.reduce(0) { $0 + $1.healthPercentage }
        return totalHealth / Double(livingAnimals.count)
    }
    
    var criticalAnimalsCount: Int {
        animalHealthMap.values.filter { $0.isCritical }.count
    }
    
    var deadAnimalsCount: Int {
        animalHealthMap.values.filter { $0.isDead }.count
    }
    
    var worstWarningLevel: AnimalHealth.AnimalWarningLevel {
        let levels = animalHealthMap.values.map { $0.warningLevel }
        
        if levels.contains(.dead) {
            return .dead
        } else if levels.contains(.critical) {
            return .critical
        } else if levels.contains(.warning) {
            return .warning
        } else {
            return .healthy
        }
    }
    
    mutating func addAnimal(_ animalType: String) {
        let animalId = "\(animalType)_\(UUID().uuidString.prefix(8))"
        animalHealthMap[animalId] = AnimalHealth.create(for: animalType)
    }
    
    mutating func feedAnimal(animalId: String, with plant: PlantInfo) -> Bool {
        guard var animal = animalHealthMap[animalId],
              let plantCount = plantInventory[plant.id],
              plantCount > 0 else {
            return false
        }
        
        // Feed the animal
        animal.feed(with: plant)
        animalHealthMap[animalId] = animal
        
        // Consume one plant
        plantInventory[plant.id] = plantCount - 1
        if plantInventory[plant.id] == 0 {
            plantInventory.removeValue(forKey: plant.id)
        }
        
        lastUpdatedAt = Date()
        return true
    }
    
    mutating func buyPlant(_ plant: PlantInfo, quantity: Int = 1) {
        let currentCount = plantInventory[plant.id] ?? 0
        plantInventory[plant.id] = currentCount + quantity
        lastUpdatedAt = Date()
    }
    
    mutating func updateAllAnimalHealth() {
        for (animalId, var animal) in animalHealthMap {
            animal.updateHealth()
            animalHealthMap[animalId] = animal
        }
        lastUpdatedAt = Date()
    }
    
    // Remove dead animals from farm (optional - for cleanup)
    mutating func removeDeadAnimals() {
        animalHealthMap = animalHealthMap.filter { !$1.isDead }
    }
    
    enum CodingKeys: String, CodingKey {
        case roomId = "room_id"
        case animalHealthMap = "animal_health_map"
        case plantInventory = "plant_inventory"
        case lastUpdatedAt = "last_updated_at"
    }
}
