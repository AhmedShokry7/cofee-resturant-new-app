-- pos_shift_cash_out_guard_test.sql
-- Behaviour test for the drawer guard of 187_pos_shift_cash_out_guard.sql, on
-- top of the shift model of 182_admin_pos_cashier_shifts.sql.
--
-- STATUS: EXECUTED AND PASSED on 2026-10-28 against the live project
-- webzzasosevzymftgszn, inside the rolled-back transaction below. The report
-- row came back as:
--   verdict = 'reached the end: no assertion failed', movements_kept = 4,
--   what_was_booked = 'cash_in 25.00, cash_out 325.00, cash_in 60.00,
--   cash_out 60.00', final_shift_status = 'closed'
--
-- RUN THIS ONLY AGAINST AN ISOLATED, NON-PRODUCTION DATABASE, and only after
-- BOTH 182 (which creates payments.pos_shifts, payments.pos_shift_movements,
-- orders.orders.pos_shift_id, payments.pos_shift_totals and the six shift RPCs)
-- AND the 187 guard above have been applied. Against a database without 182 the
-- fixtures fail with 42P01, which is the expected answer, not a bug in the test.
--
-- Like admin_orders_branch_scope_test.sql: plain SQL for the Supabase SQL Editor
-- or psql, every fixture inside one transaction that is rolled back, and every
-- assertion executed as the real authenticated role with real JWT claims so the
-- authorization arms are tested rather than asserted about.
--
-- WHAT IS NOT TESTED HERE, AND WHY
--   Concurrency. A single-session script cannot observe the lock: the guard's
--   safety comes from the FOR UPDATE this function already takes on the shift
--   row conflicting with the FOR SHARE the checkout takes (182:842) and from two
--   paid-outs serialising against each other. Proving that needs two live
--   sessions against a scratch database (session A holds a movement open inside
--   its transaction while session B tries the same shift), which is a manual
--   rehearsal, not a file like this one. It is deliberately NOT simulated here,
--   because a test that only re-reads the same totals twice would pass no matter
--   whether the lock existed.
--
-- PREREQUISITES: 004/011/013/021/123/137 (identity, RBAC matrix, orders and
-- payments), 178 (payment_transactions.method_id), 182, and 187.

begin;

-- ---------------------------------------------------------------------------
-- Fixtures: two branches, one open drawer with a counter sale and a paid-in,
-- one closed drawer, and four staff members with different reach.
-- ---------------------------------------------------------------------------
insert into core.branches (id, brand_id, code, name_ar, name_en, address, is_active, settings)
values
  ('4c100000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000001', 'DG-B1', 'فرع الحرس 1', 'Guard Branch 1', 'addr1', true, '{}'::jsonb),
  ('4c200000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000001', 'DG-B2', 'فرع الحرس 2', 'Guard Branch 2', 'addr2', true, '{}'::jsonb);

insert into auth.users (id, email)
values
  ('5f000000-0000-4000-8000-000000000001', 'dg-customer@test.local'),
  ('5e000000-0000-4000-8000-000000000001', 'dg-cashier-1@test.local'),
  ('5e000000-0000-4000-8000-000000000002', 'dg-cashier-2@test.local'),
  ('5e000000-0000-4000-8000-000000000003', 'dg-noperm@test.local'),
  ('5e000000-0000-4000-8000-000000000004', 'dg-invited@test.local');

insert into identity.profiles (id, full_name, email, phone)
values ('5f000000-0000-4000-8000-000000000001', 'DG Customer', 'dg-customer@test.local', '0500000001')
on conflict (id) do nothing;

