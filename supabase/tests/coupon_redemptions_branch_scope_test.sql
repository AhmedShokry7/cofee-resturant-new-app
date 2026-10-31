-- coupon_redemptions_branch_scope_test.sql
-- Behaviour test for 214_coupon_redemptions_branch_scope.PROPOSED.sql: the staff
-- SELECT policy of marketing.coupon_redemptions, read through the
-- security_invoker bridge view public.coupon_redemptions that 032 created and
-- granted to authenticated.
--
-- STATUS: EXECUTED AND PASSED on 2026-10-31 against the live project
-- webzzasosevzymftgszn, inside one transaction that also applied the 214 policy
-- replacement and then rolled both back. The report row came back:
--   verdict = 'reached the end: no assertion failed', branch_1_rows = 1,
--   branch_2_rows = 1, branch_3_rows = 1, and the recorded staff predicate was
--   exactly the 021 shape: has_permission('orders.read') AND EXISTS (the order of
--   a branch the caller can manage).
-- The residue check after the rollback found 0 fixture branches, orders,
-- redemptions, coupon and test role, and the live policy back to the bare
-- `identity.has_permission('orders.read'::text)` with its two policies — so 214
-- remains a proposal, not a deployed change.
--
-- One defect was found by running it: section 8a called admin_coupon_metrics()
-- while the claims still carried branch 1's manager from section 7, so it answered
-- 'missing permission: settings.write' instead of the global manager's metrics.
-- The claims switch that section needed is now in the file, outside the block.
--
-- Against the unpatched 022 policy sections 1, 2 and 3 FAIL on purpose, and that
-- failure is the leak being reported, not a broken test. Keep the discipline of
-- admin_orders_branch_scope_test.sql: one transaction, fixtures destroyed by the
-- final rollback, and the report row recorded in this header so the next reader
-- knows what was actually observed.
--
-- RUN ONLY AGAINST AN ISOLATED, NON-PRODUCTION DATABASE.
--
-- Plain SQL for the Supabase SQL Editor or psql. Every row-count assertion runs
-- as the real anon/authenticated role with real JWT claims, so the policy is
-- executed rather than described.
--
-- PREREQUISITES: 011/013 (orders), 015 (marketing tables), 018 + 123 (the RLS
-- helpers: has_permission, can_manage_branch, manages_all_branches), 022 (both
-- coupon_redemptions policies), 023 + 032 (the grants and the bridge view), 137
-- (the seeded role matrix), and the 214 replacement of
-- coupon_redemptions_select_staff.
--
-- WHAT THIS PROVES, IN ORDER
--   1  a branch manager reads only the redemptions of their own branch's orders
--   2  the same for a staff member and for a cashier — the role that could read
--      the whole company before 214
--   3  a global scope (manager with a NULL branch row, and the owner) still reads
--      every row, so no legitimate review is narrowed
--   4  an invited staff member and a role without orders.read read nothing
--   5  the customer still reads their own redemptions across every branch: the
--      two permissive SELECT policies union, so 214 cannot close 022's own row
--   6  anon still reads nothing
--   7  the change did not open a write path: no INSERT policy, no grant on the
--      view, so a client still cannot forge a redemption
--   8  the coupons screen is untouched: admin_coupon_metrics() is a security
--      definer aggregate behind settings.write, so it still counts the company,
--      and a branch manager is still refused it
--   9  the catalog states the new shape, so an out-of-band paste later cannot
--      quietly restore the old predicate
--  10  no redemption row can be hidden by a missing order: order_id is not null
--      and on delete cascade, which is why the EXISTS is safe
--
-- WHAT IS NOT TESTED HERE
--   coupons_public_read (022:58-60) — whether anon may see the coupon rows
--   themselves is a separate owner decision and this file does not touch it.

begin;

