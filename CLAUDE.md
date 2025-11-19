# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

DoodleDuo is a cozy couples/friendship app where shared doodles make a tiny world grow. It combines real-time collaborative drawing with a progression-based virtual farm that evolves based on relationship engagement.

**Core Concept:** A shared live whiteboard where every doodle generates "love energy" that powers a cozy farm filled with collectible animals, day/night cycles, and seasonal themes. The farm serves as a visual representation of the relationship's activity and streak.

**Key Features:**
- Real-time shared drawing canvas with pastel brushes and stickers
- Love energy system (every doodle/interaction generates points)
- Cozy farm that evolves with unlockable animals (chicken, sheep, pig, horse, cow, duck, goat, etc.)
- Streak system (normal + optional hardcore mode where animals fall asleep if streak breaks)
- Daily prompts for engagement ("Draw your partner as an animal", "Draw your mood")
- Dynamic backgrounds (day/night, seasonal themes, weather)
- Live widgets showing doodle preview, streak count, farm reactions
- Memory timeline (automatic relationship journal of doodles + farm milestones)

**Current Implementation Status:**
- ✅ Onboarding flow (splash → onboarding → welcome → interest survey → notifications → sign in)
- ✅ Supabase authentication (Apple Sign-In)
- ✅ Profile management and display names
- ✅ Couple pairing system with room codes
- ✅ Basic farm view with day/night cycle
- ✅ Love points and streak display (currently pseudo-metrics)
- ✅ Background audio manager
- ✅ Widget extension (LatestDoodleWidget) with shared data store
- ⚠️ **Missing:** Real-time drawing canvas, energy system, animal progression, daily prompts, realtime sync, timeline

## Build & Development Commands

Open project:
```bash
open doodleduo.xcodeproj
```

Clean build for iOS Simulator:
```bash
xcodebuild -scheme doodleduo -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' clean build
```

Run all tests (unit + UI):
```bash
xcodebuild test -scheme doodleduo -destination 'platform=iOS Simulator,name=iPhone 15'
```

Build widget extension:
```bash
xcodebuild -scheme LatestDoodleWidget -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' build
```

For development, use Xcode 15+ and run the app via the "Run" action with the Debug console visible for logging. The project contains two schemes: `doodleduo` (main app) and `LatestDoodleWidget` (widget extension).

## Architecture & Key Components

### Application Flow (ContentView.swift)
The root `ContentView` manages a state machine with these stages:
- `.splash` → `.onboarding` → `.welcome` → `.interest` → `.notifications` → `.signIn` → `.profileSetup` (if needed) → `.pairing` → `.main`

Key managers are initialized in `ContentView.init()` and passed down:
- `AuthService`: Handles Supabase authentication, session persistence, and profile management
- `CoupleSessionManager`: Manages duo room creation/joining, partner status, and room code generation
- `BackgroundAudioManager`: Controls background music playback

### Authentication Architecture (AuthService.swift)
- Uses Apple Sign-In via Supabase auth endpoints (`auth/v1`)
- Sessions are persisted to `UserDefaults` and restored on app launch
- Profile data (display names) are cached locally to avoid unnecessary API calls
- All operations are `@MainActor` and use async/await

Key methods:
- `signInWithApple(idToken:nonce:)`: Exchanges Apple credentials for Supabase session
- `refreshProfile()`: Re-fetches user profile from Supabase
- `updateDisplayName(_:)`: Updates profile display name via REST API

### Couple Pairing (CoupleSessionManager.swift)
- Creates or joins "duo rooms" identified by human-readable room codes
- Room codes are generated from a preferred name + attempt counter to ensure uniqueness
- State is cached in `UserDefaults` to persist across app restarts
- Partner names are fetched from the `profiles` table via `duo_memberships` joins

Status states: `.signedOut`, `.ready`, `.working(message:)`, `.paired(roomID:)`, `.error(message:)`

### Supabase Integration (SupabaseEnvironment.swift)
Configuration is loaded from `Info.plist` keys:
- `SUPABASE_URL`: Base URL for the Supabase project
- `SUPABASE_ANON_KEY`: Anonymous API key

The environment provides convenience URLs for auth, REST, and functions endpoints, plus header generation for authenticated requests.

### Database Schema
**Current tables** (in production via [supabase/schema.sql](supabase/schema.sql)):
- `profiles`: User profiles linked to `auth.users` via RLS policies
- `duo_rooms`: Couple rooms with unique `room_code` strings
- `duo_memberships`: Many-to-many join table linking profiles to rooms

**Planned tables** (in [supabase/migrations/001_add_core_features.sql](supabase/migrations/001_add_core_features.sql), not yet deployed):
- `doodles`: Stores drawing data as JSONB stroke arrays, thumbnails, prompt responses
- `duo_metrics`: Tracks love_energy, streaks, total_doodles, hardcore mode
- `duo_farms`: Farm progression with unlocked animals, farm level, theme
- `daily_prompts`: Prompt text, responses, completion tracking
- `timeline_events`: Automatic relationship journal entries

All tables use RLS; users can only access their own data or data from rooms they've joined.

## File Organization

