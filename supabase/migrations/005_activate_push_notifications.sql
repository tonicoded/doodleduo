-- Activate Push Notifications
-- This migration updates the trigger to actually call the edge function
-- Run this AFTER deploying the send-push-notification edge function

-- Drop and recreate the trigger function with edge function call enabled
CREATE OR REPLACE FUNCTION notify_partner_of_activity()
RETURNS TRIGGER AS $$
DECLARE
    partner_user_id UUID;
    partner_device_token TEXT;
    partner_display_name TEXT;
    room_member_count INTEGER;
    notification_payload JSONB;
    supabase_url TEXT;
    supabase_anon_key TEXT;
BEGIN
    -- Get configuration (you'll need to set these as environment variables in Supabase)
    -- For now, we'll use pg_settings or you can hardcode your project URL
    supabase_url := current_setting('app.settings.supabase_url', true);
    supabase_anon_key := current_setting('app.settings.supabase_anon_key', true);

    -- If not set via settings, fall back to hardcoded
    IF supabase_url IS NULL THEN
        supabase_url := 'https://reevrasmalgiftakwsao.supabase.co';
    END IF;

    IF supabase_anon_key IS NULL THEN
        supabase_anon_key := 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJlZXZyYXNtYWxnaWZ0YWt3c2FvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMzMTgzNzgsImV4cCI6MjA3ODg5NDM3OH0.PRq3XALuaA5ZSsdhfn7h861xFLKc9Z_F4yPlk4mOPNc';
    END IF;

    -- Get the partner's user ID from the same room
    SELECT COUNT(*) INTO room_member_count
    FROM public.duo_memberships
    WHERE room_id = NEW.room_id;

    -- Only proceed if room has exactly 2 members (duo)
    IF room_member_count = 2 THEN
        -- Get partner info
        SELECT dm.profile_id, p.display_name INTO partner_user_id, partner_display_name
        FROM public.duo_memberships dm
        LEFT JOIN public.profiles p ON dm.profile_id = p.id
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

        -- If partner has device token, send notification
        IF partner_device_token IS NOT NULL THEN
            -- Build notification payload
            notification_payload := jsonb_build_object(
                'device_token', partner_device_token,
                'activity_type', NEW.activity_type,
                'content', NEW.content,
                'room_id', NEW.room_id::text,
                'partner_name', COALESCE(partner_display_name, 'Your partner')
            );

            -- Log the notification attempt
            RAISE NOTICE 'Sending push notification: %', notification_payload;

            -- Call the edge function using pg_net extension
            -- NOTE: Make sure pg_net extension is enabled in your Supabase project
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
$$ LANGUAGE plpgsql;

-- Ensure the trigger is attached to the duo_activities table
DROP TRIGGER IF EXISTS notify_partner_on_activity ON public.duo_activities;

CREATE TRIGGER notify_partner_on_activity
    AFTER INSERT ON public.duo_activities
    FOR EACH ROW
    EXECUTE FUNCTION notify_partner_of_activity();

-- Add helpful comment
COMMENT ON TRIGGER notify_partner_on_activity ON public.duo_activities IS
    'Sends push notifications to partner when new activities are created';

-- Enable the pg_net extension if not already enabled
-- This is required for making HTTP requests from the database
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Grant permissions to use pg_net
GRANT USAGE ON SCHEMA net TO postgres, anon, authenticated, service_role;

-- Success message
DO $$
BEGIN
    RAISE NOTICE '✅ Push notification trigger activated!';
    RAISE NOTICE '✅ Edge function: send-push-notification';
    RAISE NOTICE '✅ Supabase URL configured: https://reevrasmalgiftakwsao.supabase.co';
END $$;
