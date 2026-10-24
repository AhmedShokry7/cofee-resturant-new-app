# REMAINING ISSUES REGISTER

Scope: the customer app (`lib/`, `test/`), the Edge Functions
(`supabase/functions/`) and the migration chain (`supabase/migrations/`).

**Status: the database blockers are closed.** The migrations 095-107 are
applied to the linked project `webzzasosevzymftgszn` ("cofee-resturant-new-app"),
the migration history is reconciled, and the six payment Edge Functions are
deployed.  The two remaining blockers are external credentials, listed at the
end.

Evidence used:

* **Live, read-only** - the project reference, the database identity, the
  migration ledger, the deployed definitions, the grants and the PostgREST
  surface of `webzzasosevzymftgszn` (PostgreSQL 17.11).
* **Live, applied** - the migrations 096 and 101-107, each in one transaction
  with its ledger row, after a verified logical backup (76 tables, restored
  into an isolated PostgreSQL and compared row by row: 0 mismatches).
* **Dart** - `flutter test` (651 passed, 44 skipped, 0 failed) and
  `flutter analyze --no-pub` (70 issues, all pre-existing warnings, no errors).
* **SQL** - the full chain (106 files) plus the three seed files replayed in
  an isolated PostgreSQL 16.4 (`tools/db_replay/replay.ps1`): 0 failures, every
  assertion `PASS`, and the behaviour test
  `supabase/tests/cancel_order_test.sql` passes.
* **Deno** - 45 tests over the three Edge Functions that changed
  (`deno test supabase/functions/**/index.test.ts`).
* **Live, after the change** - the REST paths of every table the payment
  functions read, with the service role, with an anonymous caller and with a
  signed-in customer.

---

## 0. What was applied to the live database

| Version | File | What it does on the live database |
|---|---|---|
| 096 | `096_assistant_rate_limit_fixed_window.sql` | the live function was a third, out-of-band variant; the reviewed fixed-window definition is now in place |
| 095, 097, 098, 099, 100 | (out of band) | their 21 effects were verified present, then recorded in the ledger without being applied twice |
| 101 | `101_cart_active_per_branch.sql` | one active cart per customer **and branch** (the old index was user wide) |
| 102 | `102_bundle_cart_identity.sql` | the bundle identity of a cart line (`bundle_id`, `bundle_key`) and `orders.reprice_cart` |
| 103 | `103_bundle_aware_checkout.sql` | bundle aware checkout, the source cart line of an order line, and the coupon guard |
| 104 | `104_push_notifications.sql` (renamed from `097_push_notifications.sql`) | the push objects, idempotent; the effects of 098 and 099 are repeated in it |
| 105 | `105_grants_hardening.sql` | the coupon helpers are closed to `anon`, the saved cards are readable again, the delivery log is writable, the cart and order bridges are read-only for customers |
| 106 | `106_public_bridge_payment_and_staff_views.sql` | the eleven `public` bridges the payment functions need, the wrapper of the activation RPC, and the privileges the service role needs to write the payment state |
| 107 | `107_cancel_order_integrity.sql` | a cancellation only from a status the transition table allows, never from a paid order, and the stock comes back for the products that were really deducted |
| 108 | `108_remove_duplicate_indexes.sql` | removes nine exact duplicate indexes verified on the development database |
| 109 | `109_catalog_products_by_ids.sql` | fetches many products, their images and branch prices through one read RPC |
| 110 | `110_product_calories.sql` | adds nullable, non-negative calories-per-serving data to products and the public catalog view |
| 111 | `111_batch_coupon_scopes.sql` | fetches scopes for a list of coupons in one RPC instead of one request per coupon |
| 112 | `112_batch_favorites_sync.sql` | mirrors a customer's pending favorites in one authenticated, RLS-protected RPC |
| 131 | `131_fix_branch_product_pricing_view.sql` | republishes `public.branch_product_pricing` with the four discount columns: the view had frozen its column list at creation time, so every branch read and every branch write failed with `42703` |
| 132 | `132_search_products_discounts.sql` | the search list prices its rows with `catalog.resolve_effective_price` instead of pricing them itself, so the discount is no longer missing from the results |
| 133 | `133_discount_badge_data.sql` | the list functions return the regular price and the discount that was applied, and the featured list regains the category names |
| 134 | `134_order_product_discount.sql` | the product discount becomes an amount of its own: `orders.orders.product_discount_total` and `orders.order_items.product_discount_total`, written by the database and never by the app |
| 135 | `135_place_order_product_discount.sql` | the placed order states the product discount, so the receipt can show what the promotion saved |
| 136 | `136_remove_demo_catalogue.sql` | removes the demo catalogue and every record of the test sessions; the accounts, the access control and the structure stay |
| 137 | `137_reference_data.sql` | the reference data the seed used to hold (the roles, the permissions, the brand, the payment methods, the loyalty rule) becomes a migration, so a database built from the migrations alone is usable |

