-- Fix for existing room: Add missing metrics and farm data
-- Run this in Supabase SQL Editor

-- Insert metrics for existing room
INSERT INTO public.duo_metrics (room_id, love_energy, current_streak, longest_streak)
VALUES ('2DB6E749-6172-4694-8DA1-46F731829EB1', 0, 0, 0)
ON CONFLICT (room_id) DO NOTHING;

-- Insert farm for existing room with starter chicken
INSERT INTO public.duo_farms (room_id, unlocked_animals, farm_level, theme, animals_sleeping)
VALUES ('2DB6E749-6172-4694-8DA1-46F731829EB1', '["chicken"]'::jsonb, 1, 'default', false)
ON CONFLICT (room_id) DO NOTHING;

-- Insert initial timeline event
INSERT INTO public.timeline_events (room_id, event_type, event_data)
VALUES (
    '2DB6E749-6172-4694-8DA1-46F731829EB1',
    'milestone',
    jsonb_build_object('message', 'Farm created! 🌾', 'icon', 'sparkles')
);

-- Verify the data was created
SELECT 'duo_metrics' as table_name, * FROM public.duo_metrics WHERE room_id = '2DB6E749-6172-4694-8DA1-46F731829EB1'
UNION ALL
SELECT 'duo_farms' as table_name, room_id::text, unlocked_animals::text, farm_level::text, theme, animals_sleeping::text, null, null, null, null, null
FROM public.duo_farms WHERE room_id = '2DB6E749-6172-4694-8DA1-46F731829EB1';
