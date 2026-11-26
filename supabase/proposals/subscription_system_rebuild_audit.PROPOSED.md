# Subscription rebuild: audit and implementation contract

Status: local design and read-only audit, 2026-11-26. This is not an approved accounting policy or a deployable migration. Do not cancel live subscriptions or apply schema changes from this document.

## Current system map

| Area | Current source | Keep / change |
|---|---|---|
| Package catalog | `subscriptions.plans`, `plan_products`, `plan_branches`; admin plan editor in `subscriptions_admin` and customer `SubscriptionPlansPage` | Keep IDs and historical rows. Version published prices, allowed products, branch rules and terms at purchase. Add per-product units or explicit pooled units and daily limits. |
| Package purchase | `subscriptions.subscriptions`, `create_pending_subscription`, Tap charge, `activate_subscription` | Keep as legacy package cycles. New purchases must snapshot price/currency/rules and activate from a single server transaction after verified payment. |
| Package balance | `cups_entitled`, `cups_used`, `cups_reserved`, `subscription_consumptions`, `subscription_usage` | Keep historical values; reconcile into a new entitlement ledger. No direct client balance writes. Existing `reserve_subscription_for_order` accepts caller order and line IDs without binding them to owned order lines: do not use it from the customer app. |
| Product subscriptions | `customer_product_subscriptions` and `customer_product_subscription_runs` | These are recurring **orders**. They currently grant no prepaid units and charge at checkout when a run is confirmed. Retain and relabel as recurring order schedules. Implement the requested prepaid product subscription separately, with a balance per product. |
| Payment | `payments.payment_transactions`, Tap create/verify/webhook Edge functions | Preserve existing order payments and references. Add a purchase target for prepaid product subscriptions, server-side amount/currency snapshot checks, and one atomic confirmation/entitlement grant. |
| Invoices and VAT | migration 262 invoice engine, order-paid trigger, refund tables and reconciliation | Preserve existing invoices and immutable snapshots. Design subscription sale and redemption document treatment only after finance approval. Never mark a covered order paid or create a fake payment. |
| Admin | plan editor, subscription directory, counter paid-subscription RPC | Keep branch and permission checks; add product packages, purchase attempts, per-product balances and ledger inspection. Counter cash/card confirmation stays a separate funding source. |

Package/customer UI is under `lib/features/subscriptions`; recurring schedules are under `lib/features/product_subscriptions`; Tap is under `supabase/functions/tap-*`. No current table or RPC implements a **prepaid product-specific balance**.

The legacy `create_pending_subscription` returns any row matching a global idempotency key without first checking `user_id` and plan. This can disclose another customer's subscription ID when a key collides. New purchase idempotency must be scoped to the authenticated customer and reject a reused key with different inputs. The legacy activation also reads mutable `plans` values, so changing a published plan between payment creation and webhook can alter granted units or reject a legitimate charge. Immutable purchase snapshots are a prerequisite for the new flow.

## Read-only impact snapshot

From the configured database on 2026-11-26; no customer data or subscription status was changed by this audit:

| Pseudonymous customer | Package cycles | Package remaining units on cancelled cycles | Active recurring schedules |
|---|---:|---:|---:|
| `f5dc635a71` | 2 cancelled | 10 | 1 daily, 1 weekly |
| `d5ff3c1d88` | 3 cancelled | 10 | 0 |

There are **no active package cycles**, **no package reservations**, **one pending recurring-order run**, and **two captured package payment transactions totaling SAR 20**. The 20 remaining units on cancelled historical cycles are an audit figure, not currently spendable credit. Match each captured transaction, invoice and any refund to its exact cycle before deciding settlement. No automatic refund or balance reset is authorized by this report. The daily schedule was added as a customer test fixture in the prior task and is included in the count.

## Target lifecycle and contracts

1. A published, immutable offer version contains price, currency, duration, allowed branches and products, unit quantities, usage limits, rollover and refund terms. Draft edits do not rewrite sold versions.
2. `create_subscription_purchase(offer_version_id, idempotency_key)` locks the offer, validates ownership and sale state, calculates price on the server, snapshots VAT inputs and creates `pending_payment` **without granting units**. Retrying the key and same request returns the same purchase; a different request is rejected.
3. Tap charge metadata identifies that purchase. A verified, signed webhook or server charge lookup must match provider reference, purchase, exact amount and currency. A single locked activation transaction records the capture and grants entitlement units once. Repeated webhook delivery returns the prior result.
4. An entitlement account is either `package_pool` or `product_specific`. It stores the source purchase and funding source (`paid`, `free`, `reward`, `counter_grant`), product ID where required, granted and expiry policy. Append-only ledger events are `grant`, `reserve`, `consume`, `release`, `expire`, `revoke`, `refund_adjustment`. Every event has user, account, source purchase, order, actor, timestamp, reason and unique idempotency key. Available = grants + releases − reservations − consumption − expiry − revocation; reserved and consumed are separately derived. A product-specific account cannot cover another product.
5. The customer selects an eligible product, branch and pickup slot. One server RPC reprices and verifies product/branch/slot/ownership, locks the entitlement accounts in stable ID order, creates an ordinary operational order and its coverage allocation, then reserves units atomically. No client-provided total, discount or coverage is trusted. A mixed basket records cash due and subscription coverage separately.
6. Handoff/completion consumes reserved units once. Allowed cancellation releases them once. Race between cancellation and handoff has one terminal winner. No-show needs an explicit business policy before automation.
7. Manual renewal creates a fresh purchase/version and entitlement period. Auto renewal requires explicit consent plus a supported payment mandate; it is disabled until reviewed. Expiry ends spendability, but preserves the ledger. Rollover defaults to zero unless the sold offer version says otherwise.

