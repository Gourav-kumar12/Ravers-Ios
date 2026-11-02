-- Saved preferences only. A payment provider must collect/tokenise full card data
-- and verify charges separately. These functions never mark a purchase paid.
begin;
create table public.payment_methods (
    id uuid primary key,
    user_id uuid not null references auth.users(id) on delete cascade,
    kind text not null check (kind in ('upi', 'card')),
    upi_id text,
    cardholder_name text,
    card_brand text,
    card_last_four text,
    expiry_month integer,
    expiry_year integer,
    created_at timestamptz not null default now(),
    check (
        (kind = 'upi' and upi_id is not null and length(split_part(upi_id, '@', 1)) between 1 and 256
         and upi_id ~ '^[a-zA-Z0-9._-]+@[a-zA-Z][a-zA-Z0-9.-]{1,63}$'
         and cardholder_name is null and card_brand is null and card_last_four is null
         and expiry_month is null and expiry_year is null)
        or
        (kind = 'card' and upi_id is null and length(btrim(cardholder_name)) between 1 and 100
         and card_brand in ('Visa', 'Mastercard', 'RuPay', 'Amex', 'Other')
         and card_last_four ~ '^[0-9]{4}$' and expiry_month between 1 and 12
         and expiry_year between 2026 and 2100
         and cardholder_name is not null and card_brand is not null and card_last_four is not null
         and expiry_month is not null and expiry_year is not null)
    )
);
create index payment_methods_owner on public.payment_methods(user_id, created_at desc);
alter table public.payment_methods enable row level security;
create policy payment_methods_own_select on public.payment_methods for select to authenticated
    using (user_id = (select auth.uid()));
create policy payment_methods_own_insert on public.payment_methods for insert to authenticated
    with check (user_id = (select auth.uid()));
create policy payment_methods_own_update on public.payment_methods for update to authenticated
    using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy payment_methods_own_delete on public.payment_methods for delete to authenticated
    using (user_id = (select auth.uid()));
revoke all on public.payment_methods from public, anon, authenticated;
grant select, delete on public.payment_methods to authenticated;
grant insert (id,user_id,kind,upi_id,cardholder_name,card_brand,card_last_four,expiry_month,expiry_year),
      update (id,user_id,kind,upi_id,cardholder_name,card_brand,card_last_four,expiry_month,expiry_year)
      on public.payment_methods to authenticated;

alter table public.orders add column payment_method_id uuid references public.payment_methods(id) on delete set null;
alter table public.tickets add column payment_method text check (payment_method in ('upi','card'));
alter table public.tickets add column payment_method_id uuid references public.payment_methods(id) on delete set null;

create function public.place_product_order_with_payment(
    p_id uuid, p_items jsonb, p_address jsonb, p_from_vault boolean, p_method uuid
) returns setof public.orders language plpgsql security definer set search_path = '' as $$
declare chosen public.payment_methods; actor uuid := auth.uid();
begin
    if actor is null or not exists (select 1 from auth.users u where u.id = actor
        and u.email_confirmed_at is not null and not coalesce(u.is_anonymous, false)) then
        raise exception 'Sign in with a verified account.' using errcode = '42501';
    end if;
    select * into chosen from public.payment_methods where id = p_method and user_id = actor;
    if not found then raise exception 'Choose one of your saved payment preferences.' using errcode = '42501'; end if;
    if chosen.kind = 'card' and chosen.expiry_year * 12 + chosen.expiry_month <
        extract(year from current_date)::integer * 12 + extract(month from current_date)::integer then
        raise exception 'This card preference has expired. Update it before checkout.' using errcode = '22023';
    end if;
    -- The existing transaction validates the request and clears only this user's cart.
    perform public.place_product_order(p_id, p_items, p_address, chosen.kind, p_from_vault);
    update public.orders set payment_method_id = chosen.id, payment_method = chosen.kind
        where id = p_id and user_id = actor and payment_method_id is null
        and payment_status = 'pending' and status = 'Placed';
    return query select * from public.orders where id = p_id and user_id = actor;
end;
$$;

create function public.book_event_ticket_with_payment(
    p_id uuid, p_event jsonb, p_tier jsonb, p_method uuid
) returns setof public.tickets language plpgsql security definer set search_path = '' as $$
declare chosen public.payment_methods; actor uuid := auth.uid(); event_key text; amount numeric;
begin
    if actor is null or not exists (select 1 from auth.users u where u.id = actor
        and u.email_confirmed_at is not null and not coalesce(u.is_anonymous, false)) then
        raise exception 'Sign in with a verified account.' using errcode = '42501';
    end if;
    select * into chosen from public.payment_methods where id = p_method and user_id = actor;
    if not found then raise exception 'Choose one of your saved payment preferences.' using errcode = '42501'; end if;
    if chosen.kind = 'card' and chosen.expiry_year * 12 + chosen.expiry_month <
        extract(year from current_date)::integer * 12 + extract(month from current_date)::integer then
        raise exception 'This card preference has expired. Update it before checkout.' using errcode = '22023';
    end if;
    event_key := p_event->>'id';
    if p_id is null or event_key is null or length(event_key) not between 1 and 500
        or jsonb_typeof(p_event) <> 'object' or jsonb_typeof(p_tier) <> 'object'
        or jsonb_typeof(p_tier->'price') is distinct from 'number' then
        raise exception 'Check the event and ticket tier.' using errcode = '22023';
    end if;
    amount := (p_tier->>'price')::numeric;
    if amount < 0 or amount > 1000000000 or amount <> trunc(amount) then
        raise exception 'Invalid ticket amount.' using errcode = '22023';
    end if;
    if exists (select 1 from public.tickets where user_id = actor and event_id = event_key
        and (status = 'Cancelled' or payment_status in ('failed','refunded'))) then
        raise exception 'This booking is no longer available. Please contact support before rebooking.' using errcode = '22023';
    end if;
    insert into public.tickets(id,user_id,event_id,event,tier,quantity,total,payment_method,payment_method_id)
        values(p_id,actor,event_key,p_event - 'heldPass',p_tier,1,amount::integer,chosen.kind,chosen.id)
        on conflict(user_id,event_id) do nothing;
    -- Retries return the same booking and never overwrite a confirmed payment.
    return query select * from public.tickets where user_id = actor and event_id = event_key;
end;
$$;
revoke all on function public.place_product_order_with_payment(uuid,jsonb,jsonb,boolean,uuid),
    public.book_event_ticket_with_payment(uuid,jsonb,jsonb,uuid) from public, anon, authenticated;
grant execute on function public.place_product_order_with_payment(uuid,jsonb,jsonb,boolean,uuid),
    public.book_event_ticket_with_payment(uuid,jsonb,jsonb,uuid) to authenticated;
commit;
