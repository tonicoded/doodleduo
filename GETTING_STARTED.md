# Getting Started with DoodleDuo Development

Welcome! This guide will get you up and running quickly.

---

## 📚 Documentation Overview

DoodleDuo has comprehensive documentation organized by purpose:

### Start Here
1. **[SUMMARY.md](SUMMARY.md)** 👈 **READ THIS FIRST**
   - What's already built
   - Current state of the project
   - Quick technical overview

### Development Planning
2. **[MVP_QUICKSTART.md](MVP_QUICKSTART.md)** - Hands-on 6-week implementation guide
3. **[ROADMAP.md](ROADMAP.md)** - Complete feature roadmap (MVP → V2.0)
4. **[AGENTS.md](AGENTS.md)** - Code style, testing, commit guidelines

### Reference
5. **[CLAUDE.md](CLAUDE.md)** - Architecture deep-dive, build commands
6. **[supabase/migrations/001_add_core_features.sql](supabase/migrations/001_add_core_features.sql)** - Database schema

---

## 🚀 Quick Start (5 Minutes)

### 1. Open the Project
```bash
cd /Users/anthonyverruijt/Downloads/doodleduo
open doodleduo.xcodeproj
```

### 2. Build & Run
- Select "iPhone 15" simulator (or any iOS 17+ device)
- Press `Cmd+R` or click the Play button
- Wait for build (~30 seconds)

### 3. Test the App
The app will launch and show:
- **Splash screen** (2 seconds)
- **Onboarding** → tap through slides
- **Welcome** → tap "I'm ready"
- **Interest survey** → select options
- **Notifications** → tap "Allow" or "Later"
- **Sign In** → tap "Sign in with Apple" (or "Continue without signing in")
- **Pairing** → tap "Create a Room" or "Join a Room"
- **Farm View** → see day/night background with stats

---

## 🎯 Your First Task: See Real Data

Currently, the farm shows **fake metrics** (pseudo-random numbers). Let's fix that!

### Step 1: Deploy Database Migration

