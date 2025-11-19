-- ============================================
-- COMPLETE DOODLEDUO DATABASE SETUP
-- Run this entire file in Supabase SQL Editor
-- ============================================

-- ============================================
-- PART 1: CREATE TABLES
-- ============================================

-- 1. DOODLES TABLE
CREATE TABLE IF NOT EXISTS public.doodles (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id uuid NOT NULL REFERENCES public.duo_rooms(id) ON DELETE CASCADE,
    author_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    drawing_data jsonb NOT NULL,
    thumbnail_url text,
    is_prompt_response boolean NOT NULL DEFAULT false,
    prompt_id uuid,
    created_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS doodles_room_id_created_at_idx ON public.doodles(room_id, created_at DESC);
CREATE INDEX IF NOT EXISTS doodles_author_id_idx ON public.doodles(author_id);

ALTER TABLE public.doodles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Room members can view doodles" ON public.doodles;
CREATE POLICY "Room members can view doodles" ON public.doodles FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM public.duo_memberships dm
        WHERE dm.room_id = doodles.room_id AND dm.profile_id = auth.uid()
    )
);

DROP POLICY IF EXISTS "Room members can create doodles" ON public.doodles;
CREATE POLICY "Room members can create doodles" ON public.doodles FOR INSERT
WITH CHECK (
    author_id = auth.uid() AND
    EXISTS (
        SELECT 1 FROM public.duo_memberships dm
        WHERE dm.room_id = doodles.room_id AND dm.profile_id = auth.uid()
    )
);

DROP POLICY IF EXISTS "Authors can delete own doodles" ON public.doodles;
CREATE POLICY "Authors can delete own doodles" ON public.doodles FOR DELETE
USING (author_id = auth.uid());

-- 2. DUO METRICS TABLE
CREATE TABLE IF NOT EXISTS public.duo_metrics (
    room_id uuid PRIMARY KEY REFERENCES public.duo_rooms(id) ON DELETE CASCADE,
    love_energy int NOT NULL DEFAULT 0,
    total_doodles int NOT NULL DEFAULT 0,
    total_strokes int NOT NULL DEFAULT 0,
    current_streak int NOT NULL DEFAULT 0,
    longest_streak int NOT NULL DEFAULT 0,
    last_activity_date date,
    last_activity_profile_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    hardcore_mode boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
    updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

DROP TRIGGER IF EXISTS set_duo_metrics_updated_at ON public.duo_metrics;
CREATE TRIGGER set_duo_metrics_updated_at
BEFORE UPDATE ON public.duo_metrics
FOR EACH ROW EXECUTE PROCEDURE public.handle_profile_updated_at();

ALTER TABLE public.duo_metrics ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Room members can view metrics" ON public.duo_metrics;
CREATE POLICY "Room members can view metrics" ON public.duo_metrics FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM public.duo_memberships dm
        WHERE dm.room_id = duo_metrics.room_id AND dm.profile_id = auth.uid()
    )
);

DROP POLICY IF EXISTS "Room members can update metrics" ON public.duo_metrics;
CREATE POLICY "Room members can update metrics" ON public.duo_metrics FOR UPDATE
USING (
    EXISTS (
        SELECT 1 FROM public.duo_memberships dm
        WHERE dm.room_id = duo_metrics.room_id AND dm.profile_id = auth.uid()
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.duo_memberships dm
        WHERE dm.room_id = duo_metrics.room_id AND dm.profile_id = auth.uid()
    )
);

DROP POLICY IF EXISTS "Room creators can insert metrics" ON public.duo_metrics;
CREATE POLICY "Room creators can insert metrics" ON public.duo_metrics FOR INSERT
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.duo_memberships dm
        WHERE dm.room_id = duo_metrics.room_id AND dm.profile_id = auth.uid()
    )
);

-- 3. DUO FARMS TABLE
CREATE TABLE IF NOT EXISTS public.duo_farms (
    room_id uuid PRIMARY KEY REFERENCES public.duo_rooms(id) ON DELETE CASCADE,
    unlocked_animals jsonb NOT NULL DEFAULT '[]',
    farm_level int NOT NULL DEFAULT 1,
    theme text NOT NULL DEFAULT 'default',
    animals_sleeping boolean NOT NULL DEFAULT false,
    last_unlock_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
    updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

DROP TRIGGER IF EXISTS set_duo_farms_updated_at ON public.duo_farms;
CREATE TRIGGER set_duo_farms_updated_at
BEFORE UPDATE ON public.duo_farms
FOR EACH ROW EXECUTE PROCEDURE public.handle_profile_updated_at();

ALTER TABLE public.duo_farms ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Room members can view farm" ON public.duo_farms;
CREATE POLICY "Room members can view farm" ON public.duo_farms FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM public.duo_memberships dm
        WHERE dm.room_id = duo_farms.room_id AND dm.profile_id = auth.uid()
    )
);

