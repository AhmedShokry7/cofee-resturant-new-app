-- admin_orders_branch_scope_test.sql
-- Behaviour tests for the branch isolation of public.admin_orders() and
-- public.admin_payments(), as fixed in the chain by
-- 186_admin_orders_payments_branch_scope.sql.  That file now matches what is
-- deployed, where the payments predicate is the strict
-- "where identity.can_manage_branch(o.branch_id)": a tender that belongs to no
-- order belongs to no branch, so only staff with a null-branch role row see it.
-- Section 2, 3 and 9 assert that, and section 4 asserts the global staff member
-- still sees every row.
--
-- RUN THIS ONLY AGAINST AN ISOLATED, NON-PRODUCTION DATABASE.
--
-- Every assertion runs as the real anon/authenticated role with real JWT claims,
-- exactly like update_order_status_authorization_test.sql. All fixtures live in
-- one transaction that is rolled back, so nothing is left behind.
--
-- This file is plain SQL on purpose: paste it into the Supabase SQL Editor or
-- run it with psql. Nothing outside a transaction is written, and an error
-- leaves the transaction aborted so the final rollback still cleans up.
--
-- PREREQUISITES: migrations 011, 013, 074, 075, 123, 137, 176 and 178 must be
-- applied in this database. 176 and 178 are the bodies this test treats as the
-- shape contract.

begin;

-- ---------------------------------------------------------------------------
-- Fixtures: four branches, three orders, three tenders, six staff members
-- ---------------------------------------------------------------------------
insert into core.branches (id, brand_id, code, name_ar, name_en, address, is_active, settings)
values
  ('3b100000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000001', 'BS-B1', 'فرع 1', 'Branch 1', 'addr1', true, '{}'::jsonb),
  ('3b200000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000001', 'BS-B2', 'فرع 2', 'Branch 2', 'addr2', true, '{}'::jsonb),
  ('3b300000-0000-4000-8000-000000000003', '00000000-0000-4000-8000-000000000001', 'BS-B3', 'فرع 3', 'Branch 3', 'addr3', true, '{}'::jsonb),
  ('3b400000-0000-4000-8000-000000000004', '00000000-0000-4000-8000-000000000001', 'BS-B4', 'فرع 4', 'Branch 4', 'addr4', true, '{}'::jsonb);

insert into auth.users (id, email)
values
  ('5c000000-0000-4000-8000-000000000001', 'bs-customer@test.local'),
  ('5c000000-0000-4000-8000-000000000002', 'bs-subscriber@test.local'),
  ('5a000000-0000-4000-8000-000000000001', 'bs-branch-a@test.local'),
  ('5a000000-0000-4000-8000-000000000002', 'bs-multi@test.local'),
  ('5a000000-0000-4000-8000-000000000003', 'bs-global@test.local'),
  ('5a000000-0000-4000-8000-000000000004', 'bs-inactive@test.local'),
  ('5a000000-0000-4000-8000-000000000005', 'bs-nopayments@test.local'),
  ('5a000000-0000-4000-8000-000000000006', 'bs-emptybranch@test.local');

insert into identity.profiles (id, full_name, email, phone)
values
  ('5c000000-0000-4000-8000-000000000001', 'BS Customer', 'bs-customer@test.local', '0500000001'),
  ('5c000000-0000-4000-8000-000000000002', 'BS Subscriber', 'bs-subscriber@test.local', '0500000002')
on conflict (id) do nothing;

insert into identity.staff_members (id, user_id, status, full_name, email)
values
  ('51000000-0000-4000-8000-000000000001', '5a000000-0000-4000-8000-000000000001', 'active',   'BS Branch A',   'bs-branch-a@test.local'),
  ('51000000-0000-4000-8000-000000000002', '5a000000-0000-4000-8000-000000000002', 'active',   'BS Multi',      'bs-multi@test.local'),
  ('51000000-0000-4000-8000-000000000003', '5a000000-0000-4000-8000-000000000003', 'active',   'BS Global',     'bs-global@test.local'),
  ('51000000-0000-4000-8000-000000000004', '5a000000-0000-4000-8000-000000000004', 'invited',  'BS Inactive',   'bs-inactive@test.local'),
  ('51000000-0000-4000-8000-000000000005', '5a000000-0000-4000-8000-000000000005', 'active',   'BS NoPayments', 'bs-nopayments@test.local'),
  ('51000000-0000-4000-8000-000000000006', '5a000000-0000-4000-8000-000000000006', 'active',   'BS EmptyBranch', 'bs-emptybranch@test.local');

