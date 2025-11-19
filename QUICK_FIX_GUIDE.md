# Quick Fix Guide - Push Notifications Not Working When App Closed

## The Problem
- ✅ Notifications work when app is open or in background
- ❌ Notifications DON'T work when app is fully closed
- ❌ Widget doesn't update when app is closed

## Why This Happens
Your app uses **polling** (checking database every 10 seconds) which stops when the app closes. You need **Apple Push Notifications (APNs)** to wake the app when closed.

## Quick Fix (5 Steps)

### 1️⃣ Get APNs Certificate (Apple Developer Portal)
- Go to [developer.apple.com/account/resources/authkeys](https://developer.apple.com/account/resources/authkeys)
- Create new key → Enable "Apple Push Notifications service (APNs)"
- **Download the .p8 file** (you can only do this ONCE!)
- Note your **Key ID** and **Team ID**

### 2️⃣ Deploy Edge Function (Terminal)
```bash
cd /path/to/doodleduo
supabase login
supabase link --project-ref YOUR_PROJECT_ID
supabase functions deploy send-push-notification
```

### 3️⃣ Configure Supabase (Dashboard)
In Supabase Dashboard → Project Settings → Edge Functions, add:
```
APPLE_TEAM_ID=YOUR_TEAM_ID
APPLE_KEY_ID=YOUR_KEY_ID
APPLE_BUNDLE_ID=com.anthony.doodleduo
APNS_PRODUCTION=false
APPLE_PRIVATE_KEY=<paste entire .p8 file contents>
```

### 4️⃣ Run Database Migration (SQL Editor)
1. Open [supabase/migrations/005_activate_push_notifications.sql](supabase/migrations/005_activate_push_notifications.sql)
2. Replace `YOUR_PROJECT_ID` with your actual project URL
3. Copy and paste into Supabase SQL Editor
4. Run the query

### 5️⃣ Test It
```bash
# Build and run app
open doodleduo.xcodeproj

# Check console for:
# "✅ Device token registered successfully"

# Then fully close the app and have partner send activity
# You should get a push notification!
```

## Verification Checklist

Run these in Supabase SQL Editor:

```sql
-- ✅ Check edge function is deployed
SELECT net.http_post(
    url := 'https://YOUR_PROJECT.supabase.co/functions/v1/send-push-notification',
    headers := '{"Content-Type": "application/json"}',
    body := '{}'
);

-- ✅ Check device token is registered
SELECT * FROM device_tokens WHERE platform = 'ios';

-- ✅ Test push notification setup
SELECT * FROM test_push_notification_setup(
    (SELECT room_id FROM duo_memberships WHERE profile_id = auth.uid())
);
```

Expected results:
- Device token exists in database
- Test returns `setup_status: "Ready for push notifications"`

## If Something Goes Wrong

### "No device token registered"
→ Make sure you granted notification permissions in the app
→ Check Xcode console for "✅ Device token registered successfully"

### "Edge function returns 401"
→ Check your APPLE_PRIVATE_KEY includes full PEM format (with headers/footers)
→ Verify Team ID and Key ID are correct

### "Notifications work in simulator but not real device"
→ For development: `APNS_PRODUCTION=false`
→ For TestFlight/App Store: `APNS_PRODUCTION=true`

## What Each File Does

| File | Purpose |
|------|---------|
| [supabase/functions/send-push-notification/index.ts](supabase/functions/send-push-notification/index.ts) | Edge function that sends APNs notifications |
| [supabase/migrations/005_activate_push_notifications.sql](supabase/migrations/005_activate_push_notifications.sql) | Database trigger that calls edge function |
| [doodleduo/doodleduoApp.swift](doodleduo/doodleduoApp.swift) | Handles incoming notifications when app is closed |
| [PUSH_NOTIFICATIONS_COMPLETE_SETUP.md](PUSH_NOTIFICATIONS_COMPLETE_SETUP.md) | Detailed setup guide with troubleshooting |

## Cost
- APNs: **Free** (unlimited)
- Supabase Edge Functions: **Free** for first 500K requests/month
- Your usage: ~3,000 notifications/month = **$0/month** 🎉

## Need More Help?
See [PUSH_NOTIFICATIONS_COMPLETE_SETUP.md](PUSH_NOTIFICATIONS_COMPLETE_SETUP.md) for detailed instructions with screenshots and troubleshooting.
