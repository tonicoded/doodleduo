# DoodleDuo Development Roadmap

This document outlines the complete development plan to transform DoodleDuo from its current foundation into the full viral couples app concept.

## Current State ✅

### Infrastructure (Complete)
- ✅ SwiftUI project structure with Xcode 15+
- ✅ Supabase backend integration (`SupabaseEnvironment.swift`)
- ✅ Apple Sign-In authentication flow (`AuthService.swift`)
- ✅ Session persistence and profile caching
- ✅ Couple pairing system with room codes (`CoupleSessionManager.swift`)
- ✅ Background audio system (`BackgroundAudioManager.swift`)

### UI/UX (Complete)
- ✅ Complete onboarding flow (7 stages)
- ✅ Cozy color palette (`CozyPalette.swift`)
- ✅ Basic farm view with day/night cycle (`FarmHomeView.swift`)
- ✅ Animated stat badges (love points, streak)
- ✅ Farm background images (day/night)
- ✅ Animal assets (horse, sheep, chicken, pig)
- ✅ Settings screen with duo management

### Database Schema (Complete)
- ✅ `profiles` table (user profiles linked to auth.users)
- ✅ `duo_rooms` table (couple rooms with unique codes)
- ✅ `duo_memberships` table (many-to-many join)

---

## Phase 1: Database & Backend Foundation 🔨

### 1.1 Expand Database Schema

**New Tables Required:**

```sql
-- Doodle storage
create table public.doodles (
    id uuid primary key default gen_random_uuid(),
    room_id uuid not null references public.duo_rooms(id) on delete cascade,
    author_id uuid not null references public.profiles(id) on delete cascade,
    drawing_data jsonb not null, -- strokes, colors, timestamps
    thumbnail_url text, -- optional preview image
    created_at timestamptz not null default timezone('utc', now())
);

-- Energy/points tracking
create table public.duo_metrics (
    room_id uuid primary key references public.duo_rooms(id) on delete cascade,
    love_energy int not null default 0,
    total_doodles int not null default 0,
    current_streak int not null default 0,
    longest_streak int not null default 0,
    last_activity_date date,
    hardcore_mode boolean not null default false,
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now())
);

-- Farm progression
create table public.duo_farms (
    room_id uuid primary key references public.duo_rooms(id) on delete cascade,
    unlocked_animals jsonb not null default '[]', -- ["chicken", "sheep", "pig"]
    farm_level int not null default 1,
    theme text not null default 'default', -- 'default', 'christmas', 'valentine'
    animals_sleeping boolean not null default false, -- for hardcore mode
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now())
);

-- Daily prompts completion
create table public.daily_prompts (
    id uuid primary key default gen_random_uuid(),
    room_id uuid not null references public.duo_rooms(id) on delete cascade,
    prompt_text text not null,
    prompt_date date not null,
    completed_by uuid[] not null default '{}', -- array of profile_ids
    doodle_id uuid references public.doodles(id) on delete set null,
    created_at timestamptz not null default timezone('utc', now()),
    unique(room_id, prompt_date)
);

-- Memory timeline entries
create table public.timeline_events (
    id uuid primary key default gen_random_uuid(),
    room_id uuid not null references public.duo_rooms(id) on delete cascade,
    event_type text not null, -- 'doodle', 'milestone', 'animal_unlock', 'streak'
    event_data jsonb not null,
    event_date timestamptz not null default timezone('utc', now())
);
```

**RLS Policies:** All tables need policies allowing room members to read/write their duo's data.

**Files to Create:**
- `supabase/migrations/001_add_core_features.sql`

### 1.2 Supabase Realtime Setup

**Channels Required:**
- `duo_room:{roomId}` - Real-time drawing sync
- `duo_metrics:{roomId}` - Energy/streak updates
- `duo_farm:{roomId}` - Animal unlocks, farm changes

**Implementation:**
- Add Supabase Realtime Swift client to project
- Create `RealtimeService.swift` for managing channels
- Subscribe/unsubscribe on room join/leave

---

## Phase 2: Core Drawing Canvas 🎨

### 2.1 Drawing Infrastructure

**New Files to Create:**

1. **`DrawingCanvas.swift`**
   - PKCanvasView wrapper for SwiftUI
   - Real-time stroke broadcasting via Supabase
   - Pastel color palette
   - Brush size controls
   - Undo/redo support

2. **`DrawingStroke.swift`**
   - Codable stroke model
   - Conversion to/from PKDrawing
   - JSON serialization for Supabase

3. **`DrawingViewModel.swift`**
   - `@MainActor` observable object
   - Manages local + remote strokes
   - Debounced sync to reduce bandwidth
   - Stroke history management

**TabView Update:**
Add "Doodle" tab to `MainTabView.swift`:
```swift
enum Tab {
    case home
    case doodle  // NEW
    case settings
}
```

