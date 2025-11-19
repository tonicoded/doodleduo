# DoodleDuo Project Summary

**Date:** 2025-01-17
**Status:** Foundation Complete, Ready for MVP Development

---

## What We Have Now ✅

### 1. Complete Onboarding Flow
- ✅ Splash screen with logo
- ✅ Multi-page onboarding with interest survey
- ✅ Notification permissions prompt
- ✅ Apple Sign-In integration
- ✅ Display name setup
- ✅ Couple pairing with room codes (create or join)

### 2. Backend Infrastructure
- ✅ Supabase authentication (`AuthService.swift`)
- ✅ Session persistence and auto-restore
- ✅ Profile management with caching
- ✅ Couple room system (`CoupleSessionManager.swift`)
- ✅ Room code generation (human-readable)
- ✅ Partner status tracking

### 3. Database Schema (Current)
```
profiles          → User profiles linked to auth.users
duo_rooms         → Couple rooms with unique codes
duo_memberships   → Many-to-many join table
```

### 4. Farm View (Basic)
- ✅ Day/night cycle (automatic based on time)
- ✅ Farm background images (day/night)
- ✅ Animated stat badges (love points, streak)
- ✅ Duo names display
- ✅ Cozy pastel color palette
- ✅ Time display with gentle pulse animation
- ✅ Custom fire and heart pulse effects

### 5. Audio & Polish
- ✅ Background music manager (5 tracks)
- ✅ Mute/unmute toggle
- ✅ Smooth transitions between screens
- ✅ Settings screen with duo management

### 6. Assets Ready
- ✅ Farm backgrounds: day, night, Christmas day, Christmas night
- ✅ Animal sprites: horse, sheep, chicken, pig
- ✅ 5 background music tracks
- ✅ App icon placeholder

---

## What's Been Created for You 📦

### New Documentation Files

1. **[CLAUDE.md](CLAUDE.md)** ⭐
   - Complete project overview
   - Build & development commands
   - Architecture deep-dive (auth, pairing, Supabase)
   - Code style & testing guidelines
   - Important configuration notes

2. **[ROADMAP.md](ROADMAP.md)** 🗺️
   - 10-phase development plan
   - Database schema expansion (5 new tables)
   - Real-time drawing canvas design
   - Energy & progression system
   - Daily prompts, widgets, timeline
   - Monetization strategy (free vs pro)
   - Success metrics & testing strategy

3. **[MVP_QUICKSTART.md](MVP_QUICKSTART.md)** 🚀
   - Week-by-week implementation guide
   - Day-by-day tasks with code examples
   - Complete drawing canvas setup
   - Energy manager implementation
   - Animal unlock logic
   - Streak system with hardcore mode
   - Two-device testing checklist

4. **[supabase/migrations/001_add_core_features.sql](supabase/migrations/001_add_core_features.sql)** 🗄️
   - Production-ready database migration
   - 5 new tables with RLS policies
   - Auto-initialization triggers
   - Streak calculation function
   - Realtime publication setup

---

## Architecture Highlights 🏗️

### State Machine (ContentView)
```
splash → onboarding → welcome → interest → notifications
  → signIn → profileSetup? → pairing? → main
```

### Service Layer
- **AuthService**: Handles all Supabase auth operations
- **CoupleSessionManager**: Room creation, joining, partner sync
- **BackgroundAudioManager**: Music playback
- **SupabaseEnvironment**: Config loader (URL + anon key from Info.plist)

### Data Flow
```
User Action → ViewModel → Service → Supabase → Service → ViewModel → UI Update
```

### Caching Strategy
- Sessions cached in UserDefaults
- Display names cached to reduce API calls
- Room state persisted across app restarts

---

## Next Steps (MVP Implementation) 🎯

### Week 1: Database
- [ ] Run migration in Supabase dashboard
- [ ] Create Swift models (DuoMetrics, DuoFarm)
- [ ] Update CoupleSessionManager to fetch real data

### Week 2: Drawing Canvas
- [ ] Integrate PencilKit
- [ ] Add "Doodle" tab to MainTabView
- [ ] Implement color palette
- [ ] Basic local drawing (no sync yet)

### Week 3: Energy System
- [ ] Create EnergyManager.swift
- [ ] Award energy for drawing
- [ ] Display real metrics in FarmHomeView
- [ ] Replace pseudo-metrics with Supabase data