The ledger held 106 rows through version 107 (001-107 without the gap at 087).
Versions 108-112 have since been applied and recorded, so the ledger currently
holds 111 rows with no duplicate version.

---

## 1. Critical

### 1.1 FIXED - the card payment charged the order number instead of the order id

* **Impact**: every online card payment failed. The order was created and
  stayed unpaid, the cart was never emptied and the loyalty points were never
  awarded.
* **Location**: `lib/features/checkout/presentation/manager/checkout/checkout_cubit.dart:743`
  (the `OrderModel` carried the human number), consumed by
  `lib/features/checkout/presentation/views/widgets/payment_method_bottom_bar.dart:38`
  and sent as `orderId` to `supabase/functions/tap-create-charge/index.ts:45`,
  which looks the order up by its uuid.
* **Evidence**: the number is built as `ORD-<year>-<sequence>`
  (`supabase/migrations/103_bundle_aware_checkout.sql:309`), never a uuid.
* **Fix**: `OrderModel` now carries the server id next to the number
  (`order_model.dart`), the checkout fills it (`checkout_cubit.dart`) and the
  payment uses it (`payment_method_bottom_bar.dart`).
* **Regression test**: `test/checkout_payment_flow_test.dart` - "the charge is
  made for the order id, never for the number".

### 1.2 FIXED - the card payment cubit was provided nowhere in the checkout

* **Impact**: `context.read<CardPaymentCubit>()` threw
  `ProviderNotFoundException` after the order had been placed. The order was
  created, unpaid, the cart was kept and the exception escaped the button.
* **Location**: `lib/features/checkout/presentation/views/widgets/payment_method_bottom_bar.dart:46`
  and `:111`; the only providers of the cubit were the two subscription
  screens.
* **Fix**: the cubit is provided app wide in
  `lib/core/di/app_providers.dart`, with the charge repository.

### 1.3 FIXED - the Tap webhook ignored every event

* **Impact**: a captured card payment left the order `payment_status =
  'unpaid'` and the subscription inactive. The transaction row was already
  marked `captured`, so the money and the ledger disagreed.
* **Location**: `supabase/functions/tap-webhook/index.ts:88` selected only
  `order_id, subscription_id` and then compared `tx.provider_reference` with
  the charge id - a column that was never selected, so the comparison was
  always false and the handler answered `ignored: true`.
* **Fix**: the transaction is read with `provider_reference, amount,
  currency_code, order_id, subscription_id`; the event is recorded **after**
  the state is applied, so a retried delivery repairs an order whose first
  update failed. Deployed.
* **Regression test**: `supabase/functions/tap-webhook/index.test.ts` - 15
  tests, among them "a captured event marks the order as paid" and "the event
  is recorded after the state was applied".

### 1.4 FIXED - the payment functions could not reach their own tables

* **Impact**: every payment call answered
  `PGRST205 Could not find the table 'public.payment_transactions' in the
  schema cache`. No charge was ever recorded, no webhook ever reached the
  order and no refund could be claimed.
* **Evidence (live)**: the PostgREST of the project serves the `public` schema
  only - its OpenAPI document is titled "standard public schema" - and the
  payment functions read the tables of the `payments`, `orders`, `subscriptions`
  and `identity` schemas through `/rest/v1/<table>`. The service role could
  not even write `payments.payment_transactions` or `orders.orders`, and could
  not read `subscriptions.*` at all.
