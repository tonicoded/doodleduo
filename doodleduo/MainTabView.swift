//
//  MainTabView.swift
//  doodleduo
//
//  Created by Anthony Verruijt on 16/11/2025.
//

import SwiftUI
import Combine
import UIKit

// MARK: - Photo Manager

@MainActor
class PhotoManager: ObservableObject {
    @Published private(set) var userProfilePhoto: UIImage?
    @Published private(set) var partnerProfilePhoto: UIImage?
    
    static let shared = PhotoManager()
    
    private let environment = SupabaseEnvironment.makeCurrent()
    private let storageBucket = "profile-photos"
    private let storageFolder = "profile_photos"
    private var authService: AuthService?
    private var sessionManager: CoupleSessionManager?
    private var cancellables = Set<AnyCancellable>()
    private var lastLoadedUserPhotoURL: String?
    private var lastLoadedPartnerPhotoURL: String?
    
    private init() {
        loadPhotos()
    }
    
    func configure(authService: AuthService, sessionManager: CoupleSessionManager) {
        let needsSubscriptionRefresh = self.authService !== authService || self.sessionManager !== sessionManager
        self.authService = authService
        self.sessionManager = sessionManager
        
        if needsSubscriptionRefresh {
            cancellables.removeAll()
            
            sessionManager.$partnerProfileID
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    Task { await self?.refreshPartnerPhoto() }
                }
                .store(in: &cancellables)
            
            authService.$isSignedIn
                .receive(on: RunLoop.main)
                .sink { [weak self] signedIn in
                    guard let self = self else { return }
                    if signedIn {
                        Task {
                            await self.refreshUserPhoto()
                            await self.refreshPartnerPhoto()
                        }
                    } else {
                        self.clearPhotos()
                    }
                }
                .store(in: &cancellables)
        }
        
