# DoodleDuo MVP Quick Start Guide

This guide walks you through implementing the **Minimum Viable Product** (MVP) to get DoodleDuo ready for first users.

**Estimated Time:** 4-6 weeks (solo developer)
**Goal:** Couples can draw together, earn points, unlock animals, and maintain streaks.

---

## Week 1: Database & Backend Setup

### Day 1-2: Database Migration

1. **Run the migration in Supabase:**
   ```bash
   # Navigate to your Supabase project dashboard
   # Go to SQL Editor
   # Paste contents of supabase/migrations/001_add_core_features.sql
   # Click "Run"
   ```

2. **Verify tables created:**
   - `doodles`
   - `duo_metrics`
   - `duo_farms`
   - `daily_prompts`
   - `timeline_events`

3. **Test initialization trigger:**
   ```sql
   -- Create a test room
   insert into duo_rooms (room_code, created_by)
   values ('TEST01', auth.uid());

   -- Check if metrics and farm were auto-created
   select * from duo_metrics where room_id = (select id from duo_rooms where room_code = 'TEST01');
   select * from duo_farms where room_id = (select id from duo_rooms where room_code = 'TEST01');
   ```

### Day 3-4: Swift Models

Create new file: `doodleduo/Models/DuoMetrics.swift`

```swift
import Foundation

struct DuoMetrics: Codable, Identifiable {
    let roomId: UUID
    var loveEnergy: Int
    var totalDoodles: Int
    var totalStrokes: Int
    var currentStreak: Int
    var longestStreak: Int
    var lastActivityDate: String? // ISO date string
    var lastActivityProfileId: UUID?
    var hardcoreMode: Bool
    let createdAt: Date
    let updatedAt: Date

    var id: UUID { roomId }

    enum CodingKeys: String, CodingKey {
        case roomId = "room_id"
        case loveEnergy = "love_energy"
        case totalDoodles = "total_doodles"
        case totalStrokes = "total_strokes"
        case currentStreak = "current_streak"
        case longestStreak = "longest_streak"
        case lastActivityDate = "last_activity_date"
        case lastActivityProfileId = "last_activity_profile_id"
        case hardcoreMode = "hardcore_mode"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct DuoFarm: Codable, Identifiable {
    let roomId: UUID
    var unlockedAnimals: [String]
    var farmLevel: Int
    var theme: String
    var animalsSleeping: Bool
    var lastUnlockAt: Date?
    let createdAt: Date
    let updatedAt: Date

    var id: UUID { roomId }

    enum CodingKeys: String, CodingKey {
        case roomId = "room_id"
        case unlockedAnimals = "unlocked_animals"
        case farmLevel = "farm_level"
        case theme
        case animalsSleeping = "animals_sleeping"
        case lastUnlockAt = "last_unlock_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
```

### Day 5-7: Fetch Real Data

Update `CoupleSessionManager.swift` to fetch metrics and farm:

```swift
@Published private(set) var metrics: DuoMetrics?
@Published private(set) var farm: DuoFarm?

func refreshMetrics() async throws {
    guard let roomID = cachedRoomCode else { return }

    // Fetch metrics
    let metricsURL = environment.restURL
        .appendingPathComponent("duo_metrics")
    var metricsRequest = URLRequest(url: metricsURL)
    metricsRequest.httpMethod = "GET"
    metricsRequest.allHTTPHeaderFields = environment.headers(accessToken: authService.session?.accessToken)
    metricsRequest.setValue("eq.\(roomID)", forHTTPHeaderField: "room_id")

    let (metricsData, _) = try await URLSession.shared.data(for: metricsRequest)
    let fetchedMetrics = try JSONDecoder().decode([DuoMetrics].self, from: metricsData).first

    // Fetch farm
    let farmURL = environment.restURL
        .appendingPathComponent("duo_farms")
    var farmRequest = URLRequest(url: farmURL)
    farmRequest.httpMethod = "GET"
    farmRequest.allHTTPHeaderFields = environment.headers(accessToken: authService.session?.accessToken)
    farmRequest.setValue("eq.\(roomID)", forHTTPHeaderField: "room_id")

    let (farmData, _) = try await URLSession.shared.data(for: farmRequest)
    let fetchedFarm = try JSONDecoder().decode([DuoFarm].self, from: farmData).first

    await MainActor.run {
        self.metrics = fetchedMetrics
        self.farm = fetchedFarm
    }
}
```

Call `refreshMetrics()` after successful pairing.

---

## Week 2: Drawing Canvas (Basic)

### Day 8-10: PencilKit Integration

1. **Add PencilKit to project** (already available in iOS)