* **Fix**: `supabase/migrations/106_public_bridge_payment_and_staff_views.sql`
  - eleven `public` bridges (`security_invoker`, explicit columns, `service_role`
  only), the wrapper `public.activate_subscription` and the privileges the
  service role needs. The customer facing `public.saved_cards` is untouched and
  still hides the provider ids; the new `public.saved_card_provider` is the
  only place where they are readable.
* **Regression test**: the isolated replay asserts the eleven bridges, that
  none of them is reachable by `anon` or by a customer, and that the service
  role may write the payment state. Live: the eleven paths answer 200 for the
  service role, 401 for an anonymous caller and 403 for a signed-in customer.

### 1.5 FIXED - the migration chain could not be pushed at all

* **Impact**: `supabase db push` aborted with
  `23505 duplicate key value violates unique constraint
  "schema_migrations_pkey"`, permanently, and the push-notification migration
  was never applied. The migrations 098 and 099 then failed with `42P01`.
* **Location**: `supabase/migrations/097_ai_learned_answers.sql` and
  `supabase/migrations/097_push_notifications.sql` - two files with the
  version 097, and the version is the primary key of the migration ledger.
* **Fix**: the push file is now `supabase/migrations/104_push_notifications.sql`
  with the same body (documented in its header: which file owns the version
  097, and how the effects of 098 and 099 are preserved - they are repeated in
  104, and 098/099 became tolerant of a delivery log that does not exist yet).
* **Regression test**: `test/migration_chain_test.dart` - "no two migrations
  share a version", plus the isolated replay, which records every version in
  the ledger and fails when a version is used twice.

---

## 2. High

### 2.1 FIXED - the 3DS return was never verified, so the payment never finished

* **Impact**: after the customer came back from the bank, nothing happened:
  the cart was not emptied, the loyalty points were not awarded and the order
  stayed unpaid.
* **Location**: `lib/features/payment/presentation/views/card_payment_page.dart`
  - `_verifyAndNavigate` was passed to the view and never called, and the page
  used `pushNamedAndRemoveUntil` instead of answering the caller.
* **Fix**: the page observes the app lifecycle, verifies the charge when the
  app resumes after the redirect and answers `true` to the checkout, which
  then empties the cart and shows the confirmation.
* **Regression test**: `test/checkout_payment_flow_test.dart` - "a verified
  charge empties the cart and confirms the order" and "a charge that is not
  verified keeps the cart".

### 2.2 FIXED - the hosted card form never reached the charge

* **Impact**: the customer filled the card form and nothing was charged. The
  cubit emitted `tokenizing` and stopped, because it had no token provider.
* **Location**: `lib/features/payment/presentation/manager/card_payment/card_payment_cubit.dart:86`
  (`if (provider == null) return;`).
* **Fix**: the token of the form is handed to the cubit
  (`createCharge(sourceToken: ...)`); without a token the attempt ends as a
  tokenization failure instead of hanging.

### 2.3 FIXED - the card form showed SAR 1.00 instead of the order amount

* **Location**: `lib/features/payment/presentation/views/card_payment_page.dart:58`.
* **Fix**: the page takes the amount and the currency; the checkout passes the
  server's total, the subscription screens the plan price.

### 2.4 FIXED - every refund was refused with "already in progress"

* **Impact**: a refund never reached Tap. The claim asked PostgREST for no
  representation, so the answer was an empty body, the claim looked
  unsuccessful and the function answered 409.
* **Location**: `supabase/functions/tap-refund/index.ts` (`claimRefund`).
* **Fix**: the claim sends `Prefer: return=representation`. Deployed.
* **Regression test**: `supabase/functions/tap-refund/index.test.ts` - "the
  claim asks PostgREST for the updated row".

### 2.5 FIXED - a refunded order still read `payment_status = 'paid'`

* **Location**: `supabase/functions/tap-refund/index.ts` (`markRefunded`).
* **Fix**: the order is marked `refunded` as well (`markOrderRefunded`).

### 2.6 FIXED - any staff member could hand the money back