-- One branch only. 'cashier', not 'branch_manager': the deployed matrix of
-- 137_reference_data.sql gives branch_manager orders.read but NOT payments.read,
-- so only cashier / manager / owner can reach admin_payments at all.
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '51000000-0000-4000-8000-000000000001', r.id, '3b100000-0000-4000-8000-000000000001'::uuid
from identity.roles r where r.code = 'cashier';

-- Two branches, and deliberately not the third or the fourth. identity.staff_roles
-- has primary key (staff_id, role_id) (004_identity_02_rbac.sql:75) and no
-- staff/branch join table exists, so one role row can carry only one branch (or
-- null = all). A real multi-branch staff member is therefore modelled as two
-- DIFFERENT roles, and that is what this fixture does.
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '51000000-0000-4000-8000-000000000002', r.id, '3b100000-0000-4000-8000-000000000001'::uuid
from identity.roles r where r.code = 'branch_manager';

insert into identity.staff_roles (staff_id, role_id, branch_id)
select '51000000-0000-4000-8000-000000000002', r.id, '3b200000-0000-4000-8000-000000000002'::uuid
from identity.roles r where r.code = 'cashier';

-- Every branch, because the role row carries a null branch.
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '51000000-0000-4000-8000-000000000003', r.id, null
from identity.roles r where r.code = 'manager';

-- Invited, never activated: identity.is_staff() must refuse this one.
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '51000000-0000-4000-8000-000000000004', r.id, null
from identity.roles r where r.code = 'manager';

-- 'staff' holds orders.read but NOT payments.read (137:80-90).
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '51000000-0000-4000-8000-000000000005', r.id, '3b100000-0000-4000-8000-000000000001'::uuid
from identity.roles r where r.code = 'staff';

-- A branch that holds no order and no tender at all, for the empty-result case.
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '51000000-0000-4000-8000-000000000006', r.id, '3b400000-0000-4000-8000-000000000004'::uuid
from identity.roles r where r.code = 'cashier';

-- placed_at is distinct on purpose: the directory sorts by it and the test
-- asserts that sort survived the new where clause.
insert into orders.orders (
  id, order_number, user_id, branch_id, fulfillment_type, status, payment_status,
  subtotal, discount_total, delivery_fee, tax_total, grand_total, currency_code,
  customer_note, placed_at, loyalty_points_earned, idempotency_key
)
values
  ('6b100000-0000-4000-8000-000000000001', 'TEST-BS-1',
   '5c000000-0000-4000-8000-000000000001', '3b100000-0000-4000-8000-000000000001',
   'pickup', 'pending', 'unpaid', 10.00, 0.00, 0.00, 0.00, 10.00, 'SAR', 'bs',
   '2026-01-01T00:00:00Z', 0, 'bs-test-key-1'),
  ('6b200000-0000-4000-8000-000000000002', 'TEST-BS-2',
   '5c000000-0000-4000-8000-000000000001', '3b200000-0000-4000-8000-000000000002',
   'pickup', 'pending', 'unpaid', 20.00, 0.00, 0.00, 0.00, 20.00, 'SAR', 'bs',
   '2026-01-02T00:00:00Z', 0, 'bs-test-key-2'),
  ('6b300000-0000-4000-8000-000000000003', 'TEST-BS-3',
   '5c000000-0000-4000-8000-000000000001', '3b300000-0000-4000-8000-000000000003',
   'pickup', 'pending', 'paid', 30.00, 0.00, 0.00, 0.00, 30.00, 'SAR', 'bs',
   '2026-01-03T00:00:00Z', 0, 'bs-test-key-3');

-- A subscription plan and purchase, so one tender can exist with no order and
-- therefore no branch anywhere (075 dropped the NOT NULL and made exactly one
-- of the two targets required).
insert into subscriptions.plans (id, code, name_ar, name_en, price, currency_code)
values ('70000000-0000-4000-8000-0000000000c1', 'BS-PLAN', 'خطة اختبار', 'BS plan', 99.00, 'SAR');

