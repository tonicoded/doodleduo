-- Check what tables and columns already exist

SELECT
    table_name,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name IN ('duo_metrics', 'duo_farms', 'duos', 'duo_members')
ORDER BY table_name, ordinal_position;
