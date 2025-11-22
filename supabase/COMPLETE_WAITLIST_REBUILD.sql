-- ================================================
-- COMPLETE WAITLIST REBUILD
-- Drop everything and rebuild from absolute scratch
-- ================================================

BEGIN;

-- 1. Drop the table completely
DROP TABLE IF EXISTS public.waitlist CASCADE;

-- 2. Recreate the table
CREATE TABLE public.waitlist (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    referral_source TEXT,
    user_agent TEXT,
    ip_address INET
);

-- 3. Create indexes
CREATE INDEX idx_waitlist_email ON public.waitlist(email);
CREATE INDEX idx_waitlist_created_at ON public.waitlist(created_at DESC);

-- 4. DO NOT ENABLE RLS YET - Grant permissions first
GRANT USAGE ON SCHEMA public TO anon, authenticated, postgres;
GRANT ALL PRIVILEGES ON TABLE public.waitlist TO postgres;
GRANT INSERT, SELECT ON TABLE public.waitlist TO anon;
GRANT ALL ON TABLE public.waitlist TO authenticated;

-- 5. Now enable RLS
ALTER TABLE public.waitlist ENABLE ROW LEVEL SECURITY;

-- 6. Create policies AFTER grants
CREATE POLICY "waitlist_insert_for_anon"
    ON public.waitlist
    FOR INSERT
    TO anon
    WITH CHECK (true);

CREATE POLICY "waitlist_insert_for_authenticated"
    ON public.waitlist
    FOR INSERT
    TO authenticated
    WITH CHECK (true);

CREATE POLICY "waitlist_select_for_authenticated"
    ON public.waitlist
    FOR SELECT
    TO authenticated
    USING (true);

-- 7. Also allow service_role (just in case)
GRANT ALL ON public.waitlist TO service_role;

COMMIT;

-- 8. Verify the setup
SELECT
    'Table created: ' || tablename as status,
    'RLS enabled: ' || rowsecurity::text as rls_status,
    'Owner: ' || tableowner as owner
FROM pg_tables
WHERE tablename = 'waitlist' AND schemaname = 'public';

SELECT
    policyname,
    cmd,
    roles::text as applies_to
FROM pg_policies
WHERE tablename = 'waitlist'
ORDER BY policyname;

SELECT
    grantee,
    string_agg(privilege_type, ', ') as privileges
FROM information_schema.table_privileges
WHERE table_name = 'waitlist' AND table_schema = 'public'
GROUP BY grantee
ORDER BY grantee;