        Task {
            await refreshUserPhoto()
            await refreshPartnerPhoto()
        }
    }
    
    func setUserPhoto(_ image: UIImage?) {
        userProfilePhoto = image
        savePhotos()
        
        Task {
            await uploadUserPhotoToDatabase(image)
        }
    }
    
    func setPartnerPhoto(_ image: UIImage?) {
        partnerProfilePhoto = image
        savePhotos()
    }
    
    func refreshPartnerPhoto() async {
        await loadPartnerPhotoFromDatabase()
    }
    
    func refreshUserPhoto() async {
        await loadCurrentUserPhotoFromDatabase()
    }
    
    private func savePhotos() {
        if let userPhoto = userProfilePhoto,
           let data = userPhoto.jpegData(compressionQuality: 0.8) {
            UserDefaults.standard.set(data, forKey: "userProfilePhoto")
        } else {
            UserDefaults.standard.removeObject(forKey: "userProfilePhoto")
        }
        
        if let partnerPhoto = partnerProfilePhoto,
           let data = partnerPhoto.jpegData(compressionQuality: 0.8) {
            UserDefaults.standard.set(data, forKey: "partnerProfilePhoto")
        } else {
            UserDefaults.standard.removeObject(forKey: "partnerProfilePhoto")
        }
    }
    
    private func clearPhotos() {
        userProfilePhoto = nil
        partnerProfilePhoto = nil
        lastLoadedUserPhotoURL = nil
        lastLoadedPartnerPhotoURL = nil
        savePhotos()
    }
    
    private func loadPhotos() {
        if let userData = UserDefaults.standard.data(forKey: "userProfilePhoto"),
           let userImage = UIImage(data: userData) {
            userProfilePhoto = userImage
        }
        
        if let partnerData = UserDefaults.standard.data(forKey: "partnerProfilePhoto"),
           let partnerImage = UIImage(data: partnerData) {
            partnerProfilePhoto = partnerImage
        }
    }
    
    private func uploadUserPhotoToDatabase(_ image: UIImage?) async {
        guard let authService = authService,
              let session = authService.session,
              let userID = authService.currentUser?.id else { return }
        
        let objectPath = makeObjectPath(for: userID)
        if let image,
           let imageData = image.jpegData(compressionQuality: 0.85) {
            do {
                try await uploadImageData(imageData, to: objectPath, session: session)
                let publicURL = makePublicURL(for: objectPath, cacheBustToken: UUID().uuidString)
                try await updateProfilePhotoInDatabase(publicURL, userID: userID, session: session)
                lastLoadedUserPhotoURL = publicURL
            } catch {
                print("⚠️ Storage upload failed, falling back to inline photo:", error)
                await storeInlinePhotoData(imageData, userID: userID, session: session)
            }
        } else {
            await removeRemotePhoto(objectPath: objectPath, userID: userID, session: session)
        }
    }
    
    private func storeInlinePhotoData(_ data: Data, userID: UUID, session: AuthSession) async {
        do {
            let inlineURL = makeInlineDataURL(from: data)
            try await updateProfilePhotoInDatabase(inlineURL, userID: userID, session: session)
            lastLoadedUserPhotoURL = inlineURL
        } catch {
            print("❌ Failed to sync profile photo:", error)
        }
    }
    
    private func removeRemotePhoto(objectPath: String, userID: UUID, session: AuthSession) async {
        do {
            try await deleteImage(at: objectPath, session: session)
        } catch {
            // Bucket may not exist or user lacks rights; ignore cleanup failure
        }
        do {
            try await updateProfilePhotoInDatabase(nil, userID: userID, session: session)
            lastLoadedUserPhotoURL = nil
        } catch {
            print("❌ Failed to sync profile photo:", error)
        }
    }
    
    private func loadPartnerPhotoFromDatabase() async {
        guard let authService = authService,
              let session = authService.session,
              let partnerID = sessionManager?.partnerProfileID else { return }
        
        do {
            let remoteURL = try await fetchPhotoURL(for: partnerID, session: session)
            try await applyRemotePhoto(urlString: remoteURL, isCurrentUser: false)
        } catch {
            print("❌ Failed to load partner photo:", error)
        }
    }
    
    private func loadCurrentUserPhotoFromDatabase() async {
        guard let authService = authService,
              let session = authService.session,
              let userID = authService.currentUser?.id else { return }
        
        do {
            let remoteURL = try await fetchPhotoURL(for: userID, session: session)
            try await applyRemotePhoto(urlString: remoteURL, isCurrentUser: true)
        } catch {
            print("❌ Failed to load user photo:", error)
        }
    }
    
    private func applyRemotePhoto(urlString: String?, isCurrentUser: Bool) async throws {
        guard let urlString = urlString, !urlString.isEmpty else {
            if isCurrentUser {
                userProfilePhoto = nil
                lastLoadedUserPhotoURL = nil
            } else {
                partnerProfilePhoto = nil
                lastLoadedPartnerPhotoURL = nil
            }
            savePhotos()
            return
        }
        
        if isCurrentUser {
            guard urlString != lastLoadedUserPhotoURL else { return }
        } else {
            guard urlString != lastLoadedPartnerPhotoURL else { return }
        }
        
        if let inlineImage = inlineImage(from: urlString) {
            if isCurrentUser {
                userProfilePhoto = inlineImage
                lastLoadedUserPhotoURL = urlString
            } else {
                partnerProfilePhoto = inlineImage
                lastLoadedPartnerPhotoURL = urlString
            }
            savePhotos()
            return
        }
        
        let image = try await downloadImage(from: urlString)
        if isCurrentUser {
            userProfilePhoto = image
            lastLoadedUserPhotoURL = urlString
        } else {
            partnerProfilePhoto = image
            lastLoadedPartnerPhotoURL = urlString
        }
        savePhotos()
    }
    
    private func fetchPhotoURL(for profileID: UUID, session: AuthSession) async throws -> String? {
        var components = URLComponents(
            url: environment.restURL.appendingPathComponent("profiles"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "id", value: "eq.\(profileID.uuidString)"),
            URLQueryItem(name: "select", value: "profile_photo_url"),
            URLQueryItem(name: "limit", value: "1")
        ]
        guard let url = components?.url else {
            throw PhotoSyncError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = environment.headers(accessToken: session.accessToken)
        let data = try await data(for: request)
        let rows = try JSONDecoder().decode([ProfilePhotoRow].self, from: data)
        return rows.first?.profilePhotoURL
    }
    
    private func updateProfilePhotoInDatabase(_ urlString: String?, userID: UUID, session: AuthSession) async throws {
        var components = URLComponents(
            url: environment.restURL.appendingPathComponent("profiles"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "id", value: "eq.\(userID.uuidString)")
        ]
        guard let url = components?.url else {
            throw PhotoSyncError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        var headers = environment.headers(accessToken: session.accessToken)
        headers["Prefer"] = "return=minimal"
        request.allHTTPHeaderFields = headers
        request.httpBody = try JSONEncoder().encode(ProfilePhotoUpdate(profilePhotoURL: urlString))
        _ = try await data(for: request)
    }
    
    private func uploadImageData(_ payload: Data, to path: String, session: AuthSession) async throws {
        var request = URLRequest(url: storageObjectURL(for: path))
        request.httpMethod = "POST"
        var headers = environment.headers(accessToken: session.accessToken)
        headers["Content-Type"] = "image/jpeg"
        headers["x-upsert"] = "true"
        request.allHTTPHeaderFields = headers
        request.httpBody = payload
        _ = try await data(for: request)
    }
    
    private func deleteImage(at path: String, session: AuthSession) async throws {
        var request = URLRequest(url: storageRemoveURL)
        request.httpMethod = "POST"
        var headers = environment.headers(accessToken: session.accessToken)
        headers["Content-Type"] = "application/json"
        request.allHTTPHeaderFields = headers
        let payload = RemovePayload(bucketId: storageBucket, objects: [RemoveObject(name: path)])
        request.httpBody = try JSONEncoder().encode(payload)
        _ = try await data(for: request)
    }
    
    private func downloadImage(from urlString: String) async throws -> UIImage {
        guard let url = URL(string: urlString) else {
            throw PhotoSyncError.invalidURL
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw PhotoSyncError.invalidResponse
        }
        guard let image = UIImage(data: data) else {
            throw PhotoSyncError.imageDecodeFailed
        }
        return image
    }
    
    private func data(for request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw PhotoSyncError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "no body"
            throw PhotoSyncError.httpError(status: http.statusCode, body: body)
        }
        return data
    }
    
    private func makeObjectPath(for profileID: UUID) -> String {
        "\(storageFolder)/\(profileID.uuidString).jpg"
    }
    
    private func storageObjectURL(for path: String, isPublic: Bool = false) -> URL {
        var url = environment.baseURL
        url.appendPathComponent("storage")
        url.appendPathComponent("v1")
        url.appendPathComponent("object")
        if isPublic {
            url.appendPathComponent("public")
        }
        url.appendPathComponent(storageBucket)
        for component in path.split(separator: "/") {
            url.appendPathComponent(String(component))
        }
        return url
    }
    
    private var storageRemoveURL: URL {
        var url = environment.baseURL
        url.appendPathComponent("storage")
        url.appendPathComponent("v1")
        url.appendPathComponent("object")
        url.appendPathComponent("remove")
        return url
    }
    
    private func makePublicURL(for path: String, cacheBustToken: String? = nil) -> String {
        let baseURL = storageObjectURL(for: path, isPublic: true)
        guard let cacheBustToken else {
            return baseURL.absoluteString
        }
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "v", value: cacheBustToken)]
        return components?.url?.absoluteString ?? baseURL.absoluteString
    }
    
    private func makeInlineDataURL(from data: Data) -> String {
        "data:image/jpeg;base64,\(data.base64EncodedString())"
    }
    
    private func inlineImage(from dataURL: String) -> UIImage? {
        guard dataURL.hasPrefix("data:image"),
              let commaIndex = dataURL.firstIndex(of: ",") else {
            return nil
        }
        let base64String = String(dataURL[dataURL.index(after: commaIndex)...])
        guard let data = Data(base64Encoded: base64String) else {
            return nil
        }
        return UIImage(data: data)
    }
    
    private struct ProfilePhotoRow: Decodable {
        let profilePhotoURL: String?
        
        enum CodingKeys: String, CodingKey {
            case profilePhotoURL = "profile_photo_url"
        }
    }
    
    private struct ProfilePhotoUpdate: Encodable {
        let profilePhotoURL: String?
        
        enum CodingKeys: String, CodingKey {
            case profilePhotoURL = "profile_photo_url"
        }
    }
    
    private struct RemovePayload: Encodable {
        let bucketId: String
        let objects: [RemoveObject]
    }
    
    private struct RemoveObject: Encodable {
        let name: String
    }
    
    private enum PhotoSyncError: Error {
        case invalidURL
        case invalidResponse
        case httpError(status: Int, body: String)
        case imageDecodeFailed
    }
}

