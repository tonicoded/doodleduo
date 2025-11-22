-- ================================================
-- DISABLE RLS FOR WAITLIST
-- Since this is a public signup form, RLS might not be needed
-- ================================================

BEGIN;

-- Simply disable RLS for the waitlist table
ALTER TABLE public.waitlist DISABLE ROW LEVEL SECURITY;

-- Ensure anon can insert
GRANT INSERT ON public.waitlist TO anon;
GRANT SELECT ON public.waitlist TO authenticated;

COMMIT;

SELECT 'RLS disabled for waitlist table' as status;

-- Verify
SELECT
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables
WHERE tablename = 'waitlist' AND schemaname = 'public';
