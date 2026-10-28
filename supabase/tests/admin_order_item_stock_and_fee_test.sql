-- admin_order_item_stock_and_fee_test.sql
-- Behaviour test for migration 200 (admin_add_order_item / admin_remove_order_item
-- / admin_recompute_order_totals): the shelf, the stock ledger and the delivery
-- fee of an order an admin edits.
--
-- STATUS: EXECUTED, ALL EIGHT CASES PASSED, EVERY FIXTURE ROLLED BACK. Case 2 is
-- what found the first draft's two bugs - the aggregated sale row was widened by
-- subtraction, so it reported one third of what the order had really taken, and a
-- product with no branch_stock row got a phantom movement because the write was
-- gated on the line insert rather than on the shelf lookup. Both are fixed in 200.
--
-- Plain SQL for the Supabase SQL Editor or psql, like the other tests here: one
-- transaction, every fixture rolled back at the end, and every write RPC executed
-- as a real authenticated role with real JWT claims, so the authorization arms
-- and the branch guards are tested rather than asserted about.
--
-- Reads that measure the effect of a call run as the connection owner again
-- (reset role), because RLS is not what this test wants to exercise - the same
-- reason admin_orders_branch_scope_test.sql parks its expected counts in
-- set_config before switching role. New line ids are handled the same way: the
-- call is made as the staff role, the id is looked up as the owner, and the value
-- is handed to the next case through a transaction-local setting.
--
-- WHAT THE FIXTURES SET UP
--   B1  the branch the editing manager manages; holds the zone and the stock.
--   B2  another branch, for the cross-branch refusal.
--   P_IN_STOCK   5 on the shelf at B1, 40.00 each, no discount.
--   P_LOW_STOCK  1 on the shelf, so a request of 3 must be refused.
--   P_UNSTOCKED  25.00 and NO branch_stock row at all: sellable, but the branch
--                never had any, so the ledger must not claim it deducted some.
--   P_FEE        70.00, also unstocked, used only by the delivery-fee case so
--                that case cannot disturb the stock assertions.
--   ZONE  fixed 15.00, waived at or above a 100.00 subtotal.
--   O1  a pickup order at B1 with no lines: the stock cases happen here, so its
--       fee is never in play.
--   O2  a delivery order at B1 in ZONE with one 40.00 line, i.e. under the
--       threshold and paying 15.00. Its fixture line carries no movement because
--       a hand-made order row is exactly what an admin edit meets in production.
--
-- Expected tax is read from core.brands inside the fixture inserts, so
-- ck_orders_total holds whatever the brand is configured to. The arithmetic
-- assertions below compare subtotal and delivery_fee only: grand_total is proven
-- by the constraint itself, because a total the constraint rejects aborts the
-- call instead of being compared.
--
-- PREREQUISITES: 004/005/007/011/012/013/018/021/035/068/137 (identity, RBAC
-- matrix, catalogue, orders, inventory, zones and fees), 134, 167, 175, 191, 200.

begin;

-- ---------------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------------
insert into core.branches (id, brand_id, code, name_ar, name_en, address, is_active, settings)
values
  ('ae100000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000001', 'AISF1B1', 'فرع اختبار الجرد 1', 'AISF Branch 1', 'addr1', true, '{}'::jsonb),
  ('ae100000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000001', 'AISF1B2', 'فرع اختبار الجرد 2', 'AISF Branch 2', 'addr2', true, '{}'::jsonb);

insert into core.delivery_zones
  (id, brand_id, name_ar, name_en, delivery_fee, min_order_amount, is_active,
   fee_method, free_delivery_over)
values
  ('ae200000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000001',
   'منطقة اختبار الجرد', 'AISF Zone', 15.00, 0.00, true, 'fixed', 100.00);

insert into core.delivery_zone_branches (zone_id, branch_id)
values ('ae200000-0000-4000-8000-000000000001', 'ae100000-0000-4000-8000-000000000001');

insert into catalog.categories (id, slug, name_ar, name_en, is_active)
values ('ae300000-0000-4000-8000-000000000001', 'aisf-test-category',
        'فئة اختبار الجرد', 'AISF Category', true);

insert into catalog.products
  (id, category_id, sku, slug, name_ar, name_en, base_price, is_active)
