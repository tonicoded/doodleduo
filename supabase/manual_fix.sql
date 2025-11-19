-- Manual fix: Add data for ALL existing rooms
-- This is a simple, guaranteed-to-work approach

-- First, let's see what rooms exist
SELECT id, room_code, created_at FROM public.duo_rooms ORDER BY created_at DESC;

-- Now add metrics for ALL rooms (even if they already have some)
INSERT INTO public.duo_metrics (room_id, love_energy, current_streak, longest_streak)
SELECT id, 0, 0, 0
FROM public.duo_rooms
ON CONFLICT (room_id) DO NOTHING;

-- Add farm for ALL rooms (even if they already have some)
INSERT INTO public.duo_farms (room_id, unlocked_animals, farm_level, theme, animals_sleeping)
SELECT id, '["chicken"]'::jsonb, 1, 'default', false
FROM public.duo_rooms
ON CONFLICT (room_id) DO NOTHING;

-- Add timeline events for ALL rooms
INSERT INTO public.timeline_events (room_id, event_type, event_data)
SELECT
    id,
    'milestone',
    jsonb_build_object('message', 'Farm created! 🌾', 'icon', 'sparkles')
FROM public.duo_rooms;

-- Verify it worked
SELECT
    r.id as room_id,
    r.room_code,
    m.love_energy,
    m.current_streak,
    f.unlocked_animals
FROM public.duo_rooms r
JOIN public.duo_metrics m ON r.id = m.room_id
JOIN public.duo_farms f ON r.id = f.room_id
ORDER BY r.created_at DESC;
