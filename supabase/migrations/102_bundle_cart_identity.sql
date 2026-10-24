-- 102_bundle_cart_identity.sql
--
-- Bundle-aware cart-line identity and one authoritative pricing function.
--
-- Today `orders.cart_items` has no bundle column, and its identity is
-- `(cart_id, product_id, note, options_key)`.  Adding a bundle component and a
-- standalone product of the same product/note/options therefore merged them
-- into one row, summed their quantities and kept one price.  The cart also
-- had no way to tell the server which bundle a line came from, and
-- `orders.place_order_impl` re-priced every line from the shelf price, so the
-- bundle price was lost at checkout.
--
-- This migration:
--   1. adds `bundle_id` (FK, nullable) and a generated `bundle_key`, and
--      extends the identity to `(cart_id, product_id, note, options_key,
--      bundle_key)` so a bundle component can never collide with a standalone
--      line or with a component of another bundle;
--   2. adds `orders.reprice_cart`, the single authoritative pricing routine;
--   3. makes `orders.upsert_cart_item` write and honour `bundle_id`;
--   4. makes `orders.replace_customer_cart` reprice the whole cart after it
--      writes it (so a bundle is priced as a group, never line by line);
--   5. exposes `options_key` and `bundle_id` on the `public.cart_items` bridge.
--
-- Pricing rules
-- -------------
-- * Standalone lines keep `catalog.resolve_effective_price` and its branch
--   availability check.
-- * A bundle group must contain every catalogue component exactly once, with
--   `quantity = bundle_items.quantity * instances`, the same `instances` for
--   every component, and an active bundle inside its date window with a
--   positive price.
-- * Components are allocated the bundle price with cumulative cent rounding
--   over `(sort_order, product_id)`:
--       cum_i   = round(price * instances * sum(w_1..i) / sum(w), 2)
--       share_i = cum_i - cum_{i-1}
--   which telescopes to exactly `round(price * instances, 2)`.  The unit
--   price is `share_i / quantity`, so `line_total = round(unit_price *
--   quantity, 2)` stays true even when a component has a per-bundle quantity
--   greater than one.
-- * Weights stay `products.base_price * bundle_items.quantity` (as before), so
--   the split is branch-independent; branch availability is still enforced per
--   component.
-- * `allow_options = false` rejects any option selection.  `allow_options =
--   true` accepts the selection and charges its deltas on top of the share.
--
-- Historical rows are NOT guessed: every existing `cart_items` row keeps
-- `bundle_id IS NULL` and remains an ordinary product line.
--
-- Rollback and verification are at the bottom.

begin;

-- A bundle component with `quantity > 1` has a per-unit share that is not
-- always representable in 2 decimals (e.g. 33.33 over two units is 16.665).
-- Four decimals keep `round(unit_price * quantity, 2)` equal to the exact
-- cent share while `line_total` stays 2 decimals.  The bridge view depends on
-- the column type, so it is dropped here and re-created below with the two new
-- columns.
drop view if exists public.cart_items;

alter table orders.cart_items
  alter column unit_price type numeric(12,4);

alter table orders.cart_items
  add column bundle_id uuid references catalog.bundles(id) on delete restrict;

alter table orders.cart_items
  add column bundle_key text
  generated always as (coalesce(bundle_id::text, '')) stored;

alter table orders.cart_items drop constraint cart_items_identity_key;

alter table orders.cart_items
  add constraint cart_items_identity_key
  unique (cart_id, product_id, note, options_key, bundle_key);

comment on column orders.cart_items.bundle_key is
  'Empty for a standalone line, the bundle id as text for a bundle component. Part of the line identity.';

-- ---------------------------------------------------------------------------
-- Repricing
-- ---------------------------------------------------------------------------
-- `p_strict = true` is used by `replace_customer_cart` (after the whole cart is
-- written) and by checkout.  `p_strict = false` is used by the legacy
-- single-line `upsert_cart_item`: an incomplete bundle group is left with its
-- provisional price instead of aborting an operation that only touched one
-- line.
create or replace function orders.reprice_cart(
  p_cart_id uuid,
  p_strict boolean default true
)
returns void
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_branch    uuid;
  v_group     uuid;
  v_bp        numeric;
  v_total     numeric;
  v_instances integer;
  v_catalog   integer;
  v_present   integer;
  v_cum       numeric;
  v_prev      numeric;
  v_share     numeric;
  v_deltas    numeric;
  v_line      record;
