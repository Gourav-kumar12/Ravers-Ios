# Raverse Backend Architecture (v2)

Rebuilt from two sources:
- `Raverse_Supabase_Backend_Architecture.pdf`: the original plan (services, tables, phases).
- **The actual iOS code**: what the screens really show (passes per event, sizes per
  product, two profile photos, Partner Key, Host a Rave, event chat, wishlist…).

Where they disagree, the app wins, because the backend has to serve the screens that exist.
§3 lists every change and the reason for it.

---

## 1. The approach: where each kind of logic lives

| Kind of work | Where it runs | Raverse examples |
|---|---|---|
| Simple read/write of *your own* rows | **PostgREST + RLS** (SDK `.from("table")`) | edit profile, wishlist, cart, read my orders/tickets, send message |
| Several rows that must change together, or a rule the client must not skip | **Postgres function (RPC)** `security definer` | `place_order()` (prices + stock), swipe → match, `get_discovery_deck()`, join group |
| Needs a secret or an external API | **Edge Function** | Razorpay order + webhook, refunds, QR validation, email delivery hook |
| Files | **Storage** (DB keeps the *path*) | profile/event/product/chat images |
| Live updates | **Realtime** | chat messages, order/ticket status after payment |
| Time-based jobs | **pg_cron** | expire unpaid orders, expire subscriptions, mark events completed |

### The three non-negotiable rules
1. **Identity comes from the JWT.** `user_id` columns default to `auth.uid()`, and RLS
   checks `= auth.uid()`. The app never sends a user ID it chose itself.
2. **Money is decided by the server.** The client sends *what* it wants (variant, quantity,
   tier). Postgres reads the prices and writes the totals. Only the payment webhook can set `paid`.
3. **No secrets in the app.** The app holds only the publishable key. The service-role key and
   Razorpay secret live in Edge Function secrets.

---

## 2. Big picture

```
 SwiftUI View → ViewModel → Service → Supabase Swift SDK (publishable key + user JWT)
                                              │
 ┌───────────────────────────── Supabase ─────┴──────────────────────────────┐
 │ Auth ........ email OTP → auth.users.id (verified user identity)          │
 │ Postgres .... tables + RLS, RPC functions, triggers, pg_cron              │
 │ Storage ..... profile-images · event-images · product-images · chat-images │
 │ Realtime .... messages, order/ticket status                               │
 │ Edge Fns .... checkout · book-tickets · subscribe · razorpay-webhook       │
 │               request-refund · validate-ticket · send-email (optional)        │
 └───────────────────────────────────────────────────────────────────────────┘
          ▲ webhook (HMAC-verified)                    ▲ email delivery
       Razorpay                                    Custom SMTP
```

---

## 3. What changed from the PDF, and why

