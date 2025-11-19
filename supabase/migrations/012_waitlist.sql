-- ================================================
-- DoodleDuo Beta Waitlist Table
-- ================================================

BEGIN;

-- Create waitlist table for beta signups
CREATE TABLE IF NOT EXISTS public.waitlist (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    referral_source TEXT,
    user_agent TEXT,
    ip_address INET
);

-- Add index for faster email lookups
CREATE INDEX IF NOT EXISTS idx_waitlist_email ON public.waitlist(email);
CREATE INDEX IF NOT EXISTS idx_waitlist_created_at ON public.waitlist(created_at DESC);

-- Enable RLS (but allow anonymous inserts for waitlist)
ALTER TABLE public.waitlist ENABLE ROW LEVEL SECURITY;

-- Policy: Allow anonymous users to insert (for public signup)
CREATE POLICY "Anonymous users can join waitlist"
    ON public.waitlist
    FOR INSERT
    TO anon
    WITH CHECK (true);

-- Policy: Allow authenticated users to insert as well
CREATE POLICY "Authenticated users can join waitlist"
    ON public.waitlist
    FOR INSERT
    TO authenticated
    WITH CHECK (true);

-- Policy: Only authenticated users/admins can read waitlist
CREATE POLICY "Only authenticated users can view waitlist"
    ON public.waitlist
    FOR SELECT
    TO authenticated
    USING (true);

COMMENT ON TABLE public.waitlist IS 'Beta waitlist signups for DoodleDuo website';
COMMENT ON COLUMN public.waitlist.email IS 'User email address for beta access notification';
COMMENT ON COLUMN public.waitlist.referral_source IS 'Optional tracking for where user found the site';

COMMIT;

-- Status output
DO $$
BEGIN
    RAISE NOTICE '✅ Waitlist table created';
    RAISE NOTICE '✅ RLS policies configured for anonymous inserts';
    RAISE NOTICE '🎉 Ready for beta signups!';
END $$;
