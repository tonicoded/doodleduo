# 🌾 DoodleDuo

> A cozy couples app where your doodles make a tiny world grow.

**Status:** Foundation Complete | MVP in Development
**Platform:** iOS 17.0+
**Tech Stack:** SwiftUI, Supabase, PencilKit

---

## 📱 What is DoodleDuo?

DoodleDuo is a relationship app that combines **real-time collaborative drawing** with a **progression-based virtual farm**. Every doodle you and your partner create generates "love energy" that unlocks cute animals and grows your shared cozy world.

### Core Features
- 🎨 **Shared Live Whiteboard** - Draw together in real-time with pastel brushes
- 💖 **Love Energy System** - Every doodle generates points to unlock animals
- 🐔 **Cozy Farm** - Collectible animals (chicken, sheep, pig, horse, cow...)
- 🔥 **Streak System** - Daily ritual with optional hardcore mode
- 📅 **Daily Prompts** - Fun drawing challenges ("Draw your partner as an animal")
- 📱 **Live Widgets** - See your farm and partner's doodles on home screen
- 📸 **Memory Timeline** - Automatic relationship journal

---

## 🚀 Quick Start

### For Developers

```bash
# Clone and open
cd doodleduo
open doodleduo.xcodeproj

# Build and run
# Press Cmd+R in Xcode
# Select iPhone 15 simulator
```

**First time here?** Read **[GETTING_STARTED.md](GETTING_STARTED.md)** for a guided walkthrough.

### Documentation Map

| Document | Purpose | When to Read |
|----------|---------|--------------|
| [GETTING_STARTED.md](GETTING_STARTED.md) | 👈 **Start here!** Quick setup + first task | Day 1 |
| [SUMMARY.md](SUMMARY.md) | What's built, what's next, status overview | Day 1 |
| [MVP_QUICKSTART.md](MVP_QUICKSTART.md) | Week-by-week implementation guide | Ongoing |
| [ROADMAP.md](ROADMAP.md) | Complete feature roadmap (10 phases) | Planning |
| [CLAUDE.md](CLAUDE.md) | Architecture deep-dive, build commands | Reference |
| [AGENTS.md](AGENTS.md) | Code style, testing, commit guidelines | Before commits |

---

## ✅ Current Implementation

### Infrastructure
- ✅ Supabase authentication (Apple Sign-In)
- ✅ Session persistence and profile caching
- ✅ Couple pairing with room codes
- ✅ Background audio system (5 music tracks)

### UI/UX
- ✅ Complete 7-stage onboarding flow
- ✅ Farm view with day/night cycle
- ✅ Animated stat badges (love points, streak)
- ✅ Settings screen with duo management
- ✅ Cozy pastel color palette

### Database
- ✅ User profiles with RLS
- ✅ Duo rooms and memberships
- ✅ Schema ready for expansion

---

## 🎯 MVP Roadmap (Next 6 Weeks)

### Week 1: Database Setup
- [ ] Deploy migration (add 5 new tables)
- [ ] Create Swift models (DuoMetrics, DuoFarm)
- [ ] Fetch real data in FarmHomeView

### Week 2: Drawing Canvas
- [ ] Integrate PencilKit
- [ ] Add "Doodle" tab
- [ ] Implement color palette
- [ ] Local drawing (no sync yet)

### Week 3: Energy System
- [ ] Create EnergyManager
- [ ] Award energy for drawing
- [ ] Update metrics in real-time

### Week 4: Animal Unlocks
- [ ] Create FarmManager
- [ ] Define unlock thresholds
- [ ] Display animals on farm

### Week 5: Streak System
- [ ] Create StreakCalculator
- [ ] Daily streak increments
- [ ] Hardcore mode (animals sleep)

### Week 6: Testing & Polish
- [ ] Two-device testing
- [ ] Bug fixes
- [ ] Loading states
- [ ] Error handling

**Detailed guide:** [MVP_QUICKSTART.md](MVP_QUICKSTART.md)

---

## 🏗️ Architecture Overview

### State Machine (ContentView)
```
splash → onboarding → welcome → interest → notifications
  → signIn → profileSetup → pairing → main
```

### Service Layer
- **AuthService** - Supabase authentication, session management
- **CoupleSessionManager** - Room creation, pairing, partner sync
- **BackgroundAudioManager** - Music playback control
- **SupabaseEnvironment** - Config loader (URL + anon key)

### Data Flow
```
User Action → ViewModel → Service → Supabase → Service → ViewModel → UI Update
```

### Database Schema
```sql
profiles          -- User data (display_name, apple_email)
duo_rooms         -- Couple rooms (room_code, created_by)
duo_memberships   -- Who's in which room
duo_metrics       -- Energy, streaks, activity tracking
duo_farms         -- Unlocked animals, farm level, theme
doodles           -- Drawing data, thumbnails
daily_prompts     -- Prompts and completion status
timeline_events   -- Automatic memory journal
```