insert into subscriptions.subscriptions (id, user_id, plan_id, ends_at, idempotency_key)
values ('70000000-0000-4000-8000-0000000000c2',
        '5c000000-0000-4000-8000-000000000002',
        '70000000-0000-4000-8000-0000000000c1',
        '2026-12-31T00:00:00Z', 'bs-test-sub-1');

insert into payments.payment_transactions
  (id, order_id, subscription_id, provider, amount, currency_code, status,
   card_brand, card_last4, card_holder_name, verified_by_server, created_at)
values
  ('7c100000-0000-4000-8000-000000000001', '6b100000-0000-4000-8000-000000000001', null,
   'tap', 10.00, 'SAR', 'captured', 'visa', '4242', 'BS CARDHOLDER A', true,
   '2026-01-01T00:00:00Z'),
  ('7c200000-0000-4000-8000-000000000002', '6b200000-0000-4000-8000-000000000002', null,
   'tap', 20.00, 'SAR', 'captured', 'mada', '1111', 'BS CARDHOLDER B', true,
   '2026-01-02T00:00:00Z'),
  ('7c300000-0000-4000-8000-000000000003', null, '70000000-0000-4000-8000-0000000000c2',
   'tap', 99.00, 'SAR', 'captured', 'visa', '9999', 'BS SUBSCRIBER CARD', true,
   '2026-01-03T00:00:00Z');

-- The expected totals for case 4 are counted here, while the session is still
-- its owner: once the role below is authenticated, RLS denies a direct read of
-- payments.payment_transactions, so the numbers are handed over as
-- transaction-local settings instead.
select set_config('test.bs_orders',
  ((select count(*) from orders.orders)::int)::text, true);
select set_config('test.bs_tenders',
  ((select count(*) from payments.payment_transactions)::int)::text, true);

set local role authenticated;

-- ---------------------------------------------------------------------------
-- 1. branch A staff sees its own order and nothing of branch B
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"5a000000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v jsonb;
begin
  v := public.admin_orders();
  if jsonb_array_length(v) <> 1 then
    raise exception 'FAIL 1: branch A saw % orders, expected 1', jsonb_array_length(v);
  end if;
  if (v -> 0 ->> 'order_number') <> 'TEST-BS-1' then
    raise exception 'FAIL 1: branch A saw % instead of its own order', v -> 0 ->> 'order_number';
  end if;
  if (v -> 0 ->> 'branch_id') <> '3b100000-0000-4000-8000-000000000001' then
    raise exception 'FAIL 1: branch A received another branch';
  end if;
  if v::text like '%TEST-BS-2%' or v::text like '%TEST-BS-3%' then
    raise exception 'FAIL 1: cross-branch order leaked into admin_orders';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 2. the same staff member gets its own tender, branch B's card data stays
--    away, and the tender of no branch is not reachable from a single branch
--    (can_manage_branch(null) is false unless the role row carries a null
--    branch — the strict predicate the owner chose on 2026-10-27)
-- ---------------------------------------------------------------------------
do $$
declare v jsonb;
begin
  v := public.admin_payments();
  if jsonb_array_length(v) <> 1 then
    raise exception 'FAIL 2: branch A saw % tenders, expected 1 (its own order only)', jsonb_array_length(v);
  end if;
  if v::text like '%TEST-BS-2%' or v::text like '%BS CARDHOLDER B%' then
    raise exception 'FAIL 2: another branch''s card holder name leaked through admin_payments';
  end if;
  if v::text like '%BS SUBSCRIBER CARD%' then
    raise exception 'FAIL 2: a branch-scoped staff member read a tender that belongs to no branch';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 3. multi-branch staff gets exactly the two branches it holds
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"5a000000-0000-4000-8000-000000000002","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v jsonb;
begin
  v := public.admin_orders();
  if jsonb_array_length(v) <> 2 then
    raise exception 'FAIL 3: multi-branch staff saw % orders, expected 2', jsonb_array_length(v);
  end if;
  if (v -> 0 ->> 'order_number') <> 'TEST-BS-2' then
    raise exception 'FAIL 3: newest order must come first, got %', v -> 0 ->> 'order_number';
  end if;
  if v::text like '%TEST-BS-3%' then
    raise exception 'FAIL 3: staff without branch C read a branch C order';
  end if;
  v := public.admin_payments();
  if jsonb_array_length(v) <> 2 then
    raise exception 'FAIL 3: multi-branch staff saw % tenders, expected 2 (one per managed branch)', jsonb_array_length(v);
  end if;
  if v::text like '%BS SUBSCRIBER CARD%' then
    raise exception 'FAIL 3: multi-branch staff read the tender of no branch';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 4. global manager keeps everything, in the same order as before
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"5a000000-0000-4000-8000-000000000003","role":"authenticated","aud":"authenticated"}', true);

