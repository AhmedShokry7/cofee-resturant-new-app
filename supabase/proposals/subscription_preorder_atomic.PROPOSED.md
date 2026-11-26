# Subscription pre-order SQL proposal (not applied)

> **Review status: BLOCKED before executable SQL.** The earlier draft assumed a
> subscription entitlement had already been paid in cash. Local code disproves
> that assumption: cycles can be payment-backed, free, or reward-funded. See
> [accounting decision](subscription_preorder_accounting_decision.md). Do not
> use the funding, order-total, or invoice statements below as an approved
> accounting design. No migration or RPC body is ready to apply.

## Scope

This proposal uses the existing `orders.orders`, `orders.order_items`,
`orders.order_status_history`, `orders.order_events`,
`subscriptions.subscription_consumptions`, and `subscriptions.subscription_usage`
tables. It creates no table. The client can select products and a branch, but
the server owns subscription eligibility, price, stock, pickup capacity, and
quota validation.

## Current integration contract

- `subscriptions.reserve_for_order(...)` already locks the subscription and
  reserves cups, but it is exposed to authenticated clients directly and
  accepts an arbitrary order id, branch, and caller-supplied order-item ids.
- `place_order_with_pickup_schedule(...)` creates normal priced orders and
  reserves a pickup slot through the current local pickup-scheduling WIP.
- Normal order creation reprices against catalog and awards loyalty points.
  The current order schema has no explicit funding-source or subscription-
  coverage field. Do not zero catalog values, encode entitlement as a discount,
  or reuse the loyalty-reward zero-total order until the financial decision is
  approved. The accounting proposal recommends explicit server-owned funding
  and coverage that preserve retail values and report amount due separately;
  whether existing `orders` fields can represent it or §7 needs an approved
  addition remains undecided.
- The KDS triggers mirror an inserted order and its lines automatically.
  `completed` currently means the pickup hand-off in the KDS, so the existing
  order status trigger can finalize the reservation at that point. Verify this
  semantic against `kitchen.complete_ticket` before approval.
- The order notification trigger deduplicates on `order:<order UUID>:<status>`
  and fires on status updates. Its payload has order id/number, status, total,
  and branch UUID; it has no branch name or scheduled pickup time. A dedicated
  insertion notification for the new order should use `order_status` and a
  unique `order:<id>:pending` dedupe key, include branch names and the scheduled
  time, and rely on the existing notification-to-push dispatcher. Later
  `confirmed`/`preparing`/`ready`/`cancelled` updates remain on the existing
  trigger and are already idempotent by status.

## Proposed RPC surface

```sql
public.list_my_subscription_preorder_branches(p_subscription_id uuid)
  returns table(branch_id uuid, code text, name_ar text, name_en text)

public.list_my_subscription_preorder_products(
  p_subscription_id uuid, p_branch_id uuid
)
  returns table(product_id uuid, name_ar text, name_en text,
                description_ar text, description_en text, image_url text,
                branch_price numeric)

public.place_subscription_preorder(
  p_subscription_id uuid,
  p_branch_id uuid,
  p_lines jsonb,                 -- [{"product_id":"...","quantity":1}]
  p_idempotency_key text,
  p_scheduled_pickup_at timestamptz
)
  returns table(order_id uuid, order_number text, status text,
                scheduled_pickup_at timestamptz, remaining_cups integer,
                cups_reserved integer,
                reused_existing_order boolean)

public.list_my_subscription_preorders(p_subscription_id uuid)
  returns table(order_id uuid, order_number text, status text,
                branch_id uuid, branch_name_ar text, branch_name_en text,
                scheduled_pickup_at timestamptz, product_id uuid,
                product_name_ar text, product_name_en text,
                quantity integer, reservation_status text, created_at timestamptz)

public.admin_order_subscription_details(p_order_id uuid)
  returns jsonb
```

## Current client contract gaps

- The customer repository calls `list_my_subscription_preorders`, so the
  server contract above now matches that name. Its Dart model currently expects
  one summary row per order (`branch_name`, `order_status`,
  `consumption_status`), not the line-level result shown above. Before SQL,
  choose one stable shape; a parent preorder plus a nested line array is the
  clearest contract for multiple products.
- The customer history currently invokes a separate detail fetch when a row is
  opened. The request/result contract must include order identity and lines, or
  deliberately continue through the existing order-details repository.
- The admin UI parses `subscription_preorder` nested in `admin_orders()`, but
  the approved narrow design is `admin_order_subscription_details(order_id)`.
  The admin repository must call this narrowly scoped RPC for the selected
  order; do not replace `admin_orders()` wholesale to add subscription data.
- The customer list RPC and all admin detail reads must filter on the owned
  subscription or `orders.read` plus `identity.can_manage_branch` respectively.
  The admin detail must never return another branch's subscription/customer
  data.

All RPCs are `SECURITY DEFINER`, `SET search_path=''`, and must explicitly
check `auth.uid()` or the existing staff permission/branch predicates. Revoke
from `PUBLIC` and `anon`; grant customer calls to `authenticated`. The admin
RPC requires `orders.read` plus `identity.can_manage_branch(order.branch_id)`.

The product-list RPC is owner-gated and returns only active plan products that
are currently available at the requested active, plan-eligible branch. For
`product_scope='selected'`, it joins `subscriptions.plan_products`; for an
all-products plan, it reads active `catalog.products`. Availability and
`branch_price` come from `catalog.resolve_effective_price`; the client must
not make one request per product or treat the estimate as an order price.
`catalog.products` has `description_ar`, `description_en`, and `image_url`
columns (migration 007), so cards can show those fields without schema changes.
The customer subscription read must also return `cups_reserved`; the client
available balance is `cups_entitled + cups_carried_over - cups_used -
cups_reserved`, clamped at zero. No per-product balance exists; all plan cups
remain fungible.

