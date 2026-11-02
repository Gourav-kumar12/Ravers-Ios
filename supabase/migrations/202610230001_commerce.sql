-- Cart contents, product orders, and event bookings belong to auth.users.id.
-- These are purchase requests. Only a trusted payment backend may mark them
-- paid/confirmed, verify catalog prices, reserve inventory, and issue QR codes.
begin;

create table public.vault_items (
    user_id uuid not null references auth.users(id) on delete cascade,
    id text not null check (length(id) between 1 and 500),
    product jsonb not null check (jsonb_typeof(product) = 'object'),
    size text,
    quantity integer not null check (quantity between 1 and 99),
    created_at timestamptz not null default now(),
    primary key (user_id, id),
    check (coalesce(length(product->>'id'), 0) > 0),
    check (jsonb_typeof(product->'price') = 'number' and (product->>'price')::numeric between 0 and 10000000)
);

create table public.orders (
    id uuid primary key,
    user_id uuid not null references auth.users(id) on delete cascade,
    items jsonb not null check (jsonb_typeof(items) = 'array' and jsonb_array_length(items) between 1 and 100),
    shipping_address jsonb not null check (jsonb_typeof(shipping_address) = 'object'),
    total integer not null check (total between 0 and 1000000000),
    currency text not null default 'INR' check (currency = 'INR'),
    payment_method text not null check (payment_method in ('upi', 'card')),
    payment_status text not null default 'pending' check (payment_status in ('pending', 'paid', 'failed', 'refunded')),
    status text not null default 'Placed' check (status in ('Placed', 'Confirmed', 'Shipped', 'Delivered', 'Cancelled')),
    checkout_source text not null check (checkout_source in ('direct', 'vault')),
    placed_at timestamptz not null default now()
);
create index orders_user_placed_at on public.orders(user_id, placed_at desc);

create table public.tickets (
    id uuid primary key,
    user_id uuid not null references auth.users(id) on delete cascade,
    event_id text not null,
    event jsonb not null check (jsonb_typeof(event) = 'object'),
    tier jsonb not null check (jsonb_typeof(tier) = 'object'),
    quantity integer not null check (quantity between 1 and 20),
    total integer not null check (total between 0 and 1000000000),
    currency text not null default 'INR' check (currency = 'INR'),
    payment_status text not null default 'pending' check (payment_status in ('pending', 'paid', 'failed', 'refunded')),
    status text not null default 'Pending' check (status in ('Pending', 'Confirmed', 'Used', 'Cancelled')),
    code text unique,
    booked_at timestamptz not null default now(),
    unique (user_id, event_id),
    check (coalesce(length(event->>'id'), 0) > 0 and event_id = event->>'id'),
    check (jsonb_typeof(tier->'price') = 'number' and (tier->>'price')::numeric * quantity = total)
);
create index tickets_user_booked_at on public.tickets(user_id, booked_at desc);

alter table public.vault_items enable row level security;
alter table public.orders enable row level security;
alter table public.tickets enable row level security;

create policy vault_items_select_own on public.vault_items for select to authenticated
    using (user_id = (select auth.uid()));
create policy vault_items_insert_own on public.vault_items for insert to authenticated
    with check (user_id = (select auth.uid()));
create policy vault_items_update_own on public.vault_items for update to authenticated
    using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy vault_items_delete_own on public.vault_items for delete to authenticated
    using (user_id = (select auth.uid()));

create policy orders_select_own on public.orders for select to authenticated
    using (user_id = (select auth.uid()));
create policy orders_insert_own_pending on public.orders for insert to authenticated
    with check (user_id = (select auth.uid()) and payment_status = 'pending' and status = 'Placed');
create policy tickets_select_own on public.tickets for select to authenticated
    using (user_id = (select auth.uid()));
create policy tickets_insert_own_pending on public.tickets for insert to authenticated
    with check (user_id = (select auth.uid()) and payment_status = 'pending' and status = 'Pending' and code is null);

revoke all on public.vault_items, public.orders, public.tickets from anon, authenticated;
grant select, delete on public.vault_items to authenticated;
grant insert (user_id, id, product, size, quantity), update (product, size, quantity)
    on public.vault_items to authenticated;
-- PostgREST upserts also update the key columns included in the payload.
grant update (user_id, id) on public.vault_items to authenticated;
grant select on public.orders, public.tickets to authenticated;
grant insert (id, user_id, items, shipping_address, total, payment_method, checkout_source)
    on public.orders to authenticated;
