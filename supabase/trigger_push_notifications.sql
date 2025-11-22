-- Create push notification system for partner doodles
-- This will send a push notification to the partner when someone sends a doodle

-- First, create a table to store device tokens for push notifications
CREATE TABLE IF NOT EXISTS device_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    device_token TEXT NOT NULL,
    platform TEXT NOT NULL DEFAULT 'ios',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, device_token)
);

-- Enable RLS for device_tokens
ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;

-- Users can only access their own device tokens
DROP POLICY IF EXISTS "Users can view their own device tokens" ON device_tokens;
CREATE POLICY "Users can view their own device tokens" ON device_tokens
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own device tokens" ON device_tokens;
CREATE POLICY "Users can insert their own device tokens" ON device_tokens
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own device tokens" ON device_tokens;
CREATE POLICY "Users can update their own device tokens" ON device_tokens
    FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own device tokens" ON device_tokens;
CREATE POLICY "Users can delete their own device tokens" ON device_tokens
    FOR DELETE USING (auth.uid() = user_id);

-- Grant permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON device_tokens TO authenticated;

-- Function for users to register their device token (bypasses RLS while still checking auth.uid())
DROP FUNCTION IF EXISTS register_device_token(TEXT, TEXT);
CREATE OR REPLACE FUNCTION register_device_token(
    p_device_token TEXT,
    p_platform TEXT DEFAULT 'ios'
) RETURNS device_tokens AS $$
DECLARE
    inserted device_tokens;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'auth.uid() is required to register device tokens';
    END IF;

    INSERT INTO device_tokens (user_id, device_token, platform)
    VALUES (auth.uid(), p_device_token, COALESCE(p_platform, 'ios'))
    ON CONFLICT (user_id, device_token)
    DO UPDATE SET
        platform = EXCLUDED.platform,
        updated_at = timezone('utc', now())
    RETURNING * INTO inserted;

    RETURN inserted;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, extensions;

GRANT EXECUTE ON FUNCTION register_device_token(TEXT, TEXT) TO authenticated;

-- Create function to send push notification via Edge Function
CREATE OR REPLACE FUNCTION send_push_notification(
    recipient_user_id UUID,
    title TEXT,
    body TEXT,
    data JSONB DEFAULT '{}'::JSONB
) RETURNS void AS $$
DECLARE
    token_record RECORD;
    functions_url TEXT := current_setting('app.supabase_functions_url', true);
    service_key TEXT := current_setting('app.supabase_service_key', true);
BEGIN
    IF functions_url IS NULL OR service_key IS NULL THEN
        RAISE NOTICE 'Skipping push notification: app.supabase_functions_url or app.supabase_service_key not configured';
        RETURN;
    END IF;

    -- Get all device tokens for the recipient
    FOR token_record IN 
        SELECT device_token 
        FROM device_tokens 
        WHERE user_id = recipient_user_id
    LOOP
        -- Call the Edge Function to send push notification
        PERFORM net.http_post(
            url := functions_url || '/push-notification',
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'Authorization', 'Bearer ' || service_key
            ),
            body := jsonb_build_object(
                'deviceToken', token_record.device_token,
                'title', title,
                'body', body,
                'data', data
            )
        );
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to notify partner when doodle is sent
CREATE OR REPLACE FUNCTION notify_partner_of_doodle() RETURNS trigger AS $$
DECLARE
    sender_name TEXT;
    partner_user_id UUID;
    room_id_val UUID;
BEGIN
    -- Only process doodle activities
    IF NEW.activity_type != 'doodle' THEN
        RETURN NEW;
    END IF;

    -- Get the room_id and sender name
    SELECT NEW.room_id INTO room_id_val;
    
    -- Get sender's display name
    SELECT COALESCE(display_name, 'Your partner')
    FROM profiles 
    WHERE id = NEW.author_id
    INTO sender_name;

    -- Find partner's user ID (other member in the same room)
    SELECT dm.profile_id
    FROM duo_memberships dm
    WHERE dm.room_id = room_id_val 
      AND dm.profile_id != NEW.author_id
    INTO partner_user_id;

    -- If we found a partner, send push notification
    IF partner_user_id IS NOT NULL THEN
        PERFORM send_push_notification(
            recipient_user_id := partner_user_id,
            title := sender_name || ' sent a doodle',
            body := 'Tap to see their latest creation! 🎨',
            data := jsonb_build_object(
                'activity_type', 'doodle',
                'activity_id', NEW.id::text,
                'widget_refresh', true,
                'room_id', room_id_val::text
            )
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger on duo_activities table
DROP TRIGGER IF EXISTS trigger_doodle_notification ON duo_activities;
CREATE TRIGGER trigger_doodle_notification
    AFTER INSERT ON duo_activities
    FOR EACH ROW
    EXECUTE FUNCTION notify_partner_of_doodle();

-- Update the updated_at timestamp for device_tokens
CREATE OR REPLACE FUNCTION update_device_token_timestamp() RETURNS trigger AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_device_token_updated_at ON device_tokens;
CREATE TRIGGER update_device_token_updated_at
    BEFORE UPDATE ON device_tokens
    FOR EACH ROW
    EXECUTE FUNCTION update_device_token_timestamp();
