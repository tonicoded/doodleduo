-- ================================================
-- FIX MISSING LAST_ACTIVITY_AT COLUMN
-- Add the missing last_activity_at column to duo_farms table
-- This is required for the farm activity trigger to work
-- ================================================

BEGIN;

-- Add missing column to duo_farms table
ALTER TABLE public.duo_farms 
ADD COLUMN IF NOT EXISTS last_activity_at TIMESTAMPTZ DEFAULT NOW();

-- Add index for performance
CREATE INDEX IF NOT EXISTS idx_duo_farms_last_activity_at 
ON public.duo_farms(last_activity_at);

-- Update existing records to have a default value
UPDATE public.duo_farms 
SET last_activity_at = created_at 
WHERE last_activity_at IS NULL;

COMMIT;

-- Verify the column exists
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'duo_farms' 
AND table_schema = 'public'
AND column_name = 'last_activity_at';

-- Success message
DO $$
BEGIN
    RAISE NOTICE '✅ Added last_activity_at column to duo_farms table';
    RAISE NOTICE '✅ Activities should now work correctly!';
    RAISE NOTICE '🎉 Farm survival system is ready';
END $$;