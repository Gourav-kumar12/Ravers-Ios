-- Apply after profiles and commerce. No demo people or messages enter the database.
begin;

create schema if not exists social_private;
revoke all on schema social_private from public, anon;
grant usage on schema social_private to authenticated;

create table public.partner_swipes (
    swiper_id uuid not null references auth.users(id) on delete cascade,
    target_id uuid not null references auth.users(id) on delete cascade,
    action text not null check (action in ('like', 'pass')),
    created_at timestamptz not null default now(),
    primary key (swiper_id, target_id),
    check (swiper_id <> target_id)
);
create table public.partner_matches (
    id uuid primary key default gen_random_uuid(),
    user_a uuid not null references auth.users(id) on delete cascade,
    user_b uuid not null references auth.users(id) on delete cascade,
    matched_at timestamptz not null default now(),
    chat_unlocks_at timestamptz not null default (now() + interval '3 hours'),
    ended_at timestamptz,
    unique (user_a, user_b),
    check (user_a < user_b),
    check (chat_unlocks_at = matched_at + interval '3 hours')
);
create index partner_matches_user_b on public.partner_matches(user_b);
create table public.partner_messages (
    id uuid primary key,
    match_id uuid not null references public.partner_matches(id) on delete cascade,
    sender_id uuid not null references auth.users(id) on delete cascade,
    body text not null check (length(btrim(body)) between 1 and 2000),
    created_at timestamptz not null default now()
);
create index partner_messages_thread on public.partner_messages(match_id, created_at desc);
create table public.event_chat_rooms (
    event_id text primary key,
    event_name text not null,
    created_at timestamptz not null default now()
);
create table public.event_chat_messages (
    id uuid primary key,
    event_id text not null references public.event_chat_rooms(event_id) on delete cascade,
    sender_id uuid not null references auth.users(id) on delete cascade,
    body text not null check (length(btrim(body)) between 1 and 2000),
    created_at timestamptz not null default now()
);
create index event_chat_messages_thread on public.event_chat_messages(event_id, created_at desc);

create function social_private.partner_eligible(p_user uuid) returns boolean
language sql stable security definer set search_path = '' as $$
    select exists (select 1 from auth.users u where u.id = p_user
        and u.email_confirmed_at is not null and coalesce(u.email, '') <> ''
        and not coalesce(u.is_anonymous, false)) and (
        exists (select 1 from public.orders o where o.user_id = p_user
            and o.payment_status in ('pending', 'paid') and o.status <> 'Cancelled'
            and jsonb_array_length(o.items) > 0)
        or exists (select 1 from public.tickets t where t.user_id = p_user
            and t.payment_status = 'paid' and t.status = 'Confirmed'));
$$;
create function social_private.has_event_ticket(p_event text) returns boolean
language sql stable security definer set search_path = '' as $$
    select exists (select 1 from public.tickets t join auth.users u on u.id = t.user_id
        where t.user_id = (select auth.uid()) and t.event_id = p_event
        and t.payment_status = 'paid' and t.status in ('Confirmed', 'Used')
        and u.email_confirmed_at is not null and not coalesce(u.is_anonymous, false));
$$;
create function social_private.can_read_match(p_match uuid) returns boolean
language sql stable security definer set search_path = '' as $$
    select exists (select 1 from public.partner_matches m where m.id = p_match
        and (select auth.uid()) in (m.user_a, m.user_b) and m.ended_at is null
        and social_private.partner_eligible(m.user_a) and social_private.partner_eligible(m.user_b));
