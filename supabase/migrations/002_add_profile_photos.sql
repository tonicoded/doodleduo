-- Add profile photo support
-- Run this in Supabase SQL editor

-- Add profile_photo_url column to existing profiles table
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS profile_photo_url TEXT;

-- Update the profiles table comment
COMMENT ON COLUMN public.profiles.profile_photo_url IS 'URL to user profile photo stored in Supabase Storage';

-- Allow duo partners to read each other's profile photo URLs
DROP POLICY IF EXISTS "Profiles visible to duo partners" ON public.profiles;
CREATE POLICY "Profiles visible to duo partners"
ON public.profiles
FOR SELECT
USING (
    auth.uid() = id
    OR EXISTS (
        SELECT 1
        FROM public.duo_memberships dm_self
        JOIN public.duo_memberships dm_partner
          ON dm_self.room_id = dm_partner.room_id
        WHERE dm_self.profile_id = auth.uid()
          AND dm_partner.profile_id = public.profiles.id
    )
);

-- Verify the change
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'profiles' 
  AND table_schema = 'public'
ORDER BY ordinal_position;
