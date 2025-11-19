# Testing Guide - Real Data Implementation

## What We Just Built ✅

### Files Created:
1. **[doodleduo/Models/DuoMetrics.swift](doodleduo/Models/DuoMetrics.swift)** - Data models for metrics and farm
2. **[doodleduo/AnimalView.swift](doodleduo/AnimalView.swift)** - Animated animal component with sleeping state

### Files Modified:
3. **[CoupleSessionManager.swift](doodleduo/CoupleSessionManager.swift)** - Added `metrics` and `farm` properties + `refreshMetrics()` method
4. **[FarmHomeView.swift](doodleduo/FarmHomeView.swift)** - Replaced pseudo-metrics with real data + added animal layers
5. **[MainTabView.swift](doodleduo/MainTabView.swift)** - Added `refreshMetrics()` call on load

---

## How to Test in Xcode

### 1. Build the Project
```bash
# Open in Xcode
open /Users/anthonyverruijt/Downloads/doodleduo/doodleduo.xcodeproj

# In Xcode:
# 1. Press Cmd+B to build
# 2. Wait for build to complete (should be no errors)
```

### 2. Run on Simulator
```bash
# In Xcode:
# 1. Select "iPhone 15" from device dropdown (top toolbar)
# 2. Press Cmd+R to run
# 3. Wait for app to launch
```

### 3. Test Flow

**Expected Behavior:**

#### A. If you have an existing duo room:
1. App opens → Splash → Farm View
2. You should see:
   - **Love Points: 0** (real data from Supabase!)
   - **Streak: 0** (real data from Supabase!)
   - **A chicken** 🐔 gently bobbing on the farm (auto-unlocked)
   - Day or night background (based on time)

#### B. If creating a new duo room:
1. App opens → Splash → Onboarding → ... → Sign In
2. Sign in with Apple (or "Continue without signing in")
3. Create a new room
4. **Important:** After creating room, you should see:
   - Farm initializes with chicken
   - Love Points: 0
   - Streak: 0

### 4. Verify Database

Check Supabase to confirm data was created:

1. Go to [Supabase Dashboard](https://app.supabase.com)
2. Navigate to **Table Editor**
3. Check `duo_metrics` table:
   ```sql
   SELECT * FROM duo_metrics ORDER BY created_at DESC LIMIT 5;
   ```
   Should show your room with `love_energy = 0`, `current_streak = 0`

4. Check `duo_farms` table:
   ```sql
   SELECT * FROM duo_farms ORDER BY created_at DESC LIMIT 5;
   ```
   Should show your room with `unlocked_animals = ["chicken"]`

5. Check `timeline_events` table:
   ```sql
   SELECT * FROM timeline_events ORDER BY event_date DESC LIMIT 10;
   ```
   Should show "Farm created! 🌾" event

---

## Expected Results

### ✅ Success Indicators:
- [x] App builds without errors
- [x] Farm displays correctly
- [x] Love Points shows "0" (not a random number)
- [x] Streak shows "0" (not a random number)
- [x] Chicken appears on farm and gently bobs
- [x] Background changes day/night based on time
- [x] Database tables show correct data

### ❌ Common Issues:

#### "Cannot find type 'DuoMetrics' in scope"
**Fix:** The file should auto-include, but if not:
1. In Xcode, right-click `doodleduo` folder
2. Select "Add Files to doodleduo..."
3. Navigate to `doodleduo/Models/DuoMetrics.swift`
4. Make sure target "doodleduo" is checked
5. Click Add

#### "Cannot find 'AnimalView' in scope"
**Fix:** Same as above, but for `doodleduo/AnimalView.swift`

#### "Love Points still shows random number"
**Check:**
- Did you run the database migration?
- Is the room_id valid?
- Check Xcode console for errors (Cmd+Shift+Y to show)

#### "No chicken appears"
**Check:**
- Verify `duo_farms.unlocked_animals` in Supabase contains `["chicken"]`
- Check if farm is nil (add breakpoint in FarmHomeView)
- Verify chicken.png exists in Assets.xcassets

#### "App crashes on launch"
**Check Xcode console for error message:**
- Missing Supabase config? (Info.plist needs SUPABASE_URL and SUPABASE_ANON_KEY)
- Network error? (Check internet connection)
- JSON decoding error? (Check Supabase table structure)

---

## What's Different Now?

### Before:
```swift
// FarmHomeView.swift (OLD)
private var affectionScore: Int {
    pseudoMetric(from: sessionManager.roomID ?? "cozy", range: 220...900)
    // Returns random number based on hash
}
```

### After:
```swift
// FarmHomeView.swift (NEW)
private var affectionScore: Int {
    sessionManager.metrics?.loveEnergy ?? 0
    // Returns actual value from Supabase
}
```

### Before:
- No animals visible on farm
- Metrics were fake (hash-based pseudo-random)
- No connection to database

### After:
- Chicken appears and animates 🐔
- Metrics are real (from `duo_metrics` table)
- Farm state syncs with `duo_farms` table

---

## Next Steps After Testing

Once you confirm everything works:

### Immediate Next:
1. **Add more animals** - Unlock sheep, pig, horse when energy thresholds reached
2. **Implement energy system** - Award points for actions (drawing, interactions)
3. **Add unlock button** - "Unlock Sheep (100 energy)" button when threshold reached

### This Week:
4. **Drawing canvas** - PencilKit integration for doodling
5. **Energy awards** - +1 per stroke, update `duo_metrics.love_energy`
6. **Streak system** - Daily increment logic

### Follow:
- [MVP_QUICKSTART.md](MVP_QUICKSTART.md) - Week 2: Drawing Canvas

---

## Debug Commands

### Check if metrics loaded:
Add this temporary code to `FarmHomeView.swift`:
```swift
.onAppear {
    print("🐔 Metrics:", sessionManager.metrics ?? "nil")
    print("🐔 Farm:", sessionManager.farm ?? "nil")
}
```

### Force refresh metrics:
Add a button in `SettingsTabView`:
```swift
Button("Refresh Metrics") {
    Task {
        try? await sessionManager.refreshMetrics()
    }
}
```

---

## Success! 🎉

If you see:
- ✅ Love Points: 0
- ✅ Streak: 0
- ✅ Chicken bobbing on farm

**You've successfully connected real Supabase data!**

The foundation is now solid. Every metric you see is pulled from the database, and animals are rendered based on `duo_farms.unlocked_animals`.

Next up: Let's add the drawing canvas so users can actually EARN that energy! 🎨

---

**Questions?** Check the Xcode console (Cmd+Shift+Y) for error messages.
