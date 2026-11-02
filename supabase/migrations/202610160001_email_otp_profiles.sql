-- Email OTP keeps auth.users.id as the owner key for all existing RLS policies.
-- Apply after 202610150001_profiles.sql. This does not merge separate identities.
begin;

create or replace function public.create_profile_for_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    insert into public.profiles (id, email, phone, handle)
    values (
        new.id,
        coalesce(new.email, ''),
        coalesce(new.phone, ''),
        'raver_' || left(replace(new.id::text, '-', ''), 8)
    )
    on conflict (id) do nothing;

    insert into public.profile_preferences (user_id)
    values (new.id)
    on conflict (user_id) do nothing;
    return new;
end;
$$;

revoke execute on function public.create_profile_for_new_auth_user() from public, anon, authenticated;

-- Backfill only missing contact email; preserve user-edited contact details.
update public.profiles as profile
set email = account.email
from auth.users as account
where profile.id = account.id
  and btrim(coalesce(profile.email, '')) = ''
  and account.email_confirmed_at is not null
  and coalesce(account.email, '') <> '';

commit;