values
  ('ae400000-0000-4000-8000-000000000001', 'ae300000-0000-4000-8000-000000000001',
   'AISF-IN-STOCK',  'aisf-in-stock',  'منتج متوفر',  'AISF in stock',  40.00, true),
  ('ae400000-0000-4000-8000-000000000002', 'ae300000-0000-4000-8000-000000000001',
   'AISF-LOW-STOCK', 'aisf-low-stock', 'منتج شبه نفد', 'AISF low stock', 60.00, true),
  ('ae400000-0000-4000-8000-000000000003', 'ae300000-0000-4000-8000-000000000001',
   'AISF-UNSTOCKED', 'aisf-unstocked', 'منتج بلا جرد', 'AISF unstocked', 25.00, true),
  ('ae400000-0000-4000-8000-000000000004', 'ae300000-0000-4000-8000-000000000001',
   'AISF-FEE',       'aisf-fee',       'منتج الأجرة',  'AISF fee probe', 70.00, true);

-- 5 units of the first product, 1 of the second, and deliberately no row for the
-- third or the fourth.
insert into inventory.branch_stock (branch_id, product_id, variant_key, quantity_on_hand, allow_negative)
values
  ('ae100000-0000-4000-8000-000000000001', 'ae400000-0000-4000-8000-000000000001',
   '00000000-0000-0000-0000-000000000000'::uuid, 5, false),
  ('ae100000-0000-4000-8000-000000000001', 'ae400000-0000-4000-8000-000000000002',
   '00000000-0000-0000-0000-000000000000'::uuid, 1, false);

insert into auth.users (id, email)
values
  ('ae500000-0000-4000-8000-000000000001', 'aisf-customer@test.local'),
  ('ae600000-0000-4000-8000-000000000001', 'aisf-manager-b1@test.local'),
  ('ae600000-0000-4000-8000-000000000002', 'aisf-manager-b2@test.local');

insert into identity.profiles (id, full_name, email, phone)
values ('ae500000-0000-4000-8000-000000000001', 'AISF Customer', 'aisf-customer@test.local', '0500000001')
on conflict (id) do nothing;

insert into identity.staff_members (id, user_id, status, full_name, email)
values
  ('ae800000-0000-4000-8000-000000000001', 'ae600000-0000-4000-8000-000000000001', 'active', 'AISF Manager B1', 'aisf-manager-b1@test.local'),
  ('ae800000-0000-4000-8000-000000000002', 'ae600000-0000-4000-8000-000000000002', 'active', 'AISF Manager B2', 'aisf-manager-b2@test.local');

-- manager holds orders.status.update (137), each row scoped to one branch.
insert into identity.staff_roles (staff_id, role_id, branch_id)
select 'ae800000-0000-4000-8000-000000000001', r.id, 'ae100000-0000-4000-8000-000000000001'::uuid
from identity.roles r where r.code = 'manager';

insert into identity.staff_roles (staff_id, role_id, branch_id)
select 'ae800000-0000-4000-8000-000000000002', r.id, 'ae100000-0000-4000-8000-000000000002'::uuid
from identity.roles r where r.code = 'manager';

-- O1: pickup at B1, pending, unpaid, empty. Every total is zero, so
-- ck_orders_total holds without needing to know the brand's tax.
insert into orders.orders (
  id, order_number, user_id, branch_id, fulfillment_type, status, payment_status,
  subtotal, discount_total, delivery_fee, tax_total, grand_total, currency_code,
  customer_note, loyalty_points_earned, idempotency_key
) values (
  'ae700000-0000-4000-8000-000000000001', 'TEST-AISF-1',
  'ae500000-0000-4000-8000-000000000001', 'ae100000-0000-4000-8000-000000000001',
  'pickup', 'pending', 'unpaid',
  0.00, 0.00, 0.00, 0.00, 0.00, 'SAR', 'aisf', 0, 'aisf-test-key-1'
);