-- ---------------------------------------------------------------------------
-- Fixtures: three branches, three orders with three redemptions, two customers
-- and seven staff with seven different reaches.
-- ---------------------------------------------------------------------------
insert into core.branches (id, brand_id, code, name_ar, name_en, address, is_active, settings)
values
  ('3c100000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000001', 'CRS-B1', 'فرع الكوبون 1', 'Coupon Scope Branch 1', 'addr1', true, '{}'::jsonb),
  ('3c200000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000001', 'CRS-B2', 'فرع الكوبون 2', 'Coupon Scope Branch 2', 'addr2', true, '{}'::jsonb),
  ('3c300000-0000-4000-8000-000000000003', '00000000-0000-4000-8000-000000000001', 'CRS-B3', 'فرع الكوبون 3', 'Coupon Scope Branch 3', 'addr3', true, '{}'::jsonb);

insert into marketing.coupons (id, code, title_ar, title_en, discount_type, discount_value, applies_to, is_active)
values ('3f100000-0000-4000-8000-000000000001', 'CRS10', 'خصم النطاق', 'Scope Discount',
        'percentage', 10.00, 'all', true);

insert into auth.users (id, email)
values
  ('5c200000-0000-4000-8000-000000000001', 'crs-customer-1@test.local'),
  ('5c200000-0000-4000-8000-000000000002', 'crs-customer-2@test.local'),
  ('5c300000-0000-4000-8000-000000000001', 'crs-owner@test.local'),
  ('5c300000-0000-4000-8000-000000000002', 'crs-global@test.local'),
  ('5c300000-0000-4000-8000-000000000003', 'crs-bm1@test.local'),
  ('5c300000-0000-4000-8000-000000000004', 'crs-staff2@test.local'),
  ('5c300000-0000-4000-8000-000000000005', 'crs-cashier3@test.local'),
  ('5c300000-0000-4000-8000-000000000006', 'crs-noread@test.local'),
  ('5c300000-0000-4000-8000-000000000007', 'crs-invited@test.local');

insert into identity.profiles (id, full_name, email, phone)
values
  ('5c200000-0000-4000-8000-000000000001', 'CRS Customer One', 'crs-customer-1@test.local', '0500000011'),
  ('5c200000-0000-4000-8000-000000000002', 'CRS Customer Two', 'crs-customer-2@test.local', '0500000012')
on conflict (id) do nothing;

insert into identity.staff_members (id, user_id, status, full_name, email)
values
  ('51300000-0000-4000-8000-000000000001', '5c300000-0000-4000-8000-000000000001', 'active',  'CRS Owner',      'crs-owner@test.local'),
  ('51300000-0000-4000-8000-000000000002', '5c300000-0000-4000-8000-000000000002', 'active',  'CRS Global',     'crs-global@test.local'),
  ('51300000-0000-4000-8000-000000000003', '5c300000-0000-4000-8000-000000000003', 'active',  'CRS BM One',     'crs-bm1@test.local'),
  ('51300000-0000-4000-8000-000000000004', '5c300000-0000-4000-8000-000000000004', 'active',  'CRS Staff Two',  'crs-staff2@test.local'),
  ('51300000-0000-4000-8000-000000000005', '5c300000-0000-4000-8000-000000000005', 'active',  'CRS Cashier Three', 'crs-cashier3@test.local'),
  ('51300000-0000-4000-8000-000000000006', '5c300000-0000-4000-8000-000000000006', 'active',  'CRS NoRead',     'crs-noread@test.local'),
  ('51300000-0000-4000-8000-000000000007', '5c300000-0000-4000-8000-000000000007', 'invited', 'CRS Invited',    'crs-invited@test.local');

-- Every seeded role in 137 holds orders.read except owner, which short-circuits
-- has_permission anyway, so a role without the code has to exist for section 4
-- to be observable. It grants nothing the product grants; the rollback drops it.
insert into identity.roles (code, name_ar, name_en, description, is_system)
values ('crs_no_orders_read', 'دور اختبار بلا قراءة الطلبات', 'Test role without orders.read',
        'Behaviour-test role for 214: an active staff member who holds no orders.read', false);

insert into identity.role_permissions (role_id, permission_id)
select r.id, p.id
  from identity.roles r
  join identity.permissions p on p.code = 'notifications.read'
 where r.code = 'crs_no_orders_read';

