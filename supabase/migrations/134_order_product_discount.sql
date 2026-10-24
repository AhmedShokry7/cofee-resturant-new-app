-- 134_order_product_discount.sql
--
-- The product discount was invisible on the order.
--
-- catalog.resolve_effective_price reduces the unit price, so a discounted line
-- simply looked cheaper and the order carried no discount of its own.
-- orders.orders.discount_total is the coupon and nothing else, which means an
-- invoice could not say what the customer actually saved.
--
-- The product discount is now an amount of its own:
--   * orders.order_items.product_discount_total - the discount on that line
--   * orders.orders.product_discount_total      - the sum over the lines
--
-- The arithmetic of the order does not change. The subtotal is still the sum
-- of the discounted lines, discount_total is still the coupon, and
-- grand_total = subtotal - discount_total + delivery_fee + tax_total still
-- holds: the constraint ck_orders_total is untouched. The invoice simply gains
-- a row - the price before the discount, the discount, then the coupon - and
-- the two still add up to the same total.
--
-- The values are derived by the database, never by the app:
--   * a BEFORE INSERT trigger on orders.order_items reads the regular price
--     from catalog.resolve_effective_price and writes the discount of the line
--   * an AFTER INSERT trigger sums the lines into the order
--
-- A bundle is priced as a whole, so it carries no product discount. That is
-- the rule the client already follows.

-- ---------------------------------------------------------------------------
-- The columns.
-- ---------------------------------------------------------------------------
alter table orders.order_items
  add column if not exists product_discount_total numeric(12,2)
    not null default 0;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'ck_order_items_product_discount_nonneg'
      and conrelid = 'orders.order_items'::regclass
  ) then
    alter table orders.order_items
      add constraint ck_order_items_product_discount_nonneg
        check (product_discount_total >= 0);
  end if;
end $$;

comment on column orders.order_items.product_discount_total is
  'The product discount on this line: the price before the discount minus the price charged, times the quantity. Zero when the line is a bundle or not discounted.';

alter table orders.orders
  add column if not exists product_discount_total numeric(12,2)
    not null default 0;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'ck_orders_product_discount_nonneg'
      and conrelid = 'orders.orders'::regclass
  ) then
    alter table orders.orders
      add constraint ck_orders_product_discount_nonneg
        check (product_discount_total >= 0);
  end if;
end $$;

comment on column orders.orders.product_discount_total is
  'The product discount of the order, the sum of the product discounts of its lines. The coupon is discount_total.';

-- ---------------------------------------------------------------------------
-- The discount of one cart line.
-- ---------------------------------------------------------------------------
create or replace function orders.cart_line_product_discount(
  p_cart_item_id uuid,
  p_unit_price numeric,
  p_quantity integer
)
returns numeric
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_branch  uuid;
  v_product uuid;
  v_bundle  uuid;
  v_ids     uuid[];
  v_regular numeric;
begin
  select c.branch_id, ci.product_id, ci.bundle_id
    into v_branch, v_product, v_bundle
    from orders.cart_items ci
    join orders.carts c on c.id = ci.cart_id
   where ci.id = p_cart_item_id;

  if v_branch is null or v_product is null or v_bundle is not null then
    -- A bundle is priced as a whole: there is no product discount on it.
    return 0;
  end if;

  select coalesce(array_agg(cio.option_value_id), '{}'::uuid[])
    into v_ids
    from orders.cart_item_options cio
   where cio.cart_item_id = p_cart_item_id;

  select r.regular_price
    into v_regular
    from catalog.resolve_effective_price(v_branch, v_product, v_ids) r;

  if v_regular is null or v_regular <= p_unit_price then
    return 0;
  end if;

  return round((v_regular - p_unit_price) * coalesce(p_quantity, 1), 2);
end;
$fn$;

comment on function orders.cart_line_product_discount(uuid, numeric, integer) is
  'The product discount of one cart line, from the authoritative regular price.';

