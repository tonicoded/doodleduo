//
//  AuthService.swift
//  doodleduo
//
//  Created by Codex on 19/01/2025.
//

import Foundation
import Combine

@MainActor
final class AuthService: ObservableObject {
    @Published private(set) var session: AuthSession? {
        didSet {
            guard managesDeviceTokens else { return }
            NotificationManager.shared.updateAuthSession(session)
        }
    }
    @Published private(set) var isSignedIn: Bool = false
    @Published private(set) var currentUser: SupabaseAuthUser?
    @Published private(set) var profile: SupabaseProfile?
    @Published private(set) var hasLoadedProfile: Bool = false
    
    private var cachedDisplayNameValue: String?
    private var cachedDisplayNameUserID: UUID?
    
    private struct NameCacheKeys {
        static let value = "doodleduo.cachedDisplayName"
        static let user = "doodleduo.cachedDisplayNameUser"
    }
    
    private let environment: SupabaseEnvironment
    private let appleClientID: String
    private let storageKey = "doodleduo.supabase.session"
    private let decoder: JSONDecoder = AuthService.makeDecoder()
    private let encoder: JSONEncoder = AuthService.makeEncoder()
    
    private let managesDeviceTokens: Bool
    
    init(environment: SupabaseEnvironment? = nil, managesDeviceTokens: Bool = false) {
        self.environment = environment ?? SupabaseEnvironment.makeCurrent()
        self.appleClientID = AuthService.resolveAppleClientID()
        self.managesDeviceTokens = managesDeviceTokens
        loadCachedDisplayName()
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? decoder.decode(AuthSession.self, from: data) {
            session = saved
            isSignedIn = true
            if managesDeviceTokens {
                NotificationManager.shared.updateAuthSession(saved)
            }
            Task {
                await restoreSession(using: saved)
            }
        }
    }
    
    func signInWithApple(idToken: String, nonce: String) async throws {
        let response = try await exchangeAppleToken(idToken: idToken, nonce: nonce)
        let newSession = AuthSession(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            tokenType: response.tokenType,
            expiresAt: response.expiresIn.flatMap { Date().addingTimeInterval($0) }
        )
        let profile = try await upsertProfile(for: response.user, session: newSession)
        session = newSession
        currentUser = response.user
        self.profile = profile
        isSignedIn = true
        hasLoadedProfile = true
        cacheDisplayName(profile.displayName, userID: response.user.id)
        persistSession(newSession)
        
        if managesDeviceTokens {
            await NotificationManager.shared.registerPendingDeviceToken(for: response.user.id)
        }
    }
    
    func refreshProfile() async throws {
        guard let session else {
            throw AuthServiceError.missingSession
        }
        do {
            let user = try await fetchCurrentUser(using: session)
            let profile = try await fetchProfile(for: user.id, session: session)
            currentUser = user
            self.profile = profile
            hasLoadedProfile = true
            cacheDisplayName(profile.displayName, userID: user.id)
        } catch {
            await handleAuthSyncError(error)
            throw error
        }
    }