-- A NULL branch row is what identity.can_manage_branch() reads as "every
-- branch", so the difference between the global shapes and the scoped ones is a
-- fixture choice, not a code path.
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '51300000-0000-4000-8000-000000000001', r.id, null from identity.roles r where r.code = 'owner';
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '51300000-0000-4000-8000-000000000002', r.id, null from identity.roles r where r.code = 'manager';
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '51300000-0000-4000-8000-000000000003', r.id, '3c100000-0000-4000-8000-000000000001' from identity.roles r where r.code = 'branch_manager';
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '51300000-0000-4000-8000-000000000004', r.id, '3c200000-0000-4000-8000-000000000002' from identity.roles r where r.code = 'staff';
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '51300000-0000-4000-8000-000000000005', r.id, '3c300000-0000-4000-8000-000000000003' from identity.roles r where r.code = 'cashier';
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '51300000-0000-4000-8000-000000000006', r.id, '3c100000-0000-4000-8000-000000000001' from identity.roles r where r.code = 'crs_no_orders_read';
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '51300000-0000-4000-8000-000000000007', r.id, '3c100000-0000-4000-8000-000000000001' from identity.roles r where r.code = 'branch_manager';

-- Three orders that carried the coupon, one per branch, with the discount the
-- redemption rows record. ck_orders_total holds: subtotal - discount + fee + tax.
insert into orders.orders (
  id, order_number, user_id, branch_id, fulfillment_type, status, payment_status,
  subtotal, discount_total, delivery_fee, tax_total, grand_total, currency_code,
  customer_note, placed_at, loyalty_points_earned, idempotency_key
)
values
  ('6b400000-0000-4000-8000-000000000001', 'TEST-CRS-1',
   '5c200000-0000-4000-8000-000000000001', '3c100000-0000-4000-8000-000000000001',
   'pickup', 'pending', 'unpaid', 100.00, 10.00, 0.00, 0.00, 90.00, 'SAR', 'crs1',
   '2026-01-01T00:00:00Z', 0, 'crs-test-key-1'),
  ('6b400000-0000-4000-8000-000000000002', 'TEST-CRS-2',
   '5c200000-0000-4000-8000-000000000001', '3c200000-0000-4000-8000-000000000002',
   'pickup', 'pending', 'unpaid', 200.00, 20.00, 0.00, 0.00, 180.00, 'SAR', 'crs2',
   '2026-01-02T00:00:00Z', 0, 'crs-test-key-2'),
  ('6b400000-0000-4000-8000-000000000003', 'TEST-CRS-3',
   '5c200000-0000-4000-8000-000000000002', '3c300000-0000-4000-8000-000000000003',
   'pickup', 'pending', 'unpaid', 300.00, 30.00, 0.00, 0.00, 270.00, 'SAR', 'crs3',
   '2026-01-03T00:00:00Z', 0, 'crs-test-key-3');

-- The rows the policy decides. Written here as the table owner, the way the
-- place-order functions write them: there is no INSERT policy for a client.
insert into marketing.coupon_redemptions (id, coupon_id, user_id, order_id, amount)
values
  ('9e100000-0000-4000-8000-000000000001', '3f100000-0000-4000-8000-000000000001',
   '5c200000-0000-4000-8000-000000000001', '6b400000-0000-4000-8000-000000000001', 10.00),
  ('9e100000-0000-4000-8000-000000000002', '3f100000-0000-4000-8000-000000000001',
   '5c200000-0000-4000-8000-000000000001', '6b400000-0000-4000-8000-000000000002', 20.00),
  ('9e100000-0000-4000-8000-000000000003', '3f100000-0000-4000-8000-000000000001',
   '5c200000-0000-4000-8000-000000000002', '6b400000-0000-4000-8000-000000000003', 30.00);

set local role authenticated;

-- ---------------------------------------------------------------------------
-- 1. A branch manager reads their own branch only.
--    Before 214 the same token read the two fixtures of the other branches too.
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"5c300000-0000-4000-8000-000000000003","role":"authenticated","aud":"authenticated"}', true);

