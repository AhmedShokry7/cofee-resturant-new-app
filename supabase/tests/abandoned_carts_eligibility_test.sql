-- abandoned_carts_eligibility_test.sql
--
-- Focused regression test for 268_abandoned_carts_eligibility.sql. It creates
-- eligible, empty, zero-total, converted and other-branch carts, then calls
-- the RPC as two real authenticated staff members.
--
-- PREREQUISITES: 011/211/268. All fixture rows are rolled back.

begin;

insert into core.branches (id, brand_id, code, name_ar, name_en, address, is_active, settings)
values
  ('c1000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000001',
   'CART-T-B1', 'فرع سلال 1', 'Cart Test B1', 'addr', true, '{}'::jsonb),
  ('c1000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000001',
   'CART-T-B2', 'فرع سلال 2', 'Cart Test B2', 'addr', true, '{}'::jsonb);

insert into auth.users (id, email) values
  ('c2000000-0000-4000-8000-000000000001', 'cart-global@test.local'),
  ('c2000000-0000-4000-8000-000000000002', 'cart-branch@test.local'),
  ('c2000000-0000-4000-8000-000000000003', 'cart-customer@test.local');

insert into identity.profiles (id, full_name, email)
values
  ('c2000000-0000-4000-8000-000000000001', 'Cart Global', 'cart-global@test.local'),
  ('c2000000-0000-4000-8000-000000000002', 'Cart Branch', 'cart-branch@test.local'),
  ('c2000000-0000-4000-8000-000000000003', 'Cart Customer', 'cart-customer@test.local')
on conflict (id) do nothing;

insert into identity.staff_members (id, user_id, status, full_name, email)
values
  ('c3000000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000001',
   'active', 'Cart Global', 'cart-global@test.local'),
  ('c3000000-0000-4000-8000-000000000002', 'c2000000-0000-4000-8000-000000000002',
   'active', 'Cart Branch', 'cart-branch@test.local');

insert into identity.roles (code, name_ar, name_en, is_system)
values ('tmp_cart_reader', 'قارئ سلال اختبار', 'Test Cart Reader', false);

insert into identity.role_permissions (role_id, permission_id)
select r.id, p.id from identity.roles r
  join identity.permissions p on p.code = 'orders.read'
 where r.code = 'tmp_cart_reader';

insert into identity.staff_roles (staff_id, role_id, branch_id)
select 'c3000000-0000-4000-8000-000000000001', r.id, null
  from identity.roles r where r.code = 'tmp_cart_reader';

insert into identity.staff_roles (staff_id, role_id, branch_id)
select 'c3000000-0000-4000-8000-000000000002', r.id, 'c1000000-0000-4000-8000-000000000001'
  from identity.roles r where r.code = 'tmp_cart_reader';

insert into catalog.categories (id, slug, name_ar, name_en)
values ('c4000000-0000-4000-8000-000000000001', 'cart-test-category', 'فئة سلال', 'Cart Test Category');

insert into catalog.products (id, category_id, sku, slug, name_ar, name_en, base_price)
values ('c5000000-0000-4000-8000-000000000001', 'c4000000-0000-4000-8000-000000000001',
        'CART-T-P1', 'cart-test-product', 'منتج سلال', 'Cart Test Product', 10.00);

insert into orders.carts (id, user_id, branch_id, status)
values
  ('c6000000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000003',
   'c1000000-0000-4000-8000-000000000001', 'active'),
  ('c6000000-0000-4000-8000-000000000002', 'c2000000-0000-4000-8000-000000000003',
   'c1000000-0000-4000-8000-000000000001', 'abandoned'),
  ('c6000000-0000-4000-8000-000000000003', 'c2000000-0000-4000-8000-000000000003',
   'c1000000-0000-4000-8000-000000000001', 'abandoned'),
  ('c6000000-0000-4000-8000-000000000004', 'c2000000-0000-4000-8000-000000000003',
   'c1000000-0000-4000-8000-000000000001', 'abandoned'),
  ('c6000000-0000-4000-8000-000000000005', 'c2000000-0000-4000-8000-000000000003',
   'c1000000-0000-4000-8000-000000000001', 'converted'),
  ('c6000000-0000-4000-8000-000000000006', 'c2000000-0000-4000-8000-000000000003',
   'c1000000-0000-4000-8000-000000000002', 'abandoned');