    func updateDisplayName(_ name: String) async throws {
        guard let session, let user = currentUser else {
            throw AuthServiceError.missingSession
        }
        var components = URLComponents(
            url: environment.restURL.appendingPathComponent("profiles"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "id", value: "eq.\(user.id.uuidString)")
        ]
        guard let url = components?.url else {
            throw AuthServiceError.invalidRequest
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.allHTTPHeaderFields = environment.headers(accessToken: session.accessToken)
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        let payload = DisplayNameUpdate(displayName: name, lastSeenAt: Date())
        request.httpBody = try encoder.encode(payload)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        let updated = try decoder.decode([SupabaseProfile].self, from: data)
        guard let profile = updated.first else {
            throw AuthServiceError.profileMissing
        }
        try await updateDuoUserDisplayName(name, session: session, authUID: user.id)
        await MainActor.run {
            self.profile = profile
            cacheDisplayName(name, userID: user.id)
        }
    }
    
    func signOut() {
        session = nil
        currentUser = nil
        profile = nil
        isSignedIn = false
        hasLoadedProfile = false
        cachedDisplayNameValue = nil
        cachedDisplayNameUserID = nil
        UserDefaults.standard.removeObject(forKey: NameCacheKeys.value)
        UserDefaults.standard.removeObject(forKey: NameCacheKeys.user)
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
    
    private func persistSession(_ session: AuthSession) {
        guard let data = try? encoder.encode(session) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
    
    private func restoreSession(using session: AuthSession) async {
        do {
            let user = try await fetchCurrentUser(using: session)
            let profile = try await fetchProfile(for: user.id, session: session)
            await MainActor.run {
                self.currentUser = user
                self.profile = profile
                self.hasLoadedProfile = true
                cacheDisplayName(profile.displayName, userID: user.id)
            }
            if managesDeviceTokens {
                await NotificationManager.shared.registerPendingDeviceToken(for: user.id)
            }
        } catch AuthServiceError.sessionExpired {
            do {
                let refreshed = try await refreshSession(using: session)
                await restoreSession(using: refreshed)
            } catch {
                await handleAuthSyncError(error)
                #if DEBUG
                print("Failed to restore session: \(error.localizedDescription)")
                #endif
                await MainActor.run {
                    self.hasLoadedProfile = true
                }
            }
        } catch {
            await handleAuthSyncError(error)
            #if DEBUG
            print("Failed to restore session: \(error.localizedDescription)")
            #endif
            await MainActor.run {
                self.hasLoadedProfile = true
            }
        }
    }
    
    private func exchangeAppleToken(idToken: String, nonce: String) async throws -> SupabaseSignInResponse {
        var components = URLComponents(
            url: environment.authURL.appendingPathComponent("token"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "grant_type", value: "id_token"),
            URLQueryItem(name: "provider", value: "apple")
        ]
        guard let url = components?.url else {
            throw AuthServiceError.invalidRequest
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = environment.headers()
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let payload = AppleSignInRequest(idToken: idToken, nonce: nonce, clientID: appleClientID)
        request.httpBody = try JSONEncoder().encode(payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try decoder.decode(SupabaseSignInResponse.self, from: data)
    }
    
    private func fetchCurrentUser(using session: AuthSession) async throws -> SupabaseAuthUser {
        var request = URLRequest(url: environment.authURL.appendingPathComponent("user"))
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = environment.headers(accessToken: session.accessToken)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try decoder.decode(SupabaseAuthUser.self, from: data)
    }
    
    private func upsertProfile(for user: SupabaseAuthUser, session: AuthSession) async throws -> SupabaseProfile {
        do {
            return try await fetchProfile(for: user.id, session: session)
        } catch AuthServiceError.profileMissing {
            var request = URLRequest(url: environment.restURL.appendingPathComponent("profiles"))
            request.httpMethod = "POST"
            request.allHTTPHeaderFields = environment.headers(accessToken: session.accessToken)
            request.setValue("return=representation", forHTTPHeaderField: "Prefer")
            request.httpBody = try encoder.encode(
                SupabaseProfileUpsert(
                    id: user.id,
                    displayName: AuthService.defaultDisplayName(for: user),
                    appleEmail: user.email,
                    lastSeenAt: Date()
                )
            )
            let (data, response) = try await URLSession.shared.data(for: request)
            try validate(response: response, data: data)
            let profiles = try decoder.decode([SupabaseProfile].self, from: data)
            guard let profile = profiles.first else {
                throw AuthServiceError.profileMissing
            }
            return profile
        }
    }
    
    private func fetchProfile(for userID: UUID, session: AuthSession) async throws -> SupabaseProfile {
        var components = URLComponents(
            url: environment.restURL.appendingPathComponent("profiles"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "id", value: "eq.\(userID.uuidString)"),
            URLQueryItem(
                name: "select",
                value: "id,display_name,apple_email,created_at,updated_at,last_seen_at,profile_photo_url"
            )
        ]
        guard let url = components?.url else {
            throw AuthServiceError.invalidRequest
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = environment.headers(accessToken: session.accessToken)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        let result = try decoder.decode([SupabaseProfile].self, from: data)
        guard let profile = result.first else {
            throw AuthServiceError.profileMissing
        }
        return profile
    }
    
    nonisolated static func defaultDisplayName(for user: SupabaseAuthUser) -> String? {
        guard let email = user.email else { return nil }
        let prefix = email.split(separator: "@").first?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = prefix, !first.isEmpty else { return nil }
        return String(first.prefix(24))
    }
    
    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw AuthServiceError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = SupabaseErrorResponse.message(from: data, decoder: decoder) ??
            "HTTP \(http.statusCode): \(String(data: data, encoding: .utf8) ?? "no body")"
            if (401...404).contains(http.statusCode) {
                throw AuthServiceError.sessionExpired(message)
            }
            throw AuthServiceError.api(message)
        }
    }
    
    private func handleAuthSyncError(_ error: Error) async {
        guard let authError = error as? AuthServiceError else { return }
        switch authError {
        case .profileMissing:
            signOut()
        case .sessionExpired:
            await refreshOrSignOut()
        default:
            break
        }
    }

    func cachedDisplayName(for userID: UUID) -> String? {
        guard cachedDisplayNameUserID == userID else { return nil }
        let trimmed = cachedDisplayNameValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
    
    private func loadCachedDisplayName() {
        let trimmed = UserDefaults.standard.string(forKey: NameCacheKeys.value)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty,
              let userString = UserDefaults.standard.string(forKey: NameCacheKeys.user),
              let userID = UUID(uuidString: userString) else {
            cachedDisplayNameValue = nil
            cachedDisplayNameUserID = nil
            return
        }
        cachedDisplayNameValue = trimmed
        cachedDisplayNameUserID = userID
    }
    
    private func cacheDisplayName(_ name: String?, userID: UUID) {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            cachedDisplayNameValue = nil
            cachedDisplayNameUserID = nil
            UserDefaults.standard.removeObject(forKey: NameCacheKeys.value)
            UserDefaults.standard.removeObject(forKey: NameCacheKeys.user)
            return
        }
        cachedDisplayNameValue = trimmed
        cachedDisplayNameUserID = userID
        UserDefaults.standard.set(trimmed, forKey: NameCacheKeys.value)
        UserDefaults.standard.set(userID.uuidString, forKey: NameCacheKeys.user)
    }
    
    private func updateDuoUserDisplayName(_ name: String, session: AuthSession, authUID: UUID) async throws {
        var components = URLComponents(
            url: environment.restURL.appendingPathComponent("duo_users"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "auth_uid", value: "eq.\(authUID.uuidString)")
        ]
        guard let url = components?.url else {
            throw AuthServiceError.invalidRequest
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.allHTTPHeaderFields = environment.headers(accessToken: session.accessToken)
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        let payload = DuoUserNameUpdate(displayName: name)
        request.httpBody = try encoder.encode(payload)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
    }
    
    private func refreshSession(using session: AuthSession) async throws -> AuthSession {
        var components = URLComponents(
            url: environment.authURL.appendingPathComponent("token"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "grant_type", value: "refresh_token")
        ]
        guard let url = components?.url else {
            throw AuthServiceError.invalidRequest
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = environment.headers()
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let payload = RefreshTokenRequest(refreshToken: session.refreshToken)
        request.httpBody = try encoder.encode(payload)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        let refreshed = try decoder.decode(SupabaseRefreshResponse.self, from: data)
        let nextSession = AuthSession(
            accessToken: refreshed.accessToken,
            refreshToken: refreshed.refreshToken,
            tokenType: refreshed.tokenType,
            expiresAt: refreshed.expiresIn.flatMap { Date().addingTimeInterval($0) }
        )
        await MainActor.run {
            self.session = nextSession
            self.isSignedIn = true
            if let updatedUser = refreshed.user {
                self.currentUser = updatedUser
            }
        }
        persistSession(nextSession)
        return nextSession
    }
    
    private func refreshOrSignOut() async {
        guard let session else {
            signOut()
            return
        }
        do {
            _ = try await refreshSession(using: session)
        } catch {
            signOut()
        }
    }
    
    private static func resolveAppleClientID() -> String {
        if let override = Bundle.main.object(forInfoDictionaryKey: "SIGN_IN_WITH_APPLE_CLIENT_ID") as? String,
           !override.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return override
        }
        if let bundleID = Bundle.main.bundleIdentifier, !bundleID.isEmpty {
            return bundleID
        }
        fatalError("Set SIGN_IN_WITH_APPLE_CLIENT_ID or define PRODUCT_BUNDLE_IDENTIFIER before running.")
    }
    
    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = Self.dateFromISO8601(value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO-8601 date: \(value)")
        }
        return decoder
    }
    
    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            let value = Self.iso8601String(from: date)
            try container.encode(value)
        }
        return encoder
    }
    
    nonisolated private static func dateFromISO8601(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date
        }
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        return fallback.date(from: value)
    }
    
    nonisolated private static func iso8601String(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}

struct AuthSession: Codable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String?
    let expiresAt: Date?
}

struct SupabaseSignInResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String?
    let expiresIn: Double?
    let user: SupabaseAuthUser
}