-- The live database is not empty, so every count below is measured against the
-- three fixture ids, never against the whole table.
do $$
declare n int;
begin
  select count(*) into n from public.coupon_redemptions
   where id = '9e100000-0000-4000-8000-000000000001';
  if n <> 1 then
    raise exception 'FAIL 1: the branch-1 manager cannot read its own redemption';
  end if;
  select count(*) into n from public.coupon_redemptions
   where id in ('9e100000-0000-4000-8000-000000000002',
                '9e100000-0000-4000-8000-000000000003');
  if n <> 0 then
    raise exception 'FAIL 1: the branch-1 manager reads % redemption rows of other branches', n;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 2. The same narrowing for the other two roles that hold orders.read: staff of
--    branch 2, and the cashier of branch 3 — the account that could read the
--    whole company before this policy existed.
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"5c300000-0000-4000-8000-000000000004","role":"authenticated","aud":"authenticated"}', true);

do $$
declare n int;
begin
  select count(*) into n from public.coupon_redemptions
   where id = '9e100000-0000-4000-8000-000000000002';
  if n <> 1 then
    raise exception 'FAIL 2a: the branch-2 staff cannot read its own redemption';
  end if;
  select count(*) into n from public.coupon_redemptions
   where id in ('9e100000-0000-4000-8000-000000000001',
                '9e100000-0000-4000-8000-000000000003');
  if n <> 0 then
    raise exception 'FAIL 2a: the branch-2 staff reads % rows of other branches', n;
  end if;
end $$;

select set_config('request.jwt.claims',
  '{"sub":"5c300000-0000-4000-8000-000000000005","role":"authenticated","aud":"authenticated"}', true);

do $$
declare n int;
begin
  select count(*) into n from public.coupon_redemptions
   where id = '9e100000-0000-4000-8000-000000000003';
  if n <> 1 then
    raise exception 'FAIL 2b: the branch-3 cashier cannot read its own redemption';
  end if;
  select count(*) into n from public.coupon_redemptions
   where id in ('9e100000-0000-4000-8000-000000000001',
                '9e100000-0000-4000-8000-000000000002');
  if n <> 0 then
    raise exception 'FAIL 2c: the branch-3 cashier reads % rows of other branches', n;
  end if;
  select count(*) into n from public.coupon_redemptions
   where id = '9e100000-0000-4000-8000-000000000003'
     and user_id = '5c200000-0000-4000-8000-000000000002'
     and amount = 30.00;
  if n <> 1 then
    raise exception 'FAIL 2c: the row the branch-3 cashier reads is not the fixture row';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 3. A global scope still reads everything: manager with a NULL branch row, then
--    the owner. Without these two assertions the change could be "nobody sees
--    anything" and still pass sections 1, 2 and 4.
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"5c300000-0000-4000-8000-000000000002","role":"authenticated","aud":"authenticated"}', true);

do $$
declare n int;
begin
  select count(*) into n from public.coupon_redemptions
   where id in ('9e100000-0000-4000-8000-000000000001',
                '9e100000-0000-4000-8000-000000000002',
                '9e100000-0000-4000-8000-000000000003');
  if n <> 3 then
    raise exception 'FAIL 3a: the global manager reads % of the three fixture rows', n;
  end if;
end $$;

select set_config('request.jwt.claims',
  '{"sub":"5c300000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);

do $$
declare n int;
begin
  select count(*) into n from public.coupon_redemptions
   where id in ('9e100000-0000-4000-8000-000000000001',
                '9e100000-0000-4000-8000-000000000002',
                '9e100000-0000-4000-8000-000000000003');
  if n <> 3 then
    raise exception 'FAIL 3b: the owner reads % of the three fixture rows', n;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 4. Nothing new was opened: an active staff member without orders.read and an
--    invited staff member with it both read zero rows.
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"5c300000-0000-4000-8000-000000000006","role":"authenticated","aud":"authenticated"}', true);

