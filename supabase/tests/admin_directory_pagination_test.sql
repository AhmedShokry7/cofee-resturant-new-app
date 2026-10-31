-- admin_directory_pagination_test.sql
-- Behaviour test for 215_admin_directory_pagination.PROPOSED.sql: the five admin
-- directory RPCs (admin_orders, admin_payments, admin_customers, admin_reviews,
-- admin_abandoned_carts) answer in pages inside a {rows,total} envelope.
--
-- STATUS: EXECUTED AND PASSED on 2026-10-31 against the live project
-- webzzasosevzymftgszn, inside one transaction that also applied the 215 function
-- replacements and then rolled both back. The report row came back as:
--   verdict = 'reached the end: no assertion failed',
--   functions_with_two_arguments = 5,
--   fixture_counts_orders_tenders_carts_customers_reviews = '7/3/3/6/4'
-- The residue check in a fresh session found 0 functions still carrying an
-- argument (all five back to [no arguments]), 0 fixture branches, 0 fixture
-- orders, carts, tenders, reviews and staff rows, and no helper function left in
-- pg_temp or public — so 215 remains a proposal, not a deployed change.
--
-- CONTROL RUN (the same fixtures, the same day, WITHOUT the 215 DDL): the live
-- project answered admin_orders with a bare JSON array of 7 rows, all five
-- signatures read [no arguments], and the POS walk-in tender's customer_name came
-- back NULL. Both readings are quoted in 215's header: the array is what the
-- pagination replaces, and the NULL is the 211 §3 half of the drift that 215
-- carries because it is written on top of the chain body.
--
-- Two defects were found by running it, both in this file rather than in 215:
-- the p_limit 3 check had been left attached to the no-argument call, and the
-- global-manager ordering check compared an absolute first row, which only holds
-- on an empty table — it now states the order relatively, so real rows cannot
-- break it.
--
-- Keep the discipline of hr_advance_cancel_scope_test.sql: one transaction, every
-- fixture destroyed by the final rollback, and the report row recorded here so the
-- next reader knows what was actually observed.
--
-- ONE ASSERTION IS NOT ABOUT 215.
--   Section 6 asserts that a POS walk-in tender prints the POS customer's name.
--   That is 211 §3. The live project on 2026-10-31 still runs 186's payments body,
--   where customer_name is p.full_name alone and the pos_customers join is absent.
--   Against the unpatched project this file cannot even reach that assertion — it
--   dies at section 1 — so the control run recorded in the STATUS block above
--   measures the same fixture tender directly and reads NULL. The assertion stays
--   here because 215 is written on top of the CHAIN body and therefore reinstates
--   211 §3: with 215 applied it reads 'DP Walk In'.
--
-- RUN ONLY AGAINST AN ISOLATED, NON-PRODUCTION DATABASE (or the rehearsal
-- transaction above). Several assertions call each directory with no limit to
-- build the reference order, so on a database with real volume they read the
-- whole table — which is precisely the pre-215 behaviour this file exists to
-- retire, and the reason it is not a production health check.
--
-- Plain SQL for the Supabase SQL Editor or psql. Every call runs as the real
-- authenticated (or anon) role with real JWT claims, so the guards are executed
-- rather than described. All fixtures die in the final rollback, together with
-- the two pg_temp helpers and the 215 definitions.
--
-- PREREQUISITES: 004/013/123/137 (identity, the RBAC helpers, the role matrix),
-- 007/011/016 (catalog, orders, engagement), 074/075 (payments), 080
-- (customers.read), 160 (admin_customers), 169 (admin_reviews), 176
-- (pos_customers), 186 (branch scope), 188 (staff/customer separation), 211 and
-- the 215 bodies of the five directories.
--
-- WHAT THIS PROVES, IN ORDER
--   1  the API shape: exactly one function per name, identity arguments of
--      "p_limit integer, p_offset integer", the zero-argument signature gone so
--      PostgREST has no overload to resolve, and the execute grant moved onto the
--      new signature (anon refused, authenticated allowed)
--   2  the envelope is exactly {rows,total}, rows is always an array, and the
--      whole set still answers when no limit is passed
--   3  total is counted before the cut: for every directory, pages of a bounded
--      size are disjoint, complete, and in the SAME order as the unbounded call;
--      total never moves between pages; a page past the end is empty while total
--      still prints the whole count
--   4  p_limit null / 0 / negative all mean "no limit" (122's contract), a
--      negative p_offset clamps to the first row, and the zero-argument CALL —
--      what the current Dart sends — still returns everything through the defaults
--   5  the row shape did not change: the same 31 order keys, 20 payment keys,
--      15 customer keys, 13 review keys (plus the 7 and 5 nested), 13 cart keys
--      and the nested item keys, with the same value types
--   6  the joins and aggregates survived the page subselect: line items, the
--      coalesced customer name, the POS walk-in name on its tender, the method
--      code, the per-customer order totals, the nested product/customer objects,
--      the per-cart line sum and item array
--   7  branch scope is unchanged: no other branch's row appears in any page, the
--      tender of no order stays invisible to a branch-scoped caller, and the
--      global caller still sees both branches and that tender
--   8  the filters that were already there are still there: the carts status
--      filter excludes 'converted', admin_customers still excludes staff accounts
--   9  every guard still fires with its own message: 'not authenticated' for a
--      customer and for an invited staff member, 'missing permission: …' for the
--      role that does not hold it, and 42501 for anon on all five
--  10 an empty scope still answers rows [] with total 0, never null
--
-- WHAT IS NOT TESTED HERE
--   p_search / status / date filters — 215 deliberately adds none. Nor the Dart
--   half: all five admin repositories still test `response is List`, so against
--   these definitions they read an empty page. That is 215's own disclosure and a
--   Dart change, not a SQL assertion. Nor the wall-clock cost of a page at volume.

begin;

-- ---------------------------------------------------------------------------
-- Fixtures: three branches (one empty), five customers, ten orders, five
-- tenders, five carts, four reviews, six staff members with six different
-- reaches. The uuid prefixes (3f/4a/4b/4c/4d/4e/4f/50/51/6a/7a/8a/8b) belong to
-- this file, so a scratch database can hold another rehearsal at the same time.
-- ---------------------------------------------------------------------------
insert into core.branches (id, brand_id, code, name_ar, name_en, address, is_active, settings)
values
  ('3f100000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000001', 'DP-B1', 'فرع الصفحات 1', 'Paging Branch 1', 'addr1', true, '{}'::jsonb),
  ('3f200000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000001', 'DP-B2', 'فرع الصفحات 2', 'Paging Branch 2', 'addr2', true, '{}'::jsonb),
  ('3f300000-0000-4000-8000-000000000003', '00000000-0000-4000-8000-000000000001', 'DP-B3', 'فرع الصفحات 3', 'Paging Branch 3', 'addr3', true, '{}'::jsonb);

insert into auth.users (id, email)
values
  ('4b100000-0000-4000-8000-000000000001', 'dp-cust-1@test.local'),
  ('4b100000-0000-4000-8000-000000000002', 'dp-cust-2@test.local'),
  ('4b100000-0000-4000-8000-000000000003', 'dp-cust-3@test.local'),
  ('4b100000-0000-4000-8000-000000000004', 'dp-cust-4@test.local'),
  ('4b100000-0000-4000-8000-000000000005', 'dp-cust-5@test.local'),
  ('4a100000-0000-4000-8000-000000000001', 'dp-b1-manager@test.local'),
  ('4a100000-0000-4000-8000-000000000002', 'dp-global@test.local'),
  ('4a100000-0000-4000-8000-000000000003', 'dp-cashier@test.local'),
  ('4a100000-0000-4000-8000-000000000004', 'dp-staff@test.local'),
  ('4a100000-0000-4000-8000-000000000005', 'dp-invited@test.local'),
  ('4a100000-0000-4000-8000-000000000006', 'dp-empty@test.local');

-- identity.handle_new_user already wrote a profile for every account above, so
-- the five customer rows are an upsert: the fixture names and the explicit
-- created_at are what the directory sorts by, and fixtures sharing one timestamp
-- could not be paged deterministically. 188 then removes the profile of any uid
-- that becomes staff, which is why no staff uid is ever inserted as a customer.
insert into identity.profiles (id, full_name, email, phone, language, created_at)
values
  ('4b100000-0000-4000-8000-000000000001', 'DP Cust One',   'dp-cust-1@test.local', '0500000101', 'ar', '2026-01-01T00:00:00Z'),
  ('4b100000-0000-4000-8000-000000000002', 'DP Cust Two',   'dp-cust-2@test.local', '0500000102', 'ar', '2026-01-02T00:00:00Z'),
  ('4b100000-0000-4000-8000-000000000003', 'DP Cust Three', 'dp-cust-3@test.local', '0500000103', 'ar', '2026-01-03T00:00:00Z'),
  ('4b100000-0000-4000-8000-000000000004', 'DP Cust Four',  'dp-cust-4@test.local', '0500000104', 'ar', '2026-01-04T00:00:00Z'),
  ('4b100000-0000-4000-8000-000000000005', 'DP Cust Five',  'dp-cust-5@test.local', '0500000105', 'ar', '2026-01-05T00:00:00Z')
on conflict (id) do update
  set full_name = excluded.full_name,
      phone     = excluded.phone,
      created_at = excluded.created_at;

insert into identity.staff_members (id, user_id, status, full_name, email)
values
  ('4c100000-0000-4000-8000-000000000001', '4a100000-0000-4000-8000-000000000001', 'active',  'DP B1 Manager',  'dp-b1-manager@test.local'),
  ('4c100000-0000-4000-8000-000000000002', '4a100000-0000-4000-8000-000000000002', 'active',  'DP Global',      'dp-global@test.local'),
  ('4c100000-0000-4000-8000-000000000003', '4a100000-0000-4000-8000-000000000003', 'active',  'DP Cashier',     'dp-cashier@test.local'),
  ('4c100000-0000-4000-8000-000000000004', '4a100000-0000-4000-8000-000000000004', 'active',  'DP Staff',       'dp-staff@test.local'),
  ('4c100000-0000-4000-8000-000000000005', '4a100000-0000-4000-8000-000000000005', 'invited', 'DP Invited',     'dp-invited@test.local'),
  ('4c100000-0000-4000-8000-000000000006', '4a100000-0000-4000-8000-000000000006', 'active',  'DP Empty Branch', 'dp-empty@test.local');

-- Six reaches. 'manager' is the only non-owner role that holds customers.read
-- (080:14-20) and reviews.moderate (137:65), so the branch-scoped page reader is
-- a manager whose role row names ONE branch: every permission, a bounded scope.
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '4c100000-0000-4000-8000-000000000001', r.id, '3f100000-0000-4000-8000-000000000001'::uuid
from identity.roles r where r.code = 'manager';

insert into identity.staff_roles (staff_id, role_id, branch_id)
select '4c100000-0000-4000-8000-000000000002', r.id, null
from identity.roles r where r.code = 'manager';

-- cashier: orders.read and payments.read, but neither customers.read nor
-- reviews.moderate (137:85-93) — the two permission-arm callers of section 9.
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '4c100000-0000-4000-8000-000000000003', r.id, '3f100000-0000-4000-8000-000000000001'::uuid
from identity.roles r where r.code = 'cashier';

-- staff: orders.read only, so admin_payments must refuse this caller.
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '4c100000-0000-4000-8000-000000000004', r.id, '3f100000-0000-4000-8000-000000000001'::uuid
from identity.roles r where r.code = 'staff';

-- invited, never activated: identity.is_staff() must refuse it.
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '4c100000-0000-4000-8000-000000000005', r.id, null
from identity.roles r where r.code = 'manager';

-- a branch holding no order, no tender and no cart: the empty-page caller.
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '4c100000-0000-4000-8000-000000000006', r.id, '3f300000-0000-4000-8000-000000000003'::uuid
from identity.roles r where r.code = 'cashier';

-- Catalog, because admin_reviews INNER JOINs products and categories.
insert into catalog.categories (id, name_ar, name_en, slug, sort_order, is_active)
values ('6a100000-0000-4000-8000-000000000001', 'قهوة الصفحات', 'Paging Coffee', 'dp-coffee', 1, true);

insert into catalog.products (id, category_id, sku, slug, name_ar, name_en, base_price, is_active)
values
  ('6a100000-0000-4000-8000-000000000011', '6a100000-0000-4000-8000-000000000001', 'DP-SKU-1', 'dp-flat-white', 'فلات وايت', 'Flat White', 25.00, true),
  ('6a100000-0000-4000-8000-000000000012', '6a100000-0000-4000-8000-000000000001', 'DP-SKU-2', 'dp-cold-brew',   'كولد برو',   'Cold Brew',  50.00, true);

-- One POS walk-in customer, so the payments name coalesce has something to say.
insert into orders.pos_customers (id, full_name, phone, created_by)
values ('50100000-0000-4000-8000-000000000001', 'DP Walk In', '0500000900', '4a100000-0000-4000-8000-000000000002');

-- A plan and a purchase: the tender that belongs to no order and therefore to no
-- branch, readable only by a role row carrying a null branch.
insert into subscriptions.plans (id, code, name_ar, name_en, price, currency_code)
values ('51100000-0000-4000-8000-000000000001', 'DP-PLAN', 'خطة الصفحات', 'DP plan', 99.00, 'SAR');

insert into subscriptions.subscriptions (id, user_id, plan_id, ends_at, idempotency_key)
values ('51100000-0000-4000-8000-000000000002', '4b100000-0000-4000-8000-000000000005',
        '51100000-0000-4000-8000-000000000001', '2026-12-31T00:00:00Z', 'dp-test-sub-1');

-- Seven orders in branch 1 (the newest of them is the POS walk-in, so its
-- user_id is null) and three in branch 2. placed_at is distinct on purpose: the
-- page order is asserted against it. 'pickup' everywhere except the POS order,
-- because 'delivery' would need a zone row (ck_orders_delivery_needs_zone).
insert into orders.orders (
  id, order_number, user_id, pos_customer_id, branch_id, fulfillment_type, order_source,
  status, payment_status, subtotal, discount_total, delivery_fee, tax_total, grand_total,
  currency_code, customer_note, placed_at, loyalty_points_earned, idempotency_key
)
values
  ('4d100000-0000-4000-8000-000000000001', 'DP-101', '4b100000-0000-4000-8000-000000000001', null,
   '3f100000-0000-4000-8000-000000000001', 'pickup', 'online', 'confirmed', 'paid',
   100.00, 0.00, 0.00, 0.00, 100.00, 'SAR', 'dp1', '2026-02-01T01:00:00Z', 0, 'dp-test-o1'),
  ('4d100000-0000-4000-8000-000000000002', 'DP-102', '4b100000-0000-4000-8000-000000000001', null,
   '3f100000-0000-4000-8000-000000000001', 'pickup', 'online', 'confirmed', 'paid',
   50.00, 0.00, 0.00, 0.00, 50.00, 'SAR', 'dp2', '2026-02-01T02:00:00Z', 0, 'dp-test-o2'),
  ('4d100000-0000-4000-8000-000000000003', 'DP-103', '4b100000-0000-4000-8000-000000000002', null,
   '3f100000-0000-4000-8000-000000000001', 'pickup', 'online', 'confirmed', 'paid',
   30.00, 0.00, 0.00, 0.00, 30.00, 'SAR', 'dp3', '2026-02-01T03:00:00Z', 0, 'dp-test-o3'),
  ('4d100000-0000-4000-8000-000000000004', 'DP-104', '4b100000-0000-4000-8000-000000000003', null,
   '3f100000-0000-4000-8000-000000000001', 'pickup', 'online', 'confirmed', 'unpaid',
   25.00, 0.00, 0.00, 0.00, 25.00, 'SAR', 'dp4', '2026-02-01T04:00:00Z', 0, 'dp-test-o4'),
  ('4d100000-0000-4000-8000-000000000005', 'DP-105', '4b100000-0000-4000-8000-000000000004', null,
   '3f100000-0000-4000-8000-000000000001', 'pickup', 'online', 'confirmed', 'unpaid',
   20.00, 0.00, 0.00, 0.00, 20.00, 'SAR', 'dp5', '2026-02-01T05:00:00Z', 0, 'dp-test-o5'),
  ('4d100000-0000-4000-8000-000000000006', 'DP-106', '4b100000-0000-4000-8000-000000000005', null,
   '3f100000-0000-4000-8000-000000000001', 'pickup', 'online', 'confirmed', 'unpaid',
   15.00, 0.00, 0.00, 0.00, 15.00, 'SAR', 'dp6', '2026-02-01T06:00:00Z', 0, 'dp-test-o6'),
  ('4d100000-0000-4000-8000-000000000007', 'DP-107', null, '50100000-0000-4000-8000-000000000001',
   '3f100000-0000-4000-8000-000000000001', 'dine_in', 'pos', 'confirmed', 'paid',
   45.00, 0.00, 0.00, 0.00, 45.00, 'SAR', 'dp7', '2026-02-01T07:00:00Z', 0, 'dp-test-o7'),
  ('4d200000-0000-4000-8000-000000000008', 'DP-201', '4b100000-0000-4000-8000-000000000002', null,
   '3f200000-0000-4000-8000-000000000002', 'pickup', 'online', 'confirmed', 'paid',
   60.00, 0.00, 0.00, 0.00, 60.00, 'SAR', 'dp8', '2026-02-01T08:00:00Z', 0, 'dp-test-o8'),
  ('4d200000-0000-4000-8000-000000000009', 'DP-202', '4b100000-0000-4000-8000-000000000003', null,
   '3f200000-0000-4000-8000-000000000002', 'pickup', 'online', 'confirmed', 'unpaid',
   70.00, 0.00, 0.00, 0.00, 70.00, 'SAR', 'dp9', '2026-02-01T09:00:00Z', 0, 'dp-test-o9'),
  ('4d200000-0000-4000-8000-000000000010', 'DP-203', '4b100000-0000-4000-8000-000000000004', null,
   '3f200000-0000-4000-8000-000000000002', 'pickup', 'online', 'confirmed', 'unpaid',
   80.00, 0.00, 0.00, 0.00, 80.00, 'SAR', 'dp10', '2026-02-01T10:00:00Z', 0, 'dp-test-o10');

-- Two lines on the newest branch-1 order and one on an older one. The nested
-- items array is a correlated subselect per row, so it is the part of the
-- aggregate most likely to break when the rows move into a page subselect.
insert into orders.order_items (
  id, order_id, product_id, product_name_ar, product_name_en, sku_snapshot,
  image_snapshot, unit_price, quantity, line_total, created_at
)
values
  ('4e100000-0000-4000-8000-000000000001', '4d100000-0000-4000-8000-000000000007',
   '6a100000-0000-4000-8000-000000000011', 'فلات وايت', 'Flat White', 'DP-SKU-1', null,
   25.00, 2, 50.00, '2026-02-01T07:00:00Z'),
  ('4e100000-0000-4000-8000-000000000002', '4d100000-0000-4000-8000-000000000007',
   '6a100000-0000-4000-8000-000000000012', 'كولد برو', 'Cold Brew', 'DP-SKU-2', null,
   50.00, 1, 50.00, '2026-02-01T07:00:00Z'),
  ('4e100000-0000-4000-8000-000000000003', '4d100000-0000-4000-8000-000000000001',
   '6a100000-0000-4000-8000-000000000011', 'فلات وايت', 'Flat White', 'DP-SKU-1', null,
   25.00, 4, 100.00, '2026-02-01T01:00:00Z');

-- Three tenders of branch-1 orders, one of a branch-2 order, one of no order at
-- all. card_last4 must stay four digits (the table CHECK), amounts positive.
insert into payments.payment_transactions (
  id, order_id, subscription_id, provider, provider_reference, method_id, amount,
  currency_code, status, paid_at, card_brand, card_last4, card_holder_name,
  verified_by_server, created_at
)
values
  ('4f100000-0000-4000-8000-000000000001', '4d100000-0000-4000-8000-000000000001', null,
   'tap', 'dp-ref-1', (select id from payments.payment_methods where code = 'card'),
   100.00, 'SAR', 'captured', '2026-02-01T01:05:00Z', 'visa', '4242', 'DP CARDHOLDER', true,
   '2026-02-01T01:05:00Z'),
  ('4f100000-0000-4000-8000-000000000003', '4d100000-0000-4000-8000-000000000003', null,
   'pos_counter', null, (select id from payments.payment_methods where code = 'cash'),
   30.00, 'SAR', 'captured', '2026-02-01T03:05:00Z', null, null, null, true,
   '2026-02-01T03:05:00Z'),
  ('4f100000-0000-4000-8000-000000000007', '4d100000-0000-4000-8000-000000000007', null,
   'pos_counter', null, (select id from payments.payment_methods where code = 'cash'),
   45.00, 'SAR', 'captured', '2026-02-01T07:05:00Z', null, null, null, true,
   '2026-02-01T07:05:00Z'),
  ('4f200000-0000-4000-8000-000000000008', '4d200000-0000-4000-8000-000000000008', null,
   'pos_counter', null, (select id from payments.payment_methods where code = 'cash'),
   60.00, 'SAR', 'captured', '2026-02-01T08:05:00Z', null, null, null, true,
   '2026-02-01T08:05:00Z'),
  ('4f300000-0000-4000-8000-000000000001', null, '51100000-0000-4000-8000-000000000002',
   'tap', 'dp-ref-sub', (select id from payments.payment_methods where code = 'card'),
   99.00, 'SAR', 'captured', '2026-02-01T11:05:00Z', 'mada', '1111', 'DP SUBSCRIBER', true,
   '2026-02-01T11:05:00Z');

-- Five carts: three visible in branch 1 (two active, one abandoned), one
-- converted in branch 1 (the status filter must keep it out), one active in
-- branch 2.
insert into orders.carts (id, user_id, branch_id, status, expires_at, created_at, updated_at)
values
  ('8a100000-0000-4000-8000-000000000001', '4b100000-0000-4000-8000-000000000001',
   '3f100000-0000-4000-8000-000000000001', 'active',    '2026-02-02T06:00:00Z', '2026-02-02T01:00:00Z', '2026-02-02T01:00:00Z'),
  ('8a100000-0000-4000-8000-000000000002', '4b100000-0000-4000-8000-000000000002',
   '3f100000-0000-4000-8000-000000000001', 'active',    '2026-02-02T06:00:00Z', '2026-02-02T02:00:00Z', '2026-02-02T02:00:00Z'),
  ('8a100000-0000-4000-8000-000000000003', '4b100000-0000-4000-8000-000000000003',
   '3f100000-0000-4000-8000-000000000001', 'abandoned', '2026-02-02T06:00:00Z', '2026-02-02T03:00:00Z', '2026-02-02T03:00:00Z'),
  ('8a100000-0000-4000-8000-000000000004', '4b100000-0000-4000-8000-000000000004',
   '3f100000-0000-4000-8000-000000000001', 'converted', '2026-02-02T06:00:00Z', '2026-02-02T04:00:00Z', '2026-02-02T04:00:00Z'),
  ('8a100000-0000-4000-8000-000000000005', '4b100000-0000-4000-8000-000000000005',
   '3f200000-0000-4000-8000-000000000002', 'active',    '2026-02-02T06:00:00Z', '2026-02-02T05:00:00Z', '2026-02-02T05:00:00Z');

insert into orders.cart_items (id, cart_id, product_id, quantity, unit_price, line_total, created_at)
values
  ('8b100000-0000-4000-8000-000000000001', '8a100000-0000-4000-8000-000000000001',
   '6a100000-0000-4000-8000-000000000011', 2, 25.00, 50.00, '2026-02-02T01:00:00Z'),
  ('8b100000-0000-4000-8000-000000000002', '8a100000-0000-4000-8000-000000000001',
   '6a100000-0000-4000-8000-000000000012', 1, 50.00, 50.00, '2026-02-02T01:00:01Z');

-- Four reviews: two published, two hidden, two of them with no order.
insert into engagement.product_reviews (
  id, product_id, user_id, order_id, rating, title_ar, title_en, body_ar, body_en,
  is_published, created_at
)
values
  ('7a100000-0000-4000-8000-000000000001', '6a100000-0000-4000-8000-000000000011',
   '4b100000-0000-4000-8000-000000000001', '4d100000-0000-4000-8000-000000000001', 5,
   'ممتاز', 'Excellent', 'قهوة جيدة', 'Good coffee', true,  '2026-03-01T01:00:00Z'),
  ('7a100000-0000-4000-8000-000000000002', '6a100000-0000-4000-8000-000000000012',
   '4b100000-0000-4000-8000-000000000002', '4d100000-0000-4000-8000-000000000003', 4,
   'جيدة', 'Good', 'متوازن', 'Balanced', false, '2026-03-01T02:00:00Z'),
  ('7a100000-0000-4000-8000-000000000003', '6a100000-0000-4000-8000-000000000011',
   '4b100000-0000-4000-8000-000000000003', null, 3,
   'عادية', 'Average', 'لا أكثر', 'Nothing special', true,  '2026-03-01T03:00:00Z'),
  ('7a100000-0000-4000-8000-000000000004', '6a100000-0000-4000-8000-000000000012',
   '4b100000-0000-4000-8000-000000000004', null, 1,
   'سيئة', 'Poor', 'باردة', 'It was cold', false, '2026-03-01T04:00:00Z');

-- ---------------------------------------------------------------------------
-- The fixture counts are measured NOW, while this session is still its owner:
-- after the role switch RLS denies a direct read of these tables, so the numbers
-- the paged answers are compared against are handed over as transaction-local
-- settings. Customers and reviews have no branch predicate in the chain at all,
-- so their totals are whole-table counts — and the table may hold real rows, so
-- only relative statements about them are asserted below.
-- ---------------------------------------------------------------------------
select set_config('test.dp_b1_orders',
  ((select count(*) from orders.orders
     where branch_id = '3f100000-0000-4000-8000-000000000001')::int)::text, true);
select set_config('test.dp_b1_tenders',
  ((select count(*) from payments.payment_transactions t
     join orders.orders o on o.id = t.order_id
     where o.branch_id = '3f100000-0000-4000-8000-000000000001')::int)::text, true);
select set_config('test.dp_b1_carts',
  ((select count(*) from orders.carts c
     where c.status in ('active', 'abandoned')
       and c.branch_id = '3f100000-0000-4000-8000-000000000001')::int)::text, true);
select set_config('test.dp_customers',
  ((select count(*) from identity.profiles p
     where not exists (select 1 from identity.staff_members sm where sm.user_id = p.id))::int)::text, true);
select set_config('test.dp_reviews',
  ((select count(*) from engagement.product_reviews)::int)::text, true);
select set_config('test.dp_staff_ids',
  (select coalesce(string_agg(sm.user_id::text, ',' order by sm.user_id), '')
     from identity.staff_members sm), true);

-- ---------------------------------------------------------------------------
-- The walk helper: one implementation for all five directories, so every one is
-- measured by the same yardstick. It calls the RPC by name and POSITIONALLY
-- ($1 = p_limit, $2 = p_offset), keeps the unbounded answer as the reference,
-- then pages to the end and compares the concatenation against that reference.
-- It is invoker-rights by default, so each inner call passes the same
-- is_staff / has_permission / can_manage_branch gates the app passes.
-- ---------------------------------------------------------------------------
create function pg_temp.dp_215_walk(p_rpc text, p_tag text, p_max_pages integer)
returns jsonb
language plpgsql
as $wf$
declare
  v_ref   jsonb;
  v_env   jsonb;
  v_total integer;
  v_step  integer;
  v_off   integer := 0;
  v_pages integer := 0;
  v_rows  jsonb := '[]'::jsonb;
  v_len   integer;
  v_probe integer;
begin
  execute 'select public.' || quote_ident(p_rpc) || '(p_limit => null, p_offset => null)'
    into v_ref;

  if jsonb_typeof(v_ref) <> 'object' then
    raise exception 'FAIL %: % must answer with an object, got %',
      p_tag, p_rpc, coalesce(jsonb_typeof(v_ref), 'null');
  end if;
  if (select array_agg(k order by k) from jsonb_object_keys(v_ref) k)
     is distinct from array['rows', 'total'] then
    raise exception 'FAIL %: % envelope is %, expected exactly rows,total',
      p_tag, p_rpc,
      coalesce((select array_to_string(array_agg(k order by k), ',')
                  from jsonb_object_keys(v_ref) k), 'null');
  end if;
  if jsonb_typeof(v_ref -> 'rows') <> 'array' then
    raise exception 'FAIL %: % rows is not an array', p_tag, p_rpc;
  end if;

  v_total := (v_ref ->> 'total')::integer;
  if v_total <> jsonb_array_length(v_ref -> 'rows') then
    raise exception 'FAIL %: % with no limit returned % rows for total=%',
      p_tag, p_rpc, jsonb_array_length(v_ref -> 'rows'), v_total;
  end if;

  -- 122's contract: null, zero or a negative limit all mean "no limit", and a
  -- negative offset clamps to the first row.
  foreach v_probe in array array[0, -1] loop
    execute 'select public.' || quote_ident(p_rpc) || '($1, $2)'
      into v_env using v_probe, v_probe;
    if jsonb_array_length(v_env -> 'rows') <> v_total then
      raise exception 'FAIL %: % p_limit=% must mean no limit: % rows expected, % returned',
        p_tag, p_rpc, v_probe, v_total, jsonb_array_length(v_env -> 'rows');
    end if;
  end loop;

  -- The walk. The page size grows with the row count, so the loop costs at most
  -- p_max_pages calls on any database and still drops to one row per page for a
  -- fixture-sized set — which is what catches an off-by-one in OFFSET.
  v_step := greatest(1, ceil(v_total::numeric / greatest(p_max_pages, 1)))::integer;
  loop
    exit when v_off >= v_total;
    execute 'select public.' || quote_ident(p_rpc) || '($1, $2)'
      into v_env using v_step, v_off;
    if (v_env ->> 'total')::integer <> v_total then
      raise exception 'FAIL %: % total moved between pages (% then %)',
        p_tag, p_rpc, v_total, (v_env ->> 'total')::integer;
    end if;
    v_len := jsonb_array_length(v_env -> 'rows');
    if v_len <> least(v_step, v_total - v_off) then
      raise exception 'FAIL %: % page at offset % has % rows, expected %',
        p_tag, p_rpc, v_off, v_len, least(v_step, v_total - v_off);
    end if;
    v_rows := v_rows || (v_env -> 'rows');
    v_off := v_off + v_step;
    v_pages := v_pages + 1;
  end loop;

  if jsonb_array_length(v_rows) <> v_total then
    raise exception 'FAIL %: % the walk produced % rows for total=%',
      p_tag, p_rpc, jsonb_array_length(v_rows), v_total;
  end if;
  -- Identical text is the strongest statement available here: equal length,
  -- equal order, nothing skipped, nothing repeated, nothing altered mid-page.
  if v_rows::text <> (v_ref -> 'rows')::text then
    raise exception 'FAIL %: % the pages do not rebuild the unbounded answer', p_tag, p_rpc;
  end if;

  -- A page past the end is empty while total still prints the whole count: that
  -- is what proves the count was taken before the cut.
  execute 'select public.' || quote_ident(p_rpc) || '($1, $2)'
    into v_env using 5, v_total + 1;
  if jsonb_array_length(v_env -> 'rows') <> 0
     or (v_env ->> 'total')::integer <> v_total then
    raise exception 'FAIL %: % past the end must be [] with total=%, got %/%',
      p_tag, p_rpc, v_total, jsonb_array_length(v_env -> 'rows'), v_env ->> 'total';
  end if;

  return jsonb_build_object('total', v_total, 'step', v_step, 'pages', v_pages);
end;
$wf$;

-- The key-contract helper: same list, same membership, nothing extra.
create function pg_temp.dp_215_keys(p_row jsonb, p_want text[], p_what text)
returns void
language plpgsql
as $kf$
declare
  v_missing text[];
  v_extra   text[];
begin
  if jsonb_typeof(p_row) <> 'object' then
    raise exception 'FAIL 5: % row is %', p_what, coalesce(jsonb_typeof(p_row), 'null');
  end if;
  select array_agg(e) into v_missing
    from unnest(p_want) e
   where not exists (select 1 from jsonb_object_keys(p_row) k where k = e);
  select array_agg(k) into v_extra
    from jsonb_object_keys(p_row) k
   where not (k = any (p_want));
  if v_missing is not null or v_extra is not null then
    raise exception 'FAIL 5: % keys changed. missing=% extra=%',
      p_what, coalesce(array_to_string(v_missing, ','), '-'),
      coalesce(array_to_string(v_extra, ','), '-');
  end if;
end;
$kf$;

-- ---------------------------------------------------------------------------
-- 1. The API shape, read from the catalog while still the owner: one function
--    per name, the two new identity arguments, the zero-argument signature gone,
--    and the grants on the new signature.
-- ---------------------------------------------------------------------------
do $$
declare
  v_name text;
  v_count integer;
  v_oid  oid;
begin
  foreach v_name in array array[
    'admin_orders', 'admin_payments', 'admin_customers', 'admin_reviews',
    'admin_abandoned_carts'
  ] loop
    select count(*) into v_count
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname = v_name;
    if v_count <> 1 then
      raise exception 'FAIL 1: % has % definitions, expected exactly 1 — an overload leaves PostgREST unable to choose',
        v_name, v_count;
    end if;

    select p.oid into v_oid
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname = v_name;

    if pg_get_function_identity_arguments(v_oid) <> 'p_limit integer, p_offset integer' then
      raise exception 'FAIL 1: % identity arguments are %',
        v_name, pg_get_function_identity_arguments(v_oid);
    end if;
    if to_regproc(format('public.%s()', v_name)) is not null then
      raise exception 'FAIL 1: the zero-argument %() signature survived', v_name;
    end if;
    if has_function_privilege('anon', v_oid, 'execute') then
      raise exception 'FAIL 1: anon still executes %', v_name;
    end if;
    if not has_function_privilege('authenticated', v_oid, 'execute') then
      raise exception 'FAIL 1: authenticated lost execute on %', v_name;
    end if;
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 2 + 3 + 4. The envelope, the walk and the limit contract, for all five, as the
--    branch-1 manager: every permission a directory needs, and a scope small
--    enough that the counts are the fixtures.
-- ---------------------------------------------------------------------------
set local role authenticated;

select set_config('request.jwt.claims',
  '{"sub":"4a100000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v jsonb;
begin
  -- The whole set, unpaginated, as the zero-argument call the app sends today.
  v := public.admin_orders();
  if (v ->> 'total')::int <> current_setting('test.dp_b1_orders')::int then
    raise exception 'FAIL 3: admin_orders total=% but the branch holds %',
      v ->> 'total', current_setting('test.dp_b1_orders');
  end if;
  if jsonb_array_length(v -> 'rows') <> current_setting('test.dp_b1_orders')::int then
    raise exception 'FAIL 4: the zero-argument call lost rows — its defaults are what today''s Dart depends on';
  end if;

  -- A limit asks for that many rows and no more; total still prints the whole.
  v := public.admin_orders(p_limit => 3);
  if jsonb_array_length(v -> 'rows') <> 3 then
    raise exception 'FAIL 4: p_limit 3 returned % rows', jsonb_array_length(v -> 'rows');
  end if;
  if (v ->> 'total')::int <> current_setting('test.dp_b1_orders')::int then
    raise exception 'FAIL 4: a page must still print the whole count, got %', v ->> 'total';
  end if;

  v := public.admin_payments();
  if (v ->> 'total')::int <> current_setting('test.dp_b1_tenders')::int then
    raise exception 'FAIL 3: admin_payments total=% but the branch holds %',
      v ->> 'total', current_setting('test.dp_b1_tenders');
  end if;

  v := public.admin_abandoned_carts();
  if (v ->> 'total')::int <> current_setting('test.dp_b1_carts')::int then
    raise exception 'FAIL 3: admin_abandoned_carts total=% but the branch holds %',
      v ->> 'total', current_setting('test.dp_b1_carts');
  end if;

  -- Customers and reviews carry no branch predicate (160 and 169 never had one),
  -- so their totals are whole-table counts even for this caller.
  v := public.admin_customers();
  if (v ->> 'total')::int <> current_setting('test.dp_customers')::int then
    raise exception 'FAIL 3: admin_customers total=% but the table holds %',
      v ->> 'total', current_setting('test.dp_customers');
  end if;

  v := public.admin_reviews();
  if (v ->> 'total')::int <> current_setting('test.dp_reviews')::int then
    raise exception 'FAIL 3: admin_reviews total=% but the table holds %',
      v ->> 'total', current_setting('test.dp_reviews');
  end if;

  -- The walk, all five, same yardstick.
  perform pg_temp.dp_215_walk('admin_orders', '2', 6);
  perform pg_temp.dp_215_walk('admin_payments', '2', 6);
  perform pg_temp.dp_215_walk('admin_customers', '2', 6);
  perform pg_temp.dp_215_walk('admin_reviews', '2', 6);
  perform pg_temp.dp_215_walk('admin_abandoned_carts', '2', 6);
end $$;

-- ---------------------------------------------------------------------------
-- 5. The row shape did not change: the same keys, the same nesting, the same
--    types, now inside the envelope. 186's own lists are reused verbatim.
-- ---------------------------------------------------------------------------
do $$
declare
  v     jsonb;
  v_row jsonb;
  o_keys text[] := array[
    'id','order_number','user_id','pos_customer_id','customer_name','customer_email',
    'customer_phone','customer_avatar_url','branch_id','branch_name_ar','branch_name_en',
    'branch_latitude','branch_longitude','fulfillment_type','order_source','table_number',
    'status','payment_method_id','payment_status','subtotal','discount_total',
    'product_discount_total','delivery_fee','tax_total','grand_total','currency_code',
    'customer_note','placed_at','completed_at','delivery_address_snapshot','items'];
  p_keys text[] := array[
    'id','order_id','order_number','customer_name','provider','provider_reference',
    'method_id','method_code','method_name_ar','method_name_en','amount','currency_code',
    'status','paid_at','refunded_at','card_brand','card_last4','card_holder_name',
    'verified_by_server','created_at'];
  c_keys text[] := array[
    'id','full_name','email','phone','avatar_url','language','last_seen_at','created_at',
    'updated_at','orders_count','total_spent','last_order_at','is_vip','is_blacklisted',
    'admin_notes'];
  r_keys text[] := array[
    'id','rating','title_ar','title_en','body_ar','body_en','is_published','created_at',
    'updated_at','order_id','order_number','product','customer'];
  rp_keys text[] := array[
    'id','name_ar','name_en','sku','image_url','category_name_ar','category_name_en'];
  rc_keys text[] := array['id','full_name','email','phone','avatar_url'];
  a_keys text[] := array[
    'id','user_id','customer_name','customer_email','branch_id','branch_name_ar',
    'branch_name_en','status','expires_at','created_at','updated_at','total','items'];
  oi_keys text[] := array[
    'id','product_id','product_name_ar','product_name_en','image_url',
    'option_group_name_ar','option_group_name_en','quantity','unit_price','line_total','note'];
  ci_keys text[] := array[
    'id','product_id','product_name_ar','product_name_en','image_url','quantity',
    'unit_price','line_total','note'];
begin
  v := public.admin_orders(p_limit => 2);
  v_row := v -> 'rows' -> 0;
  perform pg_temp.dp_215_keys(v_row, o_keys, 'admin_orders');
  if cardinality(o_keys) <> 31 then
    raise exception 'FAIL 5: the expected order key list itself is wrong';
  end if;
  if jsonb_typeof(v_row -> 'subtotal') <> 'number'
     or jsonb_typeof(v_row -> 'grand_total') <> 'number'
     or jsonb_typeof(v_row -> 'items') <> 'array' then
    raise exception 'FAIL 5: admin_orders value types changed';
  end if;

  v := public.admin_payments(p_limit => 1);
  perform pg_temp.dp_215_keys(v -> 'rows' -> 0, p_keys, 'admin_payments');
  if cardinality(p_keys) <> 20 then
    raise exception 'FAIL 5: the expected payment key list itself is wrong';
  end if;
  if jsonb_typeof(v -> 'rows' -> 0 -> 'amount') <> 'number' then
    raise exception 'FAIL 5: admin_payments amount type changed';
  end if;

  v := public.admin_customers(p_limit => 1);
  perform pg_temp.dp_215_keys(v -> 'rows' -> 0, c_keys, 'admin_customers');
  if cardinality(c_keys) <> 15 then
    raise exception 'FAIL 5: the expected customer key list itself is wrong';
  end if;

  v := public.admin_reviews(p_limit => 1);
  perform pg_temp.dp_215_keys(v -> 'rows' -> 0, r_keys, 'admin_reviews');
  perform pg_temp.dp_215_keys(v -> 'rows' -> 0 -> 'product', rp_keys, 'admin_reviews.product');
  perform pg_temp.dp_215_keys(v -> 'rows' -> 0 -> 'customer', rc_keys, 'admin_reviews.customer');

  v := public.admin_abandoned_carts(p_limit => 3);
  perform pg_temp.dp_215_keys(v -> 'rows' -> 0, a_keys, 'admin_abandoned_carts');
  if cardinality(a_keys) <> 13 then
    raise exception 'FAIL 5: the expected cart key list itself is wrong';
  end if;
  -- The branch-1 cart with two lines is the newest of the three: its item keys
  -- are the other half of the 211 shape contract.
  if (v -> 'rows' -> 0 ->> 'id') = '8a100000-0000-4000-8000-000000000001' then
    perform pg_temp.dp_215_keys(v -> 'rows' -> 0 -> 'items' -> 0, ci_keys, 'admin_abandoned_carts.items');
  end if;
  -- and the order line keys, on the order that carries two
  v := public.admin_orders(p_limit => 1);
  if (v -> 'rows' -> 0 ->> 'id') = '4d100000-0000-4000-8000-000000000007' then
    perform pg_temp.dp_215_keys(v -> 'rows' -> 0 -> 'items' -> 0, oi_keys, 'admin_orders.items');
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 6. The joins, the aggregates and the ordering survived the cut into a page.
--    The POS walk-in assertion in here is the drift probe described at the top.
-- ---------------------------------------------------------------------------
do $$
declare v jsonb; r jsonb;
begin
  -- Orders: the page the app actually renders first, with its two line items.
  v := public.admin_orders(p_limit => 1, p_offset => 0);
  r := v -> 'rows' -> 0;
  if r ->> 'order_number' <> 'DP-107' then
    raise exception 'FAIL 6: the first order page is %, expected the newest branch-1 order DP-107',
      r ->> 'order_number';
  end if;
  if jsonb_array_length(r -> 'items') <> 2 then
    raise exception 'FAIL 6: DP-107 lost its two line items inside the page (got %)',
      jsonb_array_length(r -> 'items');
  end if;
  if r ->> 'customer_name' <> 'DP Walk In' then
    raise exception 'FAIL 6: the POS order prints % instead of the walk-in name',
      coalesce(r ->> 'customer_name', 'null');
  end if;
  if r ->> 'branch_name_ar' <> 'فرع الصفحات 1' then
    raise exception 'FAIL 6: the branch join is gone from the paged answer';
  end if;

  -- The second page carries the oldest-but-one order, so OFFSET cut rows and
  -- not groups.
  v := public.admin_orders(p_limit => 3, p_offset => 3);
  if (v -> 'rows' -> 0 ->> 'order_number') <> 'DP-104' then
    raise exception 'FAIL 6: offset 3 opens with %, expected DP-104',
      v -> 'rows' -> 0 ->> 'order_number';
  end if;

  -- Payments: the card fields, the method code, and the walk-in name on its
  -- tender. THIS LAST ASSERTION IS 211 §3, NOT 215.
  v := public.admin_payments(p_limit => 5);
  select x into r from jsonb_array_elements(v -> 'rows') x
   where x ->> 'id' = '4f100000-0000-4000-8000-000000000001';
  if r is null then
    raise exception 'FAIL 6: the branch-1 card tender is missing from the paged answer';
  end if;
  if r ->> 'card_last4' <> '4242' or r ->> 'method_code' <> 'card'
     or r ->> 'order_number' <> 'DP-101' then
    raise exception 'FAIL 6: the payments joins changed inside the page: %', r;
  end if;

  select x into r from jsonb_array_elements(public.admin_payments() -> 'rows') x
   where x ->> 'id' = '4f100000-0000-4000-8000-000000000007';
  if r is null or r ->> 'customer_name' <> 'DP Walk In' then
    raise exception 'FAIL 6: the POS walk-in tender prints % — this is the 211 §3 half of the drift 215 carries',
      coalesce(r ->> 'customer_name', 'null');
  end if;

  -- Customers: the per-customer order aggregate still travels with the row.
  v := public.admin_customers(p_limit => 10);
  select x into r from jsonb_array_elements(v -> 'rows') x
   where x ->> 'id' = '4b100000-0000-4000-8000-000000000001';
  if r is null then
    raise exception 'FAIL 6: DP Cust One is missing from the customer directory';
  end if;
  if (r ->> 'orders_count')::int <> 2
     or (r ->> 'total_spent')::numeric <> 150.00 then
    raise exception 'FAIL 6: DP Cust One aggregates as % orders / % spent, expected 2 / 150.00',
      r ->> 'orders_count', r ->> 'total_spent';
  end if;
  -- created_at desc: the newest fixture must come before the oldest one, and the
  -- table may hold real rows, so the statement is relative, not positional.
  if (select min(ord) from jsonb_array_elements(v -> 'rows') with ordinality e(x, ord)
       where x ->> 'id' = '4b100000-0000-4000-8000-000000000005')
  >= (select min(ord) from jsonb_array_elements(v -> 'rows') with ordinality e(x, ord)
       where x ->> 'id' = '4b100000-0000-4000-8000-000000000001') then
    raise exception 'FAIL 6: the customer directory no longer sorts by created_at desc';
  end if;

  -- Reviews: the nested product, category and customer objects, plus the order.
  v := public.admin_reviews(p_limit => 10);
  select x into r from jsonb_array_elements(v -> 'rows') x
   where x ->> 'id' = '7a100000-0000-4000-8000-000000000001';
  if r is null then
    raise exception 'FAIL 6: the fixture review is missing from the reviews directory';
  end if;
  if (r -> 'product' ->> 'sku') <> 'DP-SKU-1'
     or (r -> 'product' ->> 'category_name_ar') <> 'قهوة الصفحات'
     or (r -> 'customer' ->> 'full_name') <> 'DP Cust One'
     or r ->> 'order_number' <> 'DP-101' then
    raise exception 'FAIL 6: the review joins changed inside the page: %', r;
  end if;

  -- Carts: the per-cart line sum and the item array.
  v := public.admin_abandoned_carts(p_limit => 3);
  r := v -> 'rows' -> 0;
  if r ->> 'id' <> '8a100000-0000-4000-8000-000000000003' then
    raise exception 'FAIL 6: the newest branch-1 cart is %, expected the abandoned one',
      r ->> 'id';
  end if;
  select x into r from jsonb_array_elements(v -> 'rows') x
   where x ->> 'id' = '8a100000-0000-4000-8000-000000000001';
  if r is null or (r ->> 'total')::numeric <> 100.00
     or jsonb_array_length(r -> 'items') <> 2 then
    raise exception 'FAIL 6: the cart with two lines lost its total or its items inside the page';
  end if;
  if (r ->> 'customer_name') <> 'DP Cust One' then
    raise exception 'FAIL 6: the cart profile join is gone';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 7. Filters that already existed still exist.
-- ---------------------------------------------------------------------------
do $$
declare v jsonb;
begin
  -- 'converted' is not an abandoned cart, and paging must not change that.
  v := public.admin_abandoned_carts(p_limit => null);
  if v::text like '%8a100000-0000-4000-8000-000000000004%' then
    raise exception 'FAIL 7: the converted cart leaked into admin_abandoned_carts';
  end if;

  -- No staff account may appear in the customer directory, page or not.
  v := public.admin_customers(p_limit => null);
  if exists (
    select 1 from jsonb_array_elements(v -> 'rows') x
     where x ->> 'id' = any (string_to_array(current_setting('test.dp_staff_ids'), ','))
  ) then
    raise exception 'FAIL 7: a staff account appeared in admin_customers';
  end if;

  -- admin_reviews answers for published AND hidden rows: moderation reads both.
  v := public.admin_reviews(p_limit => null);
  if v::text not like '%7a100000-0000-4000-8000-000000000002%' then
    raise exception 'FAIL 7: the hidden review disappeared from the directory';
  end if;
  if v::text not like '%7a100000-0000-4000-8000-000000000001%' then
    raise exception 'FAIL 7: the published review disappeared from the directory';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 8. Branch scope is unchanged, for both reaches.
-- ---------------------------------------------------------------------------
do $$
declare v jsonb;
begin
  -- The branch-1 manager: no branch-2 row in any page, and no tender of no
  -- branch at all.
  v := public.admin_orders(p_limit => null);
  if v::text like '%DP-20%' then
    raise exception 'FAIL 8: branch 1 read a branch-2 order through the paged directory';
  end if;
  v := public.admin_payments(p_limit => null);
  if v::text like '%4f200000-0000-4000-8000-000000000008%' then
    raise exception 'FAIL 8: branch 1 read a branch-2 tender';
  end if;
  if v::text like '%DP SUBSCRIBER%' then
    raise exception 'FAIL 8: a branch-scoped caller read the tender that belongs to no branch';
  end if;
  v := public.admin_abandoned_carts(p_limit => null);
  if v::text like '%8a100000-0000-4000-8000-000000000005%' then
    raise exception 'FAIL 8: branch 1 read a branch-2 cart';
  end if;
end $$;

-- The same caller by a different reach: the global manager sees both branches
-- and the orphan tender, and paging costs them nothing.
select set_config('request.jwt.claims',
  '{"sub":"4a100000-0000-4000-8000-000000000002","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v jsonb;
begin
  v := public.admin_payments(p_limit => null);
  if v::text not like '%DP SUBSCRIBER%' then
    raise exception 'FAIL 8: the global manager lost the tender of no branch';
  end if;
  if v::text not like '%4f200000-0000-4000-8000-000000000008%' then
    raise exception 'FAIL 8: the global manager lost the branch-2 tender';
  end if;
  -- The table may hold real orders as well as the ten fixtures, so the ordering
  -- statement is relative: the newest fixture still precedes the oldest one.
  v := public.admin_orders(p_limit => null);
  if (select min(ord) from jsonb_array_elements(v -> 'rows') with ordinality e(x, ord)
       where x ->> 'order_number' = 'DP-203')
  >= (select min(ord) from jsonb_array_elements(v -> 'rows') with ordinality e(x, ord)
       where x ->> 'order_number' = 'DP-101') then
    raise exception 'FAIL 8: the global orders page no longer sorts by placed_at desc';
  end if;
  perform pg_temp.dp_215_walk('admin_orders', '8', 6);
end $$;

-- ---------------------------------------------------------------------------
-- 9. Every guard still fires, with its own message, through the new signature.
-- ---------------------------------------------------------------------------

-- cashier: orders.read and payments.read, neither customers.read nor
-- reviews.moderate.
select set_config('request.jwt.claims',
  '{"sub":"4a100000-0000-4000-8000-000000000003","role":"authenticated","aud":"authenticated"}', true);

do $$
begin
  perform public.admin_customers(p_limit => 5);
  raise exception 'FAIL 9a: a cashier without customers.read read the customer directory';
exception
  when others then
    if sqlstate <> '42501' then raise; end if;
    if sqlerrm not like '%missing permission: customers.read%' then raise; end if;
end $$;

do $$
begin
  perform public.admin_reviews(p_limit => 5);
  raise exception 'FAIL 9b: a cashier without reviews.moderate read the reviews directory';
exception
  when others then
    if sqlstate <> '42501' then raise; end if;
    if sqlerrm not like '%missing permission: reviews.moderate%' then raise; end if;
end $$;

-- The arms the cashier DOES hold still work, and still cost them the limit.
do $$
declare v jsonb;
begin
  v := public.admin_orders(p_limit => 2);
  if jsonb_array_length(v -> 'rows') <> 2 then
    raise exception 'FAIL 9c: the cashier paged orders answer changed: %',
      jsonb_array_length(v -> 'rows');
  end if;
end $$;

-- staff: orders.read only.
select set_config('request.jwt.claims',
  '{"sub":"4a100000-0000-4000-8000-000000000004","role":"authenticated","aud":"authenticated"}', true);

do $$
begin
  perform public.admin_payments(p_limit => 5);
  raise exception 'FAIL 9d: staff without payments.read read the payments directory';
exception
  when others then
    if sqlstate <> '42501' then raise; end if;
    if sqlerrm not like '%missing permission: payments.read%' then raise; end if;
end $$;

-- An invited staff member is not staff at all.
select set_config('request.jwt.claims',
  '{"sub":"4a100000-0000-4000-8000-000000000005","role":"authenticated","aud":"authenticated"}', true);

do $$
begin
  perform public.admin_orders(p_limit => 5);
  raise exception 'FAIL 9e: an invited staff member read the orders directory';
exception
  when others then
    if sqlstate <> '42501' then raise; end if;
    if sqlerrm not like '%not authenticated%' then raise; end if;
end $$;

-- A signed-in customer.
select set_config('request.jwt.claims',
  '{"sub":"4b100000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);

do $$
begin
  perform public.admin_orders(p_limit => 5);
  raise exception 'FAIL 9f: an ordinary customer read the orders directory';
exception
  when others then
    if sqlstate <> '42501' then raise; end if;
end $$;

do $$
begin
  perform public.admin_customers();
  raise exception 'FAIL 9f: an ordinary customer read the customer directory';
exception
  when others then
    if sqlstate <> '42501' then raise; end if;
end $$;

reset role;

set local role anon;

do $$
declare v_name text;
begin
  foreach v_name in array array[
    'admin_orders', 'admin_payments', 'admin_customers', 'admin_reviews',
    'admin_abandoned_carts'
  ] loop
    begin
      execute 'select public.' || quote_ident(v_name) || '(p_limit => 5)';
      raise exception 'FAIL 9g: anon executed %', v_name;
    exception
      when others then
        if sqlstate <> '42501' then raise; end if;
    end;
  end loop;
end $$;

reset role;

-- ---------------------------------------------------------------------------
-- 10. An empty scope answers rows [] with total 0, never null.
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"4a100000-0000-4000-8000-000000000006","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v jsonb;
begin
  v := public.admin_orders(p_limit => 5, p_offset => 0);
  if jsonb_typeof(v -> 'rows') <> 'array'
     or jsonb_array_length(v -> 'rows') <> 0
     or (v ->> 'total')::int <> 0 then
    raise exception 'FAIL 10: a branch with no order must answer [] and total 0, got %', v;
  end if;
  v := public.admin_payments();
  if jsonb_typeof(v -> 'rows') <> 'array'
     or jsonb_array_length(v -> 'rows') <> 0
     or (v ->> 'total')::int <> 0 then
    raise exception 'FAIL 10: a branch with no tender must answer [] and total 0, got %', v;
  end if;
  v := public.admin_abandoned_carts();
  if jsonb_typeof(v -> 'rows') <> 'array'
     or jsonb_array_length(v -> 'rows') <> 0
     or (v ->> 'total')::int <> 0 then
    raise exception 'FAIL 10: a branch with no cart must answer [] and total 0, got %', v;
  end if;
end $$;

reset role;

-- Every section above raises on the first mismatch, so reaching this line is
-- itself the proof. This row is what a runner prints. The transaction still
-- rolls back, so none of it stays in the database.
select
  'reached the end: no assertion failed' as verdict,
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in ('admin_orders','admin_payments','admin_customers',
                        'admin_reviews','admin_abandoned_carts')
      and pg_get_function_identity_arguments(p.oid) = 'p_limit integer, p_offset integer')
    as functions_with_two_arguments,
  current_setting('test.dp_b1_orders') || '/' || current_setting('test.dp_b1_tenders')
    || '/' || current_setting('test.dp_b1_carts') || '/' || current_setting('test.dp_customers')
    || '/' || current_setting('test.dp_reviews') as fixture_counts_orders_tenders_carts_customers_reviews;

rollback;
