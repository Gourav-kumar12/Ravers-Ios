-- Profile persistence for the iOS profile editor.
-- Safe to apply when the base profiles/profile_preferences tables already exist.

create table if not exists public.profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    display_name text not null default '',
    handle text,
    email text not null default '',
    phone text not null default '',
    city text not null default '',
    personality text not null default '',
    avatar_path text,
    is_discoverable boolean not null default false,
    is_profile_complete boolean not null default false,
    is_hosting_rave boolean not null default false,
    hosted_rave_name text not null default '',
    hosted_rave_date timestamptz not null default now(),
    hosted_rave_venue text not null default '',
    hosted_rave_details text not null default '',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

alter table public.profiles add column if not exists display_name text not null default '';
alter table public.profiles add column if not exists handle text;
alter table public.profiles add column if not exists email text not null default '';
alter table public.profiles add column if not exists phone text not null default '';
alter table public.profiles add column if not exists city text not null default '';
alter table public.profiles add column if not exists personality text not null default '';
alter table public.profiles add column if not exists avatar_path text;
alter table public.profiles add column if not exists is_discoverable boolean not null default false;
alter table public.profiles add column if not exists is_profile_complete boolean not null default false;
alter table public.profiles add column if not exists is_hosting_rave boolean not null default false;
alter table public.profiles add column if not exists hosted_rave_name text not null default '';
alter table public.profiles add column if not exists hosted_rave_date timestamptz not null default now();
alter table public.profiles add column if not exists hosted_rave_venue text not null default '';
alter table public.profiles add column if not exists hosted_rave_details text not null default '';
alter table public.profiles add column if not exists created_at timestamptz not null default now();
alter table public.profiles add column if not exists updated_at timestamptz not null default now();

update public.profiles
set handle = 'raver_' || left(replace(id::text, '-', ''), 8)
where handle is null or btrim(handle) = '';
alter table public.profiles alter column handle set not null;
create unique index if not exists profiles_handle_unique on public.profiles (lower(handle));

