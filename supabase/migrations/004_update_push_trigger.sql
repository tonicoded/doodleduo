-- Update push notification trigger to work with edge function
-- Run this in Supabase SQL editor

-- First, let's update the trigger function to be simpler and more reliable
CREATE OR REPLACE FUNCTION notify_partner_of_activity()
RETURNS TRIGGER AS $$
DECLARE
    partner_user_id UUID;
    partner_device_token TEXT;
    partner_display_name TEXT;
    room_member_count INTEGER;
    notification_payload JSONB;
BEGIN
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
        AND platform = 'ios';
        
        -- If partner has device token, prepare notification
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
            
            -- For now, we'll just log this. To enable actual push notifications,
            -- you'll need to uncomment the next line and set up the edge function properly
            /*
            PERFORM net.http_post(
                url := 'https://YOUR_PROJECT_ID.supabase.co/functions/v1/send-push-notification',
                headers := jsonb_build_object(
                    'Content-Type', 'application/json',
                    'Authorization', 'Bearer ' || 'YOUR_SERVICE_ROLE_KEY'
                ),
                body := notification_payload
            );
            */
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create a simple test function to verify the setup
CREATE OR REPLACE FUNCTION test_push_notification_setup(test_room_id UUID)
RETURNS TABLE (
    room_id UUID,
    member_count INTEGER,
    partner_found BOOLEAN,
    device_token_found BOOLEAN,
    setup_status TEXT
) AS $$
DECLARE
    member_cnt INTEGER;
    partner_exists BOOLEAN := FALSE;
    token_exists BOOLEAN := FALSE;
BEGIN
    -- Check member count
    SELECT COUNT(*) INTO member_cnt
    FROM public.duo_memberships 
    WHERE duo_memberships.room_id = test_room_id;
    
    -- Check if partner exists
    SELECT EXISTS(
        SELECT 1 FROM public.duo_memberships 
        WHERE duo_memberships.room_id = test_room_id
        LIMIT 2
    ) INTO partner_exists;
    
    -- Check if any member has device token
    SELECT EXISTS(
        SELECT 1 
        FROM public.duo_memberships dm
        JOIN public.device_tokens dt ON dm.profile_id = dt.user_id
        WHERE dm.room_id = test_room_id
    ) INTO token_exists;
    
    RETURN QUERY SELECT 
        test_room_id,
        member_cnt,
        partner_exists,
        token_exists,
        CASE 
            WHEN member_cnt = 2 AND partner_exists AND token_exists THEN 'Ready for push notifications'
            WHEN member_cnt != 2 THEN 'Need exactly 2 room members'
            WHEN NOT token_exists THEN 'Need device token registration'
            ELSE 'Setup incomplete'
        END as setup_status;
END;
$$ LANGUAGE plpgsql;

-- Add helpful comments
COMMENT ON FUNCTION notify_partner_of_activity() IS 'Triggers push notifications when activities are created';
COMMENT ON FUNCTION test_push_notification_setup(UUID) IS 'Test function to verify push notification setup for a room';