begin
  select c.branch_id into v_branch
    from orders.carts c
   where c.id = p_cart_id
     and c.user_id = auth.uid()
     and c.status = 'active';

  if not found then
    raise exception 'cart not found or not active' using errcode = 'P0002';
  end if;

  -- Standalone lines: catalogue price, availability enforced.
  for v_line in
    select ci.id, ci.product_id, ci.quantity
      from orders.cart_items ci
     where ci.cart_id = p_cart_id
       and ci.bundle_id is null
  loop
    declare
      v_ids    uuid[];
      v_price  numeric;
      v_avail  boolean;
      v_reason text;
    begin
      select coalesce(array_agg(cio.option_value_id), '{}'::uuid[])
        into v_ids
        from orders.cart_item_options cio
       where cio.cart_item_id = v_line.id;

      select r.unit_price, r.is_available, r.unavailable_reason
        into v_price, v_avail, v_reason
        from catalog.resolve_effective_price(
               v_branch, v_line.product_id, v_ids) r;

      if not coalesce(v_avail, false) then
        raise exception 'product % is not available at this branch: %',
          v_line.product_id, coalesce(v_reason, 'unavailable')
          using errcode = '23514';
      end if;

      update orders.cart_items
         set unit_price = v_price,
             line_total = round(v_price * v_line.quantity, 2)
       where id = v_line.id;
    end;
  end loop;

  -- Bundle groups: one bundle price per instance, allocated exactly.
  for v_group in
    select distinct ci.bundle_id
      from orders.cart_items ci
     where ci.cart_id = p_cart_id
       and ci.bundle_id is not null
  loop
    select b.bundle_price into v_bp
      from catalog.bundles b
     where b.id = v_group
       and b.is_active
       and (b.starts_at is null or now() >= b.starts_at)
       and (b.ends_at   is null or now() <  b.ends_at);

    if not found then
      raise exception 'bundle % is not available', v_group using errcode = '23514';
    end if;

    if v_bp is null or v_bp <= 0 then
      raise exception 'bundle % has no price', v_group using errcode = '23514';
    end if;

    select count(*) into v_catalog
      from catalog.bundle_items bi
     where bi.bundle_id = v_group;

    if v_catalog = 0 then
      raise exception 'bundle % has no components', v_group using errcode = '23514';
    end if;

    if exists (
      select 1
        from orders.cart_items ci
       where ci.cart_id = p_cart_id
         and ci.bundle_id = v_group
         and not exists (
           select 1 from catalog.bundle_items bi
            where bi.bundle_id = v_group and bi.product_id = ci.product_id
         )
    ) then
      raise exception 'cart line is not a component of bundle %', v_group
        using errcode = '23514';
    end if;

    select count(*)::integer, min(ci.quantity / bi.quantity)::integer
      into v_present, v_instances
      from orders.cart_items ci
      join catalog.bundle_items bi
        on bi.bundle_id = v_group and bi.product_id = ci.product_id
     where ci.cart_id = p_cart_id
       and ci.bundle_id = v_group;

    if v_present <> v_catalog
       or v_instances is null
       or v_instances < 1
       or exists (
         select 1
           from orders.cart_items ci
           join catalog.bundle_items bi
             on bi.bundle_id = v_group and bi.product_id = ci.product_id
          where ci.cart_id = p_cart_id
            and ci.bundle_id = v_group
            and ci.quantity <> bi.quantity * v_instances
       ) then
      if p_strict then
        raise exception 'bundle % is incomplete or has inconsistent quantities',
          v_group using errcode = '23514';
      else
        continue;
      end if;
    end if;

    if exists (
      select 1
        from orders.cart_items ci
        join catalog.bundle_items bi
          on bi.bundle_id = v_group and bi.product_id = ci.product_id
       where ci.cart_id = p_cart_id
         and ci.bundle_id = v_group
         and bi.allow_options = false
         and ci.options_key <> ''
    ) then
      raise exception 'bundle % component options are not allowed', v_group
        using errcode = '23514';
    end if;

    select sum(p.base_price * bi.quantity) into v_total
      from catalog.bundle_items bi
      join catalog.products p on p.id = bi.product_id
     where bi.bundle_id = v_group;

    if v_total is null or v_total <= 0 then
      raise exception 'bundle % has no priced components', v_group
        using errcode = '23514';
    end if;

    v_cum := 0;
    v_prev := 0;

    for v_line in
      select ci.id, ci.quantity, p.base_price * bi.quantity as weight
        from orders.cart_items ci
        join catalog.bundle_items bi
          on bi.bundle_id = v_group and bi.product_id = ci.product_id
        join catalog.products p on p.id = ci.product_id
       where ci.cart_id = p_cart_id
         and ci.bundle_id = v_group
       order by bi.sort_order, bi.product_id
    loop
      v_cum := v_cum + v_line.weight;
      v_share := round(v_bp * v_instances * v_cum / v_total, 2) - v_prev;
      v_prev := v_prev + v_share;

      select coalesce(sum(ov.price_delta), 0)
        into v_deltas
        from orders.cart_item_options cio
        join catalog.option_values ov on ov.id = cio.option_value_id
       where cio.cart_item_id = v_line.id;

      update orders.cart_items
         set unit_price = v_share / v_line.quantity + v_deltas,
             line_total = round(v_share + v_deltas * v_line.quantity, 2)
       where id = v_line.id;
    end loop;

    if v_prev <> round(v_bp * v_instances, 2) then
      raise exception 'bundle % allocation drift: % vs %',
        v_group, v_prev, round(v_bp * v_instances, 2)
        using errcode = '23514';
    end if;
  end loop;
