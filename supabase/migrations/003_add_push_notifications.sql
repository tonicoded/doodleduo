-- Add push notification support
-- Run this in Supabase SQL editor

-- Create device_tokens table
CREATE TABLE IF NOT EXISTS public.device_tokens (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    device_token TEXT NOT NULL,
    platform TEXT DEFAULT 'ios',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Ensure one token per user (replace on update)
    UNIQUE(user_id)
);

-- Enable RLS
ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can only manage their own device tokens
CREATE POLICY "Users can manage their own device tokens"
ON public.device_tokens
FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Create function to send push notification when activity is created
CREATE OR REPLACE FUNCTION notify_partner_of_activity()
RETURNS TRIGGER AS $$
DECLARE
    partner_user_id UUID;
    partner_device_token TEXT;
    room_member_count INTEGER;
BEGIN
    -- Get the partner's user ID from the same room
    SELECT COUNT(*) INTO room_member_count
    FROM public.duo_memberships 
    WHERE room_id = NEW.room_id;
    
    -- Only proceed if room has exactly 2 members (duo)
    IF room_member_count = 2 THEN
        SELECT profile_id INTO partner_user_id
        FROM public.duo_memberships 
        WHERE room_id = NEW.room_id 
        AND profile_id != NEW.author_id
        LIMIT 1;
        
        -- Get partner's device token
        SELECT device_token INTO partner_device_token
        FROM public.device_tokens 
        WHERE user_id = partner_user_id;
        
        -- If partner has device token, send push notification
        IF partner_device_token IS NOT NULL THEN
            -- Call edge function to send push notification
            -- This would require setting up a Supabase Edge Function
            PERFORM net.http_post(
                url := 'https://YOUR_PROJECT_ID.supabase.co/functions/v1/send-push-notification',
                headers := jsonb_build_object(
                    'Content-Type', 'application/json',
                    'Authorization', 'Bearer YOUR_SERVICE_ROLE_KEY'
                ),
                body := jsonb_build_object(
                    'device_token', partner_device_token,
                    'activity_type', NEW.activity_type,
                    'content', NEW.content,
                    'room_id', NEW.room_id
                )
            );
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically send push notifications
CREATE OR REPLACE TRIGGER trigger_notify_partner_of_activity
    AFTER INSERT ON public.duo_activities
    FOR EACH ROW
    EXECUTE FUNCTION notify_partner_of_activity();

-- Add updated_at trigger for device_tokens
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trigger_update_device_tokens_updated_at
    BEFORE UPDATE ON public.device_tokens
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Add comments
COMMENT ON TABLE public.device_tokens IS 'Stores device tokens for push notifications';
COMMENT ON COLUMN public.device_tokens.device_token IS 'APNs device token for iOS push notifications';
COMMENT ON COLUMN public.device_tokens.platform IS 'Platform type (ios, android)';

-- Verify the tables
SELECT table_name, column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'device_tokens' 
  AND table_schema = 'public'
ORDER BY ordinal_position;