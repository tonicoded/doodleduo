-- ================================================
-- DOODLEDUO - COMPLETE DATABASE SETUP
-- This applies ALL missing features from migrations 003-014
-- Run this once in Supabase SQL Editor to get everything up to date
-- ================================================

BEGIN;

-- ============================================
-- 1. CORE FEATURE TABLES (from migration 001)
-- ============================================

-- 1A. DOODLES TABLE
CREATE TABLE IF NOT EXISTS public.doodles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID NOT NULL REFERENCES public.duo_rooms(id) ON DELETE CASCADE,
    author_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    drawing_data JSONB NOT NULL,
    thumbnail_url TEXT,
    is_prompt_response BOOLEAN NOT NULL DEFAULT false,
    prompt_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS doodles_room_id_created_at_idx
    ON public.doodles(room_id, created_at DESC);
CREATE INDEX IF NOT EXISTS doodles_author_id_idx
    ON public.doodles(author_id);

ALTER TABLE public.doodles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Room members can view doodles" ON public.doodles;
CREATE POLICY "Room members can view doodles"
ON public.doodles FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM public.duo_memberships dm
        WHERE dm.room_id = doodles.room_id AND dm.profile_id = auth.uid()
    )
);

DROP POLICY IF EXISTS "Room members can create doodles" ON public.doodles;
CREATE POLICY "Room members can create doodles"
ON public.doodles FOR INSERT WITH CHECK (
    author_id = auth.uid() AND EXISTS (
        SELECT 1 FROM public.duo_memberships dm
        WHERE dm.room_id = doodles.room_id AND dm.profile_id = auth.uid()
    )
);

DROP POLICY IF EXISTS "Authors can delete own doodles" ON public.doodles;
CREATE POLICY "Authors can delete own doodles"
ON public.doodles FOR DELETE USING (author_id = auth.uid());

-- 1B. DUO METRICS TABLE
CREATE TABLE IF NOT EXISTS public.duo_metrics (
    room_id UUID PRIMARY KEY REFERENCES public.duo_rooms(id) ON DELETE CASCADE,
    love_energy INT NOT NULL DEFAULT 0,
    total_doodles INT NOT NULL DEFAULT 0,
    total_strokes INT NOT NULL DEFAULT 0,
    current_streak INT NOT NULL DEFAULT 0,
    longest_streak INT NOT NULL DEFAULT 0,
    last_activity_date DATE,
    last_activity_profile_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    hardcore_mode BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

ALTER TABLE public.duo_metrics ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Room members can view metrics" ON public.duo_metrics;
CREATE POLICY "Room members can view metrics"
ON public.duo_metrics FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM public.duo_memberships dm
        WHERE dm.room_id = duo_metrics.room_id AND dm.profile_id = auth.uid()
    )
);

DROP POLICY IF EXISTS "Room members can update metrics" ON public.duo_metrics;
CREATE POLICY "Room members can update metrics"
ON public.duo_metrics FOR UPDATE USING (
    EXISTS (
        SELECT 1 FROM public.duo_memberships dm
        WHERE dm.room_id = duo_metrics.room_id AND dm.profile_id = auth.uid()
    )
) WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.duo_memberships dm
        WHERE dm.room_id = duo_metrics.room_id AND dm.profile_id = auth.uid()
    )
);

DROP POLICY IF EXISTS "Room creators can insert metrics" ON public.duo_metrics;
CREATE POLICY "Room creators can insert metrics"
ON public.duo_metrics FOR INSERT WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.duo_memberships dm
        WHERE dm.room_id = duo_metrics.room_id AND dm.profile_id = auth.uid()
    )
);

-- 1C. DUO FARMS TABLE
CREATE TABLE IF NOT EXISTS public.duo_farms (
    room_id UUID PRIMARY KEY REFERENCES public.duo_rooms(id) ON DELETE CASCADE,
    unlocked_animals JSONB NOT NULL DEFAULT '[]',
    farm_level INT NOT NULL DEFAULT 1,
    theme TEXT NOT NULL DEFAULT 'default',
    animals_sleeping BOOLEAN NOT NULL DEFAULT false,
    last_unlock_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

ALTER TABLE public.duo_farms ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Room members can view farm" ON public.duo_farms;
CREATE POLICY "Room members can view farm"
ON public.duo_farms FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM public.duo_memberships dm
        WHERE dm.room_id = duo_farms.room_id AND dm.profile_id = auth.uid()
    )
);

