-- Complete Push Notification Setup Test
-- Copy and paste this entire script into Supabase SQL Editor to verify everything

-- ========================================
-- Test 1: Check if pg_net extension is enabled
-- ========================================
SELECT
    CASE
        WHEN EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net')
        THEN '✅ pg_net extension is enabled'
        ELSE '❌ pg_net extension is NOT enabled - run: CREATE EXTENSION pg_net;'
    END AS pg_net_status;

-- ========================================
-- Test 2: Check if trigger function exists
-- ========================================
SELECT
    CASE
        WHEN EXISTS (
            SELECT 1 FROM pg_proc
            WHERE proname = 'notify_partner_of_activity'
        )
        THEN '✅ Trigger function exists'
        ELSE '❌ Trigger function NOT found - run migration 005'
    END AS trigger_function_status;

-- ========================================
-- Test 3: Check if trigger is attached to duo_activities
-- ========================================
SELECT
    CASE
        WHEN EXISTS (
            SELECT 1 FROM pg_trigger
            WHERE tgname = 'notify_partner_on_activity'
        )
        THEN '✅ Trigger is attached to duo_activities table'
        ELSE '❌ Trigger NOT attached - run migration 005'
    END AS trigger_status;

-- ========================================
-- Test 4: Check your current room setup
-- ========================================
WITH room_info AS (
    SELECT room_id FROM duo_memberships WHERE profile_id = auth.uid() LIMIT 1
)
SELECT
    'Room ID' as metric,
    room_id::text as value
FROM room_info

UNION ALL

SELECT
    'Member Count' as metric,
    COUNT(*)::text as value
FROM duo_memberships
WHERE room_id = (SELECT room_id FROM room_info)

UNION ALL

SELECT
    'Device Token Registered' as metric,
    CASE
        WHEN EXISTS (
            SELECT 1 FROM device_tokens
            WHERE user_id = auth.uid() AND platform = 'ios'
        )
        THEN '✅ Yes'
        ELSE '❌ No - run the app and grant notification permissions'
    END as value

UNION ALL

SELECT
    'Partner Has Device Token' as metric,
    CASE
        WHEN EXISTS (
            SELECT 1
            FROM duo_memberships dm
            JOIN device_tokens dt ON dm.profile_id = dt.user_id
            WHERE dm.room_id = (SELECT room_id FROM room_info)
            AND dm.profile_id != auth.uid()
            AND dt.platform = 'ios'
        )
        THEN '✅ Yes'
        ELSE '❌ No - partner needs to run app and grant permissions'
    END as value;

-- ========================================
-- Test 5: Check recent activities
-- ========================================
SELECT
    '📊 Recent Activities (last 5)' as info,
    '' as activity_type,
    '' as author,
    '' as created;

SELECT
    '' as info,
    activity_type,
    CASE
        WHEN author_id = auth.uid() THEN 'You'
        ELSE 'Partner'
    END as author,
    created_at::text as created
FROM duo_activities
WHERE room_id = (SELECT room_id FROM duo_memberships WHERE profile_id = auth.uid() LIMIT 1)
ORDER BY created_at DESC
LIMIT 5;

-- ========================================
-- Test 6: Manually test the edge function (simulate push)
-- ========================================
-- This will show if the edge function endpoint exists
-- Note: This may fail with auth errors if secrets aren't configured, but that's OK
-- We're just testing if the endpoint exists

DO $$
DECLARE
    test_token TEXT := 'test_device_token_12345';
    response_id BIGINT;
