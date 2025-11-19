-- Fix: Recreate the trigger with proper permissions
-- This ensures it works even if the original migration failed

-- Drop and recreate the function
DROP FUNCTION IF EXISTS public.initialize_duo_room_data() CASCADE;

CREATE OR REPLACE FUNCTION public.initialize_duo_room_data()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Insert default metrics
    INSERT INTO public.duo_metrics (room_id)
    VALUES (NEW.id)
    ON CONFLICT (room_id) DO NOTHING;

    -- Insert default farm with starter chicken
    INSERT INTO public.duo_farms (room_id, unlocked_animals)
    VALUES (NEW.id, '["chicken"]'::jsonb)
    ON CONFLICT (room_id) DO NOTHING;

    -- Insert initial timeline event
    INSERT INTO public.timeline_events (room_id, event_type, event_data)
    VALUES (
        NEW.id,
        'milestone',
        jsonb_build_object('message', 'Farm created! 🌾', 'icon', 'sparkles')
    );

    RETURN NEW;
END;
$$;

-- Drop and recreate the trigger
DROP TRIGGER IF EXISTS initialize_duo_data ON public.duo_rooms;

CREATE TRIGGER initialize_duo_data
    AFTER INSERT ON public.duo_rooms
    FOR EACH ROW
    EXECUTE FUNCTION public.initialize_duo_room_data();

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION public.initialize_duo_room_data() TO authenticated;
GRANT EXECUTE ON FUNCTION public.initialize_duo_room_data() TO service_role;

-- Test the trigger by checking if it fires
DO $$
DECLARE
    test_room_id uuid;
BEGIN
    -- Create a test room
    INSERT INTO public.duo_rooms (room_code, created_by)
    VALUES ('TEST_TRIGGER', (SELECT id FROM auth.users LIMIT 1))
    RETURNING id INTO test_room_id;

    -- Check if metrics and farm were created
    IF EXISTS (SELECT 1 FROM public.duo_metrics WHERE room_id = test_room_id) THEN
        RAISE NOTICE 'SUCCESS: duo_metrics created for test room';
    ELSE
        RAISE EXCEPTION 'FAILED: duo_metrics NOT created for test room';
    END IF;

    IF EXISTS (SELECT 1 FROM public.duo_farms WHERE room_id = test_room_id) THEN
        RAISE NOTICE 'SUCCESS: duo_farms created for test room';
    ELSE
        RAISE EXCEPTION 'FAILED: duo_farms NOT created for test room';
    END IF;

    -- Clean up test room
    DELETE FROM public.duo_rooms WHERE id = test_room_id;

    RAISE NOTICE 'Trigger test completed successfully!';
END $$;
