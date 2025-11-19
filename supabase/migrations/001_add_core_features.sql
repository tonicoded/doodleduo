-- DoodleDuo Phase 1 Migration: Core Features
-- Adds doodles, metrics, farm progression, prompts, and timeline tables

-- ============================================
-- 1. DOODLES TABLE
-- ============================================
-- Stores all drawings created in duo rooms
create table if not exists public.doodles (
    id uuid primary key default gen_random_uuid(),
    room_id uuid not null references public.duo_rooms(id) on delete cascade,
    author_id uuid not null references public.profiles(id) on delete cascade,
    drawing_data jsonb not null, -- stroke data: {strokes: [{points: [], color: "", width: 0}]}
    thumbnail_url text, -- optional preview image URL
    is_prompt_response boolean not null default false,
    prompt_id uuid, -- nullable, references daily_prompts if applicable
    created_at timestamptz not null default timezone('utc', now())
);

-- Index for fetching room's doodles
create index if not exists doodles_room_id_created_at_idx
    on public.doodles(room_id, created_at desc);

-- Index for author's doodles
create index if not exists doodles_author_id_idx
    on public.doodles(author_id);

alter table public.doodles enable row level security;

-- Members can view all doodles in their room
drop policy if exists "Room members can view doodles" on public.doodles;
create policy "Room members can view doodles"
on public.doodles
for select
using (
    exists (
        select 1 from public.duo_memberships dm
        where dm.room_id = doodles.room_id
          and dm.profile_id = auth.uid()
    )
);

-- Members can create doodles in their room
drop policy if exists "Room members can create doodles" on public.doodles;
create policy "Room members can create doodles"
on public.doodles
for insert
with check (
    author_id = auth.uid() and
    exists (
        select 1 from public.duo_memberships dm
        where dm.room_id = doodles.room_id
          and dm.profile_id = auth.uid()
    )
);

-- Authors can delete their own doodles
drop policy if exists "Authors can delete own doodles" on public.doodles;
create policy "Authors can delete own doodles"
on public.doodles
for delete
using (author_id = auth.uid());

-- ============================================
-- 2. DUO METRICS TABLE
-- ============================================
-- Tracks energy, streaks, and activity for each duo room
create table if not exists public.duo_metrics (
    room_id uuid primary key references public.duo_rooms(id) on delete cascade,
    love_energy int not null default 0,
    total_doodles int not null default 0,
    total_strokes int not null default 0,
    current_streak int not null default 0,
    longest_streak int not null default 0,
    last_activity_date date,
    last_activity_profile_id uuid references public.profiles(id) on delete set null,
    hardcore_mode boolean not null default false,
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now())
);

-- Trigger to auto-update updated_at
drop trigger if exists set_duo_metrics_updated_at on public.duo_metrics;
create trigger set_duo_metrics_updated_at
before update on public.duo_metrics
for each row execute procedure public.handle_profile_updated_at(); -- reuse existing function

alter table public.duo_metrics enable row level security;

-- Members can view their room's metrics
drop policy if exists "Room members can view metrics" on public.duo_metrics;
create policy "Room members can view metrics"
on public.duo_metrics
for select
using (
    exists (
        select 1 from public.duo_memberships dm
        where dm.room_id = duo_metrics.room_id
          and dm.profile_id = auth.uid()
    )
);

-- Members can update their room's metrics
drop policy if exists "Room members can update metrics" on public.duo_metrics;
create policy "Room members can update metrics"
on public.duo_metrics
for update
using (
    exists (
        select 1 from public.duo_memberships dm
        where dm.room_id = duo_metrics.room_id
          and dm.profile_id = auth.uid()
    )
)
with check (
    exists (
        select 1 from public.duo_memberships dm
        where dm.room_id = duo_metrics.room_id
          and dm.profile_id = auth.uid()
    )
);

-- Members can insert metrics (when creating room)
drop policy if exists "Room creators can insert metrics" on public.duo_metrics;
create policy "Room creators can insert metrics"
on public.duo_metrics
for insert
with check (
    exists (
        select 1 from public.duo_memberships dm
        where dm.room_id = duo_metrics.room_id
          and dm.profile_id = auth.uid()
    )
);

-- ============================================
-- 3. DUO FARMS TABLE
-- ============================================
-- Stores farm progression and unlocked animals
create table if not exists public.duo_farms (
    room_id uuid primary key references public.duo_rooms(id) on delete cascade,
    unlocked_animals jsonb not null default '[]', -- e.g., ["chicken", "sheep", "pig"]
    farm_level int not null default 1,
    theme text not null default 'default', -- 'default', 'christmas', 'valentine', 'spring', 'halloween'
    animals_sleeping boolean not null default false, -- true when hardcore streak broken
    last_unlock_at timestamptz,
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now())
);

