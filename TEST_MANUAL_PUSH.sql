-- Manual Push Notification Test
-- This will send a test push notification to YOUR device right now
-- Make sure to CLOSE the app completely before running this!

-- Step 1: Get your device token and user ID
SELECT
    'Your User ID: ' || user_id::text as info,
    'Device Token: ' || device_token as token
FROM device_tokens
WHERE user_id = auth.uid()
AND platform = 'ios'
LIMIT 1;

-- Step 2: Send a test push notification
-- CLOSE THE APP COMPLETELY ON YOUR IPHONE FIRST!
-- Then run this:

DO $$
DECLARE
    v_device_token TEXT;
    v_user_id UUID;
    v_room_id UUID;
    response_id BIGINT;
BEGIN
    -- Get your device token
    SELECT device_token, user_id
    INTO v_device_token, v_user_id
    FROM device_tokens
    WHERE user_id = auth.uid()
    AND platform = 'ios'
    LIMIT 1;

    -- Get your room ID
    SELECT room_id
    INTO v_room_id
    FROM duo_memberships
    WHERE profile_id = auth.uid()
    LIMIT 1;

    IF v_device_token IS NULL THEN
        RAISE NOTICE '❌ No device token found! Make sure the app registered your token.';
        RETURN;
    END IF;

    RAISE NOTICE '📱 Sending test push notification to device token: %', v_device_token;
    RAISE NOTICE '👤 User ID: %', v_user_id;
    RAISE NOTICE '🏠 Room ID: %', v_room_id;

    -- Call the edge function to send push notification
    SELECT net.http_post(
        url := 'https://reevrasmalgiftakwsao.supabase.co/functions/v1/send-push-notification',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJlZXZyYXNtYWxnaWZ0YWt3c2FvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMzMTgzNzgsImV4cCI6MjA3ODg5NDM3OH0.PRq3XALuaA5ZSsdhfn7h861xFLKc9Z_F4yPlk4mOPNc'
        ),
        body := jsonb_build_object(
            'device_token', v_device_token,
            'activity_type', 'ping',
            'content', 'Test notification - push is working! 🎉',
            'room_id', COALESCE(v_room_id::text, 'test-room'),
            'partner_name', 'Test System'
        )
    ) INTO response_id;

    RAISE NOTICE '✅ Push notification sent! Response ID: %', response_id;
    RAISE NOTICE '📲 Check your iPhone - you should see a notification!';
    RAISE NOTICE '';
    RAISE NOTICE 'If you don''t see it:';
    RAISE NOTICE '1. Make sure the app is COMPLETELY CLOSED (swipe up from app switcher)';
    RAISE NOTICE '2. Check Supabase Edge Function logs for errors';
    RAISE NOTICE '3. Make sure APPLE_PRIVATE_KEY secret is formatted correctly';

EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '❌ Error: %', SQLERRM;
END $$;