- `doodleduo/`: Main app SwiftUI views and Swift source files
- `doodleduo/Models/`: Data models (currently only DuoMetrics.swift)
- `doodleduo/Assets.xcassets/`: Image assets (farm backgrounds, animal icons, app icon)
- `doodleduo/*.mp3`: Background music files (bgmusic1-5.mp3)
- `doodleduo/Info.plist`: App metadata and Supabase configuration keys
- `doodleduo/doodleduo.entitlements`: App capabilities (Sign in with Apple, App Groups)
- `LatestDoodleWidget/`: Home screen widget extension (shows latest doodle)
- `Shared/`: Code shared between main app and widget extension (DoodleWidgetStore.swift)
- `doodleduoTests/`: Unit test specs (currently minimal)
- `doodleduoUITests/`: UI automation tests (smoke + launch tests)
- `supabase/schema.sql`: Current production database schema
- `supabase/migrations/001_add_core_features.sql`: Planned schema expansion for MVP features

## Code Style & Standards

- Follow Swift API Design Guidelines: PascalCase for types/views, camelCase for members
- Indent with 4 spaces, keep lines ≤120 characters
- Prefer structs, immutable state, and SwiftUI modifiers ordered from high- to low-level (layout → styling → behaviors)
- Run "Editor → Structure → Re-Indent" before committing
- Treat warnings as build failures; resolve all warnings before pushing
- Localized strings use `NSLocalizedString` keys defined near their usage

## Testing

- Use XCTest framework
- Name test files `<Subject>Tests.swift` and methods `testScenario_Expectation`
- Unit tests (in `doodleduoTests/`) should isolate business logic
- UI tests (in `doodleduoUITests/`) verify happy-path interactions and launch scenarios
- Run `xcodebuild test` before every push
- New UI features require at least one assertion on the rendered view hierarchy

## Important Notes

### Supabase Configuration
The app requires `SUPABASE_URL` and `SUPABASE_ANON_KEY` in `Info.plist`. If missing, the app crashes on launch with a fatal error from `SupabaseEnvironment.makeCurrent()`.

### Pseudo-Metrics (Temporary Implementation)
**IMPORTANT:** The current farm view ([FarmHomeView.swift:111-117](doodleduo/FarmHomeView.swift#L111-L117)) uses hash-based pseudo-metrics:
- `affectionScore`: Derived from hashing duo member IDs (ranges 42-873)
- `streakScore`: Derived from similar hash logic (ranges 1-47)

These are **placeholder values** to demonstrate the UI while the database migration is pending. Once `duo_metrics` table is deployed:
1. Replace pseudo calculations with `sessionManager.metrics?.loveEnergy` and `sessionManager.metrics?.currentStreak`
2. Update `CoupleSessionManager` to fetch real metrics from Supabase
3. Remove the hash-based calculation functions

This allows the UI to be tested without backend dependencies but must be replaced before MVP launch.

### Apple Sign-In Setup
The app expects an Apple Client ID to be configured. Ensure entitlements in `doodleduo.entitlements` are properly set for Sign in with Apple.

### State Persistence
Both `AuthService` and `CoupleSessionManager` cache their state to `UserDefaults`:
- `doodleduo.supabase.session`: Auth session data
- `doodleduo.couple.session`: Duo room and partner info
- `doodleduo.cachedDisplayName` + `doodleduo.cachedDisplayNameUser`: Display name cache

When debugging login/pairing issues, clearing these keys may help.

### View Transitions
`ContentView` uses SwiftUI animations for stage transitions. When modifying navigation flow, ensure you use `withAnimation` blocks to maintain smooth UX.

### Widget Extension & App Groups
The app includes a widget extension (`LatestDoodleWidget`) that shares data with the main app via App Groups:
- App Group ID: `group.com.doodleduo.shared`
- Shared data store: `DoodleWidgetStore` (in `Shared/` directory)
- Widget refreshes every 30 minutes via timeline policy
- Main app calls `DoodleWidgetStore.shared.saveLatestDoodle()` to update widget
- Widget displays doodle preview, sender name, and timestamp

When adding drawing functionality, remember to call `DoodleWidgetStore.shared.saveLatestDoodle()` after saving a new doodle to keep the widget in sync.

## Commit Guidelines

- Use imperative mood: "Add feature" not "Added feature"
- Keep first line concise; add body for non-trivial changes
- Reference issues with `Fixes #ID` to auto-close
- Include simulator screenshots for UI-visible changes
- Mention new assets or `Info.plist` changes in PR descriptions for entitlement review

---

## Additional Documentation

For complete development guidance, see:

- **[SUMMARY.md](SUMMARY.md)** - Project status, what's built, what's next
- **[ROADMAP.md](ROADMAP.md)** - Complete 10-phase development plan with technical details
- **[MVP_QUICKSTART.md](MVP_QUICKSTART.md)** - Week-by-week implementation guide for MVP
- **[AGENTS.md](AGENTS.md)** - Original repository guidelines (code style, testing, commits)
- **[supabase/migrations/001_add_core_features.sql](supabase/migrations/001_add_core_features.sql)** - Database migration for core features
