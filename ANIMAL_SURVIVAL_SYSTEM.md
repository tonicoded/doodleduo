# Animal Survival System - Design Doc

## Concept: Hardcore Minecraft for Couples

Instead of a simple "streak," the farm becomes a **survival challenge** where you must keep animals alive through daily activities.

---

## Core Mechanics

### 1. Days Survived Counter
- Replaces "Streak"
- Shows how many consecutive days you've kept the animals alive
- **Icon**: 📅 Calendar badge (changed from flame)
- **Label**: "days survived" (instead of "streak")
- **Color**: Green/blue gradient (nature/life themed)

### 2. Activity = Life
- **Every activity** (ping, hug, kiss, note, doodle) **keeps animals alive** for 24 hours
- If **no activity for 24 hours** → **Animals start dying**
- Animals die one by one (maybe in order: newest → oldest)
- When **all animals die** → **GAME OVER** → Reset to Day 1 with just chicken

### 3. Love Points = Currency
- Earned from activities (current system already tracks this!)
- Used to **buy new animals** from the shop
- Example prices:
  - 🐔 Chicken: FREE (starter animal)
  - 🐑 Sheep: 50 love points
  - 🐷 Pig: 100 love points
  - 🐴 Horse: 200 love points
  - 🐮 Cow: 300 love points (future)
  - 🦆 Duck: 150 love points (future)
  - 🐐 Goat: 250 love points (future)

### 4. Death & Reset
- **Hardcore Mode**: When all animals die, everything resets
  - Days Survived → 0 → 1
  - Animals → Back to just 🐔 chicken
  - Love Points → **KEEP THEM!** (or reset to 0 for true hardcore)
- **Record Keeping**: Track "longest survival" (like longest streak)

---

## UI Changes

### ✅ Already Done:
- Changed "streak" → "days survived"
- Changed flame icon 🔥 → calendar 📅
- Changed red/orange gradient → green/blue gradient

### 🔧 To Do:

#### Farm View Additions:
1. **Animal Shop Button**
   - Floating button or toolbar item
   - Shows "🛒 Shop" with love points balance
   - Opens animal purchase sheet

2. **Death Warning**
   - When <6 hours left before animals die:
     - Show warning badge/banner
     - "⚠️ Animals need attention! Send an activity to keep them alive"
   - When <1 hour: Red urgent warning

3. **Animal Status Indicators**
   - Healthy animals: Normal, animated
   - Dying animals: Faded, slow animation
   - Dead animals: Grayscale, sleeping/fainted

#### Animal Shop Sheet:
```
┌─────────────────────────────┐
│  🛒 Animal Shop              │
│  💕 84 love points available │
├─────────────────────────────┤
│  🐑 Sheep         50 pts     │
│  [Buy] or [Owned ✓]         │
├─────────────────────────────┤
│  🐷 Pig           100 pts    │
│  [Buy] or [Not enough 💔]   │
├─────────────────────────────┤
│  🐴 Horse         200 pts    │
│  [Locked - Day 5]            │
└─────────────────────────────┘
```

#### Game Over Screen:
When all animals die, show modal:
```
┌─────────────────────────────┐
│      💀 GAME OVER 💀         │
│                              │
│  Your farm lasted            │
│     🗓️ 23 DAYS 🗓️           │
│                              │
│  All animals have perished   │
│  Starting fresh with chicken │
│                              │
│  [Start Over]                │
└─────────────────────────────┘
```

---

## Database Schema Updates

### Add to `duo_farms` table:
```sql
ALTER TABLE duo_farms ADD COLUMN last_activity_at TIMESTAMPTZ;
ALTER TABLE duo_farms ADD COLUMN animals_alive BOOLEAN DEFAULT true;
ALTER TABLE duo_farms ADD COLUMN death_date TIMESTAMPTZ;
```

### Update `duo_metrics` interpretation:
- `current_streak` = days survived
- `longest_streak` = longest survival run
- `hardcore_mode` = true (always use survival mode)

### Create new table for animal catalog:
```sql
CREATE TABLE animal_catalog (
    animal_id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    cost INT NOT NULL,
    unlock_day INT DEFAULT 1,
    emoji TEXT
);

INSERT INTO animal_catalog VALUES
('chicken', 'Chicken', 0, 1, '🐔'),
('sheep', 'Sheep', 50, 1, '🐑'),
('pig', 'Pig', 100, 3, '🐷'),
('horse', 'Horse', 200, 5, '🐴'),
('cow', 'Cow', 300, 7, '🐮'),
('duck', 'Duck', 150, 4, '🦆'),
('goat', 'Goat', 250, 6, '🐐');
```

---

## Implementation Steps

### Phase 1: Visual Updates (Done! ✅)
- [x] Rename streak → days survived
- [x] Update icon and colors

### Phase 2: Animal Shop UI (Next)
- [ ] Create AnimalShopView.swift
- [ ] Add shop button to FarmHomeView
- [ ] Show available animals with prices
- [ ] Handle purchase logic (deduct love points)

### Phase 3: Death Mechanics
- [ ] Add timer check (every activity resets 24hr timer)
- [ ] Show warnings when time running out
- [ ] Animate animals dying
- [ ] Trigger game over when all dead

### Phase 4: Reset Logic
- [ ] Save "longest survival" stat
- [ ] Reset days to 1
- [ ] Reset animals to [chicken]
- [ ] Show game over modal
- [ ] Optional: Reset or keep love points

---

## Future Enhancements

### Upgrades (using love points):
- 🏠 **Barn Upgrade**: Holds more animals
- 🌾 **Food Storage**: 48hr buffer instead of 24hr
- 💊 **Medicine**: Revive one dead animal
- 🛡️ **Insurance**: One free revival per week

### Special Events:
- 🎂 **Anniversary Bonus**: Double love points
- 🌙 **Night Survival**: Send activity at night = 2x points
- 🎁 **Mystery Egg**: Random animal unlock

### Leaderboard:
- Track longest survival across all couples
- Show on website: "Top 10 Surviving Farms"

---

## Why This is Better

1. **Higher Stakes**: Streak vs. survival = way more engaging
2. **Progression**: Buy animals = sense of growth
3. **Daily Tension**: "Did we send an activity today?"
4. **Replayability**: Game over = fresh start, beat your record
5. **Couple Bonding**: "We can't let our farm die!"

---

This turns a simple couples app into a **shared survival game**! 🎮❤️