grant insert (id, user_id, event_id, event, tier, quantity, total) on public.tickets to authenticated;
grant all on public.vault_items, public.orders, public.tickets to service_role;

create function public.place_product_order(
    p_id uuid, p_items jsonb, p_address jsonb, p_payment_method text, p_from_vault boolean
)
returns setof public.orders
language plpgsql
security invoker
set search_path = ''
as $$
declare
    owner_id uuid := auth.uid();
    line jsonb;
    cart public.vault_items%rowtype;
    quantity_value integer;
    price_value integer;
    total_value bigint := 0;
begin
    if owner_id is null then
        raise exception 'Sign in before placing an order.' using errcode = '42501';
    end if;
    if p_id is null or p_from_vault is null then
        raise exception 'Missing checkout request.' using errcode = '22023';
    end if;
    -- Serialize retries of this request, including concurrent responses lost in transit.
    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(owner_id::text || p_id::text, 0));
    if exists (select 1 from public.orders where id = p_id and user_id = owner_id) then
        return query select * from public.orders where id = p_id and user_id = owner_id;
        return;
    end if;
    if p_items is null or jsonb_typeof(p_items) <> 'array' then
        raise exception 'Select items to order.' using errcode = '22023';
    end if;
    if jsonb_array_length(p_items) not between 1 and 100 or
       (select count(distinct value->>'id') from jsonb_array_elements(p_items)) <> jsonb_array_length(p_items) then
        raise exception 'Check the selected order items.' using errcode = '22023';
    end if;
    if p_payment_method is null or p_payment_method not in ('upi', 'card') or
       p_address is null or jsonb_typeof(p_address) <> 'object' or
       exists (select 1 from unnest(array['name','phone','line','city','pincode']) as field
               where length(btrim(coalesce(p_address->>field, ''))) not between 1 and 500) then
        raise exception 'Check the delivery address and payment method.' using errcode = '22023';
    end if;

    for line in select value from jsonb_array_elements(p_items) order by value->>'id' loop
        if coalesce(length(line->>'id'), 0) = 0 or
           coalesce(length(line->'product'->>'id'), 0) = 0 or
           coalesce(jsonb_typeof(line->'quantity'), '') <> 'number' or
           coalesce(jsonb_typeof(line->'product'->'price'), '') <> 'number' then
            raise exception 'Invalid order item.' using errcode = '22023';
        end if;
        -- Reject fractional/negative quantities and prices; amounts are INR rupees.
        if (line->>'quantity')::numeric <> trunc((line->>'quantity')::numeric) or
           (line->'product'->>'price')::numeric <> trunc((line->'product'->>'price')::numeric) then
            raise exception 'Invalid quantity or price.' using errcode = '22023';
        end if;
        quantity_value := (line->>'quantity')::integer;
        price_value := (line->'product'->>'price')::integer;
        if quantity_value not between 1 and 99 or price_value not between 0 and 10000000 then
            raise exception 'Invalid quantity or price.' using errcode = '22023';
        end if;
        total_value := total_value + quantity_value::bigint * price_value;
        if total_value > 1000000000 then
            raise exception 'Order total is too large.' using errcode = '22023';
        end if;
        if p_from_vault then
            select * into cart from public.vault_items
            where user_id = owner_id and id = line->>'id' for update;
            if not found or cart.quantity <> quantity_value or cart.product <> line->'product'
               or cart.size is distinct from (line->>'size') then
                raise exception 'Your Vault changed. Refresh it and try checkout again.' using errcode = '22023';
            end if;
        end if;
    end loop;

    insert into public.orders(id, user_id, items, shipping_address, total, payment_method, checkout_source)
    values(p_id, owner_id, p_items, p_address, total_value::integer, p_payment_method,
           case when p_from_vault then 'vault' else 'direct' end);
    if p_from_vault then
        delete from public.vault_items
        where user_id = owner_id and id in (select value->>'id' from jsonb_array_elements(p_items));
    end if;
    return query select * from public.orders where id = p_id and user_id = owner_id;
end;
$$;

revoke all on function public.place_product_order(uuid,jsonb,jsonb,text,boolean) from public, anon;
grant execute on function public.place_product_order(uuid,jsonb,jsonb,text,boolean) to authenticated;
notify pgrst, 'reload schema';
commit;