* **Impact**: the refund was gated on `orders.read`, a permission the `staff`
  and `cashier` roles hold as well (`supabase/seed/seed_01_reference_data.sql`),
  so a cashier could issue a full refund.
* **Location**: `supabase/functions/tap-refund/index.ts:4`.
* **Fix**: a refund needs a manager role (`owner`, `manager`,
  `branch_manager`) on top of the permission. Deployed.

### 2.7 FIXED - the rate limit trusted the user id in the request body

* **Impact**: any caller could exhaust another customer's quota - a targeted
  denial of service against their checkout - and the limit was not applied to
  the person who actually called.
* **Location**: `supabase/functions/rate-limit/index.ts:64`.
* **Fix**: the bucket is derived from the verified token, and a guest is
  bucketed by the address the request came from. The body is ignored.
  `lib/shared/utils/rate_limit_client.dart` no longer sends a user id.
  Deployed, and live: a signed-in caller and an anonymous caller each get
  their own bucket.
* **Regression test**: `supabase/functions/rate-limit/index.test.ts` - "the
  bucket is the caller, never the user id in the body".

### 2.8 FIXED - a coupon could be dropped at the moment of the order

* **Impact**: the customer saw a discount on the checkout screen, and the
  order was created at the full price. The amount charged was the full price
  while the agreed amount was lower.
* **Location**: `marketing.validate_coupon` answers with a reason instead of
  raising (`supabase/migrations/071_category_coupon_discounts_eligible_lines_only.sql:62`),
  and `orders.place_order_impl` took `max(discount)` and carried on.
* **Fix**: the order is refused when the coupon is not usable right now
  (`reason_code <> 'applied'`), and the cart stays with the customer. The
  client also reconciles the server's discount with the approval and tells
  the customer when they differ
  (`lib/features/checkout/presentation/manager/checkout/checkout_cubit.dart`).
  Live: the guard is in the deployed `place_order_impl`.

### 2.9 FIXED - two coupon helpers were readable by anybody

* **Impact**: `marketing.coupon_eligible_lines` and
  `marketing.allocate_coupon_discount` are SECURITY DEFINER, take a raw cart
  id, filtered nothing by the caller and were executable by `anon` (migration
  093 created them without a REVOKE, and the blanket hardening of migration
  081 runs before 093). A caller who knew a cart id could read the product,
  the quantity and the line total of another customer's basket.
* **Evidence (live)**: `has_function_privilege('anon', ...) = true` for both.
* **Location**: `supabase/migrations/093_restore_dropped_coupon_helpers.sql:43`
  and `:83`.
* **Fix**: `supabase/migrations/105_grants_hardening.sql` - the helpers only
  see the calling customer's cart, and their EXECUTE is revoked from `public`
  and `anon`. Live: `false` for `anon`, `true` for a customer.

### 2.10 FIXED - the saved cards of a signed-in customer were unreachable

* **Impact**: the saved-card list failed with `42501 permission denied for
  table saved_cards`. Migration 063 granted the SELECT, migration 073 dropped
  the view and re-created it without granting again, and a new view has no
  privileges of its own.
* **Location**: `supabase/migrations/073_saved_card_default.sql:91`.
* **Fix**: `supabase/migrations/105_grants_hardening.sql` restores the grant.

### 2.11 FIXED - five migration files were silently skipped by the CLI

* **Impact**: the Supabase CLI only applies a file whose name matches
  `^([0-9]+)_(.*)\.sql$`. Five files do not match, so their effects were
  missing from every fresh replay: the English label of a permission, the
  permission code pattern, the slug of a category and the validation of the
  stock variant key. Six later migrations and the whole seed then failed
  (`42703 column "slug" does not exist`, `42703 column "name_en" does not
  exist`, `23503` on the stock rows).
* **Location**: `002b`, `004b`, `004c`, `007b`, `012b`.
* **Fix**: the effect of every one of them now lives in the migration that
  owns the object - `004` (the label and the code pattern), `007` (the slug)
  and `012` (the variant validation) - and the original files stay in the
  repository, inert, with their history documented. `002b` needs nothing: its
  body is applied again by `050`.