end;
$fn$;

comment on function orders.reprice_cart(uuid, boolean) is
  'Reprices one active cart: catalogue prices for standalone lines, exact bundle allocation for bundle groups. Strict mode rejects incomplete groups.';

revoke all on function orders.reprice_cart(uuid, boolean)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- upsert_cart_item
-- ---------------------------------------------------------------------------
-- Same contract and signature.  The provisional price is per unit; the
-- authoritative price comes from `orders.reprice_cart` at the end.
create or replace function orders.upsert_cart_item(
  p_branch_id uuid,
  p_product_id uuid,
  p_quantity integer default 1,
  p_note text default '',
  p_option_value_ids uuid[] default '{}'::uuid[],
  p_bundle_id uuid default null
)
returns table (
  cart_item_id uuid,
  unit_price numeric,
  line_total numeric,
  item_count integer
)
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_uid          uuid := auth.uid();
  v_cart         uuid;
  v_price        numeric;
  v_avail        boolean;
  v_reason       text;
  v_item         uuid;
  v_line         numeric;
  v_count        integer;
  v_options_key  text;
  v_bundle_price numeric;
  v_total_weight numeric;
  v_weight       numeric;
  v_per_bundle   integer;
  v_allow_opts   boolean;
begin
  if v_uid is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if p_branch_id is null then
    raise exception 'branch required' using errcode = '23514';
  end if;
  if p_quantity is null or p_quantity < 1 then
    raise exception 'quantity must be at least 1' using errcode = '23514';
  end if;

  perform catalog.validate_product_option_selection(p_product_id, p_option_value_ids);

  v_options_key := coalesce(
    (
      select string_agg(d.value_id::text, ',' order by d.value_id::text)
        from unnest(coalesce(p_option_value_ids, '{}'::uuid[])) as d(value_id)
    ),
    ''
  );

  if p_bundle_id is not null then
    select b.bundle_price into v_bundle_price
      from catalog.bundles b
     where b.id = p_bundle_id
       and b.is_active
       and (b.starts_at is null or now() >= b.starts_at)
       and (b.ends_at   is null or now() <  b.ends_at);

    if not found then
      raise exception 'bundle % not found or not available', p_bundle_id
        using errcode = 'P0002';
    end if;

    if v_bundle_price is null or v_bundle_price <= 0 then
      raise exception 'bundle % has no price', p_bundle_id using errcode = '23514';
    end if;

    select bi.quantity, bi.allow_options
      into v_per_bundle, v_allow_opts
      from catalog.bundle_items bi
     where bi.bundle_id = p_bundle_id
       and bi.product_id = p_product_id;

    if not found then
      raise exception 'product % is not a component of bundle %',
        p_product_id, p_bundle_id using errcode = '23514';
    end if;

    if not v_allow_opts and v_options_key <> '' then
      raise exception 'bundle % component % does not allow options',
        p_bundle_id, p_product_id using errcode = '23514';
    end if;

    select coalesce(sum(p.base_price * bi.quantity), 0) into v_total_weight
      from catalog.bundle_items bi
      join catalog.products p on p.id = bi.product_id
     where bi.bundle_id = p_bundle_id;

    if v_total_weight <= 0 then
      raise exception 'bundle % has no priced components', p_bundle_id
        using errcode = '23514';
    end if;

    select p.base_price * bi.quantity into v_weight
      from catalog.bundle_items bi
      join catalog.products p on p.id = bi.product_id
     where bi.bundle_id = p_bundle_id
       and bi.product_id = p_product_id;

    v_price := round(v_bundle_price * v_weight / v_total_weight, 2)
               / v_per_bundle;
    v_price := round(v_price, 4);
    v_avail := true;

    if not exists (
      select 1
        from catalog.resolve_effective_price(
               p_branch_id, p_product_id, p_option_value_ids) r
       where r.is_available
    ) then
      raise exception 'product % is not available at this branch', p_product_id
        using errcode = '23514';
    end if;
  else
    select r.unit_price, r.is_available, r.unavailable_reason
      into v_price, v_avail, v_reason
      from catalog.resolve_effective_price(
             p_branch_id, p_product_id, p_option_value_ids) r;

    if not v_avail then
      raise exception 'product % is not available at this branch: %',
        p_product_id, coalesce(v_reason, 'unavailable') using errcode = '23514';
    end if;
  end if;

  v_cart := orders.get_or_create_cart(p_branch_id);

  insert into orders.cart_items
    (cart_id, product_id, quantity, note, options_key, unit_price, line_total, bundle_id)
  values
    (
      v_cart,
      p_product_id,
      least(p_quantity, 99),
      coalesce(p_note, ''),
      v_options_key,
      v_price,
      round(v_price * least(p_quantity, 99), 2),
      p_bundle_id
    )
  on conflict (cart_id, product_id, note, options_key, bundle_key) do update
    set quantity = least(orders.cart_items.quantity + excluded.quantity, 99),
        unit_price = excluded.unit_price,
        line_total = round(
          excluded.unit_price *
          least(orders.cart_items.quantity + excluded.quantity, 99),
          2
        )
  returning orders.cart_items.id into v_item;

  delete from orders.cart_item_options
   where orders.cart_item_options.cart_item_id = v_item;

  insert into orders.cart_item_options
    (cart_item_id, option_value_id, option_name_ar, option_name_en, price_delta)
  select v_item, ov.id, ov.name_ar, ov.name_en, ov.price_delta
    from catalog.option_values ov
   where ov.id = any(p_option_value_ids)
     and ov.is_active;

  perform orders.reprice_cart(v_cart, false);

  select ci.unit_price, ci.line_total into v_price, v_line
    from orders.cart_items ci
   where ci.id = v_item;

  select coalesce(sum(ci.quantity), 0)::integer into v_count
    from orders.cart_items ci
   where ci.cart_id = v_cart;

  return query select v_item, v_price, v_line, v_count;
