# Order lifecycle & pricing proposals — review plan

These are the changes the 2026-10-27 orders audit found. Topics **A** and **B**
were pasted into the SQL Editor during that audit and are **live now**, and have
since been recorded as their own numbered migrations
([`../migrations/190_admin_order_status_delegation.sql`](../migrations/190_admin_order_status_delegation.sql)
and
[`../migrations/191_admin_order_item_effective_price_and_totals.sql`](../migrations/191_admin_order_item_effective_price_and_totals.sql)),
so a chain rebuild reproduces the deployed state. The branch isolation was
approved separately as
[`../migrations/186_admin_orders_payments_branch_scope.sql`](../migrations/186_admin_orders_payments_branch_scope.sql).
Topics **C** onwards below are still drafts in
[`186_admin_orders_branch_scope_and_totals.PROPOSED.sql`](186_admin_orders_branch_scope_and_totals.PROPOSED.sql)
and must not be applied until their own decision, migration number and tests exist.

A full body-by-body re-scan after 190/191/194 left three diverging functions and
four missing ones. They were **not** recording work — in each case copying the live
text into a migration would bless a behaviour change — so they waited as decisions
in
[`196_body_drift_owner_decisions.PROPOSED.sql`](196_body_drift_owner_decisions.PROPOSED.sql).
Those four are **closed**: `196`, `197`, `198` and `199` shipped them, two of them
the opposite way to that file's recommendation, and a re-scan now reports zero
diverging bodies. Topic **C** below and the delivery-fee half of **B** closed the
same way as `200_admin_order_item_stock_and_delivery_fee.sql`.

Rules that keep this folder honest:

- one topic = one migration = one decision. Never bundle a security fix with a
  lifecycle or pricing change again.
- each topic needs a **read-only rehearsal query** on a copy of production data
  before anyone pastes SQL, and a written answer to "what breaks if this is
  wrong?".
- no file here counts as applied **until it is copied out with its own number and
  repaired into the ledger**. Applying one is an owner action in the SQL Editor,
  and an unrecorded paste is exactly how A and B came to differ from the chain.
  Verify live state with `pg_get_functiondef`, never with this folder.

## A. Status writes delegate instead of re-implementing (draft sections 3)

APPLIED LIVE, RECORDED AS `190_admin_order_status_delegation.sql`. Everything in
the table below is therefore in force today, not a forecast. Two of the gaps it
created are now closed by owner decision: `192_cashier_orders_cancel.sql` grants
the `cashier` the `orders.cancel` that 137 withheld, and
`195_admin_order_status_matrix.sql` plus the Dart `OrderStatusRules` narrowed the
status menus to the edges `orders.status_transitions` actually allows.

**Change.** `public.admin_update_order_status(uuid, text)` (145) writes
`orders.orders.status` directly. The draft makes it call
`orders.update_order_status(...)` (079) and, for `cancelled`,
`orders.cancel_order(...)` (107).

**Impact analysis.**

| Area | Effect |
| --- | --- |
| Transition matrix | Becomes authoritative. A status the admin menu offers but `orders.status_transitions` forbids (e.g. `ready → pending`, `completed → preparing`) starts raising instead of writing. |
| History & audit | New rows in `orders.order_status_history` and `identity.audit` for every admin change — today there are none. |
| Timestamps | `completed_at` / `cancelled_at` get set by 079/107 instead of staying null. |
| Cancellation rights | `orders.cancel_order` demands `orders.cancel`. The cashier role has `orders.status.update` but **not** `orders.cancel` (137:93), so cashiers lose cancel-on-orders-page. |
| Inventory & loyalty | Cancel now restocks and claws back loyalty (107:110-143) — a real behaviour change on live orders. |
| UI | `lib/features/orders/presentation/models/order_edit_rules.dart` and the status menu must be compared against the seeded matrix; a rejected transition needs an honest message, not a spinner. |