**Full schema:** [supabase/migrations/001_add_core_features.sql](supabase/migrations/001_add_core_features.sql)

---

## 🛠️ Tech Stack

### Frontend
- **SwiftUI** - Declarative UI framework
- **PencilKit** - Drawing canvas (native, low-latency)
- **WidgetKit** - Home screen widgets (future)
- **StoreKit 2** - In-app purchases for Pro tier (future)

### Backend
- **Supabase** - PostgreSQL database with realtime
- **Supabase Auth** - Apple Sign-In integration
- **Supabase Storage** - Image hosting (future: thumbnails)
- **Supabase Realtime** - WebSocket for live drawing sync

### Development
- **Xcode 15+** - iOS development
- **Git** - Version control
- **TestFlight** - Beta distribution (future)

---

## 🎨 Design Philosophy

### Visual Identity
- **Cozy & Warm** - Pastel colors, soft edges, gentle animations
- **Playful** - Cute animals, whimsical farm, fun prompts
- **Minimalist** - Clean UI, focus on content (doodles + farm)
- **Safe & Private** - No social features, just you and your partner

### User Experience
- **Low Barrier** - Just draw, that's it
- **Daily Ritual** - Streak system creates habit
- **Tangible Progress** - Farm grows visually with relationship
- **Emotional Resonance** - Doodles = memories, farm = relationship health

---

## 🔒 Privacy & Security

### Data Protection
- **Row-Level Security (RLS)** - Users can only access their own duo's data
- **No Social Feed** - Doodles never leave your private room
- **Local Caching** - Sensitive data stored securely in Keychain
- **End-to-End** - Drawing data encrypted in transit (HTTPS)

### Authentication
- **Apple Sign-In** - No passwords, secure by default
- **Session Tokens** - Auto-refresh, stored in UserDefaults
- **Anonymous Option** - Can use app without signing in (local only)

---

## 💸 Monetization Strategy

### Free Tier
- 4 starter animals (chicken, sheep, pig, horse)
- Basic brushes (5 pastel colors)
- Normal streak mode
- 30 days timeline history

### Pro Tier ($4.99-$6.99/month)
- All premium animals (cow, duck, goat, alpaca, fox, panda, bunny, dragon)
- Seasonal themes (Christmas, Valentine, Halloween)
- Animated brushes (glitter, rainbow, neon)
- 50+ premium stickers
- Hardcore streak mode
- Unlimited timeline
- Farm expansion
- Golden animal skins
- Export doodles as images

**Conversion Goal:** 5-10% of active users

---

## 📊 Success Metrics

### Week 1 (Post-Launch)
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
- Featured in App Store

---

## 🧪 Testing

### Unit Tests
```bash
xcodebuild test -scheme doodleduo -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Manual Testing
- [ ] Onboarding flow (all 7 stages)
- [ ] Pairing (create + join room)
- [ ] Drawing canvas (smooth, no lag)
- [ ] Energy updates (both devices)
- [ ] Animal unlocks (appear on farm)
- [ ] Streak increments (daily)
- [ ] Hardcore mode (animals sleep)

**Full checklist:** [MVP_QUICKSTART.md](MVP_QUICKSTART.md#week-6-testing--polish)

---

## 🤝 Contributing

### Code Style
- 4 spaces (no tabs)
- Lines ≤120 chars
- PascalCase for types, camelCase for members
- Group SwiftUI modifiers: layout → styling → behaviors
- Treat warnings as errors

### Commit Messages
```
imperative mood: "Add animal unlock animation"

Longer description explaining why, not what.

Fixes #123
```

### Before Pushing
```bash
# Run tests
xcodebuild test -scheme doodleduo -destination 'platform=iOS Simulator,name=iPhone 15'

# Fix all warnings
# Xcode should show 0 warnings before committing
```

**Full guidelines:** [AGENTS.md](AGENTS.md)

---

## 📚 Resources

### Documentation
- [Apple SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)
- [Supabase Swift Client](https://github.com/supabase/supabase-swift)
- [PencilKit Documentation](https://developer.apple.com/documentation/pencilkit)

### Inspiration
- Lovelee (couples journaling)
- Candle (shared moments)
- Butter (couples games)

---

## 📝 License

Proprietary - All rights reserved

---

## 🎉 Let's Build This!

DoodleDuo has the potential to become a **viral couples app** that redefines how partners connect digitally. The foundation is solid, the vision is clear, and the roadmap is detailed.

**Next Steps:**
1. Read [GETTING_STARTED.md](GETTING_STARTED.md)
2. Follow [MVP_QUICKSTART.md](MVP_QUICKSTART.md)
3. Ship the MVP in 6 weeks
4. Iterate based on user feedback
5. Scale to 100k+ users

**Let's make relationship apps fun again.** 🚀💖

---

**Questions?** Check the documentation or ask Claude Code for help!

**Built with:** ❤️ + ☕ + 🎨