struct SupabaseRefreshResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String?
    let expiresIn: Double?
    let user: SupabaseAuthUser?
}

struct AppleSignInRequest: Encodable {
    let provider = "apple"
    let grantType = "id_token"
    let idToken: String
    let nonce: String
    let clientID: String
    
    enum CodingKeys: String, CodingKey {
        case provider
        case grantType = "grant_type"
        case idToken = "id_token"
        case nonce
        case clientID = "client_id"
    }
}

struct RefreshTokenRequest: Encodable {
    let refreshToken: String
    
    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

struct SupabaseAuthUser: Decodable, Identifiable {
    let id: UUID
    let email: String?
    let phone: String?
    let aud: String?
    let createdAt: Date?
    let lastSignInAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case phone
        case aud
        case createdAt = "created_at"
        case lastSignInAt = "last_sign_in_at"
    }
}

struct SupabaseProfile: Codable, Identifiable {
    let id: UUID
    let displayName: String?
    let appleEmail: String?
    let createdAt: Date?
    let updatedAt: Date?
    let lastSeenAt: Date?
    let profilePhotoURL: String?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case appleEmail = "apple_email"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case lastSeenAt = "last_seen_at"
        case profilePhotoURL = "profile_photo_url"
    }
}

struct SupabaseProfileUpsert: Encodable {
    let id: UUID
    let displayName: String?
    let appleEmail: String?
    let lastSeenAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case appleEmail = "apple_email"
        case lastSeenAt = "last_seen_at"
    }
}

