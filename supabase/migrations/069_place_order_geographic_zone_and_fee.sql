-- 069_place_order_geographic_zone_and_fee.sql
--
-- 068 made delivery zones real geography and gave each zone a fee rule. The
-- checkout could now *display* the right fee, but the invoice is the server's:
-- place_order still read the flat `delivery_fee` column and never checked that
-- the address was inside the chosen zone. A client could name any zone its
-- branch served — or none that covers the customer — and be charged the old
-- flat amount.
--
-- This re-emits place_order_impl with two additions and nothing else changed:
--
--   1. When the address has coordinates, the chosen zone must actually cover
--      it, or the order is refused. An address with no coordinates is still
--      accepted, because the app offers manual zone choice for exactly those
--      legacy rows and refusing them would strand customers who saved an
--      address before the map picker existed.
--   2. The fee comes from core.delivery_zone_fee(...) with the real subtotal, so
--      per-km pricing and the free-delivery threshold are applied by the same
--      function the app used to quote. The customer can no longer be quoted one
--      number and charged another.
--
-- Same signature, same return columns, same idempotency, same stock and coupon
-- handling as 055. CREATE OR REPLACE keeps the 058 grants.

create or replace function orders.place_order_impl(
  p_cart_id uuid,
  p_idempotency_key text,
  p_fulfillment_type text,
  p_delivery_zone_id uuid default null,
  p_coupon_code text default null,
  p_note text default null,
  p_address_id uuid default null
)
returns table (
  order_id uuid,
  order_number text,
  subtotal numeric,
  discount_total numeric,
  delivery_fee numeric,
  tax_total numeric,
  grand_total numeric,
  points_earned integer,
  reused_existing_order boolean
)
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_uid       uuid := auth.uid();
  v_existing  orders.orders%rowtype;
  v_cart      orders.carts%rowtype;
  v_subtotal  numeric := 0;
  v_discount  numeric := 0;
  v_fee       numeric := 0;
  v_min       numeric;
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
  v_zone_name_ar text;
  v_zone_name_en text;
  v_addr      record;
  v_snapshot  jsonb;
