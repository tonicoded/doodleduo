-- ================================================
-- FIX WAITLIST RLS POLICY
-- Allows anonymous users to insert to waitlist
-- ================================================

-- Drop existing policies
DROP POLICY IF EXISTS "waitlist_insert_policy" ON public.waitlist;
DROP POLICY IF EXISTS "waitlist_select_policy" ON public.waitlist;

-- Create INSERT policy that allows ANYONE (including anonymous) to insert
CREATE POLICY "waitlist_insert_policy"
    ON public.waitlist
    FOR INSERT
    WITH CHECK (true);

-- Create SELECT policy for authenticated users only
CREATE POLICY "waitlist_select_policy"
    ON public.waitlist
    FOR SELECT
    TO authenticated
    USING (true);

-- Ensure the table has RLS enabled
ALTER TABLE public.waitlist ENABLE ROW LEVEL SECURITY;

-- Grant explicit permissions to anonymous role
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT INSERT ON public.waitlist TO anon, authenticated;
GRANT SELECT ON public.waitlist TO authenticated;

SELECT '✅ Waitlist RLS policy fixed - anonymous users can now insert!' as status;