end;
$fn$;

-- ---------------------------------------------------------------------------
-- replace_customer_cart
-- ---------------------------------------------------------------------------
-- Same contract and signature.  The only change is the strict reprice after
-- every line has been written, so a bundle is never priced while incomplete.
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
  v_uid        uuid := auth.uid();
  v_cart_id    uuid;
  v_line       jsonb;
  v_product_id uuid;
  v_quantity   integer;
  v_note       text;
  v_options    uuid[];
  v_bundle_id  uuid;
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

  perform pg_advisory_xact_lock(
    hashtextextended(v_uid::text || ':cart', 0));

  v_cart_id := orders.get_or_create_cart(p_branch_id);

  perform 1
    from orders.carts c
   where c.id = v_cart_id
     and c.user_id = v_uid
     and c.status = 'active'
   for update;

  if not found then
    raise exception 'cart not found or not active' using errcode = 'P0002';
  end if;

  delete from orders.cart_items ci where ci.cart_id = v_cart_id;

  for v_line in select value from jsonb_array_elements(p_lines)
  loop
    if jsonb_typeof(v_line) <> 'object'
       or jsonb_typeof(
            coalesce(v_line->'option_value_ids', '[]'::jsonb)
          ) <> 'array' then
      raise exception 'invalid cart line' using errcode = '22023';
    end if;

    v_product_id := nullif(v_line->>'product_id', '')::uuid;
    v_quantity   := nullif(v_line->>'quantity', '')::integer;
    v_note       := coalesce(v_line->>'note', '');
    v_bundle_id  := nullif(v_line->>'bundle_id', '')::uuid;

    if v_product_id is null
       or v_quantity is null
       or v_quantity < 1
       or v_quantity > 99 then
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

  perform orders.reprice_cart(v_cart_id);
  return v_cart_id;
