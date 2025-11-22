//
//  SignInPromptView.swift
//  doodleduo
//
//  Created by Anthony Verruijt on 16/11/2025.
//

import SwiftUI
import AuthenticationServices
import CryptoKit

struct SignInPromptView: View {
    @ObservedObject var service: AuthService
    let onFinish: (_ signedIn: Bool) -> Void
    @State private var isProcessing = false
    @State private var currentNonce: String?
    @State private var errorMessage: String?
    @Environment(\.colorScheme) private var colorScheme
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color(red: 0.05, green: 0.04, blue: 0.05) : Color(red: 0.99, green: 0.97, blue: 0.95)
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 40)
            Image("logo")
                .resizable()
                .scaledToFit()
                .frame(width: 160, height: 160)
                .shadow(color: Color.black.opacity(0.15), radius: 25, y: 12)
            Text("sign in to keep your doodles safe")
                .font(.title3.bold())
                .textCase(.lowercase)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Text("we only use your apple id to create a private duo space. no spam, no trackers—just cozy art.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .textCase(.lowercase)
                .padding(.horizontal, 40)
            
            SignInWithAppleButton(.signIn, onRequest: { request in
                request.requestedScopes = [.fullName, .email]
                let nonce = AppleSignInHelper.randomNonce()
                currentNonce = nonce
                request.nonce = AppleSignInHelper.sha256(nonce)
            }, onCompletion: { result in
                handleAppleResult(result)
            })
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 40)
            
            Button {
                onFinish(false)
            } label: {
                Text("skip for now")
                    .font(.footnote.weight(.semibold))
                    .textCase(.lowercase)
                    .padding(.top, 8)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            Spacer()
        }
        .overlay(alignment: .top) {
            HStack(spacing: 6) {
                Circle().fill(Color.secondary.opacity(0.3)).frame(width: 6, height: 6)
                Circle().fill(Color.secondary.opacity(0.3)).frame(width: 6, height: 6)
                Circle().fill(Color.secondary.opacity(0.3)).frame(width: 6, height: 6)
                Circle().fill(Color.secondary.opacity(0.9)).frame(width: 8, height: 8)
            }
            .padding(.top, 16)
        }
        .overlay {
            if isProcessing {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                ProgressView()
                    .progressViewStyle(.circular)
            }
        }
        .alert("sign in failed", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("ok", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "try again in a moment.")
                .textCase(.lowercase)
        }
        .background(backgroundColor.ignoresSafeArea())
    }
    
    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let token = String(data: tokenData, encoding: .utf8),
                  let nonce = currentNonce else {
                errorMessage = "unable to read identity token."
                return
            }
            Task {
                await signInWithSupabase(idToken: token, nonce: nonce)
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
    
    @MainActor
    private func signInWithSupabase(idToken: String, nonce: String) async {
        isProcessing = true
        do {
            try await service.signInWithApple(idToken: idToken, nonce: nonce)
            isProcessing = false
            onFinish(true)
        } catch {
            isProcessing = false
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    SignInPromptView(service: AuthService(managesDeviceTokens: false), onFinish: { _ in })
        .environment(\.colorScheme, .light)
}

enum AppleSignInHelper {
    static func randomNonce(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed.")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}