-- O2: delivery at B1 in the 15.00 zone, one 40.00 line, so under the 100.00
-- waiver and paying the fee. tax_total and grand_total come from the brand here,
-- the same way admin_recompute_order_totals reads it.
insert into orders.orders (
  id, order_number, user_id, branch_id, fulfillment_type, delivery_zone_id,
  delivery_address_snapshot, status, payment_status,
  subtotal, discount_total, delivery_fee, tax_total, grand_total, currency_code,
  customer_note, loyalty_points_earned, idempotency_key
) values (
  'ae700000-0000-4000-8000-000000000002', 'TEST-AISF-2',
  'ae500000-0000-4000-8000-000000000001', 'ae100000-0000-4000-8000-000000000001',
  'delivery', 'ae200000-0000-4000-8000-000000000001',
  jsonb_build_object('latitude', 24.7136, 'longitude', 46.6753, 'address', 'AISF test address'),
  'pending', 'unpaid',
  40.00, 0.00, 15.00,
  (select case when b.tax_included then 0.00
               else round(40.00 * coalesce(b.tax_rate, 0) / 100, 2) end
     from core.brands b limit 1),
  (select round(55.00
                 + (case when b.tax_included then 0.00
                         else round(40.00 * coalesce(b.tax_rate, 0) / 100, 2) end), 2)
     from core.brands b limit 1),
  'SAR', 'aisf', 0, 'aisf-test-key-2'
);

insert into orders.order_items (
  order_id, product_id, product_name_ar, product_name_en, sku_snapshot,
  unit_price, quantity, line_total, note
) values (
  'ae700000-0000-4000-8000-000000000002', 'ae400000-0000-4000-8000-000000000001',
  'منتج متوفر', 'AISF in stock', 'AISF-IN-STOCK',
  40.00, 1, 40.00, 'aisf fixture line'
);

set local role authenticated;

-- ---------------------------------------------------------------------------
-- 1. Who may edit: this branch's manager yes, another branch's manager no, and a
--    customer not at all.
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"ae600000-0000-4000-8000-000000000002","role":"authenticated","aud":"authenticated"}', true);

do $$
begin
  begin
    perform public.admin_add_order_item(
      'ae700000-0000-4000-8000-000000000001'::uuid,
      'ae400000-0000-4000-8000-000000000001'::uuid, 1);
    raise exception 'FAIL 1: a manager of another branch edited the order';
  exception when others then
    if sqlstate <> '42501' then raise; end if;
  end;
end $$;

