// Isolated Postgres checks. Never connects to the live project.
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
const { PGlite } = await import(pathToFileURL(process.env.PGLITE_MODULE).href);
const db = new PGlite();
const a = '11111111-1111-4111-8111-111111111111';
const b = '22222222-2222-4222-8222-222222222222';
const c = '33333333-3333-4333-8333-333333333333';
let checks = 0;
function equal(actual, expected) { assert.deepEqual(actual, expected); checks++; }
async function reject(sql, params = [], code = '42501') {
    await assert.rejects(() => db.query(sql, params), e => !code || e.code === code); checks++;
}
async function login(id) {
    await db.exec('reset role; set role authenticated');
    await db.query("select set_config('request.jwt.claim.sub',$1,false)", [id]);
}
async function ticket(user, event, paid = true) {
    await db.exec('reset role');
    await db.query(`insert into public.tickets(id,user_id,event_id,event,tier,quantity,total,payment_status,status)
        values(gen_random_uuid(),$1,$2,$3,'{"price":799}',1,799,$4,$5)`,
        [user,event,JSON.stringify({id:event,name:event}),paid?'paid':'pending',paid?'Confirmed':'Pending']);
}
try {
    await db.exec(`create role anon; create role authenticated; create role service_role bypassrls;
        create schema auth;
        create table auth.users(id uuid primary key,email text,email_confirmed_at timestamptz,is_anonymous boolean default false);
        create function auth.uid() returns uuid language sql stable as
            $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
        grant usage on schema auth,public to authenticated,anon;
        create table public.profiles(id uuid primary key references auth.users(id),display_name text,
            avatar_path text,personality text,city text,is_discoverable boolean,is_profile_complete boolean,
            email text,phone text,created_at timestamptz default now());
        create table public.profile_preferences(user_id uuid primary key references auth.users(id),
            genres text[],favorite_artists text[],show_my_area boolean);
        alter table public.profiles enable row level security;
        alter table public.profile_preferences enable row level security;
        grant select on public.profiles,public.profile_preferences to authenticated;
    `);
    for (const [i,id] of [a,b,c].entries()) {
        await db.query("insert into auth.users values($1,$2,now(),false)",[id,`private${i}@example.com`]);
        await db.query(`insert into public.profiles(id,display_name,personality,city,is_discoverable,is_profile_complete,email,phone)
            values($1,$2,'Night Owl','Delhi',true,true,'private@example.com','private-phone')`,[id,`Raver ${i}`]);
        await db.query("insert into public.profile_preferences values($1,'{Techno}','{ARKA}',false)",[id]);
    }
    await db.exec(await readFile(new URL('../migrations/202610230001_commerce.sql',import.meta.url),'utf8'));
    const item = [{id:'item',product:{id:'p',price:1000},quantity:1}];
    for (const id of [a,b,c]) {
        await db.query(`insert into public.orders(id,user_id,items,shipping_address,total,payment_method,checkout_source)
            values(gen_random_uuid(),$1,$2,'{}',1000,'upi','direct')`,[id,JSON.stringify(item)]);
    }
    await db.exec(await readFile(new URL('../migrations/202610310001_social.sql',import.meta.url),'utf8'));
    await login(a);
    let cards = (await db.query('select * from public.get_partner_candidates()')).rows.map(x=>x.get_partner_candidates);
    equal(cards.map(x=>x.id),[b,c]);
    equal(cards[0].city,null);
    equal('email' in cards[0] || 'phone' in cards[0],false);
    equal((await db.query('select * from public.profiles')).rows.length,0);
    await db.query("select public.record_partner_swipe($1,'like')",[b]);
    equal((await db.query('select * from public.get_partner_matches()')).rows.length,0);
    await reject("insert into public.partner_matches(user_a,user_b) values($1,$2)",[a,b]);
    await login(b);
    await db.query("select public.record_partner_swipe($1,'like')",[a]);
    let matches = (await db.query('select * from public.get_partner_matches()')).rows;
    equal(matches.length,1);
    const pair = matches[0];
    equal(new Date(pair.chat_unlocks_at)-new Date(pair.matched_at),10800000);
    const messageID = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
    await reject('select * from public.send_partner_message($1,$2,$3)',[messageID,pair.id,'Too soon']);
    await reject("update public.partner_matches set chat_unlocks_at=now() where id=$1",[pair.id]);
    await login(c);
    equal((await db.query('select * from public.partner_matches')).rows.length,0);
    await reject('select * from public.send_partner_message($1,$2,$3)',[messageID,pair.id,'Intruder']);
    await db.exec("reset role; update public.partner_matches set matched_at=matched_at-interval '4 hours',chat_unlocks_at=chat_unlocks_at-interval '4 hours'");
    await login(a);
    await db.query('select * from public.send_partner_message($1,$2,$3)',[messageID,pair.id,'Hello']);
    await db.query('select * from public.send_partner_message($1,$2,$3)',[messageID,pair.id,'Hello']);
    equal((await db.query('select * from public.partner_messages')).rows.length,1);
    await reject('select * from public.send_partner_message(gen_random_uuid(),$1,$2)',[pair.id,' '],'23514');
    await reject('select * from public.send_partner_message(gen_random_uuid(),$1,$2)',[pair.id,'x'.repeat(2001)],'23514');
    await login(b);
    equal((await db.query('select body from public.partner_messages')).rows[0].body,'Hello');
    await db.query('select public.end_partner_match($1)',[pair.id]);
    await login(a);
    equal((await db.query('select * from public.partner_messages')).rows.length,0);
    await reject('select * from public.send_partner_message($1,$2,$3)',[messageID,pair.id,'After unmatch']);
    await db.query("select public.record_partner_swipe($1,'like')",[b]);
    equal((await db.query('select * from public.get_partner_matches()')).rows.length,0);

    await ticket(a,'event-one');
    await ticket(b,'event-one',false);
    await ticket(c,'event-two');
    await login(a);
    equal((await db.query('select * from public.join_event_chat($1)',['event-one'])).rows[0].member_count,1);
    const eventMessageID = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
    await db.query('select * from public.send_event_chat_message($1,$2,$3)',[eventMessageID,'event-one','At the entrance']);
    await db.query('select * from public.send_event_chat_message($1,$2,$3)',[eventMessageID,'event-one','At the entrance']);
    equal((await db.query('select * from public.event_chat_messages')).rows.length,1);
    await login(b);
    await reject('select * from public.join_event_chat($1)',['event-one']);
    await reject('select * from public.get_event_chat_messages($1)',['event-one']);
    equal((await db.query('select * from public.event_chat_messages')).rows.length,0);
    await login(c);
    await reject('select * from public.join_event_chat($1)',['event-one']);
    await reject('select * from public.send_event_chat_message(gen_random_uuid(),$1,$2)',['event-one','Wrong event']);
    equal((await db.query('select * from public.event_chat_rooms')).rows.map(x=>x.event_id),['event-two']);
    await db.exec("reset role; update public.tickets set payment_status='paid',status='Confirmed' where user_id='"+b+"'");
    await login(b);
    equal((await db.query('select * from public.join_event_chat($1)',['event-one'])).rows[0].member_count,2);
    equal((await db.query('select * from public.get_event_chat_messages($1)',['event-one'])).rows[0].body,'At the entrance');
    await db.exec("reset role; update public.tickets set payment_status='refunded' where user_id='"+b+"'");
    await login(b);
    equal((await db.query('select * from public.event_chat_messages')).rows.length,0);
    await reject('select * from public.join_event_chat($1)',['event-one']);
    await reject('select * from public.send_event_chat_message(gen_random_uuid(),$1,$2)',['event-one','After refund']);
    await db.exec('reset role; set role anon');
    await reject('select * from public.get_partner_candidates()');
    await reject('select * from public.get_partner_matches()');
    await reject('select * from public.event_chat_messages');
    await reject('select * from public.join_event_chat($1)',['event-one']);
    console.log(`PASS: ${checks} social database checks (mutual likes, 3-hour delay, privacy, retries, unmatch, exact-event tickets, refunds, anonymous denial).`);
} finally { await db.close(); }