$$;
-- Deliberately excludes contact details, private settings, precise location and attendance.
create function social_private.profile_card(p_user uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
    select jsonb_build_object('id', p.id, 'name', p.display_name, 'age', 0,
        'distanceKm', 0, 'imageName', coalesce(p.avatar_path, ''),
        'genres', coalesce(pr.genres, '{}'), 'artists', coalesce(pr.favorite_artists, '{}'),
        'anthem', p.personality, 'bio', p.personality,
        'city', case when coalesce(pr.show_my_area, true) then p.city else null end)
    from public.profiles p left join public.profile_preferences pr on pr.user_id = p.id
    where p.id = p_user;
$$;

alter table public.partner_swipes enable row level security;
alter table public.partner_matches enable row level security;
alter table public.partner_messages enable row level security;
alter table public.event_chat_rooms enable row level security;
alter table public.event_chat_messages enable row level security;
create policy swipes_read_own on public.partner_swipes for select to authenticated
    using (swiper_id = (select auth.uid()));
create policy matches_read_members on public.partner_matches for select to authenticated
    using (social_private.can_read_match(id));
create policy partner_messages_read_members on public.partner_messages for select to authenticated
    using (social_private.can_read_match(match_id));
create policy event_rooms_read_ticket_holders on public.event_chat_rooms for select to authenticated
    using (social_private.has_event_ticket(event_id));
create policy event_messages_read_ticket_holders on public.event_chat_messages for select to authenticated
    using (social_private.has_event_ticket(event_id));
revoke all on public.partner_swipes, public.partner_matches, public.partner_messages,
    public.event_chat_rooms, public.event_chat_messages from anon, authenticated;
grant select on public.partner_swipes, public.partner_matches, public.partner_messages,
    public.event_chat_rooms, public.event_chat_messages to authenticated;

create function public.get_partner_candidates() returns setof jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
    if not social_private.partner_eligible(auth.uid()) then
        raise exception 'Partner access requires an eligible purchase.' using errcode = '42501';
    end if;
    return query select social_private.profile_card(p.id) from public.profiles p
        where p.id <> auth.uid() and p.is_discoverable and p.is_profile_complete
        and btrim(p.display_name) <> '' and social_private.partner_eligible(p.id)
        and not exists (select 1 from public.partner_swipes s
            where s.swiper_id = auth.uid() and s.target_id = p.id)
        order by p.created_at, p.id limit 40;
end;
$$;
create function public.get_partner_matches()
returns table(id uuid, matched_at timestamptz, chat_unlocks_at timestamptz, raver jsonb)
language sql stable security definer set search_path = '' as $$
    select m.id, m.matched_at, m.chat_unlocks_at,
        social_private.profile_card(case when m.user_a = auth.uid() then m.user_b else m.user_a end)
    from public.partner_matches m where social_private.can_read_match(m.id)
    order by m.matched_at desc;
$$;
create function public.record_partner_swipe(p_target uuid, p_action text) returns void
language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); first_user uuid; second_user uuid;
begin
    if actor is null or actor = p_target or p_action is null or p_action not in ('like', 'pass')
        or not social_private.partner_eligible(actor) then
        raise exception 'Invalid swipe.' using errcode = '42501';
    end if;
    if not exists (select 1 from public.profiles p where p.id = p_target
        and p.is_discoverable and p.is_profile_complete and btrim(p.display_name) <> '')
        or not social_private.partner_eligible(p_target) then
        raise exception 'This profile is no longer available.' using errcode = '42501';
    end if;
    first_user := least(actor, p_target); second_user := greatest(actor, p_target);
    -- Serialize both directions of the same pair so simultaneous likes cannot miss a match.
    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(first_user::text || second_user::text, 0));
    insert into public.partner_swipes(swiper_id, target_id, action) values(actor, p_target, p_action)
        on conflict(swiper_id, target_id) do update set action = excluded.action;
    if p_action = 'like' and exists (select 1 from public.partner_swipes s
        where s.swiper_id = p_target and s.target_id = actor and s.action = 'like') then
        insert into public.partner_matches(user_a, user_b) values(first_user, second_user)
            on conflict(user_a, user_b) do nothing;
    end if;
