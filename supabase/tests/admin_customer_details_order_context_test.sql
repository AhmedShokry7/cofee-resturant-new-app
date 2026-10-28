-- admin_customer_details_order_context_test.sql
-- Behaviour test for migration 201: the order objects inside
-- public.admin_customer_details carry the fulfillment type and the branch name
-- the customer dialog's order-history card renders.
--
-- STATUS: EXECUTED, ALL FOUR CASES PASSED, EVERY FIXTURE ROLLED BACK.
--
-- Plain SQL for the Supabase SQL Editor or psql, like the other tests here: one
-- transaction, every fixture rolled back at the end, and the read executed as a
-- real authenticated role with real JWT claims, so the permission arms of the
-- function are tested rather than asserted about.
--
-- WHY THIS NEEDS A TEST AT ALL. The card read three keys - branch_name_ar,
-- branch_name_en, fulfillment_type - and the function returned none of them, so
-- the Dart fell through to whatever its local switch did with an absent value:
-- every order printed "Pickup", including the point-of-sale orders that are
-- dine-in, and the branch never appeared. A payload that quietly lacks a field
-- is exactly the failure a UI-only rehearsal hides, which is how it survived
-- until 201.
--
-- WHAT THE FIXTURES SET UP
--   BR   one active branch, so a missing join cannot be confused with a missing
--        branch name.
--   C    a customer with two orders at BR: one dine_in (what every POS order is)
--        and one pickup, so the test proves the value is carried, not guessed.
--   MGR  a manager (holds customers.read, 137) - the reader.
--   BM   a branch_manager (orders.read but NOT customers.read) - the refusal.
--
-- PREREQUISITES: 004/005/007/011/012/013 (identity, RBAC matrix, branches,
-- orders), 137, 141, 161, 201.

begin;

-- ---------------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------------
insert into core.branches (id, brand_id, code, name_ar, name_en, address, is_active, settings)
values (
  'af100000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000001',
  'ACDO1B1', 'فرع اختبار تفاصيل العميل', 'ACDO Test Branch', 'addr1', true, '{}'::jsonb
);

insert into auth.users (id, email)
values
  ('af500000-0000-4000-8000-000000000001', 'acdo-customer@test.local'),
  ('af600000-0000-4000-8000-000000000001', 'acdo-manager@test.local'),
  ('af600000-0000-4000-8000-000000000002', 'acdo-branch-manager@test.local');

insert into identity.profiles (id, full_name, email, phone)
values ('af500000-0000-4000-8000-000000000001', 'ACDO Customer', 'acdo-customer@test.local', '0500000001')
on conflict (id) do nothing;

insert into identity.staff_members (id, user_id, status, full_name, email)
values
  ('af800000-0000-4000-8000-000000000001', 'af600000-0000-4000-8000-000000000001', 'active', 'ACDO Manager', 'acdo-manager@test.local'),
  ('af800000-0000-4000-8000-000000000002', 'af600000-0000-4000-8000-000000000002', 'active', 'ACDO Branch Manager', 'acdo-branch-manager@test.local');

insert into identity.staff_roles (staff_id, role_id, branch_id)
select 'af800000-0000-4000-8000-000000000001', r.id, 'af100000-0000-4000-8000-000000000001'::uuid
from identity.roles r where r.code = 'manager';

insert into identity.staff_roles (staff_id, role_id, branch_id)
select 'af800000-0000-4000-8000-000000000002', r.id, 'af100000-0000-4000-8000-000000000001'::uuid
from identity.roles r where r.code = 'branch_manager';

-- Both orders at BR with every total zero, so ck_orders_total holds without
-- needing the brand's tax, and neither is cancelled, so the card sees what the
-- dialog actually meets.
insert into orders.orders (
  id, order_number, user_id, branch_id, fulfillment_type, status, payment_status,
  subtotal, discount_total, delivery_fee, tax_total, grand_total, currency_code,
  customer_note, loyalty_points_earned, idempotency_key
) values
  ('af700000-0000-4000-8000-000000000001', 'TEST-ACDO-1',
   'af500000-0000-4000-8000-000000000001', 'af100000-0000-4000-8000-000000000001',
   'dine_in', 'pending', 'unpaid',
   0.00, 0.00, 0.00, 0.00, 0.00, 'SAR', 'acdo dine in', 0, 'acdo-test-key-1'),
  ('af700000-0000-4000-8000-000000000002', 'TEST-ACDO-2',
   'af500000-0000-4000-8000-000000000001', 'af100000-0000-4000-8000-000000000001',
   'pickup', 'pending', 'unpaid',
   0.00, 0.00, 0.00, 0.00, 0.00, 'SAR', 'acdo pickup', 0, 'acdo-test-key-2');

-- The manager's answer is parked in a transaction-local setting before the role
-- changes back, because only the last row-returning statement of the run comes
-- back through the CLI.
set local role authenticated;

