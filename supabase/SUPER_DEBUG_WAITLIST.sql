-- ================================================
-- SUPER DEBUG - Check EVERYTHING about waitlist
-- ================================================

-- 1. Check RLS status
SELECT 'RLS Status:' as check_type;
SELECT
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename = 'waitlist';

-- 2. Check ALL policies with full details
SELECT '---' as separator;
SELECT 'Policies:' as check_type;
SELECT
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual as using_clause,
    with_check as with_check_clause
FROM pg_policies
WHERE tablename = 'waitlist';

-- 3. Check grants
SELECT '---' as separator;
SELECT 'Table Grants:' as check_type;
SELECT
    grantee,
    privilege_type
FROM information_schema.table_privileges
WHERE table_schema = 'public'
  AND table_name = 'waitlist'
ORDER BY grantee, privilege_type;

-- 4. Check table owner
SELECT '---' as separator;
SELECT 'Table Owner:' as check_type;
SELECT
    schemaname,
    tablename,
    tableowner
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename = 'waitlist';

-- 5. Try to insert as different roles
SELECT '---' as separator;
SELECT 'Testing INSERT as current user:' as check_type;

-- Test 1: Direct insert (should work as postgres/admin)
INSERT INTO public.waitlist (email, created_at)
VALUES ('test_' || gen_random_uuid()::text || '@test.com', now())
RETURNING 'SUCCESS: Direct insert worked' as result, email;

-- 6. Check if there are any other policies or constraints
SELECT '---' as separator;
SELECT 'Constraints:' as check_type;
SELECT
    conname as constraint_name,
    contype as constraint_type,
    pg_get_constraintdef(oid) as definition
FROM pg_constraint
WHERE conrelid = 'public.waitlist'::regclass;