select set_config('request.jwt.claims',
  '{"sub":"ae500000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);

do $$
begin
  begin
    perform public.admin_add_order_item(
      'ae700000-0000-4000-8000-000000000001'::uuid,
      'ae400000-0000-4000-8000-000000000001'::uuid, 1);
    raise exception 'FAIL 1: a customer added an admin order line';
  exception when others then
    if sqlstate <> '42501' then raise; end if;
  end;
end $$;

reset role;

do $$
begin
  if (select count(*) from orders.order_items
       where order_id = 'ae700000-0000-4000-8000-000000000001') <> 0 then
    raise exception 'FAIL 1: a refused edit still wrote a line';
  end if;
  if (select count(*) from inventory.stock_movements
       where reference_id = 'ae700000-0000-4000-8000-000000000001') <> 0 then
    raise exception 'FAIL 1: a refused edit still wrote the ledger';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 2. Two lines of the same product: the shelf pays twice, the ledger says once.
--    uq_movement_sale_once (012:77) makes a second row for (order, product)
--    impossible, so the aggregation is what keeps the second edit from aborting
--    with 23505.
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"ae600000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);

select public.admin_add_order_item(
  'ae700000-0000-4000-8000-000000000001'::uuid,
  'ae400000-0000-4000-8000-000000000001'::uuid, 2);

select public.admin_add_order_item(
  'ae700000-0000-4000-8000-000000000001'::uuid,
  'ae400000-0000-4000-8000-000000000001'::uuid, 1);

reset role;

-- Handed over for the removal cases, while the session is still its owner.
select set_config('test.aisf_two_units',
  ((select id from orders.order_items
     where order_id = 'ae700000-0000-4000-8000-000000000001'
       and product_id = 'ae400000-0000-4000-8000-000000000001'
       and quantity = 2)::text), true);
select set_config('test.aisf_one_unit',
  ((select id from orders.order_items
     where order_id = 'ae700000-0000-4000-8000-000000000001'
       and product_id = 'ae400000-0000-4000-8000-000000000001'
       and quantity = 1)::text), true);

do $$
declare
  v_stock    integer;
  v_moves    integer;
  v_delta    integer;
  v_subtotal numeric;
begin
  select bs.quantity_on_hand into v_stock
    from inventory.branch_stock bs
   where bs.branch_id = 'ae100000-0000-4000-8000-000000000001'
     and bs.product_id = 'ae400000-0000-4000-8000-000000000001'
     and bs.variant_key = '00000000-0000-0000-0000-000000000000'::uuid;
  if v_stock <> 2 then
    raise exception 'FAIL 2: three units sold left the shelf at %, expected 2', v_stock;
  end if;

  select count(*), min(sm.quantity_delta) into v_moves, v_delta
    from inventory.stock_movements sm
   where sm.reference_id = 'ae700000-0000-4000-8000-000000000001'
     and sm.product_id = 'ae400000-0000-4000-8000-000000000001'
     and sm.reason = 'sale';
  if v_moves <> 1 then
    raise exception 'FAIL 2: the order holds % rows for one product, expected 1', v_moves;
  end if;
  if v_delta <> -3 then
    raise exception 'FAIL 2: the aggregated movement is %, expected -3', v_delta;
  end if;

  select o.subtotal into v_subtotal
    from orders.orders o where o.id = 'ae700000-0000-4000-8000-000000000001';
  if v_subtotal <> 120.00 then
    raise exception 'FAIL 2: the invoice subtotal is %, expected 120.00', v_subtotal;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 3. Not enough on the shelf: refused before the line is written, so the order
--    is exactly as it was.
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"ae600000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);

do $$
begin
  begin
    perform public.admin_add_order_item(
      'ae700000-0000-4000-8000-000000000001'::uuid,
      'ae400000-0000-4000-8000-000000000002'::uuid, 3);
    raise exception 'FAIL 3: a line was sold out of a shelf holding one unit';
  exception when others then
    if sqlstate <> '23514' then raise; end if;
    if sqlerrm not like 'insufficient stock for product%' then
      raise exception 'FAIL 3: refused with the wrong message: %', sqlerrm;
    end if;
  end;
end $$;

reset role;

do $$
declare
  v_stock integer;
  v_lines integer;
begin
  select bs.quantity_on_hand into v_stock
    from inventory.branch_stock bs
   where bs.branch_id = 'ae100000-0000-4000-8000-000000000001'
     and bs.product_id = 'ae400000-0000-4000-8000-000000000002'
     and bs.variant_key = '00000000-0000-0000-0000-000000000000'::uuid;
  if v_stock <> 1 then
    raise exception 'FAIL 3: a refused line still moved the shelf to %', v_stock;
  end if;

  select count(*) into v_lines
    from orders.order_items oi
   where oi.order_id = 'ae700000-0000-4000-8000-000000000001';
  if v_lines <> 2 then
    raise exception 'FAIL 3: a refused line still wrote a row, the order has % lines', v_lines;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 4. A product the branch does not stock: priced and written, absent from the
--    ledger. The shelf cannot go from nothing to something, so a movement here
--    would be units that cancel_order invents later.
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"ae600000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);

select public.admin_add_order_item(
  'ae700000-0000-4000-8000-000000000001'::uuid,
  'ae400000-0000-4000-8000-000000000003'::uuid, 1);

reset role;

select set_config('test.aisf_unstocked',
  ((select id from orders.order_items
     where order_id = 'ae700000-0000-4000-8000-000000000001'
       and product_id = 'ae400000-0000-4000-8000-000000000003')::text), true);

do $$
declare
  v_moves integer;
  v_rows  integer;
begin
  select count(*) into v_moves
    from inventory.stock_movements sm
   where sm.reference_id = 'ae700000-0000-4000-8000-000000000001'
     and sm.product_id = 'ae400000-0000-4000-8000-000000000003';
  if v_moves <> 0 then
    raise exception 'FAIL 4: a product with no branch_stock row wrote % movement(s)', v_moves;
  end if;

  select count(*) into v_rows
    from inventory.branch_stock bs
   where bs.branch_id = 'ae100000-0000-4000-8000-000000000001'
     and bs.product_id = 'ae400000-0000-4000-8000-000000000003';
  if v_rows <> 0 then
    raise exception 'FAIL 4: the edit created a shelf row for an unstocked product';
  end if;

  if not exists (
    select 1 from orders.order_items oi
     where oi.id = current_setting('test.aisf_unstocked')::uuid
       and oi.unit_price = 25.00 and oi.line_total = 25.00
  ) then
    raise exception 'FAIL 4: the unstocked line is missing or priced wrong';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 5. Removal: the units come back, the ledger shrinks, and the last unit leaves
--    no row behind (ck_movement_delta_nonzero forbids a zero delta, and an order
--    that no longer holds a product has no business appearing in its ledger).
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"ae600000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);

-- The unstocked line first: removing it must not create stock from nothing.
select public.admin_remove_order_item(current_setting('test.aisf_unstocked')::uuid);

-- Then the short line of the stocked product: the sale shrinks from -3 to -2.
select public.admin_remove_order_item(current_setting('test.aisf_one_unit')::uuid);

reset role;

do $$
declare
  v_stock integer;
  v_delta integer;
begin
  if exists (
    select 1 from inventory.branch_stock bs
     where bs.branch_id = 'ae100000-0000-4000-8000-000000000001'
       and bs.product_id = 'ae400000-0000-4000-8000-000000000003'
  ) then
    raise exception 'FAIL 5: removing an unstocked line created a shelf row';
  end if;

  select bs.quantity_on_hand into v_stock
    from inventory.branch_stock bs
   where bs.branch_id = 'ae100000-0000-4000-8000-000000000001'
     and bs.product_id = 'ae400000-0000-4000-8000-000000000001'
     and bs.variant_key = '00000000-0000-0000-0000-000000000000'::uuid;
  if v_stock <> 3 then
    raise exception 'FAIL 5: returning one unit left the shelf at %, expected 3', v_stock;
  end if;

  select sm.quantity_delta into v_delta
    from inventory.stock_movements sm
   where sm.reference_id = 'ae700000-0000-4000-8000-000000000001'
     and sm.product_id = 'ae400000-0000-4000-8000-000000000001'
     and sm.reason = 'sale';
  if v_delta <> -2 then
    raise exception 'FAIL 5: the sale movement is %, expected -2', v_delta;
  end if;

  if (select count(*) from inventory.stock_movements
       where reference_id = 'ae700000-0000-4000-8000-000000000001'
         and reason = 'return') <> 0 then
    raise exception 'FAIL 5: a removal wrote a compensating return row';
  end if;
end $$;

-- And the last line of that product: the sale reaches zero, so it disappears.
select set_config('request.jwt.claims',
  '{"sub":"ae600000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);

select public.admin_remove_order_item(current_setting('test.aisf_two_units')::uuid);

reset role;

do $$
declare
  v_stock integer;
  v_moves integer;
begin
  select bs.quantity_on_hand into v_stock
    from inventory.branch_stock bs
   where bs.branch_id = 'ae100000-0000-4000-8000-000000000001'
     and bs.product_id = 'ae400000-0000-4000-8000-000000000001'
     and bs.variant_key = '00000000-0000-0000-0000-000000000000'::uuid;
  if v_stock <> 5 then
    raise exception 'FAIL 5: the shelf ended at %, expected the original 5', v_stock;
  end if;

  select count(*) into v_moves
    from inventory.stock_movements sm
   where sm.reference_id = 'ae700000-0000-4000-8000-000000000001'
     and sm.reason = 'sale';
  if v_moves <> 0 then
    raise exception 'FAIL 5: % sale row(s) survive an order that holds nothing', v_moves;
  end if;

  if (select subtotal from orders.orders
       where id = 'ae700000-0000-4000-8000-000000000001') <> 0 then
    raise exception 'FAIL 5: an emptied order still bills a subtotal';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 6. The cancellation after all that gives back nothing, because nothing was
--    taken: cancel_order restores sum(sale movements), which is now zero. This is
--    the double credit the shrink-instead-of-return design exists to prevent.
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"ae500000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);

select public.cancel_order('ae700000-0000-4000-8000-000000000001'::uuid, 'aisf test');

reset role;

do $$
declare
  v_stock integer;
begin
  select bs.quantity_on_hand into v_stock
    from inventory.branch_stock bs
   where bs.branch_id = 'ae100000-0000-4000-8000-000000000001'
     and bs.product_id = 'ae400000-0000-4000-8000-000000000001'
     and bs.variant_key = '00000000-0000-0000-0000-000000000000'::uuid;
  if v_stock <> 5 then
    raise exception 'FAIL 6: cancelling an edited order over-restocked the shelf to %', v_stock;
  end if;

  select bs.quantity_on_hand into v_stock
    from inventory.branch_stock bs
   where bs.branch_id = 'ae100000-0000-4000-8000-000000000001'
     and bs.product_id = 'ae400000-0000-4000-8000-000000000002'
     and bs.variant_key = '00000000-0000-0000-0000-000000000000'::uuid;
  if v_stock <> 1 then
    raise exception 'FAIL 6: a product never sold was restocked to %', v_stock;
  end if;

  if (select status from orders.orders
       where id = 'ae700000-0000-4000-8000-000000000001') <> 'cancelled' then
    raise exception 'FAIL 6: the order was not cancelled';
  end if;
end $$;

-- A cancelled order is no longer editable, for an add or a removal alike.
select set_config('request.jwt.claims',
  '{"sub":"ae600000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);

do $$
begin
  begin
    perform public.admin_add_order_item(
      'ae700000-0000-4000-8000-000000000001'::uuid,
      'ae400000-0000-4000-8000-000000000001'::uuid, 1);
    raise exception 'FAIL 6: a cancelled order accepted a new line';
  exception when others then
    if sqlstate <> '22023' then raise; end if;
  end;
end $$;

reset role;

-- ---------------------------------------------------------------------------
-- 7. The delivery fee follows the zone at the new subtotal, in both directions.
--    O2 bills 40.00 in a 15.00 zone that waives the fee at 100.00.
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"ae600000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);

select public.admin_add_order_item(
  'ae700000-0000-4000-8000-000000000002'::uuid,
  'ae400000-0000-4000-8000-000000000004'::uuid, 1);

reset role;

select set_config('test.aisf_fee',
  ((select id from orders.order_items
     where order_id = 'ae700000-0000-4000-8000-000000000002'
       and product_id = 'ae400000-0000-4000-8000-000000000004')::text), true);

do $$
declare
  v_fee      numeric;
  v_subtotal numeric;
begin
  select o.subtotal, o.delivery_fee into v_subtotal, v_fee
    from orders.orders o where o.id = 'ae700000-0000-4000-8000-000000000002';
  if v_subtotal <> 110.00 then
    raise exception 'FAIL 7: the added line left a subtotal of %, expected 110.00', v_subtotal;
  end if;
  if v_fee <> 0 then
    raise exception 'FAIL 7: a 110.00 subtotal in a zone that waives at 100.00 still pays %', v_fee;
  end if;
end $$;

-- Back under the threshold and the zone charges again.
select set_config('request.jwt.claims',
  '{"sub":"ae600000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);

select public.admin_remove_order_item(current_setting('test.aisf_fee')::uuid);

reset role;

do $$
declare
  v_fee      numeric;
  v_subtotal numeric;
begin
  select o.subtotal, o.delivery_fee into v_subtotal, v_fee
    from orders.orders o where o.id = 'ae700000-0000-4000-8000-000000000002';
  if v_subtotal <> 40.00 then
    raise exception 'FAIL 7: removing the line left a subtotal of %', v_subtotal;
  end if;
  if v_fee <> 15.00 then
    raise exception 'FAIL 7: an order back under the waiver pays % instead of the zone fee', v_fee;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 8. A pickup order never asks the zone: O1 started at zero and every case above
--    moved its lines, so its fee is still zero - nothing was invented for an
--    order with no zone to ask.
-- ---------------------------------------------------------------------------
do $$
declare
  v_fee numeric;
begin
  select o.delivery_fee into v_fee
    from orders.orders o where o.id = 'ae700000-0000-4000-8000-000000000001';
  if v_fee <> 0 then
    raise exception 'FAIL 8: a pickup order was charged a delivery fee of %', v_fee;
  end if;
end $$;

select 'admin_order_item_stock_and_fee_test: assertions executed' as result;

rollback;
