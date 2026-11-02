// Local Postgres tests. Does not connect to the hosted payment or Supabase APIs.
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
const { PGlite } = await import(pathToFileURL(process.env.PGLITE_MODULE).href);
const db = new PGlite();
const a='11111111-1111-4111-8111-111111111111', b='22222222-2222-4222-8222-222222222222';
const upi='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', card='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const order='cccccccc-cccc-4ccc-8ccc-cccccccccccc', ticket='dddddddd-dddd-4ddd-8ddd-dddddddddddd';
let checks=0;
function equal(x,y){assert.deepEqual(x,y);checks++;}
async function deny(sql,params=[],code='42501'){await assert.rejects(()=>db.query(sql,params),e=>!code||e.code===code);checks++;}
async function login(id){await db.exec('reset role; set role authenticated');await db.query("select set_config('request.jwt.claim.sub',$1,false)",[id]);}
try {
 await db.exec(`create role anon;create role authenticated;create role service_role bypassrls;
 create schema auth;create table auth.users(id uuid primary key,email_confirmed_at timestamptz,is_anonymous boolean default false);
 create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
 grant usage on schema auth,public to authenticated,anon;`);
 await db.query('insert into auth.users values($1,now(),false),($2,now(),false)',[a,b]);
 await db.exec(await readFile(new URL('../migrations/202610230001_commerce.sql',import.meta.url),'utf8'));
 await db.exec(await readFile(new URL('../migrations/202610310002_payment_preferences.sql',import.meta.url),'utf8'));
 await login(a);
 await db.query("insert into public.payment_methods(id,user_id,kind,upi_id) values($1,$2,'upi','raver@bank')",[upi,a]);
 await db.query(`insert into public.payment_methods(id,user_id,kind,cardholder_name,card_brand,card_last_four,expiry_month,expiry_year)
 values($1,$2,'card','Test Raver','Visa','1234',12,2030)`,[card,a]);
 equal((await db.query('select * from public.payment_methods')).rows.length,2);
 await deny("insert into public.payment_methods(id,user_id,kind,upi_id) values(gen_random_uuid(),$1,'upi',null)",[a],'23514');
 await deny("insert into public.payment_methods(id,user_id,kind,upi_id) values(gen_random_uuid(),$1,'upi','not a upi')",[a],'23514');
 await deny("update public.payment_methods set card_last_four='4111111111111234' where id=$1",[card],'23514');
 const columns=(await db.query("select column_name from information_schema.columns where table_name='payment_methods'")).rows.map(x=>x.column_name);
 equal(columns.includes('card_number')||columns.includes('cvv')||columns.includes('upi_pin'),false);
 await db.query("update public.payment_methods set upi_id='edited@bank' where id=$1",[upi]);
 equal((await db.query('select upi_id from public.payment_methods where id=$1',[upi])).rows[0].upi_id,'edited@bank');
 await login(b);
 equal((await db.query('select * from public.payment_methods')).rows.length,0);
 equal((await db.query("update public.payment_methods set upi_id='stolen@bank' where id=$1 returning id",[upi])).rows.length,0);
 await deny("insert into public.payment_methods(id,user_id,kind,upi_id) values(gen_random_uuid(),$1,'upi','intruder@bank')",[a]);
 const items=JSON.stringify([{id:'p',product:{id:'hoodie',price:1000},quantity:1}]);
 const address=JSON.stringify({name:'Test',phone:'9876543210',line:'Test street',city:'Noida',pincode:'201301'});
 await deny('select * from public.place_product_order_with_payment($1,$2,$3,false,$4)',[order,items,address,upi]);
 await login(a);
 const placed=(await db.query('select * from public.place_product_order_with_payment($1,$2,$3,false,$4)',[order,items,address,upi])).rows[0];
 equal(placed.payment_method,'upi');equal(placed.payment_method_id,upi);equal(placed.payment_status,'pending');
 await db.query('select * from public.place_product_order_with_payment($1,$2,$3,false,$4)',[order,items,address,card]);
 equal((await db.query('select count(*)::int n from public.orders')).rows[0].n,1);
 equal((await db.query('select payment_method_id from public.orders')).rows[0].payment_method_id,upi);
 const event=JSON.stringify({id:'event-one',name:'Test event'}), tier=JSON.stringify({id:'general',name:'General',price:799});
 const booked=(await db.query('select * from public.book_event_ticket_with_payment($1,$2,$3,$4)',[ticket,event,tier,card])).rows[0];
 equal(booked.payment_method,'card');equal(booked.payment_method_id,card);equal(booked.payment_status,'pending');equal(booked.status,'Pending');
 await db.query('select * from public.book_event_ticket_with_payment($1,$2,$3,$4)',[ticket,event,tier,upi]);
 equal((await db.query('select count(*)::int n from public.tickets')).rows[0].n,1);
 equal((await db.query('select payment_method_id from public.tickets')).rows[0].payment_method_id,card);
 await db.query('update public.payment_methods set expiry_month=1,expiry_year=2026 where id=$1',[card]);
 await deny('select * from public.place_product_order_with_payment(gen_random_uuid(),$1,$2,false,$3)',[items,address,card],'22023');
 await deny('select * from public.book_event_ticket_with_payment(gen_random_uuid(),$1,$2,$3)',[JSON.stringify({id:'expired-card-event'}),tier,card],'22023');
 await db.query('update public.payment_methods set expiry_month=12,expiry_year=2030 where id=$1',[card]);

 await deny("update public.tickets set payment_status='paid',status='Confirmed'");
 await login(b);
 await deny('select * from public.book_event_ticket_with_payment(gen_random_uuid(),$1,$2,$3)',[event,tier,card]);
 equal((await db.query('select * from public.orders')).rows.length,0);
 equal((await db.query('select * from public.tickets')).rows.length,0);
 await login(a);
 await db.query('delete from public.payment_methods where id=$1',[upi]);
 equal((await db.query('select payment_method_id,payment_method from public.orders')).rows[0],{payment_method_id:null,payment_method:'upi'});
 equal((await db.query('select * from public.payment_methods')).rows.length,1);
 await db.exec('reset role;set role anon');
 await deny('select * from public.payment_methods');
 await deny('select * from public.book_event_ticket_with_payment(gen_random_uuid(),$1,$2,$3)',[event,tier,card]);
 console.log(`PASS: ${checks} payment database checks (ownership, editing, masked-only storage, checkout references, retries, pending status, deletion).`);
} finally {await db.close();}
