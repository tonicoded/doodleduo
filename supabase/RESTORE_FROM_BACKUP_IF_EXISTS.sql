-- ================================================
-- RESTORE WAITLIST FROM BACKUP (if it exists)
-- ================================================

-- First, check if backup exists and show the data
SELECT 'Checking for backup...' as status;

DO $$
DECLARE
    backup_count INTEGER;
BEGIN
    -- Check if backup table exists
    IF EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'public'
        AND table_name = 'waitlist_backup'
    ) THEN
        -- Count records in backup
        SELECT COUNT(*) INTO backup_count FROM waitlist_backup;
        RAISE NOTICE 'Found backup with % records', backup_count;

        -- Restore from backup
        INSERT INTO public.waitlist (email, created_at, referral_source, user_agent, ip_address)
        SELECT email, created_at, referral_source, user_agent, ip_address
        FROM waitlist_backup
        ON CONFLICT (email) DO NOTHING;

        RAISE NOTICE 'Restored % records from backup!', backup_count;
    ELSE
        RAISE NOTICE 'No backup table found. Data may be lost.';
        RAISE NOTICE 'Check Supabase dashboard for point-in-time recovery options.';
    END IF;
END $$;

-- Show current waitlist count
SELECT
    COUNT(*) as current_waitlist_count,
    MIN(created_at) as oldest_signup,
    MAX(created_at) as newest_signup
FROM public.waitlist;