insert into identity.staff_members (id, user_id, status, full_name, email)
values
  ('61000000-0000-4000-8000-000000000001', '5e000000-0000-4000-8000-000000000001', 'active',  'DG Cashier 1', 'dg-cashier-1@test.local'),
  ('61000000-0000-4000-8000-000000000002', '5e000000-0000-4000-8000-000000000002', 'active',  'DG Cashier 2', 'dg-cashier-2@test.local'),
  ('61000000-0000-4000-8000-000000000003', '5e000000-0000-4000-8000-000000000003', 'active',  'DG NoPerm',    'dg-noperm@test.local'),
  ('61000000-0000-4000-8000-000000000004', '5e000000-0000-4000-8000-000000000004', 'invited', 'DG Invited',   'dg-invited@test.local');

-- 'cashier' holds pos.manage in 137_reference_data.sql, which is the same
-- permission the counter itself needs: whoever can sell can open a drawer.
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '61000000-0000-4000-8000-000000000001', r.id, '4c100000-0000-4000-8000-000000000001'::uuid
from identity.roles r where r.code = 'cashier';

insert into identity.staff_roles (staff_id, role_id, branch_id)
select '61000000-0000-4000-8000-000000000002', r.id, '4c200000-0000-4000-8000-000000000002'::uuid
from identity.roles r where r.code = 'cashier';

-- Branch 1, but the 'staff' role carries no pos.manage.
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '61000000-0000-4000-8000-000000000003', r.id, '4c100000-0000-4000-8000-000000000001'::uuid
from identity.roles r where r.code = 'staff';

insert into identity.staff_roles (staff_id, role_id, branch_id)
select '61000000-0000-4000-8000-000000000004', r.id, '4c100000-0000-4000-8000-000000000001'::uuid
from identity.roles r where r.code = 'cashier';

-- The open drawer: 200.00 float. A 100.00 cash counter sale and a 25.00 paid-in
-- follow below, so the available cash is 325.00 and every withdrawal assertion
-- exercises cash_sales, cash_in and cash_out together.
insert into payments.pos_shifts (id, branch_id, status, opening_float, opened_by, note)
values ('7a000000-0000-4000-8000-000000000001', '4c100000-0000-4000-8000-000000000001',
        'open', 200.00, '61000000-0000-4000-8000-000000000001', 'DG open shift');

-- A closed drawer on the other branch, for the "shift is closed" arm. Its Z
-- snapshot must satisfy ck_pos_shift_closed and ck_pos_shift_variance.
insert into payments.pos_shifts (
  id, branch_id, status, opening_float, opened_by, note,
  closed_by, closed_at, cash_sales, card_sales, sales_total, order_count,
  cash_in_total, cash_out_total, expected_cash, counted_cash, variance, close_note
)
values (
  '7a000000-0000-4000-8000-000000000002', '4c200000-0000-4000-8000-000000000002',
  'closed', 100.00, '61000000-0000-4000-8000-000000000002', 'DG closed shift',
  '61000000-0000-4000-8000-000000000002', '2026-01-01T12:00:00Z',
  100.00, 0.00, 100.00, 1,
  0.00, 0.00, 100.00, 100.00, 0.00, 'counted'
);

-- The counter sale the drawer actually holds: a pos order with one captured
-- pos_counter cash tender, joined to the open shift.
insert into orders.orders (
  id, order_number, user_id, branch_id, fulfillment_type, status, payment_status,
  subtotal, discount_total, delivery_fee, tax_total, grand_total, currency_code,
  customer_note, placed_at, loyalty_points_earned, idempotency_key,
  order_source, pos_shift_id
)
values (
  '8b000000-0000-4000-8000-000000000001', 'TEST-DG-1',
  '5f000000-0000-4000-8000-000000000001', '4c100000-0000-4000-8000-000000000001',
  'dine_in', 'confirmed', 'paid', 100.00, 0.00, 0.00, 0.00, 100.00, 'SAR', 'dg',
  '2026-01-01T10:00:00Z', 0, 'dg-test-key-1',
  'pos', '7a000000-0000-4000-8000-000000000001'
);

