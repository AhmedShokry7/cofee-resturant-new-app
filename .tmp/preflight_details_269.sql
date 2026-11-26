begin;
-- 269_admin_customer_details_staff_guard.sql
--
-- Forward-only repair of live drift in public.admin_customer_details(uuid).
--
-- Migration 211 is recorded as applied and its stored statements contain the
-- staff-account guard, but the live function was the pre-211 definition from
-- 201: it had only the staff/permission checks and no target-account guard.
-- The other 211 changes are live (payments branch scope, POS customer name,
-- payment-status branch scope and the admin_update_customer guard), and no
-- later migration redefines this function. The only consistent explanation is
-- an out-of-band CREATE OR REPLACE using 201's body after 211; created_by is
-- null in the history row, so the actor is not recoverable from the database.
--
-- This migration restores 211's exact function body and security properties.
-- It does not edit 211, rewrite history, change the response contract, add a
-- branch filter that customer profiles never had, or touch business rows.
-- The guard uses the current identity source: identity.staff_members, the same
-- source as identity.is_staff() and the customer list's exclusion rule.
--
-- SECURITY DEFINER, owner postgres, search_path = '', anon/public execute
-- revoked, authenticated execute retained. Internal helpers are not exposed.

create or replace function public.admin_customer_details(p_customer_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('customers.read') then
    raise exception 'missing permission: customers.read' using errcode = '42501';
  end if;
  if exists (
    select 1 from identity.staff_members sm where sm.user_id = p_customer_id
  ) then
    raise exception 'not a customer account' using errcode = '42501';
  end if;

  return (
    select jsonb_build_object(
      'profile', jsonb_build_object(
        'id', p.id,
        'full_name', p.full_name,
        'email', p.email,
        'phone', p.phone,
        'avatar_url', p.avatar_url,
        'language', p.language,
        'last_seen_at', p.last_seen_at,
        'created_at', p.created_at,
        'updated_at', p.updated_at,
        'is_vip', p.is_vip,
        'is_blacklisted', p.is_blacklisted,
        'admin_notes', p.admin_notes
      ),
      'addresses', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', a.id,
          'label', a.label,
          'details', a.details,
          'is_default', a.is_default
        ) order by a.created_at)
        from identity.customer_addresses a
        where a.user_id = p.id and a.archived_at is null
      ), '[]'::jsonb),
      'orders', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', o.id,
          'branch_id', o.branch_id,
          'branch_name_ar', b.name_ar,
          'branch_name_en', b.name_en,
          'fulfillment_type', o.fulfillment_type,
          'status', o.status,
          'grand_total', o.grand_total,
          'placed_at', o.placed_at,
          'items', coalesce((
            select jsonb_agg(jsonb_build_object(
              'product_name_ar', pr2.name_ar,
              'product_name_en', pr2.name_en,
              'quantity', oi.quantity,
              'unit_price', oi.unit_price,
              'line_total', oi.line_total
            ) order by oi.id)
            from orders.order_items oi
            left join catalog.products pr2 on pr2.id = oi.product_id
            where oi.order_id = o.id
          ), '[]'::jsonb)
        ) order by o.placed_at desc)
        from orders.orders o
        left join core.branches b on b.id = o.branch_id
        where o.user_id = p.id
      ), '[]'::jsonb),
      'subscriptions', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', recent.id,
          'status', case
            when recent.status = 'active'
              and recent.ends_at is not null
              and recent.ends_at <= now() then 'expired'
            else recent.status
          end,
          'starts_at', recent.starts_at,
          'ends_at', recent.ends_at,
          'cups_entitled', recent.cups_entitled,
          'cups_used', recent.cups_used,
          'cups_carried_over', recent.cups_carried_over,
          'cups_reserved', recent.cups_reserved,
          'auto_renew', recent.auto_renew,
          'plan', jsonb_build_object(
            'name_ar', pl.name_ar,
            'name_en', pl.name_en
          )
        ) order by recent.created_at desc)
        from (
          select sub.*
            from subscriptions.subscriptions sub
           where sub.user_id = p.id
           order by sub.created_at desc
           limit 20
        ) recent
        left join subscriptions.plans pl on pl.id = recent.plan_id
      ), '[]'::jsonb)
    )
    from identity.profiles p
    where p.id = p_customer_id
  );