2. **Create `DrawingCanvasView.swift`:**

```swift
import SwiftUI
import PencilKit

struct DrawingCanvasView: View {
    @StateObject private var viewModel: DrawingViewModel
    @Environment(\.dismiss) private var dismiss

    init(roomID: String, sessionManager: CoupleSessionManager) {
        _viewModel = StateObject(wrappedValue: DrawingViewModel(
            roomID: roomID,
            sessionManager: sessionManager
        ))
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            PKCanvasViewRepresentable(
                canvasView: $viewModel.canvasView,
                onDrawingChanged: viewModel.handleLocalDrawing
            )
            .ignoresSafeArea(edges: .bottom)

            VStack {
                HStack {
                    Button("Done") {
                        dismiss()
                    }
                    .padding()

                    Spacer()

                    Button("Clear") {
                        viewModel.clearCanvas()
                    }
                    .padding()
                }

                Spacer()

                // Color palette
                HStack(spacing: 12) {
                    ForEach(viewModel.colors, id: \.self) { color in
                        Circle()
                            .fill(color)
                            .frame(width: 40, height: 40)
                            .onTapGesture {
                                viewModel.selectColor(color)
                            }
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.bottom, 40)
            }
        }
        .task {
            await viewModel.startListening()
        }
    }
}

struct PKCanvasViewRepresentable: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    let onDrawingChanged: (PKDrawing) -> Void

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput
        canvasView.delegate = context.coordinator
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onDrawingChanged: onDrawingChanged)
    }

    class Coordinator: NSObject, PKCanvasViewDelegate {
        let onDrawingChanged: (PKDrawing) -> Void

        init(onDrawingChanged: @escaping (PKDrawing) -> Void) {
            self.onDrawingChanged = onDrawingChanged
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            onDrawingChanged(canvasView.drawing)
        }
    }
}
```

3. **Create `DrawingViewModel.swift`:**

```swift
import SwiftUI
import PencilKit
import Combine

@MainActor
final class DrawingViewModel: ObservableObject {
    @Published var canvasView = PKCanvasView()

    let colors: [Color] = [
        Color(red: 1.0, green: 0.7, blue: 0.8),    // pastel pink
        Color(red: 0.7, green: 0.9, blue: 1.0),    // pastel blue
        Color(red: 1.0, green: 0.9, blue: 0.7),    // pastel yellow
        Color(red: 0.8, green: 1.0, blue: 0.8),    // pastel green
        Color(red: 0.95, green: 0.8, blue: 1.0),   // pastel purple
    ]

    private let roomID: String
    private unowned let sessionManager: CoupleSessionManager
    private var syncTimer: Timer?
    private var pendingStrokes: [PKStroke] = []

    init(roomID: String, sessionManager: CoupleSessionManager) {
        self.roomID = roomID
        self.sessionManager = sessionManager
        setupCanvas()
    }

    private func setupCanvas() {
        let tool = PKInkingTool(.pen, color: UIColor(colors[0]), width: 5)
        canvasView.tool = tool
    }

    func selectColor(_ color: Color) {
        let uiColor = UIColor(color)
        let tool = PKInkingTool(.pen, color: uiColor, width: 5)
        canvasView.tool = tool
    }

    func clearCanvas() {
        canvasView.drawing = PKDrawing()
    }

    func handleLocalDrawing(_ drawing: PKDrawing) {
        // Award energy for drawing
        Task {
            await awardEnergyForDrawing()
        }

        // TODO: Sync to Supabase (implement in Week 3)
    }

    func startListening() async {
        // TODO: Subscribe to Supabase realtime (implement in Week 3)
    }

    private func awardEnergyForDrawing() async {
        // Increment stroke count and energy
        // Call Supabase function to update metrics
    }
}
```

### Day 11-14: Add Drawing Tab

Update `MainTabView.swift`:

```swift
enum Tab {
    case home
    case doodle  // NEW
    case settings
}

var body: some View {
    TabView(selection: $selection) {
        FarmHomeView(sessionManager: sessionManager)
            .tabItem {
                Label("home", systemImage: "house.fill")
            }
            .tag(Tab.home)

        // NEW DOODLE TAB
        if let roomID = sessionManager.roomID {
            DrawingCanvasView(roomID: roomID, sessionManager: sessionManager)
                .tabItem {
                    Label("doodle", systemImage: "pencil.and.scribble")
                }
                .tag(Tab.doodle)
        }

        SettingsTabView(authService: authService, sessionManager: sessionManager, audioManager: audioManager)
            .tabItem {
                Label("settings", systemImage: "paintpalette")
            }
            .tag(Tab.settings)
    }
    // ... rest
}
```

