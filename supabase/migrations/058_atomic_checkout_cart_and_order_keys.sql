-- 058_atomic_checkout_cart_and_order_keys.sql
--
-- Serializes checkout by customer, makes cart replacement one transaction, and
-- combines cart replacement with coupon validation / order creation. The
-- order implementation from 055 remains the single pricing and fulfillment
-- source of truth; this migration wraps it with an idempotency advisory lock.

-- There is one active cart per user (011), so the lock is deliberately scoped
-- to the user rather than branch. Every compound cart operation uses this same
-- lock before it locks the cart row.
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
  if p_branch_id is null then
    raise exception 'branch required' using errcode = '23514';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_uid::text || ':cart', 0));

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

-- Keep the legacy clear-cart RPC serialized with replacement and checkout.
create or replace function orders.remove_all_cart_items(p_cart_id uuid)
returns integer
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_uid uuid := auth.uid();
  v_count integer;
begin
  if v_uid is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(v_uid::text || ':cart', 0));
  delete from orders.cart_items ci
   using orders.carts c
   where ci.cart_id = p_cart_id
     and c.id = ci.cart_id
     and c.user_id = v_uid
     and c.status = 'active';
  get diagnostics v_count = row_count;
  return v_count;
end;
$fn$;

create or replace function orders.remove_cart_item(p_cart_item_id uuid)
returns integer
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_uid uuid := auth.uid();
  v_count integer;
begin
  if v_uid is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(v_uid::text || ':cart', 0));
  delete from orders.cart_items ci
   using orders.carts c
   where ci.id = p_cart_item_id
     and c.id = ci.cart_id
     and c.user_id = v_uid
     and c.status = 'active';
  select coalesce(sum(ci.quantity), 0)::integer into v_count
    from orders.cart_items ci
    join orders.carts c on c.id = ci.cart_id
   where c.user_id = v_uid and c.status = 'active';
  return v_count;
end;
$fn$;

-- Internal replace helper. Any invalid line, option, availability or pricing
-- error aborts the surrounding RPC transaction and restores the old cart.
create or replace function orders.replace_customer_cart(
  p_branch_id uuid,
  p_lines jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_uid uuid := auth.uid();
  v_cart_id uuid;
  v_line jsonb;
  v_product_id uuid;
  v_quantity integer;
  v_note text;
  v_options uuid[];
  v_bundle_id uuid;
begin
  if v_uid is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if p_branch_id is null then
    raise exception 'branch required' using errcode = '23514';
  end if;
  if p_lines is null or jsonb_typeof(p_lines) <> 'array' then
    raise exception 'cart lines must be a JSON array' using errcode = '22023';
  end if;
  if jsonb_array_length(p_lines) > 100 then
    raise exception 'cart has too many lines' using errcode = '22023';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_uid::text || ':cart', 0));
  v_cart_id := orders.get_or_create_cart(p_branch_id);
  perform 1
    from orders.carts c
   where c.id = v_cart_id and c.user_id = v_uid and c.status = 'active'
   for update;
  if not found then
    raise exception 'cart not found or not active' using errcode = 'P0002';
  end if;

  delete from orders.cart_items ci where ci.cart_id = v_cart_id;

  for v_line in select value from jsonb_array_elements(p_lines)
  loop
    if jsonb_typeof(v_line) <> 'object'
       or jsonb_typeof(coalesce(v_line->'option_value_ids', '[]'::jsonb)) <> 'array' then
      raise exception 'invalid cart line' using errcode = '22023';
    end if;
    v_product_id := nullif(v_line->>'product_id', '')::uuid;
    v_quantity := nullif(v_line->>'quantity', '')::integer;
    v_note := coalesce(v_line->>'note', '');
    v_bundle_id := nullif(v_line->>'bundle_id', '')::uuid;
    if v_product_id is null or v_quantity is null or v_quantity < 1 or v_quantity > 99 then
      raise exception 'invalid cart product or quantity' using errcode = '23514';
    end if;

    select coalesce(array_agg(option_id::uuid), '{}'::uuid[])
      into v_options
      from jsonb_array_elements_text(
        coalesce(v_line->'option_value_ids', '[]'::jsonb)
      ) as option_values(option_id);

    perform orders.upsert_cart_item(
      p_branch_id,
      v_product_id,
      v_quantity,
      v_note,
      v_options,
      v_bundle_id
    );
  end loop;
  return v_cart_id;
end;
$fn$;

revoke all on function orders.replace_customer_cart(uuid, jsonb) from public, anon;
grant execute on function orders.replace_customer_cart(uuid, jsonb) to authenticated, service_role;

-- Public PostgREST bridge for an atomic cart replacement, including an empty
-- list (used by clearCart).
create or replace function public.replace_cart(p_branch_id uuid, p_lines jsonb)
returns table (cart_id uuid, item_count integer, subtotal numeric)
language plpgsql
security invoker
set search_path = ''
as $fn$
declare
  v_cart_id uuid;
begin
  v_cart_id := orders.replace_customer_cart(p_branch_id, p_lines);
  return query
    select v_cart_id,
           coalesce(sum(ci.quantity), 0)::integer,
           coalesce(round(sum(ci.line_total), 2), 0)
      from orders.cart_items ci
     where ci.cart_id = v_cart_id;
end;
$fn$;

