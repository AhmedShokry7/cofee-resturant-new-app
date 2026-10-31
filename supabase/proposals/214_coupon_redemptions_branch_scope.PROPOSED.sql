-- 214-PROPOSED: coupon redemptions must be readable only inside the branch.
--
-- NOTHING HERE HAS BEEN EXECUTED. This file is a proposal kept in
-- supabase/proposals/. It is not applied to the live project and it is not part
-- of the migration chain until the owner copies it out with its own number and
-- repairs it into the ledger (`supabase migration repair`, never `db push`).
-- Applying it is an owner action in the SQL Editor.
--
-- ONE TOPIC, ONE DECISION
--   It replaces exactly one RLS policy:
--   marketing.coupon_redemptions -> coupon_redemptions_select_staff.
--   No table, no column, no constraint, no index, no grant, no function, no
--   other policy.
--
-- WHY A SEPARATE FILE AND NOT AN EDIT TO 022
--   022 is part of the recorded chain and rebuilding from scratch must keep
--   producing the state the owner reviewed. The chain already carries later
--   deltas for earlier objects (190, 191, 195, 200 all restate 145/146/079
--   bodies), so a new number is the established way to change one object.
--
-- WHY 214 IS A PROPOSAL NUMBER AND NOT A CLAIM
--   The chain runs to 212 and 213 is already taken by the other proposal in this
--   folder, so 214 is the next free number locally — the only thing assertable
--   without touching the database. Verify live state before deciding:
--     select pol.polname,
--            pg_get_expr(pol.polqual, pol.polrelid) as using_expr
--       from pg_policy pol
--       join pg_class c on c.oid = pol.polrelid
--       join pg_namespace n on n.oid = c.relnamespace
--      where n.nspname = 'marketing' and c.relname = 'coupon_redemptions';
--   If the live predicate already carries can_manage_branch, the live database
--   was patched out of band and the chain needs the repair instead.
--
-- THE DEFECT (read from the text of 022, 021, 032 and 137; no query was run)
--   022:80-82 is the whole staff predicate:
--     using (identity.has_permission('orders.read'))
--   `orders.read` is a permission, not a scope. 137:88-93 gives it to cashier,
--   137:80-86 to staff, to branch_manager, and to manager. So today any of them
--   reads EVERY redemption row in the company:
--     select id, coupon_id, user_id, order_id, amount from public.coupon_redemptions
--   That view exists and is granted: 032:117-118 makes it a security_invoker
--   view over marketing.coupon_redemptions (so the table's RLS decides the rows,
--   exactly as intended) and the grant list ending at 032:227 gives authenticated
--   SELECT on it, while 032:230-238 revokes it from anon. A PostgREST call with a
--   cashier token reaches it; no Dart screen needs to.
--   Each row names a customer (user_id), the order that carried the discount
--   (order_id) and the money the discount cost (amount). Across branches, that
--   is a competitor's promotion performance handed to every cashier in every
--   branch.
--
--   The chain already decided this once, two files earlier, for the two tables
--   of the same shape:
--     021:103-113 order_status_history_select_staff
--     021:114-123 order_events_select_staff
--   Both read `identity.has_permission('orders.read') AND exists (select 1 from
--   orders.orders o where o.id = <child>.order_id and
--   identity.can_manage_branch(o.branch_id))`. coupon_redemptions is a child of
--   orders by order_id and was simply not given the second half. 186 then applied
--   the same isolation to the admin RPCs over orders and payments.
--
--   Verified before writing, so the change cannot hide every row by accident:
--     * marketing.coupon_redemptions.order_id is `not null references
--       orders.orders(id) on delete cascade` (015:109-116). A redemption cannot
--       outlive its order, so the EXISTS can only be false for a row whose
--       branch the caller does not manage — never because the order is missing.
--     * coupon_redemptions_select_own (022:76-78) is a second, permissive policy
--       on the same table for the same role. Postgres unions permissive SELECT
--       policies, so a customer keeps reading their own rows whatever this does.
--     * No Dart screen reads the table. The coupons page is served by the
--       admin_coupon_* definer RPCs of 168, which read it inside their own
--       bodies. So the policy change moves no row off any existing screen.
--
-- THE FIX
--   The 021 shape, verbatim, on this table. Same helper, same permission code,
--   same EXISTS-through-orders pattern, same policy name so nothing else that
--   references it has to change.
--
-- WHO IS AFFECTED — AND WHAT THE OWNER IS ACCEPTING
--   * owner and manager (NULL-branch role rows): unchanged.
--     identity.can_manage_branch() is true for a global scope.
--   * branch_manager and staff of one branch: keep the redemptions of orders
--     placed in their own branches and lose the rest. They see FEWER ROWS than
--     today. That is the point of the change and the only cost: a branch manager
--     can no longer read another branch's discount usage from the table.
--   * cashier: same narrowing, on a role that today can read everything.
--   * a staff member who is also a customer: unchanged for their own rows, which
--     coupon_redemptions_select_own still returns.
--   * anon: unchanged — 032 grants nothing to anon on this view.
--   * the coupons screen and every admin_coupon_* RPC: unchanged, they are
--     security definer behind settings.write (168:19-29, 101-113, 173-183).
--
-- WHAT THIS DELIBERATELY DOES NOT TOUCH
--   * coupons_public_read (022:58-60) lets anon read every active coupon row
--     including usage_limit and per_user_limit. That is a money and marketing
--     call for the owner, not a scope bug, and it stays a separate decision.
--   * The admin_coupon_* aggregates are company-wide by design and are bounded
--     only by their own limits; scoping them is the open item on unbounded admin
--     RPCs, not this file.
--   * There is no INSERT/UPDATE/DELETE policy on this table and this file adds
--     none: redemptions are written by the place-order functions only.
--
-- WHAT BREAKS IF THIS IS WRONG
--   The predicate is a SELECT-only restriction, so the worst outcome is a row
--   that disappears from a staff read. Nothing can be written incorrectly, no
--   money moves, and no RPC changes behaviour. If the owner dislikes the result,
--   re-running 022 restores the old policy byte-for-byte.
--   The failure mode to watch is the opposite of a leak: a branch manager who
--   legitimately needs the company-wide view for a promotion review would have to
--   use the coupons screen (168, company-wide) or be given a NULL-branch role
--   row. That is a role decision, and it is why this file changes one policy and
--   not the seeded matrix.
--
-- COMPANIONS
--   supabase/tests/coupon_redemptions_branch_scope_test.sql — behaviour test,
--   EXECUTED AND PASSED on 2026-10-31 with this policy in the same rolled-back
--   transaction; the live policy is still 022's, so this file stays unapplied.
--   No Dart change: the table is not read by any screen.

