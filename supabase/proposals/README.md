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

## G. Cancelling an advance ignores the staff scope (213)

Draft:
[`213_hr_advance_cancel_staff_scope.PROPOSED.sql`](213_hr_advance_cancel_staff_scope.PROPOSED.sql).
**STATUS: created, not applied. Its behaviour test was run against the live
project on 2026-10-31 inside one rolled-back transaction and passed — so the
guard is proven, and the live function is still the unpatched 212 one.**

`admin_hr_cancel_advance` (212:4490-4547) is the only one of the three advance
money RPCs that never calls `hr.assert_staff_access`: review asserts it at
212:4371 and disburse at 212:4459. `identity.has_permission('hr.finance.adjust')`
is a boolean and 212:5782 grants it to `branch_manager`, whose authority is one
branch, so a branch's finance holder can cancel an advance that belongs to a
staff member of another branch. `admin_hr_advances` already hides those rows from
them (212:4283-4292, 4327), so the write is reachable only by a caller that
obtained the id out of band — and `security definer` with no policy on
`hr.salary_advances` means the in-function checks are the only isolation there is.

The draft adds one statement and changes nothing else. Its behaviour test,
[`../tests/hr_advance_cancel_scope_test.sql`](../tests/hr_advance_cancel_scope_test.sql),
was executed on 2026-10-31 with the 213 function applied in the same transaction
and rolled back; it asserted the guard fires, that the refusal writes nothing, that
the guard runs **after** the existing money refusals, and that self-cancels,
in-scope cancels and global scopes still work. Running it also caught a defect in
the test itself (section 6 inherited branch 1's JWT claims and so was refused by
the very guard it was checking), which is now fixed in the file.

## H. Any staff member can read every coupon redemption (214)

Draft:
[`214_coupon_redemptions_branch_scope.PROPOSED.sql`](214_coupon_redemptions_branch_scope.PROPOSED.sql).
**STATUS: created, not applied. Its behaviour test was run against the live
project on 2026-10-31 inside one rolled-back transaction and passed — the live
policy is still 022's permission-only predicate, which is the leak itself.**

`coupon_redemptions_select_staff` (022:80-82) is `identity.has_permission('orders.read')`
and nothing more. `orders.read` is a permission, not a scope: 137 gives it to
cashier, staff, branch_manager and manager, and `public.coupon_redemptions` is a
`security_invoker` view (032:117-118) granted to `authenticated` (032:224-227).
So a cashier token can list every customer, order id and discount amount in the
company. 021 gave the two other child tables of `orders.orders` the branch half
of the predicate (021:103-113, 021:114-123) and 186 the same isolation for the
admin RPCs; this table was left out.

The draft replaces that one policy with the 021 shape. The owner is accepting a
visible narrowing: a branch manager or cashier sees fewer rows than today, and
only a NULL-branch role row keeps the company-wide read. `coupon_redemptions_select_own`
(022:76-78) is untouched, so a customer still reads their own rows, and the
coupons screen is unaffected because 168's aggregates are definer behind
`settings.write`. Test:
[`../tests/coupon_redemptions_branch_scope_test.sql`](../tests/coupon_redemptions_branch_scope_test.sql),
executed on 2026-10-31 with the 214 policy in the same rolled-back transaction. It
also caught a defect in the test itself (section 8a asked for the metrics while the
claims still carried a branch manager, so it got the settings.write refusal), which
is now fixed in the file.

Still separate, and deliberately not bundled here: whether
`coupons_public_read` (022:58-60) should let anon read the coupon rows and their
limits at all. That is a money and marketing decision for the owner, not a scope
bug.

## I. Five admin directories have no bound at all (215)

Draft:
[`215_admin_directory_pagination.PROPOSED.sql`](215_admin_directory_pagination.PROPOSED.sql).
**STATUS: created, not applied. Its behaviour test was run against the live project
on 2026-10-31 inside one rolled-back transaction that also applied the five
definitions, and it reached the end with no assertion failed; a fresh session after
the rollback found all five signatures back to [no arguments] and every fixture row
gone.**

