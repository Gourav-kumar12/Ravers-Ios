# Partner discovery and event groups

Apply `supabase/migrations/202610310001_social.sql` in the same project's SQL Editor
**after** the profile and commerce migrations. The iOS publishable key cannot apply
schema migrations. This migration creates new social tables, functions and policies;
it does not create demo users or alter customers' payment status.

Also apply `supabase/migrations/202610310003_partner_sample_history.sql` after the
profile migration. It creates `partner_sample_history`, linked by `user_id` to the
person's profile. Only the signed-in account can read its history; writes use
`save_partner_sample_history` and reject stale revisions from another device.

## Partner

The Partner tab opens a swipe deck. Left / Pass skips a profile; right / Like records
a like. Real members appear when they have an eligible purchase, a completed profile,
and discovery enabled (Ghost mode off). Email and phone are never exposed in discovery.
City is omitted when Show my area is off. Existing photo storage remains unchanged.

Both people must like each other. The server creates one match per pair and sets
`chat_unlocks_at` to exactly three hours after matching. Reads and writes remain
restricted to the participants; message writes are rejected before that timestamp.
Unmatching closes the conversation for both members. Repeated likes do not reopen it
or change its timestamps. Messages persist in Supabase and refresh every four seconds
while the chat screen is open; discovery checks for new profiles/matches every eight
seconds while its screen is active. No push notification service is included.

When the live deck has no eligible people, three clearly marked sample profiles are
available. A sample right swipe simulates a mutual match with the same three-hour
wait. Signed-in sample likes, passes, matches, original unlock dates, unmatches,
and messages are saved to Supabase before the UI confirms the change. Signing in
again (including on another device) restores that account's history without
starting a new timer. The old per-account local cache is imported only if no
server history exists. Server history takes precedence, including an empty
history after unmatching. A failed restore blocks sample actions until retry.
Samples remain clearly labeled and do not send automated replies or grant access
to a real member's chat. Unauthenticated previews remain local.

## Event groups

A paid, Confirmed or Used ticket automatically creates the event's shared room.
Existing qualifying tickets are backfilled during migration. Join the group from an
event's detail page or its pass in Vault. There is one group per exact `event_id`;
all tiers for that event share it. This chat has no three-hour delay.

A pending booking is visible in Vault but does not grant group access. A ticket to a
different event, cancelled ticket, refunded/failed payment, or unauthenticated session
cannot read the room/messages or send. Membership is checked on every server request;
refunds therefore revoke access without a separate membership cleanup job. The
current checkout still requires a real payment backend to confirm payments.

## Verification

- Open Partner with no other eligible users: sample deck, Pass/Like buttons, gestures,
  and the matches list should work. Like a sample, log out, then sign in on a second
  device: the match, messages, and exact unlock date must remain. The liked profile
  must not return to the deck. Another account must not inherit it. Unmatch, sign
  in again, and verify the old match is absent. Failed saves must not show success.
- Enable discovery and save completed profiles on two purchased accounts. A right swipe
  on only one account creates no match. The reciprocal swipe creates one on both.
- Confirm the countdown; attempts to call `send_partner_message` before unlock must fail.
  A device clock change cannot bypass the server check. Send after unlock and verify
  the other account receives the message. Retry the same message ID without duplication.
- Confirm paid tickets on two accounts for one event, and a ticket for another event
  on a third. Only the first two may join/read/send in the first event's room.
- Refund one ticket and verify its group access disappears. Unmatch a pair and verify
  neither member can continue writing in its former conversation.

Local checks (no connection to the hosted project):

```sh
PGLITE_MODULE=/path/to/@electric-sql/pglite/dist/index.js node supabase/tests/social.test.mjs
```

The Xcode `SocialTests` suite covers sample persistence, the three-hour boundary,
server-backed matching, write failures, and event-membership revocation.
