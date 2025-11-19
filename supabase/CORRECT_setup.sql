-- CORRECT setup for YOUR actual database structure
-- Uses: duos, duo_members, duo_users (not duo_rooms/duo_memberships!)

-- 1. Create duo_metrics table
CREATE TABLE IF NOT EXISTS public.duo_metrics (
    duo_id uuid PRIMARY KEY REFERENCES public.duos(id) ON DELETE CASCADE,
    love_energy int NOT NULL DEFAULT 0,
    total_doodles int NOT NULL DEFAULT 0,
    current_streak int NOT NULL DEFAULT 0,
    longest_streak int NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

ALTER TABLE public.duo_metrics ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Members can view metrics" ON public.duo_metrics;
CREATE POLICY "Members can view metrics" ON public.duo_metrics FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM public.duo_members dm
        JOIN public.duo_users du ON dm.user_id = du.id
        WHERE dm.duo_id = duo_metrics.duo_id AND du.auth_uid = auth.uid()
    )
);

DROP POLICY IF EXISTS "Members can update metrics" ON public.duo_metrics;
CREATE POLICY "Members can update metrics" ON public.duo_metrics FOR UPDATE
USING (
    EXISTS (
        SELECT 1 FROM public.duo_members dm
        JOIN public.duo_users du ON dm.user_id = du.id
        WHERE dm.duo_id = duo_metrics.duo_id AND du.auth_uid = auth.uid()
    )
);

DROP POLICY IF EXISTS "Members can insert metrics" ON public.duo_metrics;
CREATE POLICY "Members can insert metrics" ON public.duo_metrics FOR INSERT
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.duo_members dm
        JOIN public.duo_users du ON dm.user_id = du.id
        WHERE dm.duo_id = duo_metrics.duo_id AND du.auth_uid = auth.uid()
    )
);

-- 2. Create duo_farms table
CREATE TABLE IF NOT EXISTS public.duo_farms (
    duo_id uuid PRIMARY KEY REFERENCES public.duos(id) ON DELETE CASCADE,
    unlocked_animals jsonb NOT NULL DEFAULT '["chicken"]',
    farm_level int NOT NULL DEFAULT 1,
    created_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

ALTER TABLE public.duo_farms ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Members can view farm" ON public.duo_farms;
CREATE POLICY "Members can view farm" ON public.duo_farms FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM public.duo_members dm
        JOIN public.duo_users du ON dm.user_id = du.id
        WHERE dm.duo_id = duo_farms.duo_id AND du.auth_uid = auth.uid()
    )
);

DROP POLICY IF EXISTS "Members can update farm" ON public.duo_farms;
CREATE POLICY "Members can update farm" ON public.duo_farms FOR UPDATE
USING (
    EXISTS (
        SELECT 1 FROM public.duo_members dm
        JOIN public.duo_users du ON dm.user_id = du.id
        WHERE dm.duo_id = duo_farms.duo_id AND du.auth_uid = auth.uid()
    )
);

DROP POLICY IF EXISTS "Members can insert farm" ON public.duo_farms;
CREATE POLICY "Members can insert farm" ON public.duo_farms FOR INSERT
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.duo_members dm
        JOIN public.duo_users du ON dm.user_id = du.id
        WHERE dm.duo_id = duo_farms.duo_id AND du.auth_uid = auth.uid()
    )
);

-- 3. Add data for ALL existing duos
INSERT INTO public.duo_metrics (duo_id, love_energy, current_streak, longest_streak)
SELECT id, 0, 0, 0 FROM public.duos
ON CONFLICT (duo_id) DO NOTHING;

INSERT INTO public.duo_farms (duo_id, unlocked_animals, farm_level)
SELECT id, '["chicken"]'::jsonb, 1 FROM public.duos
ON CONFLICT (duo_id) DO NOTHING;

-- 4. Verify
SELECT
    d.room_code,
    m.love_energy,
    m.current_streak,
    f.unlocked_animals
FROM public.duos d
JOIN public.duo_metrics m ON d.id = m.duo_id
JOIN public.duo_farms f ON d.id = f.duo_id
ORDER BY d.created_at DESC;
