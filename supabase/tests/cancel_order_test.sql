-- cancel_order_test.sql
-- Behaviour tests for orders.cancel_order (migration 107).
--
-- RUN THIS ONLY AGAINST AN ISOLATED, NON-PRODUCTION DATABASE.
--
-- Every fixture lives in one transaction that is rolled back, so the test
-- leaves nothing behind.

\set ON_ERROR_STOP on

begin;

-- ---------------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------------
insert into auth.users (id, email)
values ('c0ffee00-0000-4000-8000-000000000001', 'cancel-test@test.local');

insert into identity.profiles (id, full_name, email)
select 'c0ffee00-0000-4000-8000-000000000001', 'Cancel Test', 'cancel-test@test.local'
where not exists (
  select 1 from identity.profiles where id = 'c0ffee00-0000-4000-8000-000000000001'
);

-- A branch of the seed, a product of the seed and the stock of that product.
create temporary table probe as
select (select id from core.branches order by id limit 1) as branch_id,
       (select id from catalog.products where is_active order by id limit 1) as product_id,
       (select id from catalog.products where is_active order by id desc limit 1) as other_product_id;

insert into inventory.branch_stock (branch_id, product_id, variant_key, quantity_on_hand, allow_negative)
select branch_id, product_id, '00000000-0000-0000-0000-000000000000'::uuid, 10, false from probe
on conflict (branch_id, product_id, variant_key) do update set quantity_on_hand = 10;

insert into inventory.branch_stock (branch_id, product_id, variant_key, quantity_on_hand, allow_negative)
select branch_id, other_product_id, '00000000-0000-0000-0000-000000000000'::uuid, 10, false from probe
on conflict (branch_id, product_id, variant_key) do update set quantity_on_hand = 10;

-- An order in `pending` that was paid for in stock: one product was deducted
-- (the movement says so), the other one was not.
insert into orders.orders (
  id, order_number, user_id, branch_id, fulfillment_type, status, payment_status,
  subtotal, discount_total, delivery_fee, tax_total, grand_total, currency_code,
  customer_note, loyalty_points_earned, idempotency_key
)
select 'c0ffee00-0000-4000-8000-000000000010', 'TEST-CANCEL-1',
       'c0ffee00-0000-4000-8000-000000000001', branch_id, 'pickup', 'pending', 'unpaid',
       20.00, 0.00, 0.00, 0.00, 20.00, 'SAR', 'test', 0, 'cancel-test-key-1'
  from probe;

insert into orders.order_items (
  order_id, product_id, product_name_ar, product_name_en, sku_snapshot,
  unit_price, quantity, line_total, note
)
select 'c0ffee00-0000-4000-8000-000000000010'::uuid, p.id,
       p.name_ar, p.name_en, p.sku, 10.00, 1, 10.00, ''
  from probe q join catalog.products p on p.id = q.product_id
union all
select 'c0ffee00-0000-4000-8000-000000000010'::uuid, p.id,
       p.name_ar, p.name_en, p.sku, 10.00, 1, 10.00, ''
  from probe q join catalog.products p on p.id = q.other_product_id;

-- The deduction of the first product, and only of the first product.
insert into inventory.stock_movements (
  branch_id, product_id, variant_key, quantity_delta, reason,
  reference_type, reference_id
)
select branch_id, product_id, '00000000-0000-0000-0000-000000000000'::uuid,
       -1, 'sale', 'order', 'c0ffee00-0000-4000-8000-000000000010'::uuid
  from probe;

update inventory.branch_stock bs
   set quantity_on_hand = bs.quantity_on_hand - 1
  from probe p
 where bs.branch_id = p.branch_id
   and bs.product_id = p.product_id
   and bs.variant_key = '00000000-0000-0000-0000-000000000000'::uuid;

-- ---------------------------------------------------------------------------
-- 1. The customer cancels: the stock comes back for the deducted product only
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"c0ffee00-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);

select public.cancel_order('c0ffee00-0000-4000-8000-000000000010'::uuid, 'test');

do $$
declare
  v_deducted  integer;
  v_untouched integer;
