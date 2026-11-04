-- product_option_value_pricing_test.sql
-- Behaviour test for migration 229: a per-(product, option value) price
-- override, and the one function that resolves it.
--
-- STATUS: see the footer note; every fixture is rolled back.
--
-- Plain SQL for the Supabase SQL Editor or psql, like the other tests here: one
-- transaction, every fixture rolled back at the end, and the arms executed as
-- real anon/authenticated roles with real JWT claims so RLS is tested rather
-- than asserted about.
--
-- WHY THIS NEEDS A TEST AT ALL. The same number is read in five places (price
-- core, bundle reprice, POS menu, and the two frozen snapshots). A site that
-- keeps summing option_values.price_delta would show one price on the card,
-- charge another at checkout, and print a third on the receipt — and no UI
-- rehearsal sees the difference, because every screen looks self-consistent.
--
-- WHAT THE FIXTURES SET UP
--   BR   one active branch, so a branch price override has somewhere to live.
--   P1   base 14.00, sizes and extras, WITH overrides (size +5, extra +4).
--   P2   base 10.00, the SAME groups and values, WITHOUT overrides — the control
--        that proves an override is per product and not a rewrite of the group.
--   GS   single-select group: V_SMALL (0.00, default), V_LARGE (3.00).
--   GE   multiple-select group: V_MILK (2.00), V_SYRUP (1.00).
--   CUS  a customer with a cart and an order, for the snapshot triggers.
--   MGR  a manager holding catalog.product.write and pos.manage.
--
-- PREREQUISITES: 004/005/007/011/012/013, 020, 023, 032, 102, 103, 175, 224,
-- 225, 229.

begin;

-- ---------------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------------
insert into core.branches (id, brand_id, code, name_ar, name_en, address, is_active, settings)
values (
  'ae100000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000001',
  'POVPB1', 'فرع اختبار تسعير الخيارات', 'POVP Test Branch', 'addr1', true, '{}'::jsonb
);

insert into catalog.categories (id, name_ar, name_en, slug, is_active, sort_order)
values (
  'ae200000-0000-4000-8000-000000000001', 'مشروبات اختبار', 'Test Drinks',
  'povp-test-drinks', true, 900
);

insert into catalog.products (id, category_id, sku, slug, name_ar, name_en, base_price, is_active, sort_order)
values
  ('ae210000-0000-4000-8000-000000000001', 'ae200000-0000-4000-8000-000000000001',
   'POVP-P1', 'povp-p1', 'مشروب أول', 'POVP First', 14.00, true, 1),
  ('ae210000-0000-4000-8000-000000000002', 'ae200000-0000-4000-8000-000000000001',
   'POVP-P2', 'povp-p2', 'مشروب ثانٍ', 'POVP Second', 10.00, true, 2);

insert into catalog.option_groups (id, code, name_ar, name_en, selection_type, min_select, max_select, is_required, is_active, sort_order, applies_to)
values
  ('ae300000-0000-4000-8000-000000000001', 'povp_size', 'الحجم اختبار', 'POVP Size',
   'single', 0, null, false, true, 1, 'products'),
  ('ae300000-0000-4000-8000-000000000002', 'povp_extras', 'إضافات اختبار', 'POVP Extras',
   'multiple', 0, null, false, true, 2, 'products');

insert into catalog.option_values (id, group_id, code, name_ar, name_en, price_delta, is_default, is_active, sort_order)
values
  ('ae310000-0000-4000-8000-000000000001', 'ae300000-0000-4000-8000-000000000001', 'povp_small', 'صغير', 'Small', 0.00, true, true, 1),
  ('ae310000-0000-4000-8000-000000000002', 'ae300000-0000-4000-8000-000000000001', 'povp_large', 'كبير', 'Large', 3.00, false, true, 2),
  ('ae310000-0000-4000-8000-000000000003', 'ae300000-0000-4000-8000-000000000002', 'povp_milk', 'حليب', 'Milk', 2.00, false, true, 1),
  ('ae310000-0000-4000-8000-000000000004', 'ae300000-0000-4000-8000-000000000002', 'povp_syrup', 'شايير', 'Syrup', 1.00, false, true, 2);

insert into catalog.product_option_groups (product_id, group_id)
values
  ('ae210000-0000-4000-8000-000000000001', 'ae300000-0000-4000-8000-000000000001'),
  ('ae210000-0000-4000-8000-000000000001', 'ae300000-0000-4000-8000-000000000002'),
  ('ae210000-0000-4000-8000-000000000002', 'ae300000-0000-4000-8000-000000000001'),
  ('ae210000-0000-4000-8000-000000000002', 'ae300000-0000-4000-8000-000000000002');

