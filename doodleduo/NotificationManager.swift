//
//  NotificationManager.swift
//  doodleduo
//
//  Handles local and push notifications for partner activities
//

import Foundation
import UserNotifications
import WidgetKit
import UIKit
import Combine

class NotificationManager: NSObject {
    static let shared = NotificationManager()

    // Track last notified activity to prevent duplicates
    private var lastNotifiedActivityID: UUID?
    private let lastNotifiedActivityKey = "doodleduo.lastNotifiedActivity"

    // Store device token until user signs in
    private var pendingDeviceToken: Data?
    private let pendingDeviceTokenKey = "doodleduo.pendingDeviceToken"
    private let sessionQueue = DispatchQueue(label: "com.anthony.doodleduo.notifications.session")
    private var cachedSession: AuthSession?

    private override init() {
        super.init()
        loadLastNotifiedActivity()
        loadPendingDeviceToken()
    }
    
    func requestPermission() async -> Bool {
        print("🔔 Requesting notification permission...")
        let center = UNUserNotificationCenter.current()

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            print("🔔 Notification permission granted:", granted)

            if granted {
                print("📱 Calling registerForRemoteNotifications()...")
                // Register for remote notifications (push notifications)
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                print("📱 registerForRemoteNotifications() called")
            } else {
                print("⚠️ Notification permission denied by user")
            }

            return granted
        } catch {
            print("❌ Failed to request notification permission:", error)
            return false
        }
    }
    
    private func loadLastNotifiedActivity() {
        if let idString = UserDefaults.standard.string(forKey: lastNotifiedActivityKey),
           let id = UUID(uuidString: idString) {
            lastNotifiedActivityID = id
        }
    }

    private func saveLastNotifiedActivity(_ id: UUID) {
        lastNotifiedActivityID = id
        UserDefaults.standard.set(id.uuidString, forKey: lastNotifiedActivityKey)
    }

    private func loadPendingDeviceToken() {
        pendingDeviceToken = UserDefaults.standard.data(forKey: pendingDeviceTokenKey)
    }

    private func savePendingDeviceToken(_ token: Data) {
        pendingDeviceToken = token
        UserDefaults.standard.set(token, forKey: pendingDeviceTokenKey)
        print("💾 Saved pending device token")
    }

    private func clearPendingDeviceToken() {
        pendingDeviceToken = nil
        UserDefaults.standard.removeObject(forKey: pendingDeviceTokenKey)
        print("🗑️ Cleared pending device token")
    }
    
    func sendPartnerActivityNotification(partnerName: String, activityType: DuoActivity.ActivityType, activityContent: String? = nil, activityID: UUID) {
        // Check if we've already notified for this activity
        if lastNotifiedActivityID == activityID {
            print("🔕 Skipping duplicate notification for activity \(activityID)")
            return
        }
        
        let center = UNUserNotificationCenter.current()
        
        // Create notification content
        let notificationContent = UNMutableNotificationContent()
        notificationContent.sound = .default
        
        switch activityType {
        case .doodle:
            notificationContent.title = "New Doodle from \(partnerName.capitalized) 🎨"
            notificationContent.body = "Your partner just shared a doodle with you!"
        case .ping:
            notificationContent.title = "\(partnerName.capitalized) is thinking of you 💝"
            notificationContent.body = "Your partner sent you a ping!"
        case .note:
            notificationContent.title = "\(partnerName.capitalized) sent a note 📝"
            notificationContent.body = activityContent?.isEmpty == false ? activityContent! : "They shared something with you"
        case .hug:
            notificationContent.title = "\(partnerName.capitalized) sent you a hug 🤗"
            notificationContent.body = "Your partner is giving you a virtual hug!"
        case .kiss:
            notificationContent.title = "\(partnerName.capitalized) sent you a kiss 💋"
            notificationContent.body = "Your partner is sending you love!"
        }
        
        // Add custom data for handling
        notificationContent.userInfo = [
            "partnerName": partnerName,
            "activityType": activityType.rawValue,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        // Create request with unique identifier
        let identifier = "partner_activity_\(Date().timeIntervalSince1970)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: notificationContent,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        
        // Schedule notification
        center.add(request) { [weak self] error in
            if let error = error {
                print("❌ Failed to schedule notification:", error)
            } else {
                print("✅ Scheduled notification for \(partnerName) \(activityType)")
                
                // Save this activity as the last notified to prevent duplicates
                self?.saveLastNotifiedActivity(activityID)
                
                // Refresh widget when notification is sent
                WidgetCenter.shared.reloadTimelines(ofKind: "LatestDoodleWidget")
            }
        }
    }
    
    func clearAllNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }
    
    func setupNotificationHandling() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
    }
    
    func updateAuthSession(_ session: AuthSession?) {
        sessionQueue.sync {
            cachedSession = session
        }
    }
    
    private func currentSession() -> AuthSession? {
        sessionQueue.sync { cachedSession }
    }
    
    func registerDeviceToken(_ deviceToken: Data, for userId: UUID?, session overrideSession: AuthSession? = nil) async {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("📱 Registering device token: \(tokenString)")

        guard let userId = userId else {
            print("⚠️ No user ID yet - saving device token for later registration")
            savePendingDeviceToken(deviceToken)
            return
        }
        
        guard let session = overrideSession ?? currentSession() else {
            print("⚠️ No auth session available - caching token until session loads")
            savePendingDeviceToken(deviceToken)
            return
        }

        // Save device token to Supabase for push notifications
        let registered = await saveDeviceTokenToSupabase(tokenString, userId: userId, session: session)
        if registered {
            print("✅ Device token registered with Supabase")
            clearPendingDeviceToken()
        } else {
            print("⚠️ Failed to register token remotely - caching for retry")
            savePendingDeviceToken(deviceToken)
        }
    }

    func registerPendingDeviceToken(for userId: UUID) async {
        guard let token = pendingDeviceToken else {
            print("ℹ️ No pending device token to register")
            return
        }

        print("📱 Registering pending device token for user:", userId)
        await registerDeviceToken(token, for: userId)
    }
    
    private var currentPushEnvironment: String {
        if let override = Bundle.main.object(forInfoDictionaryKey: "APNS_PUSH_ENVIRONMENT") as? String,
           !override.trimmingCharacters(in: .whitespaces).isEmpty {
            return override.lowercased()
        }
#if DEBUG
        return "sandbox"
#else
        return "production"
#endif
    }
    
    @discardableResult
    private func saveDeviceTokenToSupabase(_ token: String, userId: UUID, session: AuthSession) async -> Bool {
        print("💾 Saving device token to Supabase for user: \(userId)")
        
        do {
            let environment = SupabaseEnvironment.makeCurrent()
            let url = environment.restURL.appendingPathComponent("rpc/register_device_token")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            
            request.allHTTPHeaderFields = environment.headers(accessToken: session.accessToken)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let payload: [String: Any] = [
                "p_device_token": token,
                "p_platform": "ios",
                "p_environment": currentPushEnvironment
            ]
            
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response registering device token")
                return false
            }
            
            if httpResponse.statusCode >= 400 {
                let errorBody = String(data: data, encoding: .utf8) ?? "<no body>"
                print("❌ Device token registration error:", httpResponse.statusCode, errorBody)
                return false
            }
            
            print("✅ Device token registered successfully (\(currentPushEnvironment))")
            return true
            
        } catch {
            print("❌ Error registering device token:", error)
            return false
        }
    }
    
    func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) {
        print("📲 Received remote notification:", userInfo)
        
        // Refresh widget when receiving push notification
        WidgetCenter.shared.reloadTimelines(ofKind: "LatestDoodleWidget")
        
        // Handle different notification types
        if let activityType = userInfo["activity_type"] as? String {
            print("🔔 Remote notification for activity type: \(activityType)")
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle notification tap
        let userInfo = response.notification.request.content.userInfo
        
        if let activityType = userInfo["activityType"] as? String,
           let partnerName = userInfo["partnerName"] as? String {
            print("✅ User tapped notification: \(activityType) from \(partnerName)")
            
            // Refresh widget when user interacts with notification
            WidgetCenter.shared.reloadTimelines(ofKind: "LatestDoodleWidget")
        }
        
        completionHandler()
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // IMPORTANT: Do NOT show notifications when app is in foreground
        // Only show notifications when app is in background or closed
        completionHandler([])
    }
}
