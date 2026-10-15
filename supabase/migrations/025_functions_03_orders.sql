-- 025_functions_03_orders.sql
--
-- Cart and order RPCs. This is the heart of the system and the reason the
-- spec insists the client must never be trusted with a price.
--
-- Every function: SECURITY DEFINER, search_path = '', full schema
-- qualification, caller identity taken from auth.uid() only.

create sequence if not exists orders.order_number_seq start 1001;

-- ---------------------------------------------------------------------------
-- Get or create the caller's active cart for a branch (D1: the cart is
-- bound to a branch).
-- ---------------------------------------------------------------------------
create or replace function orders.get_or_create_cart(p_branch_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_uid uuid := auth.uid();
  v_cid uuid;
begin
  if v_uid is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  select c.id into v_cid
    from orders.carts c
   where c.user_id = v_uid
     and c.branch_id = p_branch_id
     and c.status = 'active'
   limit 1;

  if v_cid is null then
    insert into orders.carts (user_id, branch_id)
    values (v_uid, p_branch_id)
    returning id into v_cid;
  end if;

  return v_cid;
end;
$fn$;

-- ---------------------------------------------------------------------------
-- Add or update a cart line. The price is resolved here, from the catalogue.
-- Any price the client sends is ignored.
-- ---------------------------------------------------------------------------
create or replace function orders.upsert_cart_item(
  p_branch_id       uuid,
  p_product_id      uuid,
  p_quantity        integer default 1,
  p_note            text default '',
  p_option_value_ids uuid[] default '{}'
)
returns table (
  cart_item_id uuid,
  unit_price   numeric,
  line_total   numeric,
  item_count   integer
)
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_uid    uuid := auth.uid();
  v_cart   uuid;
  v_price  numeric;
  v_avail  boolean;
  v_reason text;
  v_item   uuid;
  v_line   numeric;
  v_count  integer;
begin
  if v_uid is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if p_quantity is null or p_quantity < 1 then
    raise exception 'quantity must be at least 1' using errcode = '23514';
  end if;

  select r.unit_price, r.is_available, r.unavailable_reason
    into v_price, v_avail, v_reason
    from catalog.resolve_effective_price(p_branch_id, p_product_id, p_option_value_ids) r;

  if not v_avail then
    raise exception 'product % is not available at this branch: %',
      p_product_id, coalesce(v_reason, 'unavailable') using errcode = '23514';
  end if;

  v_cart := orders.get_or_create_cart(p_branch_id);

  -- one row per (product, note), matching the Flutter merge key
  insert into orders.cart_items (cart_id, product_id, quantity, note, unit_price, line_total)
  values (v_cart, p_product_id, least(p_quantity, 99), coalesce(p_note, ''), v_price, round(v_price * least(p_quantity, 99), 2))
  on conflict (cart_id, product_id, note) do update
    set quantity = least(orders.cart_items.quantity + excluded.quantity, 99),
        unit_price = excluded.unit_price,
        line_total = round(excluded.unit_price * least(orders.cart_items.quantity + excluded.quantity, 99), 2)
  returning id into v_item;

  -- rebuild the structured option selections for this line
  delete from orders.cart_item_options where cart_item_id = v_item;

  insert into orders.cart_item_options
    (cart_item_id, option_value_id, option_name_ar, option_name_en, price_delta)
  select v_item, ov.id, ov.name_ar, ov.name_en, ov.price_delta
    from catalog.option_values ov
   where ov.id = any(p_option_value_ids);

  select unit_price, line_total into v_price, v_line
    from orders.cart_items where id = v_item;

  select coalesce(sum(quantity), 0)::integer into v_count
    from orders.cart_items where cart_id = v_cart;

  return query select v_item, v_price, v_line, v_count;
end;
$fn$;

comment on function orders.upsert_cart_item(uuid, uuid, integer, text, uuid[]) is
  'Add to cart. Price comes from resolve_effective_price(); client input is ignored.';

-- ---------------------------------------------------------------------------
-- Remove a cart line, scoped to the caller.
-- ---------------------------------------------------------------------------
create or replace function orders.remove_cart_item(p_cart_item_id uuid)
returns integer
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_count integer;
begin
  delete from orders.cart_items ci
   using orders.carts c
   where ci.id = p_cart_item_id
     and c.id = ci.cart_id
     and c.user_id = auth.uid();

  get diagnostics v_count = row_count;

  select coalesce(sum(quantity), 0)::integer into v_count
    from orders.cart_items
   where cart_id in (select id from orders.carts where user_id = auth.uid() and status = 'active');

  return v_count;
end;
$fn$;

-- ---------------------------------------------------------------------------
-- Cart totals, computed from stored lines. Never from client input.
-- ---------------------------------------------------------------------------
create or replace function orders.get_cart_summary(p_cart_id uuid)
returns table (
  subtotal     numeric,
  item_count   integer
)
language sql
stable
security definer
set search_path = ''
as $fn$
  select coalesce(round(sum(ci.line_total), 2), 0),
         coalesce(sum(ci.quantity), 0)::integer
    from orders.cart_items ci
    join orders.carts c on c.id = ci.cart_id
   where ci.cart_id = p_cart_id
     and c.user_id = auth.uid()
     and c.status = 'active';
$fn$;

-- ---------------------------------------------------------------------------
-- PLACE ORDER
--
-- Atomic, idempotent, fully server-priced. Guarantees:
--   * an idempotency_key can never produce two orders
--   * prices come from the catalogue, never from the client
--   * the branch serves the delivery zone
--   * products are available at that branch
--   * stock is deducted exactly once, inside the same transaction
--   * order_items carry frozen snapshots, so a later price change cannot
--     alter this invoice
-- ---------------------------------------------------------------------------
create or replace function orders.place_order(
  p_cart_id           uuid,
  p_idempotency_key   text,
  p_fulfillment_type  text,
  p_delivery_zone_id  uuid default null,
  p_coupon_code       text default null,
  p_note              text default null
)
returns table (
  order_id      uuid,
  order_number  text,
  subtotal      numeric,
  discount_total numeric,
  delivery_fee  numeric,
  tax_total     numeric,
  grand_total   numeric,
  points_earned integer,
  reused_existing_order boolean
)
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_uid       uuid := auth.uid();
  v_existing  orders.orders%rowtype;
  v_cart      orders.carts%rowtype;
  v_subtotal  numeric := 0;
  v_discount  numeric := 0;
  v_fee       numeric := 0;
  v_tax       numeric := 0;
  v_total     numeric := 0;
  v_tax_rate  numeric;
  v_tax_inc   boolean;
  v_currency  text;
  v_rule      record;
  v_points    integer := 0;
  v_created   boolean := false;
  v_order_id  uuid;
  v_number    text;
  v_line      record;
  v_new_price numeric;
  v_new_avail boolean;
  v_stock     integer;
  v_allow_neg boolean;
  v_zone_ok   boolean;
begin
  if v_uid is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  -- 1. Idempotency. A retry returns the original order untouched.
  select * into v_existing
    from orders.orders o
   where o.idempotency_key = p_idempotency_key
     and o.user_id = v_uid;

  if found then
    return query
      select v_existing.id, v_existing.order_number, v_existing.subtotal,
             v_existing.discount_total, v_existing.delivery_fee,
             v_existing.tax_total, v_existing.grand_total,
             v_existing.loyalty_points_earned, true;
    return;
  end if;

  -- 2. Lock the cart and prove ownership.
  select * into v_cart
    from orders.carts c
   where c.id = p_cart_id
     and c.user_id = v_uid
     and c.status = 'active'
   for update;

  if not found then
    raise exception 'cart not found or not active' using errcode = 'P0002';
  end if;

  if not exists (select 1 from orders.cart_items where cart_id = p_cart_id) then
    raise exception 'cart is empty' using errcode = '23514';
  end if;

  select currency_code, tax_rate, tax_included
    into v_currency, v_tax_rate, v_tax_inc
    from core.brands limit 1;

  -- 3. Delivery zone must be served by this branch (D1).
  if p_fulfillment_type = 'delivery' then
    if p_delivery_zone_id is null then
      raise exception 'delivery zone required' using errcode = '23514';
    end if;
    select exists (
      select 1 from core.delivery_zone_branches z
       where z.zone_id = p_delivery_zone_id and z.branch_id = v_cart.branch_id
    ) into v_zone_ok;
    if not v_zone_ok then
      raise exception 'this branch does not serve the selected delivery zone'
        using errcode = '23514';
    end if;
    select dz.delivery_fee into v_fee
      from core.delivery_zones dz
     where dz.id = p_delivery_zone_id and dz.is_active;
    v_fee := coalesce(v_fee, 0);
  end if;

  -- 4. Re-price every line server-side and re-check availability.
  for v_line in
    select ci.id, ci.product_id, ci.quantity, ci.note
      from orders.cart_items ci
     where ci.cart_id = p_cart_id
  loop
    select r.unit_price, r.is_available
      into v_new_price, v_new_avail
      from catalog.resolve_effective_price(
        v_cart.branch_id, v_line.product_id,
        coalesce((select array_agg(cio.option_value_id)
                    from orders.cart_item_options cio
                   where cio.cart_item_id = v_line.id), '{}')
      ) r;

    if not v_new_avail then
      raise exception 'product % is no longer available at this branch', v_line.product_id
        using errcode = '23514';
    end if;

    -- price changed since it was added to the cart: re-price the line
    update orders.cart_items
       set unit_price = v_new_price,
           line_total = round(v_new_price * v_line.quantity, 2)
     where id = v_line.id;
  end loop;

  select coalesce(round(sum(line_total), 2), 0) into v_subtotal
    from orders.cart_items where cart_id = p_cart_id;

  -- 5. Coupon, validated server-side.
  if nullif(btrim(coalesce(p_coupon_code, '')), '') is not null then
    select coalesce(max(v.discount), 0) into v_discount
      from marketing.validate_coupon(p_coupon_code, v_subtotal, v_cart.branch_id) v;
    v_discount := least(v_discount, v_subtotal);
  end if;

  -- 6. Tax.
  if v_tax_inc then
    v_tax := 0;
  else
    v_tax := round((v_subtotal - v_discount) * v_tax_rate / 100, 2);
  end if;

  v_total := round(v_subtotal - v_discount + v_fee + v_tax, 2);

  -- 7. Points earned, from the active rule.
  select coalesce(max(points), 0) into v_points
    from ( select floor((v_subtotal - v_discount) * r.points_per_currency_unit)::integer as points
             from loyalty.loyalty_rules r
            where r.is_active
              and (r.valid_to is null or r.valid_to > now())
            order by r.valid_from desc
            limit 1 ) s;
  v_points := greatest(coalesce(v_points, 0), 0);

  -- 8. Create the order.
  v_number := 'ORD-' || to_char(now(), 'YYYY') || '-' ||
              lpad(nextval('orders.order_number_seq')::text, 6, '0');

  insert into orders.orders (
    order_number, user_id, branch_id, fulfillment_type, delivery_zone_id,
    status, payment_status, subtotal, discount_total, delivery_fee,
    tax_total, grand_total, currency_code, customer_note,
    loyalty_points_earned, idempotency_key
  ) values (
    v_number, v_uid, v_cart.branch_id, p_fulfillment_type, p_delivery_zone_id,
    'pending', 'unpaid', v_subtotal, v_discount, v_fee,
    v_tax, v_total, v_currency, coalesce(p_note, ''),
    v_points, p_idempotency_key
  ) returning id into v_order_id;

  -- 9. Freeze every line.
  insert into orders.order_items (
    order_id, product_id, option_group_name_ar, option_group_name_en,
    product_name_ar, product_name_en, sku_snapshot, image_snapshot,
    unit_price, quantity, line_total, note
  )
  select
    v_order_id, ci.product_id,
    coalesce((select string_agg(g.name_ar, '، ') from catalog.option_groups g
               join catalog.option_values ov on ov.group_id = g.id
               join orders.cart_item_options cio on cio.option_value_id = ov.id
              where cio.cart_item_id = ci.id), ''),
    coalesce((select string_agg(g.name_en, ', ') from catalog.option_groups g
               join catalog.option_values ov on ov.group_id = g.id
               join orders.cart_item_options cio on cio.option_value_id = ov.id
              where cio.cart_item_id = ci.id), ''),
    p.name_ar, p.name_en, p.sku, p.image_url,
    ci.unit_price, ci.quantity, ci.line_total, ci.note
  from orders.cart_items ci
  join catalog.products p on p.id = ci.product_id
  where ci.cart_id = p_cart_id;

  insert into orders.order_item_options
    (order_item_id, option_value_id, option_name_ar, option_name_en, price_delta)
  select oi.id, cio.option_value_id, cio.option_name_ar, cio.option_name_en, cio.price_delta
    from orders.cart_items ci
    join orders.cart_item_options cio on cio.cart_item_id = ci.id
    join orders.order_items oi on oi.order_id = v_order_id and oi.note = ci.note
   where ci.cart_id = p_cart_id;

  -- 10. Deduct stock exactly once.
  --     A product with NO branch_stock row is treated as untracked
  --     (available indefinitely). A product WITH a row must have stock.
  for v_line in
    select ci.product_id, ci.quantity
      from orders.cart_items ci
     where ci.cart_id = p_cart_id
  loop
    select bs.quantity_on_hand, bs.allow_negative
      into v_stock, v_allow_neg
      from inventory.branch_stock bs
     where bs.branch_id = v_cart.branch_id
       and bs.product_id = v_line.product_id
       and bs.variant_key = '00000000-0000-0000-0000-000000000000'::uuid
     for update;

    if found and not v_allow_neg and v_stock < v_line.quantity then
      raise exception 'insufficient stock for product %', v_line.product_id
        using errcode = '23514';
    end if;

    if found then
      update inventory.branch_stock
         set quantity_on_hand = quantity_on_hand - v_line.quantity,
             updated_at = now()
       where branch_id = v_cart.branch_id
         and product_id = v_line.product_id
         and variant_key = '00000000-0000-0000-0000-000000000000'::uuid;

      -- unique index uq_movement_sale_once makes a repeat insert impossible
      insert into inventory.stock_movements
        (branch_id, product_id, variant_key, quantity_delta, reason,
         reference_type, reference_id, actor_user_id)
      values
        (v_cart.branch_id, v_line.product_id,
         '00000000-0000-0000-0000-000000000000'::uuid,
         -v_line.quantity, 'sale', 'order', v_order_id, v_uid);
    end if;
  end loop;

  -- 11. Coupon redemption.
  if v_discount > 0 and nullif(btrim(coalesce(p_coupon_code, '')), '') is not null then
    insert into marketing.coupon_redemptions (coupon_id, user_id, order_id, amount)
    select c.id, v_uid, v_order_id, v_discount
      from marketing.coupons c
     where c.code = upper(btrim(p_coupon_code))
    on conflict (coupon_id, order_id) do nothing;
  end if;

  -- 12. Award points through the ledger.
  if v_points > 0 then
    perform loyalty.apply_points(v_uid, v_points, 'earn_order', 'order', v_order_id,
      'earned on order ' || v_number);
  end if;

  -- 13. Close the cart and record the first status transition.
  update orders.carts set status = 'converted', updated_at = now()
   where id = p_cart_id;

  insert into orders.order_status_history (order_id, from_status, to_status, changed_by, note)
  values (v_order_id, null, 'pending', v_uid, 'order placed');

  insert into orders.order_events (order_id, event_type, payload)
  values (v_order_id, 'order.placed', jsonb_build_object('total', v_total, 'branch', v_cart.branch_id));

  return query
    select v_order_id, v_number, v_subtotal, v_discount, v_fee, v_tax, v_total, v_points, false;
end;
$fn$;

comment on function orders.place_order is
  'Atomic, idempotent order placement. Server-priced, stock-checked, snapshotting, points-awarding.';

-- ---------------------------------------------------------------------------
-- Status transitions, constrained by the lookup table.
-- ---------------------------------------------------------------------------
create or replace function orders.update_order_status(p_order_id uuid, p_to_status text, p_note text default null)
returns boolean
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_order orders.orders%rowtype;
  v_uid   uuid := auth.uid();
  v_ok    boolean;
begin
  select * into v_order from orders.orders where id = p_order_id for update;

  if not found then
    raise exception 'order % not found', p_order_id using errcode = 'P0002';
  end if;

  select st.is_allowed into v_ok
    from orders.status_transitions st
   where st.from_status = v_order.status and st.to_status = p_to_status;

  if v_ok is null then
    raise exception 'unknown transition % -> %', v_order.status, p_to_status
      using errcode = '23514';
  end if;
  if not v_ok then
    raise exception 'transition % -> % is not allowed', v_order.status, p_to_status
      using errcode = '23514';
  end if;

  update orders.orders
     set status = p_to_status,
         completed_at = case when p_to_status = 'completed' then now() else completed_at end,
         cancelled_at = case when p_to_status = 'cancelled' then now() else cancelled_at end
   where id = p_order_id;

  insert into orders.order_status_history (order_id, from_status, to_status, changed_by, note)
  values (p_order_id, v_order.status, p_to_status, v_uid, p_note);

  return true;
end;
$fn$;

-- ---------------------------------------------------------------------------
-- Cancel and return stock, exactly once.
-- ---------------------------------------------------------------------------
create or replace function orders.cancel_order(p_order_id uuid, p_reason text default null)
returns boolean
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_order orders.orders%rowtype;
  v_uid   uuid := auth.uid();
  v_line  record;
begin
  select * into v_order from orders.orders where id = p_order_id for update;
  if not found then
    raise exception 'order % not found', p_order_id using errcode = 'P0002';
  end if;

  -- the owner may cancel while it is not yet completed
  if v_order.user_id <> v_uid and not identity.has_permission('orders.cancel') then
    raise exception 'not permitted to cancel this order' using errcode = '42501';
  end if;
  if v_order.status in ('completed','cancelled') then
    raise exception 'order is already %', v_order.status using errcode = '23514';
  end if;

  update orders.orders
     set status = 'cancelled', cancelled_at = now(), cancel_reason = p_reason
   where id = p_order_id;

  -- return stock, guarded by the partial unique index on reason='sale'
  for v_line in
    select oi.product_id, oi.quantity
      from orders.order_items oi
     where oi.order_id = p_order_id and oi.product_id is not null
  loop
    if exists (
      select 1 from inventory.branch_stock bs
       where bs.branch_id = v_order.branch_id
         and bs.product_id = v_line.product_id
         and bs.variant_key = '00000000-0000-0000-0000-000000000000'::uuid
    ) then
      update inventory.branch_stock
         set quantity_on_hand = quantity_on_hand + v_line.quantity,
             updated_at = now()
       where branch_id = v_order.branch_id
         and product_id = v_line.product_id
         and variant_key = '00000000-0000-0000-0000-000000000000'::uuid;

      insert into inventory.stock_movements
        (branch_id, product_id, variant_key, quantity_delta, reason,
         reference_type, reference_id, actor_user_id, note)
      values
        (v_order.branch_id, v_line.product_id,
         '00000000-0000-0000-0000-000000000000'::uuid,
         v_line.quantity, 'cancellation', 'order', p_order_id, v_uid, p_reason)
      on conflict do nothing;
    end if;
  end loop;

  -- claw back earned points
  if v_order.loyalty_points_earned > 0 then
    perform loyalty.apply_points(v_order.user_id, -v_order.loyalty_points_earned,
      'refund', 'order', p_order_id, 'points reversed on cancellation');
  end if;

  insert into orders.order_status_history (order_id, from_status, to_status, changed_by, note)
  values (p_order_id, v_order.status, 'cancelled', v_uid, p_reason);

  return true;
end;
$fn$;

comment on function orders.cancel_order is
  'Cancels an order, returns stock exactly once, and reverses earned points.';