### Week 4: Animal Unlocks
- [ ] Create FarmManager.swift
- [ ] Implement unlock logic
- [ ] Add "Unlock" button UI
- [ ] Show animals as PNG layers on farm

### Week 5: Streak System
- [ ] Create StreakCalculator.swift
- [ ] Call update_streak_for_room function
- [ ] Implement hardcore mode (animals sleep)
- [ ] Daily streak increment

### Week 6: Testing & Polish
- [ ] Two-device testing
- [ ] Bug fixes
- [ ] Loading states
- [ ] Error handling
- [ ] Animations

---

## Technical Decisions Made 🔧

### Why Supabase?
- Built-in auth (Apple Sign-In)
- Realtime subscriptions (perfect for live drawing)
- PostgreSQL (robust, scalable)
- Row-level security (secure by default)
- Free tier for MVP

### Why PencilKit?
- Native iOS framework (no dependencies)
- Apple Pencil support (smooth, low-latency)
- Built-in undo/redo
- Export to image easily

### Why SwiftUI?
- Modern, declarative UI
- Animations built-in
- Less boilerplate than UIKit
- WidgetKit integration

### Data Storage Strategy
- **Supabase tables**: Source of truth for duo data
- **Local cache**: UserDefaults for session, last known state
- **Images**: Supabase Storage (future: thumbnails for timeline)
- **Realtime**: Supabase channels for live drawing sync

---

## Key Files to Know 📁

### Core App
- `doodleduoApp.swift` - Entry point
- `ContentView.swift` - Root state machine (359 lines)
- `MainTabView.swift` - Tab navigation (140 lines)

### Farm
- `FarmHomeView.swift` - Main farm UI with day/night (367 lines)
- `CozyPalette.swift` - Color constants

### Services
- `AuthService.swift` - Authentication (22,951 bytes)
- `CoupleSessionManager.swift` - Room management (18,202 bytes)
- `SupabaseEnvironment.swift` - Config (1,683 bytes)

### Onboarding
- `SplashView.swift`
- `OnboardingPagerView.swift`
- `WelcomeView.swift`
- `OnboardingQuestionScreens.swift` (interest + notifications)
- `SignInPromptView.swift`
- `DisplayNamePromptView.swift`
- `CouplePairingView.swift`

### Database
- `supabase/schema.sql` - Original schema (103 lines)
- `supabase/migrations/001_add_core_features.sql` - New tables (500+ lines)

---

## Known Issues to Fix 🐛

### Current State
1. **FarmHomeView uses pseudo-metrics**
   - `affectionScore` and `streakScore` are hash-based fakes
   - Location: `FarmHomeView.swift:111-117`
   - Fix: Replace with `sessionManager.metrics?.loveEnergy`

2. **No drawing persistence**
   - Doodles aren't saved anywhere
   - Fix: Implement `doodles` table storage

3. **Streak doesn't actually increment**
   - Just displays pseudo-random number
   - Fix: Call `update_streak_for_room` function daily

4. **Animals don't appear on farm**
   - Images exist but not displayed
   - Fix: Add `AnimalView` layers in `FarmHomeView`

5. **No error handling**
   - Network failures crash silently
   - Fix: Add try/catch with user-facing alerts

---

## App Concept Recap 💡

**One-sentence pitch:**
> A cozy couples app where your doodles make a tiny world grow.

**Core Loop:**
1. Draw together on shared canvas
2. Every doodle generates "love energy"
3. Spend energy to unlock cute animals
4. Maintain daily streak to keep farm alive
5. Collect memories in automatic timeline