-- One transaction covers replacement and server-side coupon validation. The
-- caller's subtotal is intentionally not accepted; the server prices the cart.
create or replace function public.validate_coupon_for_cart(
  p_branch_id uuid,
  p_code text,
  p_lines jsonb
)
returns table (
  coupon_id uuid,
  code text,
  discount numeric,
  message text,
  cart_subtotal numeric
)
language plpgsql
security invoker
set search_path = ''
as $fn$
declare
  v_cart_id uuid;
  v_subtotal numeric;
begin
  v_cart_id := orders.replace_customer_cart(p_branch_id, p_lines);
  select coalesce(round(sum(ci.line_total), 2), 0)
    into v_subtotal
    from orders.cart_items ci
   where ci.cart_id = v_cart_id;
  return query
    select v.coupon_id, v.code, v.discount, v.message, v_subtotal
      from marketing.validate_coupon(p_code, v_subtotal, p_branch_id) v;
end;
$fn$;

-- Serialize same-key requests before the existing order implementation checks
-- for a prior result. This prevents concurrent identical requests from racing
-- into the UNIQUE constraint and failing instead of returning the saved order.
do $migration$
begin
  if to_regprocedure(
    'orders.place_order_impl(uuid,text,text,uuid,text,text,uuid)'
  ) is null then
    alter function orders.place_order(uuid, text, text, uuid, text, text, uuid)
      rename to place_order_impl;
  end if;
end;
$migration$;

create or replace function orders.place_order(
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
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if nullif(btrim(coalesce(p_idempotency_key, '')), '') is null then
    raise exception 'idempotency key required' using errcode = '22023';
  end if;
  perform pg_advisory_xact_lock(
    hashtextextended(v_uid::text || ':order:' || p_idempotency_key, 0)
  );
  return query
    select * from orders.place_order_impl(
      p_cart_id, p_idempotency_key, p_fulfillment_type,
      p_delivery_zone_id, p_coupon_code, p_note, p_address_id
    );
end;
$fn$;

revoke all on function orders.place_order_impl(uuid, text, text, uuid, text, text, uuid)
  from public, anon, authenticated, service_role;
revoke all on function orders.place_order(uuid, text, text, uuid, text, text, uuid)
  from public, anon;
grant execute on function orders.place_order(uuid, text, text, uuid, text, text, uuid)
  to authenticated, service_role;

-- New app entry point: idem lock -> cart lock -> cart row lock -> order work.
-- Retries with the same key return before replacing the cart. Any failure after
-- replacement rolls back both the replacement and the order side effects.
create or replace function orders.place_order_with_lines(
  p_branch_id uuid,
  p_lines jsonb,
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
  v_uid uuid := auth.uid();
  v_existing orders.orders%rowtype;
  v_cart_id uuid;
begin
  if v_uid is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if nullif(btrim(coalesce(p_idempotency_key, '')), '') is null then
    raise exception 'idempotency key required' using errcode = '22023';
  end if;
  perform pg_advisory_xact_lock(
    hashtextextended(v_uid::text || ':order:' || p_idempotency_key, 0)
  );
  select * into v_existing
    from orders.orders o
   where o.user_id = v_uid and o.idempotency_key = p_idempotency_key;
  if found then
    return query select v_existing.id, v_existing.order_number,
      v_existing.subtotal, v_existing.discount_total, v_existing.delivery_fee,
      v_existing.tax_total, v_existing.grand_total,
      v_existing.loyalty_points_earned, true;
    return;
  end if;

  v_cart_id := orders.replace_customer_cart(p_branch_id, p_lines);
  return query
    select * from orders.place_order_impl(
      v_cart_id, p_idempotency_key, p_fulfillment_type,
      p_delivery_zone_id, p_coupon_code, p_note, p_address_id
    );
end;
$fn$;

revoke all on function orders.place_order_with_lines(
  uuid, jsonb, text, text, uuid, text, text, uuid
) from public, anon;
grant execute on function orders.place_order_with_lines(
  uuid, jsonb, text, text, uuid, text, text, uuid
) to authenticated, service_role;

-- Keep the existing seven-argument PostgREST bridge bound to the serialized
-- wrapper after the implementation rename.
create or replace function public.place_order(
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
language sql
security invoker
set search_path = ''
as $fn$
  select * from orders.place_order(
    p_cart_id, p_idempotency_key, p_fulfillment_type,
    p_delivery_zone_id, p_coupon_code, p_note, p_address_id
  );
$fn$;

create or replace function public.place_order_with_lines(
  p_branch_id uuid,
  p_lines jsonb,
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
language sql
security invoker
set search_path = ''
as $fn$
  select * from orders.place_order_with_lines(
    p_branch_id, p_lines, p_idempotency_key, p_fulfillment_type,
    p_delivery_zone_id, p_coupon_code, p_note, p_address_id
  );
$fn$;

-- Keep public bridges explicit; no anonymous writes or coupon validation.
revoke all on function public.replace_cart(uuid, jsonb),
  public.validate_coupon_for_cart(uuid, text, jsonb),
  public.place_order_with_lines(uuid, jsonb, text, text, uuid, text, text, uuid)
  from public, anon;
grant execute on function public.replace_cart(uuid, jsonb),
  public.validate_coupon_for_cart(uuid, text, jsonb),
  public.place_order_with_lines(uuid, jsonb, text, text, uuid, text, text, uuid)
  to authenticated, service_role;
revoke all on function public.place_order(uuid, text, text, uuid, text, text, uuid)
  from public, anon;
grant execute on function public.place_order(uuid, text, text, uuid, text, text, uuid)
  to authenticated, service_role;

notify pgrst, 'reload schema';
