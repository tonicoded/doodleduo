//
//  doodleduoApp.swift
//  doodleduo
//
//  Created by Anthony Verruijt on 16/11/2025.
//

import SwiftUI
import UIKit
import BackgroundTasks
import WidgetKit

// App Delegate for handling remote notifications
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        print("🚀 AppDelegate didFinishLaunchingWithOptions called")
        // Register background tasks
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.anthony.doodleduo.refresh", using: nil) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
        print("🚀 AppDelegate initialization complete")
        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("📱 Device token received:", tokenString)
        Task {
            // Get current user ID and register device token (or save for later if not signed in yet)
            let userId = AuthService(managesDeviceTokens: false).currentUser?.id
            if userId != nil {
                print("📱 User signed in - registering device token immediately")
            } else {
                print("📱 User not signed in yet - saving device token for later")
            }
            await NotificationManager.shared.registerDeviceToken(deviceToken, for: userId)
        }
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for remote notifications:", error)
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("📲 Received remote notification")
        print("📲 Application state:", application.applicationState.rawValue)
        print("📲 Notification payload:", userInfo)

        // Handle the notification
        NotificationManager.shared.handleRemoteNotification(userInfo)

        let shouldRefreshWidget = (userInfo["widget_refresh"] as? Bool) == true
        let activityType = userInfo["activity_type"] as? String
        let activityID = (userInfo["activity_id"] as? String).flatMap(UUID.init)

        guard shouldRefreshWidget, activityType == "doodle" else {
            // No widget sync required, but still report success so iOS doesn't throttle pushes
            completionHandler(.newData)
            return
        }

        print("📲 Widget refresh requested via push notification")

        Task {
            let updated = await WidgetSyncService.shared.syncLatestDoodle(trigger: .push(activityID: activityID))
            completionHandler(updated ? .newData : .noData)
        }
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        scheduleAppRefresh()
    }
    
    private func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.anthony.doodleduo.refresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes from now
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("🔄 Scheduled background refresh")
        } catch {
            print("❌ Failed to schedule background refresh: \(error)")
        }
    }
    
    private func handleAppRefresh(task: BGAppRefreshTask) {
        print("🔄 Executing background refresh")

        // Schedule next refresh
        scheduleAppRefresh()
        
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        // Refresh widget data in background
        Task {
            let updated = await WidgetSyncService.shared.syncLatestDoodle(trigger: .backgroundRefresh)
            if !updated {
                WidgetCenter.shared.reloadTimelines(ofKind: "LatestDoodleWidget")
            }
            task.setTaskCompleted(success: true)
        }
    }
}

@main
struct doodleduoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                _ = await WidgetSyncService.shared.syncLatestDoodle(trigger: .backgroundRefresh)
            }
        }
    }
}