| PDF design | Rebuilt | Why (evidence in the app) |
|---|---|---|
| `profiles.profile_image_url` | `profiles.avatar_path` + **`profile_photos`** (up to 6) | `UserProfile.primaryPhoto/secondaryPhoto` and Partner photo1/photo2 feed the swipe card. Store paths, not URLs. |
| `profiles.party_type`, `preferred_venue` (single values) | moved to **`profile_preferences`** as `text[]` | `genres[]`, `venues[]`, `partyStyles`, `favoriteArtists[]` are multi-select chips |
| `profile_preferences` with its own `id` | `user_id` **is** the PK (1:1) | one preferences row per user, so no duplicates are possible |
| `profiles.role` | kept, but **only an admin RPC can change it** | otherwise any user could `update profiles set role='admin'` |
| — | **`organizer_applications`** | the "Host a Rave" screen (`HostRaveView`) |
| `events.ticket_price` | **`ticket_tiers`** (name, price, capacity, sold) | `Event.passes: [Pass]`: "Phase 1", "Phase 2", each with its own price and remaining count |
| `events.event_date + start_time + end_time` | `starts_at`, `ends_at` (`timestamptz`) | raves end after midnight, and three separate columns break on "23:00 → 05:00" |
| `events.image_url` | `cover_image_path` + **`event_images`** | gallery + banner |
| — | **`event_lineup`** | `Event.lineup: [LineupSlot]` on EventDetail |
| `tickets.ticket_type` (text), `qr_code` stored | `tier_id` FK, `code` + **server-signed QR**, `entries_used` | `HeldPass(tierName, entries, code)`. A stored static QR can be forged; a signed one can't. |
| status `CHECKED_IN` | `ticket_status = used` + **`ticket_scans`** log | matches your spec's statuses; the door needs an audit trail |
| `products.price / image_url / stock_quantity` | `price_paise`, `compare_at_price_paise`, `is_partner_key`, `specs[]` + **`product_variants`** (stock per size) + **`product_images`** | `Product.sizes`, `compareAtPrice`, `isPartnerKey`, `specs` |
| `cart_items.product_id` | `cart_items.variant_id` | the cart has to know *which size* |
| — | **`wishlist_items`** | `WishlistStore` / Wishlist tab |
| `orders.total_amount` (decimal) | integer **paise** columns + `order_number` + address **snapshot** | no float rounding; the address can't change after the order |
| refund columns on `orders` | **`payments`**, **`payment_events`**, **`refunds`** tables | one payment model for orders, tickets **and** subscriptions; webhooks are idempotent |
| `conversations.event_id` only | `type` = `direct` / `group` / `event` + `match_id` / `group_id` / `event_id` | matches → DM, crews → group chat, `Event.chatPreview` → event-wide chat |
| — | **`user_blocks`**, **`reports`** | required for any swipe/match/chat app (App Store review asks for this) |
| — | `has_partner_access()` | Partner tab is locked (`PartnerLockedView`) until subscription **or** Partner Key |
| — | **`admin_audit_log`** | track what admins changed |
| iOS: top-level `Views/`, `ViewModels/` folders | **keep your feature folders** (`Features/X/…`) + shared `Services/`, `Core/Models/` | your app is already organised this way, and feature folders scale better. A refactor isn't worth it. |
| 6 phases, payments + webhooks last | payments infra built **with the shop** | you can't confirm an order without the webhook |

---

## 4. Database schema

Conventions:
- `id uuid pk default gen_random_uuid()` (profiles use the auth user id)
- `created_at`, `updated_at timestamptz` (trigger-maintained)
- money is `integer` **paise** (₹1,499 = `149900`)
- RLS on **every** table, plus explicit `grant`s to `authenticated` (never `anon` for user data)

### 4.0 Foundation
Enums: `app_role (user, organizer, admin)` · `order_status (pending, confirmed, processing, shipped, delivered, cancelled, refunded)` ·
`payment_status (pending, paid, failed, refunded)` · `ticket_status (pending, confirmed, cancelled, used, refunded)` ·
`event_status (draft, published, cancelled, completed)` · `subscription_status (pending, active, expired, cancelled)` ·
`swipe_action (like, pass)` · `conversation_type (direct, group, event)` · `message_type (text, image, system)`

Helper functions (`security definer`, `stable`): `is_admin()`, `is_organizer()`, `owns_event(event_id)`,
`is_conversation_member(conversation_id)`, `has_partner_access()`, `set_updated_at()`

### 4.1 People
| Table | Columns | Access |
|---|---|---|
| **profiles** | `id`→auth.users, `display_name`, `handle` unique, `phone`, `email`, `date_of_birth`, `gender`, `bio`, `city`, `location geography(point)`, `avatar_path`, `personality`, `role`, `is_discoverable`, `is_profile_complete` | own row read/update (not `role`); others read only via `public_profiles` view |
| **profile_preferences** | `user_id` PK, `genres[]`, `venues[]`, `party_styles[]`, `favorite_artists[]`, `anthem`, `interested_in[]`, `age_min`, `age_max`, `max_distance_km` | own row |
| **profile_photos** | `user_id`, `position` 0–5, `storage_path` · unique(user_id, position) | own rows; others via discovery |
| **organizer_applications** | `user_id`, `brand_name`, `details`, `status`, `reviewed_by` | own insert/read; admin approves → role = organizer |

