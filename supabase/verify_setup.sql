-- Quick verification - run this to check if setup worked

-- 1. Check tables exist
SELECT 'Tables created' as status;
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
AND table_name IN ('doodles', 'duo_metrics', 'duo_farms', 'daily_prompts', 'timeline_events')
ORDER BY table_name;

-- 2. Check trigger exists
SELECT 'Trigger status' as status;
SELECT trigger_name, event_object_table, action_timing, event_manipulation
FROM information_schema.triggers
WHERE trigger_name = 'initialize_duo_data';

-- 3. Check summary
SELECT 'Summary' as status;
SELECT
    'Total rooms' as metric,
    COUNT(*) as count
FROM public.duo_rooms
UNION ALL
SELECT 'Rooms with metrics', COUNT(*) FROM public.duo_metrics
UNION ALL
SELECT 'Rooms with farms', COUNT(*) FROM public.duo_farms
UNION ALL
SELECT 'Total timeline events', COUNT(*) FROM public.timeline_events;

-- 4. Check YOUR specific room
SELECT 'Your room data' as status;
SELECT
    r.id as room_id,
    r.room_code,
    CASE WHEN m.room_id IS NOT NULL THEN '✅' ELSE '❌' END as has_metrics,
    CASE WHEN f.room_id IS NOT NULL THEN '✅' ELSE '❌' END as has_farm,
    COALESCE(m.love_energy, 0) as love_energy,
    COALESCE(m.current_streak, 0) as current_streak,
    f.unlocked_animals
FROM public.duo_rooms r
LEFT JOIN public.duo_metrics m ON r.id = m.room_id
LEFT JOIN public.duo_farms f ON r.id = f.room_id
ORDER BY r.created_at DESC
LIMIT 5;
