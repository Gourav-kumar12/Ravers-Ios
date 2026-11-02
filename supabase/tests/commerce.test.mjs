// Local, isolated database test. Never connects to the hosted Supabase project.
// PGLITE_MODULE must point to an installed @electric-sql/pglite/dist/index.js.
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';

const { PGlite } = await import(pathToFileURL(process.env.PGLITE_MODULE).href);
const db = new PGlite();
let checks = 0;
const owner = '11111111-1111-4111-8111-111111111111';
const other = '22222222-2222-4222-8222-222222222222';
const address = { name: 'Test', phone: '9876543210', line: 'Test street', city: 'Noida', pincode: '201301' };
const first = { id: 'first', product: { id: 'p1', name: 'Hoodie', price: 1500 }, size: 'M', quantity: 2 };
const second = { id: 'second', product: { id: 'p2', name: 'Tee', price: 2000 }, size: 'L', quantity: 1 };

async function login(userID = owner) {
    await db.exec('reset role; set role authenticated');
    await db.query("select set_config('request.jwt.claim.sub', $1, false)", [userID]);
}
async function cart(item, userID = owner) {
    return db.query('insert into public.vault_items(user_id,id,product,size,quantity) values($1,$2,$3,$4,$5)',
        [userID, item.id, JSON.stringify(item.product), item.size, item.quantity]);
}
async function order(id, items, fromVault = true) {
    return db.query('select * from public.place_product_order($1,$2,$3,$4,$5)',
        [id, JSON.stringify(items), JSON.stringify(address), 'upi', fromVault]);
}
async function count(table) { return (await db.query(`select count(*)::int as n from public.${table}`)).rows[0].n; }
async function rejects(action, code) {
    await assert.rejects(action, error => !code || error.code === code);
    checks++;
}
function equal(actual, expected) { assert.deepEqual(actual, expected); checks++; }

try {
    await db.exec(`
        create role anon; create role authenticated; create role service_role bypassrls;
        create schema auth;
        create table auth.users(id uuid primary key);
        create function auth.uid() returns uuid language sql stable as
          $$ select nullif(current_setting('request.jwt.claim.sub', true),'')::uuid $$;
        grant usage on schema auth, public to authenticated, anon;
        insert into auth.users values ('${owner}'), ('${other}');
    `);
    await db.exec(await readFile(new URL('../migrations/202610230001_commerce.sql', import.meta.url), 'utf8'));
    await login();
    await cart(first);
    await cart(second);
    equal(await count('vault_items'), 2);

    await login(other);
    equal(await count('vault_items'), 0);
    await rejects(() => cart({ ...first, id: 'forbidden' }, owner), '42501');
    await login();

    const orderID = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
    const saved = (await order(orderID, [first, second])).rows[0];
    equal(saved.total, 5000);
    equal(saved.items.length, 2);
    equal(saved.payment_status, 'pending');
    equal(await count('vault_items'), 0);
    equal((await order(orderID, [first, second])).rows[0].id, orderID);
    equal(await count('orders'), 1);

    // An order failure after its insert must roll back the order and cart deletion.
    await db.exec(`reset role;
        create function public.reject_test_delete() returns trigger language plpgsql as $$
        begin if old.id = 'fail-delete' then raise exception 'simulated delete failure'; end if; return old; end; $$;
        create trigger reject_test_delete before delete on public.vault_items
        for each row execute function public.reject_test_delete();`);
    await login();
    const failingItem = { ...first, id: 'fail-delete' };
    await cart(failingItem);
    await rejects(() => order('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', [failingItem]));
    equal(await count('orders'), 1);
    equal(await count('vault_items'), 1);
    await rejects(() => order('cccccccc-cccc-4ccc-8ccc-cccccccccccc', [{ ...failingItem, quantity: 1 }]), '22023');
    equal(await count('orders'), 1);

    // Direct checkout must leave an unrelated saved cart item intact.
    await order('dddddddd-dddd-4ddd-8ddd-dddddddddddd', [second], false);
    equal(await count('vault_items'), 1);
    equal(await count('orders'), 2);

    await rejects(() => db.query("update public.orders set payment_status = 'paid'"), '42501');
    await rejects(() => db.query(`insert into public.orders(id,user_id,items,shipping_address,total,payment_method,checkout_source,payment_status)
        values('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',$1,$2,$3,5000,'upi','direct','paid')`,
        [owner, JSON.stringify([first]), JSON.stringify(address)]), '42501');

    const ticketParams = [owner, 'event-1', JSON.stringify({ id: 'event-1', name: 'Test event' }),
        JSON.stringify({ id: 'general', name: 'General', price: 799 })];
    const ticketInsert = `insert into public.tickets(id,user_id,event_id,event,tier,quantity,total)
        values($1,$2,$3,$4,$5,1,799) on conflict(user_id,event_id) do nothing`;
    await db.query(ticketInsert, ['ffffffff-ffff-4fff-8fff-ffffffffffff', ...ticketParams]);
    await db.query(ticketInsert, ['eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', ...ticketParams]);
    equal(await count('tickets'), 1);
    equal((await db.query('select payment_status,status,code from public.tickets')).rows[0],
        { payment_status: 'pending', status: 'Pending', code: null });
    await rejects(() => db.query("update public.tickets set status='Confirmed',payment_status='paid',code='invented'"), '42501');
    await login(other);
    equal(await count('orders'), 0);
    equal(await count('tickets'), 0);
    await db.exec('reset role; set role anon');
    await rejects(() => count('orders'), '42501');
    await rejects(() => order('99999999-9999-4999-8999-999999999999', [first], false), '42501');
    console.log(`PASS: ${checks} database checks (ownership, pending-only writes, multi-item checkout, rollback, retries, ticket uniqueness, anonymous denial).`);
} finally {
    await db.close();
}