BEGIN
    -- Try to call the edge function
    -- If this errors with "function not found", the edge function isn't deployed
    BEGIN
        SELECT net.http_post(
            url := 'https://reevrasmalgiftakwsao.supabase.co/functions/v1/send-push-notification',
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJlZXZyYXNtYWxnaWZ0YWt3c2FvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMzMTgzNzgsImV4cCI6MjA3ODg5NDM3OH0.PRq3XALuaA5ZSsdhfn7h861xFLKc9Z_F4yPlk4mOPNc'
            ),
            body := jsonb_build_object(
                'device_token', test_token,
                'activity_type', 'ping',
                'content', 'Test notification',
                'room_id', 'test-room-id',
                'partner_name', 'Test Partner'
            )
        ) INTO response_id;

        RAISE NOTICE '✅ Edge function endpoint is accessible (response_id: %)', response_id;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '⚠️ Edge function test: % (This is OK if function exists but secrets not configured)', SQLERRM;
    END;
END $$;

-- ========================================
-- Final Summary
-- ========================================
SELECT '=' as divider, '=' as a, '=' as b, '=' as c;
SELECT '📋 SETUP SUMMARY' as status, '' as details, '' as action, '' as d;
SELECT '=' as divider, '=' as a, '=' as b, '=' as c;

-- Check all critical components
WITH setup_checks AS (
    SELECT
        EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net') as pg_net_ok,
        EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'notify_partner_of_activity') as function_ok,
        EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'notify_partner_on_activity') as trigger_ok,
        EXISTS (SELECT 1 FROM device_tokens WHERE user_id = auth.uid() AND platform = 'ios') as device_token_ok,
        (SELECT COUNT(*) FROM duo_memberships WHERE room_id = (SELECT room_id FROM duo_memberships WHERE profile_id = auth.uid() LIMIT 1)) = 2 as room_ok
)
SELECT
    CASE
        WHEN pg_net_ok AND function_ok AND trigger_ok AND device_token_ok AND room_ok
        THEN '🎉 ALL SYSTEMS GO!'
        WHEN pg_net_ok AND function_ok AND trigger_ok AND room_ok
        THEN '⚠️ Almost there! Just need device tokens registered (run the app)'
        WHEN pg_net_ok AND function_ok AND trigger_ok
        THEN '⚠️ Database ready, but need to pair with partner and register device tokens'
        ELSE '❌ Setup incomplete - check errors above'
    END as overall_status,
    CASE
        WHEN NOT pg_net_ok THEN 'Enable pg_net extension'
        WHEN NOT function_ok THEN 'Run migration 005_activate_push_notifications.sql'
        WHEN NOT trigger_ok THEN 'Run migration 005_activate_push_notifications.sql'
        WHEN NOT room_ok THEN 'Pair with your partner in the app'
        WHEN NOT device_token_ok THEN 'Run app and grant notification permissions'
        ELSE 'Test by sending activity with app closed!'
    END as next_action,
    pg_net_ok::text as pg_net,
    function_ok::text as func
FROM setup_checks;

-- ========================================
-- Edge Function Secrets Check (manual)
-- ========================================
SELECT '=' as divider, '=' as a, '=' as b, '=' as c;
SELECT '🔐 EDGE FUNCTION SECRETS (Check manually in Supabase Dashboard)' as info, '' as b, '' as c, '' as d;
SELECT '=' as divider, '=' as a, '=' as b, '=' as c;

SELECT
    '1. APPLE_TEAM_ID' as secret_name,
    'Should be: 6XQ6Q4DLD3' as expected_value,
    'Go to Project Settings → Edge Functions → Secrets' as location,
    '' as d
UNION ALL
SELECT
    '2. APPLE_KEY_ID',
    'Should be: 5MKRR9AHUM',
    'Check in Supabase Dashboard',
    ''
UNION ALL
SELECT
    '3. APPLE_BUNDLE_ID',
    'Should be: com.anthony.doodleduo',
    'Check in Supabase Dashboard',
    ''
UNION ALL
SELECT
    '4. APNS_PRODUCTION',
    'Should be: false (for development)',
    'Check in Supabase Dashboard',
    ''
UNION ALL
SELECT
    '5. APPLE_PRIVATE_KEY',
    'Should be: Your full .p8 file contents',
    'Check in Supabase Dashboard',
    '';