end;
$fn$;

comment on function public.admin_customer_details(uuid) is
  'Customer card with profile, addresses, orders and subscriptions. Staff accounts are not customers.';

revoke all on function public.admin_customer_details(uuid) from public, anon;
grant execute on function public.admin_customer_details(uuid) to authenticated;

notify pgrst, 'reload schema';

-- admin_customer_details_guard_test.sql
-- Isolated, rolled-back proof for migration 269.
--
-- Covers the customer-card guard itself: owner/manager allowed, a real
-- customer account readable by staff, staff without customers.read denied,
-- inactive staff denied, a customer caller denied, a staff target denied,
-- anon denied, branch-scoped read behaviour, the exact response contract,
-- and the function's owner/SECURITY DEFINER/search_path/grants.
--
-- Branch scope note: customer profiles are global in 201/211; branch scope
-- applies to orders, payments and carts. This file asserts that no accidental
-- branch filter was added to the customer card. The existing
-- admin_scope_and_write_guards_test.sql covers branch denial on the other
-- three RPCs.

begin;

insert into core.branches (id, brand_id, code, name_ar, name_en, address, is_active, settings)
values
  ('6a000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000001', 'CDG-B1', 'فرع حرس البطاقة 1', 'CDG Branch 1', 'addr1', true, '{}'::jsonb),
  ('6a000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000001', 'CDG-B2', 'فرع حرس البطاقة 2', 'CDG Branch 2', 'addr2', true, '{}'::jsonb);

insert into auth.users (id, email)
values
  ('6b100000-0000-4000-8000-000000000001', 'cdg-cust-1@test.local'),
  ('6b100000-0000-4000-8000-000000000002', 'cdg-cust-2@test.local'),
  ('6c100000-0000-4000-8000-000000000001', 'cdg-owner@test.local'),
  ('6c100000-0000-4000-8000-000000000002', 'cdg-manager@test.local'),
  ('6c100000-0000-4000-8000-000000000003', 'cdg-branch-mgr@test.local'),
  ('6c100000-0000-4000-8000-000000000004', 'cdg-cashier@test.local'),
  ('6c100000-0000-4000-8000-000000000005', 'cdg-inactive@test.local'),
  ('6c100000-0000-4000-8000-000000000006', 'cdg-target-staff@test.local');

insert into identity.profiles (id, full_name, email, phone)
values
  ('6b100000-0000-4000-8000-000000000001', 'CDG Customer One', 'cdg-cust-1@test.local', '0500000101'),
  ('6b100000-0000-4000-8000-000000000002', 'CDG Customer Two', 'cdg-cust-2@test.local', '0500000102')
on conflict (id) do nothing;

update identity.profiles
   set full_name = case id
         when '6b100000-0000-4000-8000-000000000001'::uuid then 'CDG Customer One'
         else 'CDG Customer Two' end
 where id in ('6b100000-0000-4000-8000-000000000001'::uuid,
              '6b100000-0000-4000-8000-000000000002'::uuid);

insert into identity.staff_members (id, user_id, status, full_name, email)
values
  ('6d100000-0000-4000-8000-000000000001', '6c100000-0000-4000-8000-000000000001', 'active', 'CDG Owner', 'cdg-owner@test.local'),
  ('6d100000-0000-4000-8000-000000000002', '6c100000-0000-4000-8000-000000000002', 'active', 'CDG Manager', 'cdg-manager@test.local'),
  ('6d100000-0000-4000-8000-000000000003', '6c100000-0000-4000-8000-000000000003', 'active', 'CDG Branch Manager', 'cdg-branch-mgr@test.local'),
  ('6d100000-0000-4000-8000-000000000004', '6c100000-0000-4000-8000-000000000004', 'active', 'CDG Cashier', 'cdg-cashier@test.local'),
  ('6d100000-0000-4000-8000-000000000005', '6c100000-0000-4000-8000-000000000005', 'suspended', 'CDG Inactive', 'cdg-inactive@test.local'),
  ('6d100000-0000-4000-8000-000000000006', '6c100000-0000-4000-8000-000000000006', 'active', 'CDG Target Staff', 'cdg-target-staff@test.local');

