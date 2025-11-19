-- Verify the trigger exists and is enabled
SELECT
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement,
    action_timing
FROM information_schema.triggers
WHERE trigger_name = 'initialize_duo_data'
AND event_object_table = 'duo_rooms';

-- Check if the function exists
SELECT routine_name, routine_type
FROM information_schema.routines
WHERE routine_name = 'initialize_duo_room_data'
AND routine_schema = 'public';

-- Check what's in duo_rooms
SELECT id, room_code, created_by, created_at
FROM public.duo_rooms
ORDER BY created_at DESC
LIMIT 5;

-- Check what's in duo_metrics
SELECT room_id, love_energy, current_streak
FROM public.duo_metrics
ORDER BY created_at DESC
LIMIT 5;

-- Check what's in duo_farms
SELECT room_id, unlocked_animals, farm_level
FROM public.duo_farms
ORDER BY created_at DESC
LIMIT 5;