end;
$$;
create function public.end_partner_match(p_match uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
    update public.partner_matches set ended_at = now()
        where id = p_match and auth.uid() in (user_a, user_b) and ended_at is null;
end;
$$;
create function public.send_partner_message(p_id uuid, p_match uuid, p_body text)
returns setof public.partner_messages
language plpgsql security definer set search_path = '' as $$
begin
    -- Client clocks and client-supplied timestamps cannot bypass the delay.
    if not social_private.can_read_match(p_match) or not exists (
        select 1 from public.partner_matches m where m.id = p_match and m.chat_unlocks_at <= now()) then
        raise exception 'Chat opens three hours after a mutual match.' using errcode = '42501';
    end if;
    insert into public.partner_messages(id, match_id, sender_id, body)
        values(p_id, p_match, auth.uid(), btrim(p_body)) on conflict(id) do nothing;
    return query select * from public.partner_messages m
        where m.id = p_id and m.match_id = p_match and m.sender_id = auth.uid();
end;
$$;

create function social_private.create_event_room() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
    if new.payment_status = 'paid' and new.status in ('Confirmed', 'Used') then
        insert into public.event_chat_rooms(event_id, event_name)
            values(new.event_id, coalesce(new.event->>'name', new.event_id))
            on conflict(event_id) do nothing;
    end if;
    return new;
end;
$$;
create trigger ticket_creates_event_room after insert or update on public.tickets
    for each row execute function social_private.create_event_room();
insert into public.event_chat_rooms(event_id, event_name)
    select distinct on (event_id) event_id, coalesce(event->>'name', event_id) from public.tickets
    where payment_status = 'paid' and status in ('Confirmed', 'Used')
    order by event_id, booked_at on conflict(event_id) do nothing;

create function public.join_event_chat(p_event text)
returns table(event_id text, event_name text, member_count bigint)
language plpgsql security definer set search_path = '' as $$
begin
    if not social_private.has_event_ticket(p_event) then
        raise exception 'A paid ticket for this event is required.' using errcode = '42501';
    end if;
    return query select r.event_id, r.event_name,
        (select count(distinct t.user_id) from public.tickets t where t.event_id = p_event
            and t.payment_status = 'paid' and t.status in ('Confirmed', 'Used'))
        from public.event_chat_rooms r where r.event_id = p_event;
end;
$$;
create function public.get_event_chat_messages(p_event text)
returns table(id uuid, sender_id uuid, sender_name text, body text, created_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
begin
    if not social_private.has_event_ticket(p_event) then
        raise exception 'A paid ticket for this event is required.' using errcode = '42501';
    end if;
    return query select m.id, m.sender_id, coalesce(nullif(p.display_name, ''), 'Raver'), m.body, m.created_at
        from public.event_chat_messages m left join public.profiles p on p.id = m.sender_id
        where m.event_id = p_event order by m.created_at desc, m.id desc limit 100;
end;
$$;
create function public.send_event_chat_message(p_id uuid, p_event text, p_body text)
returns setof public.event_chat_messages
language plpgsql security definer set search_path = '' as $$
begin
    if not social_private.has_event_ticket(p_event) then
        raise exception 'A paid ticket for this event is required.' using errcode = '42501';
    end if;
    insert into public.event_chat_messages(id, event_id, sender_id, body)
        values(p_id, p_event, auth.uid(), btrim(p_body)) on conflict(id) do nothing;
    return query select * from public.event_chat_messages m
        where m.id = p_id and m.event_id = p_event and m.sender_id = auth.uid();
end;
$$;

revoke all on all functions in schema social_private from public, anon, authenticated;
grant execute on function social_private.has_event_ticket(text), social_private.can_read_match(uuid) to authenticated;
revoke all on function public.get_partner_candidates(), public.get_partner_matches(),
    public.record_partner_swipe(uuid,text), public.end_partner_match(uuid),
    public.send_partner_message(uuid,uuid,text), public.join_event_chat(text),
    public.get_event_chat_messages(text), public.send_event_chat_message(uuid,text,text)
    from public, anon, authenticated;
grant execute on function public.get_partner_candidates(), public.get_partner_matches(),
    public.record_partner_swipe(uuid,text), public.end_partner_match(uuid),
    public.send_partner_message(uuid,uuid,text), public.join_event_chat(text),
    public.get_event_chat_messages(text), public.send_event_chat_message(uuid,text,text) to authenticated;
commit;
