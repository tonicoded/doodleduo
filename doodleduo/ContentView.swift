//
//  ContentView.swift
//  doodleduo
//
//  Created by Anthony Verruijt on 16/11/2025.
//

import SwiftUI

struct ContentView: View {
    enum Stage {
        case splash
        case onboarding
        case welcome
        case interest
        case notifications
        case signIn
        case profileSetup
        case pairing
        case main
    }
    
    @StateObject private var audioManager: BackgroundAudioManager
    @StateObject private var authService: AuthService
    @StateObject private var coupleManager: CoupleSessionManager
    @State private var stage: Stage = .splash
    @State private var hasStarted = false
    @State private var hasRequestedNotifications = false
    
    private var needsProfileSetup: Bool {
        guard authService.hasLoadedProfile else { return false }
        guard let user = authService.currentUser else { return false }
        if let duoName = coupleManager.myDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines), !duoName.isEmpty {
            return false
        }
        if let cachedName = authService.cachedDisplayName(for: user.id),
           !cachedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }
        let trimmed = authService.profile?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty
    }
    
    init() {
        let authService = AuthService()
        _authService = StateObject(wrappedValue: authService)
        _coupleManager = StateObject(wrappedValue: CoupleSessionManager(authService: authService))
        _audioManager = StateObject(wrappedValue: BackgroundAudioManager())
    }
    
    var body: some View {
        ZStack {
            switch stage {
            case .splash:
                SplashView()
                    .transition(.opacity)
            case .onboarding:
                OnboardingPagerView {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        stage = .welcome
                    }
                }
                .transition(.opacity)
            case .welcome:
                WelcomeView {
                    stage = .interest
                }
                    .transition(.opacity.combined(with: .scale))
            case .interest:
                InterestSurveyView {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        stage = .notifications
                    }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            case .notifications:
                NotificationPromptView {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        stage = .signIn
                    }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            case .signIn:
                SignInPromptView(service: authService) { signedIn in
                    withAnimation(.easeInOut(duration: 0.4)) {
                        if signedIn {
                            coupleManager.markSignedIn()
                            if needsProfileSetup {
                                stage = .profileSetup
                            } else {
                                stage = coupleManager.roomID == nil ? .pairing : .main
                            }
                            requestNotificationsIfNeeded()
                        } else {
                            stage = .main
                        }
                    }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            case .profileSetup:
                DisplayNamePromptView(authService: authService) {
                    Task { await coupleManager.refreshPartnerStatus() }
                    withAnimation(.easeInOut(duration: 0.4)) {
                        stage = coupleManager.roomID == nil ? .pairing : .main
                    }
                }
                .transition(.opacity)
            case .pairing:
                CouplePairingView(sessionManager: coupleManager, profile: authService.profile) {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        stage = .main
                    }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            case .main:
                MainTabView(authService: authService, sessionManager: coupleManager, audioManager: audioManager)
                    .transition(.opacity)
            }
        }
        .task {
            guard !hasStarted else { return }
            hasStarted = true
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.6)) {
                    if authService.isSignedIn {
                        updateStageAfterSignIn(animated: false)
                    } else {
                        stage = .onboarding
                    }
                    audioManager.startIfNeeded()
                    requestNotificationsIfNeeded()
                }
            }
        }
        .onChange(of: stage) { _, newStage in
            if newStage != .splash {
                audioManager.startIfNeeded()
            }
        }
        .onChange(of: authService.isSignedIn) { _, signedIn in
            if signedIn {
                updateStageAfterSignIn(animated: true)
            } else {
                withAnimation(.easeInOut(duration: 0.4)) {
                    stage = .welcome
                }
                coupleManager.reset()
                hasRequestedNotifications = false
            }
        }
        .onChange(of: authService.hasLoadedProfile) { _, loaded in
            if loaded && authService.isSignedIn {
                updateStageAfterSignIn(animated: true)
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}

private struct AudioToggleButton: View {
    @Binding var isMuted: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Label(isMuted ? "sound off" : "sound on", systemImage: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.footnote.weight(.semibold))
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .background(.thinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 10, y: 6)
    }
}

private extension ContentView {
    func updateStageAfterSignIn(animated: Bool) {
        coupleManager.markSignedIn()
        let destination: Stage
        if needsProfileSetup {
            destination = .profileSetup
        } else if coupleManager.roomID == nil {
            destination = .pairing
        } else {
            destination = .main
        }
        if animated {
            withAnimation(.easeInOut(duration: 0.4)) {
                stage = destination
            }
        } else {
            stage = destination
        }
        requestNotificationsIfNeeded()
    }
    
    func requestNotificationsIfNeeded() {
        guard authService.isSignedIn, !hasRequestedNotifications else { return }
        hasRequestedNotifications = true
        Task {
            NotificationManager.shared.setupNotificationHandling()
            _ = await NotificationManager.shared.requestPermission()
        }
    }
}