### 2.2 Drawing Features

**MVP Features:**
- ✏️ Multi-touch drawing
- 🎨 5-7 pastel colors
- 🖌️ 3 brush sizes (thin, medium, thick)
- ↩️ Undo/redo (last 20 strokes)
- 🗑️ Clear canvas
- 💾 Auto-save every 10 seconds

**Future Features (v2):**
- Sticker library
- Text tool
- Shape tools (heart, star, circle)
- Layers
- Export as image

### 2.3 Real-time Sync Strategy

**Approach:**
- Local drawing updates instantly (no lag)
- Broadcast strokes in batches every 500ms
- Receive remote strokes and merge into canvas
- Conflict resolution: last-write-wins with timestamps

**Bandwidth Optimization:**
- Send simplified stroke data (not full PKDrawing)
- Compress long strokes (sample points)
- Thumbnail generation for timeline (not full drawing)

---

## Phase 3: Energy & Progression System ⚡

### 3.1 Love Energy Manager

**New File:** `EnergyManager.swift`

**Energy Sources:**
| Action | Energy Gained |
|--------|---------------|
| Draw stroke | +1 per stroke (max 50/session) |
| Send heart reaction | +3 |
| Complete daily prompt | +10 |
| Partner joins room | +5 |
| Doodle together (both active) | +2 bonus/min |

**Energy Sinks:**
| Use | Energy Cost |
|-----|-------------|
| Unlock chicken | 50 |
| Unlock sheep | 100 |
| Unlock pig | 200 |
| Unlock horse | 350 |
| Unlock cow | 500 |
| Unlock duck + pond | 750 |
| Unlock goat | 1000 |
| Farm expansion | 300 |

**Implementation:**
- Listen to drawing events
- Update `duo_metrics` table
- Emit events for UI updates
- Persist locally + sync to Supabase

### 3.2 Streak System

**Update:** `CoupleSessionManager.swift`

**Streak Logic:**
- Both partners must interact daily to maintain streak
- Interaction = draw, react, or complete prompt
- Reset at midnight user's timezone
- Store `last_activity_date` in `duo_metrics`

**Hardcore Mode:**
- Optional toggle in settings
- Missing a day → streak resets to 0
- All animals "fall asleep" for 24 hours (show sleeping animation)
- Must perform activity to "wake" farm

**New Files:**
- `StreakCalculator.swift` - Date math and validation
- `StreakBadgeView.swift` - Enhanced streak display with fire animation

### 3.3 Farm Progression

**Update:** `FarmHomeView.swift`

**Changes:**
- Read from `duo_farms` table instead of pseudo-metrics
- Display unlocked animals as PNG layers
- Add "Unlock Next" button when energy threshold reached
- Show animal unlock animation (fade-in + bounce)

**New Files:**
- `FarmState.swift` - Model for farm configuration
- `AnimalLayer.swift` - SwiftUI view for each animal
- `FarmManager.swift` - Business logic for unlocks

**Animal Behaviors:**
- Idle: gentle bobbing/breathing animation
- Active: when partner is drawing (sparkles appear)
- Sleeping: when hardcore streak broken (closed eyes, "zzz")

---

## Phase 4: Daily Prompts 📝

### 4.1 Prompt System

**New Files:**
1. **`DailyPromptService.swift`**
   - Fetch/generate daily prompt
   - Check completion status
   - Mark as completed when doodle submitted

2. **`PromptLibrary.swift`**
   - 100+ prompts categorized:
     - Romantic: "Draw your favorite memory together"
     - Playful: "Draw your partner as an animal"
     - Reflective: "Draw how you're feeling today"
     - Quick: "Draw a heart"

3. **`DailyPromptView.swift`**
   - Card showing today's prompt
   - "Complete" button → opens drawing canvas
   - Completion status (checkmark when done)

**Integration:**
- Show in `FarmHomeView` as floating card
- Notification reminder at 8pm if not completed
- Bonus energy for completion (+10)

### 4.2 Prompt Completion Flow

1. User taps prompt card
2. Opens drawing canvas with prompt overlay
3. After drawing, tap "Submit"
4. Saves doodle with `prompt_id` reference
5. Updates `daily_prompts.completed_by` array
6. Awards energy + timeline event
7. Shows celebration animation

---

## Phase 5: Live Widgets 📱

### 5.1 Widget Implementation

**Widget Types:**

1. **Small Widget (2x2)**
   - Shows current streak number
   - Tiny farm preview (just background + 1 animal)
   - Updates every 15 min

2. **Medium Widget (4x2)**
   - Streak + love points
   - Last doodle thumbnail
   - Partner's name
   - "Draw together" button (deep link)

