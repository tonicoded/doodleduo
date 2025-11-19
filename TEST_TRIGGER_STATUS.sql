-- TEST: Check if duo_activities table exists and trigger is set up correctly
-- Run this to diagnose the push notification trigger issue

-- Step 1: Check if duo_activities table exists
SELECT
    table_name,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'duo_activities'
ORDER BY ordinal_position;

-- Step 2: Check if the trigger exists
SELECT
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement
FROM information_schema.triggers
WHERE trigger_schema = 'public'
  AND event_object_table = 'duo_activities';

-- Step 3: Check if the trigger function exists
SELECT
    routine_name,
    routine_type,
    routine_definition
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name = 'notify_partner_of_activity';

-- Step 4: Check if there are any duo_activities records
SELECT
    COUNT(*) as total_activities,
    MAX(created_at) as most_recent_activity
FROM public.duo_activities;

-- Step 5: Check recent activities (last 10)
SELECT
    id,
    room_id,
    author_id,
    activity_type,
    LEFT(content, 50) as content_preview,
    created_at
FROM public.duo_activities
ORDER BY created_at DESC
LIMIT 10;

-- Step 6: Check if pg_net extension is enabled (required for calling edge function)
SELECT
    extname,
    extversion
FROM pg_extension
WHERE extname = 'pg_net';