-- ---------------------------------------------------------------------------
-- The product discount of a whole cart.
-- ---------------------------------------------------------------------------
create or replace function orders.cart_product_discount(p_cart_id uuid)
returns numeric
language sql
stable
security definer
set search_path = ''
as $fn$
  select coalesce(
           round(sum(
             orders.cart_line_product_discount(ci.id, ci.unit_price, ci.quantity)
           ), 2),
           0)
    from orders.cart_items ci
   where ci.cart_id = p_cart_id;
$fn$;

comment on function orders.cart_product_discount(uuid) is
  'The product discount of a cart, the sum of the discount of its lines.';

revoke all on function orders.cart_line_product_discount(uuid, numeric, integer)
  from public, anon, authenticated;
revoke all on function orders.cart_product_discount(uuid)
  from public, anon, authenticated;
grant execute on function orders.cart_line_product_discount(uuid, numeric, integer)
  to service_role;
grant execute on function orders.cart_product_discount(uuid)
  to service_role;

-- ---------------------------------------------------------------------------
-- The order line and the order pick the discount up from there.
-- ---------------------------------------------------------------------------
create or replace function orders.fill_order_item_product_discount()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  new.product_discount_total := case
    when new.source_cart_item_id is null then 0
    else orders.cart_line_product_discount(
           new.source_cart_item_id, new.unit_price, new.quantity)
  end;
  return new;
end;
$fn$;

drop trigger if exists tr_order_items_product_discount on orders.order_items;

create trigger tr_order_items_product_discount
  before insert on orders.order_items
  for each row execute function orders.fill_order_item_product_discount();

create or replace function orders.refresh_order_product_discount()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_order uuid;
begin
  select distinct oi.order_id into v_order from inserted oi;
  if v_order is null then
    return null;
  end if;

  update orders.orders o
     set product_discount_total = coalesce((
           select round(sum(oi.product_discount_total), 2)
             from orders.order_items oi
            where oi.order_id = o.id
         ), 0)
   where o.id = v_order;

  return null;
end;
$fn$;

drop trigger if exists tr_order_items_refresh_product_discount on orders.order_items;

create trigger tr_order_items_refresh_product_discount
  after insert on orders.order_items
  referencing new table as inserted
  for each statement execute function orders.refresh_order_product_discount();

-- ---------------------------------------------------------------------------
-- The quote states the product discount, so the checkout screen can show it
-- before the order is placed.
--
-- The return type changes, so the function has to be dropped first, and a
-- dropped function carries no grants of its own (see
-- REMAINING_ISSUES_REGISTER.md 2.10).
-- ---------------------------------------------------------------------------
drop function if exists public.quote_checkout(uuid, jsonb, text, uuid, text, uuid);

create or replace function public.quote_checkout(
  p_branch_id uuid,
  p_lines jsonb,
  p_fulfillment_type text,
  p_delivery_zone_id uuid default null,
  p_coupon_code text default null,
  p_address_id uuid default null
)
returns table (
  subtotal numeric,
  discount_total numeric,
  delivery_fee numeric,
  tax_total numeric,
  grand_total numeric,
  currency_code text,
  product_discount_total numeric
)
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_uid uuid := auth.uid();
  v_cart uuid;
  v_subtotal numeric := 0;
  v_discount numeric := 0;
  v_fee numeric := 0;
  v_tax numeric := 0;
  v_total numeric := 0;
  v_rate numeric := 0;
  v_tax_included boolean := false;
  v_currency text;
  v_coupon_reason text;
  v_product_discount numeric := 0;
  v_zone core.delivery_zones%rowtype;
  v_address identity.customer_addresses%rowtype;
