//
//  CouplePairingView.swift
//  doodleduo
//
//  Created by Codex on 22/11/2025.
//

import SwiftUI

struct CouplePairingView: View {
    @ObservedObject var sessionManager: CoupleSessionManager
    let profile: SupabaseProfile?
    let onPaired: () -> Void
    
    @State private var duoSeed = ""
    @State private var joinCode = ""
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var focusedField: Field?
    
    private var isBusy: Bool {
        if case .working = sessionManager.status {
            return true
        }
        return false
    }
    
    private var statusLine: (text: String, color: Color)? {
        switch sessionManager.status {
        case .working(let message):
            return (message, .secondary)
        case .error(let message):
            return (message, .red)
        default:
            return nil
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                header
                if let (text, color) = statusLine {
                    Text(text)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(color)
                        .textCase(.lowercase)
                }
                pairingCards
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 32)
        }
        .background(CozyPalette.background(for: colorScheme).ignoresSafeArea())
        .overlay {
            if isBusy {
                Color.black.opacity(0.15).ignoresSafeArea()
                ProgressView()
                    .tint(.brown)
            }
        }
        .onAppear {
            if case .paired = sessionManager.status {
                onPaired()
            }
        }
        .onChange(of: sessionManager.status) { _, newStatus in
            if case .paired = newStatus {
                onPaired()
            }
        }
    }
    
    private var header: some View {
        VStack(spacing: 8) {
            Text("welcome\(profile?.displayName.flatMap { " \( $0.lowercased())" } ?? "")")
                .font(.title2.bold())
                .textCase(.lowercase)
            Text("create a new duo room or join your partner's invite to unlock your cozy shared space.")
                .font(.subheadline)
                .textCase(.lowercase)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
    }
    
    private var pairingCards: some View {
        VStack(spacing: 20) {
            card {
                VStack(alignment: .leading, spacing: 16) {
                    Label("create a room", systemImage: "sparkles")
                        .font(.headline)
                        .textCase(.lowercase)
                    TextField("duo nickname (ex. lil farm)", text: $duoSeed)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(CozyPalette.cardBackground(for: colorScheme))
                        )
                        .focused($focusedField, equals: .createName)
                    
                        Button {
                            focusedField = nil
                            Task {
                                await sessionManager.createRoom(preferredName: duoSeed)
                            }
                        } label: {
                            Label("create room", systemImage: "heart.circle.fill")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.42, green: 0.27, blue: 0.23))
                    .disabled(duoSeed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isBusy)
                }
            }
            
            card {
                VStack(alignment: .leading, spacing: 16) {
                    Label("join an invite", systemImage: "link")
                        .font(.headline)
                        .textCase(.lowercase)
                    TextField("invite code (ex. 6G5KQ2)", text: $joinCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(CozyPalette.cardBackground(for: colorScheme))
                        )
                        .focused($focusedField, equals: .joinCode)
                    
                        Button {
                            focusedField = nil
                            Task {
                                await sessionManager.joinRoom(code: joinCode)
                            }
                        } label: {
                            Label("join room", systemImage: "person.2.circle.fill")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(CozyPalette.accent)
                    .disabled(joinCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isBusy)
                }
            }
        }
    }
    
    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.05), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 14, y: 8)
    }
    
    private enum Field {
        case createName
        case joinCode
    }
    
    private var cardBackground: Color {
        CozyPalette.cardBackground(for: colorScheme)
    }
}

#Preview {
    let authService = AuthService(managesDeviceTokens: false)
    CouplePairingView(sessionManager: CoupleSessionManager(authService: authService), profile: nil, onPaired: {})
}