create table if not exists public.profile_preferences (
    user_id uuid primary key references auth.users(id) on delete cascade,
    genres text[] not null default '{}',
    venues text[] not null default '{}',
    party_styles text[] not null default '{}',
    favorite_artists text[] not null default '{}',
    anthem text,
    interested_in text[] not null default '{}',
    age_min smallint,
    age_max smallint,
    max_distance_km integer,
    show_my_area boolean not null default true,
    share_attendance boolean not null default true,
    notify_drops boolean not null default true,
    notify_party_alerts boolean not null default true,
    notify_sync_requests boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

alter table public.profile_preferences add column if not exists genres text[] not null default '{}';
alter table public.profile_preferences add column if not exists venues text[] not null default '{}';
alter table public.profile_preferences add column if not exists party_styles text[] not null default '{}';
alter table public.profile_preferences add column if not exists favorite_artists text[] not null default '{}';
alter table public.profile_preferences add column if not exists show_my_area boolean not null default true;
alter table public.profile_preferences add column if not exists share_attendance boolean not null default true;
alter table public.profile_preferences add column if not exists notify_drops boolean not null default true;
alter table public.profile_preferences add column if not exists notify_party_alerts boolean not null default true;
alter table public.profile_preferences add column if not exists notify_sync_requests boolean not null default true;
alter table public.profile_preferences add column if not exists created_at timestamptz not null default now();
alter table public.profile_preferences add column if not exists updated_at timestamptz not null default now();

create table if not exists public.profile_photos (
    user_id uuid not null references auth.users(id) on delete cascade,
    position smallint not null check (position between 0 and 5),
    storage_path text not null,
    created_at timestamptz not null default now(),
    primary key (user_id, position)
);

alter table public.profiles enable row level security;
alter table public.profile_preferences enable row level security;
alter table public.profile_photos enable row level security;

drop policy if exists profiles_select_own on public.profiles;
create policy profiles_select_own on public.profiles
    for select to authenticated using (id = (select auth.uid()));
drop policy if exists profiles_insert_own on public.profiles;
create policy profiles_insert_own on public.profiles
    for insert to authenticated with check (id = (select auth.uid()));
drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles
    for update to authenticated using (id = (select auth.uid()))
    with check (id = (select auth.uid()));

drop policy if exists profile_preferences_select_own on public.profile_preferences;
create policy profile_preferences_select_own on public.profile_preferences
    for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists profile_preferences_insert_own on public.profile_preferences;
create policy profile_preferences_insert_own on public.profile_preferences
    for insert to authenticated with check (user_id = (select auth.uid()));
drop policy if exists profile_preferences_update_own on public.profile_preferences;
create policy profile_preferences_update_own on public.profile_preferences
    for update to authenticated using (user_id = (select auth.uid()))
    with check (user_id = (select auth.uid()));

drop policy if exists profile_photos_select_own on public.profile_photos;
create policy profile_photos_select_own on public.profile_photos
    for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists profile_photos_insert_own on public.profile_photos;
create policy profile_photos_insert_own on public.profile_photos
    for insert to authenticated with check (user_id = (select auth.uid()));
drop policy if exists profile_photos_update_own on public.profile_photos;
create policy profile_photos_update_own on public.profile_photos
    for update to authenticated using (user_id = (select auth.uid()))
    with check (user_id = (select auth.uid()));
drop policy if exists profile_photos_delete_own on public.profile_photos;
create policy profile_photos_delete_own on public.profile_photos
    for delete to authenticated using (user_id = (select auth.uid()));

revoke all on public.profiles, public.profile_preferences, public.profile_photos from anon;
revoke all on public.profiles from authenticated;
grant select on public.profiles to authenticated;
grant insert (id, display_name, handle, email, phone, city, personality, avatar_path, is_discoverable, is_profile_complete, is_hosting_rave, hosted_rave_name, hosted_rave_date, hosted_rave_venue, hosted_rave_details)
    on public.profiles to authenticated;
grant update (id, display_name, handle, email, phone, city, personality, avatar_path, is_discoverable, is_profile_complete, is_hosting_rave, hosted_rave_name, hosted_rave_date, hosted_rave_venue, hosted_rave_details, updated_at)
    on public.profiles to authenticated;
grant select, insert, update on public.profile_preferences to authenticated;
grant select, insert, update, delete on public.profile_photos to authenticated;

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

drop trigger if exists profiles_touch_updated_at on public.profiles;
create trigger profiles_touch_updated_at before update on public.profiles
    for each row execute function public.touch_updated_at();
drop trigger if exists profile_preferences_touch_updated_at on public.profile_preferences;
create trigger profile_preferences_touch_updated_at before update on public.profile_preferences
    for each row execute function public.touch_updated_at();

create or replace function public.create_profile_for_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    insert into public.profiles (id, phone, handle)
    values (new.id, coalesce(new.phone, ''), 'raver_' || left(replace(new.id::text, '-', ''), 8))
    on conflict (id) do nothing;
    insert into public.profile_preferences (user_id)
    values (new.id)
    on conflict (user_id) do nothing;
    return new;
end;
$$;

drop trigger if exists on_auth_user_created_profile on auth.users;
create trigger on_auth_user_created_profile
    after insert on auth.users
    for each row execute function public.create_profile_for_new_auth_user();

insert into storage.buckets (id, name, public)
values ('profile-images', 'profile-images', true)
on conflict (id) do update set public = excluded.public;

drop policy if exists profile_images_public_read on storage.objects;
create policy profile_images_public_read on storage.objects
    for select using (bucket_id = 'profile-images');
drop policy if exists profile_images_owner_insert on storage.objects;
create policy profile_images_owner_insert on storage.objects
    for insert to authenticated
    with check (bucket_id = 'profile-images' and (storage.foldername(name))[1] = (select auth.uid())::text);
drop policy if exists profile_images_owner_update on storage.objects;
create policy profile_images_owner_update on storage.objects
    for update to authenticated
    using (bucket_id = 'profile-images' and (storage.foldername(name))[1] = (select auth.uid())::text)
    with check (bucket_id = 'profile-images' and (storage.foldername(name))[1] = (select auth.uid())::text);
drop policy if exists profile_images_owner_delete on storage.objects;
create policy profile_images_owner_delete on storage.objects
    for delete to authenticated
    using (bucket_id = 'profile-images' and (storage.foldername(name))[1] = (select auth.uid())::text);
