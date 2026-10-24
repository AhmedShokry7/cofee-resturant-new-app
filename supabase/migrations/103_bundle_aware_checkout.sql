-- 103_bundle_aware_checkout.sql
--
-- Preserve bundle identity and bundle pricing through checkout.
--
-- `orders.place_order_impl` used to re-price every cart line with
-- `catalog.resolve_effective_price`, which ignores bundles entirely.  A cart
-- that showed a 48.00 bundle was invoiced at the 55.00 shelf price of its
-- components.  The `order_items` rows also carried no bundle identity, and the
-- option rows were linked back to the order with
-- `(order_id, product_id, note, options_key)`, which duplicates option rows as
-- soon as a standalone line and a bundle component share that tuple.
--
-- This migration:
--   1. adds bundle identity and immutable bundle snapshots to `order_items`,
--      plus the source cart line (unique) for unambiguous linkage;
--   2. re-creates `orders.place_order_impl` so it reprices the cart through
--      `orders.reprice_cart(p_cart_id, true)` exactly once, snapshots the
--      bundle on every component line, and links option rows by cart line;
--   3. appends `options_key`, `discount_total` and the bundle snapshot to the
--      `public.order_items` bridge;
--   4. refuses an order whose coupon is not usable at the moment of the
--      order, instead of placing it at the full price behind a discount the
--      customer was shown (see the coupon block in the function body).
--
-- Everything else is preserved verbatim: idempotency lookup, the advisory
-- lock in `place_order_with_lines`, delivery zones and address snapshots,
-- fees, coupon validation/allocation, tax, loyalty points, inventory
-- deduction and movement rows, cart conversion, order history and events.
--
-- This file is not deployed yet, so the coupon guard is part of the same
-- version instead of a follow-up migration: there is no environment that
-- runs the old body.
--
-- Rollback and verification are at the bottom.

begin;

-- Matches the widened cart column so an order line keeps exactly the unit
-- price the cart charged. `ck_order_items_total` still rounds the product to
-- cents, which is why the extra precision is needed for qty > 1 components.
-- The bridge view depends on the column type, so it is dropped here and
-- re-created below with the bundle snapshot columns.
drop view if exists public.order_items;

alter table orders.order_items
  alter column unit_price type numeric(12,4);

alter table orders.order_items add column bundle_id uuid;
alter table orders.order_items add column bundle_name_ar text not null default '';
alter table orders.order_items add column bundle_name_en text not null default '';
alter table orders.order_items add column bundle_price_snapshot numeric;
alter table orders.order_items add column source_cart_item_id uuid;

comment on column orders.order_items.bundle_id is
  'Catalogue bundle this line came from. Deliberately no FK: an invoice must outlive the catalogue row.';
comment on column orders.order_items.bundle_price_snapshot is
  'The configured bundle price at the time of the order (per bundle instance).';
comment on column orders.order_items.source_cart_item_id is
  'The cart line this order line was written from. Unique so options and discounts link unambiguously.';

alter table orders.order_items
  add constraint order_items_bundle_price_check
  check (bundle_price_snapshot is null or bundle_price_snapshot >= 0);

create unique index uq_order_items_source_cart_item
  on orders.order_items (source_cart_item_id)
  where source_cart_item_id is not null;

-- Appended columns only; the existing column order is preserved.  The view is
-- re-created (not replaced) because it was dropped for the type change, so its
-- grants are restored explicitly.
create view public.order_items with (security_invoker = true) as
select id,
       order_id,
       product_id,
       option_group_name_ar,
       option_group_name_en,
       product_name_ar,
       product_name_en,
       sku_snapshot,
       image_snapshot,
       unit_price,
       quantity,
       line_total,
       note,
       created_at,
       options_key,
       discount_total,
       bundle_id,
       bundle_name_ar,
       bundle_name_en,
       bundle_price_snapshot
  from orders.order_items;

