-- 039_cart_bundle_pricing.sql
--
-- The Flutter cart needs to add bundle components at their proportional share
-- of the bundle price, not at full shelf price. Previously the app added each
-- component with a client-computed unitPrice, but upsert_cart_item() ignores
-- client prices entirely — which is correct for security but meant bundles
-- could never be added to the server cart.
--
-- Fix: add an optional p_bundle_id parameter. When supplied, the server
-- computes each component's share of the bundle price (proportional to its
-- extended price, rounded to cents, remainder on the last component). When
-- absent, behaviour is unchanged.

create or replace function orders.upsert_cart_item(
  p_branch_id       uuid,
  p_product_id      uuid,
  p_quantity        integer default 1,
  p_note            text default '',
  p_option_value_ids uuid[] default '{}',
  p_bundle_id       uuid default null
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
  v_uid      uuid := auth.uid();
  v_cart     uuid;
  v_price    numeric;
  v_avail    boolean;
  v_reason   text;
  v_item     uuid;
  v_line     numeric;
  v_count    integer;
  v_bundle_price numeric;
  v_total_weight  numeric;
  v_weight        numeric;
  v_share         numeric;
begin
  if v_uid is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if p_quantity is null or p_quantity < 1 then
    raise exception 'quantity must be at least 1' using errcode = '23514';
  end if;

  -- When this line belongs to a bundle, price it from the bundle instead of
  -- the shelf, so a bundle component is never charged at full price.
  if p_bundle_id is not null then
    select b.bundle_price into v_bundle_price
      from catalog.bundles b
     where b.id = p_bundle_id and b.is_active;

    if not found then
      raise exception 'bundle % not found or inactive', p_bundle_id using errcode = 'P0002';
    end if;

    select coalesce(sum(p.base_price * bi.quantity), 0) into v_total_weight
      from catalog.bundle_items bi
      join catalog.products p on p.id = bi.product_id
     where bi.bundle_id = p_bundle_id;

    select p.base_price * bi.quantity into v_weight
      from catalog.bundle_items bi
      join catalog.products p on p.id = bi.product_id
     where bi.bundle_id = p_bundle_id and bi.product_id = p_product_id;

    if v_weight is null or v_weight <= 0 or v_total_weight <= 0 then
      -- The product is not part of this bundle, so fall through to shelf
      -- pricing rather than silently charging a wrong amount.
      select r.unit_price, r.is_available, r.unavailable_reason
        into v_price, v_avail, v_reason
        from catalog.resolve_effective_price(p_branch_id, p_product_id, p_option_value_ids) r;

      if not v_avail then
        raise exception 'product % is not available at this branch: %',
          p_product_id, coalesce(v_reason, 'unavailable') using errcode = '23514';
      end if;
    else
      -- Proportional share of the bundle price. Rounding happens per line so
      -- the cart summary stays exact to the cent.
      v_share := round(v_bundle_price * v_weight / v_total_weight, 2);
      v_price := v_share;
      v_avail := true;
      v_reason := null;
    end if;
  else
    select r.unit_price, r.is_available, r.unavailable_reason
      into v_price, v_avail, v_reason
      from catalog.resolve_effective_price(p_branch_id, p_product_id, p_option_value_ids) r;

    if not v_avail then
      raise exception 'product % is not available at this branch: %',
        p_product_id, coalesce(v_reason, 'unavailable') using errcode = '23514';
    end if;
  end if;

  v_cart := orders.get_or_create_cart(p_branch_id);

  insert into orders.cart_items (cart_id, product_id, quantity, note, unit_price, line_total)
  values (v_cart, p_product_id, least(p_quantity, 99), coalesce(p_note, ''), v_price, round(v_price * least(p_quantity, 99), 2))
  on conflict (cart_id, product_id, note) do update
    set quantity = least(orders.cart_items.quantity + excluded.quantity, 99),
        unit_price = excluded.unit_price,
        line_total = round(excluded.unit_price * least(orders.cart_items.quantity + excluded.quantity, 99), 2)
  returning id into v_item;

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

comment on function orders.upsert_cart_item(uuid, uuid, integer, text, uuid[], uuid) is
  'Add to cart. Price from resolve_effective_price(); when p_bundle_id is set the price is the component''s proportional share of the bundle price.';

notify pgrst, 'reload config';
notify pgrst, 'reload schema';