`admin_orders()`, `admin_payments()`, `admin_customers()`, `admin_reviews()` and
`admin_abandoned_carts()` take no parameters. Verified live, not inferred:
`pg_get_function_identity_arguments` is the empty string for all five and their
bodies contain no `limit`, while the one directory that does paginate,
`admin_catalog_snapshot(p_branch_id, p_limit, p_offset, p_search)`, reports all four
arguments. The admin app calls the five with nothing, so every page load, every
realtime refresh and every search keystroke serialises the whole matching result set
of the deployment into one JSON value. That is a capacity wall at real volume.

The draft copies 122's shape onto all five: `p_limit`/`p_offset` defaulting to null,
the match count taken BEFORE the cut, the rows cut in a subselect and only then
aggregated, and the answer wrapped in `{rows,total}`. A caller that passes nothing
keeps receiving everything, which is the only reason the Dart does not fail to
compile. It is NOT the reason the Dart keeps working: all five admin repositories test
`response is List`, so against these definitions they read an empty page and print an
empty table over a populated one. The pair is the decision — this file plus the
repository change — and the Dart was deliberately not touched here.

**The drift this surfaced.** 211 reached the live database with two of its three
sections: `admin_abandoned_carts()` carries its branch predicate and
`admin_update_payment_status()` carries its not-found and cross-branch refusals, but
the live `admin_payments()` is still 186's body, so POS walk-in tenders print no
customer name. Measured with the test's own fixtures: the live answer gives that
tender `customer_name = NULL`, the 215 body gives it `'DP Walk In'`. Because 215 is
written on the CHAIN body, applying it reinstates 211 §3 as a side effect; the owner
may instead repair that drift first and re-read the live body — either order lands
the same text.

Test: [`../tests/admin_directory_pagination_test.sql`](../tests/admin_directory_pagination_test.sql).
It walks each directory page by page and compares the concatenation with the
unbounded answer, so a skipped, repeated or re-ordered row fails the run; it re-asserts
186's 31 order keys and 20 payment keys inside the envelope; and it re-runs every guard
with its own message. Two files written against the bare array break with 215 and belong
to the same release: `admin_orders_branch_scope_test.sql` and
`admin_scope_and_write_guards_test.sql`.

Still separate, and deliberately not bundled here: server-side search, status and date
filters for `admin_orders()`, and a count RPC for the dashboard and the export that
today compute over the whole Dart list.

## J. Two trigger functions are still advertised to PUBLIC (216)

Draft:
[`216_trigger_function_grants.PROPOSED.sql`](216_trigger_function_grants.PROPOSED.sql).
**STATUS: created, not applied. Its behaviour test was run against the live project
on 2026-10-31 inside one rolled-back transaction that also ran the four REVOKEs, and
it reached the end with no assertion failed; a fresh session after the rollback found
both ACLs back to `=X/postgres,…`, `anon_can_execute` true again, the two COMMENTs
back to 188's text and no fixture row anywhere.**

188 ends with two GRANTs and no REVOKE, so the two trigger functions it created
carry the default grant to PUBLIC: the live ACL of both begins `=X/postgres` and
`has_function_privilege('anon', …, 'execute')` is true for both. That is exactly the
state 081:14-15 exists to prevent — `revoke execute on all functions in schema
identity from public; … from anon;` — and 081 runs at 081, long before 188 created
anything. 105_grants_hardening.sql:5-15 documented the same sequence for
marketing's two coupon helpers and repaired it one REVOKE per function. This is that
repair, for the pair 188 added.

The scope was measured, not assumed: 29 functions across the application schemas are
executable by `anon`, almost all of them the legitimate public-read RPCs, and exactly
two of the 29 are trigger functions — these two. So 216 is a two-name fix inside a
class that should be empty, not a sweep.

