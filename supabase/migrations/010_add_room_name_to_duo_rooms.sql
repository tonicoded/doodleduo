-- Add friendly room names for duo rooms
ALTER TABLE public.duo_rooms
ADD COLUMN IF NOT EXISTS room_name text;

COMMENT ON COLUMN public.duo_rooms.room_name IS 'Optional display name chosen by the couple (ex. Cozy Farm)';
