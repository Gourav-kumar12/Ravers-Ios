# Supabase orders, tickets, and Vault

Run the entire [commerce migration](../supabase/migrations/202610230001_commerce.sql)
once in the same Supabase project's **SQL Editor**, then run the iOS app again.
The migration is transactional: an error rolls back the setup. Existing tables
with these names must be reviewed before applying it; do not drop customer data.

In **Table Editor**, select the **public** schema:

| Table | Records |
| --- | --- |
| `vault_items` | Saved products, selected sizes, quantities, and user IDs |
| `orders` | One row per checkout; `items` contains every product, size, and quantity; delivery address, INR total, payment preference, source, and timestamps |
| `tickets` | Event, selected tier, quantity, INR total, user ID, booking/payment status, and eventual ticket code |

`user_id` always references **Authentication → Users → ID**. Users can only read
their own rows. Clients can change their own cart but cannot mark orders paid,
confirm tickets, issue codes, or overwrite purchase history.

Both **Order Now** and **Vault → Checkout** call `place_product_order`. Vault
checkout saves every selected line and removes the purchased cart lines in the
same database transaction. A changed Vault is rejected so the user can refresh
before trying again. Retrying the same order ID returns the existing order.

Ticket booking uses a unique `(user_id, event_id)` key, so retries do not create
duplicate bookings. Saved bookings appear under **Vault → Passes**, and saved
orders appear under **Vault → Orders**. History and cart contents reload after
sign-in, when Vault opens, and when the app becomes active; pull down in Vault to
refresh manually. Orders, tickets, and cart items load independently, so a failed
cart or ticket request does not hide successfully restored orders.

For an event, tap **Get Pass** to open the full-screen payment flow, select its
tier and saved/new payment preference, then confirm **Book Pass · ₹…**. The app writes to `public.tickets` and reads that user's
saved booking back before opening **Vault → Passes**. Errors remain in the
form for retry; no pass is added on a failed save. An existing booking's button
also opens Passes. The card includes the full booking reference, matching `id`
in Table Editor → public → tickets. Pending bookings are visible here even
before payment confirmation. A cached record alone never counts as a successful
save. Debug logs show `Sending ticket <id> to <host>` and, after readback,
`Verified saved ticket <id> in <host>`.

Server-confirmed orders and tickets are cached separately for each authenticated
user UUID. A relaunch can display that user's saved history while refreshing;
network failures preserve it and show a retry message. On iOS, the cache uses
file protection and is excluded from device backups. Cached payment status never
unlocks Partner until the server validates current history. A successful empty
server response clears stale cached records. This cache cannot restore purchases
from the old app version that were never saved to Supabase.

## Payment integration

There is no payment gateway in the current app. New orders and tickets therefore
have `payment_status = 'pending'`. Checkout records only the preferred method
(`upi` or `card`) and a reference to the user's saved preference. The separate
`payment_methods` table stores UPI IDs and masked card metadata; full card numbers,
CVVs and UPI PINs are never collected or stored. See
[the payment preference setup guide](PAYMENT_PREFERENCES_SETUP.md) for the required
additional migration and edit/delete behavior. No successful charge is invented.

Catalog products and events are currently local fixtures. Their prices and
availability are purchase-request snapshots, not trusted fulfillment data. A
future payment backend must validate authoritative prices and inventory, create
the provider payment, and verify its webhook before using a server-only
`service_role` credential to mark records paid/confirmed and issue ticket codes.
Partner membership starts after a product order is saved and read back from the
server, including orders whose payment is pending. Existing orders also unlock
Partner after history refreshes. Cancelled orders and failed or refunded payments
do not qualify. This membership rule does not mark payments paid or activate
event passes: tickets still require paid/confirmed status for Partner access and
entry codes. Only rows verified during the current session grant access; saving
one new order does not validate other cached rows.

## Find a customer's purchases (admin SQL Editor)

```sql
select o.id, u.email, o.items, o.total, o.payment_status, o.status, o.placed_at
from public.orders o join auth.users u on u.id = o.user_id
where u.email ilike '%rahul%'
order by o.placed_at desc;

select t.id, u.email, t.event->>'name' as event_name,
       t.tier->>'name' as tier, t.total, t.payment_status, t.status
from public.tickets t join auth.users u on u.id = t.user_id
where u.email ilike '%rahul%'
order by t.booked_at desc;
```

If a save fails, the screen stays open and shows an error. In a Debug build,
Xcode's console prints the underlying error under `[CommerceService]`.
Successful checkout reads the saved row from `orders` before showing confirmation.
The confirmation includes the full order reference, which can be searched in the
Table Editor. Debug logs include `Sending order <id> to <host>` followed by
`Verified saved order <id> in <host>`. Neither log includes an address or payment
credentials. A send message without a verification message indicates a failed
request; the next error line identifies the cause.