insert into payments.payment_transactions (
  id, order_id, provider, method_id, amount, currency_code, status,
  paid_at, verified_by_server, created_at
)
values (
  '9c000000-0000-4000-8000-000000000001', '8b000000-0000-4000-8000-000000000001',
  'pos_counter', (select id from payments.payment_methods where code = 'cash'),
  100.00, 'SAR', 'captured', '2026-01-01T10:00:00Z', true, '2026-01-01T10:00:00Z'
);

insert into payments.pos_shift_movements (id, shift_id, kind, amount, reason, created_by)
values ('9d000000-0000-4000-8000-000000000001', '7a000000-0000-4000-8000-000000000001',
        'cash_in', 25.00, 'DG float top-up', '61000000-0000-4000-8000-000000000001');

set local role authenticated;

-- ---------------------------------------------------------------------------
-- 1. the starting balance is float + cash sales + paid-in = 325.00
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"5e000000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v jsonb;
begin
  v := public.admin_pos_shift('4c100000-0000-4000-8000-000000000001');
  if v is null then
    raise exception 'FAIL 1: the open shift of branch 1 is not readable';
  end if;
  if (v ->> 'expected_cash')::numeric <> 325.00 then
    raise exception 'FAIL 1: expected cash is %, expected 325.00', v ->> 'expected_cash';
  end if;
  if (v ->> 'cash_sales')::numeric <> 100.00 or (v ->> 'cash_in')::numeric <> 25.00 then
    raise exception 'FAIL 1: the drawer does not carry its sale and paid-in (cash %, in %)',
      v ->> 'cash_sales', v ->> 'cash_in';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 2. a withdrawal larger than the drawer is rejected, with the specific message
-- ---------------------------------------------------------------------------
do $$
declare v jsonb;
begin
  v := public.admin_pos_record_cash_movement(
    '7a000000-0000-4000-8000-000000000001', 'cash_out', 325.01, 'DG over withdrawal');
  raise exception 'FAIL 2: the guard accepted a withdrawal of 325.01 over 325.00';
exception
  when others then
    if sqlstate <> '22023' then raise; end if;
    if sqlerrm not like '%cash out exceeds the drawer%' then raise; end if;
end $$;

-- ---------------------------------------------------------------------------
-- 3. the rejection changes nothing: no movement row, no drawer, no report
-- ---------------------------------------------------------------------------
do $$
declare before_ jsonb; after_ jsonb;
begin
  before_ := public.admin_pos_shift('4c100000-0000-4000-8000-000000000001');
  begin
    perform public.admin_pos_record_cash_movement(
      '7a000000-0000-4000-8000-000000000001', 'cash_out', 999.00, 'DG rejected');
  exception
    when others then
      if sqlstate <> '22023' then raise; end if;
  end;
  after_ := public.admin_pos_shift('4c100000-0000-4000-8000-000000000001');
  if before_ is null or after_ is null then
    raise exception 'FAIL 3: the shift report vanished around the rejected call';
  end if;
  if before_::text <> after_::text then
    raise exception 'FAIL 3: a rejected paid-out changed the drawer';
  end if;
  if jsonb_array_length(after_ -> 'movements') <> 1 then
    raise exception 'FAIL 3: the rejected paid-out left a movement row (% rows)',
      jsonb_array_length(after_ -> 'movements');
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 4. a withdrawal equal to the available cash still succeeds: the guard rejects
--    only a negative balance, and expected_cash >= 0 holds at zero.
-- ---------------------------------------------------------------------------
do $$
declare v jsonb;
begin
  v := public.admin_pos_record_cash_movement(
    '7a000000-0000-4000-8000-000000000001', 'cash_out', 325.00, 'DG empty the drawer');
  if v is null then
    raise exception 'FAIL 4: the exact-balance withdrawal returned nothing';
  end if;
  if (v ->> 'expected_cash')::numeric <> 0 then
    raise exception 'FAIL 4: expected cash is %, expected 0', v ->> 'expected_cash';
  end if;
  if (v ->> 'cash_out')::numeric <> 325.00 then
    raise exception 'FAIL 4: cash_out is %, expected 325.00', v ->> 'cash_out';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 5. one cent over the now-empty drawer is rejected again, so the guard reads
