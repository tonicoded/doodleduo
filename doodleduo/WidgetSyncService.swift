//
//  WidgetSyncService.swift
//  doodleduo
//
//  Keeps the Latest Doodle widget in sync when the app is backgrounded or closed.
//

import Foundation

final class WidgetSyncService {
    static let shared = WidgetSyncService()
    
    private let environment = SupabaseEnvironment.makeCurrent()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    
    private init() {}
    
    enum Trigger {
        case backgroundRefresh
        case push(activityID: UUID?)
    }
    
    /// Fetch the latest partner doodle and store it for the widget.
    @discardableResult
    func syncLatestDoodle(trigger: Trigger) async -> Bool {
        guard let context = await loadContext() else {
            print("🔁 WidgetSyncService: Missing auth/room context, skipping sync")
            return false
        }
        
        let activityID: UUID?
        switch trigger {
        case .backgroundRefresh:
            activityID = nil
        case .push(let id):
            activityID = id
        }
        
        do {
            guard let doodle = try await fetchDoodle(context: context, activityID: activityID) else {
                print("🔁 WidgetSyncService: No partner doodle found for sync")
                return false
            }
            
            await MainActor.run {
                DoodleWidgetStore.shared.saveReceivedDoodle(
                    imageData: doodle.imageData,
                    fromPartner: doodle.partnerName,
                    activityDate: doodle.createdAt,
                    activityID: doodle.activityID
                )
            }
            print("✅ WidgetSyncService: Stored doodle from \(doodle.partnerName)")
            return true
        } catch {
            print("❌ WidgetSyncService: Failed to fetch doodle - \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Private helpers
    
    private func loadContext() async -> SyncContext? {
        await MainActor.run {
            let authService = AuthService(managesDeviceTokens: false)
            guard let session = authService.session else {
                return nil
            }
            
            let sessionManager = CoupleSessionManager(authService: authService)
            guard let roomID = sessionManager.currentRoomID else {
                return nil
            }
            
            let partnerName = sessionManager.partnerName ?? "your partner"
            let cachedUserID = authService.currentUser?.id ?? Self.cachedUserID()
            
            return SyncContext(
                session: session,
                roomID: roomID,
                partnerDisplayName: partnerName,
                currentUserID: cachedUserID
            )
        }
    }
    
    private func fetchDoodle(context: SyncContext, activityID: UUID?) async throws -> FetchedDoodle? {
        var components = URLComponents(
            url: environment.restURL.appendingPathComponent("duo_activities"),
            resolvingAgainstBaseURL: false
        )
        
        var items: [URLQueryItem] = [
            URLQueryItem(name: "select", value: "id,author_id,activity_type,content,created_at"),
            URLQueryItem(name: "limit", value: "1")
        ]
        
        if let activityID = activityID {
            items.append(URLQueryItem(name: "id", value: "eq.\(activityID.uuidString)"))
        } else {
            items.append(URLQueryItem(name: "room_id", value: "eq.\(context.roomID.uuidString)"))
            items.append(URLQueryItem(name: "activity_type", value: "eq.doodle"))
            items.append(URLQueryItem(name: "order", value: "created_at.desc"))
        }
        
        if activityID == nil, let currentUserID = context.currentUserID {
            items.append(URLQueryItem(name: "author_id", value: "neq.\(currentUserID.uuidString)"))
        }
        
        components?.queryItems = items
        
        guard let url = components?.url else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = environment.headers(accessToken: context.session.accessToken)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<400).contains(httpResponse.statusCode) else {
            if let body = String(data: data, encoding: .utf8) {
                print("❌ WidgetSyncService: Supabase error \( (response as? HTTPURLResponse)?.statusCode ?? -1): \(body)")
            }
            return nil
        }
        
        guard let activity = try decoder.decode([WidgetActivityResponse].self, from: data).first,
              activity.activityType == "doodle",
              let imageData = WidgetSyncService.decodeImage(from: activity.content) else {
            return nil
        }

        if let currentUserID = context.currentUserID, activity.authorID == currentUserID {
            print("🔁 WidgetSyncService: Ignoring doodle \(activity.id) authored by current user")
            return nil
        }
        
        return FetchedDoodle(
            imageData: imageData,
            partnerName: context.partnerDisplayName,
            createdAt: activity.createdAt,
            activityID: activity.id
        )
    }
    
    private static func decodeImage(from payload: String) -> Data? {
        let trimmed: String
        if let commaIndex = payload.firstIndex(of: ",") {
            trimmed = String(payload[payload.index(after: commaIndex)...])
        } else {
            trimmed = payload
        }
        return Data(base64Encoded: trimmed)
    }
    
    private static func cachedUserID() -> UUID? {
        guard let raw = UserDefaults.standard.string(forKey: "doodleduo.cachedDisplayNameUser") else {
            return nil
        }
        return UUID(uuidString: raw)
    }
}

// MARK: - Helper models

private struct SyncContext {
    let session: AuthSession
    let roomID: UUID
    let partnerDisplayName: String
    let currentUserID: UUID?
}

private struct WidgetActivityResponse: Decodable {
    let id: UUID
    let authorID: UUID
    let activityType: String
    let content: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case authorID = "author_id"
        case activityType = "activity_type"
        case content
        case createdAt = "created_at"
    }
}

private struct FetchedDoodle {
    let imageData: Data
    let partnerName: String
    let createdAt: Date
    let activityID: UUID
}