A trigger on `auth.users` insert creates the `profiles` + `profile_preferences` rows, so
every logged-in user always has a profile. `is_profile_complete` drives onboarding.

### 4.2 Shop
| Table | Columns | Access |
|---|---|---|
| **products** | `name`, `slug`, `description`, `category`, `price_paise`, `compare_at_price_paise`, `is_partner_key`, `specs[]`, `is_active` | read active; admin writes |
| **product_images** | `product_id`, `storage_path`, `position` | read; admin writes |
| **product_variants** | `product_id`, `size` (null = one size), `sku`, `stock_quantity ≥ 0` | read; admin writes |
| **wishlist_items** | `user_id`, `product_id` · unique | own |
| **cart_items** | `user_id`, `variant_id`, `quantity 1–10` · unique(user, variant) | own (no price column) |
| **shipping_addresses** | `user_id`, `name`, `phone`, `line1`, `line2`, `city`, `state`, `pincode`, `is_default` | own |
| **orders** | `user_id`, `order_number`, `status`, `payment_status`, `subtotal_paise`, `shipping_paise`, `total_paise`, `shipping_address jsonb`, `cancelled_at` | own **read only**; created by `place_order()` |
| **order_items** | `order_id`, `product_id`, `variant_id`, `product_name`, `size`, `unit_price_paise`, `quantity`, `line_total_paise` | read if you own the order |

### 4.3 Payments
| Table | Columns | Access |
|---|---|---|
| **payments** | `user_id`, `purpose` (order/ticket/subscription), `order_id`/`ticket_id`/`subscription_id`, `amount_paise`, `gateway_order_id` unique, `gateway_payment_id`, `status`, `failure_reason` | own read; Edge Functions write |
| **payment_events** | `gateway_event_id` unique, `type`, `payload jsonb`, `processed_at` | service only |
| **refunds** | `payment_id`, `amount_paise`, `gateway_refund_id`, `status`, `reason`, `requested_by` | own read; Edge Functions write |

### 4.4 Events & tickets
| Table | Columns | Access |
|---|---|---|
| **events** | `organizer_id`, `title`, `description`, `about_title`, `genres[]`, `venue_name`, `address`, `city`, `location geography(point)`, `starts_at`, `ends_at`, `capacity`, `status`, `cover_image_path` | everyone reads `published`; organizer CRUD own; admin all |
| **event_images** / **event_lineup** | `event_id`, … `position` | read with event; organizer writes |
| **ticket_tiers** | `event_id`, `name`, `detail`, `price_paise`, `capacity`, `sold_count`, `sales_start`, `sales_end`, `is_active` | read; organizer writes |
| **tickets** | `user_id`, `event_id`, `tier_id`, `quantity`, `unit_price_paise`, `total_paise`, `payment_status`, `status`, `code` unique, `entries_used`, `used_at` | owner reads; organizer reads own event's; **nobody updates from the client** |
| **ticket_scans** | `ticket_id`, `scanned_by`, `result`, `scanned_at` | organizer of event, admin |

View `event_stats` (going count, remaining per tier) is computed and never written by the client.

### 4.5 Social
| Table | Columns | Access |
|---|---|---|
| **groups** | `event_id`, `name`, `created_by`, `conversation_id`, `max_members` | ticket holders of the event |
| **group_members** | PK(`group_id`, `user_id`), `role`, `joined_at` | members; join/leave via RPC |
| **swipes** | PK(`swiper_id`, `target_id`), `action`, check swiper ≠ target | own insert (needs `has_partner_access()`), own read |
| **matches** | `user1_id < user2_id`, `conversation_id` · unique pair | both users read; created only by trigger |
| **user_blocks** / **reports** | blocker/blocked · reporter/reported/reason/status | own; admin reviews reports |
| **conversations** | `type`, `match_id?`, `group_id?`, `event_id?`, `last_message_at` | members |
| **conversation_members** | PK(`conversation_id`, `user_id`), `last_read_at` | members |
| **messages** | `conversation_id`, `sender_id`, `body`, `message_type`, `image_path` | members read/insert; in the Realtime publication |