--    the live balance instead of the opening float.
-- ---------------------------------------------------------------------------
do $$
begin
  perform public.admin_pos_record_cash_movement(
    '7a000000-0000-4000-8000-000000000001', 'cash_out', 0.01, 'DG one cent too much');
  raise exception 'FAIL 5: the guard accepted a withdrawal from an empty drawer';
exception
  when others then
    if sqlstate <> '22023' then raise; end if;
    if sqlerrm not like '%cash out exceeds the drawer%' then raise; end if;
end $$;

-- ---------------------------------------------------------------------------
-- 6. cash-in is not blocked by the guard and immediately restores the balance
-- ---------------------------------------------------------------------------
do $$
declare v jsonb;
begin
  v := public.admin_pos_record_cash_movement(
    '7a000000-0000-4000-8000-000000000001', 'cash_in', 60.00, 'DG paid back in');
  if (v ->> 'expected_cash')::numeric <> 60.00 then
    raise exception 'FAIL 6: after a paid-in the expected cash is %, expected 60.00',
      v ->> 'expected_cash';
  end if;
  v := public.admin_pos_record_cash_movement(
    '7a000000-0000-4000-8000-000000000001', 'cash_out', 60.00, 'DG takes it back out');
  if (v ->> 'expected_cash')::numeric <> 0 then
    raise exception 'FAIL 6: the paid-in did not become withdrawable cash';
  end if;
  if jsonb_array_length(v -> 'movements') <> 4 then
    raise exception 'FAIL 6: expected 4 movement rows, found %',
      jsonb_array_length(v -> 'movements');
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 7. the authorization arms still fire, in the same order as before the guard:
--    branch scope first, then the permission, then the authentication.
-- ---------------------------------------------------------------------------
-- Cashier of branch 2 reaching the drawer of branch 1.
select set_config('request.jwt.claims',
  '{"sub":"5e000000-0000-4000-8000-000000000002","role":"authenticated","aud":"authenticated"}', true);

do $$
begin
  perform public.admin_pos_record_cash_movement(
    '7a000000-0000-4000-8000-000000000001', 'cash_out', 10.00, 'DG cross branch');
  raise exception 'FAIL 7a: a branch cashier reached another branch drawer';
exception
  when others then
    if sqlstate <> '42501' then raise; end if;
    if sqlerrm not like '%branch out of scope%' then raise; end if;
end $$;

-- Same branch, but a role without pos.manage.
select set_config('request.jwt.claims',
  '{"sub":"5e000000-0000-4000-8000-000000000003","role":"authenticated","aud":"authenticated"}', true);

do $$
begin
  perform public.admin_pos_record_cash_movement(
    '7a000000-0000-4000-8000-000000000001', 'cash_out', 10.00, 'DG no permission');
  raise exception 'FAIL 7b: a staff member without pos.manage recorded a movement';
exception
  when others then
    if sqlstate <> '42501' then raise; end if;
    if sqlerrm not like '%missing permission: pos.manage%' then raise; end if;
end $$;

-- Invited, never activated: not staff at all.
select set_config('request.jwt.claims',
  '{"sub":"5e000000-0000-4000-8000-000000000004","role":"authenticated","aud":"authenticated"}', true);

do $$
begin
  perform public.admin_pos_record_cash_movement(
    '7a000000-0000-4000-8000-000000000001', 'cash_out', 10.00, 'DG invited staff');
  raise exception 'FAIL 7c: an invited staff member recorded a movement';
exception
  when others then
    if sqlstate <> '42501' then raise; end if;
    if sqlerrm not like '%not authenticated%' then raise; end if;
end $$;

-- ---------------------------------------------------------------------------
-- 8. the pre-existing validations are untouched by the guard: a closed shift,
--    a bad kind, a zero amount and an empty reason all keep their own answer,
--    and none of them reaches the drawer check.
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"5e000000-0000-4000-8000-000000000002","role":"authenticated","aud":"authenticated"}', true);