comment on view public.order_items is
  'Bridge to orders.order_items. Identity and bundle snapshot columns are appended; existing order is preserved.';

grant select, insert, update, delete on public.order_items
  to authenticated, service_role;
revoke all on public.order_items from anon;

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
set search_path = ''
as $fn$
declare
  v_uid        uuid := auth.uid();
  v_existing   orders.orders%rowtype;
  v_cart       orders.carts%rowtype;
  v_subtotal   numeric := 0;
  v_discount   numeric := 0;
  v_coupon_id  uuid;
  v_coupon_reason text;
  v_fee        numeric := 0;
  v_min        numeric;
  v_tax        numeric := 0;
  v_total      numeric := 0;
  v_tax_rate   numeric;
  v_tax_inc    boolean;
  v_currency   text;
  v_points     integer := 0;
  v_order_id   uuid;
  v_number     text;
  v_line       record;
  v_stock      integer;
  v_allow_neg  boolean;
  v_zone_ok    boolean;
  v_zone_name_ar text;
  v_zone_name_en text;
  v_addr       record;
  v_snapshot   jsonb;
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
      select v_existing.id,
             v_existing.order_number,
             v_existing.subtotal,
             v_existing.discount_total,
             v_existing.delivery_fee,
             v_existing.tax_total,
             v_existing.grand_total,
             v_existing.loyalty_points_earned,
             true;
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
    from core.brands
   limit 1;

  if p_fulfillment_type = 'delivery' then
    if p_delivery_zone_id is null then
      raise exception 'delivery zone required' using errcode = '23514';
    end if;

    select exists (
      select 1
        from core.delivery_zone_branches z
       where z.zone_id = p_delivery_zone_id
         and z.branch_id = v_cart.branch_id
    ) into v_zone_ok;

    if not v_zone_ok then
      raise exception 'this branch does not serve the selected delivery zone'
        using errcode = '23514';
    end if;

    select dz.min_order_amount, dz.name_ar, dz.name_en
      into v_min, v_zone_name_ar, v_zone_name_en
      from core.delivery_zones dz
     where dz.id = p_delivery_zone_id
       and dz.is_active;

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

  -- One authoritative repricing.  Standalone lines get the catalogue price
  -- and branch availability; every bundle group is validated and allocated
  -- exactly.  Any failure aborts the whole order.
  perform orders.reprice_cart(p_cart_id, true);

  select coalesce(round(sum(line_total), 2), 0)
    into v_subtotal
    from orders.cart_items
   where cart_id = p_cart_id;

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
      p_delivery_zone_id,
      v_cart.branch_id,
      v_addr.latitude,
      v_addr.longitude,
      v_subtotal
    );

    if v_min is not null and v_subtotal < v_min then
      raise exception 'order total is below the minimum for this delivery zone'
        using errcode = '23514';
    end if;
  end if;

  if nullif(btrim(coalesce(p_coupon_code, '')), '') is not null then
    select v.discount, v.coupon_id, v.reason_code
      into v_discount, v_coupon_id, v_coupon_reason
      from marketing.validate_coupon(
        p_coupon_code, v_subtotal, v_cart.branch_id) v;

    -- The coupon has to be usable right now.  `marketing.validate_coupon`
    -- answers with a reason instead of raising, so an expired, exhausted or
    -- out-of-scope coupon used to place the order at the full price while
    -- the checkout screen still showed the discount: the customer agreed to
    -- one amount and was charged another.  The order is refused instead, and
    -- the customer keeps the cart.
    if v_coupon_reason is distinct from 'applied'
       or v_discount is null
       or v_discount <= 0 then
      raise exception 'coupon % cannot be applied: %',
        p_coupon_code, coalesce(v_coupon_reason, 'not_applicable')
        using errcode = '23514';
    end if;

    v_discount := least(v_discount, v_subtotal);
  end if;

  if v_tax_inc then
    v_tax := 0;
  else
    v_tax := round((v_subtotal - v_discount) * v_tax_rate / 100, 2);
  end if;

  v_total := round(v_subtotal - v_discount + v_fee + v_tax, 2);

  select coalesce(max(points), 0) into v_points
    from (
      select floor(
               (v_subtotal - v_discount) * r.points_per_currency_unit
             )::integer as points
        from loyalty.loyalty_rules r
       where r.is_active
         and (r.valid_to is null or r.valid_to > now())
       order by r.valid_from desc
       limit 1
    ) s;

  v_points := greatest(coalesce(v_points, 0), 0);

  v_number := 'ORD-' || to_char(now(), 'YYYY') || '-' ||
              lpad(nextval('orders.order_number_seq')::text, 6, '0');

  insert into orders.orders (
    order_number,
    user_id,
    branch_id,
    fulfillment_type,
    delivery_zone_id,
    delivery_address_snapshot,
    status,
    payment_status,
    subtotal,
    discount_total,
    delivery_fee,
    tax_total,
    grand_total,
    currency_code,
    customer_note,
    loyalty_points_earned,
    idempotency_key
  ) values (
    v_number,
    v_uid,
    v_cart.branch_id,
    p_fulfillment_type,
    p_delivery_zone_id,
    coalesce(v_snapshot, '{}'::jsonb),
    'pending',
    'unpaid',
    v_subtotal,
    v_discount,
    v_fee,
    v_tax,
    v_total,
    v_currency,
    coalesce(p_note, ''),
    v_points,
    p_idempotency_key
  ) returning id into v_order_id;

  insert into orders.order_items (
    order_id,
    product_id,
    option_group_name_ar,
    option_group_name_en,
    product_name_ar,
    product_name_en,
    sku_snapshot,
    image_snapshot,
    unit_price,
    quantity,
    line_total,
    discount_total,
    note,
    options_key,
    bundle_id,
    bundle_name_ar,
    bundle_name_en,
    bundle_price_snapshot,
    source_cart_item_id
  )
  select
    v_order_id,
    ci.product_id,
    coalesce((
      select string_agg(g.name_ar, ' / ')
        from catalog.option_groups g
        join catalog.option_values ov on ov.group_id = g.id
        join orders.cart_item_options cio on cio.option_value_id = ov.id
       where cio.cart_item_id = ci.id
    ), ''),
    coalesce((
      select string_agg(g.name_en, ', ')
        from catalog.option_groups g
        join catalog.option_values ov on ov.group_id = g.id
        join orders.cart_item_options cio on cio.option_value_id = ov.id
       where cio.cart_item_id = ci.id
    ), ''),
    p.name_ar,
    p.name_en,
    p.sku,
    p.image_url,
    ci.unit_price,
    ci.quantity,
    ci.line_total,
    coalesce((
      select a.discount
        from marketing.allocate_coupon_discount(
               v_coupon_id, p_cart_id, v_discount) a
       where a.cart_item_id = ci.id
    ), 0),
    ci.note,
    ci.options_key,
    ci.bundle_id,
    coalesce(b.name_ar, ''),
    coalesce(b.name_en, ''),
    b.bundle_price,
    ci.id
  from orders.cart_items ci
  join catalog.products p on p.id = ci.product_id
  left join catalog.bundles b on b.id = ci.bundle_id
  where ci.cart_id = p_cart_id;

  insert into orders.order_item_options (
    order_item_id,
    option_value_id,
    option_name_ar,
    option_name_en,
    price_delta
  )
  select
    oi.id,
    cio.option_value_id,
    cio.option_name_ar,
    cio.option_name_en,
    cio.price_delta
  from orders.cart_items ci
  join orders.cart_item_options cio on cio.cart_item_id = ci.id
  join orders.order_items oi on oi.source_cart_item_id = ci.id
  where ci.cart_id = p_cart_id;

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

      insert into inventory.stock_movements (
        branch_id,
        product_id,
        variant_key,
        quantity_delta,
        reason,
        reference_type,
        reference_id,
        actor_user_id
      ) values (
        v_cart.branch_id,
        v_line.product_id,
        '00000000-0000-0000-0000-000000000000'::uuid,
        -v_line.quantity,
        'sale',
        'order',
        v_order_id,
        v_uid
      );
    end if;
  end loop;

  if v_discount > 0
     and nullif(btrim(coalesce(p_coupon_code, '')), '') is not null then
    insert into marketing.coupon_redemptions (
      coupon_id, user_id, order_id, amount
    )
    select c.id, v_uid, v_order_id, v_discount
      from marketing.coupons c
     where c.code = upper(btrim(p_coupon_code))
       and not exists (
         select 1
           from marketing.coupon_redemptions cr
          where cr.coupon_id = c.id
            and cr.order_id = v_order_id
       );
  end if;

  if v_points > 0 then
    perform loyalty.apply_points(
      v_uid, v_points, 'earn_order', 'order', v_order_id,
      'earned on order ' || v_number
    );
  end if;

  update orders.carts
     set status = 'converted', updated_at = now()
   where id = p_cart_id;

  insert into orders.order_status_history (
    order_id, from_status, to_status, changed_by, note
  ) values (
    v_order_id, null, 'pending', v_uid, 'order placed'
  );

  insert into orders.order_events (order_id, event_type, payload)
  values (
    v_order_id,
    'order.placed',
    jsonb_build_object('total', v_total, 'branch', v_cart.branch_id)
  );

  return query
    select v_order_id,
           v_number,
           v_subtotal,
           v_discount,
           v_fee,
           v_tax,
           v_total,
           v_points,
           false;
