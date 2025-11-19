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
    
    static let placeholder = DoodleWidgetSnapshot(
        imageData: Data(),
        senderName: "partner",
        partnerName: nil,
        updatedAt: Date(),
        isFromPartner: true
    )
}

final class DoodleWidgetStore {
    static let shared = DoodleWidgetStore()
    
    private let suiteName = "group.com.anthony.doodleduo.shared"
    private let storageKey = "latestDoodleSnapshot"
    private init() {}
    
    func saveReceivedDoodle(imageData: Data, fromPartner partnerName: String, activityDate: Date = Date()) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        
        if let existing = loadLatestDoodle(), existing.updatedAt >= activityDate {
            // Already have this doodle or a newer one cached
            return
        }
        
        let snapshot = DoodleWidgetSnapshot(
            imageData: imageData,
            senderName: partnerName,
            partnerName: nil,
            updatedAt: activityDate,
            isFromPartner: true
        )
        
        if let encoded = try? JSONEncoder().encode(snapshot) {
            defaults.set(encoded, forKey: storageKey)
            defaults.synchronize()
            refreshWidgetTimeline()
        }
    }
    
    func loadLatestDoodle() -> DoodleWidgetSnapshot? {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: storageKey),
              let snapshot = try? JSONDecoder().decode(DoodleWidgetSnapshot.self, from: data) else {
            return nil
        }
        return snapshot.isFromPartner ? snapshot : nil
    }
    
    private func refreshWidgetTimeline() {
        guard #available(iOS 14.0, *) else { return }
        WidgetCenter.shared.reloadTimelines(ofKind: "LatestDoodleWidget")
    }
}