struct MainTabView: View {
    @ObservedObject var authService: AuthService
    @ObservedObject var sessionManager: CoupleSessionManager
    @ObservedObject var audioManager: BackgroundAudioManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var selection: Tab = .home
    @State private var refreshLoopTask: Task<Void, Never>?
    
    var body: some View {
        TabView(selection: $selection) {
            FarmHomeView(sessionManager: sessionManager)
                .tabItem {
                    Label("home", systemImage: "house.fill")
                }
                .tag(Tab.home)
            
            ActivityView(sessionManager: sessionManager, authService: authService)
                .tabItem {
                    Label("activity", systemImage: "heart.fill")
                }
                .tag(Tab.activity)
            
            SettingsTabView(authService: authService, sessionManager: sessionManager, audioManager: audioManager)
                .tabItem {
                    Label("settings", systemImage: "paintpalette")
                }
                .tag(Tab.settings)
        }
        .tint(CozyPalette.accentTint(for: colorScheme))
        .background(CozyPalette.background(for: colorScheme).ignoresSafeArea())
        .task {
            PhotoManager.shared.configure(authService: authService, sessionManager: sessionManager)
            await sessionManager.refreshPartnerStatus()
            do {
                try await sessionManager.refreshMetrics()
                print("✅ Metrics loaded:", sessionManager.metrics as Any)
                print("✅ Farm loaded:", sessionManager.farm as Any)
            } catch {
                print("❌ Error loading metrics:", error)
            }
            startGlobalRefreshLoop()
        }
        .onDisappear {
            refreshLoopTask?.cancel()
            refreshLoopTask = nil
        }
    }
    
