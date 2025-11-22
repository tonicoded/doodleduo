-- ================================================
-- STANDALONE SECURITY FIX
-- Run this directly in Supabase SQL Editor
-- ================================================

-- ============================================
-- 1. FIX WAITLIST TABLE (if it exists)
-- ============================================

DO $$
BEGIN
    -- Enable RLS on waitlist if table exists
    IF EXISTS (
        SELECT FROM information_schema.tables
        WHERE table_schema = 'public'
        AND table_name = 'waitlist'
    ) THEN
        ALTER TABLE public.waitlist ENABLE ROW LEVEL SECURITY;

        -- Drop existing policies
        DROP POLICY IF EXISTS "waitlist_insert_policy" ON public.waitlist;
        DROP POLICY IF EXISTS "waitlist_select_policy" ON public.waitlist;

        -- Create new policies
        EXECUTE 'CREATE POLICY "waitlist_insert_policy"
            ON public.waitlist
            FOR INSERT
            TO anon, authenticated
            WITH CHECK (true)';

        EXECUTE 'CREATE POLICY "waitlist_select_policy"
            ON public.waitlist
            FOR SELECT
            TO authenticated
            USING (true)';

        RAISE NOTICE 'Waitlist RLS policies fixed';
    ELSE
        RAISE NOTICE 'Waitlist table does not exist, skipping';
    END IF;
END $$;

-- ============================================
-- 2. FIX FUNCTION SECURITY (search_path)
-- ============================================

-- Fix handle_profile_updated_at function
CREATE OR REPLACE FUNCTION public.handle_profile_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    new.updated_at = timezone('utc', now());
    RETURN new;
END;
$$ LANGUAGE plpgsql
SET search_path = public, pg_temp;

-- Fix initialize_duo_room_data function (if it exists)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' AND p.proname = 'initialize_duo_room_data'
    ) THEN
        EXECUTE 'CREATE OR REPLACE FUNCTION public.initialize_duo_room_data()
        RETURNS TRIGGER AS $func$
        BEGIN
            INSERT INTO public.duo_metrics (room_id)
            VALUES (new.id)
            ON CONFLICT (room_id) DO NOTHING;

            INSERT INTO public.duo_farms (room_id, unlocked_animals)
            VALUES (new.id, ''["chicken"]''::jsonb)
            ON CONFLICT (room_id) DO NOTHING;

            INSERT INTO public.timeline_events (room_id, event_type, event_data)
            VALUES (
                new.id,
                ''milestone'',
                jsonb_build_object(''message'', ''Farm created! 🌾'', ''icon'', ''sparkles'')
            );

            RETURN new;
        END;
        $func$ LANGUAGE plpgsql
        SECURITY DEFINER
        SET search_path = public, pg_temp';

        RAISE NOTICE 'initialize_duo_room_data function fixed';
    ELSE
        RAISE NOTICE 'initialize_duo_room_data function does not exist, skipping';
    END IF;
END $$;

-- Fix update_streak_for_room function (if it exists)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' AND p.proname = 'update_streak_for_room'
    ) THEN
        EXECUTE 'CREATE OR REPLACE FUNCTION public.update_streak_for_room(
            p_room_id uuid,
            p_profile_id uuid,
            p_activity_date date DEFAULT CURRENT_DATE
        )
        RETURNS jsonb AS $func$
        DECLARE
            v_metrics record;
            v_new_streak int;
            v_streak_broken boolean := false;
            v_days_since_last int;
        BEGIN
            SELECT * INTO v_metrics
            FROM public.duo_metrics
            WHERE room_id = p_room_id;

            IF NOT FOUND THEN
                RAISE EXCEPTION ''Room metrics not found'';
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
                    ''streak'',
                    jsonb_build_object(''days'', v_new_streak, ''message'', format(''%s day streak! 🔥'', v_new_streak))
                );
            END IF;

            IF v_streak_broken THEN
                INSERT INTO public.timeline_events (room_id, event_type, event_data)
                VALUES (
                    p_room_id,
                    ''milestone'',
                    jsonb_build_object(''message'', ''Streak broken. Animals are sleeping. 😴'', ''icon'', ''moon.zzz'')
                );
            END IF;

            RETURN jsonb_build_object(
                ''new_streak'', v_new_streak,
                ''streak_broken'', v_streak_broken,
                ''days_since_last'', v_days_since_last
            );
        END;
        $func$ LANGUAGE plpgsql
        SECURITY DEFINER
        SET search_path = public, pg_temp';

        RAISE NOTICE 'update_streak_for_room function fixed';
    ELSE
        RAISE NOTICE 'update_streak_for_room function does not exist, skipping';
    END IF;
END $$;

-- Fix test_push_notification_setup function (if it exists)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' AND p.proname = 'test_push_notification_setup'
    ) THEN
        EXECUTE 'CREATE OR REPLACE FUNCTION public.test_push_notification_setup()
        RETURNS TABLE(
            check_name text,
            status text,
            details text
        ) AS $func$
        BEGIN
            RETURN QUERY
            SELECT
                ''push_tokens_table''::text,
                CASE WHEN EXISTS (
                    SELECT 1 FROM information_schema.tables
                    WHERE table_schema = ''public'' AND table_name = ''push_tokens''
                ) THEN ''OK'' ELSE ''MISSING'' END::text,
                ''Verifies push_tokens table exists''::text;

            RETURN QUERY
            SELECT
                ''send_push_function''::text,
                CASE WHEN EXISTS (
                    SELECT 1 FROM pg_proc p
                    JOIN pg_namespace n ON p.pronamespace = n.oid
                    WHERE n.nspname = ''public'' AND p.proname = ''send_partner_push_notification''
                ) THEN ''OK'' ELSE ''MISSING'' END::text,
                ''Verifies send_partner_push_notification function exists''::text;

            RETURN QUERY
            SELECT
                ''activity_trigger''::text,
                CASE WHEN EXISTS (
                    SELECT 1 FROM pg_trigger
                    WHERE tgname = ''notify_partner_on_activity''
                ) THEN ''OK'' ELSE ''MISSING'' END::text,
                ''Verifies duo_activities trigger exists''::text;
        END;
        $func$ LANGUAGE plpgsql
        SECURITY DEFINER
        SET search_path = public, pg_temp';

        EXECUTE 'GRANT EXECUTE ON FUNCTION public.test_push_notification_setup() TO authenticated';

        RAISE NOTICE 'test_push_notification_setup function fixed';
    ELSE
        RAISE NOTICE 'test_push_notification_setup function does not exist, skipping';
    END IF;
END $$;

-- ============================================
-- 3. VERIFY FIXES
-- ============================================

SELECT 'Security fixes applied successfully! ✅' as status;