Use only the states needed per entity. Purchase states: `pending_payment`, `payment_processing`, `paid`, `payment_failed`, `refund_pending`, `partially_refunded`, `refunded`. Entitlement states: `active`, `expired`, `cancelled`; `draft` belongs to offers, not purchases. Staff actions require existing `subscriptions.manage` or `subscriptions.consume` permissions plus branch scope; customer RPCs require `auth.uid()` ownership. Direct balance table writes remain revoked.

## Financial decision gate

Finance must approve: revenue recognition timing; whether subscription sale or redemption triggers VAT and which tax invoice/receipt; treatment of free/reward grants; partial/full refunds after partial consumption; unused balance at expiry or cancellation; no-show handling; and whether any paid legacy cancelled balance is owed. Keep these policies configurable and block the affected posting/document steps until approval. Technical order coverage cannot be represented as `payment_status='paid'` without a real captured payment.

The existing `subscriptions.activate_subscription` SQL still accepts a server-verified `authorized` transaction. The local Tap handlers now mark only `captured` as paid and do not activate an authorization. Before deploying either handler, the development migration must also tighten the SQL predicate to `status = 'captured'`, assert transaction amount/currency against an immutable purchase snapshot, and prove that legacy reward and counter-grant paths remain valid. Publishing only the Edge code would leave an inconsistent payment contract.

## Proposed schema and RPC acceptance contract

`subscription_system_rebuild_schema.PROPOSED.sql` specifies additive offer versions, purchases, payment links, pooled/per-product entitlement accounts, append-only events, order allocations and owner-scoped read RLS. It ends in `ROLLBACK` and has not been applied. A reviewed deployment migration must add staff read RPCs with branch checks, prohibit direct client writes, make published offer versions immutable, and implement these transaction-scoped RPCs before any route uses the new tables:

- `create_subscription_purchase(offer_version, key)`: validate the published offer, snapshot price/currency/terms, return the same purchase for an identical repeated key and reject key reuse with different inputs. Never grant here.
- `confirm_captured_subscription_purchase(purchase, provider_reference)`: lock purchase and transaction, require captured/verified amount, currency and reference match, create one account per product or one pool, append grants once, and mark purchase paid in the same transaction.
- `create_subscription_preorder(account selections, branch, slot, items, key)`: derive price and coverage from catalog and offer snapshots, lock accounts in stable order, validate ownership/product/branch/time, create order and allocation, append reservations once. Return separate cash due and coverage; no fake payment.
- `finalize_subscription_order(order, action, key)`: consume on authorized handoff or release on allowed cancellation exactly once under an order lock. Reject a second terminal action and audit the actor.
- `expire_entitlement` and refund/cancellation operations: append reasoned terminal events; accounting posting, invoice creation, no-show deductions and refunds remain gated by approved policy.

The schema alone is insufficient to spend units. The ledger must be reconciled against locked account projections in each RPC, with tests for simultaneous last-unit requests, repeated keys, mixed baskets, malformed client totals, cross-customer access and staff branch scope. Existing normal order contracts remain the fallback until these acceptance tests pass on an isolated development database.

## Transition and rollback

1. Build new tables and RPCs on an isolated development database, leaving legacy tables and customer rows intact. Backfill a **read-only reconciliation manifest** mapping every legacy cycle and usage row to its proposed entitlement account. Resolve all mismatches before granting migrated balances.
2. Test package and product purchases, payment failure/retry/webhook replay, server pricing, branch/owner guards, concurrent reservations, release/consume, expiry, renewals, refund policy, normal orders and admin read scopes. Compare invoice and revenue reports to pre-change snapshots.
3. Run a staged customer impact report immediately before any cancellation. The separate cancellation SQL proposal aborts by default. Review pending runs and captured payments per cycle with finance. Obtain explicit approval for the exact customer list and policy before any live cancellation.
4. Rollback before paid purchases means disabling new offers/routes and reverting additive schema/RPC deployment while keeping the append-only audit. After real captures, rollback must preserve payment, invoice and entitlement rows and use compensating events; deleting rows or restoring a stale balance snapshot is forbidden.

## Current local delivery and remaining work

This audit, guarded cancellation draft, proposed additive schema, collapsed history in My Subscriptions, and local Tap verification guards are prepared. The new prepaid product purchase, executable entitlement RPCs, atomic redemption, admin finance screens, accounting integration and development-database acceptance tests remain to be implemented. Local checks: focused Dart analysis passed for subscription code; 14 customer subscription navigation/detail widget tests and 77 admin subscription tests passed; customer and admin web builds passed; Deno type checks passed and 22 Tap shared/webhook/verification tests passed. The separate Tap refund test file still has six existing failures (its expected HTTP/status behavior differs from the current implementation); a combined run without `--allow-env` also fails one shared Tap environment test. The network-dependent `hash_test.ts` could not download its Deno standard-library import in this restricted environment. The admin-wide Dart analysis completed with 16 info-level lint findings outside this change. No production migration, mass cancellation, refund or Edge deployment has been performed for this rebuild.
