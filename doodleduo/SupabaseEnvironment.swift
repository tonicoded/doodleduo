//
//  SupabaseEnvironment.swift
//  doodleduo
//
//  Created by Codex on 19/01/2025.
//

import Foundation

struct SupabaseEnvironment: Sendable {
    let baseURL: URL
    let anonKey: String
    
    static func makeCurrent() -> SupabaseEnvironment {
        guard
            let urlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let anonKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
            let url = URL(string: urlString),
            !anonKey.isEmpty
        else {
            fatalError("Add SUPABASE_URL and SUPABASE_ANON_KEY to Info.plist before running.")
        }
        return SupabaseEnvironment(baseURL: url, anonKey: anonKey)
    }
    
    var authURL: URL {
        baseURL.appendingPathComponent("auth/v1")
    }
    
    var restURL: URL {
        baseURL.appendingPathComponent("rest/v1")
    }
    
    var functionsURL: URL {
        baseURL.appendingPathComponent("functions/v1")
    }
    
    func url(appending path: String) -> URL {
        let trimmed = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !trimmed.isEmpty else { return baseURL }
        return trimmed
            .split(separator: "/")
            .reduce(baseURL) { partial, component in
                partial.appendingPathComponent(String(component))
            }
    }
    
    func headers(accessToken: String? = nil) -> [String: String] {
        var headers: [String: String] = [
            "apikey": anonKey,
            "Content-Type": "application/json"
        ]
        headers["Authorization"] = "Bearer \(accessToken ?? anonKey)"
        return headers
    }
}
