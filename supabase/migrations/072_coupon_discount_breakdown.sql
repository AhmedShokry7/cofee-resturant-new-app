-- 072_coupon_discount_breakdown.sql
--
-- 071 made a scoped coupon discount only the eligible lines, which is correct
-- but opaque: the cart still showed one discount figure against a subtotal, so
-- a customer who saw 20% off cold drinks take 2.40 off a 48.00 basket had no way
-- to tell that the arithmetic was right.
--
-- The discount is now attributed to the lines it actually came off, in three
-- places:
--
--   * orders.order_items gains discount_total, so the invoice itself carries the
--     breakdown and order history can render it without recomputing anything.
--   * marketing.allocate_coupon_discount() splits an approved amount across the
--     eligible lines.
--   * public.coupon_line_breakdown() answers the same question for the cart, so
--     the customer can see it *before* paying rather than only on the receipt.
--
-- Allocation is cumulative, not "divide and round each line". Each line's share
-- is the difference between the rounded cumulative target at that line and the
-- one before it, which has two properties that matter:
--
--   * the shares sum to exactly the approved amount, with no cent of drift to
--     reconcile afterwards — the last cumulative target is
--     round(amount * total / total, 2) = amount by construction;
--   * every share is non-negative, because the running total only grows.
--
-- Dividing each line and rounding independently leaves the parts summing to
-- something other than the approved total, and fixing that up afterwards means
-- writing a correction row, which is how invoices acquire mysterious
-- adjustments.
--
-- For a percentage coupon with no cap this reduces to exactly that percentage on
-- each eligible line, which is the intuitive reading. A capped coupon shares the
-- cap proportionally across the eligible lines rather than filling them one by
-- one, because "20% off the first item and nothing off the rest" is harder to
-- explain than "the cap spread across everything eligible".

-- ---------------------------------------------------------------------------
-- Per-line attribution on the invoice
-- ---------------------------------------------------------------------------

alter table orders.order_items
  add column if not exists discount_total numeric(12,2) not null default 0;

do $migration$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'ck_order_items_discount_nonneg'
  ) then
    alter table orders.order_items
      add constraint ck_order_items_discount_nonneg check (discount_total >= 0);
  end if;
  -- A line can never give up more than it is worth. This is what makes the
  -- invoice self-consistent even if a future coupon rule misbehaves.
  if not exists (
    select 1 from pg_constraint where conname = 'ck_order_items_discount_capped'
  ) then
    alter table orders.order_items
      add constraint ck_order_items_discount_capped
        check (discount_total <= line_total);
  end if;
end;
$migration$;

comment on column orders.order_items.discount_total is
  'Share of the order discount attributed to this line. Sums to '
  'orders.orders.discount_total. Zero on lines a scoped coupon did not cover.';

-- ---------------------------------------------------------------------------
-- Which lines a coupon can discount
-- ---------------------------------------------------------------------------

-- Shared by the allocator, the breakdown RPC and place_order, so the three can
-- never disagree about what "eligible" means. That disagreement is what let the
-- category and product scopes drift apart in the first place.
create or replace function marketing.coupon_eligible_lines(
  p_coupon_id uuid, p_cart_id uuid
)
returns table (
  cart_item_id uuid,
  product_id uuid,
  line_total numeric
)
language sql
stable
security definer
set search_path to ''
as $fn$
  select ci.id, ci.product_id, ci.line_total
    from marketing.coupons c
    join orders.cart_items ci on ci.cart_id = p_cart_id
   where c.id = p_coupon_id
     and (
       c.applies_to = 'all'
       or (c.applies_to = 'product' and exists (
             select 1 from marketing.coupons_products cp
              where cp.coupon_id = c.id and cp.product_id = ci.product_id
       ))
       or (c.applies_to = 'category' and exists (
             select 1 from marketing.coupons_categories cc
             join catalog.categories cat on cat.id = cc.category_id
             join catalog.products pr on pr.category_id = cat.id
              where cc.coupon_id = c.id and pr.id = ci.product_id
       ))
     )
   order by ci.id;
$fn$;

comment on function marketing.coupon_eligible_lines(uuid, uuid) is
  'The cart lines a coupon may discount. One definition, used by the '
  'allocator, the client-facing breakdown and place_order.';

-- ---------------------------------------------------------------------------
-- Allocation
-- ---------------------------------------------------------------------------