DROP POLICY IF EXISTS "Room members can update farm" ON public.duo_farms;
CREATE POLICY "Room members can update farm" ON public.duo_farms FOR UPDATE
USING (
    EXISTS (
        SELECT 1 FROM public.duo_memberships dm
        WHERE dm.room_id = duo_farms.room_id AND dm.profile_id = auth.uid()
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.duo_memberships dm
        WHERE dm.room_id = duo_farms.room_id AND dm.profile_id = auth.uid()
    )
);

DROP POLICY IF EXISTS "Room creators can insert farm" ON public.duo_farms;
CREATE POLICY "Room creators can insert farm" ON public.duo_farms FOR INSERT
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.duo_memberships dm
        WHERE dm.room_id = duo_farms.room_id AND dm.profile_id = auth.uid()
    )
);

-- 4. DAILY PROMPTS TABLE
CREATE TABLE IF NOT EXISTS public.daily_prompts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id uuid NOT NULL REFERENCES public.duo_rooms(id) ON DELETE CASCADE,
    prompt_text text NOT NULL,
    prompt_category text NOT NULL DEFAULT 'general',
    prompt_date date NOT NULL,
    completed_by uuid[] NOT NULL DEFAULT '{}',
    completed_doodle_ids uuid[] NOT NULL DEFAULT '{}',
    created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
    UNIQUE(room_id, prompt_date)
);

CREATE INDEX IF NOT EXISTS daily_prompts_room_date_idx ON public.daily_prompts(room_id, prompt_date DESC);

ALTER TABLE public.daily_prompts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Room members can view prompts" ON public.daily_prompts;
CREATE POLICY "Room members can view prompts" ON public.daily_prompts FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM public.duo_memberships dm
        WHERE dm.room_id = daily_prompts.room_id AND dm.profile_id = auth.uid()
    )
);

DROP POLICY IF EXISTS "Room members can insert prompts" ON public.daily_prompts;
CREATE POLICY "Room members can insert prompts" ON public.daily_prompts FOR INSERT
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.duo_memberships dm
        WHERE dm.room_id = daily_prompts.room_id AND dm.profile_id = auth.uid()
    )
);

DROP POLICY IF EXISTS "Room members can update prompts" ON public.daily_prompts;
CREATE POLICY "Room members can update prompts" ON public.daily_prompts FOR UPDATE
USING (
    EXISTS (
        SELECT 1 FROM public.duo_memberships dm
        WHERE dm.room_id = daily_prompts.room_id AND dm.profile_id = auth.uid()
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.duo_memberships dm
        WHERE dm.room_id = daily_prompts.room_id AND dm.profile_id = auth.uid()
    )
);

-- 5. TIMELINE EVENTS TABLE
CREATE TABLE IF NOT EXISTS public.timeline_events (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id uuid NOT NULL REFERENCES public.duo_rooms(id) ON DELETE CASCADE,
    event_type text NOT NULL,
    event_data jsonb NOT NULL,
    event_date timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS timeline_events_room_date_idx ON public.timeline_events(room_id, event_date DESC);
CREATE INDEX IF NOT EXISTS timeline_events_type_idx ON public.timeline_events(event_type);

ALTER TABLE public.timeline_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Room members can view timeline" ON public.timeline_events;
CREATE POLICY "Room members can view timeline" ON public.timeline_events FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM public.duo_memberships dm
        WHERE dm.room_id = timeline_events.room_id AND dm.profile_id = auth.uid()
    )
);

DROP POLICY IF EXISTS "Room members can insert timeline" ON public.timeline_events;
CREATE POLICY "Room members can insert timeline" ON public.timeline_events FOR INSERT
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.duo_memberships dm
        WHERE dm.room_id = timeline_events.room_id AND dm.profile_id = auth.uid()
    )
);

-- ============================================
-- PART 2: CREATE TRIGGER FUNCTION
-- ============================================

DROP FUNCTION IF EXISTS public.initialize_duo_room_data() CASCADE;

CREATE OR REPLACE FUNCTION public.initialize_duo_room_data()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Insert default metrics
    INSERT INTO public.duo_metrics (room_id)
    VALUES (NEW.id)
    ON CONFLICT (room_id) DO NOTHING;

    -- Insert default farm with starter chicken
    INSERT INTO public.duo_farms (room_id, unlocked_animals)
    VALUES (NEW.id, '["chicken"]'::jsonb)
    ON CONFLICT (room_id) DO NOTHING;

    -- Insert initial timeline event
    INSERT INTO public.timeline_events (room_id, event_type, event_data)
    VALUES (
        NEW.id,
        'milestone',
        jsonb_build_object('message', 'Farm created! 🌾', 'icon', 'sparkles')
    );

    RETURN NEW;
