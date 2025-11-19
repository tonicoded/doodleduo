-- ================================================
-- DoodleDuo Waitlist - RLS Fix
-- Run this to fix the RLS policy issue
-- ================================================

-- Drop ALL existing policies first
DROP POLICY IF EXISTS "Anyone can join waitlist" ON public.waitlist;
DROP POLICY IF EXISTS "Anonymous users can join waitlist" ON public.waitlist;
DROP POLICY IF EXISTS "Authenticated users can join waitlist" ON public.waitlist;
DROP POLICY IF EXISTS "Only authenticated users can view waitlist" ON public.waitlist;

-- Create a single permissive INSERT policy that works with all roles
CREATE POLICY "Enable insert access for all users"
    ON public.waitlist
    FOR INSERT
    WITH CHECK (true);

-- Allow authenticated users to read
CREATE POLICY "Enable read access for authenticated users"
    ON public.waitlist
    FOR SELECT
    TO authenticated
    USING (true);

-- Verify RLS is enabled
ALTER TABLE public.waitlist ENABLE ROW LEVEL SECURITY;

-- Test query (should work)
-- INSERT INTO public.waitlist (email) VALUES ('test@example.com');