---

## Week 3: Energy System

### Day 15-17: Energy Manager

Create `EnergyManager.swift`:

```swift
import Foundation

@MainActor
final class EnergyManager: ObservableObject {
    private let environment: SupabaseEnvironment
    private unowned let sessionManager: CoupleSessionManager

    init(environment: SupabaseEnvironment = .makeCurrent(), sessionManager: CoupleSessionManager) {
        self.environment = environment
        self.sessionManager = sessionManager
    }

    // Award energy for actions
    func awardEnergy(amount: Int, reason: String) async throws {
        guard let roomID = sessionManager.cachedDuoID else { return }

        // Increment love_energy in duo_metrics
        let url = environment.restURL
            .appendingPathComponent("duo_metrics")
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.allHTTPHeaderFields = environment.headers(accessToken: sessionManager.authService.session?.accessToken)
        request.setValue("eq.\(roomID.uuidString)", forHTTPHeaderField: "room_id")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")

        let payload: [String: Any] = [
            "love_energy": "duo_metrics.love_energy + \(amount)" // PostgreSQL expression
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, _) = try await URLSession.shared.data(for: request)
        let updated = try JSONDecoder().decode([DuoMetrics].self, from: data).first

        // Update local state
        sessionManager.metrics = updated

        // Create timeline event
        try await createTimelineEvent(
            roomID: roomID,
            type: "milestone",
            data: ["message": "+\(amount) energy: \(reason)", "icon": "sparkles"]
        )
    }

    private func createTimelineEvent(roomID: UUID, type: String, data: [String: Any]) async throws {
        // Insert into timeline_events
        // ... implementation
    }
}
```

### Day 18-21: Hook Up Energy Awards

In `DrawingViewModel.swift`:

```swift
private var energyManager: EnergyManager!

init(roomID: String, sessionManager: CoupleSessionManager) {
    // ...
    self.energyManager = EnergyManager(sessionManager: sessionManager)
}

func handleLocalDrawing(_ drawing: PKDrawing) {
    Task {
        // Award 1 energy per stroke (max 50 per session)
        if pendingStrokes.count < 50 {
            try? await energyManager.awardEnergy(amount: 1, reason: "drawing")
        }
    }
}
```

---

## Week 4: Animal Unlocks & Streak

### Day 22-24: Animal Unlock Logic

Create `FarmManager.swift`:

```swift
import Foundation

struct AnimalUnlock {
    let name: String
    let energyCost: Int
    let icon: String

    static let unlocks: [AnimalUnlock] = [
        AnimalUnlock(name: "chicken", energyCost: 0, icon: "chicken"),    // starter
        AnimalUnlock(name: "sheep", energyCost: 100, icon: "sheep"),
        AnimalUnlock(name: "pig", energyCost: 200, icon: "pig"),
        AnimalUnlock(name: "horse", energyCost: 350, icon: "horse"),
    ]
}

@MainActor
final class FarmManager: ObservableObject {
    private let environment: SupabaseEnvironment
    private unowned let sessionManager: CoupleSessionManager

    init(environment: SupabaseEnvironment = .makeCurrent(), sessionManager: CoupleSessionManager) {
        self.environment = environment
        self.sessionManager = sessionManager
    }

    func canUnlock(animal: String) -> Bool {
        guard let farm = sessionManager.farm,
              let metrics = sessionManager.metrics else { return false }

        guard !farm.unlockedAnimals.contains(animal) else { return false }

        guard let unlock = AnimalUnlock.unlocks.first(where: { $0.name == animal }) else { return false }

        return metrics.loveEnergy >= unlock.energyCost
    }

    func unlockAnimal(_ animal: String) async throws {
        guard canUnlock(animal: animal) else {
            throw FarmError.insufficientEnergy
        }

        guard let roomID = sessionManager.cachedDuoID else { return }

        // Add to unlocked_animals array
        var updatedAnimals = sessionManager.farm?.unlockedAnimals ?? []
        updatedAnimals.append(animal)

        // Update duo_farms
        // ... Supabase PATCH request

        // Create timeline event
        // ... "animal_unlock" event

        // Refresh farm state
        try await sessionManager.refreshMetrics()
    }
}

enum FarmError: Error {
    case insufficientEnergy
}
```

### Day 25-28: Update FarmHomeView with Real Data

Update `FarmHomeView.swift`:

```swift
// Replace pseudo-metrics with:
private var affectionScore: Int {
    sessionManager.metrics?.loveEnergy ?? 0
}

private var streakScore: Int {
    sessionManager.metrics?.currentStreak ?? 0
}

// Add animal layers
@ViewBuilder
private func animalLayers() -> some View {
    if let farm = sessionManager.farm {
        ForEach(farm.unlockedAnimals, id: \.self) { animal in
            AnimalView(name: animal, isSleeping: farm.animalsSleeping)
        }
    }
}
```

Create `AnimalView.swift`:

```swift
import SwiftUI

struct AnimalView: View {
    let name: String
    let isSleeping: Bool

    var body: some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .frame(width: 80, height: 80)
            .opacity(isSleeping ? 0.5 : 1.0)
            .overlay(alignment: .topTrailing) {
                if isSleeping {
                    Text("💤")
                        .font(.caption)
                }
            }
            .scaleEffect(isSleeping ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isSleeping)
    }
}
```

---

## Week 5: Streak System

### Day 29-31: Streak Calculator

Create `StreakCalculator.swift`:

```swift
import Foundation

struct StreakCalculator {
    static func shouldUpdateStreak(lastActivityDate: String?, currentDate: Date = Date()) -> Bool {
        guard let lastDateString = lastActivityDate else { return true }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]

        guard let lastDate = formatter.date(from: lastDateString) else { return true }

        let calendar = Calendar.autoupdatingCurrent
        let daysSince = calendar.dateComponents([.day], from: lastDate, to: currentDate).day ?? 0

        return daysSince >= 1
    }

    static func updateStreak(metrics: DuoMetrics, activityDate: Date = Date()) async throws -> DuoMetrics {
        // Call Supabase function update_streak_for_room
        // Returns updated metrics
    }
}
```

### Day 32-35: Hook Up Streak Updates

In `EnergyManager.swift`:

```swift
func awardEnergy(amount: Int, reason: String) async throws {
    // ... existing code

    // Check if streak should update
    if StreakCalculator.shouldUpdateStreak(lastActivityDate: sessionManager.metrics?.lastActivityDate) {
        let updated = try await StreakCalculator.updateStreak(metrics: sessionManager.metrics!)
        sessionManager.metrics = updated
    }
}
```

---

## Week 6: Testing & Polish

### Day 36-38: Two-Device Testing

1. **Setup:**
   - Install on two physical devices (or simulator + device)
   - Create account on Device A
   - Create duo room
   - Join room from Device B

2. **Test Cases:**
   - ✅ Both see same farm state
   - ✅ Drawing on A updates metrics visible on B
   - ✅ Energy increments correctly
   - ✅ Unlock animal (verify both see new animal)
   - ✅ Maintain streak for 3 days
   - ✅ Break streak (hardcore mode) → animals sleep

### Day 39-42: Bug Fixes & Polish

- [ ] Loading states (show spinner while fetching)
- [ ] Error handling (show alerts on failures)
- [ ] Offline mode (cache last known state)
- [ ] Animations (animal unlock celebration)
- [ ] Sounds (optional: unlock sound, streak milestone sound)
- [ ] Accessibility (VoiceOver labels)

---

## MVP Checklist

Before calling it "done," verify:

- [x] Database schema deployed
- [ ] Real metrics displayed in FarmHomeView
- [ ] Drawing canvas functional (smooth, no lag)
- [ ] Energy awarded for drawing
- [ ] 4 animals unlockable (chicken, sheep, pig, horse)
- [ ] Streak increments daily
- [ ] Hardcore mode works (animals sleep on broken streak)
- [ ] Two devices can see each other's changes (within 5 seconds)
- [ ] No crashes or critical bugs
- [ ] Code follows existing style (AGENTS.md guidelines)

---

## After MVP: Next Steps

Once MVP is stable:

1. **Week 7:** Daily prompts (Phase 4 from ROADMAP.md)
2. **Week 8:** Timeline view (Phase 6)
3. **Week 9:** Notifications (Phase 8)
4. **Week 10:** Widgets (Phase 5)
5. **Week 11-12:** App Store prep + beta testing

---

## Need Help?

**Common Issues:**

1. **"Metrics not updating"**
   - Check Supabase RLS policies (use Policy Editor)
   - Verify access token is valid
   - Check network requests in Xcode console

2. **"Animals not appearing"**
   - Verify `unlocked_animals` JSONB format: `["chicken", "sheep"]`
   - Check image asset names match exactly

3. **"Drawing too slow"**
   - Reduce sync frequency (currently 500ms)
   - Simplify stroke data before sending

**Resources:**
- Supabase Docs: https://supabase.com/docs/guides/realtime
- PencilKit Guide: https://developer.apple.com/documentation/pencilkit
- SwiftUI Animations: https://developer.apple.com/tutorials/swiftui

---

**Good luck building! 🚀**
