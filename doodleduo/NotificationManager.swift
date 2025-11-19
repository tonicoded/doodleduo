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

class NotificationManager: NSObject {
    static let shared = NotificationManager()

    // Track last notified activity to prevent duplicates
    private var lastNotifiedActivityID: UUID?
    private let lastNotifiedActivityKey = "doodleduo.lastNotifiedActivity"

    // Store device token until user signs in
    private var pendingDeviceToken: Data?
    private let pendingDeviceTokenKey = "doodleduo.pendingDeviceToken"

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
    
    func registerDeviceToken(_ deviceToken: Data, for userId: UUID?) async {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("📱 Registering device token: \(tokenString)")

        guard let userId = userId else {
            print("⚠️ No user ID yet - saving device token for later registration")
            savePendingDeviceToken(deviceToken)
            return
        }

        // Save device token to Supabase for push notifications
        await saveDeviceTokenToSupabase(tokenString, userId: userId)
        clearPendingDeviceToken()
    }

    func registerPendingDeviceToken(for userId: UUID) async {
        guard let token = pendingDeviceToken else {
            print("ℹ️ No pending device token to register")
            return
        }

        print("📱 Registering pending device token for user:", userId)
        await registerDeviceToken(token, for: userId)
    }
    
    private func saveDeviceTokenToSupabase(_ token: String, userId: UUID) async {
        print("💾 Saving device token to Supabase for user: \(userId)")
        
        do {
            let environment = SupabaseEnvironment.makeCurrent()
            var components = URLComponents(
                url: environment.restURL.appendingPathComponent("device_tokens"),
                resolvingAgainstBaseURL: false
            )
            components?.queryItems = [
                URLQueryItem(name: "on_conflict", value: "user_id")
            ]
            guard let url = components?.url else {
                print("❌ Invalid device token URL")
                return
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            
            // Get auth session for API call
            guard let session = AuthService().session else {
                print("❌ No auth session for device token registration")
                return
            }
            
            request.allHTTPHeaderFields = environment.headers(accessToken: session.accessToken)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("return=representation,resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
            
            let payload = [
                "user_id": userId.uuidString,
                "device_token": token,
                "platform": "ios"
            ]
            
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response registering device token")
                return
            }
            
            if httpResponse.statusCode >= 400 {
                print("❌ Device token registration error:", httpResponse.statusCode)
                return
            }
            
            print("✅ Device token registered successfully")
            
        } catch {
            print("❌ Error registering device token:", error)
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
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound])
    }
}
