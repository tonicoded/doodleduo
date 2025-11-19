-- The REAL problem: RLS is blocking access because you're not in duo_memberships!

-- Check duo_memberships - you probably have NO entries
SELECT * FROM public.duo_memberships;

-- Check duo_rooms
SELECT id, room_code, created_by FROM public.duo_rooms ORDER BY created_at DESC;

-- The issue: When you create a room, you're not being added to duo_memberships!
-- Let's fix that by adding the room creator to memberships

INSERT INTO public.duo_memberships (profile_id, room_id)
SELECT created_by, id
FROM public.duo_rooms
WHERE (created_by, id) NOT IN (SELECT profile_id, room_id FROM public.duo_memberships);

-- Now verify you can see the data
SELECT
    r.room_code,
    dm.profile_id,
    m.love_energy,
    f.unlocked_animals
FROM public.duo_rooms r
JOIN public.duo_memberships dm ON r.id = dm.room_id
LEFT JOIN public.duo_metrics m ON r.id = m.room_id
LEFT JOIN public.duo_farms f ON r.id = f.room_id
ORDER BY r.created_at DESC;
