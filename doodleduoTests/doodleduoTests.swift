//
//  doodleduoTests.swift
//  doodleduoTests
//
//  Created by Anthony Verruijt on 16/11/2025.
//

import Foundation
import Testing
@testable import doodleduo

struct doodleduoTests {

    @MainActor
    @Test func cachedDisplayNameLoadsFromDefaults() async throws {
        let userID = UUID()
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "doodleduo.supabase.session")
        defaults.set("  tester  ", forKey: "doodleduo.cachedDisplayName")
        defaults.set(userID.uuidString, forKey: "doodleduo.cachedDisplayNameUser")
        defer {
            defaults.removeObject(forKey: "doodleduo.cachedDisplayName")
            defaults.removeObject(forKey: "doodleduo.cachedDisplayNameUser")
        }
        let environment = SupabaseEnvironment(
            baseURL: URL(string: "https://example.invalid")!,
            anonKey: "anon"
        )
        let service = AuthService(environment: environment)
        #expect(service.cachedDisplayName(for: userID) == "tester")
    }

}