do $$
declare
  v        jsonb;
  n        int;
  pos_hi   int;
  pos_mid  int;
  pos_lo   int;
begin
  -- The expected totals came from the transaction-local settings above, not from
  -- hard-coded numbers: this database may already hold real orders, and the point
  -- of the case is that a global staff member sees every one of them.
  v := public.admin_orders();
  n := current_setting('test.bs_orders')::int;
  if jsonb_array_length(v) <> n then
    raise exception 'FAIL 4: global manager saw % orders, expected all %', jsonb_array_length(v), n;
  end if;
  -- placed_at desc, measured between the three fixtures only, because real rows
  -- may be newer than any of them.
  select ord into pos_hi from jsonb_array_elements(v) with ordinality as e(item, ord)
   where item ->> 'order_number' = 'TEST-BS-3';
  select ord into pos_mid from jsonb_array_elements(v) with ordinality as e(item, ord)
   where item ->> 'order_number' = 'TEST-BS-2';
  select ord into pos_lo from jsonb_array_elements(v) with ordinality as e(item, ord)
   where item ->> 'order_number' = 'TEST-BS-1';
  if pos_hi is null or pos_mid is null or pos_lo is null
     or not (pos_hi < pos_mid and pos_mid < pos_lo) then
    raise exception 'FAIL 4: admin_orders no longer sorts by placed_at desc (% / % / %)', pos_hi, pos_mid, pos_lo;
  end if;

  v := public.admin_payments();
  n := current_setting('test.bs_tenders')::int;
  if jsonb_array_length(v) <> n then
    raise exception 'FAIL 4: global manager saw % tenders, expected all %', jsonb_array_length(v), n;
  end if;
  select ord into pos_hi from jsonb_array_elements(v) with ordinality as e(item, ord)
   where item ->> 'id' = '7c300000-0000-4000-8000-000000000003';
  select ord into pos_lo from jsonb_array_elements(v) with ordinality as e(item, ord)
   where item ->> 'id' = '7c100000-0000-4000-8000-000000000001';
  if pos_hi is null or pos_lo is null or pos_hi >= pos_lo then
    raise exception 'FAIL 4: admin_payments no longer sorts by created_at desc';
  end if;
  -- The strict predicate must not cost the global staff anything: the tender of
  -- no branch is theirs, since their role row carries a null branch.
  if v::text not like '%BS SUBSCRIBER CARD%' then
    raise exception 'FAIL 4: the global manager lost the subscription tender';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 5. the shape contract: same 31 order keys, same 20 payment keys, same types
-- ---------------------------------------------------------------------------
do $$
declare
  v        jsonb;
  o_keys   text[] := array[
    'id','order_number','user_id','pos_customer_id','customer_name','customer_email',
    'customer_phone','customer_avatar_url','branch_id','branch_name_ar','branch_name_en',
    'branch_latitude','branch_longitude','fulfillment_type','order_source','table_number',
    'status','payment_method_id','payment_status','subtotal','discount_total',
    'product_discount_total','delivery_fee','tax_total','grand_total','currency_code',
    'customer_note','placed_at','completed_at','delivery_address_snapshot','items'];
  p_keys   text[] := array[
    'id','order_id','order_number','customer_name','provider','provider_reference',
    'method_id','method_code','method_name_ar','method_name_en','amount','currency_code',
    'status','paid_at','refunded_at','card_brand','card_last4','card_holder_name',
    'verified_by_server','created_at'];
  missing  text[];
  extra    text[];