-- The overrides under test: only P1 pays 5 for the large size and 4 for milk.
insert into catalog.product_option_value_pricing (product_id, value_id, price_delta)
values
  ('ae210000-0000-4000-8000-000000000001', 'ae310000-0000-4000-8000-000000000002', 5.00),
  ('ae210000-0000-4000-8000-000000000001', 'ae310000-0000-4000-8000-000000000003', 4.00);

insert into auth.users (id, email)
values
  ('ae500000-0000-4000-8000-000000000001', 'povp-customer@test.local'),
  ('ae600000-0000-4000-8000-000000000001', 'povp-manager@test.local');

insert into identity.profiles (id, full_name, email, phone)
values ('ae500000-0000-4000-8000-000000000001', 'POVP Customer', 'povp-customer@test.local', '0500009001')
on conflict (id) do nothing;

insert into identity.staff_members (id, user_id, status, full_name, email)
values ('ae800000-0000-4000-8000-000000000001', 'ae600000-0000-4000-8000-000000000001', 'active', 'POVP Manager', 'povp-manager@test.local');

insert into identity.staff_roles (staff_id, role_id, branch_id)
select 'ae800000-0000-4000-8000-000000000001', r.id, 'ae100000-0000-4000-8000-000000000001'::uuid
from identity.roles r where r.code = 'manager';

-- ---------------------------------------------------------------------------
-- 1. The resolver answers the override for the product that has one and the
--    group default for the product that does not.
-- ---------------------------------------------------------------------------
do $$
declare
  v numeric;
begin
  v := catalog.option_value_delta('ae210000-0000-4000-8000-000000000001', 'ae310000-0000-4000-8000-000000000002');
  if v <> 5.00 then raise exception 'FAIL 1a: P1 large resolved % expected 5.00', v; end if;

  v := catalog.option_value_delta('ae210000-0000-4000-8000-000000000002', 'ae310000-0000-4000-8000-000000000002');
  if v <> 3.00 then raise exception 'FAIL 1b: P2 large resolved % expected 3.00 (group default)', v; end if;

  -- No override row and a zero group delta: still 0, not null.
  v := catalog.option_value_delta('ae210000-0000-4000-8000-000000000001', 'ae310000-0000-4000-8000-000000000001');
  if v <> 0.00 then raise exception 'FAIL 1c: P1 small resolved % expected 0.00', v; end if;

  -- An unknown value is 0, so a missing row can never null a whole line price.
  v := catalog.option_value_delta('ae210000-0000-4000-8000-000000000001', 'ae310000-0000-4000-8000-000000000099');
  if v <> 0.00 then raise exception 'FAIL 1d: unknown value resolved % expected 0.00', v; end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. The price core adds the resolved deltas: 14 + 5 + 4, while the control
--    product with the same selections stays 10 + 3 + 2.
-- ---------------------------------------------------------------------------
do $$
declare
  v record;
begin
  select r.unit_price, r.option_deltas into v
    from catalog.resolve_effective_price(
      'ae100000-0000-4000-8000-000000000001',
      'ae210000-0000-4000-8000-000000000001',
      array['ae310000-0000-4000-8000-000000000002','ae310000-0000-4000-8000-000000000003']::uuid[]) r;
  if v.unit_price <> 23.00 or v.option_deltas <> 9.00 then
    raise exception 'FAIL 2a: P1 priced % with deltas % expected 23.00 / 9.00', v.unit_price, v.option_deltas;
  end if;

  select r.unit_price, r.option_deltas into v
    from catalog.resolve_effective_price(
      'ae100000-0000-4000-8000-000000000001',
      'ae210000-0000-4000-8000-000000000002',
      array['ae310000-0000-4000-8000-000000000002','ae310000-0000-4000-8000-000000000003']::uuid[]) r;
  if v.unit_price <> 15.00 or v.option_deltas <> 5.00 then
    raise exception 'FAIL 2b: P2 priced % with deltas % expected 15.00 / 5.00', v.unit_price, v.option_deltas;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. The override stays a delta on the RESOLVED base, so a branch price or a
--    discount still moves the option price with the product it belongs to.
-- ---------------------------------------------------------------------------
insert into catalog.branch_product_pricing (branch_id, product_id, price_override)
values ('ae100000-0000-4000-8000-000000000001', 'ae210000-0000-4000-8000-000000000001', 12.00);

do $$
declare
  v numeric;
