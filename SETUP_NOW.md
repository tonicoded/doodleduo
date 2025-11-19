# Setup Push Notifications - YOUR EXACT STEPS

Everything is ready! Just follow these 3 steps:

---

## Step 1: Install Supabase CLI and Deploy Edge Function

```bash
# Install Supabase CLI (choose one)
brew install supabase/tap/supabase
# OR
npm install -g supabase

# Login to Supabase
supabase login

# Link your project
supabase link --project-ref reevrasmalgiftakwsao

# Deploy the edge function
cd /Users/anthonyverruijt/Downloads/doodleduo
supabase functions deploy send-push-notification
```

You should see: `✔ Deployed Function send-push-notification`

---

## Step 2: Set Environment Variables in Supabase

1. Go to your Supabase dashboard: https://supabase.com/dashboard/project/reevrasmalgiftakwsao
2. Click **Project Settings** (gear icon in sidebar)
3. Click **Edge Functions** in the left menu
4. Click **Add new secret**
5. Add these 4 secrets one by one:

### Secret 1:
- **Name**: `APPLE_TEAM_ID`
- **Value**: `6XQ6Q4DLD3`

### Secret 2:
- **Name**: `APPLE_KEY_ID`
- **Value**: `5MKRR9AHUM`

### Secret 3:
- **Name**: `APPLE_BUNDLE_ID`
- **Value**: `com.anthony.doodleduo`

### Secret 4:
- **Name**: `APNS_PRODUCTION`
- **Value**: `false`

### Secret 5 (the private key):
- **Name**: `APPLE_PRIVATE_KEY`
- **Value**: Copy and paste this EXACTLY (including the header/footer):
```
-----BEGIN PRIVATE KEY-----
MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQgodgpta8qZLjFCNZB
+EGSBkKZW8KSMRu847asO23nx4KgCgYIKoZIzj0DAQehRANCAARrxDTe3hOFLZUK
5qEUZybjugB8jV2BYMphmmCCcSz0etBZ7ut6MeGGo46DgpY7VEGzLT6b5X5Ff5UI
GTdo14zx
-----END PRIVATE KEY-----
```

Click **Save** after each secret.

---

## Step 3: Run Database Migration

1. Go to Supabase dashboard: https://supabase.com/dashboard/project/reevrasmalgiftakwsao
2. Click **SQL Editor** in the sidebar
3. Click **New Query**
4. Open this file: `/Users/anthonyverruijt/Downloads/doodleduo/supabase/migrations/005_activate_push_notifications.sql`
5. Copy the ENTIRE contents
6. Paste into the SQL Editor
7. Click **Run** button

You should see success messages in the results panel.

---

## Step 4: Test It!

1. **Run your app in Xcode**
   - Open `doodleduo.xcodeproj`
   - Hit Cmd+R to run

2. **Check the console for:**
   ```
   📱 Registering device token: ...
   ✅ Device token registered successfully
   ```

3. **Test with app closed:**
   - Have both devices/simulators paired
   - **Fully close the app** (swipe up from app switcher)
   - From the other device, send a ping/note/doodle
   - **You should get a push notification!** 🎉

4. **Check widget:**
   - Add the widget to home screen
   - When notification arrives, widget should update

---

## Troubleshooting

### If you see "command not found: supabase"
The CLI didn't install correctly. Try:
```bash
# Using Homebrew
brew install supabase/tap/supabase

# Or using NPM (if you have Node.js)
npm install -g supabase

# Verify installation
supabase --version
```

### If edge function deployment fails
Make sure you're logged in:
```bash
supabase login
```

Then try deploying again:
```bash
cd /Users/anthonyverruijt/Downloads/doodleduo
supabase functions deploy send-push-notification
```

### If database migration fails
Check that the `pg_net` extension is enabled:
```sql
CREATE EXTENSION IF NOT EXISTS pg_net;
```

### If notifications don't arrive
Check device token was registered:
```sql
SELECT * FROM device_tokens WHERE platform = 'ios';
```

Check Supabase function logs:
- Go to **Edge Functions** → **send-push-notification**
- Click **Logs** tab
- Look for errors

---

## What Happens After Setup

### When App is Closed:
1. Partner sends activity → Database trigger fires
2. Trigger calls your edge function
3. Edge function sends APNs push notification
4. Notification wakes your device
5. Widget updates automatically

### Cost:
- **$0/month** - All within free tiers! 🎉

---

## Quick Verification Commands

After setup, verify everything works:

```sql
-- Check device tokens are registered
SELECT * FROM device_tokens WHERE platform = 'ios';

-- Test your room setup
SELECT * FROM test_push_notification_setup(
    (SELECT room_id FROM duo_memberships WHERE profile_id = auth.uid())
);
```

Should return:
- `member_count`: 2
- `device_token_found`: true
- `setup_status`: "Ready for push notifications"

---

## Summary

Your credentials (already configured):
- ✅ Team ID: `6XQ6Q4DLD3`
- ✅ Key ID: `5MKRR9AHUM`
- ✅ Bundle ID: `com.anthony.doodleduo`
- ✅ Private Key: From `AuthKey_5MKRR9AHUM.p8`
- ✅ Supabase URL: `https://reevrasmalgiftakwsao.supabase.co`
- ✅ Database migration: Updated with your project URL

**Just do the 3 steps above and you're done!** 🚀
