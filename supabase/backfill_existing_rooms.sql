-- Backfill metrics and farm data for ALL existing rooms
-- This handles any room created before the migration

-- Insert metrics for all rooms that don't have them
INSERT INTO public.duo_metrics (room_id, love_energy, current_streak, longest_streak)
SELECT id, 0, 0, 0
FROM public.duo_rooms
WHERE id NOT IN (SELECT room_id FROM public.duo_metrics)
ON CONFLICT (room_id) DO NOTHING;

-- Insert farm for all rooms that don't have them (with starter chicken)
INSERT INTO public.duo_farms (room_id, unlocked_animals, farm_level, theme, animals_sleeping)
SELECT id, '["chicken"]'::jsonb, 1, 'default', false
FROM public.duo_rooms
WHERE id NOT IN (SELECT room_id FROM public.duo_farms)
ON CONFLICT (room_id) DO NOTHING;

-- Insert initial timeline event for all rooms
INSERT INTO public.timeline_events (room_id, event_type, event_data)
SELECT
    id,
    'milestone',
    jsonb_build_object('message', 'Farm created! 🌾', 'icon', 'sparkles')
FROM public.duo_rooms
WHERE id NOT IN (
    SELECT DISTINCT room_id
    FROM public.timeline_events
    WHERE event_type = 'milestone'
    AND event_data->>'message' = 'Farm created! 🌾'
);

-- Show results
SELECT
    'Total rooms' as metric,
    COUNT(*) as count
FROM public.duo_rooms
UNION ALL
SELECT
    'Rooms with metrics',
    COUNT(*)
FROM public.duo_metrics
UNION ALL
SELECT
    'Rooms with farms',
    COUNT(*)
FROM public.duo_farms;