DROP POLICY IF EXISTS "Room members can update farm" ON public.duo_farms;
CREATE POLICY "Room members can update farm"
ON public.duo_farms FOR UPDATE USING (
    EXISTS (
        SELECT 1 FROM public.duo_memberships dm
        WHERE dm.room_id = duo_farms.room_id AND dm.profile_id = auth.uid()
    )
) WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.duo_memberships dm
        WHERE dm.room_id = duo_farms.room_id AND dm.profile_id = auth.uid()
    )
);

DROP POLICY IF EXISTS "Room creators can insert farm" ON public.duo_farms;
CREATE POLICY "Room creators can insert farm"
ON public.duo_farms FOR INSERT WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.duo_memberships dm
        WHERE dm.room_id = duo_farms.room_id AND dm.profile_id = auth.uid()
    )
);

-- 1D. DAILY PROMPTS TABLE
CREATE TABLE IF NOT EXISTS public.daily_prompts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID NOT NULL REFERENCES public.duo_rooms(id) ON DELETE CASCADE,
    prompt_text TEXT NOT NULL,
    prompt_category TEXT NOT NULL DEFAULT 'general',
    prompt_date DATE NOT NULL,
    completed_by UUID[] NOT NULL DEFAULT '{}',
    completed_doodle_ids UUID[] NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    UNIQUE(room_id, prompt_date)
);

CREATE INDEX IF NOT EXISTS daily_prompts_room_date_idx
    ON public.daily_prompts(room_id, prompt_date DESC);

ALTER TABLE public.daily_prompts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Room members can view prompts" ON public.daily_prompts;
CREATE POLICY "Room members can view prompts"
ON public.daily_prompts FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM public.duo_memberships dm
        WHERE dm.room_id = daily_prompts.room_id AND dm.profile_id = auth.uid()
    )
);

DROP POLICY IF EXISTS "Room members can insert prompts" ON public.daily_prompts;
CREATE POLICY "Room members can insert prompts"
ON public.daily_prompts FOR INSERT WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.duo_memberships dm
        WHERE dm.room_id = daily_prompts.room_id AND dm.profile_id = auth.uid()
    )
);

DROP POLICY IF EXISTS "Room members can update prompts" ON public.daily_prompts;
CREATE POLICY "Room members can update prompts"
ON public.daily_prompts FOR UPDATE USING (
    EXISTS (
        SELECT 1 FROM public.duo_memberships dm
        WHERE dm.room_id = daily_prompts.room_id AND dm.profile_id = auth.uid()
    )
) WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.duo_memberships dm
        WHERE dm.room_id = daily_prompts.room_id AND dm.profile_id = auth.uid()
    )
);

-- 1E. TIMELINE EVENTS TABLE
CREATE TABLE IF NOT EXISTS public.timeline_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID NOT NULL REFERENCES public.duo_rooms(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL,
    event_data JSONB NOT NULL,
    event_date TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS timeline_events_room_date_idx
    ON public.timeline_events(room_id, event_date DESC);
CREATE INDEX IF NOT EXISTS timeline_events_type_idx
    ON public.timeline_events(event_type);

ALTER TABLE public.timeline_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Room members can view timeline" ON public.timeline_events;
CREATE POLICY "Room members can view timeline"
ON public.timeline_events FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM public.duo_memberships dm
        WHERE dm.room_id = timeline_events.room_id AND dm.profile_id = auth.uid()
    )
);

DROP POLICY IF EXISTS "Room members can insert timeline" ON public.timeline_events;
CREATE POLICY "Room members can insert timeline"
ON public.timeline_events FOR INSERT WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.duo_memberships dm
        WHERE dm.room_id = timeline_events.room_id AND dm.profile_id = auth.uid()
    )
);

-- ============================================
-- 2. PUSH NOTIFICATIONS (from migrations 003-009)
-- ============================================

-- 2A. DEVICE TOKENS TABLE
CREATE TABLE IF NOT EXISTS public.device_tokens (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    device_token TEXT NOT NULL,
    platform TEXT DEFAULT 'ios',
    environment TEXT NOT NULL DEFAULT 'production',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, device_token)
);

ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage their own device tokens" ON public.device_tokens;
CREATE POLICY "Users can manage their own device tokens"
ON public.device_tokens FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- 2B. DUO ACTIVITIES TABLE
CREATE TABLE IF NOT EXISTS public.duo_activities (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    room_id UUID NOT NULL REFERENCES public.duo_rooms(id) ON DELETE CASCADE,
    author_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    activity_type TEXT NOT NULL CHECK (activity_type IN ('ping', 'hug', 'kiss', 'note', 'doodle')),
    content TEXT NOT NULL DEFAULT '',
    love_points_earned INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS duo_activities_room_id_created_at_idx
    ON public.duo_activities(room_id, created_at DESC);
CREATE INDEX IF NOT EXISTS duo_activities_author_id_idx
    ON public.duo_activities(author_id);

ALTER TABLE public.duo_activities ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Room members can view activities" ON public.duo_activities;
CREATE POLICY "Room members can view activities"
ON public.duo_activities FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM public.duo_memberships dm
        WHERE dm.room_id = duo_activities.room_id AND dm.profile_id = auth.uid()
    )
);