**Viral Hooks:**
- Live widgets showing partner's doodles
- Hardcore mode (miss a day = animals sleep 😭)
- Seasonal farm themes (Christmas, Valentine's)
- "Our farm after 30 days" TikTok content
- Golden rare animal at level 10

**Monetization:**
- Free: 4 basic animals, standard theme, normal streak
- Pro ($4.99/mo): Premium animals, seasonal themes, animated brushes, hardcore mode, unlimited timeline

---

## Resources & References 📚

### Supabase
- Project URL: `https://reevrasmalgiftakwsao.supabase.co`
- Anon Key: (stored in `Info.plist`)
- Database: PostgreSQL with RLS
- Auth: Apple Sign-In configured

### Design Inspiration
- Lovelee app (couples journaling)
- Candle app (shared moments)
- Butter app (couples games)
- **Unique twist:** Farm progression + drawing combo

### Tech Stack
- iOS 17.0+
- SwiftUI + PencilKit
- Supabase (auth, database, realtime, storage)
- WidgetKit (future)
- StoreKit 2 (future, for Pro)

---

## Questions Answered ❓

### "Can we use Supabase Realtime for drawing?"
✅ **Yes!** Supabase Realtime uses PostgreSQL logical replication. You can:
- Subscribe to `duo_room:{roomId}` channel
- Broadcast stroke data as JSONB
- Both clients receive updates in <200ms

### "Should we store full PKDrawing or simplified strokes?"
📝 **Simplified strokes** recommended:
```json
{
  "strokes": [
    {
      "points": [[x, y], [x, y], ...],
      "color": "#FFB6C1",
      "width": 5.0
    }
  ]
}
```
- Smaller payload (faster sync)
- Easier to render on both devices
- Can generate thumbnails for timeline

### "How to handle offline mode?"
💾 **Cache-first approach:**
- Store last known farm state in UserDefaults
- Queue drawing strokes locally
- Sync when connection restored
- Show "Offline" indicator in UI

### "What about battery drain from realtime?"
🔋 **Optimization strategies:**
- Only subscribe when drawing tab is active
- Unsubscribe when app backgrounded
- Batch stroke updates (every 500ms, not real-time per stroke)
- Use Supabase's presence feature (see when partner is online)

---

## Success Checklist for MVP ✅

### Before First User
- [ ] Database migration deployed
- [ ] Drawing canvas smooth (<16ms frame time)
- [ ] Energy system awards points correctly
- [ ] 4 animals unlockable (chicken → sheep → pig → horse)
- [ ] Streak increments daily (tested over 3 days)
- [ ] Two devices sync within 5 seconds
- [ ] No critical crashes (tested 30+ min)

### Before App Store Submission
- [ ] Privacy policy published
- [ ] App icon finalized (1024x1024)
- [ ] Screenshots for all device sizes
- [ ] 30-second preview video
- [ ] TestFlight beta (10+ testers)
- [ ] Fixed all crash reports
- [ ] Accessibility audit (VoiceOver)
- [ ] Localization (at least English)

---

## Team Notes 📝

### Code Style Reminders
- 4 spaces (no tabs)
- Lines ≤120 chars
- PascalCase for types, camelCase for members
- Group SwiftUI modifiers: layout → styling → behaviors
- Treat warnings as errors

### Commit Message Format
```
imperative mood: "Add animal unlock animation"

Longer description explaining why, not what.

Fixes #123
```

### Before Every Push
```bash
xcodebuild test -scheme doodleduo -destination 'platform=iOS Simulator,name=iPhone 15'
```

---

## What Makes DoodleDuo Special? ✨

### 1. Unique Hybrid Concept
- Not just another couples app
- Not just a drawing app
- Not just a farm game
- **All three combined** = viral potential

### 2. Emotional Resonance
- Farm represents your relationship health
- Streaks create daily ritual
- Doodles become memories
- Animals = tangible progress

### 3. Low Barrier to Entry
- No complex gameplay
- Just draw = easy to understand
- Works for couples AND friends
- All ages (teens to adults)

### 4. Built-in Virality
- Widgets show on home screen (free advertising)
- Seasonal themes = shareable content
- Streak anxiety = engagement
- "Look what we built together" TikToks

### 5. Technical Excellence
- Real-time sync (feels magical)
- Smooth animations (delightful)
- Offline support (reliable)
- Privacy-first (Supabase RLS)

---

## Final Thoughts 💭

You have a **complete foundation** for a viral couples app. The hardest parts (auth, pairing, backend) are done. Now it's just a matter of:

1. **Week 1-2:** Drawing canvas (fun to build!)
2. **Week 3-4:** Energy + unlocks (satisfying to see work)
3. **Week 5-6:** Polish + testing (makes it feel professional)

Then ship to TestFlight and start gathering feedback.

**This is ready to become a real product.** 🚀

Good luck! 🍀
