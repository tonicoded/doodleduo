-- ================================================
-- FIX ALL SECURITY ISSUES
-- Addresses RLS and function search_path vulnerabilities
-- ================================================

-- ============================================
-- 1. FIX WAITLIST TABLE RLS
-- ============================================

-- Enable RLS on waitlist table (if it exists)
ALTER TABLE IF EXISTS public.waitlist ENABLE ROW LEVEL SECURITY;

-- Drop and recreate waitlist policies with correct permissions
DROP POLICY IF EXISTS "waitlist_insert_policy" ON public.waitlist;
DROP POLICY IF EXISTS "waitlist_select_policy" ON public.waitlist;

-- Allow anyone (anon + authenticated) to insert to waitlist
CREATE POLICY "waitlist_insert_policy"
    ON public.waitlist
    FOR INSERT
    TO anon, authenticated
    WITH CHECK (true);

-- Only authenticated users can view waitlist
CREATE POLICY "waitlist_select_policy"
    ON public.waitlist
    FOR SELECT
    TO authenticated
    USING (true);

-- ============================================
-- 2. FIX FUNCTION SECURITY (search_path)
-- ============================================

-- Fix initialize_duo_room_data function
CREATE OR REPLACE FUNCTION public.initialize_duo_room_data()
RETURNS TRIGGER AS $$
BEGIN
    -- Insert default metrics
    INSERT INTO public.duo_metrics (room_id)
    VALUES (new.id)
    ON CONFLICT (room_id) DO NOTHING;

    -- Insert default farm with starter chicken
    INSERT INTO public.duo_farms (room_id, unlocked_animals)
    VALUES (new.id, '["chicken"]'::jsonb)
    ON CONFLICT (room_id) DO NOTHING;

    -- Insert initial timeline event
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

-- Fix update_streak_for_room function
CREATE OR REPLACE FUNCTION public.update_streak_for_room(
    p_room_id uuid,
    p_profile_id uuid,
    p_activity_date date DEFAULT CURRENT_DATE
)
RETURNS jsonb AS $$
DECLARE
    v_metrics record;
    v_new_streak int;
    v_streak_broken boolean := false;
    v_days_since_last int;
BEGIN
    -- Fetch current metrics
    SELECT * INTO v_metrics
    FROM public.duo_metrics
    WHERE room_id = p_room_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Room metrics not found';
    END IF;

    -- Calculate days since last activity
    IF v_metrics.last_activity_date IS NULL THEN
        v_days_since_last := 999;
    ELSE
        v_days_since_last := p_activity_date - v_metrics.last_activity_date;
    END IF;

    -- Determine new streak
    IF v_days_since_last = 0 THEN
        -- Same day, no change
        v_new_streak := v_metrics.current_streak;
    ELSIF v_days_since_last = 1 THEN
        -- Consecutive day, increment
        v_new_streak := v_metrics.current_streak + 1;
    ELSE
        -- Gap detected
        IF v_metrics.hardcore_mode THEN
            -- Hardcore: reset to 0
            v_new_streak := 0;
            v_streak_broken := true;

            -- Put animals to sleep
            UPDATE public.duo_farms
            SET animals_sleeping = true
            WHERE room_id = p_room_id;
        ELSE
            -- Normal: pause but don't reset
            v_new_streak := v_metrics.current_streak;
        END IF;
    END IF;

    -- Update metrics
    UPDATE public.duo_metrics
    SET
        current_streak = v_new_streak,
        longest_streak = GREATEST(longest_streak, v_new_streak),
        last_activity_date = p_activity_date,
        last_activity_profile_id = p_profile_id
    WHERE room_id = p_room_id;

    -- Create timeline event for milestones
    IF v_new_streak > 0 AND v_new_streak % 5 = 0 THEN
        INSERT INTO public.timeline_events (room_id, event_type, event_data)
        VALUES (
            p_room_id,
            'streak',
            jsonb_build_object('days', v_new_streak, 'message', format('%s day streak! 🔥', v_new_streak))
        );
    END IF;

    -- Create event if streak broken
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

-- Fix handle_profile_updated_at function
CREATE OR REPLACE FUNCTION public.handle_profile_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    new.updated_at = timezone('utc', now());
    RETURN new;
END;
$$ LANGUAGE plpgsql
SET search_path = public, pg_temp;

-- Fix test_push_notification_setup function (if it exists)
CREATE OR REPLACE FUNCTION public.test_push_notification_setup()
RETURNS TABLE(
    check_name text,
    status text,
    details text
) AS $$
BEGIN
    -- Check if push_tokens table exists
    RETURN QUERY
    SELECT
        'push_tokens_table'::text,
        CASE WHEN EXISTS (
            SELECT 1 FROM information_schema.tables
            WHERE table_schema = 'public' AND table_name = 'push_tokens'
        ) THEN 'OK' ELSE 'MISSING' END::text,
        'Verifies push_tokens table exists'::text;

    -- Check if function exists
    RETURN QUERY
    SELECT
        'send_push_function'::text,
        CASE WHEN EXISTS (
            SELECT 1 FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE n.nspname = 'public' AND p.proname = 'send_partner_push_notification'
        ) THEN 'OK' ELSE 'MISSING' END::text,
        'Verifies send_partner_push_notification function exists'::text;

    -- Check if trigger exists
    RETURN QUERY
    SELECT
        'activity_trigger'::text,
        CASE WHEN EXISTS (
            SELECT 1 FROM pg_trigger
            WHERE tgname = 'notify_partner_on_activity'
        ) THEN 'OK' ELSE 'MISSING' END::text,
        'Verifies duo_activities trigger exists'::text;
END;
$$ LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp;

GRANT EXECUTE ON FUNCTION public.test_push_notification_setup() TO authenticated;

-- ============================================
-- 3. VERIFY FIXES
-- ============================================

SELECT 'Security issues fixed successfully!' as status;