begin
  select bs.quantity_on_hand into v_deducted
    from inventory.branch_stock bs, probe p
   where bs.branch_id = p.branch_id and bs.product_id = p.product_id
     and bs.variant_key = '00000000-0000-0000-0000-000000000000'::uuid;
  if v_deducted <> 10 then
    raise exception 'FAIL: the deducted product was not given back (it has %)', v_deducted;
  end if;

  select bs.quantity_on_hand into v_untouched
    from inventory.branch_stock bs, probe p
   where bs.branch_id = p.branch_id and bs.product_id = p.other_product_id
     and bs.variant_key = '00000000-0000-0000-0000-000000000000'::uuid;
  if v_untouched <> 10 then
    raise exception 'FAIL: a product that was never deducted was given stock (it has %)', v_untouched;
  end if;

  if (select status from orders.orders where id = 'c0ffee00-0000-4000-8000-000000000010'::uuid) <> 'cancelled' then
    raise exception 'FAIL: the order was not cancelled';
  end if;

  if not exists (
    select 1 from inventory.stock_movements
     where reference_id = 'c0ffee00-0000-4000-8000-000000000010'::uuid
       and reason = 'cancellation' and quantity_delta = 1
  ) then
    raise exception 'FAIL: the cancellation movement is missing';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 2. The second cancellation is refused and the stock is not given back twice
-- ---------------------------------------------------------------------------
do $$
declare
  v_quantity integer;
begin
  begin
    perform public.cancel_order('c0ffee00-0000-4000-8000-000000000010'::uuid, 'again');
    raise exception 'FAIL: the second cancellation succeeded';
  exception
    when others then
      if sqlstate <> '23514' then raise; end if;
  end;

  select bs.quantity_on_hand into v_quantity
    from inventory.branch_stock bs, probe p
   where bs.branch_id = p.branch_id and bs.product_id = p.product_id
     and bs.variant_key = '00000000-0000-0000-0000-000000000000'::uuid;
  if v_quantity <> 10 then
    raise exception 'FAIL: the stock was given back twice (it has %)', v_quantity;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 3. An order that left the kitchen cannot be cancelled
-- ---------------------------------------------------------------------------
insert into orders.orders (
  id, order_number, user_id, branch_id, fulfillment_type, status, payment_status,
  subtotal, discount_total, delivery_fee, tax_total, grand_total, currency_code,
  customer_note, loyalty_points_earned, idempotency_key
)
select 'c0ffee00-0000-4000-8000-000000000011', 'TEST-CANCEL-2',
       'c0ffee00-0000-4000-8000-000000000001', branch_id, 'pickup', 'ready', 'unpaid',
       20.00, 0.00, 0.00, 0.00, 20.00, 'SAR', 'test', 0, 'cancel-test-key-2'
  from probe;

do $$
begin
  begin
    perform public.cancel_order('c0ffee00-0000-4000-8000-000000000011'::uuid, 'too late');
    raise exception 'FAIL: a ready order was cancelled';
  exception
    when others then
      if sqlstate <> '23514' then raise; end if;
  end;
end $$;

-- ---------------------------------------------------------------------------
-- 4. A paid order cannot be cancelled behind the back of the refund
-- ---------------------------------------------------------------------------
insert into orders.orders (
  id, order_number, user_id, branch_id, fulfillment_type, status, payment_status,
  subtotal, discount_total, delivery_fee, tax_total, grand_total, currency_code,
  customer_note, loyalty_points_earned, idempotency_key
)
select 'c0ffee00-0000-4000-8000-000000000012', 'TEST-CANCEL-3',
       'c0ffee00-0000-4000-8000-000000000001', branch_id, 'pickup', 'confirmed', 'paid',
       20.00, 0.00, 0.00, 0.00, 20.00, 'SAR', 'test', 0, 'cancel-test-key-3'
  from probe;

do $$
begin
  begin
    perform public.cancel_order('c0ffee00-0000-4000-8000-000000000012'::uuid, 'paid');
    raise exception 'FAIL: a paid order was cancelled';
  exception
    when others then
      if sqlstate <> '23514' then raise; end if;
  end;

  if (select status from orders.orders where id = 'c0ffee00-0000-4000-8000-000000000012'::uuid) <> 'confirmed' then
    raise exception 'FAIL: the paid order was cancelled';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 5. A stranger cannot cancel the order of a customer
-- ---------------------------------------------------------------------------
insert into auth.users (id, email)
values ('c0ffee00-0000-4000-8000-000000000003', 'stranger@test.local');

insert into identity.profiles (id, full_name, email)
select 'c0ffee00-0000-4000-8000-000000000003', 'Stranger', 'stranger@test.local'
where not exists (
  select 1 from identity.profiles where id = 'c0ffee00-0000-4000-8000-000000000003'
);

select set_config('request.jwt.claims',
  '{"sub":"c0ffee00-0000-4000-8000-000000000003","role":"authenticated","aud":"authenticated"}', true);

do $$
begin
  begin
    perform public.cancel_order('c0ffee00-0000-4000-8000-000000000011'::uuid, 'not mine');
    raise exception 'FAIL: a stranger cancelled the order';
  exception
    when others then
      if sqlstate <> '42501' then raise; end if;
  end;
end $$;

reset role;

rollback;
