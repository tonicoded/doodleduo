-- ================================================
-- TEMPORARY: Disable RLS to test if that's the issue
-- ================================================

-- Disable RLS on waitlist table
ALTER TABLE public.waitlist DISABLE ROW LEVEL SECURITY;

-- Now try the form - it should work!
-- If it works, we know RLS is the problem
-- If it still fails, there's another issue

SELECT 'RLS DISABLED - Try the form now!' as status;
