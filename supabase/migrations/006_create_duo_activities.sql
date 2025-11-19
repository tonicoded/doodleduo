-- Create duo_activities table
-- This table stores all activities (pings, hugs, kisses, notes, doodles)
-- The app creates activities when users interact, and push notifications are sent via trigger

-- Create the duo_activities table
CREATE TABLE IF NOT EXISTS public.duo_activities (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    room_id UUID NOT NULL REFERENCES public.duo_rooms(id) ON DELETE CASCADE,
    author_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    activity_type TEXT NOT NULL CHECK (activity_type IN ('ping', 'hug', 'kiss', 'note', 'doodle')),
    content TEXT NOT NULL DEFAULT '',
    love_points_earned INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS duo_activities_room_id_created_at_idx
    ON public.duo_activities(room_id, created_at DESC);

CREATE INDEX IF NOT EXISTS duo_activities_author_id_idx
    ON public.duo_activities(author_id);

-- Enable RLS
ALTER TABLE public.duo_activities ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Room members can view all activities in their room
DROP POLICY IF EXISTS "Room members can view activities" ON public.duo_activities;
CREATE POLICY "Room members can view activities"
ON public.duo_activities
FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM public.duo_memberships dm
        WHERE dm.room_id = duo_activities.room_id
          AND dm.profile_id = auth.uid()
    )
);

-- RLS Policy: Room members can create activities in their room
DROP POLICY IF EXISTS "Room members can create activities" ON public.duo_activities;
CREATE POLICY "Room members can create activities"
ON public.duo_activities
FOR INSERT
WITH CHECK (
    author_id = auth.uid() AND
    EXISTS (
        SELECT 1 FROM public.duo_memberships dm
        WHERE dm.room_id = duo_activities.room_id
          AND dm.profile_id = auth.uid()
    )
);

-- RLS Policy: Authors can delete their own activities
DROP POLICY IF EXISTS "Authors can delete own activities" ON public.duo_activities;
CREATE POLICY "Authors can delete own activities"
ON public.duo_activities
FOR DELETE
USING (author_id = auth.uid());

-- Add helpful comments
COMMENT ON TABLE public.duo_activities IS 'Stores all partner activities: pings, hugs, kisses, notes, and doodles';
COMMENT ON COLUMN public.duo_activities.activity_type IS 'Type of activity: ping, hug, kiss, note, or doodle';
COMMENT ON COLUMN public.duo_activities.content IS 'Activity content (note text or base64 doodle image)';
COMMENT ON COLUMN public.duo_activities.love_points_earned IS 'Love points earned for this activity';

-- Success message
DO $$
BEGIN
    RAISE NOTICE '✅ duo_activities table created successfully!';
    RAISE NOTICE '✅ The push notification trigger from migration 005 will now work';
    RAISE NOTICE '✅ App can now create activities and send push notifications';
END $$;
