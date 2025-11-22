-- ================================================
-- TEST ANONYMOUS INSERT
-- This simulates what your website does
-- ================================================

-- First, let's try to set role to anon and test
SET ROLE anon;

-- Try to insert
INSERT INTO public.waitlist (email, created_at)
VALUES ('test_anon_' || gen_random_uuid()::text || '@test.com', now());

-- Reset role
RESET ROLE;

SELECT 'If you see this, the INSERT worked!' as status;