begin
  perform set_config('request.jwt.claims',
    '{"sub":"5a000000-0000-4000-8000-000000000003","role":"authenticated","aud":"authenticated"}', true);

  v := public.admin_orders();
  select array_agg(e) into missing
    from unnest(o_keys) e
   where not exists (select 1 from jsonb_object_keys(v -> 0) k where k = e);
  select array_agg(k) into extra
    from jsonb_object_keys(v -> 0) k
   where not (k = any (o_keys));
  if missing is not null or extra is not null then
    raise exception 'FAIL 5: admin_orders keys changed. missing=% extra=%',
      coalesce(array_to_string(missing, ','), '-'), coalesce(array_to_string(extra, ','), '-');
  end if;
  if cardinality(o_keys) <> 31 then
    raise exception 'FAIL 5: the expected key list itself is wrong';
  end if;
  if jsonb_typeof(v -> 0 -> 'subtotal') <> 'number'
     or jsonb_typeof(v -> 0 -> 'grand_total') <> 'number'
     or jsonb_typeof(v -> 0 -> 'items') <> 'array' then
    raise exception 'FAIL 5: admin_orders value types changed';
  end if;

  v := public.admin_payments();
  select array_agg(e) into missing
    from unnest(p_keys) e
   where not exists (select 1 from jsonb_object_keys(v -> 0) k where k = e);
  select array_agg(k) into extra
    from jsonb_object_keys(v -> 0) k
   where not (k = any (p_keys));
  if missing is not null or extra is not null then
    raise exception 'FAIL 5: admin_payments keys changed. missing=% extra=%',
      coalesce(array_to_string(missing, ','), '-'), coalesce(array_to_string(extra, ','), '-');
  end if;
  if jsonb_typeof(v -> 0 -> 'amount') <> 'number' then
    raise exception 'FAIL 5: admin_payments amount type changed';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 6. a staff role that holds orders.read still reads, but never payments
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"5a000000-0000-4000-8000-000000000005","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v jsonb;
begin
  v := public.admin_orders();
  if jsonb_array_length(v) <> 1 or (v -> 0 ->> 'order_number') <> 'TEST-BS-1' then
    raise exception 'FAIL 6: staff with orders.read lost its own branch order';
  end if;
end $$;

do $$
begin
  perform public.admin_payments();
  raise exception 'FAIL 6: staff without payments.read read every payment';
exception
  when others then
    if sqlstate <> '42501' then raise; end if;
end $$;

-- ---------------------------------------------------------------------------
-- 7. not-an-active-staff and not-authenticated are still refused outright
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"5a000000-0000-4000-8000-000000000004","role":"authenticated","aud":"authenticated"}', true);

do $$
begin
  perform public.admin_orders();
  raise exception 'FAIL 7: an invited staff member read the directory';
exception
  when others then
    if sqlstate <> '42501' then raise; end if;
end $$;

select set_config('request.jwt.claims',
  '{"sub":"5c000000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);

do $$
begin
  perform public.admin_orders();
  raise exception 'FAIL 7: an ordinary customer read the directory';
exception
  when others then
    if sqlstate <> '42501' then raise; end if;
end $$;

do $$
begin
  perform public.admin_payments();
  raise exception 'FAIL 7: an ordinary customer read the payments directory';
exception
  when others then
    if sqlstate <> '42501' then raise; end if;
end $$;

reset role;

set local role anon;

do $$
begin
  perform public.admin_orders();
  raise exception 'FAIL 8: anon executed admin_orders';
exception
  when others then
    if sqlstate <> '42501' then raise; end if;
end $$;

do $$
begin
  perform public.admin_payments();
  raise exception 'FAIL 8: anon executed admin_payments';
exception
  when others then
    if sqlstate <> '42501' then raise; end if;
end $$;

reset role;

-- ---------------------------------------------------------------------------
-- 9. a staff member with no visible order gets [], never null
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"5a000000-0000-4000-8000-000000000006","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v jsonb;
begin
  v := public.admin_orders();
  if v is null or jsonb_typeof(v) <> 'array' or jsonb_array_length(v) <> 0 then
    raise exception 'FAIL 9: admin_orders must return [] for a branch with no order';
  end if;
  -- A tender of no branch is not reachable from branch B4, so this staff member
  -- gets an empty array rather than null or a dropped return.
  v := public.admin_payments();
  if v is null or jsonb_typeof(v) <> 'array' or jsonb_array_length(v) <> 0 then
    raise exception 'FAIL 9: admin_payments must return [] for a branch with no tender';
  end if;
end $$;

reset role;

rollback;
