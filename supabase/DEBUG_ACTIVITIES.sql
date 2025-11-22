-- ================================================
-- DEBUG ACTIVITIES TABLE
-- Check if activities exist and RLS is correct
-- ================================================

-- 1. Check if there are any activities
SELECT 'Total activities in database:' as check_type, COUNT(*) as count
FROM public.duo_activities;

-- 2. Check RLS status
SELECT 'RLS enabled:' as check_type, rowsecurity::text as status
FROM pg_tables
WHERE tablename = 'duo_activities';

-- 3. Check policies
SELECT
    policyname,
    cmd,
    roles::text,
    qual::text as using_clause,
    with_check::text
FROM pg_policies
WHERE tablename = 'duo_activities'
ORDER BY policyname;

-- 4. Sample some activities (if any)
SELECT
    id,
    room_id,
    author_id,
    activity_type,
    created_at
FROM public.duo_activities
ORDER BY created_at DESC
LIMIT 5;

-- 5. Check if current user can see activities
SELECT 'Activities visible to authenticated user:' as check_type, COUNT(*) as count
FROM public.duo_activities
WHERE EXISTS (
    SELECT 1 FROM public.duo_memberships dm
    WHERE dm.room_id = duo_activities.room_id
);