begin
  if v_uid is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if p_fulfillment_type not in ('pickup', 'delivery') then
    raise exception 'invalid fulfillment type' using errcode = '22023';
  end if;

  v_cart := orders.replace_customer_cart(p_branch_id, p_lines);
  perform orders.reprice_cart(v_cart, true);
  select coalesce(round(sum(ci.line_total), 2), 0)
    into v_subtotal from orders.cart_items ci where ci.cart_id = v_cart;

  -- The price before the discount, so the checkout screen can show what the
  -- product discount saved next to the coupon.
  v_product_discount := orders.cart_product_discount(v_cart);

  if p_fulfillment_type = 'delivery' then
    if p_delivery_zone_id is null or p_address_id is null then
      raise exception 'delivery zone and address required' using errcode = '23514';
    end if;
    select dz.* into v_zone
      from core.delivery_zones dz
      join core.delivery_zone_branches dzb on dzb.zone_id = dz.id
     where dz.id = p_delivery_zone_id and dzb.branch_id = p_branch_id
       and dz.is_active;
    if not found then
      raise exception 'delivery zone unavailable' using errcode = '23514';
    end if;
    select a.* into v_address from identity.customer_addresses a
     where a.id = p_address_id and a.user_id = v_uid and a.archived_at is null;
    if not found then
      raise exception 'delivery address not found' using errcode = '23514';
    end if;
    if not core.zone_covers_point(
      p_delivery_zone_id, v_address.latitude, v_address.longitude
    ) then
      raise exception 'delivery address outside selected zone' using errcode = '23514';
    end if;
    if v_subtotal < v_zone.min_order_amount then
      raise exception 'order total below delivery minimum' using errcode = '23514';
    end if;
    v_fee := core.delivery_zone_fee(
      p_delivery_zone_id, p_branch_id, v_address.latitude,
      v_address.longitude, v_subtotal
    );
  end if;

  if nullif(btrim(coalesce(p_coupon_code, '')), '') is not null then
    select v.discount, v.reason_code into v_discount, v_coupon_reason
      from marketing.validate_coupon(
        p_coupon_code, v_subtotal, p_branch_id
      ) v;
    if v_coupon_reason is distinct from 'applied'
       or coalesce(v.discount, 0) <= 0 then
      raise exception 'coupon cannot be applied: %',
        coalesce(v_coupon_reason, 'not_applicable') using errcode = '23514';
    end if;
    v_discount := least(v.discount, v_subtotal);
  end if;

  select b.currency_code, b.tax_rate, b.tax_included
    into v_currency, v_rate, v_tax_included from core.brands b limit 1;
  if not coalesce(v_tax_included, false) then
    v_tax := round((v_subtotal - v_discount) * coalesce(v_rate, 0) / 100, 2);
  end if;
  v_total := round(v_subtotal - v_discount + v_fee + v_tax, 2);
  return query
    select v_subtotal, v_discount, v_fee, v_tax, v_total, v_currency,
           v_product_discount;
end;
$fn$;

revoke all on function public.quote_checkout(uuid, jsonb, text, uuid, text, uuid)
  from public, anon;
grant execute on function public.quote_checkout(uuid, jsonb, text, uuid, text, uuid)
  to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- The bridge views. A view freezes its column list when it is created, so
-- public.orders has to be republished with the new column (the trap
-- documented in 131) and public.order_items with its own.
-- ---------------------------------------------------------------------------
create or replace view public.orders with (security_invoker = true) as
  select id,
         order_number,
         user_id,
         branch_id,
         fulfillment_type,
         delivery_zone_id,
         delivery_address_snapshot,
         status,
         payment_method_id,
         payment_status,
         subtotal,
         discount_total,
         delivery_fee,
         tax_total,
         grand_total,
         currency_code,
         customer_note,
         loyalty_points_earned,
         loyalty_points_redeemed,
         idempotency_key,
         placed_at,
         completed_at,
         cancelled_at,
         cancel_reason,
         created_at,
         updated_at,
         product_discount_total
    from orders.orders;

grant select on public.orders to authenticated;
revoke all on public.orders from anon;

create or replace view public.order_items with (security_invoker = true) as
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
         bundle_price_snapshot,
         product_discount_total
    from orders.order_items;

grant select, insert, update, delete on public.order_items
  to authenticated, service_role;
revoke all on public.order_items from anon;

notify pgrst, 'reload schema';
