-- Simple fix: Add data for any rooms missing metrics/farm data
-- This works with the EXISTING duo_metrics and duo_farms tables

-- Add metrics for rooms that don't have them yet
INSERT INTO public.duo_metrics (room_id, love_energy, total_doodles, current_streak, longest_streak)
SELECT id, 0, 0, 0, 0
FROM public.duo_rooms
WHERE id NOT IN (SELECT room_id FROM public.duo_metrics)
ON CONFLICT (room_id) DO NOTHING;

-- Add farm for rooms that don't have them yet
INSERT INTO public.duo_farms (room_id, unlocked_animals, farm_level)
SELECT id, '["chicken"]'::jsonb, 1
FROM public.duo_rooms
WHERE id NOT IN (SELECT room_id FROM public.duo_farms)
ON CONFLICT (room_id) DO NOTHING;

-- Verify it worked
SELECT
    r.id as room_id,
    r.room_code,
    m.love_energy,
    m.current_streak,
    f.unlocked_animals,
    f.farm_level
FROM public.duo_rooms r
LEFT JOIN public.duo_metrics m ON r.id = m.room_id
LEFT JOIN public.duo_farms f ON r.id = f.room_id
ORDER BY r.created_at DESC;