struct DisplayNameUpdate: Encodable {
    let displayName: String
    let lastSeenAt: Date
    
    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case lastSeenAt = "last_seen_at"
    }
}

struct DuoUserNameUpdate: Encodable {
    let displayName: String
    
    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
    }
}

enum AuthServiceError: LocalizedError {
    case invalidRequest
    case invalidResponse
    case missingSession
    case profileMissing
    case sessionExpired(String)
    case api(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "we couldn't build a supabase request. double-check your config."
        case .invalidResponse:
            return "supabase responded without proper http metadata."
        case .missingSession:
            return "sign in again to create a supabase session."
        case .profileMissing:
            return "your account exists in auth but no profile row was returned."
        case .sessionExpired(let message):
            return "your session is no longer valid: \(message)"
        case .api(let message):
            return "supabase rejected the request: \(message)"
        }
    }
}

struct SupabaseErrorResponse: Decodable {
    let error: String?
    let errorDescription: String?
    let message: String?
    let description: String?
    let code: String?
    let hint: String?
    
    static func message(from data: Data, decoder: JSONDecoder) -> String? {
        guard let response = try? decoder.decode(SupabaseErrorResponse.self, from: data) else {
            return nil
        }
        return response.readableMessage
    }
    
    private var readableMessage: String? {
        return [message, errorDescription, description, error, code, hint]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }
}
