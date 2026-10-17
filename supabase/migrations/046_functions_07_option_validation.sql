-- 046_functions_07_option_validation.sql
--
-- Phase 2: server-side option selection validation.
--
-- Cart writes and place_order already reject unfamiliar option value ids, but
-- they did not enforce group membership rules such as duplicates, min/max,
-- single-select, required bindings or inactive values. This migration adds
-- one central verifier used by both the read-only price RPC and the cart RPC.
--
-- No schema redesign is required: existing tables and bindings are sufficient.
-- This migration only changes function definitions and grants.

create or replace function catalog.validate_product_option_selection(
  p_product_id uuid,
  p_option_value_ids uuid[]
)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_ids uuid[] := coalesce(p_option_value_ids, array[]::uuid[]);
  v_distinct uuid[] := coalesce(
    (select array_agg(distinct id) from unnest(v_ids) as t(id)),
    array[]::uuid[]
  );
  v_value uuid;
  v_group record;
  v_count integer;
  v_required boolean;
  v_min integer;
  v_max integer;
begin
  -- Reject explicit nulls in a PostgREST array.
  foreach v_value in array v_ids
  loop
    if v_value is null then
      raise exception 'option not available for product %', p_product_id
        using errcode = '23514';
    end if;
  end loop;

  -- Quantity of each selected value is exactly one in this version.
  if coalesce(array_length(v_ids, 1), 0) <> coalesce(array_length(v_distinct, 1), 0) then
    raise exception 'invalid option selection for product %', p_product_id
      using errcode = '23514';
  end if;

  -- Product-level existence is still the caller's boundary case; resolve_price
  -- and upsert_cart_item retain their additional availability behaviour.
  if not exists (
    select 1 from catalog.products p
     where p.id = p_product_id
  ) then
    raise exception 'product % not found', p_product_id using errcode = 'P0002';
  end if;

  -- Activated values may only come from active groups and active values bound
  -- to this product. This covers foreign, cross-product and inactive cases.
  if exists (
    select 1
      from unnest(v_distinct) as d(value_id)
     where not exists (
       select 1
         from catalog.product_option_groups pog
         join catalog.option_groups og on og.id = pog.group_id
         join catalog.option_values ov on ov.group_id = pog.group_id
        where pog.product_id = p_product_id
          and ov.id = d.value_id
          and ov.is_active
          and og.is_active
     )
  ) then
    raise exception 'option not available for product %', p_product_id
      using errcode = '23514';
  end if;

  -- Rules are applied independently per bound group.
  for v_group in
    select
      pog.group_id,
      coalesce(pog.is_required, false) as binding_required,
      og.code,
      og.selection_type,
      og.min_select,
      og.max_select,
      og.is_required as group_required
    from catalog.product_option_groups pog
    join catalog.option_groups og on og.id = pog.group_id
   where pog.product_id = p_product_id
     and og.is_active
  loop
    -- The binding can make a group required without changing the group default,
    -- but it cannot silently relax a required group.
    v_required := v_group.binding_required or v_group.group_required;
    v_min := v_group.min_select;
    if v_required then
      v_min := greatest(v_min, 1);
    end if;

    if v_group.selection_type = 'single' then
      v_max := coalesce(v_group.max_select, 1);
      if v_max > 1 then
        v_max := 1;
      end if;
    else
      v_max := v_group.max_select;
    end if;

    select count(*)::int into v_count
      from unnest(v_distinct) as d(value_id)
      join catalog.option_values ov on ov.id = d.value_id
     where ov.group_id = v_group.group_id;

    if v_count < v_min then
      raise exception 'invalid option selection for product %', p_product_id
        using errcode = '23514';
    end if;

    if v_max is not null and v_count > v_max then
      raise exception 'invalid option selection for product %', p_product_id
        using errcode = '23514';
    end if;
  end loop;
end;
$fn$;

comment on function catalog.validate_product_option_selection(uuid, uuid[]) is
  'Server-side contract for product option selections: membership, active status, uniqueness, min/max and required groups.';

revoke all on function
  catalog.validate_product_option_selection(uuid, uuid[])
  from public;

grant execute on function
  catalog.validate_product_option_selection(uuid, uuid[])
  to service_role;

-- Keep resolve_effective_price authoritative and make it reject the same invalid
-- selections before it computes a price.
create or replace function catalog.resolve_effective_price(
  p_branch_id  uuid,
  p_product_id uuid,
  p_option_value_ids uuid[] default '{}'
)
returns table (
  unit_price      numeric,
  currency_code   text,
  is_available    boolean,
  option_deltas   numeric,
  unavailable_reason text
)
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_base      numeric;
  v_override  numeric;
  v_available boolean;
  v_reason    text;
  v_active    boolean;
  v_archived  timestamptz;
  v_currency  text;
  v_deltas    numeric;
begin
  perform catalog.validate_product_option_selection(p_product_id, p_option_value_ids);

  select p.base_price, p.is_active, p.archived_at
    into v_base, v_active, v_archived
    from catalog.products p
   where p.id = p_product_id;

  if not found then
    raise exception 'product % not found', p_product_id using errcode = 'P0002';
  end if;

  select b.currency_code into v_currency from core.brands b limit 1;

  select bpp.price_override, bpp.is_available, bpp.unavailable_reason
    into v_override, v_available, v_reason
    from catalog.branch_product_pricing bpp
   where bpp.branch_id = p_branch_id and bpp.product_id = p_product_id;

  v_available := coalesce(v_available, true);
  if not v_active or v_archived is not null then
    v_available := false;
    v_reason := coalesce(v_reason, 'product inactive');
  end if;

  select coalesce(sum(ov.price_delta), 0)
    into v_deltas
    from catalog.option_values ov
   where ov.id = any(p_option_value_ids)
     and ov.is_active;

  return query
  select round(coalesce(v_override, v_base) + v_deltas, 2),
         v_currency,
         v_available,
         round(v_deltas, 2),
         v_reason;
end;
$fn$;

comment on function catalog.resolve_effective_price(uuid, uuid, uuid[]) is
  'Server-side price truth. The client cannot override the result or smuggle in an invalid option.';

-- Cart writes share the same verifier before any server cart state is written.
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

  -- Every entry path is validated before branch availability or bundle pricing.
  perform catalog.validate_product_option_selection(p_product_id, p_option_value_ids);

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

  insert into orders.cart_items (cart_id, product_id, quantity, note, unit_price, line_total)
  values (v_cart, p_product_id, least(p_quantity, 99), coalesce(p_note, ''), v_price, round(v_price * least(p_quantity, 99), 2))
  on conflict (cart_id, product_id, note) do update
    set quantity = least(orders.cart_items.quantity + excluded.quantity, 99),
        unit_price = excluded.unit_price,
        line_total = round(excluded.unit_price * least(orders.cart_items.quantity + excluded.quantity, 99), 2)
  returning id into v_item;

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
  'Add to cart. Price from resolve_effective_price(); option selections are server validated; bundle prices remain authoritative.';

-- Re-pricing during order placement still calls resolve_effective_price(),
-- so invalid selections remain impossible even after the cart was created.
-- No separate order item change is required; historical snapshots are preserved.

notify pgrst, 'reload config';
notify pgrst, 'reload schema';