end;
$fn$;

notify pgrst, 'reload schema';

commit;

-- Verification
-- ------------
-- 1) Per-line discounts are preserved and never exceed the line:
--      select id from orders.order_items
--       where discount_total < 0 or discount_total > line_total;
--    Expected: 0 rows.
-- 2) Bundle lines always carry their snapshot:
--      select id from orders.order_items
--       where bundle_id is not null
--         and (bundle_price_snapshot is null
--              or bundle_name_ar = ''
--              or bundle_name_en = '');
--    Expected: 0 rows.
-- 3) Option rows never multiply:
--      select oi.id, count(*)
--        from orders.order_items oi
--        join orders.order_item_options oio on oio.order_item_id = oi.id
--        join orders.cart_items ci on ci.id = oi.source_cart_item_id
--       group by oi.id
--      having count(*) <> (
--        select count(*) from orders.cart_item_options
--         where cart_item_id = ci.id
--      );
--    Expected: 0 rows (for orders created after this migration).
-- 4) The bridge exposes the new columns:
--      select column_name from information_schema.columns
--       where table_schema = 'public' and table_name = 'order_items'
--       order by ordinal_position;
--
-- Rollback
-- --------
-- Data-destructive once revision-103 orders exist.  Revert 103 before 102.
--
-- begin;
-- create or replace view public.order_items with (security_invoker = true) as
--   select id, order_id, product_id, option_group_name_ar,
--          option_group_name_en, product_name_ar, product_name_en,
--          sku_snapshot, image_snapshot, unit_price, quantity, line_total,
--          note, created_at
--     from orders.order_items;
-- -- restore orders.place_order_impl from migration 094 before dropping the
-- -- columns it no longer uses.
-- drop index if exists orders.uq_order_items_source_cart_item;
-- alter table orders.order_items drop constraint order_items_bundle_price_check;
-- alter table orders.order_items
--   drop column source_cart_item_id,
--   drop column bundle_price_snapshot,
--   drop column bundle_name_en,
--   drop column bundle_name_ar,
--   drop column bundle_id;
-- commit;
-- ---------------------------------------------------------------------------