do $$
declare n int;
begin
  select count(*) into n from public.coupon_redemptions
   where id in ('9e100000-0000-4000-8000-000000000001',
                '9e100000-0000-4000-8000-000000000002',
                '9e100000-0000-4000-8000-000000000003');
  if n <> 0 then
    raise exception 'FAIL 4a: a staff member without orders.read sees % fixture rows', n;
  end if;
end $$;

select set_config('request.jwt.claims',
  '{"sub":"5c300000-0000-4000-8000-000000000007","role":"authenticated","aud":"authenticated"}', true);

do $$
declare n int;
begin
  select count(*) into n from public.coupon_redemptions
   where id in ('9e100000-0000-4000-8000-000000000001',
                '9e100000-0000-4000-8000-000000000002',
                '9e100000-0000-4000-8000-000000000003');
  if n <> 0 then
    raise exception 'FAIL 4b: an invited staff member sees % fixture rows', n;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 5. The customer half is untouched: coupon_redemptions_select_own (022:76-78)
--    is a second permissive policy and Postgres unions them. Customer One sees
--    their own two rows across two branches even though they manage nothing.
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"5c200000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);

do $$
declare n int;
begin
  select count(*) into n from public.coupon_redemptions
   where id in ('9e100000-0000-4000-8000-000000000001',
                '9e100000-0000-4000-8000-000000000002',
                '9e100000-0000-4000-8000-000000000003');
  if n <> 2 then
    raise exception 'FAIL 5: the customer reads % of their own two fixture redemptions', n;
  end if;
  if exists (select 1 from public.coupon_redemptions
              where id in ('9e100000-0000-4000-8000-000000000001',
                           '9e100000-0000-4000-8000-000000000002',
                           '9e100000-0000-4000-8000-000000000003')
                and user_id <> auth.uid()) then
    raise exception 'FAIL 5: the customer read a redemption that is not theirs';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 6. anon still reads nothing (032:235 + 032:238 revoke the view from it).
-- ---------------------------------------------------------------------------
reset role;
set local role anon;

do $$
begin
  if exists (select 1 from public.coupon_redemptions
              where id in ('9e100000-0000-4000-8000-000000000001',
                           '9e100000-0000-4000-8000-000000000002',
                           '9e100000-0000-4000-8000-000000000003')) then
    raise exception 'FAIL 6: anon read a fixture coupon redemption';
  end if;
exception
  when insufficient_privilege then
    -- Also the correct answer: 032:230-238 revokes the view from anon.
    null;
end $$;

set local role authenticated;

-- ---------------------------------------------------------------------------
-- 7. No write path appeared with the policy change: a client still cannot forge
--    a redemption row, whatever its branch scope.
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"5c300000-0000-4000-8000-000000000003","role":"authenticated","aud":"authenticated"}', true);

do $$
begin
  insert into public.coupon_redemptions (coupon_id, user_id, order_id, amount)
  values ('3f100000-0000-4000-8000-000000000001', '5c200000-0000-4000-8000-000000000001',
          '6b400000-0000-4000-8000-000000000003', 99.00);
  raise exception 'FAIL 7: an in-scope manager inserted a redemption row';
exception
  when insufficient_privilege or check_violation or integrity_constraint_violation then
    if sqlstate <> '42501' then
      raise exception 'FAIL 7: the insert was refused by % / %, expected 42501', sqlstate, sqlerrm;
    end if;
end $$;

