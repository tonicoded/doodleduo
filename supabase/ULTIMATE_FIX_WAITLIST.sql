-- ================================================
-- ULTIMATE FIX - Completely bypass and rebuild
-- ================================================

BEGIN;

-- 1. Disable RLS temporarily to clear everything
ALTER TABLE IF EXISTS public.waitlist DISABLE ROW LEVEL SECURITY;

-- 2. Drop ALL policies
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT policyname FROM pg_policies WHERE tablename = 'waitlist') LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || r.policyname || '" ON public.waitlist';
    END LOOP;
END $$;

-- 3. Drop and recreate the table
DROP TABLE IF EXISTS public.waitlist CASCADE;

CREATE TABLE public.waitlist (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    referral_source TEXT,
    user_agent TEXT,
    ip_address INET
);

-- 4. Add indexes
CREATE INDEX idx_waitlist_email ON public.waitlist(email);
CREATE INDEX idx_waitlist_created_at ON public.waitlist(created_at DESC);

-- 5. Grant permissions FIRST (before enabling RLS)
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL PRIVILEGES ON public.waitlist TO anon;
GRANT ALL PRIVILEGES ON public.waitlist TO authenticated;
GRANT ALL PRIVILEGES ON public.waitlist TO postgres;

-- 6. Enable RLS
ALTER TABLE public.waitlist ENABLE ROW LEVEL SECURITY;

-- 7. Create INSERT policy for everyone (no role restriction)
CREATE POLICY "Enable insert for all users"
    ON public.waitlist
    FOR INSERT
    WITH CHECK (true);

-- 8. Create SELECT policy for authenticated only
CREATE POLICY "Enable select for authenticated users only"
    ON public.waitlist
    FOR SELECT
    TO authenticated
    USING (true);

-- 9. Force apply to anon role explicitly
ALTER TABLE public.waitlist FORCE ROW LEVEL SECURITY;

COMMIT;

-- 10. Verify everything
SELECT 'Setup complete. Checking configuration...' as status;

SELECT
    'RLS Enabled: ' || rowsecurity::text as check_1
FROM pg_tables
WHERE tablename = 'waitlist';

SELECT
    policyname,
    cmd,
    roles::text,
    with_check::text
FROM pg_policies
WHERE tablename = 'waitlist';

-- 11. Test insert as anon
DO $$
BEGIN
    EXECUTE 'SET ROLE anon';
    INSERT INTO public.waitlist (email) VALUES ('test_' || gen_random_uuid()::text || '@test.com');
    EXECUTE 'RESET ROLE';
    RAISE NOTICE 'SUCCESS: Anonymous insert test passed!';
EXCEPTION WHEN OTHERS THEN
    EXECUTE 'RESET ROLE';
    RAISE NOTICE 'FAILED: Anonymous insert test failed: %', SQLERRM;
END $$;