1. Go to [Supabase Dashboard](https://app.supabase.com)
2. Select project: `reevrasmalgiftakwsao`
3. Navigate to **SQL Editor**
4. Click **New Query**
5. Open `supabase/migrations/001_add_core_features.sql` in a text editor
6. Copy the entire file contents
7. Paste into Supabase SQL Editor
8. Click **Run** (bottom right)
9. Verify success (should see "Success. No rows returned")

### Step 2: Verify Tables Created

In Supabase, go to **Table Editor**. You should see new tables:
- ✅ `doodles`
- ✅ `duo_metrics`
- ✅ `duo_farms`
- ✅ `daily_prompts`
- ✅ `timeline_events`

### Step 3: Create Swift Models

Create new file: `doodleduo/Models/DuoMetrics.swift`

```swift
import Foundation

struct DuoMetrics: Codable, Identifiable {
    let roomId: UUID
    var loveEnergy: Int
    var totalDoodles: Int
    var currentStreak: Int
    var longestStreak: Int
    var lastActivityDate: String?
    var hardcoreMode: Bool
    let createdAt: Date
    let updatedAt: Date

    var id: UUID { roomId }

    enum CodingKeys: String, CodingKey {
        case roomId = "room_id"
        case loveEnergy = "love_energy"
        case totalDoodles = "total_doodles"
        case currentStreak = "current_streak"
        case longestStreak = "longest_streak"
        case lastActivityDate = "last_activity_date"
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
    let createdAt: Date
    let updatedAt: Date

    var id: UUID { roomId }

    enum CodingKeys: String, CodingKey {
        case roomId = "room_id"
        case unlockedAnimals = "unlocked_animals"
        case farmLevel = "farm_level"
        case theme
        case animalsSleeping = "animals_sleeping"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
```

### Step 4: Update CoupleSessionManager

Open [CoupleSessionManager.swift](doodleduo/CoupleSessionManager.swift) and add:

```swift
// Add to published properties (around line 23)
@Published private(set) var metrics: DuoMetrics?
@Published private(set) var farm: DuoFarm?

// Add new method
func refreshMetrics() async throws {
    guard let roomID = cachedDuoID else { return }

    // Fetch metrics
    var metricsURL = URLComponents(url: environment.restURL.appendingPathComponent("duo_metrics"), resolvingAgainstBaseURL: false)!
    metricsURL.queryItems = [URLQueryItem(name: "room_id", value: "eq.\(roomID.uuidString)")]

    var metricsRequest = URLRequest(url: metricsURL.url!)
    metricsRequest.httpMethod = "GET"
    metricsRequest.allHTTPHeaderFields = environment.headers(accessToken: authService.session?.accessToken)

    let (metricsData, _) = try await URLSession.shared.data(for: metricsRequest)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let fetchedMetrics = try decoder.decode([DuoMetrics].self, from: metricsData).first

    // Fetch farm
    var farmURL = URLComponents(url: environment.restURL.appendingPathComponent("duo_farms"), resolvingAgainstBaseURL: false)!
    farmURL.queryItems = [URLQueryItem(name: "room_id", value: "eq.\(roomID.uuidString)")]

    var farmRequest = URLRequest(url: farmURL.url!)
    farmRequest.httpMethod = "GET"
    farmRequest.allHTTPHeaderFields = environment.headers(accessToken: authService.session?.accessToken)

    let (farmData, _) = try await URLSession.shared.data(for: farmRequest)
    let fetchedFarm = try decoder.decode([DuoFarm].self, from: farmData).first

    await MainActor.run {
        self.metrics = fetchedMetrics
        self.farm = fetchedFarm
    }
}
```

### Step 5: Update FarmHomeView

Open [FarmHomeView.swift](doodleduo/FarmHomeView.swift) and replace:

```swift
// REPLACE lines 111-117 with:
private var affectionScore: Int {
    sessionManager.metrics?.loveEnergy ?? 0
}

private var streakScore: Int {
    sessionManager.metrics?.currentStreak ?? 0
}
```

### Step 6: Call refreshMetrics

In [MainTabView.swift](doodleduo/MainTabView.swift), update the `.task` block (around line 33):

```swift
.task {
    await sessionManager.refreshPartnerStatus()
    try? await sessionManager.refreshMetrics()  // ADD THIS
}
```

### Step 7: Test It!

1. Build and run (`Cmd+R`)
2. Create a new room or join existing
3. You should now see:
   - **Love Points: 0** (real data from `duo_metrics.love_energy`)
   - **Streak: 0** (real data from `duo_metrics.current_streak`)

🎉 **Congratulations!** You're now reading real data from Supabase!

---

## 🛠️ Development Workflow

### Daily Workflow
```bash
# 1. Open project
open doodleduo.xcodeproj

# 2. Build and test
xcodebuild test -scheme doodleduo -destination 'platform=iOS Simulator,name=iPhone 15'

# 3. Run app
# Press Cmd+R in Xcode

# 4. Make changes
# Edit Swift files, test in simulator

# 5. Commit when done
git add .
git commit -m "Add feature X"
```

### When Adding New Features
1. Check [ROADMAP.md](ROADMAP.md) for architecture
2. Follow [MVP_QUICKSTART.md](MVP_QUICKSTART.md) for step-by-step
3. Test on real device (not just simulator)
4. Update [SUMMARY.md](SUMMARY.md) checklist when complete

### When Stuck
1. Check [CLAUDE.md](CLAUDE.md) for architecture details
2. Read [AGENTS.md](AGENTS.md) for code style
3. Review existing code in similar files
4. Ask Claude Code for help!

---

## 📁 Project Structure

```
doodleduo/
├── doodleduo/                      # Main source code
│   ├── doodleduoApp.swift         # App entry point
│   ├── ContentView.swift          # Root state machine
│   ├── MainTabView.swift          # Tab navigation (home, doodle, settings)
│   │
│   ├── Views/                     # UI Components
│   │   ├── FarmHomeView.swift    # Main farm screen
│   │   ├── WelcomeView.swift     # Onboarding
│   │   ├── CouplePairingView.swift
│   │   └── ...
│   │
│   ├── Services/                  # Business logic (to be created)
│   │   ├── AuthService.swift     # Already exists (root level)
│   │   ├── CoupleSessionManager.swift  # Already exists
│   │   └── EnergyManager.swift   # To be created
│   │
│   ├── Models/                    # Data structures (to be created)
│   │   ├── DuoMetrics.swift      # You just created this!
│   │   └── DrawingStroke.swift   # Future
│   │
│   ├── Assets.xcassets/          # Images, colors
│   ├── Info.plist                # Supabase config
│   └── *.mp3                     # Background music
│
├── doodleduoTests/               # Unit tests
├── doodleduoUITests/             # UI automation tests
├── supabase/                     # Backend
│   ├── schema.sql               # Original schema
│   └── migrations/
│       └── 001_add_core_features.sql  # New tables
│
└── Documentation/
    ├── CLAUDE.md                 # Architecture reference
    ├── ROADMAP.md               # Feature roadmap
    ├── MVP_QUICKSTART.md        # Implementation guide
    ├── SUMMARY.md               # Project status
    ├── AGENTS.md                # Code guidelines
    └── GETTING_STARTED.md       # This file!
```

---

## 🎨 Key Features to Implement Next

### Priority 1: Drawing Canvas (Week 2)
- [ ] Add PencilKit integration
- [ ] Create "Doodle" tab
- [ ] Implement color palette (5 pastel colors)
- [ ] Test local drawing (no sync yet)

**Why first?** This is the core feature. Everything else depends on having a working canvas.

### Priority 2: Energy System (Week 3)
- [ ] Create `EnergyManager.swift`
- [ ] Award +1 energy per drawing stroke
- [ ] Update `duo_metrics` table
- [ ] Show energy increasing in real-time

**Why second?** Makes drawing feel rewarding. Builds the progression loop.

### Priority 3: Animal Unlocks (Week 4)
- [ ] Create `FarmManager.swift`
- [ ] Define unlock thresholds (chicken: 0, sheep: 100, pig: 200, horse: 350)
- [ ] Add "Unlock" button when threshold reached
- [ ] Display animals as PNG layers on farm

**Why third?** Tangible reward for earning energy. Completes the core loop.

### Priority 4: Streak System (Week 5)
- [ ] Create `StreakCalculator.swift`
- [ ] Call `update_streak_for_room` Supabase function
- [ ] Increment streak daily
- [ ] Implement hardcore mode (animals sleep on break)

**Why fourth?** Drives daily retention. Makes app habit-forming.

---

## 🧪 Testing Checklist

Before considering a feature "done":

- [ ] Builds without errors or warnings
- [ ] Runs on iPhone simulator (iOS 17+)
- [ ] Runs on real device (if available)
- [ ] No crashes during normal use (5+ min test)
- [ ] Network errors handled gracefully
- [ ] Loading states shown (not blank screens)
- [ ] Animations smooth (60 fps)
- [ ] Follows code style (4 spaces, ≤120 chars)
- [ ] Updated relevant documentation

---

## 🆘 Common Issues

### "Xcode can't find Supabase types"
- ✅ Make sure you created `Models/DuoMetrics.swift`
- ✅ Check that file is added to target (File Inspector → Target Membership)

### "App crashes on launch"
- ✅ Check Info.plist has `SUPABASE_URL` and `SUPABASE_ANON_KEY`
- ✅ Look at crash log in Xcode console

### "Farm shows 0 for everything"
- ✅ Verify you ran the database migration
- ✅ Check `duo_metrics` table exists in Supabase
- ✅ Ensure you called `refreshMetrics()` in MainTabView

### "Simulator is slow"
- ✅ Restart simulator (Device → Erase All Content and Settings)
- ✅ Reduce animation scale (Settings → Accessibility → Motion)
- ✅ Use "iPhone 15" not "iPhone 15 Pro Max" (less pixels)

---

## 🎓 Learning Resources

### SwiftUI
- [Apple's SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)
- [Hacking with Swift](https://www.hackingwithswift.com/quick-start/swiftui)

### Supabase
- [Supabase Swift Client](https://github.com/supabase/supabase-swift)
- [Realtime Docs](https://supabase.com/docs/guides/realtime)
- [Row Level Security](https://supabase.com/docs/guides/auth/row-level-security)

### PencilKit (for drawing)
- [Apple's PencilKit Docs](https://developer.apple.com/documentation/pencilkit)
- [WWDC 2019: Introducing PencilKit](https://developer.apple.com/videos/play/wwdc2019/221/)

---

## 🚢 Ship It!

### When MVP is Ready
1. **TestFlight Beta** (Week 6)
   - Add testers in App Store Connect
   - Upload build via Xcode Archive
   - Gather feedback

2. **App Store Submission** (Week 8)
   - Prepare screenshots (6.7", 6.5", 5.5")
   - Write app description
   - Submit for review
   - Wait 1-3 days

3. **Launch!** 🎉
   - Tweet announcement
   - Post on Product Hunt
   - Share TikTok/Instagram content
   - Monitor reviews

---

## 💬 Questions?

If you're stuck, Claude Code can help! Just ask:
- "How do I implement X?"
- "Why is Y not working?"
- "Show me an example of Z"
- "Review my code for bugs"

**Happy coding!** 🚀✨

---

**Next Steps:**
1. Read [SUMMARY.md](SUMMARY.md) to understand current state
2. Follow [MVP_QUICKSTART.md](MVP_QUICKSTART.md) for week-by-week tasks
3. Build your first feature (drawing canvas!)
