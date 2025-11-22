-- ================================================
-- NUCLEAR FIX for Waitlist RLS Issue
-- This completely recreates the table with correct policies
-- IDENTICAL to migration 013 that was working
-- ================================================

BEGIN;

-- Drop the entire table and start fresh
DROP TABLE IF EXISTS public.waitlist CASCADE;

-- Recreate table
CREATE TABLE public.waitlist (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    referral_source TEXT,
    user_agent TEXT,
    ip_address INET
);

-- Add indexes
CREATE INDEX idx_waitlist_email ON public.waitlist(email);
CREATE INDEX idx_waitlist_created_at ON public.waitlist(created_at DESC);

-- Enable RLS
ALTER TABLE public.waitlist ENABLE ROW LEVEL SECURITY;

-- Create ONE simple policy for INSERT (no role restriction)
CREATE POLICY "waitlist_insert_policy"
    ON public.waitlist
    FOR INSERT
    WITH CHECK (true);

-- Create policy for SELECT (authenticated only)
CREATE POLICY "waitlist_select_policy"
    ON public.waitlist
    FOR SELECT
    TO authenticated
    USING (true);

-- Add comments
COMMENT ON TABLE public.waitlist IS 'Beta waitlist signups for DoodleDuo website';

-- Grant permissions explicitly
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON public.waitlist TO anon, authenticated;

COMMIT;

SELECT 'Waitlist table recreated successfully!' as status;

-- Verify the setup
SELECT 'Checking policies...' as status;
SELECT policyname, cmd, roles FROM pg_policies WHERE tablename = 'waitlist';
