//
//  AnimalShopView.swift
//  doodleduo
//
//  Animal shop for purchasing animals with love points
//

import SwiftUI

struct AnimalShopView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var sessionManager: CoupleSessionManager
    @State private var purchasingAnimal: AnimalInfo?
    @State private var showPurchaseSuccess = false
    @State private var selectedTab: ShopTab = .animals
    @State private var purchasingPlant: PlantInfo?
    @State private var showPlantSuccess = false
    
    enum ShopTab: String, CaseIterable {
        case animals = "Animals"
        case plants = "Plants"
        
        var icon: String {
            switch self {
            case .animals: return "pawprint.fill"
            case .plants: return "leaf.fill"
            }
        }
    }

    private var lovePoints: Int {
        sessionManager.metrics?.loveEnergy ?? 0
    }

    private var currentDay: Int {
        sessionManager.metrics?.currentStreak ?? 1
    }

    private var ownedAnimals: Set<String> {
        Set(sessionManager.farm?.unlockedAnimals ?? ["chicken"])
    }

    private var availableAnimals: [AnimalInfo] {
        AnimalCatalog.availableAnimals(forDay: currentDay)
    }

    var body: some View {
        ZStack {
            CozyPalette.background(for: colorScheme)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.top, 20)
                    .padding(.bottom, 16)
                
                // Tab Selector
                tabSelector
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                ScrollView {
                    VStack(spacing: 12) {
                        if selectedTab == .animals {
                            ForEach(AnimalCatalog.all) { animal in
                                animalCard(for: animal)
                            }
                        } else {
                            ForEach(PlantCatalog.all) { plant in
                                plantCard(for: plant)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .overlay {
            if showPurchaseSuccess, let animal = purchasingAnimal {
                purchaseSuccessOverlay(for: animal)
            } else if showPlantSuccess, let plant = purchasingPlant {
                plantSuccessOverlay(for: plant)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "cart.fill")
                    .font(.title2)
                Text(selectedTab == .animals ? "animal shop" : "plant shop")
                    .font(.title.weight(.bold))
            }
            .foregroundStyle(.white)

            HStack(spacing: 6) {
                Image(systemName: "heart.fill")
                    .font(.caption)
                    .foregroundStyle(Color(red: 0.93, green: 0.27, blue: 0.36))
                Text("\(lovePoints) love points available")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.25))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            )
        }
    }
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(ShopTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: tab.icon)
                            .font(.caption)
                        Text(tab.rawValue)
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundStyle(selectedTab == tab ? .white : .white.opacity(0.6))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(selectedTab == tab ? Color.white.opacity(0.2) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.2))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func plantCard(for plant: PlantInfo) -> some View {
        let isUnlocked = plant.unlockDay <= currentDay
        let canAfford = PlantCatalog.canAfford(plant, withLovePoints: lovePoints)
        let canPurchase = isUnlocked && canAfford

        HStack(spacing: 16) {
            Image(plant.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .background(
                    Circle()
                        .fill(Color.white.opacity(isUnlocked ? 0.12 : 0.05))
                )
                .opacity(isUnlocked ? 1.0 : 0.4)

            VStack(alignment: .leading, spacing: 4) {
                Text(plant.name.lowercased())
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)

                Text(plant.description)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(2)

                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                            .foregroundStyle(Color(red: 0.93, green: 0.27, blue: 0.36))
                        Text("\(plant.cost) pts")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    
                    Text(plant.feedingBonus)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color(red: 0.55, green: 0.89, blue: 0.75))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color(red: 0.55, green: 0.89, blue: 0.75).opacity(0.15))
                        )
                }

                if plant.unlockDay > currentDay {
                    Text("unlocks after \(plant.unlockDay) days survived")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color(red: 0.99, green: 0.63, blue: 0.32))
                }
            }

            Spacer()

            plantPurchaseButton(
                for: plant,
                canPurchase: canPurchase,
                isUnlocked: isUnlocked,
                canAfford: canAfford
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(CozyPalette.cardBackground(for: colorScheme).opacity(isUnlocked ? 0.7 : 0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(isUnlocked ? 0.15 : 0.05), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }

    @ViewBuilder
    private func plantPurchaseButton(
        for plant: PlantInfo,
        canPurchase: Bool,
        isUnlocked: Bool,
        canAfford: Bool
    ) -> some View {
        if !isUnlocked {
            Image(systemName: "lock.fill")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.3))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        } else if !canAfford {
            Text("not enough 💔")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        } else {
            Button {
                purchasePlant(plant)
            } label: {
                Text("buy")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.55, green: 0.89, blue: 0.75),
                                        Color(red: 0.45, green: 0.79, blue: 0.65)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func animalCard(for animal: AnimalInfo) -> some View {
        let isOwned = ownedAnimals.contains(animal.id)
        let isUnlocked = animal.unlockDay <= currentDay
        let canAfford = AnimalCatalog.canAfford(animal, withLovePoints: lovePoints)
        let canPurchase = isUnlocked && !isOwned && canAfford

        HStack(spacing: 16) {
            Image(animal.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .background(
                    Circle()
                        .fill(Color.white.opacity(isUnlocked ? 0.12 : 0.05))
                )
                .opacity(isUnlocked ? 1.0 : 0.4)

            VStack(alignment: .leading, spacing: 4) {
                Text(animal.name.lowercased())
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)

                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.caption2)
                        .foregroundStyle(Color(red: 0.93, green: 0.27, blue: 0.36))
                    Text("\(animal.cost) pts")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                }

                if animal.isStarter {
                    Text("starter animal")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.6))
                } else if animal.unlockDay > currentDay {
                    Text("unlocks after \(animal.unlockDay) days survived")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color(red: 0.99, green: 0.63, blue: 0.32))
                }
            }

            Spacer()

            purchaseButton(
                for: animal,
                isOwned: isOwned,
                canPurchase: canPurchase,
                isUnlocked: isUnlocked,
                canAfford: canAfford
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(CozyPalette.cardBackground(for: colorScheme).opacity(isUnlocked ? 0.7 : 0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(isUnlocked ? 0.15 : 0.05), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }

    @ViewBuilder
    private func purchaseButton(
        for animal: AnimalInfo,
        isOwned: Bool,
        canPurchase: Bool,
        isUnlocked: Bool,
        canAfford: Bool
    ) -> some View {
        if isOwned {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                Text("owned")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(Color(red: 0.55, green: 0.89, blue: 0.75))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color(red: 0.55, green: 0.89, blue: 0.75).opacity(0.15))
            )
        } else if !isUnlocked {
            Image(systemName: "lock.fill")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.3))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        } else if !canAfford {
            Text("not enough 💔")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        } else {
            Button {
                purchaseAnimal(animal)
            } label: {
                Text("buy")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 1.0, green: 0.72, blue: 0.58),
                                        Color(red: 0.99, green: 0.63, blue: 0.32)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func purchaseSuccessOverlay(for animal: AnimalInfo) -> some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(animal.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .scaleEffect(showPurchaseSuccess ? 1.0 : 0.5)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showPurchaseSuccess)

                VStack(spacing: 8) {
                    Text("new friend!")
                        .font(.title.weight(.bold))
                        .foregroundStyle(.white)

                    Text("\(animal.name.lowercased()) joined your farm")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(CozyPalette.cardBackground(for: colorScheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.3), radius: 30, y: 15)
        }
        .onTapGesture {
            withAnimation {
                showPurchaseSuccess = false
                purchasingAnimal = nil
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }
    
    @ViewBuilder
    private func plantSuccessOverlay(for plant: PlantInfo) -> some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(plant.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .scaleEffect(showPlantSuccess ? 1.0 : 0.5)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showPlantSuccess)

                VStack(spacing: 8) {
                    Text("fresh food!")
                        .font(.title.weight(.bold))
                        .foregroundStyle(.white)

                    Text("\(plant.name.lowercased()) added to your inventory")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                    
                    Text(plant.feedingBonus)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color(red: 0.55, green: 0.89, blue: 0.75))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color(red: 0.55, green: 0.89, blue: 0.75).opacity(0.15))
                        )
                }
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(CozyPalette.cardBackground(for: colorScheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.3), radius: 30, y: 15)
        }
        .onTapGesture {
            withAnimation {
                showPlantSuccess = false
                purchasingPlant = nil
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }

    private func purchasePlant(_ plant: PlantInfo) {
        print("🌱 Attempting to purchase:", plant.name)

        // Deduct love points
        let newLoveEnergy = lovePoints - plant.cost
        print("💕 Love points: \(lovePoints) - \(plant.cost) = \(newLoveEnergy)")

        Task {
            await sessionManager.purchasePlant(plantID: plant.id, cost: plant.cost)

            await MainActor.run {
                purchasingPlant = plant
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    showPlantSuccess = true
                }

                // Auto-dismiss success message after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        showPlantSuccess = false
                        purchasingPlant = nil
                    }
                }
            }
        }
    }

    private func purchaseAnimal(_ animal: AnimalInfo) {
        print("🛒 Attempting to purchase:", animal.name)

        // Deduct love points
        let newLoveEnergy = lovePoints - animal.cost
        print("💕 Love points: \(lovePoints) - \(animal.cost) = \(newLoveEnergy)")

        // Add animal to farm
        var currentAnimals = sessionManager.farm?.unlockedAnimals ?? ["chicken"]
        if !currentAnimals.contains(animal.id) {
            currentAnimals.append(animal.id)
            print("🐔 New animals list:", currentAnimals)
        }

        // Update session manager (this will need to sync to Supabase)
        // For now, we'll update the local state
        Task {
            await sessionManager.purchaseAnimal(animalID: animal.id, cost: animal.cost)

            await MainActor.run {
                purchasingAnimal = animal
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    showPurchaseSuccess = true
                }

                // Auto-dismiss success message after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        showPurchaseSuccess = false
                        purchasingAnimal = nil
                    }
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    AnimalShopView(sessionManager: .preview)
}
#endif