3. **Large Widget (4x4)**
   - Full farm preview
   - All unlocked animals
   - Streak + energy stats
   - Today's prompt

**New Files:**
- `DoodleDuoWidget/` folder
- `WidgetView.swift`
- `WidgetProvider.swift`
- `WidgetBundle.swift`

**Data Sharing:**
- Use App Groups for shared UserDefaults
- Cache farm state, last doodle thumbnail
- Update on significant events

### 5.2 Live Activities (iOS 16.1+)

**Use Case:** "Partner is drawing now!"
- Show live update when partner opens canvas
- Display "Join them" button
- Auto-dismiss after 5 min of inactivity

---

## Phase 6: Memory Timeline 📸

### 6.1 Timeline View

**New File:** `TimelineView.swift`

**Display:**
- Chronological list of events
- Infinite scroll (paginated)
- Event types:
  - 🎨 Doodle posted (thumbnail)
  - 🐾 Animal unlocked (icon + name)
  - 🔥 Streak milestone (5, 10, 30, 50, 100 days)
  - 💝 Daily prompt completed
  - ⭐ Farm level up

**Event Card Design:**
- Date/time stamp
- Icon/thumbnail
- Brief description
- Tap to expand (show full doodle or details)

### 6.2 Timeline Storage

**Implementation:**
- Auto-create `timeline_events` on key actions
- Store in Supabase + cache locally
- Fetch 20 events at a time
- Search/filter by date or type

---

## Phase 7: Enhanced Farm Experience 🌾

### 7.1 Seasonal Themes

**Themes to Add:**
- 🎄 Christmas (have assets already)
- 💝 Valentine's Day
- 🌸 Spring
- 🎃 Halloween

**Implementation:**
- Store `theme` in `duo_farms` table
- Auto-switch based on date (or manual toggle in Pro)
- Swap background images
- Add themed decorations (PNG overlays)

**New Assets Needed:**
- Valentine farm backgrounds (day/night)
- Spring farm backgrounds
- Halloween farm backgrounds
- Themed decorations (trees, fences, signs)

### 7.2 Weather System

**Dynamic Weather (reacts to doodles):**
- Draw sun → sunny weather (brighter)
- Draw rain → light rain animation
- Draw stars → night sparkles
- Draw flowers → plants bloom

**Implementation:**
- Detect keywords in drawing metadata
- Apply temporary visual effects (5-10 min)
- Particle effects (rain drops, stars)

### 7.3 Animal Interactions

**Tap Behaviors:**
- Tap chicken → lays egg + clucking sound
- Tap sheep → jumps + "baa" sound
- Tap horse → gallops across screen
- Tap pig → rolls in mud

**Rare Golden Animal (Level 10):**
- Special unlock at farm level 10
- Animated sprite with sparkles
- Grants bonus energy (+50% multiplier)

---

## Phase 8: Notifications & Engagement 🔔

### 8.1 Notification Types

1. **Streak Reminder**
   - 8pm daily if no activity yet
   - "Don't break your X-day streak!"

2. **Partner Activity**
   - "Your partner just drew something!"
   - Deep link to doodle view

3. **Daily Prompt**
   - 9am: "Today's prompt: [text]"

4. **Milestone**
   - "You unlocked a new animal!"
   - "10-day streak achieved!"

**Implementation:**
- `NotificationManager.swift`
- Request permission in onboarding
- Schedule local notifications
- Supabase triggers for partner events

---

## Phase 9: Premium Features 💎

### 9.1 Free vs Pro

**Free Tier:**
- Basic farm (default theme)
- 4 starter animals (chicken, sheep, pig, horse)
- Standard brushes (5 colors, 3 sizes)
- Normal streak mode
- 30 days timeline history

**Pro Tier ($4.99–$6.99/month):**
- All premium animals (cow, duck, goat, alpaca, fox, panda, bunny, dragon)
- All seasonal themes
- Animated brushes (glitter, rainbow, neon)
- 50+ premium stickers
- Hardcore streak mode
- Unlimited timeline
- Farm expansion (2x space)
- Custom farm decorations
- Golden animal skins
- Export doodles as high-res images
- No "Unlock" wait times

### 9.2 In-App Purchase Setup

**Files:**
- `StoreManager.swift` - StoreKit 2 integration
- `PaywallView.swift` - Premium upsell screen
- Product IDs in App Store Connect

**Paywall Triggers:**
- Tap locked animal
- Tap locked theme
- After 3 days of use (soft prompt)
- In settings ("Upgrade to Pro")

---

## Phase 10: Polish & Launch Prep 🚀

### 10.1 Performance Optimization

- [ ] Reduce drawing sync latency (<200ms)
- [ ] Optimize image loading (lazy load timeline)
- [ ] Cache farm state aggressively
- [ ] Reduce memory footprint (release old drawings)
- [ ] Battery optimization (reduce realtime polling)