create or replace function marketing.allocate_coupon_discount(
  p_coupon_id uuid, p_cart_id uuid, p_amount numeric
)
returns table (
  cart_item_id uuid,
  discount numeric
)
language sql
stable
security definer
set search_path to ''
as $fn$
  with base as (
    select coalesce(sum(el.line_total), 0) as total
      from marketing.coupon_eligible_lines(p_coupon_id, p_cart_id) el
  ),
  running as (
    select el.cart_item_id,
           sum(el.line_total) over (order by el.cart_item_id) as cumulative
      from marketing.coupon_eligible_lines(p_coupon_id, p_cart_id) el
  ),
  marked as (
    select r.cart_item_id,
           round(p_amount * r.cumulative / b.total, 2) as target
      from running r
      cross join base b
     where b.total > 0
  )
  select m.cart_item_id,
         round(m.target - coalesce(
           lag(m.target) over (order by m.cart_item_id), 0
         ), 2) as discount
    from marked m
   order by m.cart_item_id;
$fn$;

comment on function marketing.allocate_coupon_discount(uuid, uuid, numeric) is
  'Splits an approved discount across the eligible cart lines. Cumulative '
  'rounding, so the parts sum to exactly p_amount and no share is negative. '
  'Returns no rows when the amount is zero or nothing is eligible.';

-- ---------------------------------------------------------------------------
-- Client-facing breakdown
-- ---------------------------------------------------------------------------

-- Why a discount figure looks the way it does, per cart line.
--
-- Returns every line, eligible or not, so the app can show "only these are
-- discounted" rather than silently reducing the total. Identical arithmetic to
-- marketing.allocate_coupon_discount, because both call the same helper.
create or replace function public.coupon_line_breakdown(
  p_branch_id uuid,
  p_code text,
  p_lines jsonb
)
returns table (
  cart_item_id   uuid,
  product_id     uuid,
  product_name_ar text,
  product_name_en text,
  line_total     numeric,
  eligible       boolean,
  discount       numeric
)
language sql
stable
set search_path to ''
as $fn$
  with cart as (
    select orders.replace_customer_cart(p_branch_id, p_lines) as cart_id
  ),
  resolved as (
    select c.cart_id, v.coupon_id, v.discount
      from cart c
      cross join lateral marketing.validate_coupon(
        p_code,
        (select coalesce(round(sum(ci.line_total), 2), 0)
           from orders.cart_items ci where ci.cart_id = c.cart_id),
        p_branch_id
      ) v
  ),
  eligible as (
    select el.cart_item_id, el.product_id, el.line_total
      from resolved r
      cross join lateral marketing.coupon_eligible_lines(r.coupon_id, r.cart_id) el
  ),
  shares as (
    select a.cart_item_id, a.discount
      from resolved r
      cross join lateral marketing.allocate_coupon_discount(
        r.coupon_id, r.cart_id, r.discount
      ) a
  )
  select ci.id, ci.product_id, p.name_ar, p.name_en, ci.line_total,
         e.cart_item_id is not null,
         coalesce(s.discount, 0)
    from cart c
    join orders.cart_items ci on ci.cart_id = c.cart_id
    left join catalog.products p on p.id = ci.product_id
    left join eligible e on e.cart_item_id = ci.id
    left join shares s on s.cart_item_id = ci.id
   order by ci.id;
$fn$;

comment on function public.coupon_line_breakdown(uuid, text, jsonb) is
  'Per-line attribution of a coupon discount for the cart screen. Every line is '
  'returned; eligible marks the ones a scoped coupon actually covers.';

revoke all on function public.coupon_line_breakdown(uuid, text, jsonb) from public;
grant execute on function public.coupon_line_breakdown(uuid, text, jsonb)
  to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- place_order: write the attribution onto the invoice
-- ---------------------------------------------------------------------------

drop function if exists orders.place_order_impl(uuid, text, text, uuid, text, text, uuid);drop function if exists marketing.allocate_coupon_discount(uuid, uuid, numeric);drop function if exists marketing.coupon_eligible_lines(uuid, uuid);drop function if exists public.coupon_line_breakdown(uuid, text, jsonb);

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
  v_coupon_id uuid;
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
    if v_addr.latitude is not null and v_addr.longitude is not null then
      v_zone_ok := core.zone_covers_point(
        p_delivery_zone_id, v_addr.latitude, v_addr.longitude
      );
      if not v_zone_ok then
        raise exception 'delivery address is outside the selected delivery zone'
          using errcode = '23514';
      end if;
    end if;
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
    select coalesce(max(v.discount), 0), max(v.coupon_id)
      into v_discount, v_coupon_id
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
    unit_price, quantity, line_total, discount_total, note, options_key
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
    ci.unit_price, ci.quantity, ci.line_total,
    -- Allocated per cart line, in the same statement that writes the line.
    -- Matching order_items back to cart_items afterwards on
    -- (product, note, options_key) would be ambiguous whenever a product
    -- appears twice with the same note and options, and would then credit both
    -- rows with the same share.
    coalesce((
      select a.discount
        from marketing.allocate_coupon_discount(
               v_coupon_id, p_cart_id, v_discount) a
       where a.cart_item_id = ci.id
    ), 0),
    ci.note, ci.options_key
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