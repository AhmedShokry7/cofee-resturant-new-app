-- 049_place_order_option_identity.sql
--
-- Keeps order option snapshots attached to the right line after the cart
-- identity widened in 048_cart_item_identity.sql.
--
-- Before 048 a cart could not hold two lines with the same (product, note), so
-- place_order matched a frozen order_item to its cart line by note alone:
--     join orders.order_items oi on oi.order_id = v_order_id and oi.note = ci.note
-- Now that (product, note, options) is the identity, two lines such as a large
-- and a small latte with an empty note legitimately share a note. The note-only
-- join would then copy each line's options onto every same-note order item.
--
-- fix: order_items carries the same canonical `options_key` as the cart line,
-- and the option snapshot is joined on (order_id, product_id, note, options_key),
-- which is unique per order because the cart key is unique per cart.
--
-- place_order also re-validates each line's stored selection explicitly. It
-- already went through resolve_effective_price() (validated since 046), but a
-- direct call makes the "tampering outside the RPC is caught at checkout"
-- guarantee obvious and independent of resolve's internals.

alter table orders.order_items
  add column if not exists options_key text not null default '';

comment on column orders.order_items.options_key is
  'Canonical option identity copied from the cart line. Pairs each order_item with exactly its own option snapshot.';

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
  v_line_options uuid[];
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

  -- 4. Re-validate and re-price every line server-side, re-check availability.
  for v_line in
    select ci.id, ci.product_id, ci.quantity, ci.note
      from orders.cart_items ci
     where ci.cart_id = p_cart_id
  loop
    v_line_options := coalesce(
      (select array_agg(cio.option_value_id)
         from orders.cart_item_options cio
        where cio.cart_item_id = v_line.id), '{}');

    -- A cart line could have been written outside the RPC, or an option could
    -- have been deactivated since it was added. Reject at checkout.
    perform catalog.validate_product_option_selection(v_line.product_id, v_line_options);

    select r.unit_price, r.is_available
      into v_new_price, v_new_avail
      from catalog.resolve_effective_price(
        v_cart.branch_id, v_line.product_id, v_line_options) r;

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

  -- 9. Freeze every line. options_key keeps each snapshot paired with its line.
  insert into orders.order_items (
    order_id, product_id, option_group_name_ar, option_group_name_en,
    product_name_ar, product_name_en, sku_snapshot, image_snapshot,
    unit_price, quantity, line_total, note, options_key
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
    ci.unit_price, ci.quantity, ci.line_total, ci.note, ci.options_key
  from orders.cart_items ci
  join catalog.products p on p.id = ci.product_id
  where ci.cart_id = p_cart_id;

  insert into orders.order_item_options
    (order_item_id, option_value_id, option_name_ar, option_name_en, price_delta)
  select oi.id, cio.option_value_id, cio.option_name_ar, cio.option_name_en, cio.price_delta
    from orders.cart_items ci
    join orders.cart_item_options cio on cio.cart_item_id = ci.id
    join orders.order_items oi on oi.order_id = v_order_id
                              and oi.product_id = ci.product_id
                              and oi.note = ci.note
                              and oi.options_key = ci.options_key
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
  'Atomic, idempotent order placement. Server-priced, options re-validated, stock-checked, snapshotting, points-awarding.';

notify pgrst, 'reload config';
notify pgrst, 'reload schema';