END;
$$;

-- ============================================
-- PART 3: CREATE TRIGGER
-- ============================================

DROP TRIGGER IF EXISTS initialize_duo_data ON public.duo_rooms;

CREATE TRIGGER initialize_duo_data
    AFTER INSERT ON public.duo_rooms
    FOR EACH ROW
    EXECUTE FUNCTION public.initialize_duo_room_data();

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.initialize_duo_room_data() TO authenticated;
GRANT EXECUTE ON FUNCTION public.initialize_duo_room_data() TO service_role;

-- ============================================
-- PART 4: STREAK CALCULATION FUNCTION
-- ============================================

DROP FUNCTION IF EXISTS public.update_streak_for_room(uuid, uuid, date);

CREATE OR REPLACE FUNCTION public.update_streak_for_room(
    p_room_id uuid,
    p_profile_id uuid,
    p_activity_date date DEFAULT CURRENT_DATE
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_metrics record;
    v_new_streak int;
    v_streak_broken boolean := false;
    v_days_since_last int;
BEGIN
    SELECT * INTO v_metrics FROM public.duo_metrics WHERE room_id = p_room_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Room metrics not found';
    END IF;

    IF v_metrics.last_activity_date IS NULL THEN
        v_days_since_last := 999;
    ELSE
        v_days_since_last := p_activity_date - v_metrics.last_activity_date;
    END IF;

    IF v_days_since_last = 0 THEN
        v_new_streak := v_metrics.current_streak;
    ELSIF v_days_since_last = 1 THEN
        v_new_streak := v_metrics.current_streak + 1;
    ELSE
        IF v_metrics.hardcore_mode THEN
            v_new_streak := 0;
            v_streak_broken := true;
            UPDATE public.duo_farms SET animals_sleeping = true WHERE room_id = p_room_id;
        ELSE
            v_new_streak := v_metrics.current_streak;
        END IF;
    END IF;

    UPDATE public.duo_metrics
    SET
        current_streak = v_new_streak,
        longest_streak = GREATEST(longest_streak, v_new_streak),
        last_activity_date = p_activity_date,
        last_activity_profile_id = p_profile_id
    WHERE room_id = p_room_id;

    IF v_new_streak > 0 AND v_new_streak % 5 = 0 THEN
        INSERT INTO public.timeline_events (room_id, event_type, event_data)
        VALUES (
            p_room_id,
            'streak',
            jsonb_build_object('days', v_new_streak, 'message', format('%s day streak! 🔥', v_new_streak))
        );
    END IF;

    IF v_streak_broken THEN
        INSERT INTO public.timeline_events (room_id, event_type, event_data)
        VALUES (
            p_room_id,
            'milestone',
            jsonb_build_object('message', 'Streak broken. Animals are sleeping. 😴', 'icon', 'moon.zzz')
        );
    END IF;

    RETURN jsonb_build_object(
        'new_streak', v_new_streak,
        'streak_broken', v_streak_broken,
        'days_since_last', v_days_since_last
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_streak_for_room TO authenticated;

-- ============================================
-- PART 5: BACKFILL EXISTING ROOMS
-- ============================================

-- Insert metrics for all existing rooms that don't have them
INSERT INTO public.duo_metrics (room_id, love_energy, current_streak, longest_streak)
SELECT id, 0, 0, 0
FROM public.duo_rooms
WHERE id NOT IN (SELECT room_id FROM public.duo_metrics)
ON CONFLICT (room_id) DO NOTHING;

-- Insert farm for all existing rooms that don't have them
INSERT INTO public.duo_farms (room_id, unlocked_animals, farm_level, theme, animals_sleeping)
SELECT id, '["chicken"]'::jsonb, 1, 'default', false
FROM public.duo_rooms
WHERE id NOT IN (SELECT room_id FROM public.duo_farms)
ON CONFLICT (room_id) DO NOTHING;

-- Insert initial timeline event for all existing rooms
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

-- ============================================
-- PART 6: ENABLE REALTIME (if publication exists)
-- ============================================

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.doodles;
        ALTER PUBLICATION supabase_realtime ADD TABLE public.duo_metrics;
        ALTER PUBLICATION supabase_realtime ADD TABLE public.duo_farms;
        ALTER PUBLICATION supabase_realtime ADD TABLE public.timeline_events;
    END IF;
END $$;

-- ============================================
-- PART 7: VERIFICATION
-- ============================================

-- Show summary
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
FROM public.duo_farms
UNION ALL
SELECT
    'Total timeline events',
    COUNT(*)
FROM public.timeline_events;

-- Show recent rooms with their data
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
LIMIT 10;