### 4.6 Subscriptions & admin
| Table | Columns | Access |
|---|---|---|
| **subscription_plans** | `code`, `name`, `price_paise`, `interval`, `features jsonb`, `is_active` | read active |
| **subscriptions** | `user_id`, `plan_id`, `status`, `starts_at`, `ends_at`, `payment_id`, `gateway_subscription_id`, `cancel_at_period_end` | own read; webhook writes |
| **admin_audit_log** | `admin_id`, `action`, `table_name`, `record_id`, `diff jsonb` | admin |

### Relationships
```
auth.users 1─1 profiles 1─1 profile_preferences
                 ├─n profile_photos, shipping_addresses, organizer_applications
                 ├─n wishlist_items ─► products 1─n product_variants, product_images
                 ├─n cart_items ─────► product_variants
                 ├─n orders 1─n order_items ─► products / product_variants
                 ├─n payments ◄─ orders | tickets | subscriptions ─► refunds
                 ├─n events (organizer) 1─n ticket_tiers, event_lineup, event_images, groups
                 ├─n tickets ─► events, ticket_tiers   1─n ticket_scans
                 ├─n group_members ─► groups ─► conversations(group)
                 ├─n swipes ─(mutual like)─► matches ─► conversations(direct)
                 ├─n conversation_members ─► conversations 1─n messages
                 └─n subscriptions ─► subscription_plans
```

---

## 5. Key flows

**Login.** Email → `signInWithOTP(email:shouldCreateUser: true)` → enter the six-digit code → `verifyOTP(email:token:type: .email)` → verified session in Keychain → profile and preferences saved under the Auth UUID → Home. See [email OTP setup](EMAIL_OTP_SETUP.md) for SMTP, templates, hosted configuration, and acceptance checks.

**Shop checkout.**
```
Cart (cart_items) → "Pay" → Edge fn checkout
   → place_order(address_id): lock cart, read live prices, reserve stock, insert order + items
   → Razorpay create order → returns razorpay_order_id → iOS Razorpay SDK
   → Razorpay → razorpay-webhook (verify HMAC, dedupe by event id)
   → payments.paid → orders.payment_status = paid, status = confirmed, clear cart
iOS listens (Realtime) to its order row. The SDK's "success" callback confirms nothing.
Unpaid after 15 min → pg_cron cancels it and releases stock.
```

**Ticket booking + door.**
```
Tier + qty → Edge fn book-tickets → check capacity, create ticket (pending) → Razorpay
webhook → ticket confirmed, tier.sold_count += qty, user added to the event chat
Ticket screen shows QR = code + HMAC(code)  ← generated by the server
Organizer scans → validate-ticket: verify HMAC, owns_event, status confirmed,
                  entries_used < quantity → increment + ticket_scans row
```

**Swipe → match → chat.** `swipe(target, like)` inserts a row → trigger checks for the reverse
like → creates `matches` + `conversations(direct)` + 2 members → both users see it in the inbox.

**Refund.** Organizer/admin → `request-refund` → Razorpay refund API → `refunds` row →
webhook `refund.processed` → payment/order/ticket set to `refunded`, stock or tier capacity released.

---

## 6. Storage

| Bucket | Read | Path | Write |
|---|---|---|---|
| `profile-images` | public | `{user_id}/{uuid}.jpg` | owner (first folder = `auth.uid()`) |
| `event-images` | public | `{event_id}/{uuid}.jpg` | `owns_event()` |
| `product-images` | public | `{product_id}/{uuid}.jpg` | admin |
| `chat-images` | **private** (signed URLs) | `{conversation_id}/{uuid}.jpg` | conversation members |

Compress on device before upload (max 1600 px, JPEG ~0.8).

---

## 7. iOS structure (keep what you have)