insert into orders.cart_items (cart_id, product_id, quantity, unit_price, line_total)
values
  ('c6000000-0000-4000-8000-000000000001', 'c5000000-0000-4000-8000-000000000001', 1, 10.00, 10.00),
  ('c6000000-0000-4000-8000-000000000002', 'c5000000-0000-4000-8000-000000000001', 2, 10.00, 20.00),
  ('c6000000-0000-4000-8000-000000000004', 'c5000000-0000-4000-8000-000000000001', 1, 0.00, 0.00),
  ('c6000000-0000-4000-8000-000000000005', 'c5000000-0000-4000-8000-000000000001', 3, 10.00, 30.00),
  ('c6000000-0000-4000-8000-000000000006', 'c5000000-0000-4000-8000-000000000001', 4, 10.00, 40.00);

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"c2000000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}',
  true);

-- Global staff: both branches, but only the three eligible fixtures.
do $$
declare
  v jsonb;
  v_cart1 jsonb;
  v_cart2 jsonb;
  c int;
begin
  v := public.admin_abandoned_carts();

  select count(*) into c from jsonb_array_elements(v) e
   where e ->> 'id' in ('c6000000-0000-4000-8000-000000000001',
                        'c6000000-0000-4000-8000-000000000002',
                        'c6000000-0000-4000-8000-000000000006');
  if c <> 3 then
    raise exception 'FAIL 1a: global staff sees % of the three eligible fixtures', c;
  end if;

  if exists (
    select 1 from jsonb_array_elements(v) e
     where e ->> 'id' in ('c6000000-0000-4000-8000-000000000003',
                          'c6000000-0000-4000-8000-000000000004',
                          'c6000000-0000-4000-8000-000000000005')
  ) then
    raise exception 'FAIL 1b: empty, zero-total or converted cart reached the list';
  end if;

  if exists (
    select 1 from jsonb_array_elements(v) e
     where (e ->> 'total')::numeric <= 0 or jsonb_array_length(e -> 'items') = 0
  ) then
    raise exception 'FAIL 1c: an ineligible cart reached the list (%)', v::text;
  end if;

  select e into v_cart1 from jsonb_array_elements(v) e
   where e ->> 'id' = 'c6000000-0000-4000-8000-000000000001';
  select e into v_cart2 from jsonb_array_elements(v) e
   where e ->> 'id' = 'c6000000-0000-4000-8000-000000000002';
  if v_cart1 is null or (v_cart1 ->> 'total')::numeric <> 10.00 then
    raise exception 'FAIL 1d: eligible cart 1 total is %', v_cart1 ->> 'total';
  end if;
  if v_cart2 is null or (v_cart2 ->> 'total')::numeric <> 20.00
     or jsonb_array_length(v_cart2 -> 'items') <> 1
     or (v_cart2 -> 'items' -> 0 ->> 'quantity')::int <> 2 then
    raise exception 'FAIL 1e: eligible cart 2 details are wrong (%)', v_cart2;
  end if;
end $$;

select set_config('request.jwt.claims',
  '{"sub":"c2000000-0000-4000-8000-000000000002","role":"authenticated","aud":"authenticated"}',
  true);

-- Branch staff: the other-branch eligible cart must stay out of scope.
do $$
declare v jsonb;
begin
  v := public.admin_abandoned_carts();
  if exists (
    select 1 from jsonb_array_elements(v) e
     where e ->> 'id' = 'c6000000-0000-4000-8000-000000000006'
  ) then
    raise exception 'FAIL 2a: branch staff sees the other-branch cart';
  end if;
  if not exists (
    select 1 from jsonb_array_elements(v) e
     where e ->> 'id' = 'c6000000-0000-4000-8000-000000000002'
  ) then
    raise exception 'FAIL 2b: branch staff lost the own-branch eligible cart';
  end if;
end $$;

rollback;