select set_config('request.jwt.claims',
  '{"sub":"af600000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);

select set_config(
  'test.acdo_orders',
  coalesce(
    (public.admin_customer_details('af500000-0000-4000-8000-000000000001'::uuid) -> 'orders')::text,
    'null'
  ),
  true
);

reset role;

-- ---------------------------------------------------------------------------
-- 1. Both order rows are present and each carries its own fulfillment type.
-- ---------------------------------------------------------------------------
do $$
declare
  payload_orders jsonb := current_setting('test.acdo_orders')::jsonb;
  reported text;
  kept text;
begin
  if jsonb_array_length(payload_orders) <> 2 then
    raise exception 'FAIL 1: expected two orders in the payload, got %', jsonb_array_length(payload_orders);
  end if;

  select string_agg(e ->> 'fulfillment_type', ',' order by e ->> 'id'),
         string_agg(o.fulfillment_type, ',' order by o.id)
    into reported, kept
    from jsonb_array_elements(payload_orders) e
    join orders.orders o on o.id = (e ->> 'id')::uuid;

  if (select count(*) from jsonb_array_elements(payload_orders) e
       where e ->> 'fulfillment_type' is null) <> 0 then
    raise exception 'FAIL 1: an order reached the card with no fulfillment type';
  end if;
  if reported is distinct from kept then
    raise exception 'FAIL 1: the card reports % where the rows hold %', reported, kept;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 2. The two fixtures differ on purpose, so a constant could not pass: one
--    dine_in and one pickup both appear, exactly once.
-- ---------------------------------------------------------------------------
do $$
declare
  payload_orders jsonb := current_setting('test.acdo_orders')::jsonb;
begin
  if (select count(*) from jsonb_array_elements(payload_orders) e
       where e ->> 'fulfillment_type' = 'dine_in') <> 1 then
    raise exception 'FAIL 2: the dine_in order is not reported as dine_in';
  end if;
  if (select count(*) from jsonb_array_elements(payload_orders) e
       where e ->> 'fulfillment_type' = 'pickup') <> 1 then
    raise exception 'FAIL 2: the pickup order is not reported as pickup';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 3. The branch is named in both languages, from the join, not left null.
-- ---------------------------------------------------------------------------
do $$
declare
  payload_orders jsonb := current_setting('test.acdo_orders')::jsonb;
begin
  if (select count(*) from jsonb_array_elements(payload_orders) e
       where e ->> 'branch_name_ar' = 'فرع اختبار تفاصيل العميل'
         and e ->> 'branch_name_en' = 'ACDO Test Branch') <> 2 then
    raise exception 'FAIL 3: an order reached the card without its branch name';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 4. The guards are untouched: branch_manager (no customers.read) and the
--    customer themselves are both refused, and the rest of the payload keeps
--    its shape.
-- ---------------------------------------------------------------------------
set local role authenticated;

select set_config('request.jwt.claims',
  '{"sub":"af600000-0000-4000-8000-000000000002","role":"authenticated","aud":"authenticated"}', true);

do $$
begin
  begin
    perform public.admin_customer_details('af500000-0000-4000-8000-000000000001'::uuid);
    raise exception 'FAIL 4a: a branch_manager without customers.read read the dialog';
  exception when others then
    if sqlstate <> '42501' then raise; end if;
  end;
end $$;

select set_config('request.jwt.claims',
  '{"sub":"af500000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);

do $$
begin
  begin
    perform public.admin_customer_details('af500000-0000-4000-8000-000000000001'::uuid);
    raise exception 'FAIL 4b: a customer read their own admin dialog';
  exception when others then
    if sqlstate <> '42501' then raise; end if;
  end;
end $$;

reset role;

-- The claims are still the customer's from 4b, and the function reads them
-- through auth.uid() whoever the current role is, so the reader is put back
-- before the shape is checked.
select set_config('request.jwt.claims',
  '{"sub":"af600000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);

do $$
declare
  payload jsonb;
begin
  payload := public.admin_customer_details('af500000-0000-4000-8000-000000000001'::uuid);
  if not (payload ?& array['profile', 'addresses', 'orders', 'subscriptions']) then
    raise exception 'FAIL 4c: the payload lost one of its four sections';
  end if;
  -- The profile row is deliberately not asserted on: a trigger on auth.users
  -- writes the display name from the email, so 'ACDO Customer' never lands.
  if jsonb_array_length(payload -> 'addresses') <> 0
     or jsonb_array_length(payload -> 'subscriptions') <> 0
     or payload -> 'profile' ->> 'id' <> 'af500000-0000-4000-8000-000000000001' then
    raise exception 'FAIL 4c: 201 changed the rest of the payload: %', payload -> 'profile';
  end if;
end $$;

-- Everything above is a fixture inside this transaction.
rollback;
