-- 015_push_environment_split.sql
-- Track APNs environment per device token and allow sandbox vs production routing

BEGIN;

-- 1. Add environment column if missing
ALTER TABLE public.device_tokens
ADD COLUMN IF NOT EXISTS environment TEXT NOT NULL DEFAULT 'production';

-- 2. Update register_device_token RPC to accept environment
DROP FUNCTION IF EXISTS public.register_device_token(TEXT, TEXT);
DROP FUNCTION IF EXISTS public.register_device_token(TEXT, TEXT, TEXT);

CREATE OR REPLACE FUNCTION public.register_device_token(
    p_device_token TEXT,
    p_platform TEXT DEFAULT 'ios',
    p_environment TEXT DEFAULT 'production'
) RETURNS device_tokens AS $$
DECLARE
    inserted device_tokens;
    normalized_environment TEXT := lower(COALESCE(NULLIF(p_environment, ''), 'production'));
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'auth.uid() is required to register device tokens';
    END IF;

    INSERT INTO device_tokens (user_id, device_token, platform, environment)
    VALUES (auth.uid(), p_device_token, COALESCE(p_platform, 'ios'), normalized_environment)
    ON CONFLICT (user_id, device_token)
    DO UPDATE SET
        platform = EXCLUDED.platform,
        environment = EXCLUDED.environment,
        updated_at = timezone('utc', now())
    RETURNING * INTO inserted;

    RETURN inserted;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, extensions;

GRANT EXECUTE ON FUNCTION public.register_device_token(TEXT, TEXT, TEXT) TO authenticated;

-- 3. Update notify_partner_of_activity to forward environment info
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
                'activity_id', NEW.id,
                'activity_type', NEW.activity_type,
                'content', NEW.content,
                'room_id', NEW.room_id::text,
                'partner_name', COALESCE(partner_display_name, 'Your partner'),
                'widget_refresh', (NEW.activity_type = 'doodle'),
                'environment', COALESCE(partner_environment, 'production')
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

COMMIT;
