-- Account-owned sample activity. Real matches remain in partner_matches;
-- sample history can never grant access to another person's conversation.
begin;

create table public.partner_sample_history (
    user_id uuid primary key references public.profiles(id) on delete cascade,
    history jsonb not null,
    revision bigint not null default 1 check (revision > 0),
    updated_at timestamptz not null default now(),
    check (jsonb_typeof(history) = 'object' and octet_length(history::text) <= 4194304),
    check (jsonb_typeof(history->'matches') = 'array'
        and jsonb_typeof(history->'messages') = 'object'
        and jsonb_typeof(history->'dismissedIDs') = 'array'),
    check (history ?& array['matches', 'messages', 'dismissedIDs'])
);
alter table public.partner_sample_history enable row level security;
create policy sample_history_read_own on public.partner_sample_history
    for select to authenticated using (user_id = (select auth.uid()));
revoke all on public.partner_sample_history from public, anon, authenticated;
grant select on public.partner_sample_history to authenticated;

-- Compare revisions so an older device cannot silently overwrite a more recent
-- match, unmatch, or message. The client refreshes and retries on a conflict.
create function public.save_partner_sample_history(p_history jsonb, p_revision bigint)
returns setof public.partner_sample_history
language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); saved public.partner_sample_history;
begin
    if actor is null or not exists (select 1 from auth.users u
        where u.id = actor and u.email_confirmed_at is not null
        and coalesce(u.email, '') <> '' and not coalesce(u.is_anonymous, false)) then
        raise exception 'Sign in again to save your connections.' using errcode = '42501';
    end if;
    if p_history is null or p_revision is null or p_revision < 0 then
        raise exception 'Invalid connection history.' using errcode = '22023';
    end if;
    if p_revision = 0 then
        insert into public.partner_sample_history(user_id, history)
            values(actor, p_history) on conflict(user_id) do nothing returning * into saved;
    else
        update public.partner_sample_history set history = p_history,
            revision = revision + 1, updated_at = now()
            where user_id = actor and revision = p_revision returning * into saved;
    end if;
    if saved.user_id is null then
        raise exception 'Connections changed on another device. Refresh and try again.' using errcode = '40001';
    end if;
    return next saved;
end;
$$;
revoke all on function public.save_partner_sample_history(jsonb,bigint) from public, anon, authenticated;
grant execute on function public.save_partner_sample_history(jsonb,bigint) to authenticated;

commit;