end;
$fn$;

-- ---------------------------------------------------------------------------
-- Bridge view
-- ---------------------------------------------------------------------------
-- Appended columns only; the existing column order is preserved.  The view is
-- re-created (not replaced) because it was dropped for the type change, so its
-- grants are restored explicitly.
create view public.cart_items with (security_invoker = true) as
select id,
       cart_id,
       product_id,
       quantity,
       note,
       unit_price,
       line_total,
       created_at,
       options_key,
       bundle_id
  from orders.cart_items;

comment on view public.cart_items is
  'Bridge to orders.cart_items. options_key and bundle_id are appended columns; existing order is preserved.';

grant select, insert, update, delete on public.cart_items
  to authenticated, service_role;
revoke all on public.cart_items from anon;

notify pgrst, 'reload schema';

commit;

-- Verification
-- ------------
-- 1) Identity includes bundle_key:
--      select pg_get_constraintdef(oid) from pg_constraint
--       where conrelid = 'orders.cart_items'::regclass
--         and conname = 'cart_items_identity_key';
--    Expected: UNIQUE (cart_id, product_id, note, options_key, bundle_key)
-- 2) Two lines that differ only by bundle coexist:
--      select cart_id, product_id, note, options_key, bundle_key, count(*)
--        from orders.cart_items group by 1,2,3,4,5 having count(*) > 1;
--    Expected: 0 rows.
-- 3) Every live bundle group allocates exactly its price:
--      with g as (
--        select ci.cart_id, ci.bundle_id,
--               min(ci.quantity / bi.quantity) as instances,
--               sum(ci.line_total) as charged
--          from orders.cart_items ci
--          join catalog.bundle_items bi
--            on bi.bundle_id = ci.bundle_id
--           and bi.product_id = ci.product_id
--         where ci.bundle_id is not null
--         group by 1, 2)
--      select g.*, b.bundle_price,
--             round(b.bundle_price * g.instances, 2) as expected
--        from g join catalog.bundles b on b.id = g.bundle_id
--       where g.charged <> round(b.bundle_price * g.instances, 2);
--    Expected: 0 rows.
-- 4) The line-total invariant still holds:
--      select id from orders.cart_items
--       where line_total <> round(unit_price * quantity, 2);
--    Expected: 0 rows.
--
-- Rollback
-- --------
-- Reversing this migration is only safe before bundle rows exist.
--
-- begin;
-- drop view if exists public.cart_items;
-- create view public.cart_items with (security_invoker = true) as
--   select id, cart_id, product_id, quantity, note, unit_price, line_total,
--          created_at
--     from orders.cart_items;
-- grant select on public.cart_items to authenticated, service_role;
-- revoke all on public.cart_items from anon;
-- delete from orders.cart_items where bundle_id is not null;
-- alter table orders.cart_items drop constraint cart_items_identity_key;
-- alter table orders.cart_items drop column bundle_key;
-- alter table orders.cart_items drop column bundle_id;
-- alter table orders.cart_items
--   add constraint cart_items_identity_key
--   unique (cart_id, product_id, note, options_key);
-- drop function if exists orders.reprice_cart(uuid, boolean);
-- -- restore orders.upsert_cart_item and orders.replace_customer_cart from
-- -- migration 058 / 048 before dropping reprice_cart if they still call it.
-- commit;
-- ---------------------------------------------------------------------------
