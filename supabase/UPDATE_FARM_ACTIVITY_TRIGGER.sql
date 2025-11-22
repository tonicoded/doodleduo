-- ================================================
-- UPDATE FARM ACTIVITY TRIGGER
-- Update last_activity_at when activities are created
-- This powers the survival timer system
-- ================================================

BEGIN;

-- Create function to update farm's last_activity_at
CREATE OR REPLACE FUNCTION public.update_farm_activity_timestamp()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    -- Update the farm's last_activity_at for this room
    UPDATE public.duo_farms
    SET last_activity_at = NEW.created_at
    WHERE room_id = NEW.room_id;

    RAISE NOTICE '🕒 Updated farm last_activity_at for room: %', NEW.room_id;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.update_farm_activity_timestamp() IS
    'Updates duo_farms.last_activity_at whenever a new activity is created to track survival timer';

-- Create trigger on duo_activities
DROP TRIGGER IF EXISTS update_farm_activity_on_activity ON public.duo_activities;

CREATE TRIGGER update_farm_activity_on_activity
    AFTER INSERT ON public.duo_activities
    FOR EACH ROW
    EXECUTE FUNCTION public.update_farm_activity_timestamp();

COMMIT;

SELECT '✅ Farm activity timestamp trigger created successfully!' as status;
