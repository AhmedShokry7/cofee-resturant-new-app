-- 048_cart_item_identity.sql
--
-- Fixes the cart-line identity so the server matches the app's merge rule.
--
-- The app merges a cart line by (product, note, sorted option value ids)
-- (see CartCubit.add). The server used a UNIQUE key of (cart_id, product_id,
-- note) only, so two visually different configurations of the same product
-- (e.g. a large latte and a small latte with the same note) collapsed into one
-- row and the second add silently overwrote the first line's options.
--
-- Instead of hashing the options, the canonical identity is stored explicitly
-- in a new `options_key` column: the option value ids sorted and comma-joined.
-- That is the real identity, so it cannot collide the way a hash could. The
-- unique key becomes (cart_id, product_id, note, options_key), which means:
--   * same product + same note + same options  -> merge (quantity adds up)
--   * same product + same note + different options -> two distinct lines
--   * same product + different note             -> two distinct lines
--
-- No data is deleted. Existing rows keep their line and are backfilled with
-- the key that describes the options they already carry. Because the previous
-- key (cart_id, product_id, note) was unique, the wider key is unique too, so
-- the constraint can be swapped safely.

alter table orders.cart_items
  add column if not exists options_key text not null default '';

update orders.cart_items ci
   set options_key = coalesce(
         (select string_agg(o.option_value_id::text, ',' order by o.option_value_id::text)
            from orders.cart_item_options o
           where o.cart_item_id = ci.id),
         '')
 where ci.options_key = '';

alter table orders.cart_items
  drop constraint if exists cart_items_cart_id_product_id_note_key;

alter table orders.cart_items
  drop constraint if exists cart_items_identity_key;

alter table orders.cart_items
  add constraint cart_items_identity_key
  unique (cart_id, product_id, note, options_key);

comment on column orders.cart_items.options_key is
  'Canonical option identity: option_value_ids sorted and comma-joined. Empty string means no options. Part of the cart-line uniqueness key.';

-- The 6-argument cart RPC now writes the canonical key and conflicts on it.
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
  v_options_key text;
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

  -- Every entry path is validated before branch availability or bundle pricing.
  perform catalog.validate_product_option_selection(p_product_id, p_option_value_ids);

  v_options_key := coalesce(
    (select string_agg(d.value_id::text, ',' order by d.value_id::text)
       from unnest(coalesce(p_option_value_ids, '{}'::uuid[])) as d(value_id)),
    '');

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
      select r.unit_price, r.is_available, r.unavailable_reason
        into v_price, v_avail, v_reason
        from catalog.resolve_effective_price(p_branch_id, p_product_id, p_option_value_ids) r;

      if not v_avail then
        raise exception 'product % is not available at this branch: %',
          p_product_id, coalesce(v_reason, 'unavailable') using errcode = '23514';
      end if;
    else
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

  insert into orders.cart_items
    (cart_id, product_id, quantity, note, options_key, unit_price, line_total)
  values
    (v_cart, p_product_id, least(p_quantity, 99), coalesce(p_note, ''), v_options_key,
     v_price, round(v_price * least(p_quantity, 99), 2))
  on conflict (cart_id, product_id, note, options_key) do update
    set quantity = least(orders.cart_items.quantity + excluded.quantity, 99),
        unit_price = excluded.unit_price,
        line_total = round(excluded.unit_price *
                           least(orders.cart_items.quantity + excluded.quantity, 99), 2)
  returning orders.cart_items.id into v_item;

  -- Qualify: the OUT parameter is also called cart_item_id.
  delete from orders.cart_item_options
   where orders.cart_item_options.cart_item_id = v_item;

  insert into orders.cart_item_options
    (cart_item_id, option_value_id, option_name_ar, option_name_en, price_delta)
  select v_item, ov.id, ov.name_ar, ov.name_en, ov.price_delta
    from catalog.option_values ov
   where ov.id = any(p_option_value_ids)
     and ov.is_active;

  -- Qualify: unit_price and line_total are also OUT parameter names.
  select ci.unit_price, ci.line_total into v_price, v_line
    from orders.cart_items ci where ci.id = v_item;

  select coalesce(sum(ci.quantity), 0)::integer into v_count
    from orders.cart_items ci where ci.cart_id = v_cart;

  return query select v_item, v_price, v_line, v_count;
end;
$fn$;

comment on function orders.upsert_cart_item(uuid, uuid, integer, text, uuid[], uuid) is
  'Add to cart. Price from resolve_effective_price(); option selections are server validated; bundle prices remain authoritative. Lines are identified by (cart, product, note, options).';

notify pgrst, 'reload config';
notify pgrst, 'reload schema';