-- Trigger to auto-update updated_at
drop trigger if exists set_duo_farms_updated_at on public.duo_farms;
create trigger set_duo_farms_updated_at
before update on public.duo_farms
for each row execute procedure public.handle_profile_updated_at();

alter table public.duo_farms enable row level security;

-- Members can view their farm
drop policy if exists "Room members can view farm" on public.duo_farms;
create policy "Room members can view farm"
on public.duo_farms
for select
using (
    exists (
        select 1 from public.duo_memberships dm
        where dm.room_id = duo_farms.room_id
          and dm.profile_id = auth.uid()
    )
);

-- Members can update their farm
drop policy if exists "Room members can update farm" on public.duo_farms;
create policy "Room members can update farm"
on public.duo_farms
for update
using (
    exists (
        select 1 from public.duo_memberships dm
        where dm.room_id = duo_farms.room_id
          and dm.profile_id = auth.uid()
    )
)
with check (
    exists (
        select 1 from public.duo_memberships dm
        where dm.room_id = duo_farms.room_id
          and dm.profile_id = auth.uid()
    )
);

-- Members can insert farm (when creating room)
drop policy if exists "Room creators can insert farm" on public.duo_farms;
create policy "Room creators can insert farm"
on public.duo_farms
for insert
with check (
    exists (
        select 1 from public.duo_memberships dm
        where dm.room_id = duo_farms.room_id
          and dm.profile_id = auth.uid()
    )
);

-- ============================================
-- 4. DAILY PROMPTS TABLE
-- ============================================
-- Tracks daily prompts and completion status
create table if not exists public.daily_prompts (
    id uuid primary key default gen_random_uuid(),
    room_id uuid not null references public.duo_rooms(id) on delete cascade,
    prompt_text text not null,
    prompt_category text not null default 'general', -- 'romantic', 'playful', 'reflective', 'quick'
    prompt_date date not null,
    completed_by uuid[] not null default '{}', -- array of profile_ids who completed it
    completed_doodle_ids uuid[] not null default '{}', -- array of doodle_ids
    created_at timestamptz not null default timezone('utc', now()),
    unique(room_id, prompt_date)
);

-- Index for fetching room's prompts by date
create index if not exists daily_prompts_room_date_idx
    on public.daily_prompts(room_id, prompt_date desc);

alter table public.daily_prompts enable row level security;

-- Members can view their room's prompts
drop policy if exists "Room members can view prompts" on public.daily_prompts;
create policy "Room members can view prompts"
on public.daily_prompts
for select
using (
    exists (
        select 1 from public.duo_memberships dm
        where dm.room_id = daily_prompts.room_id
          and dm.profile_id = auth.uid()
    )
);

-- Members can insert prompts
drop policy if exists "Room members can insert prompts" on public.daily_prompts;
create policy "Room members can insert prompts"
on public.daily_prompts
for insert
with check (
    exists (
        select 1 from public.duo_memberships dm
        where dm.room_id = daily_prompts.room_id
          and dm.profile_id = auth.uid()
    )
);

-- Members can update prompts (mark as completed)
drop policy if exists "Room members can update prompts" on public.daily_prompts;
create policy "Room members can update prompts"
on public.daily_prompts
for update
using (
    exists (
        select 1 from public.duo_memberships dm
        where dm.room_id = daily_prompts.room_id
          and dm.profile_id = auth.uid()
    )
)
with check (
    exists (
        select 1 from public.duo_memberships dm
        where dm.room_id = daily_prompts.room_id
          and dm.profile_id = auth.uid()
    )
);

-- ============================================
-- 5. TIMELINE EVENTS TABLE
-- ============================================
-- Auto-generated events for memory timeline
create table if not exists public.timeline_events (
    id uuid primary key default gen_random_uuid(),
    room_id uuid not null references public.duo_rooms(id) on delete cascade,
    event_type text not null, -- 'doodle', 'milestone', 'animal_unlock', 'streak', 'prompt_complete'
    event_data jsonb not null, -- flexible data: {animal: "chicken", level: 5, etc.}
    event_date timestamptz not null default timezone('utc', now())
);

-- Index for fetching room's timeline
create index if not exists timeline_events_room_date_idx
    on public.timeline_events(room_id, event_date desc);

-- Index for filtering by event type
create index if not exists timeline_events_type_idx
    on public.timeline_events(event_type);

alter table public.timeline_events enable row level security;

-- Members can view their timeline
drop policy if exists "Room members can view timeline" on public.timeline_events;
create policy "Room members can view timeline"
on public.timeline_events
for select
using (
    exists (
        select 1 from public.duo_memberships dm
        where dm.room_id = timeline_events.room_id
          and dm.profile_id = auth.uid()
    )
);

