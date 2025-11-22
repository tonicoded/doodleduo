-- ================================================
-- CHECK FOR BACKUP DATA
-- See if there's a backup table we can restore from
-- ================================================

-- Check if we created a backup table earlier
SELECT
    tablename,
    'Found backup table!' as status
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename LIKE '%waitlist%'
ORDER BY tablename;

-- If waitlist_backup exists, show the data
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'waitlist_backup' AND schemaname = 'public') THEN
        RAISE NOTICE 'Backup table exists! Showing data...';
    ELSE
        RAISE NOTICE 'No backup table found.';
    END IF;
END $$;

-- Show any waitlist-related tables
SELECT
    table_name,
    (SELECT COUNT(*) FROM information_schema.columns WHERE table_name = t.table_name) as column_count
FROM information_schema.tables t
WHERE table_schema = 'public'
  AND table_name LIKE '%waitlist%';
