-- doodleduo Supabase schema
-- Run this script inside the SQL editor in https://app.supabase.com on the "reevrasmalgiftakwsao" project.

create extension if not exists "pgcrypto";

create table if not exists public.profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    display_name text,
    apple_email text,
    onboarding_complete boolean not null default false,
    last_seen_at timestamptz not null default timezone('utc', now()),
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now())
);

create or replace function public.handle_profile_updated_at()
returns trigger as $$
begin
    new.updated_at = timezone('utc', now());
    return new;
end;
$$ language plpgsql;

drop trigger if exists set_profiles_updated_at on public.profiles;
create trigger set_profiles_updated_at
before update on public.profiles
for each row execute procedure public.handle_profile_updated_at();

alter table public.profiles enable row level security;

drop policy if exists "Profiles are selectable by owner" on public.profiles;
create policy "Profiles are selectable by owner"
on public.profiles
for select
using (auth.uid() = id);

drop policy if exists "Profiles are insertable by owner" on public.profiles;
create policy "Profiles are insertable by owner"
on public.profiles
for insert
with check (auth.uid() = id);

drop policy if exists "Profiles are updatable by owner" on public.profiles;
create policy "Profiles are updatable by owner"
on public.profiles
for update
using (auth.uid() = id)
with check (auth.uid() = id);

drop policy if exists "Profiles visible to duo partners" on public.profiles;
create policy "Profiles visible to duo partners"
on public.profiles
for select
using (
    auth.uid() = id
    or exists (
        select 1
        from public.duo_memberships dm_self
        join public.duo_memberships dm_partner
          on dm_self.room_id = dm_partner.room_id
        where dm_self.profile_id = auth.uid()
          and dm_partner.profile_id = profiles.id
    )
);

create table if not exists public.duo_rooms (
    id uuid primary key default gen_random_uuid(),
    room_code text not null unique,
    room_name text,
    created_by uuid not null references public.profiles(id) on delete cascade,
    created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.duo_memberships (
    profile_id uuid not null references public.profiles(id) on delete cascade,
    room_id uuid not null references public.duo_rooms(id) on delete cascade,
    joined_at timestamptz not null default timezone('utc', now()),
    primary key (profile_id, room_id)
);

alter table public.duo_rooms enable row level security;
alter table public.duo_memberships enable row level security;

drop policy if exists "Rooms visible to members" on public.duo_rooms;
create policy "Rooms visible to members"
on public.duo_rooms
for select
using (
    exists (
        select 1 from public.duo_memberships dm
        where dm.room_id = duo_rooms.id
          and dm.profile_id = auth.uid()
    )
);

drop policy if exists "Rooms creatable by owners" on public.duo_rooms;
create policy "Rooms creatable by owners"
on public.duo_rooms
for insert
with check (created_by = auth.uid());

drop policy if exists "Room owners can update" on public.duo_rooms;
create policy "Room owners can update"
on public.duo_rooms
for update
using (created_by = auth.uid())
with check (created_by = auth.uid());

drop policy if exists "Memberships visible to self" on public.duo_memberships;
create policy "Memberships visible to self"
on public.duo_memberships
for select
using (profile_id = auth.uid());

drop policy if exists "Memberships insertable by self" on public.duo_memberships;
create policy "Memberships insertable by self"
on public.duo_memberships
for insert
with check (profile_id = auth.uid());