### 10.2 Accessibility

- [ ] VoiceOver labels for all UI
- [ ] Dynamic Type support
- [ ] Color contrast checks (WCAG AA)
- [ ] Haptic feedback for key actions

### 10.3 Error Handling

- [ ] Offline mode (show cached data)
- [ ] Network error retry logic
- [ ] Graceful Supabase failures
- [ ] User-friendly error messages

### 10.4 Analytics

**Track:**
- Daily active users (DAU)
- Drawing frequency
- Streak retention rate
- Premium conversion rate
- Feature usage (prompts, animals, themes)

**Tools:**
- Mixpanel or Amplitude
- App Store Connect analytics
- Supabase logs

### 10.5 App Store Assets

**Required:**
- [ ] App icon (1024x1024)
- [ ] Screenshots (6.7", 6.5", 5.5" devices)
- [ ] Preview video (15-30 sec)
- [ ] App Store description
- [ ] Keywords (couples, doodle, cozy, farm, streak)
- [ ] Privacy policy URL
- [ ] Support URL

---

## Development Priorities (Suggested Order)

### MVP (Minimum Viable Product) - 4-6 weeks
1. ✅ Phase 1.1: Expand database schema
2. ✅ Phase 2: Drawing canvas (basic)
3. ✅ Phase 3.1: Energy system (simplified)
4. ✅ Phase 3.2: Streak system (normal mode)
5. ✅ Phase 3.3: Animal unlocks (4 animals)

**Goal:** Couples can draw together, earn points, unlock animals, maintain streaks.

### V1.0 Launch - 2-3 weeks after MVP
6. Phase 4: Daily prompts
7. Phase 6: Timeline (basic)
8. Phase 8: Notifications
9. Phase 10.1-10.4: Polish & testing

**Goal:** Shippable product with core viral loop.

### V1.1 Post-Launch - 1-2 months
10. Phase 5: Widgets
11. Phase 7.1: Seasonal themes
12. Phase 9: Premium tier
13. Phase 7.2: Weather system

**Goal:** Monetization + engagement boosters.

### V2.0 Future
14. Phase 7.3: Advanced animal interactions
15. Multi-room support (multiple friend groups)
16. Social features (share to Instagram/TikTok)
17. Desktop web version

---

## Technical Debt to Address

### Current Issues
1. **Pseudo-metrics in FarmHomeView**
   - Replace with real Supabase data
   - File: `FarmHomeView.swift:111-117`

2. **No drawing persistence**
   - Add doodle storage table
   - Implement history view

3. **Streak calculation missing**
   - Currently just displays pseudo-random number
   - Need date-based logic

4. **No error states**
   - Add loading/error views
   - Handle Supabase failures gracefully

### Code Organization
- Create `Models/` folder for data structures
- Create `Services/` folder for managers
- Create `Views/` folder with subfolders (Farm, Drawing, Settings, etc.)
- Move extensions to `Extensions/` folder

---

## Testing Strategy

### Unit Tests
- `EnergyManager` calculation logic
- `StreakCalculator` date math
- `DrawingStroke` serialization
- `FarmManager` unlock conditions

### UI Tests
- Complete onboarding flow
- Pairing process (create + join room)
- Drawing canvas interactions
- Animal unlock flow
- Streak reset (hardcore mode)

### Manual Testing Checklist
- [ ] Two devices pairing successfully
- [ ] Real-time drawing sync (<500ms lag)
- [ ] Energy updates reflected on both devices
- [ ] Streak increments daily
- [ ] Animals unlock at correct thresholds
- [ ] Notifications arrive on time
- [ ] Widgets update correctly
- [ ] App survives background/foreground transitions

---

## Success Metrics (Post-Launch)

### Week 1
- 1,000 downloads
- 40%+ D1 retention
- 100+ active duos

### Month 1
- 10,000 downloads
- 25%+ D7 retention
- 5%+ premium conversion
- Avg 3+ drawings/day per duo

### Month 3
- 50,000 downloads
- TikTok virality (1M+ views on #doodleduo)
- 10%+ premium conversion
- Featured in App Store "Apps We Love"

---

## Questions to Resolve

1. **Drawing data storage:** Store full PKDrawing or simplified stroke data?
2. **Real-time protocol:** Supabase Realtime vs custom WebSocket?
3. **Image hosting:** Supabase Storage vs Cloudinary vs S3?
4. **Analytics:** Mixpanel vs Amplitude vs PostHog?
5. **Crash reporting:** Sentry vs Crashlytics?
6. **Pro subscription:** Monthly only or annual discount?
7. **Free trial:** 7 days or 14 days?

---

**Last Updated:** 2025-01-17
**Maintained By:** Development Team
**Version:** 1.0