```
Ravers-ios/
├── App/                RaverseApp, RootView (auth gate)                 ✅
├── Core/
│   ├── Supabase/       SupabaseManager, Secrets.xcconfig                 ✅
│   ├── Models/         DB models: Profile, ProfilePreferences, Product, ProductVariant,
│   │                   CartItem, Order, OrderItem, Event, TicketTier, Ticket, Group,
│   │                   GroupMember, Swipe, Match, Conversation, Message,
│   │                   SubscriptionPlan, Subscription, Enums
│   ├── Components/  Theme/  Utilities/ (Money, AppError)
├── Services/           AuthService ✅, ProfileService, StorageService, ProductService,
│                       WishlistService, CartService, OrderService, PaymentService,
│                       EventService, TicketService, GroupService, MatchService,
│                       ChatService, SubscriptionService
└── Features/           each feature = Views + ViewModel
    Auth ✅ · Profile · Home (shop) · Wishlist · Vault (cart/orders) · Checkout ·
    Party (events) · Tickets (new) · Organizer (new) · Partner · Match (+ chat)
```

Rules: Views never import Supabase. Services never take a `userID` for writes.
Models use snake_case `CodingKeys`, and the existing UI structs map from them.

| Existing code | Connects to |
|---|---|
| `ProfileViewModel`, `EditProfileView`, `HostRaveView` | ProfileService, StorageService |
| `HomeViewModel`, `ProductDetailView` | ProductService |
| `WishlistStore` | WishlistService |
| `VaultStore` (cart, orders, address) | CartService, OrderService |
| `CheckoutFlowView` | PaymentService (Razorpay) |
| `PartyViewModel`, `EventDetailView` (`Pass` → TicketTier, `HeldPass` → Ticket) | EventService, TicketService, GroupService |
| `PartnerViewModel` | SubscriptionService, ProfileService (preferences) |
| `MatchStore`, `MatchesInboxView`, `ChatView` | MatchService, ChatService |

---

## 8. Roadmap

The PDF's 6 milestones, broken into shippable steps:

| # | Milestone | Steps | Status |
|---|---|---|---|
| 1 | **Auth** | project · SDK · SupabaseManager · connection test · email OTP · verified session · sign out | code implemented · hosted Email/SMTP/templates and live acceptance checks required |
| 2 | **Profiles** | foundation migration · profiles · preferences · photos · Storage · Profile/Edit screens · Host a Rave | next |
| 3 | **Shop** | products/variants/images · wishlist · cart · addresses · `place_order()` · Razorpay checkout + webhook · orders screen · refunds | |
| 4 | **Events & tickets** | events/tiers/lineup · organizer role · organizer screens · book-tickets · signed QR · scanner · validate-ticket | |
| 5 | **Social** | groups · swipes + match trigger · discovery deck · blocks/reports · conversations · messages · Realtime | |
| 6 | **Subscriptions & admin** | plans · subscribe + webhook · Partner gating · admin RPCs · audit log · pg_cron jobs | |

Every step ships in the same order: migration SQL → RLS + grants → test the policies in SQL →
Swift model → Service → ViewModel → wire the existing screen → check in the dashboard.

---

## 9. Dev workflow

```
supabase/                     ← created by `supabase init`
├── config.toml
├── migrations/               one file per step, never edited after it's pushed
│   └── 2026xxxxxxxxxx_<name>.sql
├── functions/<name>/index.ts Edge Functions
└── seed.sql                  sample products/events for dev only
```

| Task | Command |
|---|---|
| new migration | `supabase migration new profiles` |
| apply to the project | `supabase db push` |
| new Edge Function | `supabase functions new checkout` |
| set a secret | `supabase secrets set RAZORPAY_KEY_SECRET=…` |
| deploy a function | `supabase functions deploy checkout` |

Before launch: create a **second project for production**. Keep the current one as dev, and push
the same migrations to both. Configure custom SMTP and OTP email templates as described in [email OTP setup](EMAIL_OTP_SETUP.md).