### 2.12 FIXED - the cancellation could end in a state that never existed

* **Impact**: a customer could cancel an order in `ready` or
  `out_for_delivery` - after the drink was made or sent - and still get the
  stock back and the loyalty points reversed. The stock was also given back
  for products that were never deducted, and a paid order was cancelled while
  its money stayed captured.
* **Location**: `supabase/migrations/025_functions_03_orders.sql:517`.
* **Fix**: `supabase/migrations/107_cancel_order_integrity.sql` - the status
  has to be one the transition table allows, a paid or authorized order is
  refused, and the stock is restored from the movement ledger, which is the
  record of what was really deducted. Applied to the live database.
* **Regression test**: `supabase/tests/cancel_order_test.sql` - five cases:
  the stock comes back for the deducted product only, a repeated cancellation
  is refused and does not give the stock back twice, a `ready` order is
  refused, a paid order is refused, and a stranger is refused. It runs in the
  isolated replay (`tools/db_replay/replay.ps1`).

---

## 3. Medium

### 3.1 FIXED - the delivery log of the push notifications could not be written

* **Location**: `supabase/migrations/099_push_bridge_views.sql:49` and
  `supabase/functions/send-push/handler.ts:345`.
* **Fix**: `supabase/migrations/105_grants_hardening.sql` grants the write to
  the service role and keeps `anon` and `authenticated` out.

### 3.2 FIXED - the cart and order bridges were writable by every customer

* **Fix**: `supabase/migrations/105_grants_hardening.sql` revokes them.

### 3.3 FIXED - the coupon bridges were executable by `anon`

* **Fix**: `supabase/migrations/105_grants_hardening.sql`.

### 3.4 FIXED - the checkout could not forget an address or a saved card

* **Location**: `lib/features/checkout/presentation/manager/checkout/checkout_state.dart`
  (`copyWith` could not set a field to null) and
  `lib/features/checkout/presentation/manager/checkout/checkout_cubit.dart`.
* **Fix**: `clearSelectedAddress` and `clearSelectedSavedCard`, and
  `PaymentMethodModel.isCardMethod`, which decides whether a stored card may
  pay the chosen method.
* **Regression test**: `test/checkout_payment_flow_test.dart` - "a saved card
  is only used for a card method".

### 3.5 FIXED - "add card" could never work

* **Impact**: `supabase/functions/tap-tokenize-card/index.ts` assigned to
  `token` without ever declaring it. The module is strict, so the function
  answered with a `ReferenceError` before it did anything.
* **Fix**: the token is declared, and the stored card is written through the
  new `public.saved_card_provider` bridge, which carries the provider ids.
  Deployed.

---

## 4. Open - confirmed

### 4.1 HIGH - the payment provider credentials are not configured

* **Impact**: every Tap function answers
  `503 {"error":"TAP_SECRET_KEY is not configured for this function"}`. The
  secret list of the project holds no Tap key, so no charge can be created,
  verified, refunded or deleted, and the webhook cannot check a signature.
* **Why it is open**: the key lives in the merchant's Tap dashboard and is not
  in the repository, the environment or the project.
* **Next step**: add the secret of the project, then re-deploy the functions:
  `supabase secrets set TAP_SECRET_KEY=<the key of the Tap dashboard>`, and
  the card form of the app needs the public key:
  `--dart-define=TAP_PUBLIC_KEY=<the public key>`.

### 4.2 MEDIUM - external push delivery is not configured end to end

* **Impact**: the in-app notification store is live (47 rows), the dispatch
  trigger, `pg_net`, Vault webhook secret and `send-push` Edge Function are
  present, and three device tokens are registered. The delivery log has zero
  attempts, and the project has no `FIREBASE_SERVICE_ACCOUNT`, so receipt of
  external notifications is not verified and FCM cannot be authenticated.
* **Next step**: `supabase secrets set FIREBASE_SERVICE_ACCOUNT=<the service
  account JSON of the Firebase project>`.

### 4.3 MEDIUM - checkout total differs from the invoice - CLOSED

