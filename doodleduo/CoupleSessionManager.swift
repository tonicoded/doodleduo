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
    @Published private(set) var isGameOver = false
    @Published private(set) var partnerProfileID: UUID?
    @Published private(set) var survivalStartDate: Date?
    @Published private(set) var shouldShowTutorial = false

    private let environment: SupabaseEnvironment
    private unowned let authService: AuthService
    private let storageKey = "doodleduo.couple.session"
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private var deathSpeedMultiplier: Double = 1.0
    private static let fastDeathArgument = "--fast-death-mode"
    private static let fastDeathMultiplierValue: Double = 720.0 // 24h drains in ~2 minutes
    private let tutorialCompletionKey = "doodleduo.tutorial.completed"
    
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

        configureDeathSpeedMultiplier()
        updateTutorialPresentationState()
    }

    private func configureDeathSpeedMultiplier() {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains(Self.fastDeathArgument) {
            deathSpeedMultiplier = Self.fastDeathMultiplierValue
            print("⚡️ Fast death mode enabled for testing (animals die in ≈2 minutes)")
        }
#endif
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
            scheduleTutorialPresentation()
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
            scheduleTutorialPresentation()
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
        shouldShowTutorial = false
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
        if let fetchedFarm {
            isGameOver = fetchedFarm.unlockedAnimals.isEmpty
            survivalStartDate = fetchedFarm.createdAt
        }

        print("🎉 Metrics and farm updated successfully!")
        print("✅ Metrics loaded:", self.metrics as Any)
        print("✅ Farm loaded:", self.farm as Any)
    }

    func purchaseAnimal(animalID: String, cost: Int) async {
        guard let roomID = cachedDuoID,
              let session = authService.session,
              let currentMetrics = metrics,
              let currentFarm = farm else {
            print("❌ Cannot purchase animal - missing data")
            return
        }

        print("🛒 Purchasing \(animalID) for \(cost) love points")

        do {
            // 1. Update love energy (deduct cost)
            let newLoveEnergy = currentMetrics.loveEnergy - cost
            var metricsUpdateURL = URLComponents(
                url: environment.restURL.appendingPathComponent("duo_metrics"),
                resolvingAgainstBaseURL: false
            )!
            metricsUpdateURL.queryItems = [
                URLQueryItem(name: "room_id", value: "eq.\(roomID.uuidString)")
            ]

            var metricsUpdateRequest = URLRequest(url: metricsUpdateURL.url!)
            metricsUpdateRequest.httpMethod = "PATCH"
            metricsUpdateRequest.allHTTPHeaderFields = environment.headers(accessToken: session.accessToken)
            metricsUpdateRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            metricsUpdateRequest.setValue("return=representation", forHTTPHeaderField: "Prefer")

            let metricsPayload = ["love_energy": newLoveEnergy]
            metricsUpdateRequest.httpBody = try JSONSerialization.data(withJSONObject: metricsPayload)

            let (metricsData, _) = try await URLSession.shared.data(for: metricsUpdateRequest)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let updatedMetrics = try decoder.decode([DuoMetrics].self, from: metricsData).first
            print("✅ Updated metrics, new love energy:", updatedMetrics?.loveEnergy ?? 0)

            // 2. Update farm (add animal)
            var newAnimals = currentFarm.unlockedAnimals
            if !newAnimals.contains(animalID) {
                newAnimals.append(animalID)
            }

            var farmUpdateURL = URLComponents(
                url: environment.restURL.appendingPathComponent("duo_farms"),
                resolvingAgainstBaseURL: false
            )!
            farmUpdateURL.queryItems = [
                URLQueryItem(name: "room_id", value: "eq.\(roomID.uuidString)")
            ]

            var farmUpdateRequest = URLRequest(url: farmUpdateURL.url!)
            farmUpdateRequest.httpMethod = "PATCH"
            farmUpdateRequest.allHTTPHeaderFields = environment.headers(accessToken: session.accessToken)
            farmUpdateRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            farmUpdateRequest.setValue("return=representation", forHTTPHeaderField: "Prefer")

            let farmPayload = ["unlocked_animals": newAnimals]
            farmUpdateRequest.httpBody = try JSONSerialization.data(withJSONObject: farmPayload)

            let (farmData, _) = try await URLSession.shared.data(for: farmUpdateRequest)
            let updatedFarm = try decoder.decode([DuoFarm].self, from: farmData).first
            print("✅ Updated farm, animals:", updatedFarm?.unlockedAnimals ?? [])

            // 3. Update local state
            self.metrics = updatedMetrics
            self.farm = updatedFarm

            // 4. Initialize ecosystem if needed
            if ecosystem == nil {
                await initializeEcosystem()
            }

            // 5. Create health record in database for the new animal
            await createAnimalHealthRecord(animalID: animalID, roomID: roomID, session: session)

            // 6. Reload animal health from database (this will load with correct health, no flicker)
            await refreshAnimalHealthFromDatabase()

            print("🎉 Purchase complete! Added \(animalID) to farm")

        } catch {
            print("❌ Purchase failed:", error)
        }
    }

    func restartFarm() async {
        guard let roomID = cachedDuoID,
              let session = authService.session,
              let currentMetrics = metrics else {
            print("❌ Cannot restart farm - missing data")
            return
        }

        print("🔄 Restarting farm...")

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let resetDate = Date()
            let isoResetDate = ISO8601DateFormatter().string(from: resetDate)

            // 1. Update metrics (reset streak to 1, update longest if needed)
            let newLongestStreak = max(currentMetrics.longestStreak, currentMetrics.currentStreak)
            var metricsUpdateURL = URLComponents(
                url: environment.restURL.appendingPathComponent("duo_metrics"),
                resolvingAgainstBaseURL: false
            )!
            metricsUpdateURL.queryItems = [
                URLQueryItem(name: "room_id", value: "eq.\(roomID.uuidString)")
            ]

            var metricsUpdateRequest = URLRequest(url: metricsUpdateURL.url!)
            metricsUpdateRequest.httpMethod = "PATCH"
            metricsUpdateRequest.allHTTPHeaderFields = environment.headers(accessToken: session.accessToken)
            metricsUpdateRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            metricsUpdateRequest.setValue("return=representation", forHTTPHeaderField: "Prefer")

            let metricsPayload = [
                "love_energy": 0,
                "current_streak": 0,
                "longest_streak": newLongestStreak
            ] as [String: Any]
            metricsUpdateRequest.httpBody = try JSONSerialization.data(withJSONObject: metricsPayload)

            let (metricsData, _) = try await URLSession.shared.data(for: metricsUpdateRequest)
            let updatedMetrics = try decoder.decode([DuoMetrics].self, from: metricsData).first
            print("✅ Reset streak to 1, longest: \(newLongestStreak)")

            // 2. Reset farm (back to just chicken)
            var farmUpdateURL = URLComponents(
                url: environment.restURL.appendingPathComponent("duo_farms"),
                resolvingAgainstBaseURL: false
            )!
            farmUpdateURL.queryItems = [
                URLQueryItem(name: "room_id", value: "eq.\(roomID.uuidString)")
            ]

            var farmUpdateRequest = URLRequest(url: farmUpdateURL.url!)
            farmUpdateRequest.httpMethod = "PATCH"
            farmUpdateRequest.allHTTPHeaderFields = environment.headers(accessToken: session.accessToken)
            farmUpdateRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            farmUpdateRequest.setValue("return=representation", forHTTPHeaderField: "Prefer")

            let farmPayload = [
                "unlocked_animals": ["chicken"],
                "last_activity_at": isoResetDate,
                "created_at": isoResetDate
            ] as [String: Any]
            farmUpdateRequest.httpBody = try JSONSerialization.data(withJSONObject: farmPayload)

            let (farmData, _) = try await URLSession.shared.data(for: farmUpdateRequest)
            let updatedFarm = try decoder.decode([DuoFarm].self, from: farmData).first
            print("✅ Reset farm to chicken only")

            // 3. Update local state
            self.metrics = updatedMetrics
            self.farm = updatedFarm
            self.isGameOver = false
            self.survivalStartDate = updatedFarm?.createdAt ?? resetDate
            await clearPlantInventory()
            await resetAnimalHealthRecords()
            ecosystem = nil
            await loadEcosystemFromDatabase()
            print("🎉 Farm restart complete!")

        } catch {
            print("❌ Restart failed:", error)
        }
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
            "animals_sleeping": false,
            "last_activity_at": ISO8601DateFormatter().string(from: Date())
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

    private var tutorialCompleted: Bool {
        get { UserDefaults.standard.bool(forKey: tutorialCompletionKey) }
        set { UserDefaults.standard.set(newValue, forKey: tutorialCompletionKey) }
    }

    private func updateTutorialPresentationState() {
        shouldShowTutorial = cachedRoomCode != nil && !tutorialCompleted
    }

    private func scheduleTutorialPresentation() {
        tutorialCompleted = false
        updateTutorialPresentationState()
    }

    func completeTutorialFlow() {
        tutorialCompleted = true
        updateTutorialPresentationState()
    }
    
    // MARK: - New Ecosystem Management
    
    @Published private(set) var ecosystem: FarmEcosystem?
    
    func initializeEcosystem(force: Bool = false) async {
        guard let roomID = cachedDuoID else {
            print("❌ Cannot initialize ecosystem - no room ID")
            return
        }

        if ecosystem != nil && !force {
            return
        }

        // Create empty ecosystem - animals will be loaded from database with their actual health
        // DO NOT add animals with default 100% health here - that causes flickering!
        ecosystem = FarmEcosystem(roomId: roomID)

        print("✅ Ecosystem initialized - will load animals from database")
    }
    
    func purchasePlant(plantID: String, cost: Int) async {
        guard let plant = PlantCatalog.plant(byID: plantID),
              let roomID = cachedDuoID,
              let session = authService.session,
              let currentMetrics = metrics else {
            print("❌ Cannot purchase plant - missing data")
            return
        }
        
        print("🌱 Purchasing \(plant.name) for \(cost) love points")
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            // 1. Update love energy in database (deduct cost)
            let newLoveEnergy = currentMetrics.loveEnergy - cost
            var metricsUpdateURL = URLComponents(
                url: environment.restURL.appendingPathComponent("duo_metrics"),
                resolvingAgainstBaseURL: false
            )!
            metricsUpdateURL.queryItems = [
                URLQueryItem(name: "room_id", value: "eq.\(roomID.uuidString)")
            ]

            var metricsUpdateRequest = URLRequest(url: metricsUpdateURL.url!)
            metricsUpdateRequest.httpMethod = "PATCH"
            metricsUpdateRequest.allHTTPHeaderFields = environment.headers(accessToken: session.accessToken)
            metricsUpdateRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            metricsUpdateRequest.setValue("return=representation", forHTTPHeaderField: "Prefer")

            let metricsPayload = ["love_energy": newLoveEnergy]
            metricsUpdateRequest.httpBody = try JSONSerialization.data(withJSONObject: metricsPayload)

            let (metricsData, _) = try await URLSession.shared.data(for: metricsUpdateRequest)
            let updatedMetrics = try decoder.decode([DuoMetrics].self, from: metricsData).first
            print("✅ Updated metrics, new love energy:", updatedMetrics?.loveEnergy ?? 0)
            
            // 2. Add plant to inventory for later feeding
            await upsertPlantInventory(roomID: roomID, plantID: plantID, quantityToAdd: 1, session: session)
            await refreshEcosystemData()
            
            // 3. Update local state
            self.metrics = updatedMetrics
            
            print("✅ Plant purchase complete! Added \(plant.name) to inventory")
            
        } catch {
            print("❌ Plant purchase failed:", error)
        }
    }

    func feedAnimal(animalId: String, with plantID: String) -> Bool {
        guard let plant = PlantCatalog.plant(byID: plantID),
              var currentEcosystem = ecosystem,
              var animal = currentEcosystem.animalHealthMap[animalId],
              let plantCount = currentEcosystem.plantInventory[plantID],
              plantCount > 0 else {
            print("❌ Cannot feed animal - missing plant inventory or ecosystem")
            return false
        }

        animal.feed(with: plant)
        currentEcosystem.animalHealthMap[animalId] = animal
        currentEcosystem.plantInventory[plantID] = plantCount - 1
        if currentEcosystem.plantInventory[plantID] == 0 {
            currentEcosystem.plantInventory.removeValue(forKey: plantID)
        }
        currentEcosystem.lastUpdatedAt = Date()
        ecosystem = currentEcosystem

        Task {
            await saveAnimalHealthToDatabase(using: currentEcosystem, only: [animalId])
            let newQuantity = currentEcosystem.plantInventory[plantID] ?? 0
            await persistPlantInventoryCount(plantID: plantID, quantity: newQuantity)
            await refreshEcosystemData()
            await refreshAnimalHealthFromDatabase()
        }

        print("🍽️ Fed \(animalId) with \(plant.name)")
        return true
    }
    
    func updateAnimalHealth() {
        // DO NOT call updateAllAnimalHealth() here - it causes flickering!
        // Health is calculated in real-time from the database values in refreshAnimalHealthFromDatabase()

        // Just clean up dead animals and check for deaths
        Task {
            await cleanupDeadAnimals()
        }

        print("⏰ Checked for dead animals")
    }
    
    private func cleanupDeadAnimals() async {
        guard let currentEcosystem = ecosystem else { return }
        
        let deadAnimals = currentEcosystem.animalHealthMap.filter { $1.isDead }
        
        if !deadAnimals.isEmpty {
            print("💀 Cleaning up \(deadAnimals.count) dead animals")
            
            // Remove from ecosystem
            ecosystem?.removeDeadAnimals()
            
            // Remove from database
            await deleteAnimalHealthRecords(withIDs: Array(deadAnimals.keys))

            let deadTypes = Set(deadAnimals.values.map { $0.animalType })
            if !deadTypes.isEmpty {
                await removeAnimalsFromFarm(deadTypes)
            }
        }

        await evaluateGameOverConditionIfNeeded()
    }

    private func evaluateGameOverConditionIfNeeded() async {
        guard let farm = farm else { return }

        let hasFarmAnimals = !farm.unlockedAnimals.isEmpty
        let healthMap = ecosystem?.animalHealthMap ?? [:]
        let hasAnyHealthRecords = !healthMap.isEmpty
        let hasLivingHealthRecords = healthMap.values.contains { !$0.isDead }

        var shouldBeGameOver = false
        if !hasFarmAnimals {
            shouldBeGameOver = true
        } else if hasAnyHealthRecords {
            shouldBeGameOver = !hasLivingHealthRecords
        }

        if shouldBeGameOver {
            if !isGameOver {
                print("💥 All animals lost - triggering game over")
                isGameOver = true
            }
        } else if isGameOver {
            print("🌤️ Farm revived - clearing game over state")
            isGameOver = false
        }
    }
    
    func onActivitySent() {
        // When couples are active, extend animal life by a few hours (not full heal)
        guard ecosystem != nil else { return }
        // Activities now only generate love points for buying plants; animals no longer gain health directly.
        print("💕 Activity sent! Earned love energy for plants (no direct health boost)")
    }
    
    var criticalAnimalsCount: Int {
        ecosystem?.criticalAnimalsCount ?? 0
    }
    
    var overallFarmHealth: Double {
        ecosystem?.overallHealthPercentage ?? 1.0
    }
    
    var farmHealthWarning: String {
        ecosystem?.worstWarningLevel.message ?? "Animals are happy and healthy!"
    }
    
    func loadEcosystemFromDatabase() async {
        await initializeEcosystem()
        await refreshEcosystemData()
        await refreshAnimalHealthFromDatabase()
    }

    private func persistPlantInventoryCount(plantID: String, quantity: Int) async {
        guard let roomID = cachedDuoID,
              let session = authService.session else {
            print("❌ Cannot persist plant inventory - missing data")
            return
        }

        do {
            let payload: [String: Any] = [
                "room_id": roomID.uuidString,
                "plant_id": plantID,
                "quantity": quantity,
                "updated_at": ISO8601DateFormatter().string(from: Date())
            ]

            var request = URLRequest(url: environment.restURL.appendingPathComponent("plant_inventory"))
            request.httpMethod = "POST"
            request.allHTTPHeaderFields = environment.headers(accessToken: session.accessToken)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("return=minimal,resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)

            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode < 400 else {
                print("❌ Failed to persist plant inventory for \(plantID)")
                return
            }

            print("✅ Updated plant inventory for \(plantID): \(quantity)")
        } catch {
            print("❌ Error updating plant inventory:", error)
        }
    }
    
    private func refreshAnimalHealthFromDatabase() async {
        guard let roomID = cachedDuoID,
              let session = authService.session else {
            print("❌ Cannot refresh animal health - missing data")
            return
        }
        
        do {
            // Load animal health from database
            var animalURL = URLComponents(
                url: environment.restURL.appendingPathComponent("animal_health"),
                resolvingAgainstBaseURL: false
            )!
            animalURL.queryItems = [
                URLQueryItem(name: "room_id", value: "eq.\(roomID.uuidString)"),
                URLQueryItem(name: "select", value: "*")
            ]
            
            var animalRequest = URLRequest(url: animalURL.url!)
            animalRequest.httpMethod = "GET"
            animalRequest.allHTTPHeaderFields = environment.headers(accessToken: session.accessToken)
            
            let (animalData, _) = try await URLSession.shared.data(for: animalRequest)
            let animalRows = try JSONSerialization.jsonObject(with: animalData) as? [[String: Any]] ?? []
            
            print("📊 Found \(animalRows.count) animal health records in database")
            
            // Create ecosystem if needed
            if ecosystem == nil {
                await initializeEcosystem()
            }
            
            // If no animal health records exist but we have unlocked animals, create them
            if animalRows.isEmpty && !(farm?.unlockedAnimals.isEmpty ?? true) {
                print("🔄 No animal health records found, but have unlocked animals. Creating initial records...")
                await createMissingAnimalHealthRecords()
                // Recursive call to load the newly created records
                await refreshAnimalHealthFromDatabase()
                return
            }
            
            // Update animal health - calculate current health from database values
            var bestByType: [String: (id: String, health: AnimalHealth)] = [:]

            // Create ISO8601 formatters that handle both with and without fractional seconds
            let formatterWithFractional = ISO8601DateFormatter()
            formatterWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            let formatterWithoutFractional = ISO8601DateFormatter()
            formatterWithoutFractional.formatOptions = [.withInternetDateTime]

            for row in animalRows {
                if let animalId = row["animal_id"] as? String,
                   let animalType = row["animal_type"] as? String,
                   let lastFedString = row["last_fed_at"] as? String,
                   let dbHoursUntilDeath = row["hours_until_death"] as? Double {

                    // Try parsing with fractional seconds first, then without
                    guard let dbLastFedAt = formatterWithFractional.date(from: lastFedString)
                                         ?? formatterWithoutFractional.date(from: lastFedString) else {
                        print("⚠️ Failed to parse date for \(animalType): \(lastFedString)")
                        continue
                    }

                    // Calculate current health based on time elapsed since last database update
                    let now = Date()
                    let elapsedSinceLastFed = now.timeIntervalSince(dbLastFedAt) / 3600 // hours
                    let adjustedElapsed = elapsedSinceLastFed * deathSpeedMultiplier
                    let currentHoursUntilDeath = max(0, dbHoursUntilDeath - adjustedElapsed)

                    // Create animal with calculated current health, but keep original lastFedAt
                    let animalHealth = AnimalHealth(
                        id: animalId,
                        animalType: animalType,
                        lastFedAt: dbLastFedAt,
                        hoursUntilDeath: currentHoursUntilDeath
                    )

                    let healthPct = (currentHoursUntilDeath / 24.0) * 100
                    print("💊 \(animalType): DB hours=\(String(format: "%.3f", dbHoursUntilDeath)), elapsed=\(String(format: "%.3f", adjustedElapsed)), current=\(String(format: "%.3f", currentHoursUntilDeath)), HP=\(String(format: "%.1f", healthPct))%")

                    if var existing = bestByType[animalType] {
                        let hpDelta = animalHealth.hoursUntilDeath - existing.health.hoursUntilDeath
                        if hpDelta > 0.001 || (abs(hpDelta) < 0.001 && animalHealth.lastFedAt > existing.health.lastFedAt) {
                            existing = (id: animalId, health: animalHealth)
                            bestByType[animalType] = existing
                        }
                    } else {
                        bestByType[animalType] = (id: animalId, health: animalHealth)
                    }
                }
            }

            // Only update if we have new data - prevents unnecessary UI refreshes
            var refreshedIDs: [String] = []
            var hadDeadAnimals = false
            if !bestByType.isEmpty {
                var newHealthMap: [String: AnimalHealth] = [:]
                for (animalType, entry) in bestByType {
                    newHealthMap[entry.id] = entry.health
                    if entry.health.isDead {
                        hadDeadAnimals = true
                    }
                    print("✅ Keeping best record for \(animalType): \(entry.id) @ \(Int(entry.health.healthPercentage * 100))%")
                }
                ecosystem?.animalHealthMap = newHealthMap
                ecosystem?.lastUpdatedAt = Date()
                refreshedIDs = Array(newHealthMap.keys)
            } else {
                ecosystem?.animalHealthMap = [:]
            }
            
            if !refreshedIDs.isEmpty {
                print("✅ Refreshed animal health data - Animals: \(refreshedIDs.sorted())")
            }
            
            if hadDeadAnimals {
                await cleanupDeadAnimals()
            } else {
                await evaluateGameOverConditionIfNeeded()
            }
            
        } catch {
            print("❌ Error refreshing animal health:", error)
        }
    }
    
    private func createAnimalHealthRecord(animalID: String, roomID: UUID, session: AuthSession) async {
        let uniqueAnimalId = "\(animalID)_\(UUID().uuidString.prefix(8))"

        let payload: [String: Any] = [
            "room_id": roomID.uuidString,
            "animal_id": uniqueAnimalId,
            "animal_type": animalID,
            "last_fed_at": ISO8601DateFormatter().string(from: Date()),
            "hours_until_death": 24.0 // New animals start with full health
        ]

        do {
            var createRequest = URLRequest(url: environment.restURL.appendingPathComponent("animal_health"))
            createRequest.httpMethod = "POST"
            createRequest.allHTTPHeaderFields = environment.headers(accessToken: session.accessToken)
            createRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            createRequest.setValue("return=minimal", forHTTPHeaderField: "Prefer")
            createRequest.httpBody = try JSONSerialization.data(withJSONObject: payload)

            let (_, response) = try await URLSession.shared.data(for: createRequest)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode < 400 else {
                print("❌ Failed to create health record for \(animalID)")
                return
            }

            print("✅ Created health record for \(animalID) with full health")

        } catch {
            print("❌ Error creating health record for \(animalID):", error)
        }
    }

    private func createMissingAnimalHealthRecords() async {
        guard let roomID = cachedDuoID,
              let session = authService.session,
              let unlockedAnimals = farm?.unlockedAnimals else {
            print("❌ Cannot create animal health records - missing data")
            return
        }
        
        print("🐔 Creating health records for \(unlockedAnimals.count) unlocked animals")
        
        for animalType in unlockedAnimals {
            let animalId = "\(animalType)_\(UUID().uuidString.prefix(8))"
            
            let payload: [String: Any] = [
                "room_id": roomID.uuidString,
                "animal_id": animalId,
                "animal_type": animalType,
                "last_fed_at": ISO8601DateFormatter().string(from: Date()),
                "hours_until_death": 24.0 // New animals start with full health
            ]
            
            do {
                var createRequest = URLRequest(url: environment.restURL.appendingPathComponent("animal_health"))
                createRequest.httpMethod = "POST"
                createRequest.allHTTPHeaderFields = environment.headers(accessToken: session.accessToken)
                createRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                createRequest.setValue("return=minimal", forHTTPHeaderField: "Prefer")
                createRequest.httpBody = try JSONSerialization.data(withJSONObject: payload)
                
                let (_, response) = try await URLSession.shared.data(for: createRequest)
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode < 400 else {
                    print("❌ Failed to create health record for \(animalType)")
                    continue
                }
                
                print("✅ Created health record for \(animalType)")
                
            } catch {
                print("❌ Error creating health record for \(animalType):", error)
            }
        }
    }

    private func upsertPlantInventory(roomID: UUID, plantID: String, quantityToAdd: Int, session: AuthSession) async {
        do {
            var selectURL = URLComponents(
                url: environment.restURL.appendingPathComponent("plant_inventory"),
                resolvingAgainstBaseURL: false
            )!
            selectURL.queryItems = [
                URLQueryItem(name: "room_id", value: "eq.\(roomID.uuidString)"),
                URLQueryItem(name: "plant_id", value: "eq.\(plantID)"),
                URLQueryItem(name: "select", value: "quantity")
            ]
            
            var selectRequest = URLRequest(url: selectURL.url!)
            selectRequest.httpMethod = "GET"
            selectRequest.allHTTPHeaderFields = environment.headers(accessToken: session.accessToken)
            
            let (data, _) = try await URLSession.shared.data(for: selectRequest)
            let existingRows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
            let currentQuantity = (existingRows.first?["quantity"] as? Int) ?? 0
            let newQuantity = currentQuantity + quantityToAdd
            
            var upsertRequest = URLRequest(url: environment.restURL.appendingPathComponent("plant_inventory"))
            upsertRequest.httpMethod = "POST"
            upsertRequest.allHTTPHeaderFields = environment.headers(accessToken: session.accessToken)
            upsertRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            upsertRequest.setValue("return=representation,resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
            
            let payload: [String: Any] = [
                "room_id": roomID.uuidString,
                "plant_id": plantID,
                "quantity": newQuantity,
                "updated_at": ISO8601DateFormatter().string(from: Date())
            ]
            upsertRequest.httpBody = try JSONSerialization.data(withJSONObject: payload)
            
            let (_, response) = try await URLSession.shared.data(for: upsertRequest)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode < 400 else {
                print("❌ Failed to update plant inventory")
                return
            }
            
            print("✅ Updated plant inventory: \(plantID) = \(newQuantity)")
            
        } catch {
            print("❌ Error updating plant inventory:", error)
        }
    }
    
    private func refreshEcosystemData() async {
        guard let roomID = cachedDuoID,
              let session = authService.session else {
            print("❌ Cannot refresh ecosystem - missing data")
            return
        }
        
        do {
            var plantURL = URLComponents(
                url: environment.restURL.appendingPathComponent("plant_inventory"),
                resolvingAgainstBaseURL: false
            )!
            plantURL.queryItems = [
                URLQueryItem(name: "room_id", value: "eq.\(roomID.uuidString)"),
                URLQueryItem(name: "select", value: "*")
            ]
            
            var plantRequest = URLRequest(url: plantURL.url!)
            plantRequest.httpMethod = "GET"
            plantRequest.allHTTPHeaderFields = environment.headers(accessToken: session.accessToken)
            
            let (plantData, _) = try await URLSession.shared.data(for: plantRequest)
            let plantRows = try JSONSerialization.jsonObject(with: plantData) as? [[String: Any]] ?? []
            
            if ecosystem == nil {
                await initializeEcosystem()
            }
            
            var newInventory: [String: Int] = [:]
            for row in plantRows {
                if let plantId = row["plant_id"] as? String,
                   let quantity = row["quantity"] as? Int {
                    newInventory[plantId] = quantity
                }
            }
            
            ecosystem?.plantInventory = newInventory
            ecosystem?.lastUpdatedAt = Date()
            
            print("✅ Refreshed ecosystem data - Plants: \(newInventory)")
            
        } catch {
            print("❌ Error refreshing ecosystem:", error)
        }
    }
   
    private func saveAnimalHealthToDatabase(using ecosystemSnapshot: FarmEcosystem? = nil, only animalIDs: [String]? = nil) async {
        guard let roomID = cachedDuoID,
              let session = authService.session else {
            print("❌ Cannot save animal health - missing data")
            return
        }

        let ecosystemToPersist = ecosystemSnapshot ?? ecosystem

        guard let currentEcosystem = ecosystemToPersist else {
            print("❌ Cannot save animal health - no ecosystem snapshot")
            return
        }

        if let animalIDs, animalIDs.isEmpty {
            print("ℹ️ No animal IDs provided for save - skipping")
            return
        }

        let formatter = ISO8601DateFormatter()
        let snapshotDate = Date()
        let elapsedSinceLastUpdate = max(0, snapshotDate.timeIntervalSince(currentEcosystem.lastUpdatedAt) / 3600)
        let isFullSync = animalIDs == nil
        let targetIDs = animalIDs.map { Set<String>($0) }
        
        do {
            // Save each animal's health to database
            for (animalId, animal) in currentEcosystem.animalHealthMap {
                if let targetIDs, !targetIDs.contains(animalId) { continue }

                let referenceDate = isFullSync ? snapshotDate : animal.lastFedAt
                let normalizedHours = isFullSync
                    ? max(0, animal.hoursUntilDeath - elapsedSinceLastUpdate)
                    : animal.hoursUntilDeath

                let payload: [String: Any] = [
                    "room_id": roomID.uuidString,
                    "animal_id": animalId,
                    "animal_type": animal.animalType,
                    "last_fed_at": formatter.string(from: referenceDate),
                    "hours_until_death": normalizedHours
                ]
                
                var upsertRequest = URLRequest(url: environment.restURL.appendingPathComponent("animal_health"))
                upsertRequest.httpMethod = "POST"
                upsertRequest.allHTTPHeaderFields = environment.headers(accessToken: session.accessToken)
                upsertRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                upsertRequest.setValue("return=minimal,resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
                upsertRequest.httpBody = try JSONSerialization.data(withJSONObject: payload)
                
                let (_, response) = try await URLSession.shared.data(for: upsertRequest)
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode < 400 else {
                    print("❌ Failed to save animal health for \(animalId)")
                    continue
                }
            }

            ecosystem?.lastUpdatedAt = snapshotDate

            if let animalIDs {
                print("✅ Saved animal health for \(animalIDs.count) animal(s)")
            } else {
                print("✅ Saved full animal health snapshot")
            }
            
        } catch {
            print("❌ Error saving animal health:", error)
        }
    }

    private func deleteAnimalHealthRecords(withIDs animalIDs: [String]) async {
        guard !animalIDs.isEmpty else { return }
        guard let roomID = cachedDuoID,
              let session = authService.session else {
            print("❌ Cannot delete animal health - missing credentials")
            return
        }

        do {
            for animalId in animalIDs {
                var components = URLComponents(
                    url: environment.restURL.appendingPathComponent("animal_health"),
                    resolvingAgainstBaseURL: false
                )!
                components.queryItems = [
                    URLQueryItem(name: "room_id", value: "eq.\(roomID.uuidString)"),
                    URLQueryItem(name: "animal_id", value: "eq.\(animalId)")
                ]

                guard let url = components.url else { continue }

                var deleteRequest = URLRequest(url: url)
                deleteRequest.httpMethod = "DELETE"
                deleteRequest.allHTTPHeaderFields = environment.headers(accessToken: session.accessToken)
                deleteRequest.setValue("return=minimal", forHTTPHeaderField: "Prefer")

                let (_, response) = try await URLSession.shared.data(for: deleteRequest)
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode < 400 else {
                    print("❌ Failed to delete animal \(animalId)")
                    continue
                }
            }

            print("🧹 Deleted \(animalIDs.count) dead animal record(s)")
        } catch {
            print("❌ Error deleting animal health:", error)
        }
    }

    private func resetAnimalHealthRecords() async {
        guard let roomID = cachedDuoID,
              let session = authService.session else { return }

        do {
            var components = URLComponents(
                url: environment.restURL.appendingPathComponent("animal_health"),
                resolvingAgainstBaseURL: false
            )!
            components.queryItems = [
                URLQueryItem(name: "room_id", value: "eq.\(roomID.uuidString)")
            ]

            guard let url = components.url else { return }

            var deleteRequest = URLRequest(url: url)
            deleteRequest.httpMethod = "DELETE"
            deleteRequest.allHTTPHeaderFields = environment.headers(accessToken: session.accessToken)
            deleteRequest.setValue("return=minimal", forHTTPHeaderField: "Prefer")

            let (_, response) = try await URLSession.shared.data(for: deleteRequest)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode < 400 else {
                print("❌ Failed to reset animal health records")
                return
            }

            print("🧼 Cleared all animal health records for restart")
        } catch {
            print("❌ Error resetting animal health records:", error)
        }
    }

    private func clearPlantInventory() async {
        guard let roomID = cachedDuoID,
              let session = authService.session else { return }

        do {
            var components = URLComponents(
                url: environment.restURL.appendingPathComponent("plant_inventory"),
                resolvingAgainstBaseURL: false
            )!
            components.queryItems = [
                URLQueryItem(name: "room_id", value: "eq.\(roomID.uuidString)")
            ]

            guard let url = components.url else { return }

            var deleteRequest = URLRequest(url: url)
            deleteRequest.httpMethod = "DELETE"
            deleteRequest.allHTTPHeaderFields = environment.headers(accessToken: session.accessToken)
            deleteRequest.setValue("return=minimal", forHTTPHeaderField: "Prefer")

            let (_, response) = try await URLSession.shared.data(for: deleteRequest)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode < 400 else {
                print("❌ Failed to clear plant inventory on restart")
                return
            }

            print("🌱 Cleared plant inventory for restart")
        } catch {
            print("❌ Error clearing plant inventory:", error)
        }
    }

    private func removeAnimalsFromFarm(_ animalTypes: Set<String>) async {
        guard let roomID = cachedDuoID,
              let session = authService.session,
              let currentFarm = farm,
              !animalTypes.isEmpty else { return }

        let updatedAnimals = currentFarm.unlockedAnimals.filter { !animalTypes.contains($0) }
        guard updatedAnimals.count != currentFarm.unlockedAnimals.count else { return }

        do {
            var farmUpdateURL = URLComponents(
                url: environment.restURL.appendingPathComponent("duo_farms"),
                resolvingAgainstBaseURL: false
            )!
            farmUpdateURL.queryItems = [
                URLQueryItem(name: "room_id", value: "eq.\(roomID.uuidString)")
            ]

            var farmUpdateRequest = URLRequest(url: farmUpdateURL.url!)
            farmUpdateRequest.httpMethod = "PATCH"
            farmUpdateRequest.allHTTPHeaderFields = environment.headers(accessToken: session.accessToken)
            farmUpdateRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            farmUpdateRequest.setValue("return=representation", forHTTPHeaderField: "Prefer")

            let payload: [String: Any] = [
                "unlocked_animals": updatedAnimals
            ]
            farmUpdateRequest.httpBody = try JSONSerialization.data(withJSONObject: payload)

            let (farmData, response) = try await URLSession.shared.data(for: farmUpdateRequest)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode < 400 else {
                print("❌ Failed to update farm animals after death")
                return
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let updatedFarm = try decoder.decode([DuoFarm].self, from: farmData).first
            self.farm = updatedFarm ?? {
                var manual = currentFarm
                manual.unlockedAnimals = updatedAnimals
                return manual
            }()

            print("🌑 Removed dead animals from farm: \(animalTypes.sorted())")
        } catch {
            print("❌ Error removing animals from farm:", error)
        }
    }
}

#if DEBUG
extension CoupleSessionManager {
    static var preview: CoupleSessionManager {
        let auth = AuthService(managesDeviceTokens: false)
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

extension CoupleSessionManager {
    var daysTogether: Int {
        let reference = survivalStartDate ?? farm?.createdAt ?? metrics?.createdAt ?? Date()
        let components = Calendar.current.dateComponents([.day], from: reference, to: Date())
        return max(0, components.day ?? 0)
    }

    var hasClearedTrial: Bool {
        daysTogether >= 1
    }
}

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

#if DEBUG
extension CoupleSessionManager {
    func setFastDeathMode(enabled: Bool) {
        deathSpeedMultiplier = enabled ? Self.fastDeathMultiplierValue : 1.0
        print(enabled ? "⚡️ Fast death mode enabled manually" : "🐢 Fast death mode disabled")
    }
}
#endif