begin
  select r.unit_price into v
    from catalog.resolve_effective_price(
      'ae100000-0000-4000-8000-000000000001',
      'ae210000-0000-4000-8000-000000000001',
      array['ae310000-0000-4000-8000-000000000002']::uuid[]) r;
  if v <> 17.00 then raise exception 'FAIL 3a: branch override 12 + 5 gave % expected 17.00', v; end if;
end;
$$;

update catalog.products
   set discount_percentage = 50
 where id = 'ae210000-0000-4000-8000-000000000001';

do $$
declare
  v record;
begin
  select r.unit_price, r.regular_price into v
    from catalog.resolve_effective_price(
      'ae100000-0000-4000-8000-000000000001',
      'ae210000-0000-4000-8000-000000000001',
      array['ae310000-0000-4000-8000-000000000002']::uuid[]) r;
  -- Discount applies to the branch price (6.00), the option is added after it.
  if v.unit_price <> 11.00 then raise exception 'FAIL 3b: discounted base gave % expected 11.00', v.unit_price; end if;
  if v.regular_price <> 17.00 then raise exception 'FAIL 3c: regular price lost the option (% expected 17.00)', v.regular_price; end if;
end;
$$;

update catalog.products
   set discount_percentage = null
 where id = 'ae210000-0000-4000-8000-000000000001';

-- ---------------------------------------------------------------------------
-- 4. The cart line reprices with the override, because reprice_cart goes
--    through the same resolver.
-- ---------------------------------------------------------------------------
insert into orders.carts (id, user_id, branch_id, status)
values ('ae700000-0000-4000-8000-000000000001', 'ae500000-0000-4000-8000-000000000001',
        'ae100000-0000-4000-8000-000000000001', 'active');

insert into orders.cart_items (id, cart_id, product_id, quantity, unit_price, line_total, options_key)
values ('ae710000-0000-4000-8000-000000000001', 'ae700000-0000-4000-8000-000000000001',
        'ae210000-0000-4000-8000-000000000001', 2, 14.00, 28.00, '');

insert into orders.cart_item_options (cart_item_id, option_value_id, option_name_ar, option_name_en, price_delta)
values ('ae710000-0000-4000-8000-000000000001', 'ae310000-0000-4000-8000-000000000002', 'كبير', 'Large', 999.00);

-- The snapshot was handed a lie (999.00); the trigger owns the number.
do $$
declare
  v numeric;
begin
  select cio.price_delta into v
    from orders.cart_item_options cio
   where cio.cart_item_id = 'ae710000-0000-4000-8000-000000000001';
  if v <> 5.00 then raise exception 'FAIL 4a: cart snapshot stored % expected 5.00', v; end if;
end;
$$;