-- Members can insert timeline events
drop policy if exists "Room members can insert timeline" on public.timeline_events;
create policy "Room members can insert timeline"
on public.timeline_events
for insert
with check (
    exists (
        select 1 from public.duo_memberships dm
        where dm.room_id = timeline_events.room_id
          and dm.profile_id = auth.uid()
    )
);

-- ============================================
-- 6. HELPER FUNCTIONS
-- ============================================

-- Function to initialize farm and metrics when room is created
create or replace function public.initialize_duo_room_data()
returns trigger as $$
begin
    -- Insert default metrics
    insert into public.duo_metrics (room_id)
    values (new.id)
    on conflict (room_id) do nothing;

    -- Insert default farm with starter chicken
    insert into public.duo_farms (room_id, unlocked_animals)
    values (new.id, '["chicken"]'::jsonb)
    on conflict (room_id) do nothing;

    -- Insert initial timeline event
    insert into public.timeline_events (room_id, event_type, event_data)
    values (
        new.id,
        'milestone',
        jsonb_build_object('message', 'Farm created! 🌾', 'icon', 'sparkles')
    );

    return new;
end;
$$ language plpgsql security definer;

-- Trigger to auto-initialize data when duo_room is created
drop trigger if exists initialize_duo_data on public.duo_rooms;
create trigger initialize_duo_data
after insert on public.duo_rooms
for each row execute procedure public.initialize_duo_room_data();

-- Function to calculate streak (called from app or cron job)
create or replace function public.update_streak_for_room(
    p_room_id uuid,
    p_profile_id uuid,
    p_activity_date date default current_date
)
returns jsonb as $$
declare
    v_metrics record;
    v_new_streak int;
    v_streak_broken boolean := false;
    v_days_since_last int;
begin
    -- Fetch current metrics
    select * into v_metrics
    from public.duo_metrics
    where room_id = p_room_id;

    if not found then
        raise exception 'Room metrics not found';
    end if;

    -- Calculate days since last activity
    if v_metrics.last_activity_date is null then
        v_days_since_last := 999;
    else
        v_days_since_last := p_activity_date - v_metrics.last_activity_date;
    end if;

    -- Determine new streak
    if v_days_since_last = 0 then
        -- Same day, no change
        v_new_streak := v_metrics.current_streak;
    elsif v_days_since_last = 1 then
        -- Consecutive day, increment
        v_new_streak := v_metrics.current_streak + 1;
    else
        -- Gap detected
        if v_metrics.hardcore_mode then
            -- Hardcore: reset to 0
            v_new_streak := 0;
            v_streak_broken := true;

            -- Put animals to sleep
            update public.duo_farms
            set animals_sleeping = true
            where room_id = p_room_id;
        else
            -- Normal: pause but don't reset
            v_new_streak := v_metrics.current_streak;
        end if;
    end if;

    -- Update metrics
    update public.duo_metrics
    set
        current_streak = v_new_streak,
        longest_streak = greatest(longest_streak, v_new_streak),
        last_activity_date = p_activity_date,
        last_activity_profile_id = p_profile_id
    where room_id = p_room_id;

    -- Create timeline event for milestones
    if v_new_streak > 0 and v_new_streak % 5 = 0 then
        insert into public.timeline_events (room_id, event_type, event_data)
        values (
            p_room_id,
            'streak',
            jsonb_build_object('days', v_new_streak, 'message', format('%s day streak! 🔥', v_new_streak))
        );
    end if;

    -- Create event if streak broken
    if v_streak_broken then
        insert into public.timeline_events (room_id, event_type, event_data)
        values (
            p_room_id,
            'milestone',
            jsonb_build_object('message', 'Streak broken. Animals are sleeping. 😴', 'icon', 'moon.zzz')
        );
    end if;

    return jsonb_build_object(
        'new_streak', v_new_streak,
        'streak_broken', v_streak_broken,
        'days_since_last', v_days_since_last
    );
end;
$$ language plpgsql security definer;

-- Grant execute permissions
grant execute on function public.update_streak_for_room to authenticated;

-- ============================================
-- 7. REALTIME PUBLICATION
-- ============================================
-- Enable realtime for key tables
alter publication supabase_realtime add table public.doodles;
alter publication supabase_realtime add table public.duo_metrics;
alter publication supabase_realtime add table public.duo_farms;
alter publication supabase_realtime add table public.timeline_events;

-- Note: If publication doesn't exist, run:
-- create publication supabase_realtime;
-- Then add tables as above.

-- ============================================
-- END OF MIGRATION
-- ============================================

-- Verification queries (run these to test):
-- select * from public.duo_metrics;
-- select * from public.duo_farms;
-- select * from public.doodles limit 10;
-- select * from public.timeline_events order by event_date desc limit 20;
