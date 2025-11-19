# Push Notifications Setup Guide

## Current Status ✅
- ✅ App registers for remote notifications
- ✅ Device tokens are saved to database
- ✅ Database trigger detects new activities
- ✅ Widget refreshes when notifications arrive
- ⏳ **Missing**: APNs certificates + actual push sending

## Quick Setup Steps

### 1. Run the Database Migration
In your Supabase SQL Editor, run:
```sql
-- Copy and paste the contents of:
-- supabase/migrations/004_update_push_trigger.sql
```

### 2. Test the Setup
After running the migration, test your room setup:
```sql
-- Replace YOUR_ROOM_ID with your actual duo room ID
SELECT * FROM test_push_notification_setup('YOUR_ROOM_ID'::UUID);
```

This should show:
- `member_count`: 2
- `partner_found`: true
- `device_token_found`: true (after running the app)
- `setup_status`: "Ready for push notifications"

### 3. Enable Real Push Notifications

#### Option A: Simplified (No APNs certificates needed)
For testing, the app will show notifications when it's running. When closed, iOS will limit widget updates but the infrastructure is ready.

#### Option B: Full APNs Setup (Real push notifications)
1. **Get APNs Certificate**:
   - Go to Apple Developer Console
   - Create APNs certificate for `com.anthony.doodleduo`
   - Download the .p8 key file

2. **Configure Supabase**:
   - Go to your Supabase project settings
   - Add environment variables:
     ```
     APPLE_TEAM_ID=your_team_id
     APPLE_KEY_ID=your_key_id  
     APPLE_BUNDLE_ID=com.anthony.doodleduo
     APPLE_PRIVATE_KEY=contents_of_p8_file
     ```

3. **Deploy Edge Function**:
   ```bash
   supabase functions deploy send-push-notification
   ```

4. **Enable the trigger**:
   In the database trigger function, uncomment these lines:
   ```sql
   PERFORM net.http_post(
       url := 'https://YOUR_PROJECT_ID.supabase.co/functions/v1/send-push-notification',
       headers := jsonb_build_object(
           'Content-Type', 'application/json',
           'Authorization', 'Bearer ' || 'YOUR_SERVICE_ROLE_KEY'
       ),
       body := notification_payload
   );
   ```

## How It Currently Works

### When App Is Open:
- ✅ Real-time notifications work perfectly
- ✅ Widget updates immediately  
- ✅ All activity types supported

### When App Is Closed:
- ✅ Device tokens are registered
- ✅ Database detects new activities
- ⏳ Push notifications ready (need APNs setup)
- ⏳ Widget updates when push arrives (iOS permitting)

## Testing

1. **Build and run the app**
2. **Grant notification permissions**
3. **Check console for**: "✅ Device token registered successfully"
4. **Send an activity to your partner**
5. **Check Supabase logs** for: "Sending push notification: ..."

## Debug Commands

Check if device token is saved:
```sql
SELECT * FROM device_tokens WHERE user_id = auth.uid();
```

Check recent activities:
```sql
SELECT * FROM duo_activities ORDER BY created_at DESC LIMIT 5;
```

Check your room setup:
```sql
SELECT * FROM test_push_notification_setup(
  (SELECT room_id FROM duo_memberships WHERE profile_id = auth.uid())
);
```

## Summary

**Current state**: App has complete push notification infrastructure. Real-time notifications work when app is open. For true background notifications, you need APNs certificates (Option B above).

**For development**: The current setup provides excellent real-time experience and widget updates. Most users keep apps in background (not fully closed) so notifications will work in most cases.