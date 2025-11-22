//
//  EcosystemHealthView.swift
//  doodleduo
//
//  Modern farm ecosystem health monitoring and feeding interface
//

import SwiftUI
import Combine

struct EcosystemHealthView: View {
    @ObservedObject var sessionManager: CoupleSessionManager
    @State private var showFeedingSheet = false
    @Environment(\.colorScheme) private var colorScheme
    
    private var healthPercentage: Double {
        sessionManager.overallFarmHealth
    }
    
    private var criticalCount: Int {
        sessionManager.criticalAnimalsCount
    }
    
    private var warningMessage: String {
        sessionManager.farmHealthWarning
    }
    
    private var healthColor: Color {
        if healthPercentage > 0.7 {
            return Color(red: 0.55, green: 0.89, blue: 0.75) // Healthy green
        } else if healthPercentage > 0.3 {
            return Color(red: 0.99, green: 0.63, blue: 0.32) // Warning orange
        } else {
            return Color(red: 0.87, green: 0.19, blue: 0.26) // Critical red
        }
    }
    
    private var needsAttention: Bool {
        healthPercentage < 0.7
    }
    
    private var hasPlantsInInventory: Bool {
        guard let inventory = sessionManager.ecosystem?.plantInventory else { return false }
        return inventory.contains { $0.value > 0 }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Health overview
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: needsAttention ? "exclamationmark.triangle.fill" : "heart.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(healthColor)
                    
                    Text(needsAttention ? "animals need care" : "farm healthy")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
                
                Spacer()
                
                Button {
                    showFeedingSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "leaf.fill")
                            .font(.caption2.weight(.bold))
                        Text(hasPlantsInInventory ? "feed animals" : "no plants")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(hasPlantsInInventory ? Color(red: 0.55, green: 0.89, blue: 0.75) : Color.white.opacity(0.15))
                    )
                }
                .buttonStyle(.plain)
                .disabled(!hasPlantsInInventory)
            }
            
            // Health bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.black.opacity(0.25))
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [healthColor, healthColor.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * max(0.05, healthPercentage))
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: healthPercentage)
                }
            }
            .frame(height: 8)
            
            // Warning message
            if needsAttention {
                VStack(spacing: 4) {
                    Text(warningMessage)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(healthColor)
                        .multilineTextAlignment(.center)
                    Text(hasPlantsInInventory ? "Select an animal and spend plants to heal it." : "Buy plants in the shop to keep each animal alive.")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.25))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(healthColor.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        .sheet(isPresented: $showFeedingSheet) {
            AnimalFeedingSheet(sessionManager: sessionManager)
        }
        .onAppear {
            // Initialize ecosystem when view appears
            Task {
                if sessionManager.ecosystem == nil {
                    await sessionManager.initializeEcosystem()
                }
                sessionManager.updateAnimalHealth()
            }
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
            // Update animal health every 30 seconds
            sessionManager.updateAnimalHealth()
        }
    }
}


#if DEBUG
#Preview {
    EcosystemHealthView(sessionManager: .preview)
        .background(Color.gray)
}
#endif

struct AnimalFeedingSheet: View {
    @ObservedObject var sessionManager: CoupleSessionManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedAnimal: String?
    @State private var feedMessage: String?
    
    private var animals: [String: AnimalHealth] {
        sessionManager.ecosystem?.animalHealthMap ?? [:]
    }
    
    private var displayedAnimals: [(String, AnimalHealth)] {
        var seenTypes = Set<String>()
        var ordered: [(String, AnimalHealth)] = []
        for key in animals.keys.sorted() {
            if let animal = animals[key],
               seenTypes.insert(animal.animalType).inserted {
                ordered.append((key, animal))
            }
        }
        return ordered
    }
    
    private var plantInventory: [String: Int] {
        sessionManager.ecosystem?.plantInventory ?? [:]
    }
    
    private var availablePlants: [PlantInfo] {
        PlantCatalog.all.filter { plant in
            (plantInventory[plant.id] ?? 0) > 0
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CozyPalette.background(for: colorScheme)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        if animals.isEmpty {
                            EmptyFarmView()
                        } else {
                            animalList
                            
                            if !availablePlants.isEmpty {
                                plantInventoryView
                            } else {
                                noFoodView
                            }

                            if let feedMessage {
                                Text(feedMessage)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color(red: 0.55, green: 0.89, blue: 0.75))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(Color.white.opacity(0.1))
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Feed Animals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    private var animalList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Animals")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
            
            ForEach(displayedAnimals, id: \.0) { animalId, animal in
                AnimalHealthCard(
                    animal: animal,
                    isSelected: selectedAnimal == animalId,
                    onSelect: { selectedAnimal = animalId }
                )
            }
        }
    }
    
    private var plantInventoryView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Plant Inventory")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
            
            if selectedAnimal == nil {
                Text("Select an animal above to feed it")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.vertical, 20)
            } else {
                ForEach(availablePlants) { plant in
                    PlantInventoryCard(
                        plant: plant,
                        quantity: plantInventory[plant.id] ?? 0,
                        onFeed: {
                            feedSelectedAnimal(with: plant)
                        }
                    )
                }
            }
        }
    }
    
    private var noFoodView: some View {
        VStack(spacing: 16) {
            Image(systemName: "leaf")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.6))
            
            Text("No Plants Available")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
            
            Text("Buy plants from the shop to feed your animals!")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }
    
    private func feedSelectedAnimal(with plant: PlantInfo) {
        guard let animalId = selectedAnimal else { return }
        
        let success = sessionManager.feedAnimal(animalId: animalId, with: plant.id)
        
        if success {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            selectedAnimal = nil
            feedMessage = "Restored +\(Int(plant.nutritionValue)) hp!"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation {
                    feedMessage = nil
                }
            }
        }
    }
}

struct AnimalHealthCard: View {
    let animal: AnimalHealth
    let isSelected: Bool
    let onSelect: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    private var animalInfo: AnimalInfo? {
        AnimalCatalog.animal(byID: animal.animalType)
    }
    
    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: 16) {
                if let info = animalInfo {
                    Image(info.assetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 50, height: 50)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(animal.animalType.capitalized)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    
                    HStack(spacing: 8) {
                        Text(animal.statusIcon)
                            .font(.caption)
                        
                        Text("\(Int(animal.healthPercentage * 100))% hp · \(Int(animal.hoursUntilDeath))h left")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.2))
                            
                            Capsule()
                                .fill(animal.warningLevel == .healthy ? Color.green : (animal.warningLevel == .warning ? Color.orange : Color.red))
                                .frame(width: geometry.size.width * animal.healthPercentage)
                        }
                    }
                    .frame(height: 4)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color(red: 0.55, green: 0.89, blue: 0.75))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(CozyPalette.cardBackground(for: colorScheme).opacity(isSelected ? 0.8 : 0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isSelected ? Color(red: 0.55, green: 0.89, blue: 0.75) : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct PlantInventoryCard: View {
    let plant: PlantInfo
    let quantity: Int
    let onFeed: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 16) {
            Image(plant.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(plant.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                
                Text(plant.feedingBonus)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color(red: 0.55, green: 0.89, blue: 0.75))
            }
            
            Spacer()
            
            Text("x\(quantity)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white.opacity(0.8))
            
            Button {
                onFeed()
            } label: {
                Text("Feed")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color(red: 0.55, green: 0.89, blue: 0.75))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(CozyPalette.cardBackground(for: colorScheme).opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct EmptyFarmView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "pawprint")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.6))
            
            Text("No Animals Yet")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
            
            Text("Buy animals from the shop to start your farm!")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }
}