-- -----------------------------------------------------------------------------
-- marketing.coupon_redemptions: the branch scope 021 gave its two sibling tables.
-- -----------------------------------------------------------------------------
drop policy if exists coupon_redemptions_select_staff on marketing.coupon_redemptions;

create policy coupon_redemptions_select_staff on marketing.coupon_redemptions
  for select to authenticated
  using (
    identity.has_permission('orders.read')
    and exists (
      select 1 from orders.orders o
      where o.id = coupon_redemptions.order_id
        and identity.can_manage_branch(o.branch_id)
    )
  );

comment on policy coupon_redemptions_select_staff on marketing.coupon_redemptions is
  'Staff read a coupon redemption only when they manage the branch of the order '
  'that carried it. Same shape as order_status_history_select_staff and '
  'order_events_select_staff in 021; orders.read alone was never a scope.';

-- -----------------------------------------------------------------------------
-- READ-ONLY PRE-FLIGHT, run this in the SQL Editor BEFORE pasting anything above
-- -----------------------------------------------------------------------------
-- 1) The live shape of both policies on the table, with the exact predicate text.
-- select pol.polname, pol.permissive,
--        pg_get_expr(pol.polqual, pol.polrelid) as using_expr
--   from pg_policy pol
--   join pg_class c on c.oid = pol.polrelid
--   join pg_namespace n on n.oid = c.relnamespace
--  where n.nspname = 'marketing' and c.relname = 'coupon_redemptions';
--
-- 2) How many rows each branch manager would lose. Zero rows means the guard is
--    being added as a fence rather than closing a live exposure — say so in the
--    decision instead of calling it a repaired leak.
-- select o.branch_id, count(*) as redemption_rows,
--        sum(r.amount) as discount_given
--   from marketing.coupon_redemptions r
--   join orders.orders o on o.id = r.order_id
--  group by o.branch_id
--  order by o.branch_id;
--
-- 3) Does any staff member hold orders.read on a branch-scoped role row only?
--    Those are the accounts whose reads change.
-- select sr.branch_id, r.code as role_code, count(distinct sr.staff_id) as staff
--   from identity.staff_roles sr
--   join identity.roles r on r.id = sr.role_id
--   join identity.role_permissions rp on rp.role_id = r.id
--   join identity.permissions p on p.id = rp.id
--  where p.code = 'orders.read'
--  group by sr.branch_id, r.code
--  order by sr.branch_id;
--
-- 4) Rehearsal in a transaction that can never commit, the same discipline as
--    supabase/tests/*.sql. Put the SQL above between these lines, run the file,
--    and the final ROLLBACK removes the policy change with the fixtures.
-- begin;
-- ...
-- rollback;
