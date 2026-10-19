-- update_order_status_authorization_test.sql
-- Behaviour tests for orders.update_order_status (migration 079).
--
-- RUN THIS ONLY AGAINST AN ISOLATED, NON-PRODUCTION DATABASE.
--
-- Every access-control assertion runs as the real authenticated/anon roles with
-- real JWT claims. Fixtures live in one transaction that is rolled back.

\set ON_ERROR_STOP on

begin;

-- ---------------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------------
insert into core.branches (id, brand_id, code, name_ar, name_en, address, is_active, settings)
values
  ('33333333-3333-4333-8333-333333333333', '00000000-0000-4000-8000-000000000001', 'B1', 'فرع 1', 'Branch 1', 'addr1', true, '{}'::jsonb),
  ('44444444-4444-4444-8444-444444444444', '00000000-0000-4000-8000-000000000001', 'B2', 'فرع 2', 'Branch 2', 'addr2', true, '{}'::jsonb);

insert into auth.users (id, email)
values
  ('55555555-5555-4555-8555-555555555555', 'uos-customer@test.local'),
  ('66666666-6666-4666-8666-666666666666', 'uos-staff1@test.local'),
  ('77777777-7777-4777-8777-777777777777', 'uos-staff2@test.local'),
  ('99999999-9999-4999-8999-999999999999', 'uos-staff3@test.local');

insert into identity.staff_members (id, user_id, status, full_name, email)
values
  ('60000000-0000-4000-8000-000000000001', '66666666-6666-4666-8666-666666666666', 'active', 'Staff One', 'uos-staff1@test.local'),
  ('70000000-0000-4000-8000-000000000002', '77777777-7777-4777-8777-777777777777', 'active', 'Staff Two', 'uos-staff2@test.local'),
  ('90000000-0000-4000-8000-000000000003', '99999999-9999-4999-8999-999999999999', 'active', 'Staff Three', 'uos-staff3@test.local');

insert into identity.staff_roles (staff_id, role_id, branch_id)
select '60000000-0000-4000-8000-000000000001', r.id, null
from identity.roles r where r.code = 'manager';

insert into identity.staff_roles (staff_id, role_id, branch_id)
select '70000000-0000-4000-8000-000000000002', r.id, '44444444-4444-4444-8444-444444444444'::uuid
from identity.roles r where r.code = 'branch_manager';

insert into identity.staff_roles (staff_id, role_id, branch_id)
select '90000000-0000-4000-8000-000000000003', r.id, null
from identity.roles r where r.code = 'staff';

insert into orders.orders (
  id, order_number, user_id, branch_id, fulfillment_type, status, payment_status,
  subtotal, discount_total, delivery_fee, tax_total, grand_total, currency_code,
  customer_note, loyalty_points_earned, idempotency_key
)
values (
  '88888888-8888-4888-8888-888888888888',
  'TEST-UOS-1',
  '55555555-5555-4555-8555-555555555555',
  '33333333-3333-4333-8333-333333333333',
  'pickup', 'pending', 'unpaid',
  10.00, 0.00, 0.00, 0.00, 10.00, 'SAR',
  'test', 0, 'uos-test-key-1'
);

-- ---------------------------------------------------------------------------
-- 1. anon cannot execute
-- ---------------------------------------------------------------------------
set local role anon;
do $$
begin
  perform public.update_order_status('88888888-8888-4888-8888-888888888888'::uuid, 'confirmed', 'x');
  raise exception 'FAIL: anon call succeeded';
exception
  when others then
    if sqlstate <> '42501' then raise; end if;
end $$;

reset role;

-- ---------------------------------------------------------------------------
-- 2. ordinary customer is rejected
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"55555555-5555-4555-8555-555555555555","role":"authenticated","aud":"authenticated"}', true);

do $$
begin
  perform public.update_order_status('88888888-8888-4888-8888-888888888888'::uuid, 'confirmed', 'x');
  raise exception 'FAIL: customer call succeeded';
exception
  when others then
    if sqlstate <> '42501' then raise; end if;
end $$;

-- ---------------------------------------------------------------------------
-- 3. authorized staff (all branches) can transition pending -> confirmed
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"66666666-6666-4666-8666-666666666666","role":"authenticated","aud":"authenticated"}', true);

select public.update_order_status('88888888-8888-4888-8888-888888888888'::uuid, 'confirmed', 'ok');

do $$
begin
  if (select status from orders.orders where id = '88888888-8888-4888-8888-888888888888'::uuid) <> 'confirmed' then
    raise exception 'FAIL: authorized status update did not apply';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 4. branch-scoped staff cannot manage another branch
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"77777777-7777-4777-8777-777777777777","role":"authenticated","aud":"authenticated"}', true);

do $$
begin
  perform public.update_order_status('88888888-8888-4888-8888-888888888888'::uuid, 'preparing', 'x');
  raise exception 'FAIL: cross-branch staff call succeeded';
exception
  when others then
    if sqlstate <> '42501' then raise; end if;
end $$;

-- ---------------------------------------------------------------------------
-- 5. invalid transition rejected
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"66666666-6666-4666-8666-666666666666","role":"authenticated","aud":"authenticated"}', true);

do $$
begin
  perform public.update_order_status('88888888-8888-4888-8888-888888888888'::uuid, 'completed', 'x');
  raise exception 'FAIL: invalid transition succeeded';
exception
  when others then
    if sqlstate <> '23514' then raise; end if;
end $$;

-- ---------------------------------------------------------------------------
-- 6. staff without orders.status.update is rejected
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"99999999-9999-4999-8999-999999999999","role":"authenticated","aud":"authenticated"}', true);

do $$
begin
  perform public.update_order_status('88888888-8888-4888-8888-888888888888'::uuid, 'preparing', 'x');
  raise exception 'FAIL: permissionless staff call succeeded';
exception
  when others then
    if sqlstate <> '42501' then raise; end if;
end $$;

-- ---------------------------------------------------------------------------
-- 7. cancellation through this RPC is rejected (must use cancel_order)
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"66666666-6666-4666-8666-666666666666","role":"authenticated","aud":"authenticated"}', true);

do $$
begin
  perform public.update_order_status('88888888-8888-4888-8888-888888888888'::uuid, 'cancelled', 'x');
  raise exception 'FAIL: cancellation via status RPC succeeded';
exception
  when others then
    if sqlstate <> '23514' then raise; end if;
end $$;

reset role;

rollback;