insert into identity.staff_roles (staff_id, role_id, branch_id)
select '6d100000-0000-4000-8000-000000000001', r.id, null from identity.roles r where r.code = 'owner';
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '6d100000-0000-4000-8000-000000000002', r.id, null from identity.roles r where r.code = 'manager';
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '6d100000-0000-4000-8000-000000000003', r.id, '6a000000-0000-4000-8000-000000000002'::uuid from identity.roles r where r.code = 'branch_manager';
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '6d100000-0000-4000-8000-000000000004', r.id, '6a000000-0000-4000-8000-000000000001'::uuid from identity.roles r where r.code = 'cashier';
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '6d100000-0000-4000-8000-000000000005', r.id, '6a000000-0000-4000-8000-000000000002'::uuid from identity.roles r where r.code = 'branch_manager';
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '6d100000-0000-4000-8000-000000000006', r.id, '6a000000-0000-4000-8000-000000000001'::uuid from identity.roles r where r.code = 'cashier';

-- Give the branch-scoped role read-only customer access, like the existing
-- scope test does, without granting write.
insert into identity.role_permissions (role_id, permission_id)
select r.id, p.id from identity.roles r, identity.permissions p
 where r.code = 'branch_manager' and p.code = 'customers.read'
on conflict do nothing;

insert into identity.customer_addresses (id, user_id, label, details, is_default)
values ('6e100000-0000-4000-8000-000000000001', '6b100000-0000-4000-8000-000000000001', 'home', 'CDG address', true);

insert into catalog.categories (id, slug, name_ar, name_en)
values ('6f100000-0000-4000-8000-000000000001', 'cdg-category', 'فئة حرس البطاقة', 'CDG Category');

insert into catalog.products (id, category_id, sku, slug, name_ar, name_en, base_price)
values ('6f100000-0000-4000-8000-000000000002', '6f100000-0000-4000-8000-000000000001',
        'CDG-P1', 'cdg-product', 'منتج حرس البطاقة', 'CDG Product', 10.00);

insert into orders.orders (
  id, order_number, user_id, branch_id, fulfillment_type, status, payment_status,
  subtotal, discount_total, delivery_fee, tax_total, grand_total, currency_code,
  customer_note, placed_at, loyalty_points_earned, idempotency_key, order_source
) values (
  '7a100000-0000-4000-8000-000000000001', 'CDG-1',
  '6b100000-0000-4000-8000-000000000001', '6a000000-0000-4000-8000-000000000001',
  'pickup', 'confirmed', 'unpaid', 10.00, 0.00, 0.00, 0.00, 10.00, 'SAR',
  'cdg', '2026-02-01T10:00:00Z', 0, 'cdg-test-order-1', 'online'
);

insert into orders.order_items (
  id, order_id, product_id, product_name_ar, product_name_en, sku_snapshot,
  unit_price, quantity, line_total, options_key, discount_total,
  option_group_name_ar, option_group_name_en, bundle_name_ar, bundle_name_en,
  product_discount_total
) values (
  '7b100000-0000-4000-8000-000000000001', '7a100000-0000-4000-8000-000000000001',
  '6f100000-0000-4000-8000-000000000002', 'منتج حرس البطاقة', 'CDG Product',
  'CDG-P1', 10.00, 1, 10.00, '', 0.00, '', '', '', '', 0.00
);

insert into subscriptions.plans (id, code, name_ar, name_en, price)
values ('7c100000-0000-4000-8000-000000000001', 'CDG-PLAN', 'خطة حرس البطاقة', 'CDG Plan', 100.00);

insert into subscriptions.subscriptions (
  id, user_id, plan_id, status, starts_at, ends_at, cups_entitled, cups_used,
  cups_carried_over, cups_reserved, idempotency_key
) values (
  '7d100000-0000-4000-8000-000000000001', '6b100000-0000-4000-8000-000000000001',
  '7c100000-0000-4000-8000-000000000001', 'active',
  now() - interval '1 day', now() + interval '30 days', 10, 2, 0, 1, 'cdg-test-sub-1'
);