-- ---------------------------------------------------------------------------
-- 8. The coupons screen did not lose anything: admin_coupon_metrics() reads the
--    table inside a security definer body behind settings.write, so RLS cannot
--    narrow it — and a branch manager still cannot call it at all.
-- ---------------------------------------------------------------------------
-- Section 7 left branch 1's manager in the claims; the metrics call needs the
-- global manager, so it gets its own statement outside the block.
select set_config('request.jwt.claims',
  '{"sub":"5c300000-0000-4000-8000-000000000002","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v jsonb;
begin
  v := public.admin_coupon_metrics();
  if v is null then
    raise exception 'FAIL 8a: the global manager got no coupon metrics';
  end if;
  if (v ->> 'discount_given')::numeric < 60.00 then
    raise exception 'FAIL 8a: the definer metrics see % discount given, less than the 60.00 of these fixtures',
      v ->> 'discount_given';
  end if;
  if (v ->> 'redemptions')::numeric < 3 then
    raise exception 'FAIL 8a: the definer metrics count % redemptions, fewer than these three fixtures',
      v ->> 'redemptions';
  end if;
end $$;

select set_config('request.jwt.claims',
  '{"sub":"5c300000-0000-4000-8000-000000000003","role":"authenticated","aud":"authenticated"}', true);

do $$
begin
  perform public.admin_coupon_metrics();
  raise exception 'FAIL 8b: a branch manager ran the settings.write metrics';
exception
  when others then
    if sqlstate <> '42501' then raise; end if;
    if sqlerrm not like '%missing permission: settings.write%' then raise; end if;
end $$;

-- ---------------------------------------------------------------------------
-- 9. The catalog states the new shape, so a later out-of-band paste cannot
--    quietly restore the bare permission predicate.
-- ---------------------------------------------------------------------------
reset role;

do $$
declare v text;
declare n int;
begin
  select pg_get_expr(pol.polqual, pol.polrelid) into v
    from pg_policy pol
    join pg_class c on c.oid = pol.polrelid
    join pg_namespace ns on ns.oid = c.relnamespace
   where ns.nspname = 'marketing' and c.relname = 'coupon_redemptions'
     and pol.polname = 'coupon_redemptions_select_staff';
  if not found then
    raise exception 'FAIL 9a: the staff policy is gone from the table';
  end if;
  if v is null or v not like '%can_manage_branch%' then
    raise exception 'FAIL 9a: the staff policy has no branch scope: %', v;
  end if;
  if v not like '%orders.read%' then
    raise exception 'FAIL 9b: the staff policy dropped the permission check it must keep: %', v;
  end if;
  if v like '%id = coupon_redemptions.user_id%' and v not like '%order_id%' then
    raise exception 'FAIL 9c: the staff policy reads the customer column instead of the order';
  end if;

  select count(*) into n
    from pg_policy pol
    join pg_class c on c.oid = pol.polrelid
    join pg_namespace ns on ns.oid = c.relnamespace
   where ns.nspname = 'marketing' and c.relname = 'coupon_redemptions';
  if n <> 2 then
    raise exception 'FAIL 9d: the table has % policies, expected exactly own + staff', n;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 10. Why the EXISTS cannot hide every row by accident: order_id is not null and
--     cascades with the order, so there is no redemption without an order to
--     price its branch against.
-- ---------------------------------------------------------------------------
do $$
declare n int;
begin
  select count(*) into n
    from marketing.coupon_redemptions r
    left join orders.orders o on o.id = r.order_id
   where o.id is null;
  if n <> 0 then
    raise exception 'FAIL 10: % redemption row(s) have no order, so the new EXISTS would hide them forever', n;
  end if;
end $$;

-- Every section above raises on the first mismatch, so reaching this line is
-- itself the proof. The counts below are the report a runner prints; they measure
-- only the fixture ids, because a real database already holds redemptions.
reset role;

select
  'reached the end: no assertion failed' as verdict,
  (select count(*) from marketing.coupon_redemptions r
     join orders.orders o on o.id = r.order_id
    where o.branch_id = '3c100000-0000-4000-8000-000000000001') as branch_1_rows,
  (select count(*) from marketing.coupon_redemptions r
     join orders.orders o on o.id = r.order_id
    where o.branch_id = '3c200000-0000-4000-8000-000000000002') as branch_2_rows,
  (select count(*) from marketing.coupon_redemptions r
     join orders.orders o on o.id = r.order_id
    where o.branch_id = '3c300000-0000-4000-8000-000000000003') as branch_3_rows,
  (select pg_get_expr(pol.polqual, pol.polrelid)
     from pg_policy pol
     join pg_class c on c.oid = pol.polrelid
     join pg_namespace ns on ns.oid = c.relnamespace
    where ns.nspname = 'marketing' and c.relname = 'coupon_redemptions'
      and pol.polname = 'coupon_redemptions_select_staff') as staff_predicate;

rollback;