DROP POLICY IF EXISTS "Room members can create activities" ON public.duo_activities;
CREATE POLICY "Room members can create activities"
ON public.duo_activities FOR INSERT WITH CHECK (
    author_id = auth.uid() AND EXISTS (
        SELECT 1 FROM public.duo_memberships dm
        WHERE dm.room_id = duo_activities.room_id AND dm.profile_id = auth.uid()
    )
);

DROP POLICY IF EXISTS "Authors can delete own activities" ON public.duo_activities;
CREATE POLICY "Authors can delete own activities"
ON public.duo_activities FOR DELETE USING (author_id = auth.uid());

-- ============================================
-- 3. DUO ROOMS ENHANCEMENTS (from migration 010)
-- ============================================

ALTER TABLE public.duo_rooms
ADD COLUMN IF NOT EXISTS room_name TEXT;

COMMENT ON COLUMN public.duo_rooms.room_name IS 'Optional display name chosen by the couple';

-- ============================================
-- 4. WAITLIST TABLE (from migrations 012-013)
-- ============================================

CREATE TABLE IF NOT EXISTS public.waitlist (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    referral_source TEXT,
    user_agent TEXT,
    ip_address INET
);

CREATE INDEX IF NOT EXISTS idx_waitlist_email ON public.waitlist(email);
CREATE INDEX IF NOT EXISTS idx_waitlist_created_at ON public.waitlist(created_at DESC);

ALTER TABLE public.waitlist ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "waitlist_insert_policy" ON public.waitlist;
CREATE POLICY "waitlist_insert_policy"
    ON public.waitlist FOR INSERT
    TO anon, authenticated
    WITH CHECK (true);

DROP POLICY IF EXISTS "waitlist_select_policy" ON public.waitlist;
CREATE POLICY "waitlist_select_policy"
    ON public.waitlist FOR SELECT
    TO authenticated
    USING (true);

COMMENT ON TABLE public.waitlist IS 'Beta waitlist signups for DoodleDuo website';

-- Grant permissions
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON public.waitlist TO anon, authenticated;

-- ============================================
-- 5. HELPER FUNCTIONS
-- ============================================

-- 5A. Initialize duo room data (creates metrics, farm, timeline when room created)
CREATE OR REPLACE FUNCTION public.initialize_duo_room_data()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.duo_metrics (room_id)
    VALUES (new.id)
    ON CONFLICT (room_id) DO NOTHING;

    INSERT INTO public.duo_farms (room_id, unlocked_animals)
    VALUES (new.id, '["chicken"]'::jsonb)
    ON CONFLICT (room_id) DO NOTHING;

    INSERT INTO public.timeline_events (room_id, event_type, event_data)
    VALUES (
        new.id,
        'milestone',
        jsonb_build_object('message', 'Farm created! 🌾', 'icon', 'sparkles')
    );

    RETURN new;
END;
$$ LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp;

DROP TRIGGER IF EXISTS initialize_duo_data ON public.duo_rooms;
CREATE TRIGGER initialize_duo_data
AFTER INSERT ON public.duo_rooms
FOR EACH ROW EXECUTE PROCEDURE public.initialize_duo_room_data();

-- 5B. Update streak for room
CREATE OR REPLACE FUNCTION public.update_streak_for_room(
    p_room_id UUID,
    p_profile_id UUID,
    p_activity_date DATE DEFAULT CURRENT_DATE
)
RETURNS JSONB AS $$
DECLARE
    v_metrics RECORD;
    v_new_streak INT;
    v_streak_broken BOOLEAN := false;
    v_days_since_last INT;
BEGIN
    SELECT * INTO v_metrics
    FROM public.duo_metrics
    WHERE room_id = p_room_id;

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
            UPDATE public.duo_farms
            SET animals_sleeping = true
            WHERE room_id = p_room_id;
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
$$ LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp;

GRANT EXECUTE ON FUNCTION public.update_streak_for_room TO authenticated;

-- 5C. Push notification trigger function
CREATE OR REPLACE FUNCTION public.notify_partner_of_activity()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    partner_user_id UUID;
    partner_device_token TEXT;
    partner_environment TEXT;
    partner_display_name TEXT;
    room_member_count INTEGER;
    notification_payload JSONB;
    supabase_url TEXT;
    supabase_anon_key TEXT;
