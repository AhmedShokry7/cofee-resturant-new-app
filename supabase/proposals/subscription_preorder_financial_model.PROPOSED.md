# Subscription preorder: financial and technical model

**Status: proposal only.** This model records required distinctions and safe transaction boundaries. It does not choose a VAT treatment, revenue-recognition policy, subscription valuation method, or legal invoice document. Those decisions need finance approval before the executable migration is completed.

## Core entities and audit trail

The current schema already has subscriptions, plan products, payment transactions, usage, order-linked consumptions, order events, invoices, and order status history. It does not persist the source/value of subscription entitlement, per-line funding allocation, an accounting policy, or a subscription liability ledger. `subscription_events` is useful operational audit but is not a double-entry accounting ledger.

Proposed additions, subject to `DATABASE_SPEC.md` §7 approval:

1. **Subscription funding record** per issued cycle: `source` (`customer_payment`, `free_plan`, `loyalty_reward`, `admin_grant`, or another enumerated source), source reference, gross amount, discounts, tax evidence/reference, currency, payment transaction reference where real, and creation actor/time. It distinguishes the way the entitlement was granted; it does not assert revenue recognition.
2. **Order funding allocation** per order line and funding component: order/line/subscription IDs, allocated quantity, gross retail value, coverage value, cash amount due/collected, allocation method/version, currency, and idempotency reference. A line may have subscription and customer-payment components when approved rules allow it. The server derives every amount from current authoritative price and approved coverage rules.
3. **Append-only subscription accounting events** linked to funding/allocation and the operational reservation/usage event. Event types include cycle-issued, coverage-reserved, coverage-consumed, coverage-released, refunded/adjusted, and approved no-show resolution. Corrections use reversal/adjustment events rather than rewriting history. Posting to a general ledger remains out of scope until an existing ledger or approved chart of accounts is identified.
4. **Versioned accounting policy** for revenue-recognition trigger, subscription valuation/allocation, tax point/document, partial coverage, and free/reward cycles. It must be immutable once referenced by a transaction; policy changes affect future events only.

These are design entities, not approved table names or deployable schema. Any new table/column requires adding the data dictionary and review prescribed by `DATABASE_SPEC.md` §1 and §7.

## Sources of entitlement

| Source | Operational entitlement | Cash payment record | Accounting consequence |
|---|---|---|---|
| Customer payment | Issued after verified subscription payment | Existing subscription-linked captured transaction | Recognition, VAT, and invoice timing must follow approved policy. |
| Free commercial plan | Issued with explicit free-plan provenance | None | Finance decides if promotional cost, zero-value sale, or other treatment applies. |
| Loyalty reward | Issued with reward/redemption reference | None for the entitlement itself; points ledger remains separate | Finance decides whether points redemption has a value/revenue effect. |
| Admin grant/compensation | Issued with actor, reason, and audit event | None unless separately collected | Must not be treated as a cash sale; finance decides cost/contra-revenue treatment. |

Presence of an active subscription is never sufficient evidence that cash was collected.

## Entitlement and reservation lifecycle

Let `issued_units` be the entitled and valid carryover units under the existing subscription rules. `reserved_units` are units held by live orders; `consumed_units` are units delivered. `available_units = max(issued_units - consumed_units - reserved_units, 0)`. The database subscription row remains the serialization lock/source for cup count; order allocation rows provide value/funding audit.

| Event | Customer balance effect | Reservation state | Financial/audit effect |
|---|---|---|---|
| Cycle issued | Increase issued units | None | Record source and policy version; do not infer a cash receipt or revenue journal. |
| Preorder accepted | Move selected units from available to reserved; total entitlement unchanged | `reserved` | Append coverage-reserved event; do not recognize consumption yet. |
| Order handed over | Decrease reserved and increase consumed; available remains consistent | `consumed` | Append one usage and one accounting event. Apply the approved liability/revenue policy once. |
| Authorized cancellation before handoff | Decrease reserved, restore available | `released` | Append reasoned release/reversal; reverse any provisional accounting effect only under the approved policy. |
| No-show | No automatic balance change in v1 | Remains reserved until approved resolution | No expiry duration or forfeiture is invented. A later authorized resolution must be auditable and idempotent. |
| Refund/chargeback for original subscription | No silent rewriting of historical usage | Depends on policy and existing consumed units | Record refund/adjustment against original funding; define future entitlement suspension/negative balance with finance. |

