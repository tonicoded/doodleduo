//
//  DoodleWidgetStore.swift
//  doodleduo
//
//  Handles persisting the most recent doodle so the widget can mirror it.
//

import Foundation
import WidgetKit

struct DoodleWidgetSnapshot: Codable {
    let imageData: Data
    let senderName: String
    let partnerName: String?
    let updatedAt: Date
    let isFromPartner: Bool
    let activityID: UUID?
    
    static let placeholder = DoodleWidgetSnapshot(
        imageData: Data(),
        senderName: "partner",
        partnerName: nil,
        updatedAt: Date(),
        isFromPartner: true,
        activityID: nil
    )
}

final class DoodleWidgetStore {
    static let shared = DoodleWidgetStore()
    
    private let suiteName = "group.com.anthony.doodleduo.shared"
    private let storageKey = "latestDoodleSnapshot"
    private init() {}
    
    func saveReceivedDoodle(imageData: Data, fromPartner partnerName: String, activityDate: Date = Date(), activityID: UUID? = nil, forceRefresh: Bool = false) {
        print("🎨 DoodleWidgetStore: Attempting to save doodle from \(partnerName)")
        
        guard let defaults = UserDefaults(suiteName: suiteName) else { 
            print("❌ Failed to get UserDefaults with suite name: \(suiteName)")
            return 
        }
        
        print("✅ UserDefaults suite name loaded successfully")
        
        if !forceRefresh, let existing = loadLatestDoodle() {
            if let existingID = existing.activityID,
               let activityID,
               existingID == activityID {
                print("⚠️ Already have doodle \(activityID) cached")
                refreshWidgetTimeline()
                return
            }
            
            if existing.updatedAt > activityDate {
                print("⚠️ Existing doodle is newer (existing: \(existing.updatedAt), new: \(activityDate))")
                refreshWidgetTimeline()
                return
            }
            
            if activityID == nil, existing.updatedAt == activityDate {
                print("⚠️ Existing doodle has same timestamp and no activity ID, skipping update")
                refreshWidgetTimeline()
                return
            }
        }
        
        let snapshot = DoodleWidgetSnapshot(
            imageData: imageData,
            senderName: partnerName,
            partnerName: nil,
            updatedAt: activityDate,
            isFromPartner: true,
            activityID: activityID
        )
        
        print("📝 Created snapshot: partner=\(partnerName), size=\(imageData.count) bytes")
        
        if let encoded = try? JSONEncoder().encode(snapshot) {
            defaults.set(encoded, forKey: storageKey)
            let success = defaults.synchronize()
            print("💾 Saved to UserDefaults, sync success: \(success)")
            refreshWidgetTimeline()
        } else {
            print("❌ Failed to encode snapshot")
        }
    }
    
    func loadLatestDoodle() -> DoodleWidgetSnapshot? {
        print("🎨 DoodleWidgetStore: Loading latest doodle")
        
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            print("❌ Failed to get UserDefaults with suite name: \(suiteName)")
            return nil
        }
        
        guard let data = defaults.data(forKey: storageKey) else {
            print("⚠️ No data found for key: \(storageKey)")
            return nil
        }
        
        print("✅ Found data (\(data.count) bytes) for key: \(storageKey)")
        
        guard let snapshot = try? JSONDecoder().decode(DoodleWidgetSnapshot.self, from: data) else {
            print("❌ Failed to decode snapshot data")
            return nil
        }
        
        print("✅ Decoded snapshot: sender=\(snapshot.senderName), isFromPartner=\(snapshot.isFromPartner)")
        
        return snapshot.isFromPartner ? snapshot : nil
    }
    
    private func refreshWidgetTimeline() {
        guard #available(iOS 14.0, *) else { 
            print("❌ iOS 14.0+ required for widget refresh")
            return 
        }
        print("🔄 Refreshing widget timeline for 'LatestDoodleWidget'")
        WidgetCenter.shared.reloadTimelines(ofKind: "LatestDoodleWidget")
    }
}
