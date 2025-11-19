# Complete Push Notifications Setup Guide

This guide will help you enable **real push notifications** when the app is fully closed, so your partner gets notified immediately and the widget updates.

## Why Notifications Don't Work When App is Closed

Your app currently uses **polling** (checking every 10 seconds) which only works when the app is running. When the app is fully closed:
- ❌ Timers stop running
- ❌ No database polling happens
- ❌ Widget can't update automatically

**Solution**: Use Apple Push Notification service (APNs) to wake the app and update the widget.

---

## Step 1: Get APNs Authentication Key from Apple

### 1.1 Go to Apple Developer Portal
1. Visit [developer.apple.com](https://developer.apple.com)
2. Sign in with your Apple Developer account
3. Go to **Certificates, Identifiers & Profiles**

### 1.2 Create APNs Key
1. Click **Keys** in the sidebar
2. Click the **+** button to create a new key
3. Name it: `DoodleDuo Push Notifications`
4. Check the box for **Apple Push Notifications service (APNs)**
5. Click **Continue**, then **Register**
6. **Download the .p8 key file** - YOU CAN ONLY DOWNLOAD THIS ONCE!
7. Save the file somewhere safe

### 1.3 Note Down These Values
After creating the key, you'll see:
- **Key ID** (example: `AB12CD34EF`)
- **Team ID** (example: `XYZ1234567`) - found in your account settings

Keep these safe - you'll need them for Supabase configuration.

---

## Step 2: Configure Your Xcode Project

### 2.1 Enable Push Notifications Capability
1. Open `doodleduo.xcodeproj` in Xcode
2. Select your main app target (**doodleduo**)
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability**
5. Add **Push Notifications**
6. Make sure **Background Modes** is enabled with:
   - ✅ Remote notifications
   - ✅ Background fetch

### 2.2 Verify Entitlements
Your [doodleduo.entitlements](doodleduo/doodleduo.entitlements) should include:
```xml
<key>aps-environment</key>
<string>development</string>
```

For production builds, this should be `production`.

---

## Step 3: Deploy the Supabase Edge Function

### 3.1 Install Supabase CLI
If you haven't already:
```bash
# macOS
brew install supabase/tap/supabase

# Or using npm
npm install -g supabase
```

### 3.2 Login to Supabase
```bash
supabase login
```

### 3.3 Link Your Project
```bash
# Get your project ID from Supabase dashboard URL
# Example: https://app.supabase.com/project/abcdefghijklmn
supabase link --project-ref YOUR_PROJECT_ID
```

### 3.4 Deploy the Edge Function
```bash
cd /path/to/doodleduo
supabase functions deploy send-push-notification
```

You should see:
```
✔ Deployed Function send-push-notification
```

> ℹ️ Anytime you pull new changes (like the APNs JWT signing fix in this update), redeploy this function so Supabase uses the latest code.

---

## Step 4: Configure Supabase Environment Variables

### 4.1 Set APNs Credentials
In your Supabase dashboard:

1. Go to **Project Settings** → **Edge Functions**
2. Add these environment variables:

```bash
APPLE_TEAM_ID=YOUR_TEAM_ID          # From Step 1.3
APPLE_KEY_ID=YOUR_KEY_ID            # From Step 1.3
APPLE_BUNDLE_ID=com.anthony.doodleduo
APNS_PRODUCTION=false               # Set to 'true' for production builds
```

3. For `APPLE_PRIVATE_KEY`, open your downloaded `.p8` file and copy the **entire contents** including the header and footer:
```
-----BEGIN PRIVATE KEY-----
MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQg...
(multiple lines)
...
-----END PRIVATE KEY-----
```

Paste this entire block as the value for `APPLE_PRIVATE_KEY`.

### 4.2 Get Your Supabase Project URL and Anon Key
1. Go to **Project Settings** → **API**
2. Copy these values:
   - **Project URL** (e.g., `https://abcdefghij.supabase.co`)
   - **anon public** key

---

## Step 5: Run Database Migrations

### 5.1 Update Migration with Your Project URL
Edit [supabase/migrations/005_activate_push_notifications.sql](supabase/migrations/005_activate_push_notifications.sql):

Find this line:
```sql
supabase_url := 'https://YOUR_PROJECT_ID.supabase.co';
```

Replace with your actual Supabase project URL.

### 5.2 Run the Migration
In Supabase Dashboard:
1. Go to **SQL Editor**
2. Click **New Query**
3. Copy the contents of `005_activate_push_notifications.sql`
4. Paste and click **Run**

You should see success messages in the results.

---

## Step 6: Test Push Notifications

### 6.1 Build and Run the App
```bash
# Clean build for iOS Simulator
xcodebuild -scheme doodleduo -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' clean build

# Or just run in Xcode with Cmd+R
```

### 6.2 Grant Notification Permissions
When the app asks for notification permissions, tap **Allow**.

### 6.3 Check Device Token Registration
In Xcode console, look for:
```
📱 Registering device token: a1b2c3d4e5f6...
✅ Device token registered successfully
```

### 6.4 Verify in Database
In Supabase SQL Editor:
```sql
-- Check if your device token was saved
SELECT * FROM device_tokens WHERE platform = 'ios';
```

You should see your device token listed.

### 6.5 Send a Test Activity
1. Keep the app open
2. Have your partner (or yourself in another simulator) send a ping/note/doodle
3. Check Supabase **Logs** → **Functions**
4. You should see the `send-push-notification` function being called

### 6.6 Test with App Fully Closed
1. **Close the app completely** (swipe up from app switcher)
2. Have your partner send an activity
3. **You should get a push notification!**
4. The notification should appear on your lock screen
5. The widget should update with the new activity

---

## Troubleshooting

### No device token in console
**Problem**: You don't see "Device token registered successfully"

**Solutions**:
- Make sure you granted notification permissions
- Check that Push Notifications capability is enabled in Xcode
- Rebuild and reinstall the app

### Edge function returns 401 or 403
**Problem**: Database trigger can't call the edge function

**Solutions**:
```sql
-- Grant permissions to pg_net
GRANT USAGE ON SCHEMA net TO postgres, anon, authenticated, service_role;
```

### APNs returns "Invalid token"
**Problem**: JWT authentication failing

**Solutions**:
- Double-check your `APPLE_TEAM_ID` and `APPLE_KEY_ID`
- Make sure `APPLE_PRIVATE_KEY` includes the full PEM format (including headers)
- Verify your Team ID matches the one in your Apple Developer account

### Notifications work in simulator but not on device
**Problem**: Using sandbox APNs with production build

**Solutions**:
- For development builds: `APNS_PRODUCTION=false`
- For TestFlight/App Store: `APNS_PRODUCTION=true`
- Make sure your provisioning profile includes Push Notifications entitlement

### Database trigger not firing
**Problem**: Activities created but no push sent

**Check**:
```sql
-- Test the trigger manually
SELECT * FROM test_push_notification_setup(
  (SELECT room_id FROM duo_memberships WHERE profile_id = auth.uid())
);
```

Should return:
- `member_count`: 2
- `device_token_found`: true
- `setup_status`: "Ready for push notifications"

---

## What Happens Now

### When App is Open
✅ Instant real-time updates (via polling every 10 seconds)
✅ Local notifications appear
✅ Widget updates immediately

### When App is in Background (not closed)
✅ Push notifications arrive
✅ Widget updates
✅ App can process notifications silently

### When App is Fully Closed
✅ Push notifications wake the device
✅ Notification appears on lock screen
✅ Widget updates when notification arrives
✅ Tapping notification opens the app

---

## Cost Considerations

- **Supabase Edge Functions**: 500K requests/month free, then $2 per 1M requests
- **APNs**: Completely free, unlimited notifications
- **Database triggers**: Part of your Supabase plan (no extra cost)

For a typical couple using the app:
- ~50-100 activities per day = 1,500-3,000 notifications/month
- **Well within free tier** 🎉

---

## Production Checklist

Before submitting to App Store:

- [ ] Set `APNS_PRODUCTION=true` in Supabase environment variables
- [ ] Update `aps-environment` to `production` in entitlements
- [ ] Test with TestFlight build first
- [ ] Verify push notifications work on physical devices
- [ ] Update database trigger URL if using custom domain
- [ ] Enable pg_net extension in production database

---

## Quick Reference Commands

```bash
# Deploy edge function
supabase functions deploy send-push-notification

# Check function logs
supabase functions logs send-push-notification

# Test database setup
# (Run in Supabase SQL Editor)
SELECT * FROM test_push_notification_setup('YOUR_ROOM_ID'::UUID);

# Check device tokens
SELECT * FROM device_tokens WHERE platform = 'ios';

# View recent activities
SELECT * FROM duo_activities ORDER BY created_at DESC LIMIT 10;
```

---

## Summary

Your app now has **complete push notification infrastructure**:

1. ✅ **Edge Function** - Sends APNs notifications with proper JWT auth
2. ✅ **Database Trigger** - Automatically detects new activities and calls edge function
3. ✅ **Device Registration** - App registers device tokens with Supabase
4. ✅ **Background Handling** - App properly handles notifications when closed
5. ✅ **Widget Integration** - Widget updates when notifications arrive

**Next steps**: Follow this guide to get your APNs certificate and deploy the edge function. Once configured, notifications will work even when the app is completely closed!
