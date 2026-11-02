# Saved payment preferences and ticket checkout

Apply [202610310002_payment_preferences.sql](../supabase/migrations/202610310002_payment_preferences.sql)
in Supabase SQL Editor after the profiles and commerce migrations. No payment
provider credentials are needed for these preference screens. This migration does
not charge users or confirm any payment.

## Screens

- Product checkout: delivery address, then the payment screen. Enter a UPI ID or
  a masked card preference, or choose an existing saved preference.
- Get Pass: opens the same styled payment flow directly, with event/tier selection
  and payment preferences. Tickets do not ask for a delivery address.
- Profile → Accounts & Settings: lists the authenticated account's actual saved
  preferences. Add, edit or remove either kind. The earlier sample methods are gone.
- Checkout can also edit an existing preference. Changes appear in the shared
  account store after Supabase confirms the save. Expired card preferences must
  be edited before checkout.

UPI entries save the VPA only, never a UPI PIN. Card preferences save cardholder
name, network, exactly the last four digits and expiry month/year. They are labeled
as preferences, not chargeable saved cards. No full card number, CVV, PIN or
fabricated provider token is collected or stored. There is no local payment-data
cache. A future provider integration must collect full details through its secure
checkout, perform tokenisation with consent, and verify charges on the server.

## Database

`payment_methods.user_id` references `auth.users.id`. Row-level policies permit
only that account to read, add, update or delete its preferences. Upsert payloads
use an explicit field allowlist. Orders/tickets retain their chosen `payment_method`
(`upi`/`card`) plus `payment_method_id`. Deleting a preference clears the foreign
key without deleting purchase history or changing its payment status.

`place_product_order_with_payment` verifies the selected preference belongs to the
current verified user, then calls the existing order transaction and attaches the
preference. `book_event_ticket_with_payment` does the same for one event/tier.
Repeated request IDs return the existing purchase, including its original method;
clients cannot mark either record paid. Unpaid tickets still do not grant event
chat access. Current catalog prices remain request snapshots rather than trusted
payment-provider amounts.

## Verification

The Xcode `PaymentPreferenceTests` suite covers validation, masked-only fields,
save/edit/reload/delete behavior, failures and preference reuse. The database
suite exercises the actual migration, account isolation, forbidden fields,
checkout references, safe retries and pending-only status:

```sh
PGLITE_MODULE=/path/to/@electric-sql/pglite/dist/index.js node supabase/tests/payment-preferences.test.mjs
```

After applying the migration, save a UPI preference and a card preference on one
account, restart, and verify they appear in Accounts & Settings and both checkouts.
Edit and delete them; switch accounts and verify there is no shared payment data.