do $$
begin
  perform public.admin_pos_record_cash_movement(
    '7a000000-0000-4000-8000-000000000002', 'cash_out', 10.00, 'DG closed');
  raise exception 'FAIL 8a: a movement was recorded on a closed shift';
exception
  when others then
    if sqlstate <> '23514' then raise; end if;
    if sqlerrm not like '%cashier shift is closed%' then raise; end if;
end $$;

-- The next three are branch 1's own cashier: the branch check runs BEFORE the
-- kind/amount/reason validations, so a branch-2 staff member would only ever
-- prove the branch arm again.
select set_config('request.jwt.claims',
  '{"sub":"5e000000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);

do $$
begin
  perform public.admin_pos_record_cash_movement(
    '7a000000-0000-4000-8000-000000000001', 'cash_split', 10.00, 'DG bad kind');
  raise exception 'FAIL 8b: an unknown movement kind was accepted';
exception
  when others then
    if sqlstate <> '22023' then raise; end if;
    if sqlerrm not like '%invalid cash movement kind%' then raise; end if;
end $$;

do $$
begin
  perform public.admin_pos_record_cash_movement(
    '7a000000-0000-4000-8000-000000000001', 'cash_out', 0.00, 'DG zero amount');
  raise exception 'FAIL 8c: a zero amount was accepted';
exception
  when others then
    if sqlstate <> '22023' then raise; end if;
    if sqlerrm not like '%invalid cash movement amount%' then raise; end if;
end $$;

do $$
begin
  perform public.admin_pos_record_cash_movement(
    '7a000000-0000-4000-8000-000000000001', 'cash_out', 10.00, '   ');
  raise exception 'FAIL 8d: a movement without a reason was accepted';
exception
  when others then
    if sqlstate <> '22023' then raise; end if;
    if sqlerrm not like '%needs a reason%' then raise; end if;
end $$;

-- ---------------------------------------------------------------------------
-- 9. the guard is the last thing standing between the cashier and the close:
--    with the balance protected, admin_pos_close_shift can always write its Z
--    snapshot (the defect this proposal removes was the close failing forever).
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"5e000000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v jsonb;
begin
  v := public.admin_pos_close_shift(
    '7a000000-0000-4000-8000-000000000001', 0.00, 'DG counted empty');
  if v is null or (v ->> 'status') <> 'closed' then
    raise exception 'FAIL 9: the drawer that the guard kept at zero could not be closed';
  end if;
  if (v ->> 'expected_cash')::numeric <> 0 or (v ->> 'variance')::numeric <> 0 then
    raise exception 'FAIL 9: the Z snapshot disagrees (expected %, variance %)',
      v ->> 'expected_cash', v ->> 'variance';
  end if;
  if public.admin_pos_shift('4c100000-0000-4000-8000-000000000001') is not null then
    raise exception 'FAIL 9: branch 1 still reports an open shift after the close';
  end if;
end $$;

-- Only the owner reads these tables — every assertion above ran as the
-- authenticated role, which has no table privileges at all, which is the point.
reset role;

-- Every section above raises on the first mismatch, so reaching this line is
-- itself the proof. This row is the report a runner prints: the movements the
-- accepted calls wrote, and the state the guarded drawer ended in. The
-- transaction still rolls back, so none of this rehearsal stays in the database.
select
  'reached the end: no assertion failed' as verdict,
  (select count(*) from payments.pos_shift_movements
    where shift_id = '7a000000-0000-4000-8000-000000000001') as movements_kept,
  (select string_agg(m.kind || ' ' || m.amount::text, ', ' order by m.created_at)
     from payments.pos_shift_movements m
    where m.shift_id = '7a000000-0000-4000-8000-000000000001') as what_was_booked,
  (select status from payments.pos_shifts
    where id = '7a000000-0000-4000-8000-000000000001') as final_shift_status;

rollback;