* **Fix**: migration 113 adds `public.quote_checkout`, which reprices the
  current cart and returns the same tax, delivery fee, coupon and grand total
  rules as order placement. The checkout now shows only this server quote, and
  `public.place_order_with_quote` rolls back order creation if the server total
  changed after the customer confirmed it. Migration 113 is deployed.

### 4.4 LOW - the admin application is a placeholder

* **Impact**: `agent/AGENTS.md` and `agent/CODE_ARCHITECTURE.md` describe an
  admin app whose only implemented flow is the authentication. The permission
  model of the database is therefore not exercised by any interface.
* **Why it is open**: a product scope, not a defect.

### 4.5 MEDIUM - there is no screen that creates a branch

* **Impact**: the demo branches were removed with the rest of the demo content
  (migration 136), so the customer application has no branch to pick and the
  branch pricing screen has nothing to price. The database has no admin write
  path for `core.branches` either: the branch rows used to come from the seed.
* **Why it is open**: a product scope, not a defect. The reference data the
  application needs is in migration 137; the branches are the tenant's own
  locations and they are entered by hand until a branch screen exists.

---

## 5. Unverified - not counted as defects

* **The default privileges of the `public` schema** on the live project. They
  decide whether the grants of 105 and 106 are sufficient; the live checks
  show the outcome is right in both cases.
* **The 44 skipped tests** are the integration tests that need credentials or
  a database. They are unchanged and still skipped for the same reason.

---

## 6. Files changed in this run

```
lib/core/di/app_providers.dart                       the card payment cubit
lib/core/locale/app_strings.dart                      one new message
lib/features/checkout/data/model/order_model.dart    the server id of an order
lib/features/checkout/data/model/payment_method_model.dart   isCardMethod
lib/features/checkout/presentation/manager/checkout/checkout_cubit.dart
lib/features/checkout/presentation/manager/checkout/checkout_state.dart
lib/features/checkout/presentation/views/widgets/payment_method_bottom_bar.dart
lib/features/payment/presentation/manager/card_payment/card_payment_cubit.dart
lib/features/payment/presentation/views/card_payment_page.dart
lib/features/subscriptions/presentation/views/subscription_plan_details_page.dart
lib/features/subscriptions/presentation/views/subscription_plans_page.dart
lib/shared/utils/rate_limit_client.dart
supabase/functions/_shared/tap.ts                     a named answer for a missing secret
supabase/functions/rate-limit/index.ts
supabase/functions/rate-limit/index.test.ts            new
supabase/functions/tap-create-charge/index.ts         the provider bridge of a card
supabase/functions/tap-delete-card/index.ts           the provider bridge of a card
supabase/functions/tap-refund/index.ts
supabase/functions/tap-refund/index.test.ts
supabase/functions/tap-tokenize-card/index.ts         the undeclared token
supabase/functions/tap-verify-charge/index.ts         the provider bridge of a card
supabase/functions/tap-webhook/index.ts
supabase/functions/tap-webhook/index.test.ts           new
supabase/migrations/004_identity_02_rbac.sql          the corrections of 004b/004c
supabase/migrations/007_catalog_01_categories_products.sql  the correction of 007b
supabase/migrations/012_inventory_01.sql               the correction of 012b
supabase/migrations/098_push_delivery_locale_and_grants.sql   tolerant
supabase/migrations/099_push_bridge_views.sql          tolerant
supabase/migrations/104_push_notifications.sql         renamed from 097
supabase/migrations/105_grants_hardening.sql           new
supabase/migrations/106_public_bridge_payment_and_staff_views.sql  new
supabase/migrations/107_cancel_order_integrity.sql     new
supabase/tests/cancel_order_test.sql                  new
test/checkout_payment_flow_test.dart                   new
test/migration_chain_test.dart                         new
tools/db_replay/bootstrap.sql                          new
tools/db_replay/replay.ps1                             new
tools/db_replay/assertions.sql                         new
```

The changes of the previous run (`lib/features/cart/**`,
`test/cart_cross_device_sync_test.dart`, `test/cart_sync_race_test.dart`,
`test/support/fake_postgrest_server.dart` and the migrations 101-103) were
kept as they are.