The existing order lifecycle supports `ready` then `completed` at pickup handoff; `completed` is the point at which reserved units may be consumed. Existing authorized cancellation invokes the normal cancellation path and releases the reservation. Finalization must also append a uniquely keyed `subscription_usage` row; the current trigger does not.

## Mixed-basket pricing and coverage

For each order line, the server loads authoritative retail price and validates branch, options, availability, subscription inclusion, and quantity. The customer never sends trusted prices, coverage values, taxes, or totals.

For design purposes only:

`line_due = max(line_retail - approved_subscription_coverage - approved_discounts, 0) + applicable_fees_and_tax`

The server allocates each eligible unit to subscription coverage only within the approved entitlement. Any uncovered units or non-covered products use the existing priced checkout/payment path. Every portion is recorded separately so retail value, coverage, discount, payment due, and actual collection are not conflated. `orders.grand_total` and current item constraints must retain their existing meanings or be revised additively after migration and invoice/report impact review; no client-side or post-insert rewriting is allowed.

The current plan is cup-count based and does not define a monetary value per cup. Partial line coverage therefore needs an approved valuation basis (fixed plan value allocation, retail-price coverage, or another approved method) and rounding rules. Until that basis is approved, mixed baskets may be supported only where products/quantities are unambiguously covered and the rest is priced normally; partial monetary coverage remains disabled.

## Events and accounting controls

- **Sale of subscription:** persist actual funding source and payment evidence. Whether this creates the invoice/VAT document and whether proceeds are revenue or deferred liability is a finance decision.
- **Reserve:** no cash transaction and no revenue recognition by default. Record order/source/allocation/policy references and idempotency key.
- **Consume:** once-only event on physical pickup handoff. This is the operational usage fact; financial posting depends on policy (e.g. release deferred amount, recognize sale, or no additional posting if recognized earlier).
- **Release:** once-only event on authorized pre-handoff cancellation. Restore units. No new revenue or customer charge is inferred.
- **Customer payment for mixed basket:** the regular cash/card tender applies only to the amount due. Existing captured/verified payment records remain real payment evidence; no zero-value fake tender is inserted.
- **Invoices/VAT:** normal paid order invoice behavior stays unchanged. Subscription-covered amounts must be distinguished by explicit funding source and allocation, not `grand_total = 0`, discounts, or payment status. An invoice/document for subscription sale or redemption must be chosen by the accountant; tax treatment cannot be inferred from current code.
- **Reports:** report gross retail fulfillment, subscription coverage, cash due, actual captured amount, and policy treatment in separate measures. Existing financial reconciliation must not classify subscription-covered value as a missing cash invoice or a captured payment mismatch. Implement these report changes in the same approved migration as funding semantics.

## Atomic server path and privileges

1. Authenticate with `auth.uid()`; derive customer identity server-side.
2. Validate strict input shape and take a per-user/idempotency transaction lock. A retry must compare canonical branch, subscription, schedule, lines, and chosen funding allocation to the persisted original.
3. Lock the owned active subscription row; validate start/end/status, plan and branch eligibility, and plan-product inclusion. Lock/check inventory and the exact pickup slot using existing server paths.
4. Recompute retail prices and approved coverage from trusted tables/policy; reject over-allocation and required modifiers unsupported by this version.
5. Create the order, line snapshots, funding allocations, reservation consumptions, status event/history, and deduplicated confirmation notification in one transaction. Any failure rolls back slot, stock, order, and reserve.
6. Revoke direct authenticated execution of the legacy helper once its ownership/order-item checks are hardened. The new writer alone may call the internal definer helper with server-built order item IDs.
7. Only the existing permission-checked admin status path may move order state. On cancellation/handoff, triggers or an internal state function update reservation/allocation and append usage/accounting events atomically. The client/admin UI cannot mutate balances.
8. Customer reads are owner-gated. Admin detail is a narrow RPC gated by `orders.read` and `identity.can_manage_branch(order.branch_id)`. Preserve current `admin_orders()` output and add an optional field compatibly only if review proves that is the smallest safe contract change.

