-- ================================================
-- RESTORE WORKING STATE
-- This restores the trigger and fixes issues
-- ================================================

BEGIN;

-- 1. Drop any broken triggers
DROP TRIGGER IF EXISTS trigger_notify_partner_of_activity ON public.duo_activities;
DROP TRIGGER IF EXISTS notify_partner_on_activity ON public.duo_activities;

-- 2. Recreate the WORKING trigger function from migration 011
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
        WHERE dm.room_id = NEW.room_id
          AND dm.profile_id != NEW.author_id
        LIMIT 1;

        SELECT device_token, environment INTO partner_device_token, partner_environment
        FROM public.device_tokens
        WHERE user_id = partner_user_id
          AND platform = 'ios'
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

            RAISE NOTICE 'Sending push notification: %', notification_payload;

            PERFORM net.http_post(
                url := supabase_url || '/functions/v1/send-push-notification',
                headers := jsonb_build_object(
                    'Content-Type', 'application/json',
                    'Authorization', 'Bearer ' || supabase_anon_key
                ),
                body := notification_payload
            );

            RAISE NOTICE '✅ Push notification request sent to edge function';
        ELSE
            RAISE NOTICE '⚠️ No device token found for partner user %', partner_user_id;
        END IF;
    ELSE
        RAISE NOTICE '⚠️ Room does not have exactly 2 members (has %)', room_member_count;
    END IF;

    RETURN NEW;
END;
$$;

-- 3. Recreate the trigger
CREATE TRIGGER notify_partner_on_activity
    AFTER INSERT ON public.duo_activities
    FOR EACH ROW
    EXECUTE FUNCTION public.notify_partner_of_activity();

COMMIT;

SELECT '✅ Trigger restored to working state' as status;