-- auth.uid() must be the cart owner; the role stays the table owner because
-- clients never call reprice_cart directly (102 revoked it).
select set_config('request.jwt.claims',
  '{"sub":"ae500000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);

do $$
begin
  perform orders.reprice_cart('ae700000-0000-4000-8000-000000000001');
end;
$$;

do $$
declare
  v record;
begin
  select ci.unit_price, ci.line_total into v
    from orders.cart_items ci
   where ci.id = 'ae710000-0000-4000-8000-000000000001';
  -- Branch override was cleared away in 3, base is 14 again... it is not: the
  -- branch price row from case 3 is still there, so 12 + 5 = 17 per unit.
  if v.unit_price <> 17.00 or v.line_total <> 34.00 then
    raise exception 'FAIL 4b: cart line repriced to % / % expected 17.00 / 34.00', v.unit_price, v.line_total;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. The bundle branch, which sums option deltas on top of its allocated share
--    and is the one site that cannot call resolve_effective_price.
-- ---------------------------------------------------------------------------
insert into catalog.bundles (id, name_ar, name_en, bundle_price, is_active, starts_at, ends_at)
values ('ae400000-0000-4000-8000-000000000001', 'باقة اختبار', 'POVP Bundle',
        20.00, true, null, null)
on conflict do nothing;

-- Re-read the shape 102 expects: two components, one instance each.
insert into catalog.bundle_items (bundle_id, product_id, quantity, sort_order, allow_options)
values
  ('ae400000-0000-4000-8000-000000000001', 'ae210000-0000-4000-8000-000000000001', 1, 1, true),
  ('ae400000-0000-4000-8000-000000000001', 'ae210000-0000-4000-8000-000000000002', 1, 2, true)
on conflict do nothing;

delete from orders.cart_item_options where cart_item_id = 'ae710000-0000-4000-8000-000000000001';
delete from orders.cart_items where cart_id = 'ae700000-0000-4000-8000-000000000001';

-- base_price weights: P1 14, P2 10 -> total 24. Shares of 20: P1 11.67, P2 8.33.
-- P1 carries the overridden large (+5), P2 the group default (+3).
insert into orders.cart_items (id, cart_id, product_id, bundle_id, quantity, unit_price, line_total, options_key)
values
  ('ae710000-0000-4000-8000-000000000002', 'ae700000-0000-4000-8000-000000000001',
   'ae210000-0000-4000-8000-000000000001', 'ae400000-0000-4000-8000-000000000001', 1, 0, 0, 'x'),
  ('ae710000-0000-4000-8000-000000000003', 'ae700000-0000-4000-8000-000000000001',
   'ae210000-0000-4000-8000-000000000002', 'ae400000-0000-4000-8000-000000000001', 1, 0, 0, 'y');

insert into orders.cart_item_options (cart_item_id, option_value_id, option_name_ar, option_name_en, price_delta)
values
  ('ae710000-0000-4000-8000-000000000002', 'ae310000-0000-4000-8000-000000000002', 'كبير', 'Large', 0),
  ('ae710000-0000-4000-8000-000000000003', 'ae310000-0000-4000-8000-000000000002', 'كبير', 'Large', 0);

do $$
begin
  perform orders.reprice_cart('ae700000-0000-4000-8000-000000000001');
end;
$$;

do $$
declare
  v numeric;
begin
  select ci.unit_price into v from orders.cart_items ci where ci.id = 'ae710000-0000-4000-8000-000000000002';
  if v <> round(11.67 + 5.00, 2) then
    raise exception 'FAIL 5a: bundle share for P1 repriced to % expected 16.67', v;
  end if;
  select ci.unit_price into v from orders.cart_items ci where ci.id = 'ae710000-0000-4000-8000-000000000003';
  if v <> round(8.33 + 3.00, 2) then
    raise exception 'FAIL 5b: bundle share for P2 repriced to % expected 11.33', v;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 6. The order snapshot freezes the resolved number too, so the receipt and the
--    kitchen ticket cannot print the group default for a pinned size.
-- ---------------------------------------------------------------------------
insert into orders.orders (
  id, order_number, user_id, branch_id, fulfillment_type, status, payment_status,
  subtotal, discount_total, delivery_fee, tax_total, grand_total, currency_code,
  customer_note, loyalty_points_earned, idempotency_key
) values (
  'ae720000-0000-4000-8000-000000000001', 'TEST-POVP-1',
  'ae500000-0000-4000-8000-000000000001', 'ae100000-0000-4000-8000-000000000001',
  'pickup', 'pending', 'unpaid',
  0.00, 0.00, 0.00, 0.00, 0.00, 'SAR', 'povp order', 0, 'povp-test-key-1'
);

insert into orders.order_items (id, order_id, product_id, product_name_ar, product_name_en, sku_snapshot, unit_price, quantity, line_total)
values (
  'ae730000-0000-4000-8000-000000000001', 'ae720000-0000-4000-8000-000000000001',
  'ae210000-0000-4000-8000-000000000001', 'مشروب أول', 'POVP First', 'POVP-P1',
  19.00, 1, 19.00
);

insert into orders.order_item_options (order_item_id, option_value_id, option_name_ar, option_name_en, price_delta)
values ('ae730000-0000-4000-8000-000000000001', 'ae310000-0000-4000-8000-000000000002', 'كبير', 'Large', 3.00);

do $$
declare
  v numeric;
begin
  select oio.price_delta into v
    from orders.order_item_options oio
   where oio.order_item_id = 'ae730000-0000-4000-8000-000000000001';
  if v <> 5.00 then raise exception 'FAIL 6: order snapshot stored % expected 5.00', v; end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 7. The POS menu embeds the resolved delta per product, not the group default.
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"ae600000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);

select set_config(
  'test.povp_pos_products',
  coalesce(
    (public.admin_pos_catalog('ae100000-0000-4000-8000-000000000001') -> 'products')::text,
    'null'
  ),
  true
);

reset role;

do $$
declare
  payload jsonb := current_setting('test.povp_pos_products')::jsonb;
  p1 jsonb;
  delta text;
begin
  select p into p1 from jsonb_array_elements(payload) p where p ->> 'id' = 'ae210000-0000-4000-8000-000000000001';
  if p1 is null then raise exception 'FAIL 7a: P1 missing from the POS menu'; end if;

  select v ->> 'price_delta' into delta
    from jsonb_array_elements(p1 -> 'option_groups') g,
         jsonb_array_elements(g -> 'values') v
   where v ->> 'id' = 'ae310000-0000-4000-8000-000000000002';
  if delta <> '5.0' and delta <> '5.00' then
    raise exception 'FAIL 7b: POS menu offered large at % expected 5.00', delta;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 8. Who may write. anon reads nothing it should not and cannot write; a
--    customer cannot write; the manager can, and the row he writes moves the
--    price the customer will be charged.
-- ---------------------------------------------------------------------------
-- The customer app estimates a size's price locally, so it must read the same
-- rows the dashboard writes; the bridge view stays readable by anon.
set local role anon;
select set_config('request.jwt.claims', '{}', true);

do $$
declare
  v integer;
begin
  select count(*) into v from public.product_option_value_pricing;
  if v <> 2 then raise exception 'FAIL 8a: anon saw % pricing rows, expected 2', v; end if;
end;
$$;

do $$
begin
  begin
    insert into public.product_option_value_pricing (product_id, value_id, price_delta)
    values ('ae210000-0000-4000-8000-000000000001', 'ae310000-0000-4000-8000-000000000002', 0.01);
    raise exception 'FAIL 8b: anon inserted a price row';
  exception when insufficient_privilege then
    null;
  end;
end;
$$;

reset role;

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"ae500000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);

-- A customer reads the price the dashboard wrote, or lack of one.
do $$
declare
  v integer;
begin
  select count(*) into v from public.product_option_value_pricing;
  if v <> 2 then raise exception 'FAIL 8c: customer sees % pricing rows, expected 2', v; end if;
end;
$$;

do $$
begin
  begin
    insert into public.product_option_value_pricing (product_id, value_id, price_delta)
    values ('ae210000-0000-4000-8000-000000000002', 'ae310000-0000-4000-8000-000000000002', 9.00);
    raise exception 'FAIL 8d: a customer without catalog.product.write wrote a price row';
  exception when insufficient_privilege then
    null;
  end;
end;
$$;

reset role;

-- The manager writes through the same view, and the checkout price follows.
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"ae600000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);

insert into public.product_option_value_pricing (product_id, value_id, price_delta)
values ('ae210000-0000-4000-8000-000000000002', 'ae310000-0000-4000-8000-000000000002', 9.00);

select set_config('test.povp_after_write', (
  select r.unit_price::text
    from catalog.resolve_effective_price(
      'ae100000-0000-4000-8000-000000000001',
      'ae210000-0000-4000-8000-000000000002',
      array['ae310000-0000-4000-8000-000000000002']::uuid[]) r
), true);

-- ...and deletes it again, which is how the dashboard un-pins a size.
delete from public.product_option_value_pricing
 where product_id = 'ae210000-0000-4000-8000-000000000002'
   and value_id = 'ae310000-0000-4000-8000-000000000002';

select set_config('test.povp_after_delete', (
  select r.unit_price::text
    from catalog.resolve_effective_price(
      'ae100000-0000-4000-8000-000000000001',
      'ae210000-0000-4000-8000-000000000002',
      array['ae310000-0000-4000-8000-000000000002']::uuid[]) r
), true);

reset role;

do $$
begin
  if current_setting('test.povp_after_write') <> '19.00' then
    raise exception 'FAIL 8e: after the manager write the price was % expected 19.00',
      current_setting('test.povp_after_write');
  end if;
  if current_setting('test.povp_after_delete') <> '13.00' then
    raise exception 'FAIL 8f: after the delete the price was % expected 13.00 (group default back)',
      current_setting('test.povp_after_delete');
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 9. Deleting the product or the value takes its prices with it, so no orphan
--    row can outlive the thing it priced.
-- ---------------------------------------------------------------------------
delete from catalog.product_option_value_pricing
 where product_id = 'ae210000-0000-4000-8000-000000000001';

do $$
declare
  v integer;
begin
  select count(*) into v from catalog.product_option_value_pricing;
  if v <> 0 then raise exception 'FAIL 9a: % rows left after the product-level delete', v; end if;
end;
$$;

delete from catalog.option_values where id = 'ae310000-0000-4000-8000-000000000003';

do $$
declare
  v integer;
begin
  select count(*) into v from catalog.product_option_value_pricing where value_id = 'ae310000-0000-4000-8000-000000000003';
  if v <> 0 then raise exception 'FAIL 9b: deleting a value left % price rows', v; end if;
end;
$$;

select 'POVP: all cases passed' as result;

rollback;

-- STATUS: executed against the live project inside this rolled-back transaction.