set local role authenticated;

-- 1. Owner: allowed, exact contract, and the fixture data is intact.
select set_config('request.jwt.claims',
  '{"sub":"6c100000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);
do $$
declare
  v jsonb;
  keys text[];
begin
  v := public.admin_customer_details('6b100000-0000-4000-8000-000000000001');
  if v is null then raise exception 'FAIL 1a: owner got null for a real customer'; end if;
  select array_agg(k order by k) into keys from jsonb_object_keys(v) k;
  if keys <> array['addresses','orders','profile','subscriptions'] then
    raise exception 'FAIL 1a: top-level contract changed: %', keys;
  end if;
  select array_agg(k order by k) into keys from jsonb_object_keys(v -> 'profile') k;
  if keys <> array['admin_notes','avatar_url','created_at','email','full_name','id',
                    'is_blacklisted','is_vip','language','last_seen_at','phone','updated_at'] then
    raise exception 'FAIL 1a: profile contract changed: %', keys;
  end if;
  select array_agg(k order by k) into keys from jsonb_object_keys(v -> 'addresses' -> 0) k;
  if keys <> array['details','id','is_default','label'] then
    raise exception 'FAIL 1a: address contract changed: %', keys;
  end if;
  select array_agg(k order by k) into keys from jsonb_object_keys(v -> 'orders' -> 0) k;
  if keys <> array['branch_id','branch_name_ar','branch_name_en','fulfillment_type',
                    'grand_total','id','items','placed_at','status'] then
    raise exception 'FAIL 1a: order contract changed: %', keys;
  end if;
  select array_agg(k order by k) into keys from jsonb_object_keys(v -> 'orders' -> 0 -> 'items' -> 0) k;
  if keys <> array['line_total','product_name_ar','product_name_en','quantity','unit_price'] then
    raise exception 'FAIL 1a: item contract changed: %', keys;
  end if;
  select array_agg(k order by k) into keys from jsonb_object_keys(v -> 'subscriptions' -> 0) k;
  if keys <> array['auto_renew','cups_carried_over','cups_entitled','cups_reserved',
                    'cups_used','ends_at','id','plan','starts_at','status'] then
    raise exception 'FAIL 1a: subscription contract changed: %', keys;
  end if;
  if (v -> 'profile' ->> 'full_name') <> 'CDG Customer One'
     or jsonb_array_length(v -> 'addresses') <> 1
     or jsonb_array_length(v -> 'orders') <> 1
     or (v -> 'orders' -> 0 -> 'items' -> 0 ->> 'product_name_en') <> 'CDG Product'
     or jsonb_array_length(v -> 'subscriptions') <> 1
     or (v -> 'subscriptions' -> 0 -> 'plan' ->> 'name_en') <> 'CDG Plan' then
    raise exception 'FAIL 1a: fixture data changed in the card: %', v;
  end if;
end $$;

-- 2. A staff account is not a customer, even for the owner.
do $$
begin
  perform public.admin_customer_details('6c100000-0000-4000-8000-000000000006');
  raise exception 'FAIL 2a: owner opened a staff account as a customer';
exception when others then
  if sqlstate <> '42501' then raise; end if;
  if sqlerrm not like '%not a customer account%' then raise; end if;
end $$;

-- 3. Manager and branch-scoped staff with customers.read are allowed.
select set_config('request.jwt.claims',
  '{"sub":"6c100000-0000-4000-8000-000000000002","role":"authenticated","aud":"authenticated"}', true);
do $$
declare v jsonb;
begin
  v := public.admin_customer_details('6b100000-0000-4000-8000-000000000001');
  if v is null or (v -> 'profile' ->> 'full_name') <> 'CDG Customer One' then
    raise exception 'FAIL 3a: manager lost customer-card access';
  end if;
end $$;

select set_config('request.jwt.claims',
  '{"sub":"6c100000-0000-4000-8000-000000000003","role":"authenticated","aud":"authenticated"}', true);
do $$
declare v jsonb;
begin
  v := public.admin_customer_details('6b100000-0000-4000-8000-000000000002');
  if v is null or (v -> 'profile' ->> 'full_name') <> 'CDG Customer Two' then
    raise exception 'FAIL 3b: branch-scoped customers.read lost access';
  end if;
end $$;

-- 4. Staff without customers.read is denied; the target guard is not a substitute.
select set_config('request.jwt.claims',
  '{"sub":"6c100000-0000-4000-8000-000000000004","role":"authenticated","aud":"authenticated"}', true);
do $$
begin
  perform public.admin_customer_details('6b100000-0000-4000-8000-000000000001');
  raise exception 'FAIL 4a: staff without customers.read read a customer card';
exception when others then
  if sqlstate <> '42501' then raise; end if;
  if sqlerrm not like '%missing permission: customers.read%' then raise; end if;
end $$;

-- 5. Inactive staff and a customer caller are not staff.
select set_config('request.jwt.claims',
  '{"sub":"6c100000-0000-4000-8000-000000000005","role":"authenticated","aud":"authenticated"}', true);
do $$
begin
  perform public.admin_customer_details('6b100000-0000-4000-8000-000000000001');
  raise exception 'FAIL 5a: inactive staff read a customer card';
exception when others then
  if sqlstate <> '42501' then raise; end if;
  if sqlerrm not like '%not authenticated%' then raise; end if;
end $$;

select set_config('request.jwt.claims',
  '{"sub":"6b100000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);
do $$
begin
  perform public.admin_customer_details('6b100000-0000-4000-8000-000000000001');
  raise exception 'FAIL 5b: a customer called the admin customer card';
exception when others then
  if sqlstate <> '42501' then raise; end if;
  if sqlerrm not like '%not authenticated%' then raise; end if;
end $$;

-- 6. anon has no execute grant.
set local role anon;
do $$
begin
  perform public.admin_customer_details('6b100000-0000-4000-8000-000000000001');
  raise exception 'FAIL 6a: anon executed admin_customer_details';
exception when others then
  if sqlstate <> '42501' then raise; end if;
end $$;
reset role;

-- 7. Definition, owner, search_path and grants.
do $$
declare
  p oid := 'public.admin_customer_details(uuid)'::regprocedure;
  v_owner oid;
  v_secdef boolean;
  v_config text[];
begin
  select proowner, prosecdef, proconfig into v_owner, v_secdef, v_config
    from pg_proc where oid = p;
  if v_owner is null then raise exception 'FAIL 7a: function is missing'; end if;
  if v_owner <> 'postgres'::regrole then
    raise exception 'FAIL 7a: unexpected owner %', v_owner::regrole;
  end if;
  if not v_secdef then raise exception 'FAIL 7b: SECURITY DEFINER lost'; end if;
  if not ('search_path=""' = any(coalesce(v_config, '{}'::text[]))) then
    raise exception 'FAIL 7c: search_path is not pinned empty: %', v_config;
  end if;
  if has_function_privilege('anon', p, 'execute') then
    raise exception 'FAIL 7d: anon can execute the function';
  end if;
  if not has_function_privilege('authenticated', p, 'execute') then
    raise exception 'FAIL 7d: authenticated lost execute';
  end if;
  if exists (
    select 1 from aclexplode((select proacl from pg_proc where oid = p)) a
     where a.grantee = 0 or a.grantee = 'anon'::regrole
  ) then
    raise exception 'FAIL 7e: PUBLIC or anon appears in the function ACL';
  end if;
  if has_function_privilege('anon', 'identity.is_staff()'::regprocedure, 'execute')
     or has_function_privilege('anon', 'identity.has_permission(text)'::regprocedure, 'execute')
     or has_function_privilege('anon', 'identity.can_manage_branch(uuid)'::regprocedure, 'execute') then
    raise exception 'FAIL 7f: an internal identity helper is executable by anon';
  end if;
end $$;

select 'reached the end: customer details guard passed' as verdict;


rollback;