    enum Tab {
        case home
        case activity
        case settings
    }
    
    private func startGlobalRefreshLoop() {
        guard refreshLoopTask == nil else { return }
        refreshLoopTask = Task {
            while !Task.isCancelled {
                await sessionManager.refreshPartnerStatus()
                do {
                    try await sessionManager.refreshMetrics()
                } catch {
                    // swallow background refresh errors
                }
                try? await Task.sleep(nanoseconds: 10 * 1_000_000_000)
            }
        }
    }
}

private struct SettingsTabView: View {
    @ObservedObject var authService: AuthService
    @ObservedObject var sessionManager: CoupleSessionManager
    @ObservedObject var audioManager: BackgroundAudioManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var isEditingName = false
    @ObservedObject private var photoManager = PhotoManager.shared
    @State private var showingImagePicker = false
    
    private var partnerLine: String {
        friendlyName(from: sessionManager.partnerName) ?? "waiting for partner to join"
    }
    
    private var userLine: String {
        friendlyName(from: sessionManager.myDisplayName) ??
        friendlyName(from: authService.profile?.displayName) ??
        authService.currentUser.flatMap { friendlyName(from: authService.cachedDisplayName(for: $0.id)) } ??
        friendlyName(from: authService.currentUser?.email) ??
        "signed in friend"
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    profileCard
                    duoCard
                    soundCard
                    dangerCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
            .background(CozyPalette.background(for: colorScheme).ignoresSafeArea())
            .navigationTitle("settings")
        }
        .sheet(isPresented: $isEditingName) {
            DisplayNamePromptView(authService: authService) {
                isEditingName = false
                Task { await sessionManager.refreshPartnerStatus() }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            SettingsImagePicker { image in
                photoManager.setUserPhoto(image)
            }
        }
    }
    
    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("your profile")
                .font(.headline)
            HStack(spacing: 16) {
                profilePhotoView
                VStack(alignment: .leading, spacing: 6) {
                    Text(userLine)
                        .font(.title3.weight(.semibold))
                    Text("This photo appears in your shared activity feed.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if photoManager.userProfilePhoto != nil {
                        Button("Remove photo", role: .destructive) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                photoManager.setUserPhoto(nil)
                            }
                        }
                        .buttonStyle(.plain)
                        .font(.footnote)
                        .foregroundColor(.red)
                    }
                }
                Spacer()
            }
            Button {
                isEditingName = true
            } label: {
                Label("Edit display name", systemImage: "pencil")
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule().fill(CozyPalette.cardBackground(for: colorScheme).opacity(0.65))
            )
            .overlay(
                Capsule().stroke(Color.primary.opacity(0.05), lineWidth: 1)
            )
            .foregroundColor(.primary)
        }
        .padding(20)
        .background(cardBackground)
    }
    
    private var duoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("your duo")
                .font(.headline)
            infoRow(label: "Room ID", value: sessionManager.roomID ?? "not set")
            infoRow(label: "Partner", value: partnerLine, muted: sessionManager.partnerName == nil)
            infoRow(label: "You", value: userLine, muted: true)
            if let code = sessionManager.roomID {
                HStack {
                    Text("Share code with your partner")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Copy") {
                        UIPasteboard.general.string = code
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(20)
        .background(cardBackground)
    }
    
    private var soundCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("sound & presence")
                .font(.headline)
            Button {
                audioManager.toggleMute()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: audioManager.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    VStack(alignment: .leading, spacing: 2) {
                        Text(audioManager.isMuted ? "Sound muted" : "Sound on")
                            .fontWeight(.semibold)
                        Text("tap to toggle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(CozyPalette.cardBackground(for: colorScheme))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                        )
                )
                .foregroundColor(.primary)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(cardBackground)
    }
    
    private var dangerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("account")
                .font(.headline)
            Button(role: .destructive) {
                authService.signOut()
            } label: {
                Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(CozyPalette.dangerRed)
        }
        .padding(20)
        .background(cardBackground)
    }
    
    private var profilePhotoView: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(colorScheme == .dark ? 0.35 : 0.18), lineWidth: 1)
                )
            profilePhotoContent
                .frame(width: 88, height: 88)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
        }
        .frame(width: 96, height: 96)
        .overlay(alignment: .bottomTrailing) {
            Button {
                showingImagePicker = true
            } label: {
                Image(systemName: "camera.fill")
                    .font(.caption.weight(.bold))
                    .padding(6)
                    .background(
                        Circle()
                            .fill(CozyPalette.cardBackground(for: colorScheme))
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
            .offset(x: 6, y: 6)
        }
    }
    
    @ViewBuilder
    private var profilePhotoContent: some View {
        if let photo = photoManager.userProfilePhoto {
            Image(uiImage: photo)
                .resizable()
                .scaledToFill()
        } else {
            DefaultAvatarPlaceholder(initials: initials(from: userLine))
        }
    }
    
    private func infoRow(label: String, value: String, muted: Bool = false) -> some View {
        HStack {
            Text(label.uppercased())
                .font(.caption2)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.body.weight(.medium))
                .foregroundColor(muted ? .secondary : .primary)
        }
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(CozyPalette.cardBackground(for: colorScheme))
            .shadow(color: .black.opacity(0.04), radius: 12, y: 6)
    }
    
    private func initials(from text: String) -> String {
        let words = text.split(whereSeparator: { $0.isWhitespace })
        let letters = words.prefix(2).compactMap { $0.first }
        if !letters.isEmpty {
            return letters.map { String($0) }.joined().uppercased()
        }
        if let first = text.trimmingCharacters(in: .whitespacesAndNewlines).first {
            return String(first).uppercased()
        }
        return "?"
    }
    
    private func friendlyName(from raw: String?) -> String? {
        guard let value = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        if let at = value.firstIndex(of: "@") {
            let prefix = value[..<at]
            if !prefix.isEmpty {
                return String(prefix)
            }
        }
        return value
    }
}

private struct DefaultAvatarPlaceholder: View {
    let initials: String
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    CozyPalette.secondaryAccent.opacity(0.95),
                    CozyPalette.accent.opacity(0.85)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(
                AngularGradient(
                    gradient: Gradient(colors: [.white.opacity(0.05), .clear, .white.opacity(0.08)]),
                    center: .center,
                    angle: .degrees(250)
                )
            )
            Text(initials)
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 3)
                .minimumScaleFactor(0.5)
        }
    }
}

// MARK: - Settings Image Picker

struct SettingsImagePicker: UIViewControllerRepresentable {
    let onImageSelected: (UIImage?) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: SettingsImagePicker
        
        init(_ parent: SettingsImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let editedImage = info[.editedImage] as? UIImage {
                parent.onImageSelected(editedImage)
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.onImageSelected(originalImage)
            }
            
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
