-- ================================================
-- FINAL WAITLIST FIX
-- This adds FORCE ROW LEVEL SECURITY which applies to table owner too
-- ================================================

BEGIN;

-- Drop existing policies completely
DROP POLICY IF EXISTS "waitlist_insert_policy" ON public.waitlist;
DROP POLICY IF EXISTS "waitlist_select_policy" ON public.waitlist;
DROP POLICY IF EXISTS "Enable insert for all users" ON public.waitlist;
DROP POLICY IF EXISTS "Enable select for authenticated users only" ON public.waitlist;

-- Disable RLS temporarily
ALTER TABLE public.waitlist DISABLE ROW LEVEL SECURITY;

-- Re-enable with FORCE (this is key - it applies RLS even to table owner)
ALTER TABLE public.waitlist ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.waitlist FORCE ROW LEVEL SECURITY;

-- Create the most permissive INSERT policy possible
CREATE POLICY "waitlist_anon_insert"
    ON public.waitlist
    AS PERMISSIVE
    FOR INSERT
    TO PUBLIC
    WITH CHECK (true);

-- Create SELECT policy for authenticated users
CREATE POLICY "waitlist_authenticated_select"
    ON public.waitlist
    AS PERMISSIVE
    FOR SELECT
    TO authenticated
    USING (true);

-- Ensure grants are correct
REVOKE ALL ON public.waitlist FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT INSERT ON public.waitlist TO anon;
GRANT SELECT ON public.waitlist TO authenticated;
GRANT ALL ON public.waitlist TO postgres;

COMMIT;

-- Test it
SELECT 'Testing insert as anon role...' as test_status;

SET ROLE anon;
INSERT INTO public.waitlist (email, created_at)
VALUES ('test_final_' || gen_random_uuid()::text || '@example.com', now())
RETURNING 'SUCCESS! ✅' as result, email;
RESET ROLE;