## Atomic order transaction

`place_subscription_preorder` must, in one PostgreSQL transaction:

1. Require `auth.uid()`, a non-empty idempotency key, an active branch, a
   scheduled pickup time, and a non-empty JSON array of distinct product IDs
   with positive quantities (bounded by the existing cart's maximum line qty).
2. Acquire the same per-user/idempotency advisory transaction lock used by the
   order RPC. For an existing order with that user/key, verify its
   `subscription.preorder_created` event, subscription id, branch, scheduled
   pickup, and ordered products/quantities match the retry; return that order
   unchanged. Reject a reused key with different input.
3. Lock the subscription row `FOR UPDATE`; verify ownership, `active` status,
   `starts_at <= now()`, `ends_at > now()`, active plan, active branch,
   `all_branches` or a matching `plan_branches` row, and product scope (`all`
   or matching `plan_products`). Check every product is active and available
   for the selected branch by calling `catalog.resolve_effective_price` with
   no option IDs. Do not accept or use a client price or balance.
4. Validate that `p_scheduled_pickup_at` is exactly one of
   `public.available_pickup_slots(p_branch_id, local_pickup_date)` and is not
   earlier than the configured prep buffer. The existing order trigger locks
   capacity for this slot inside the same transaction; allow it to reject a
   full slot, which rolls back the order and reservation together.
5. Sum requested quantity, then compare it with
   `cups_entitled + cups_carried_over - cups_used - cups_reserved` under the
   subscription row lock. Reject insufficient quota.
6. Create the pickup order and snapshots only after the approved funding
   representation is defined. Never mark the order `paid` or create a fake
   payment. Preserve catalog retail line values; approve the coverage and due
   representation against the existing total constraint before implementing
   it. The `BEFORE INSERT` pickup-capacity trigger claims the slot.
7. Apply the same existing branch inventory lock/check/decrement and
   `inventory.stock_movements` sale rows used by free loyalty reward orders.
   If a branch-stock row is absent, preserve existing reward behavior; if a
   row is present and stock is insufficient and `allow_negative=false`, abort.
8. Call the internal `subscriptions.reserve_for_order` with server-built lines
   containing the actual `order_item_id`s. This updates `cups_reserved` and
   inserts `subscription_consumptions` before commit. A failure rolls back
   order, stock, slot capacity, and reservation.
9. Insert `order_status_history`, a `subscription.preorder_created` order event
   containing subscription id and canonical product/quantity lines, and one
   deduplicated `order_status` confirmation notification including order number,
   branch name, scheduled time, and status.
10. Return the saved order and the server-computed remaining cup balance.

The RPC must reject option/customization fields for this first version: the
current subscription-plan product RPC returns base products only and the
existing plan rule is cup-count based. Adding customizations requires the
standard option-validation and price snapshot contract, not a client-side
shortcut.

## Reservation lifecycle and hardening

- Revoke `authenticated` execute on both
  `subscriptions.reserve_for_order(uuid,uuid,uuid,jsonb,text)` and
  `public.reserve_subscription_for_order(uuid,uuid,uuid,jsonb,text)`. Keep the
  internal function callable by the new definer RPC, not by Flutter.
- In the internal helper, additionally require the order belongs to `auth.uid()`,
  its branch equals `p_branch_id`, its status is still `pending`, its fulfillment
  is pickup, and each supplied `(order_item_id, product_id, quantity)` exactly
  matches an item on that order. Keep the subscription row lock and quota check.
- Existing trigger behavior stays: `ready` does not finalize; `completed`
  decrements `cups_reserved` and increments `cups_used`; `cancelled` decrements
  only `cups_reserved`. Extend finalization to insert an idempotent
  `subscription_usage` row with `method='app_order'`, order/branch/product,
  quantity, and the reservation idempotency key. Never create usage rows at
  reservation time.
- No-show expiry/cancellation has no existing business rule. Do not auto-release
  reservations. Until a policy is approved, a staff member may cancel via the
  existing permitted cancellation route; capacity and quota are released once.

## Not included / design gate

This cannot be a thin wrapper around `place_order_with_quote`: that core always
reprices and charges catalog amounts, and it awards loyalty points from payable
subtotal. The pre-order path must be an explicit entitlement order creator using
the existing free-reward order pattern, or the paid order core must first be
extended with a trusted server-only entitlement context. Do not call the
current public `reserve_subscription_for_order` from Flutter, and do not make a
normal paid order then refund/rewrite totals afterward.

Mixed baskets of subscription-covered and paid products are intentionally
excluded. The UI should accept only the plan's included products and show zero
due. Delivery and add-ons are excluded; this is scheduled pickup only.

## Rollback and approval

This is a proposal only; it is not a migration and has not been executed.
Rollback should revoke/drop only the new RPCs and restore the previous
`subscriptions.reserve_for_order`, `subscriptions.finalize_order_consumption`,
and notification trigger definitions from the source migrations. Because this
changes reservation lifecycle and closes a client-callable RPC, roll back only
before real preorder consumption records exist; afterward use a forward fix.
No rows or historic migrations should be deleted or rewritten.

Before moving the SQL into a numbered migration or applying it, the owner must
review the complete SQL, risk/rollback steps, isolated non-production test
result, and explicitly select a non-production target phase. Production apply
is out of scope.
