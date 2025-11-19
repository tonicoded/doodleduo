//
//  AnimalView.swift
//  doodleduo
//
//  Created by Claude Code on 17/11/2025.
//

import SwiftUI

struct AnimalView: View {
    let name: String
    let isSleeping: Bool

    @State private var walkOffset: CGPoint = .zero
    @State private var isAnimating = false
    @State private var walkDirection: CGFloat = 1 // 1 for right, -1 for left
    @State private var currentTarget: CGPoint = .zero

    var body: some View {
        ZStack {
            // Animal image
            Image(name)
                .resizable()
                .scaledToFit()
                .frame(width: animalSize.width, height: animalSize.height)
                .opacity(isSleeping ? 0.6 : 1.0)
                .scaleEffect(x: (isSleeping ? 0.9 : 1.0) * walkDirection, y: isSleeping ? 0.9 : 1.0)
                .offset(x: walkOffset.x, y: walkOffset.y)
                .animation(.easeInOut(duration: 0.3), value: walkDirection)

            // Sleeping indicator
            if isSleeping {
                Text("💤")
                    .font(.title3)
                    .offset(x: walkOffset.x + 25, y: walkOffset.y - 30)
                    .opacity(isAnimating ? 1.0 : 0.5)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isAnimating)
            }
        }
        .onAppear {
            startWalkingAnimation()
        }
    }

    private var animalSize: CGSize {
        switch name {
        case "chicken":
            return CGSize(width: 70, height: 70)
        case "sheep":
            return CGSize(width: 90, height: 80)
        case "pig":
            return CGSize(width: 85, height: 75)
        case "horse":
            return CGSize(width: 100, height: 95)
        default:
            return CGSize(width: 80, height: 80)
        }
    }

    private func startWalkingAnimation() {
        isAnimating = true
        
        if isSleeping {
            // Just gentle swaying for sleeping animals
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                walkOffset = CGPoint(x: 0, y: 3)
            }
        } else {
            // Start walking around
            moveToRandomTarget()
        }
    }
    
    private func moveToRandomTarget() {
        guard !isSleeping else { return }
        
        // Define walking boundaries (stay within farm area)
        let walkingBounds = CGRect(x: -60, y: -20, width: 120, height: 40)
        
        // Pick a random target within bounds
        let targetX = CGFloat.random(in: walkingBounds.minX...walkingBounds.maxX)
        let targetY = CGFloat.random(in: walkingBounds.minY...walkingBounds.maxY)
        let newTarget = CGPoint(x: targetX, y: targetY)
        
        // Update direction based on movement
        let deltaX = newTarget.x - walkOffset.x
        if deltaX != 0 {
            walkDirection = deltaX > 0 ? 1 : -1
        }
        
        // Calculate walk duration based on distance
        let distance = sqrt(pow(deltaX, 2) + pow(newTarget.y - walkOffset.y, 2))
        let duration = Double(distance / 30) + 0.5 // Slower walking
        
        currentTarget = newTarget
        
        // Animate to new position
        withAnimation(.easeInOut(duration: duration)) {
            walkOffset = newTarget
        }
        
        // Schedule next movement
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + Double.random(in: 1.0...3.0)) {
            moveToRandomTarget()
        }
    }
}

#Preview {
    ZStack {
        Color.green.opacity(0.3).ignoresSafeArea()

        VStack(spacing: 30) {
            HStack(spacing: 40) {
                AnimalView(name: "chicken", isSleeping: false)
                AnimalView(name: "sheep", isSleeping: false)
            }
            HStack(spacing: 40) {
                AnimalView(name: "pig", isSleeping: true)
                AnimalView(name: "horse", isSleeping: false)
            }
        }
    }
}
