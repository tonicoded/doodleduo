//
//  CoupleSessionManager.swift
//  doodleduo
//
//  Created by Anthony Verruijt on 16/11/2025.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class CoupleSessionManager: ObservableObject {
    enum Status: Equatable {
        case signedOut
        case ready
        case working(message: String)
        case paired(roomID: String)
        case error(message: String)
    }
    
    @Published private(set) var status: Status
    @Published private(set) var partnerName: String?
    @Published private(set) var myDisplayName: String?
    @Published private(set) var roomName: String?
    @Published private(set) var metrics: DuoMetrics?
    @Published private(set) var farm: DuoFarm?
    @Published private(set) var partnerProfileID: UUID?

    private let environment: SupabaseEnvironment
    private unowned let authService: AuthService
    private let storageKey = "doodleduo.couple.session"
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    
    private var cachedDuoID: UUID?
    private var cachedRoomCode: String?
    
    init(environment: SupabaseEnvironment? = nil, authService: AuthService) {
        self.environment = environment ?? SupabaseEnvironment.makeCurrent()
        self.authService = authService
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let stored = try? decoder.decode(StoredState.self, from: data) {
            cachedDuoID = stored.duoID
            cachedRoomCode = stored.roomCode
            partnerName = stored.partnerName
            myDisplayName = stored.myName
            roomName = stored.roomName
            partnerProfileID = stored.partnerProfileID
            _status = Published(initialValue: .paired(roomID: stored.roomCode))
        } else {
            _status = Published(initialValue: .signedOut)
        }
    }
    
    func markSignedIn() {
        guard case .paired = status else {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                status = cachedRoomCode != nil ? .paired(roomID: cachedRoomCode!) : .ready
            }
            return
        }
    }
    
    func createRoom(preferredName: String) async {
        await perform(action: {
            let context = try requireAuthContext()
            let duoUser = try await upsertDuoUser(context: context)
            let trimmedRoomName = preferredName.trimmingCharacters(in: .whitespacesAndNewlines)
            let roomDisplayName = trimmedRoomName.isEmpty ? nil : trimmedRoomName
            var attempts = 0
            var duoID: UUID?
            var roomCode: String?
            while attempts < 3 && duoID == nil {
                let newID = UUID()
                let candidate = Self.generateRoomCode(seed: preferredName, attempt: attempts)
                do {
                    try await insertDuo(id: newID, roomCode: candidate, roomName: roomDisplayName, createdBy: context.user.id, session: context.session)
                    duoID = newID
                    roomCode = candidate
                } catch CoupleSessionError.backend(let message) where message.contains("duplicate key value violates unique constraint \"duos_room_code_key\"") {
                    attempts += 1
                } catch {
                    throw error
                }
            }
            guard let finalDuoID = duoID, let finalRoomCode = roomCode else {
                throw CoupleSessionError.backend("unable to allocate a unique room code.")
            }
            myDisplayName = duoUser.displayName
            try await ensureMembership(duoID: finalDuoID, userID: duoUser.id, session: context.session)
            let partner = try await fetchPartnerName(for: finalDuoID, excluding: context.user.id, session: context.session)
            self.partnerName = partner
            self.cachedDuoID = finalDuoID
            self.cachedRoomCode = finalRoomCode
            self.roomName = roomDisplayName
            self.persistState()
            self.status = .paired(roomID: finalRoomCode)
        }, workingMessage: "setting up your cozy farm…")
    }
    
    func joinRoom(code: String) async {
        await perform(action: {
            let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            guard normalized.count >= 4 else {
                throw CoupleSessionError.invalidRoomCode
            }
            let context = try requireAuthContext()
            let duoUser = try await upsertDuoUser(context: context)
            myDisplayName = duoUser.displayName
            let duo = try await fetchDuo(for: normalized, session: context.session)
            if !(try await hasMembership(duoID: duo.id, userID: duoUser.id, session: context.session)) {
                let count = try await memberCount(for: duo.id, session: context.session)
                guard count < 2 else {
                    throw CoupleSessionError.roomFull
                }
            }
            try await ensureMembership(duoID: duo.id, userID: duoUser.id, session: context.session)
            let partner = try await fetchPartnerName(for: duo.id, excluding: context.user.id, session: context.session)
            self.partnerName = partner
            self.cachedDuoID = duo.id
            self.cachedRoomCode = duo.roomCode
            self.roomName = duo.roomName
            self.persistState()
            self.status = .paired(roomID: duo.roomCode)
        }, workingMessage: "connecting to your duo…")
    }
    
    func refreshPartnerStatus() async {
        guard let duoID = cachedDuoID else { return }
        do {
            let context = try requireAuthContext()
            if let partner = try await fetchPartnerName(for: duoID, excluding: context.user.id, session: context.session) {
                partnerName = partner
            }
            if let selfRecord = try await fetchDuoUser(authUID: context.user.id, session: context.session) {
                myDisplayName = selfRecord.displayName
            }
            persistState()
        } catch {
            // swallow refresh errors
        }
    }
    
    func reset() {
        status = .signedOut
        partnerName = nil
        myDisplayName = nil
        roomName = nil
        partnerProfileID = nil
        cachedDuoID = nil
        cachedRoomCode = nil
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
    
    var roomID: String? {
        cachedRoomCode
    }
    
    var currentRoomID: UUID? {
        return cachedDuoID
    }

    func updateMetrics(_ newMetrics: DuoMetrics) {
        self.metrics = newMetrics
    }
    
    func updateStreakForToday() async throws {
        guard let _ = currentRoomID,
              let _ = authService.session,
              let _ = authService.currentUser?.id else { return }
        
        // TODO: In the future, call the Supabase function for streak calculation
        // For now, don't automatically increment streak - let it be managed by the database
        // Streak should only increase when actual activities happen, not just when this function is called
        print("🔥 Streak update called - should be handled by database triggers")
    }
    
    func refreshMetrics() async throws {
        print("🔍 refreshMetrics called")
        print("🔍 cachedDuoID:", cachedDuoID as Any)
        print("🔍 cachedRoomCode:", cachedRoomCode as Any)

        guard let roomID = cachedDuoID else {
            print("❌ No cachedDuoID - throwing error")
            throw CoupleSessionError.notAuthenticated
        }

        guard let session = authService.session else {
            print("❌ No session - throwing error")
            throw CoupleSessionError.notAuthenticated
        }

        print("✅ Room ID:", roomID)
        print("✅ Has session")

        // Configure JSON decoder for ISO8601 dates
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Fetch metrics
        var metricsURL = URLComponents(
            url: environment.restURL.appendingPathComponent("duo_metrics"),
            resolvingAgainstBaseURL: false
        )!
        metricsURL.queryItems = [
            URLQueryItem(name: "room_id", value: "eq.\(roomID.uuidString)")
        ]

        print("📡 Fetching metrics from:", metricsURL.url?.absoluteString ?? "nil")

        var metricsRequest = URLRequest(url: metricsURL.url!)
        metricsRequest.httpMethod = "GET"
        metricsRequest.allHTTPHeaderFields = environment.headers(accessToken: session.accessToken)

        let (metricsData, metricsResponse) = try await URLSession.shared.data(for: metricsRequest)
        print("📡 Metrics response:", (metricsResponse as? HTTPURLResponse)?.statusCode ?? 0)
        print("📡 Metrics data:", String(data: metricsData, encoding: .utf8) ?? "nil")

        var fetchedMetrics = try decoder.decode([DuoMetrics].self, from: metricsData).first
        print("✅ Decoded metrics:", fetchedMetrics as Any)

        // Fetch farm
        var farmURL = URLComponents(
            url: environment.restURL.appendingPathComponent("duo_farms"),
            resolvingAgainstBaseURL: false
        )!
        farmURL.queryItems = [
            URLQueryItem(name: "room_id", value: "eq.\(roomID.uuidString)")
        ]

        print("📡 Fetching farm from:", farmURL.url?.absoluteString ?? "nil")

        var farmRequest = URLRequest(url: farmURL.url!)
        farmRequest.httpMethod = "GET"
        farmRequest.allHTTPHeaderFields = environment.headers(accessToken: session.accessToken)

        let (farmData, farmResponse) = try await URLSession.shared.data(for: farmRequest)
        print("📡 Farm response:", (farmResponse as? HTTPURLResponse)?.statusCode ?? 0)
        print("📡 Farm data:", String(data: farmData, encoding: .utf8) ?? "nil")

        var fetchedFarm = try decoder.decode([DuoFarm].self, from: farmData).first
        print("✅ Decoded farm:", fetchedFarm as Any)

        // If data doesn't exist, create it
        if fetchedMetrics == nil {
            print("🔧 Creating missing metrics data")
            fetchedMetrics = try await createMetricsData(roomID: roomID, session: session)
        }
        
        if fetchedFarm == nil {
            print("🔧 Creating missing farm data")
            fetchedFarm = try await createFarmData(roomID: roomID, session: session)
        }

        // Update on main actor
        self.metrics = fetchedMetrics
        self.farm = fetchedFarm

        print("🎉 Metrics and farm updated successfully!")
        print("✅ Metrics loaded:", self.metrics as Any)
        print("✅ Farm loaded:", self.farm as Any)
    }

    // MARK: - Private helpers
    
    private func createMetricsData(roomID: UUID, session: AuthSession) async throws -> DuoMetrics {
        print("🔧 Creating metrics for room:", roomID)
        
        let metricsPayload = [
            "room_id": roomID.uuidString,
            "love_energy": 0,
            "total_doodles": 0,
            "total_strokes": 0,
            "current_streak": 0,
            "longest_streak": 0,
            "hardcore_mode": false
        ] as [String : Any]
        
        var request = URLRequest(url: environment.restURL.appendingPathComponent("duo_metrics"))
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = environment.headers(accessToken: session.accessToken)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        
        let jsonData = try JSONSerialization.data(withJSONObject: metricsPayload)
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CoupleSessionError.backend("Invalid response creating metrics")
        }
        
        if httpResponse.statusCode >= 400 {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Create metrics error:", httpResponse.statusCode, errorBody)
            throw CoupleSessionError.backend("Failed to create metrics: \(errorBody)")
        }
        
        print("✅ Created metrics successfully")
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let createdMetrics = try decoder.decode([DuoMetrics].self, from: data)
        
        guard let metrics = createdMetrics.first else {
            throw CoupleSessionError.backend("No metrics returned after creation")
        }
        
        return metrics
    }
    
    private func createFarmData(roomID: UUID, session: AuthSession) async throws -> DuoFarm {
        print("🔧 Creating farm for room:", roomID)
        
        let farmPayload = [
            "room_id": roomID.uuidString,
            "unlocked_animals": ["chicken"],
            "farm_level": 1,
            "theme": "default",
            "animals_sleeping": false
        ] as [String : Any]
        
        var request = URLRequest(url: environment.restURL.appendingPathComponent("duo_farms"))
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = environment.headers(accessToken: session.accessToken)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        
        let jsonData = try JSONSerialization.data(withJSONObject: farmPayload)
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CoupleSessionError.backend("Invalid response creating farm")
        }
        
        if httpResponse.statusCode >= 400 {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Create farm error:", httpResponse.statusCode, errorBody)
            throw CoupleSessionError.backend("Failed to create farm: \(errorBody)")
        }
        
        print("✅ Created farm successfully")
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let createdFarm = try decoder.decode([DuoFarm].self, from: data)
        
        guard let farm = createdFarm.first else {
            throw CoupleSessionError.backend("No farm returned after creation")
        }
        
        return farm
    }
    
    private func perform(action: () async throws -> Void, workingMessage: String) async {
        status = .working(message: workingMessage)
        do {
            try await action()
        } catch {
            status = .error(message: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }
    
    private func requireAuthContext() throws -> AuthContext {
        guard let session = authService.session,
              let user = authService.currentUser else {
            throw CoupleSessionError.notAuthenticated
        }
        let display = authService.profile?.displayName ??
            authService.cachedDisplayName(for: user.id) ??
            user.email
        return AuthContext(session: session, user: user, displayName: display)
    }
    
    private func upsertDuoUser(context: AuthContext) async throws -> DuoUserRecord {
        if let existing = try await fetchDuoUser(authUID: context.user.id, session: context.session) {
            myDisplayName = existing.displayName
            return existing
        }
        
        var request = authenticatedRequest(
            url: environment.restURL.appendingPathComponent("profiles"),
            method: "POST",
            session: context.session
        )
        request.setValue("return=representation,resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        let payload = DuoUserUpsert(authUid: context.user.id, displayName: context.displayName)
        request.httpBody = try JSONEncoder().encode(payload)
        let data = try await data(for: request)
        let rows = try JSONDecoder().decode([DuoUserRecord].self, from: data)
        guard let record = rows.first else {
            throw CoupleSessionError.backend("failed to upsert profile")
        }
        return record
    }
    
    private func fetchDuoUser(authUID: UUID, session: AuthSession) async throws -> DuoUserRecord? {
        var components = URLComponents(url: environment.restURL.appendingPathComponent("profiles"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "id", value: "eq.\(authUID.uuidString)"),
            URLQueryItem(name: "select", value: "id,display_name")
        ]
        guard let url = components?.url else {
            throw CoupleSessionError.backend("unable to build profile lookup")
        }
        let request = authenticatedRequest(url: url, method: "GET", session: session)
        let data = try await data(for: request)
        let rows = try JSONDecoder().decode([DuoUserRecord].self, from: data)
        return rows.first
    }
    
    private func insertDuo(id: UUID, roomCode: String, roomName: String?, createdBy: UUID, session: AuthSession) async throws {
        var request = authenticatedRequest(
            url: environment.restURL.appendingPathComponent("duo_rooms"),
            method: "POST",
            session: session
        )
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        let payload = CreateDuoPayload(id: id, roomCode: roomCode, roomName: roomName, createdBy: createdBy)
        request.httpBody = try JSONEncoder().encode(payload)
        _ = try await data(for: request)
    }
    
    private func ensureMembership(duoID: UUID, userID: UUID, session: AuthSession) async throws {
        if try await hasMembership(duoID: duoID, userID: userID, session: session) {
            return
        }
        var request = authenticatedRequest(
            url: environment.restURL.appendingPathComponent("duo_memberships"),
            method: "POST",
            session: session
        )
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        let payload = CreateMembershipPayload(profileId: userID, roomId: duoID)
        request.httpBody = try JSONEncoder().encode(payload)
        _ = try await data(for: request)
    }
    
    private func hasMembership(duoID: UUID, userID: UUID, session: AuthSession) async throws -> Bool {
        var components = URLComponents(url: environment.restURL.appendingPathComponent("duo_memberships"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "room_id", value: "eq.\(duoID.uuidString)"),
            URLQueryItem(name: "profile_id", value: "eq.\(userID.uuidString)"),
            URLQueryItem(name: "select", value: "profile_id"),
            URLQueryItem(name: "limit", value: "1")
        ]
        guard let url = components?.url else {
            throw CoupleSessionError.backend("unable to check duo membership")
        }
        let request = authenticatedRequest(url: url, method: "GET", session: session)
        let data = try await data(for: request)
        struct MembershipRow: Decodable { let profile_id: UUID }
        let rows = try JSONDecoder().decode([MembershipRow].self, from: data)
        return !rows.isEmpty
    }
    
    private func memberCount(for duoID: UUID, session: AuthSession) async throws -> Int {
        var components = URLComponents(url: environment.restURL.appendingPathComponent("duo_memberships"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "room_id", value: "eq.\(duoID.uuidString)"),
            URLQueryItem(name: "select", value: "profile_id")
        ]
        guard let url = components?.url else {
            throw CoupleSessionError.backend("unable to count members")
        }
        let request = authenticatedRequest(url: url, method: "GET", session: session)
        let data = try await data(for: request)
        struct Row: Decodable { let profile_id: UUID }
        let rows = try JSONDecoder().decode([Row].self, from: data)
        return rows.count
    }
    
    private func fetchDuo(for code: String, session: AuthSession) async throws -> DuoRecord {
        var components = URLComponents(url: environment.restURL.appendingPathComponent("duo_rooms"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "room_code", value: "eq.\(code)"),
            URLQueryItem(name: "select", value: "id,room_code,room_name"),
            URLQueryItem(name: "limit", value: "1")
        ]
        guard let url = components?.url else {
            throw CoupleSessionError.backend("unable to build room lookup")
        }
        let request = authenticatedRequest(url: url, method: "GET", session: session)
        let data = try await data(for: request)
        let results = try JSONDecoder().decode([DuoRecord].self, from: data)
        guard let duo = results.first else {
            throw CoupleSessionError.roomNotFound
        }
        return duo
    }
    
    private func fetchPartnerName(for duoID: UUID, excluding authUID: UUID, session: AuthSession) async throws -> String? {
        var components = URLComponents(url: environment.restURL.appendingPathComponent("duo_memberships"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "room_id", value: "eq.\(duoID.uuidString)"),
            URLQueryItem(name: "select", value: "profile:profiles!inner(display_name,id)")
        ]
        guard let url = components?.url else {
            throw CoupleSessionError.backend("unable to build partner lookup")
        }
        let request = authenticatedRequest(url: url, method: "GET", session: session)
        let data = try await data(for: request)
        let members = try JSONDecoder().decode([MemberProfileRow].self, from: data)
        if let partner = members.first(where: { $0.profile.authUid != authUID })?.profile {
            partnerProfileID = partner.authUid
            return partner.displayName
        }
        partnerProfileID = nil
        return nil
    }
    
    private func authenticatedRequest(url: URL, method: String, session: AuthSession) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.allHTTPHeaderFields = environment.headers(accessToken: session.accessToken)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }
    
    private func data(for request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CoupleSessionError.backend("supabase responded without http metadata.")
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "no body returned"
            throw CoupleSessionError.backend("supabase error \(http.statusCode): \(body)")
        }
        return data
    }
    
    private func persistState() {
        guard let duoID = cachedDuoID, let roomCode = cachedRoomCode else {
            UserDefaults.standard.removeObject(forKey: storageKey)
            return
        }
        let state = StoredState(
            duoID: duoID,
            roomCode: roomCode,
            partnerName: partnerName,
            myName: myDisplayName,
            roomName: roomName,
            partnerProfileID: partnerProfileID
        )
        if let data = try? encoder.encode(state) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    private static let codeCharacters = Array("23456789ABCDEFGHJKLMNPQRSTUVWXYZ")
    
    private static func generateRoomCode(seed: String, attempt: Int = 0) -> String {
        var rng = SystemRandomNumberGenerator()
        return String((0..<6).map { _ in codeCharacters.randomElement(using: &rng)! })
    }
    
    private struct AuthContext {
        let session: AuthSession
        let user: SupabaseAuthUser
        let displayName: String?
    }
    
    private struct DuoUserRecord: Codable {
        let id: UUID
        let displayName: String?
        
        enum CodingKeys: String, CodingKey {
            case id
            case displayName = "display_name"
        }
    }
    
    private struct DuoUserUpsert: Encodable {
        let authUid: UUID
        let displayName: String?
        
        enum CodingKeys: String, CodingKey {
            case authUid = "id"
            case displayName = "display_name"
        }
    }
    
    private struct CreateDuoPayload: Encodable {
        let id: UUID
        let roomCode: String
        let roomName: String?
        let createdBy: UUID
        
        enum CodingKeys: String, CodingKey {
            case id
            case roomCode = "room_code"
            case roomName = "room_name"
            case createdBy = "created_by"
        }
    }
    
    private struct CreateMembershipPayload: Encodable {
        let profileId: UUID
        let roomId: UUID
        
        enum CodingKeys: String, CodingKey {
            case profileId = "profile_id"
            case roomId = "room_id"
        }
    }
    
    private struct DuoRecord: Decodable {
        let id: UUID
        let roomCode: String
        let roomName: String?
        
        enum CodingKeys: String, CodingKey {
            case id
            case roomCode = "room_code"
            case roomName = "room_name"
        }
    }
    
    private struct MemberProfileRow: Decodable {
        let profile: DuoProfile
        
        struct DuoProfile: Decodable {
            let displayName: String?
            let authUid: UUID
            
            enum CodingKeys: String, CodingKey {
                case displayName = "display_name"
                case authUid = "id"
            }
        }
    }
    
    private struct StoredState: Codable {
        let duoID: UUID
        let roomCode: String
        let partnerName: String?
        let myName: String?
        let roomName: String?
        let partnerProfileID: UUID?
    }
}

#if DEBUG
extension CoupleSessionManager {
    static var preview: CoupleSessionManager {
        let auth = AuthService()
        let manager = CoupleSessionManager(authService: auth)
        manager.applyPreviewState(
            roomCode: "DUSHI",
            myName: "dushi",
            partnerName: "milo",
            roomName: "cozy farm"
        )
        return manager
    }
    
    private func applyPreviewState(roomCode: String, myName: String?, partnerName: String?, roomName: String? = nil) {
        cachedDuoID = UUID()
        cachedRoomCode = roomCode
        self.myDisplayName = myName
        self.partnerName = partnerName
        self.roomName = roomName
        status = .paired(roomID: roomCode)
    }
}
#endif

enum CoupleSessionError: LocalizedError {
    case invalidRoomCode
    case notAuthenticated
    case roomNotFound
    case roomFull
    case backend(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidRoomCode:
            return "the duo code should be at least four characters."
        case .notAuthenticated:
            return "sign in again to manage your duo room."
        case .roomNotFound:
            return "we couldn't find that invite code."
        case .roomFull:
            return "that duo already has two members."
        case .backend(let detail):
            return detail
        }
    }
}
