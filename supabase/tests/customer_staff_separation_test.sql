-- customer_staff_separation_test.sql
-- Behaviour test for 188_separate_customer_and_staff_accounts.sql: the user app
-- reads identity.profiles, the admin app reads identity.staff_members, and an
-- account may belong to one of the two and never to both.
--
-- HOW TO RUN
--   Plain SQL for the Supabase SQL Editor or psql, as the owner role. Everything
--   is inside one transaction that is rolled back, so no fixture survives and the
--   database is unchanged by running it. Against a database without 188 the two
--   triggers are missing and section 3/section 4 fail with "unrecognized
--   configuration parameter" or with no error at all — that is the expected
--   answer, not a bug in this file.
--
-- WHAT EACH SECTION PROVES
--   1  a customer signup still gets its profile (003's trigger is unchanged)
--   2  provisioning that same uid as staff takes it out of the customer table
--   3  a customer row cannot be written for a uid that is already staff
--   4  an ordinary customer keeps working, so 3 is not a blanket refusal
--   5  an account with order history is refused, loudly, instead of silently
--      deleting the row that orders.orders references with ON DELETE RESTRICT
--   6  RBAC is untouched: identity.is_staff() still answers from staff_members,
--      for the staff uid and against the customer uid
--   7  the end-state invariant: the two tables share no uid

begin;

-- ---------------------------------------------------------------------------
-- Fixture: one branch, so section 5 can place a real order.
-- ---------------------------------------------------------------------------
insert into core.branches (id, brand_id, code, name_ar, name_en, address, is_active, settings)
values ('4d100000-0000-4000-8000-000000000001',
        '00000000-0000-4000-8000-000000000001', 'SEP-B1', 'فرع الفصل', 'Sep Branch 1',
        'addr', true, '{}'::jsonb);

-- ---------------------------------------------------------------------------
-- 1. A signup through Supabase Auth creates a customer profile.
-- ---------------------------------------------------------------------------
insert into auth.users (id, email)
values ('7d000000-0000-4000-8000-000000000001', 'sep-customer@test.local');

do $$
begin
  if not exists (
    select 1 from identity.profiles where id = '7d000000-0000-4000-8000-000000000001'
  ) then
    raise exception 'FAIL 1: the signup trigger stopped writing identity.profiles';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 2. The same account is then provisioned as staff — what 080's
--    identity.provision_staff does after the login exists. Its customer row
--    has to go, because it is the signup trigger's side effect, not a customer.
-- ---------------------------------------------------------------------------
insert into identity.staff_members (id, user_id, status, full_name, email)
values ('7f000000-0000-4000-8000-000000000001',
        '7d000000-0000-4000-8000-000000000001', 'invited',
        'Sep Staff', 'sep-customer@test.local');

do $$
begin
  if exists (
    select 1 from identity.profiles where id = '7d000000-0000-4000-8000-000000000001'
  ) then
    raise exception 'FAIL 2: a staff account still has a customer profile row';
  end if;
  if not exists (
    select 1 from identity.staff_members where id = '7f000000-0000-4000-8000-000000000001'
  ) then
    raise exception 'FAIL 2: the staff row itself is missing';
  end if;
  if not exists (
    select 1 from auth.users where id = '7d000000-0000-4000-8000-000000000001'
  ) then
    raise exception 'FAIL 2: the login must survive; only the population changed';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 3. Nothing may put that uid back into the customer table.
-- ---------------------------------------------------------------------------
do $$
begin
  insert into identity.profiles (id, email, full_name)
  values ('7d000000-0000-4000-8000-000000000001', 'sep-customer@test.local', 'Sep Staff');
  raise exception 'FAIL 3: a staff uid was accepted into identity.profiles';
exception
  when others then
    if sqlstate <> '23514' then raise; end if;
    if sqlerrm not like '%cannot also be a customer%' then raise; end if;
end $$;

-- The refused insert left nothing behind.
do $$
begin
  if exists (
    select 1 from identity.profiles where id = '7d000000-0000-4000-8000-000000000001'
  ) then
    raise exception 'FAIL 3: the rejected profile row was kept';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 4. An ordinary account is unaffected.
-- ---------------------------------------------------------------------------
insert into auth.users (id, email)
values ('7d000000-0000-4000-8000-000000000002', 'sep-customer-2@test.local');

do $$
begin
  if not exists (
    select 1 from identity.profiles where id = '7d000000-0000-4000-8000-000000000002'
  ) then
    raise exception 'FAIL 4: a plain customer signup lost its profile';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 5. A real customer with an order cannot be flipped into staff by deleting
--    its history: orders.orders.user_id is the only ON DELETE RESTRICT edge
--    into identity.profiles, so the row must stay and the provisioning must
--    explain itself.
-- ---------------------------------------------------------------------------
insert into auth.users (id, email)
values ('7d000000-0000-4000-8000-000000000003', 'sep-buyer@test.local');

insert into orders.orders (
  id, order_number, user_id, branch_id, fulfillment_type, status, payment_status,
  subtotal, discount_total, delivery_fee, tax_total, grand_total, currency_code,
  customer_note, placed_at, loyalty_points_earned, idempotency_key, order_source
)
values (
  '8c000000-0000-4000-8000-000000000001', 'TEST-SEP-1',
  '7d000000-0000-4000-8000-000000000003', '4d100000-0000-4000-8000-000000000001',
  'dine_in', 'confirmed', 'paid', 40.00, 0.00, 0.00, 0.00, 40.00, 'SAR', 'sep',
  '2026-01-01T10:00:00Z', 0, 'sep-test-key-1', 'online'
);

do $$
begin
  insert into identity.staff_members (id, user_id, status, full_name, email)
  values ('7f000000-0000-4000-8000-000000000003',
          '7d000000-0000-4000-8000-000000000003', 'invited',
          'Sep Buyer As Staff', 'sep-buyer@test.local');
  raise exception 'FAIL 5: an account with orders was turned into staff';
exception
  when others then
    if sqlstate <> '23514' then raise; end if;
    if sqlerrm not like '%has customer orders%' then raise; end if;
end $$;

-- The order and its customer both survived the refused provisioning.
do $$
begin
  if not exists (
    select 1 from identity.profiles where id = '7d000000-0000-4000-8000-000000000003'
  ) then
    raise exception 'FAIL 5: the refused provisioning deleted the customer row';
  end if;
  if not exists (
    select 1 from orders.orders where id = '8c000000-0000-4000-8000-000000000001'
  ) then
    raise exception 'FAIL 5: the refused provisioning deleted the order';
  end if;
  if exists (
    select 1 from identity.staff_members where user_id = '7d000000-0000-4000-8000-000000000003'
  ) then
    raise exception 'FAIL 5: the refused provisioning kept the staff row';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 6. RBAC is untouched. identity.is_staff() (018:13) answers from
--    identity.staff_members under real JWT claims, for both populations. It
--    wants an ACTIVE row, so the invited fixture is activated first — and
--    activation must not put the account back into the customer table.
-- ---------------------------------------------------------------------------
update identity.staff_members
   set status = 'active'
 where id = '7f000000-0000-4000-8000-000000000001';

do $$
begin
  if exists (
    select 1 from identity.profiles where id = '7d000000-0000-4000-8000-000000000001'
  ) then
    raise exception 'FAIL 6: activating a staff account re-created its customer row';
  end if;
end $$;

select set_config('request.jwt.claims',
  '{"sub":"7d000000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);
do $$
begin
  if not identity.is_staff() then
    raise exception 'FAIL 6: a provisioned account is no longer recognised as staff';
  end if;
end $$;

select set_config('request.jwt.claims',
  '{"sub":"7d000000-0000-4000-8000-000000000002","role":"authenticated","aud":"authenticated"}', true);
do $$
begin
  if identity.is_staff() then
    raise exception 'FAIL 6: a plain customer is reported as staff';
  end if;
end $$;

reset role;

-- ---------------------------------------------------------------------------
-- 7. The end state: no uid is in both tables.
-- ---------------------------------------------------------------------------
select
  'reached the end: no assertion failed' as verdict,
  (select count(*)
     from identity.profiles p
     join identity.staff_members s on s.user_id = p.id) as uids_in_both_tables,
  (select count(*) from identity.profiles
     where id in ('7d000000-0000-4000-8000-000000000002',
                  '7d000000-0000-4000-8000-000000000003')) as customers_kept,
  (select count(*) from identity.staff_members
     where id in ('7f000000-0000-4000-8000-000000000001')) as staff_kept,
  (select count(*) from orders.orders
     where order_number = 'TEST-SEP-1') as order_kept;

rollback;