begin
  if v_uid is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
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
    -- The fee is no longer read here: it depends on the subtotal, which is not
    -- known until the cart lines have been repriced below.
    select dz.min_order_amount, dz.name_ar, dz.name_en
      into v_min, v_zone_name_ar, v_zone_name_en
      from core.delivery_zones dz
     where dz.id = p_delivery_zone_id and dz.is_active;
    if not found then
      raise exception 'delivery zone is not active' using errcode = '23514';
    end if;
    if p_address_id is null then
      raise exception 'delivery address required' using errcode = '23514';
    end if;
    select a.label, a.details, a.latitude, a.longitude
      into v_addr
      from identity.customer_addresses a
     where a.id = p_address_id
       and a.user_id = v_uid
       and a.archived_at is null;
    if not found then
      raise exception 'delivery address not found' using errcode = '23514';
    end if;
    v_snapshot := jsonb_build_object(
      'address_id', p_address_id,
      'label', v_addr.label,
      'details', v_addr.details,
      'latitude', v_addr.latitude,
      'longitude', v_addr.longitude,
      'zone_id', p_delivery_zone_id,
      'zone_name_ar', v_zone_name_ar,
      'zone_name_en', v_zone_name_en
    );
  end if;
  for v_line in
    select ci.id, ci.product_id, ci.quantity, ci.note
      from orders.cart_items ci
     where ci.cart_id = p_cart_id
  loop
    v_line_options := coalesce(
      (select array_agg(cio.option_value_id)
         from orders.cart_item_options cio
        where cio.cart_item_id = v_line.id), '{}');
    perform catalog.validate_product_option_selection(v_line.product_id, v_line_options);
    select r.unit_price, r.is_available
      into v_new_price, v_new_avail
      from catalog.resolve_effective_price(
        v_cart.branch_id, v_line.product_id, v_line_options) r;
    if not v_new_avail then
      raise exception 'product % is no longer available at this branch', v_line.product_id
        using errcode = '23514';
    end if;
    update orders.cart_items
       set unit_price = v_new_price,
           line_total = round(v_new_price * v_line.quantity, 2)
     where id = v_line.id;
  end loop;
  select coalesce(round(sum(line_total), 2), 0) into v_subtotal
    from orders.cart_items where cart_id = p_cart_id;
  if p_fulfillment_type = 'delivery' then
    -- Geography, now that the address is known. Skipped when the address has no
    -- coordinates: manual zone choice is the documented fallback for those.
    if v_addr.latitude is not null and v_addr.longitude is not null then
      v_zone_ok := core.zone_covers_point(
        p_delivery_zone_id, v_addr.latitude, v_addr.longitude
      );
      if not v_zone_ok then
        raise exception 'delivery address is outside the selected delivery zone'
          using errcode = '23514';
      end if;
    end if;
    -- One function decides the price, so the app's quote and the invoice cannot
    -- disagree. free_delivery_over needs the real subtotal, which is why this
    -- cannot run any earlier.
    v_fee := core.delivery_zone_fee(
      p_delivery_zone_id, v_cart.branch_id,
      v_addr.latitude, v_addr.longitude, v_subtotal
    );
    if v_min is not null and v_subtotal < v_min then
      raise exception 'order total is below the minimum for this delivery zone'
        using errcode = '23514';
    end if;
  end if;
  if nullif(btrim(coalesce(p_coupon_code, '')), '') is not null then
    select coalesce(max(v.discount), 0) into v_discount
      from marketing.validate_coupon(p_coupon_code, v_subtotal, v_cart.branch_id) v;
    v_discount := least(v_discount, v_subtotal);
  end if;
  if v_tax_inc then
    v_tax := 0;
  else
    v_tax := round((v_subtotal - v_discount) * v_tax_rate / 100, 2);
  end if;
  v_total := round(v_subtotal - v_discount + v_fee + v_tax, 2);
  select coalesce(max(points), 0) into v_points
    from ( select floor((v_subtotal - v_discount) * r.points_per_currency_unit)::integer as points
             from loyalty.loyalty_rules r
            where r.is_active
              and (r.valid_to is null or r.valid_to > now())
            order by r.valid_from desc
            limit 1 ) s;
  v_points := greatest(coalesce(v_points, 0), 0);
  v_number := 'ORD-' || to_char(now(), 'YYYY') || '-' ||
              lpad(nextval('orders.order_number_seq')::text, 6, '0');
  insert into orders.orders (
    order_number, user_id, branch_id, fulfillment_type, delivery_zone_id,
    delivery_address_snapshot,
    status, payment_status, subtotal, discount_total, delivery_fee,
    tax_total, grand_total, currency_code, customer_note,
    loyalty_points_earned, idempotency_key
  ) values (
    v_number, v_uid, v_cart.branch_id, p_fulfillment_type, p_delivery_zone_id,
    coalesce(v_snapshot, '{}'::jsonb),
    'pending', 'unpaid', v_subtotal, v_discount, v_fee,
    v_tax, v_total, v_currency, coalesce(p_note, ''),
    v_points, p_idempotency_key
  ) returning id into v_order_id;
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
  -- Aggregate the cart lines per product so a product split across several
  -- lines produces one stock deduction and one 'sale' movement, which keeps the
  -- uq_movement_sale_once index satisfied.
  for v_line in
    select ci.product_id, sum(ci.quantity) as quantity
      from orders.cart_items ci
     where ci.cart_id = p_cart_id
     group by ci.product_id
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
      insert into inventory.stock_movements
        (branch_id, product_id, variant_key, quantity_delta, reason,
         reference_type, reference_id, actor_user_id)
      values
        (v_cart.branch_id, v_line.product_id,
         '00000000-0000-0000-0000-000000000000'::uuid,
         -v_line.quantity, 'sale', 'order', v_order_id, v_uid);
    end if;
  end loop;
  if v_discount > 0 and nullif(btrim(coalesce(p_coupon_code, '')), '') is not null then
    insert into marketing.coupon_redemptions (coupon_id, user_id, order_id, amount)
    select c.id, v_uid, v_order_id, v_discount
      from marketing.coupons c
     where c.code = upper(btrim(p_coupon_code))
       and not exists (select 1 from marketing.coupon_redemptions cr
                        where cr.coupon_id = c.id and cr.order_id = v_order_id);
  end if;
  if v_points > 0 then
    perform loyalty.apply_points(v_uid, v_points, 'earn_order', 'order', v_order_id,
      'earned on order ' || v_number);
  end if;
  update orders.carts set status = 'converted', updated_at = now()
   where id = p_cart_id;
  insert into orders.order_status_history (order_id, from_status, to_status, changed_by, note)
  values (v_order_id, null, 'pending', v_uid, 'order placed');
  insert into orders.order_events (order_id, event_type, payload)
  values (v_order_id, 'order.placed', jsonb_build_object('total', v_total, 'branch', v_cart.branch_id));
  return query
    select v_order_id, v_number, v_subtotal, v_discount, v_fee, v_tax, v_total, v_points, false;
end;
$function$;

notify pgrst, 'reload schema';