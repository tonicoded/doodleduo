//
//  DisplayNamePromptView.swift
//  doodleduo
//
//  Created by Codex on 23/11/2025.
//

import SwiftUI

struct DisplayNamePromptView: View {
    @ObservedObject var authService: AuthService
    let onComplete: () -> Void
    
    @State private var displayName: String
    @State private var isSaving = false
    @State private var errorMessage: String?
    @Environment(\.colorScheme) private var colorScheme
    
    init(authService: AuthService, onComplete: @escaping () -> Void) {
        self.authService = authService
        self.onComplete = onComplete
        let fallback = authService.currentUser.flatMap { authService.cachedDisplayName(for: $0.id) }
        let seed = authService.profile?.displayName ?? fallback ?? ""
        let normalizedSeed = seed.trimmingCharacters(in: .whitespacesAndNewlines)
        _displayName = State(initialValue: normalizedSeed)
    }
    
    private var isValid: Bool {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("choose your cozy name")
                .font(.title2.bold())
                .textCase(.lowercase)
            Text("this is how your duo sees you across invites, farms, and love pings.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .textCase(.lowercase)
                .padding(.horizontal, 32)
            TextField("your name", text: $displayName)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(CozyPalette.cardBackground(for: colorScheme))
                )
                .padding(.horizontal, 32)
            
            Button {
                Task { await save() }
            } label: {
                Text(isSaving ? "saving…" : "save and continue")
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(CozyPalette.accent, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 32)
            .disabled(!isValid || isSaving)
            
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Spacer()
        }
        .padding(.top, 80)
        .background(CozyPalette.background(for: colorScheme).ignoresSafeArea())
    }
    
    private func save() async {
        guard isValid else { return }
        isSaving = true
        do {
            try await authService.updateDisplayName(displayName.trimmingCharacters(in: .whitespacesAndNewlines))
            isSaving = false
            onComplete()
        } catch {
            isSaving = false
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    DisplayNamePromptView(authService: AuthService(managesDeviceTokens: false), onComplete: {})
}