**This closes a contract, not an exploit, and the draft says so.** Three layers
already refused an outside caller, all three measured: a direct call by `anon` answers
`0A000 trigger functions can only be called as triggers` (and with 216 applied the same
call answers `42501` — Postgres reads the function ACL before it complains about trigger
context, so the refusal changes shape while remaining a refusal); PostgREST does not
expose the `identity` schema at all, so `/rest/v1/rpc/reject_customer_profile_for_staff`
returns the same 404 "not in the schema cache" as a name that does not exist, while an
exposed function answers on its own terms (`/rest/v1/rpc/admin_orders` gives `401
permission denied for function admin_orders` for the same anon key); and neither trigger
has anything to do for `anon` or `service_role`, because neither role holds INSERT or
UPDATE on `identity.profiles` or `identity.staff_members`. What remains is the artifact:
`pg_proc` advertising EXECUTE to PUBLIC on two SECURITY DEFINER functions that modify
the customer table, which every future privilege review has to re-litigate.

Test: [`../tests/trigger_function_grants_test.sql`](../tests/trigger_function_grants_test.sql).
The part worth naming is section 5c: `authenticated` is the one non-owner role with a
write on `identity.profiles` (profiles_insert_own / profiles_update_own), so it is the
role that really fires `trg_profile_not_staff`, and its own INSERT for a staff uid
answered `23514` — the trigger's refusal, not a privilege error — with the REVOKEs
already applied. 5d is its mirror: a plain customer's profile edit still goes through,
and 5b/5e keep 188's drop and order-history guards firing. Section 4 asserts the
whole-schema invariant rather than two names, so the next migration that creates an
identity function without a REVOKE fails it too.

Still separate, and deliberately not bundled here: whether `authenticated` needs
EXECUTE on a function it can only ever reach through a trigger at all. 188 granted it
and nothing in that file explains why; narrowing it further has a real blast radius,
and it belongs in its own decision.

## K. "Make this card my default" calls a function that was never deployed (223)

Draft: [`223_public_bridge_set_default_card.PROPOSED.sql`](223_public_bridge_set_default_card.PROPOSED.sql).
**STATUS: created, not applied. Nothing here was rehearsed in the SQL Editor — this
session has no authorized path to run SQL on the live project; the evidence below is
from the migrations chain and from anonymous HTTPS requests against the live PostgREST
endpoint.**

`SupabaseSavedCardsRepository.setDefaultCard()` invoked an Edge Function named
`set_default_card`. `supabase/functions/` has no such function — the Tap family is
`tap-create-charge`, `tap-tokenize-card`, `tap-verify-charge`, `tap-refund`,
`tap-delete-card`, `tap-webhook` — so the only possible answer is 404, and the rule
could never run on any device. The app's own data is not the problem: the rule exists
and is correct, in `payments.set_default_card(p_card_id uuid)` (073), which takes a
per-customer advisory lock, re-checks ownership and keeps the one-default invariant in
one transaction. It is simply unreachable, because PostgREST does not expose the
`payments` schema.

The client has no legal way to do it itself, and both layers were checked rather than
assumed: `public.saved_cards` is SELECT-only for `authenticated` (063 + 105) and an
anon read of it answers live `401 {"code":"42501","message":"permission denied for
view saved_cards"}` (`GET /rest/v1/saved_cards?select=id&limit=1`), and
`payments.saved_cards` has the single `saved_cards_select_own` policy (062). So the
fix is the bridge wrapper this repo already uses for every other domain RPC (035, 063,
074, 078) — `security invoker`, so `auth.uid()` inside 073 still sees the customer,
`usage on schema payments` already granted by 023 — with EXECUTE for `authenticated`
and an explicit revoke from `anon` and `public`, the same shape 216 restores elsewhere.

The Dart side now calls `_client.rpc('set_default_card', …)` and the doc-comment names
073 as the owner of the rule. Until this draft is applied, that RPC answers 404 live —
verified with the exact signature, `POST /rest/v1/rpc/set_default_card` with
`{"p_card_id": …}` gives `PGRST202 Could not find the function
public.set_default_card(p_card_id) in the schema cache`, whereas a name that exists but
is refused for the role answers 401/42501 (`my_subscription` does, on the same key) —
so the button keeps failing, with a different and more accurate error than the 404 it
used to get from the missing Edge Function. Applying 223 is what closes it; the app
needs no further change.