**Decision the owner must write down.** Which transitions the admin may perform,
and whether cashier keeps cancellation (grant `orders.cancel` or drop the action
from that role's UI).

**Tests still required.** SQL: each allowed and each forbidden transition, as the
real `authenticated` role; a cross-branch order id must be refused; cancel by
cashier must fail with `42501` until decided. Dart: the status menu shows only
matrix-allowed targets, and a refused transition surfaces its message
(`test/order_detail_layout_test.dart` pattern).

## B. Item edits: branch guard, effective price, invoice totals (draft section 4)

APPLIED LIVE, RECORDED AS `191_admin_order_item_effective_price_and_totals.sql`,
which also brings `admin_recompute_order_totals(uuid)` into the chain — it had
never existed in any migration file, only in the live database, and it stays
private there: `authenticated` holds no execute grant, so a client can reach it
only through the two item RPCs.

**Change.** `admin_add_order_item` / `admin_remove_order_item` (146, guarded by
154) get a `can_manage_branch` guard, price new lines with
`catalog.resolve_effective_price(branch, product)` (175:219) instead of
`catalog.products.base_price`, and recompute totals through a private
`admin_recompute_order_totals(uuid)` so `ck_orders_total` (011:113) keeps
holding.

**Impact analysis.**

- Today any add/remove on an order with `delivery_fee > 0` or a coupon violates
  `ck_orders_total` and fails with a generic error — the fix changes failures
  into successful writes, which is a behaviour change on its own.
- A line added at the effective price can differ from the customer's quote;
  `discount_total` stays capped (`ck_orders_discount_capped`) but **the coupon is
  not re-validated**.
- `delivery_fee` is left as the zone priced it, so an added line can push a
  delivery order over a zone minimum it was never checked against.
- The totals helper reads `core.brands` for `tax_rate` / `tax_included` with
  `limit 1`; multi-brand data would need a real join.
- **Inventory is deliberately untouched**: no deduct on add, no restore on
  remove. That is topic C.

**Decision required.** Re-price the zone and re-validate the coupon on an item
edit, or forbid item edits on delivery/coupon orders entirely. **DECIDED
2026-10-27:** the zone is re-asked at the new subtotal (`200`), the coupon keeps
the discount the customer earned and stays capped, and `min_order_amount` is not
re-enforced — it is an acceptance rule at checkout (134:298), and refusing the
edit would strand the admin with an order they can neither shrink nor leave.

**Tests still required.** SQL: add/remove on an order with fee + coupon keeps
`round(subtotal − discount + delivery + tax, 2) = grand_total`; cross-branch
write refused; a discounted product lands at the effective price with
`product_discount_total` outside `line_total` (134). Dart: existing
`test/order_items_list_test.dart` confirmation flow must keep passing.

## C. Inventory and loyalty on admin item edits

DECIDED 2026-10-27 AND APPLIED AS
[`../migrations/200_admin_order_item_stock_and_delivery_fee.sql`](../migrations/200_admin_order_item_stock_and_delivery_fee.sql).
An admin line edit moves stock: `admin_add_order_item` locks the branch's stock
row, refuses a quantity the shelf cannot cover with 167's rule, message and
errcode, deducts, and writes the order's single aggregated `sale` movement
(`uq_movement_sale_once` forbids a second row for the same product);
`admin_remove_order_item` returns exactly what that ledger says this order took
and **shrinks** the sale row instead of adding a `return` row, because
`107:110-143` restocks from `sum(sale movements)` and a stale row would hand the
same units back twice on a later cancellation. A product with no `branch_stock`
row is priced and written but never enters the ledger, so nothing is restocked
that was never taken.

Loyalty is deliberately **not** recalculated. Points were awarded for what the
customer actually paid at checkout; editing an invoice after the fact is not an
earn event, and 107 already claws the points back when the order is cancelled.

Verified by [`../tests/admin_order_item_stock_and_fee_test.sql`](../tests/admin_order_item_stock_and_fee_test.sql),
which is what caught the first draft's two bugs: the aggregate widened by
subtraction, and a phantom movement for an unstocked product.

## D. Subscription tenders and branch scope

DECIDED 2026-10-27 IN THE OTHER DIRECTION, AND ALREADY LIVE. The deployed
`public.admin_payments()` filters with a bare `where
identity.can_manage_branch(o.branch_id)`, which `186_admin_orders_payments_branch_scope.sql`
now reproduces: a tender with no order belongs to no branch
(075:10-22, and `subscriptions.subscriptions` has no branch column), so only
staff whose `staff_roles.branch_id` is NULL see it. The owner kept that, because
the alternative would hand `card_holder_name`, `card_brand` and `card_last4` of
every subscription buyer in the company to any branch cashier. `supabase/tests/
admin_orders_branch_scope_test.sql` locks both halves of that behaviour (cases 2,
3, 4 and 9).

Still open if it is ever revisited: hiding them means the payments page of a
branch cashier cannot show subscription revenue at all, and no per-branch
subscription model exists. Note when reading the matrix: `branch_manager` does
not hold `payments.read` in `137_reference_data.sql` (only `cashier`, `manager`
and `owner` do), so a branch manager never reaches this RPC today.

## E. Shift sales block and cancelled orders (182 hunk 1)

Draft:
[`182_pos_shift_report_and_drawer.PROPOSED.sql`](182_pos_shift_report_and_drawer.PROPOSED.sql).
`payments.pos_shift_totals` counts captured `pos_counter` tenders for cash and
card, but sums `grand_total` and `count(*)` over **every** order of the shift.
Verified live: a paid counter order cannot be cancelled (107 refuses it, and the
deployed `admin_update_order_status` delegates to it), no tender is ever moved
out of `captured`, and `orders.orders` has SELECT-only RLS policies. So the
divergence is unreachable today and the hunk is a guard for the day a refund or
reversal path exists.

**Decision (approved).** Ship 182 as written; no SQL change is justified now. Add
the guard together with the refund or reversal feature that makes the divergence
reachable, so it arrives with the tests that can actually reach it. This is not a
bug to fix in isolation.

## F. A paid-out can brick a shift (182 hunk 2)

Was drafted in
[`182_pos_shift_report_and_drawer.PROPOSED.sql`](182_pos_shift_report_and_drawer.PROPOSED.sql);
the accepted text is the standalone
[`187_pos_shift_cash_out_guard.PROPOSED.sql`](187_pos_shift_cash_out_guard.PROPOSED.sql).
`admin_pos_record_cash_movement` validates only
`0 < amount <= 1000000`, while the table CHECKs `expected_cash >= 0` and the
close recomputes `opening_float + cash_sales + cash_in − cash_out`. A paid-out
bigger than the drawer therefore makes the shift **impossible to close**, and
the branch keeps an open drawer that nobody can end except by booking a
fictitious paid-in or editing `payments.pos_shifts` by hand. The Dart maps the
resulting 23514 to the generic `PosShiftFailure.invalid`.

**Decision (approved).** Reject the over-withdrawal at the movement RPC, with a
distinct Dart failure arm and string. Implemented locally: 187 raises
`cash out exceeds the drawer` under errcode `22023`, and
`PosShiftFailure.insufficientDrawerCash` plus `S.posShiftInsufficientDrawerCash`
render it. The two CHECKs and the Z maths stay exactly as 182 wrote them.
`187_pos_shift_cash_out_guard.sql` was promoted out of this folder and applied to
the development project, and the guard test in
`supabase/tests/pos_shift_cash_out_guard_test.sql` passes against it, so the new
arm can now fire.