## Idempotency and concurrency

- Serialize balance updates with `SELECT ... FOR UPDATE` on the subscription row; balance check and reservation are in the same transaction.
- Enforce uniqueness for the user/idempotency key, per-order allocation component, consumption idempotency, and once-only usage event.
- Retry with same key and same canonical request returns original order. Same key with different input fails.
- Finalize and release select only `reserved` rows `FOR UPDATE`, transition each once, and insert events with unique keys. A concurrent finalize/cancel has one winner through the row lock and terminal state.
- The pickup capacity trigger already serializes slot occupancy; keep it in the same transaction.

## Admin contract

Keep `admin_orders()` backward compatible. The least risky contract change is a narrow `admin_order_subscription_details(p_order_id)` RPC called only when an authorized employee opens a selected order. Include subscription/plan reference, entitlement source, covered products and quantities, retail/covered/cash amounts, and reserved/consumed/released state. Gate it with `orders.read` and `identity.can_manage_branch(order.branch_id)`. The current UI assumes nested `subscription_preorder`, but local `admin_orders()` does not produce it; update the UI repository to call the narrow RPC before activation, rather than changing the list payload.

## Unresolved finance/business decisions

1. Revenue-recognition point and accounting account for each funding source.
2. Subscription sale invoice and VAT tax point; document required at redemption, if any.
3. Valuation and allocation of one cup against variable product retail prices, options, discounts, and rounding.
4. Tax treatment of free plans, reward-funded cycles, staff/admin grants, refunds, and chargebacks.
5. Whether partial monetary coverage and mixed baskets are allowed, and tender/receipt behavior for the remainder.
6. No-show policy: reservation hold duration, forfeiture/refund rules, and who may resolve it.
7. Treatment of existing active subscriptions without explicit funding provenance. Do not backfill them as paid by inference.

These decisions are configuration points in a future implementation, not defaults to encode now. No SQL/RPC/financial posting is enabled until an owner/accountant approves the values and the exact SQL/test/rollback package.

## Test plan (not run against a database)

After SQL is approved and installed on an isolated development database, use real authenticated test sessions and cover:

- valid fully-covered, mixed, and partial-coverage baskets with server-derived totals;
- paid, free, reward-funded, and admin-granted entitlement provenance;
- unowned/expired/not-started subscription, excluded product, mandatory option, unavailable product/branch, invalid slot, insufficient units, and insufficient stock;
- simultaneous requests whose combined units exceed balance; exactly one succeeds;
- same idempotency key/same body returns same order and allocation; changed body rejects;
- rollback at each insertion/trigger boundary leaves no order, slot, stock movement, allocation, or reserved balance;
- cancellation releases once; ready does not consume; completed handoff consumes and inserts one usage row; concurrent cancel/finalize has one terminal winner;
- notification dedupe by order/status and exact confirmation details;
- owner reads only own orders/subscriptions; other owner and anon denied; branch staff see permitted branch only;
- normal cash/card order and POS still issue the existing invoice; subscription-covered order creates no fake payment or unintended invoice; finance reconciliation separates coverage; no duplicate revenue posting under each approved policy;
- admin can read selected order subscription detail only with orders.read and branch access; existing order JSON fields remain unchanged.

Flutter regression already run locally: the prior 40 targeted subscription tests passed. It does not prove any RPC or accounting behavior. Admin order regression tests passed. Database tests in `supabase/tests/subscription_preorder_acceptance_test.sql` remain unrun because the RPC contract and accounting schema are not finalized.
