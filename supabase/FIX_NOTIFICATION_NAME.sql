-- ================================================
-- FIX NOTIFICATION NAME BUG
-- The notification should show the SENDER's name, not the receiver's name
-- ================================================

BEGIN;

DROP TRIGGER IF EXISTS notify_partner_on_activity ON public.duo_activities;

CREATE OR REPLACE FUNCTION public.notify_partner_of_activity()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    partner_user_id UUID;
    partner_device_token TEXT;
    sender_display_name TEXT;  -- Changed from partner_display_name
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
        -- First, get the SENDER's display name (the person who created the activity)
        SELECT p.display_name INTO sender_display_name
        FROM public.profiles p
        WHERE p.id = NEW.author_id;

        -- Then, get the PARTNER's user ID (the person who should receive the notification)
        SELECT dm.profile_id INTO partner_user_id
        FROM public.duo_memberships dm
        WHERE dm.room_id = NEW.room_id
          AND dm.profile_id != NEW.author_id
        LIMIT 1;

        -- Get partner's device token
        SELECT device_token INTO partner_device_token
        FROM public.device_tokens
        WHERE user_id = partner_user_id
          AND platform = 'ios'
        ORDER BY updated_at DESC
        LIMIT 1;

        IF partner_device_token IS NOT NULL THEN
            notification_payload := jsonb_build_object(
                'device_token', partner_device_token,
                'activity_id', NEW.id,
                'activity_type', NEW.activity_type,
                'content', NEW.content,
                'room_id', NEW.room_id::text,
                'partner_name', COALESCE(sender_display_name, 'Your partner'),  -- This is the sender's name
                'widget_refresh', (NEW.activity_type = 'doodle')
            );

            RAISE NOTICE 'Sending push to % with sender name: %', partner_user_id, sender_display_name;

            PERFORM net.http_post(
                url := supabase_url || '/functions/v1/send-push-notification',
                headers := jsonb_build_object(
                    'Content-Type', 'application/json',
                    'Authorization', 'Bearer ' || supabase_anon_key
                ),
                body := notification_payload
            );

            RAISE NOTICE '✅ Push notification sent';
        ELSE
            RAISE NOTICE '⚠️ No device token found for partner user %', partner_user_id;
        END IF;
    ELSE
        RAISE NOTICE '⚠️ Room does not have exactly 2 members (has %)', room_member_count;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER notify_partner_on_activity
    AFTER INSERT ON public.duo_activities
    FOR EACH ROW
    EXECUTE FUNCTION public.notify_partner_of_activity();

COMMIT;

SELECT '✅ Fixed! Notification will now show sender''s name, not receiver''s name' as status;