BEGIN
    supabase_url := current_setting('app.settings.supabase_url', true);
    supabase_anon_key := current_setting('app.settings.supabase_anon_key', true);

    IF supabase_url IS NULL THEN
        supabase_url := 'https://reevrasmalgiftakwsao.supabase.co';
    END IF;

    IF supabase_anon_key IS NULL THEN
        supabase_anon_key := 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJlZXZyYXNtYWxnaWZ0YWt3c2FvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMzMTgzNzgsImV4cCI6MjA3ODg5NDM3OH0.PRq3XALuaA5ZSsdhfn7h861xFLKc9Z_F4yPlk4mOPNc';
    END IF;

    SELECT COUNT(*) INTO room_member_count
    FROM public.duo_memberships
    WHERE room_id = NEW.room_id;

    IF room_member_count = 2 THEN
        SELECT dm.profile_id, p.display_name INTO partner_user_id, partner_display_name
        FROM public.duo_memberships dm
        LEFT JOIN public.profiles p ON dm.profile_id = p.id
        WHERE dm.room_id = NEW.room_id AND dm.profile_id != NEW.author_id
        LIMIT 1;

        SELECT device_token, environment INTO partner_device_token, partner_environment
        FROM public.device_tokens
        WHERE user_id = partner_user_id AND platform = 'ios'
        ORDER BY updated_at DESC
        LIMIT 1;

        IF partner_device_token IS NOT NULL THEN
            notification_payload := jsonb_build_object(
                'device_token', partner_device_token,
                'environment', COALESCE(partner_environment, 'production'),
                'activity_id', NEW.id,
                'activity_type', NEW.activity_type,
                'content', NEW.content,
                'room_id', NEW.room_id::text,
                'partner_name', COALESCE(partner_display_name, 'Your partner'),
                'widget_refresh', (NEW.activity_type = 'doodle')
            );

            PERFORM net.http_post(
                url := supabase_url || '/functions/v1/send-push-notification',
                headers := jsonb_build_object(
                    'Content-Type', 'application/json',
                    'Authorization', 'Bearer ' || supabase_anon_key
                ),
                body := notification_payload
            );
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_notify_partner_of_activity ON public.duo_activities;
DROP TRIGGER IF EXISTS notify_partner_on_activity ON public.duo_activities;

CREATE TRIGGER notify_partner_on_activity
    AFTER INSERT ON public.duo_activities
    FOR EACH ROW
    EXECUTE FUNCTION public.notify_partner_of_activity();

-- 5D. Update updated_at columns
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql
SET search_path = public, pg_temp;

DROP TRIGGER IF EXISTS trigger_update_device_tokens_updated_at ON public.device_tokens;
CREATE TRIGGER trigger_update_device_tokens_updated_at
    BEFORE UPDATE ON public.device_tokens
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS set_duo_metrics_updated_at ON public.duo_metrics;
CREATE TRIGGER set_duo_metrics_updated_at
BEFORE UPDATE ON public.duo_metrics
FOR EACH ROW EXECUTE PROCEDURE public.handle_profile_updated_at();

DROP TRIGGER IF EXISTS set_duo_farms_updated_at ON public.duo_farms;
CREATE TRIGGER set_duo_farms_updated_at
BEFORE UPDATE ON public.duo_farms
FOR EACH ROW EXECUTE PROCEDURE public.handle_profile_updated_at();

-- ============================================
-- 6. REALTIME PUBLICATION
-- ============================================

DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.doodles;
EXCEPTION
    WHEN undefined_object THEN NULL;
    WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.duo_metrics;
EXCEPTION
    WHEN undefined_object THEN NULL;
    WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.duo_farms;
EXCEPTION
    WHEN undefined_object THEN NULL;
    WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.timeline_events;
EXCEPTION
    WHEN undefined_object THEN NULL;
    WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.duo_activities;
EXCEPTION
    WHEN undefined_object THEN NULL;
    WHEN duplicate_object THEN NULL;
END $$;

COMMIT;

-- ============================================
-- 7. VERIFICATION
-- ============================================

SELECT '✅ ALL TABLES CREATED SUCCESSFULLY!' as status;

-- Show created tables
SELECT
    tablename,
    CASE
        WHEN tablename IN ('doodles', 'duo_metrics', 'duo_farms', 'daily_prompts', 'timeline_events', 'duo_activities', 'device_tokens', 'waitlist')
        THEN '✅ NEW'
        ELSE '✓ Existing'
    END as status
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;
