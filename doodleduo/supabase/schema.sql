-- doodleduo Supabase schema
--
-- Run this script once in the Supabase SQL editor (or via `supabase db push`)
-- to create the core duo tables plus indexes and baseline RLS.

create extension if not exists "uuid-ossp";

-- 1) Users keyed by Supabase auth UID
create table if not exists public.duo_users (
    id uuid primary key default uuid_generate_v4(),
    auth_uid uuid not null unique,
    display_name text,
    created_at timestamptz not null default now()
);

-- 2) Duo rooms
create table if not exists public.duos (
    id uuid primary key default uuid_generate_v4(),
    room_code text not null unique,
    created_at timestamptz not null default now(),
    last_activity timestamptz,
    hardcore boolean default false
);

-- 3) Membership (two rows per duo max)
create table if not exists public.duo_members (
    id uuid primary key default uuid_generate_v4(),
    duo_id uuid not null references public.duos(id) on delete cascade,
    user_id uuid not null references public.duo_users(id) on delete cascade,
    joined_at timestamptz not null default now(),
    unique (duo_id, user_id)
);

-- 4) Doodle events for XP / timeline
create table if not exists public.doodle_events (
    id uuid primary key default uuid_generate_v4(),
    duo_id uuid not null references public.duos(id) on delete cascade,
    user_id uuid references public.duo_users(id) on delete set null,
    kind text not null check (kind in ('stroke', 'sticker', 'prompt', 'love_ping', 'reveal')),
    payload jsonb,
    xp_value int not null default 1,
    created_at timestamptz not null default now()
);

-- 5) Farm/streak tracking
create table if not exists public.duo_progress (
    duo_id uuid primary key references public.duos(id) on delete cascade,
    xp_total int not null default 0,
    streak_normal int not null default 0,
    streak_hardcore int not null default 0,
    last_action_date date,
    hardcore_sleep_until timestamptz
);

-- 6) Simple memory timeline entries
create table if not exists public.duo_memories (
    id uuid primary key default uuid_generate_v4(),
    duo_id uuid not null references public.duos(id) on delete cascade,
    snapshot_url text,
    caption text,
    created_at timestamptz not null default now()
);

-- Helpful indexes
create index if not exists idx_duos_room_code on public.duos(room_code);
create index if not exists idx_events_duo_created on public.doodle_events(duo_id, created_at desc);
create index if not exists idx_members_user on public.duo_members(user_id);

-- Enable Row Level Security
alter table public.duo_users enable row level security;
alter table public.duos enable row level security;
alter table public.duo_members enable row level security;
alter table public.doodle_events enable row level security;
alter table public.duo_progress enable row level security;
alter table public.duo_memories enable row level security;

-- Profiles table for display names
create table if not exists public.profiles (
    id uuid primary key,
    display_name text,
    apple_email text,
    created_at timestamptz not null default now(),
    updated_at timestamptz,
    last_seen_at timestamptz
);

alter table public.profiles enable row level security;

drop policy if exists "owners manage profile" on public.profiles;
create policy "owners manage profile" on public.profiles
    for all
    using (auth.uid() = id)
    with check (auth.uid() = id);

drop policy if exists "users can manage themselves" on public.duo_users;
create policy "users can manage themselves" on public.duo_users
    for all
    using (auth.uid() = auth_uid)
    with check (auth.uid() = auth_uid);

create or replace function public.can_view_duo_user(target_user uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
    if target_user is null then
        return false;
    end if;
    if exists (
        select 1
        from public.duo_users
        where id = target_user
          and auth_uid = auth.uid()
    ) then
        return true;
    end if;
    return exists (
        select 1
        from public.duo_users du_self
        join public.duo_members dm_self on dm_self.user_id = du_self.id
        join public.duo_members dm_partner on dm_partner.duo_id = dm_self.duo_id
        where du_self.auth_uid = auth.uid()
          and dm_partner.user_id = target_user
    );
end;
$$;

grant execute on function public.can_view_duo_user(target_user uuid) to anon, authenticated;

drop policy if exists "duo users visible to roommates" on public.duo_users;
create policy "duo users visible to roommates" on public.duo_users
    for select
    using (public.can_view_duo_user(id));

-- Duos policies
drop policy if exists "members can read their duos" on public.duos;
create policy "members can read their duos" on public.duos
    for select
    using (
        exists (
            select 1
            from public.duo_members dm
            join public.duo_users du on du.id = dm.user_id
            where dm.duo_id = duos.id
              and du.auth_uid = auth.uid()
        )
    );

drop policy if exists "users can create duos" on public.duos;
create policy "users can create duos" on public.duos
    for insert
    with check (auth.uid() = auth.uid());

create or replace function public.duo_lookup_by_code(invite text)
returns table(id uuid, room_code text)
language sql
security definer
set search_path = public
as $$
    select id, room_code
    from public.duos
    where room_code = invite;
$$;

grant execute on function public.duo_lookup_by_code(invite text) to anon, authenticated;

drop policy if exists "members can view membership" on public.duo_members;
create or replace function public.can_access_duo_member(target_duo uuid, target_user uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
    if target_duo is null or target_user is null then
        return false;
    end if;
    if exists (
        select 1 from public.duo_users
        where id = target_user and auth_uid = auth.uid()
    ) then
        return true;
    end if;
    return exists (
        select 1
        from public.duo_users du_self
        join public.duo_members dm_self on dm_self.user_id = du_self.id
        where du_self.auth_uid = auth.uid()
          and dm_self.duo_id = target_duo
    );
end;
$$;

grant execute on function public.can_access_duo_member(target_duo uuid, target_user uuid) to anon, authenticated;

create policy "members can view membership" on public.duo_members
    for select
    using (public.can_access_duo_member(duo_id, user_id));

drop policy if exists "members manage their rows" on public.duo_members;
create policy "members manage their rows" on public.duo_members
    for all
    using (public.can_access_duo_member(duo_id, user_id))
    with check (public.can_access_duo_member(duo_id, user_id));

drop policy if exists "members can read duo events" on public.doodle_events;
create policy "members can read duo events" on public.doodle_events
    for select
    using (
        exists (
            select 1
            from public.duo_members dm
            join public.duo_users du on du.id = dm.user_id
            where dm.duo_id = doodle_events.duo_id
              and du.auth_uid = auth.uid()
        )
    );

drop policy if exists "members can read duo progress" on public.duo_progress;
create policy "members can read duo progress" on public.duo_progress
    for select
    using (
        exists (
            select 1
            from public.duo_members dm
            join public.duo_users du on du.id = dm.user_id
            where dm.duo_id = duo_progress.duo_id
              and du.auth_uid = auth.uid()
        )
    );

drop policy if exists "members can read memories" on public.duo_memories;
create policy "members can read memories" on public.duo_memories
    for select
    using (
        exists (
            select 1
            from public.duo_members dm
            join public.duo_users du on du.id = dm.user_id
            where dm.duo_id = duo_memories.duo_id
              and du.auth_uid = auth.uid()
        )
    );

-- NOTE: Insert/update/delete policies for duos/events/progress/memories are omitted
-- because the app is expected to go through Supabase Edge Functions / RPC calls
-- (service role) when mutating shared duo data. Add more permissive policies if
-- you choose to call these tables directly from the client.
