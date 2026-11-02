// Isolated Postgres checks; never connects to the hosted project.
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
const { PGlite } = await import(pathToFileURL(process.env.PGLITE_MODULE).href);
const db = new PGlite();
const a = '11111111-1111-4111-8111-111111111111';
const b = '22222222-2222-4222-8222-222222222222';
let checks = 0;
const equal = (actual, expected) => { assert.deepEqual(actual, expected); checks++; };
async function deny(sql, params = [], code = '42501') {
    await assert.rejects(() => db.query(sql, params), e => e.code === code); checks++;
}
async function login(id) {
    await db.exec('reset role; set role authenticated');
    await db.query("select set_config('request.jwt.claim.sub',$1,false)", [id]);
}
const empty = { matches: [], messages: {}, dismissedIDs: [] };
const history = {
    matches: [{ id: 'demo-zoya', raver: { id: 'zoya' }, matched_at: 1000, chat_unlocks_at: 11800 }],
    messages: { zoya: [{ id: 'message-one', text: 'Hello', sentAt: 11800, isMine: true, raverID: 'zoya' }] },
    dismissedIDs: ['zoya', 'arjun']
};
async function save(value, revision) {
    return (await db.query('select * from public.save_partner_sample_history($1,$2)',
        [JSON.stringify(value), revision])).rows[0];
}
try {
    await db.exec(`create role anon; create role authenticated;
        create schema auth;
        create table auth.users(id uuid primary key, email text, email_confirmed_at timestamptz, is_anonymous boolean);
        create table public.profiles(id uuid primary key references auth.users(id) on delete cascade);
        create function auth.uid() returns uuid language sql stable as
            $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
        grant usage on schema auth,public to authenticated,anon;`);
    for (const id of [a,b]) {
        await db.query('insert into auth.users values($1,$2,now(),false)', [id, `${id}@example.com`]);
        await db.query('insert into public.profiles values($1)', [id]);
    }
    await db.exec(await readFile(new URL('../migrations/202610310003_partner_sample_history.sql', import.meta.url), 'utf8'));
    await login(a);
    equal((await db.query('select * from public.partner_sample_history')).rows, []);
    const first = await save(history, 0);
    equal(first.user_id, a);
    equal(Number(first.revision), 1);
    equal(first.history, history);
    await deny('insert into public.partner_sample_history(user_id,history) values($1,$2)', [a, JSON.stringify(empty)]);
    await deny('update public.partner_sample_history set history=$1', [JSON.stringify(empty)]);
    await deny('delete from public.partner_sample_history');
    // A new session sees exactly the original timestamps and messages.
    await db.exec('reset role');
    await login(a);
    equal((await db.query('select history from public.partner_sample_history')).rows[0].history, history);
    await deny('select * from public.save_partner_sample_history($1,0)', [JSON.stringify(empty)], '40001');
    const updated = await save({ ...history, dismissedIDs: [...history.dismissedIDs, 'meher'] }, 1);
    equal(Number(updated.revision), 2);
    equal(updated.history.matches[0], history.matches[0]);
    await deny('select * from public.save_partner_sample_history($1,1)', [JSON.stringify(empty)], '40001');
    // Another account cannot read or overwrite the first account's snapshot.
    await login(b);
    equal((await db.query('select * from public.partner_sample_history')).rows, []);
    await deny('select * from public.save_partner_sample_history($1,2)', [JSON.stringify(empty)], '40001');
    equal((await save(empty, 0)).user_id, b);
    await login(a);
    equal((await db.query('select history from public.partner_sample_history')).rows[0].history, updated.history);
    await deny('select * from public.save_partner_sample_history($1,-1)', [JSON.stringify(empty)], '22023');
    await deny('select * from public.save_partner_sample_history(null,2)', [], '22023');
    await deny('select * from public.save_partner_sample_history($1,2)', [JSON.stringify({})], '23514');
    await deny('select * from public.save_partner_sample_history($1,2)', [JSON.stringify({ ...empty, matches: null })], '23514');
    equal((await save(empty, 2)).history, empty);
    await login(a);
    equal((await db.query('select history from public.partner_sample_history')).rows[0].history, empty);
    await db.exec('reset role; set role anon');
    await deny('select * from public.partner_sample_history');
    await deny('select * from public.save_partner_sample_history($1,0)', [JSON.stringify(empty)]);
    await db.exec('reset role');
    await db.query('update auth.users set email_confirmed_at=null where id=$1', [b]);
    await login(b);
    await deny('select * from public.save_partner_sample_history($1,1)', [JSON.stringify(history)]);
    await db.exec('reset role');
    await db.query('delete from public.profiles where id=$1', [a]);
    equal((await db.query('select user_id from public.partner_sample_history')).rows.map(r => r.user_id), [b]);
    console.log(`PASS: ${checks} sample history database checks (login persistence, original dates, account isolation, revisions, unmatch, validation, anonymous denial, profile ownership).`);
} finally { await db.close(); }
