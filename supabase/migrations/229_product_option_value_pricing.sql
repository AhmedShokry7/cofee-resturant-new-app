-- 229_product_option_value_pricing.sql
--
-- WHAT THIS ADDS
-- A per-(product, option value) price override. Until now an option value
-- carried ONE `price_delta` for every product that offered it, so "الكبير +٤"
-- was true for كابتشينو and for إسبريسو alike. The dashboard needs both shapes:
-- a group-wide default delta that applies to every drink, and a specific size's
-- price pinned for one drink when that drink's base makes the default wrong.
--
--   catalog.product_option_value_pricing(price_delta)  overrides
--   catalog.option_values(price_delta)                 the default
--
-- WHY AN OVERRIDE OF THE DELTA, NOT AN ABSOLUTE PRICE
-- The price of a line is resolved in one place (175): the product's base after
-- branch override and discounts, PLUS the sum of its selected values' deltas.
-- Storing an absolute price for one size would fork that rule, because sizes
-- and extras are read by the same code: an extra is a summand, so "absolute"
-- means nothing when three of them are selected together, and a pinned size
-- would silently escape the branch override and the discount window that the
-- product's base already obeys. Overriding the delta keeps one arithmetic for
-- every group type, so the branch price and the discount stay applied and the
-- dashboard can still print the resulting final price next to the field.
--
-- WHY ONE FUNCTION OWNS THE RULE
-- Same reason as 224's `effective_product_option_groups`: the same number is
-- needed by the price core, the bundle branch of the cart reprice, the POS menu
-- and the two snapshot writes. If each re-derived it, an override could be
-- honoured at checkout and missed on a receipt. So
-- catalog.option_value_delta(product, value) is the only place that answers,
-- and every reader calls it.

-- ---------------------------------------------------------------------------
-- 1. The override table, its RLS and its bridge view.
-- ---------------------------------------------------------------------------
create table if not exists catalog.product_option_value_pricing (
  product_id  uuid    not null references catalog.products(id) on delete cascade,
  value_id    uuid    not null references catalog.option_values(id) on delete cascade,
  price_delta numeric not null default 0,
  updated_at  timestamptz not null default now(),
  primary key (product_id, value_id)
);

comment on table catalog.product_option_value_pricing is
  'Per-product override of an option value price_delta; absent row means the group default.';
comment on column catalog.product_option_value_pricing.price_delta is
  'What this value adds to THIS product, replacing option_values.price_delta. Negative is allowed: a short size priced under the product base.';

-- A value is deleted with its overrides, and a product with them. The value
-- itself can only be deleted when no sold line references it (011 restricts on
-- orders.cart_item_options), so a cascade here never rewrites history.
create index if not exists ix_product_option_value_pricing_value
  on catalog.product_option_value_pricing (value_id);

alter table catalog.product_option_value_pricing enable row level security;

drop policy if exists product_option_value_pricing_public_read on catalog.product_option_value_pricing;
create policy product_option_value_pricing_public_read on catalog.product_option_value_pricing
  for select to anon, authenticated
  using (true);

drop policy if exists product_option_value_pricing_admin_write on catalog.product_option_value_pricing;
create policy product_option_value_pricing_admin_write on catalog.product_option_value_pricing
  for all to authenticated
  using (identity.has_permission('catalog.product.write'))
  with check (identity.has_permission('catalog.product.write'));

create or replace view public.product_option_value_pricing
  with (security_invoker = true) as
  select * from catalog.product_option_value_pricing;

-- 225 measured that Supabase's default privileges in `public` hand ALL to every
-- role, so a new bridge view is narrowed here rather than left granted by
-- accident: everyone reads the price, only staff with catalogue write changes it.
-- The view is a separate object and needs its own grants (131), but so does the
-- base table it reads through: a security-invoker view runs as the caller, so
-- anon must hold SELECT on catalog.* too or the read raises 42501 (measured on
-- the first run of this file). Least privilege keeps the 023 + 030 split:
-- everyone reads, only staff with the catalogue write permission changes it,
-- and RLS still decides row by row.
grant select on catalog.product_option_value_pricing to anon, authenticated;
grant insert, update, delete on catalog.product_option_value_pricing to authenticated;

revoke all on public.product_option_value_pricing from anon, authenticated;
grant select on public.product_option_value_pricing to anon, authenticated;
grant insert, update, delete on public.product_option_value_pricing to authenticated;

-- ---------------------------------------------------------------------------
-- 2. The single owner of "what does this value add to this product".
-- ---------------------------------------------------------------------------
create or replace function catalog.option_value_delta(
  p_product_id uuid,
  p_value_id   uuid
)
returns numeric
language sql
stable
security definer
set search_path = ''
as $fn$
  select coalesce(
    (select pvp.price_delta
       from catalog.product_option_value_pricing pvp
      where pvp.product_id = p_product_id
        and pvp.value_id = p_value_id),
    (select ov.price_delta
       from catalog.option_values ov
      where ov.id = p_value_id),
    0
  );
$fn$;

comment on function catalog.option_value_delta(uuid, uuid) is
  'The only definition of what an option value adds to one product: its override, else the group default.';

revoke all on function catalog.option_value_delta(uuid, uuid)
  from public, anon, authenticated;
grant execute on function catalog.option_value_delta(uuid, uuid) to service_role;

-- ---------------------------------------------------------------------------
-- 3. The price core reads the resolved delta. Everything else about it is
--    unchanged (175): branch override, discount windows, availability.
-- ---------------------------------------------------------------------------
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
  unavailable_reason text,
  regular_price   numeric,
  discount_percentage numeric
)
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_base   record;
  v_deltas numeric;
begin
  perform catalog.validate_product_option_selection(p_product_id, p_option_value_ids);

  select r.unit_price, r.currency_code, r.is_available, r.unavailable_reason,
         r.regular_price, r.discount_percentage
    into v_base
    from catalog.resolve_product_base_price(p_branch_id, p_product_id) r;

  select coalesce(sum(catalog.option_value_delta(p_product_id, ov.id)), 0)
    into v_deltas
    from catalog.option_values ov
   where ov.id = any(p_option_value_ids)
     and ov.is_active;

  return query
  select round(v_base.unit_price + v_deltas, 2),
         v_base.currency_code,
         v_base.is_available,
         round(v_deltas, 2),
         v_base.unavailable_reason,
         round(v_base.regular_price + v_deltas, 2),
         v_base.discount_percentage;
end;
$fn$;

comment on function catalog.resolve_effective_price(uuid, uuid, uuid[]) is
  'Server-side price truth including per-product option prices, general and branch-specific discounts.';

-- ---------------------------------------------------------------------------
-- 4. The bundle branch of the cart reprice. Bundle lines allocate the bundle
--    price across components and then add their own option deltas; those deltas
--    must be the per-product ones or a bundle of a pinned-size drink would
--    reprice itself differently from the same drink bought alone.
--    Full body replays 102 with the delta lookup and ci.product_id added to the
--    line cursor it needed.
-- ---------------------------------------------------------------------------
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
      select ci.id, ci.quantity, ci.product_id, p.base_price * bi.quantity as weight
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

      select coalesce(sum(catalog.option_value_delta(v_line.product_id, ov.id)), 0)
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
  'Reprices one active cart: catalogue prices for standalone lines, exact bundle allocation for bundle groups, both with per-product option prices.';

revoke all on function orders.reprice_cart(uuid, boolean)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 5. The POS menu embeds the resolved delta, so the cashier taps the same price
--    the customer sees and the same price admin_pos_place_order will charge.
--    Full body replays 224 with one expression changed.
-- ---------------------------------------------------------------------------
create or replace function public.admin_pos_catalog(
  p_branch_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_branch       uuid;
  v_currency     text;
  v_tax_rate     numeric := 0;
  v_tax_included boolean := true;
  v_branches     jsonb;
  v_categories   jsonb;
  v_products     jsonb;
  v_methods      jsonb;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('pos.manage') then
    raise exception 'missing permission: pos.manage' using errcode = '42501';
  end if;

  -- Resolve the branch: the requested one, otherwise the cashier's branch,
  -- otherwise the first active branch for an owner or a global manager.
  if p_branch_id is null then
    select sr.branch_id
      into v_branch
      from identity.staff_members sm
      join identity.staff_roles sr on sr.staff_id = sm.id
     where sm.user_id = auth.uid()
       and sm.status = 'active'
       and sr.branch_id is not null
     order by sr.branch_id
     limit 1;

    if v_branch is null then
      select b.id into v_branch
        from core.branches b
       where b.is_active
       order by b.code
       limit 1;
    end if;
  else
    v_branch := p_branch_id;
  end if;

  if v_branch is null then
    raise exception 'no branch is available for this staff member'
      using errcode = 'P0002';
  end if;
  if not exists (
    select 1 from core.branches b where b.id = v_branch and b.is_active
  ) then
    raise exception 'branch not found or inactive' using errcode = 'P0002';
  end if;
  if not identity.can_manage_branch(v_branch) then
    raise exception 'branch out of scope' using errcode = '42501';
  end if;

  select b.currency_code,
         coalesce(b.tax_rate, 0),
         coalesce(b.tax_included, true)
    into v_currency, v_tax_rate, v_tax_included
    from core.brands b
   limit 1;

  select coalesce(jsonb_agg(
           jsonb_build_object(
             'id', b.id,
             'code', b.code,
             'name_ar', b.name_ar,
             'name_en', b.name_en
           ) order by b.name_ar
         ), '[]'::jsonb)
    into v_branches
    from core.branches b
   where b.is_active
     and identity.can_manage_branch(b.id);

  select coalesce(jsonb_agg(
           jsonb_build_object(
             'id', c.id,
             'name_ar', c.name_ar,
             'name_en', c.name_en,
             'image_url', c.image_url,
             'sort_order', c.sort_order,
             'product_count', coalesce(pc.product_count, 0)
           ) order by c.sort_order, c.name_ar
         ), '[]'::jsonb)
    into v_categories
    from catalog.categories c
    left join lateral (
      select count(*)::integer as product_count
        from catalog.products p
       where p.category_id = c.id
         and p.is_active
         and p.archived_at is null
    ) pc on true
   where c.is_active;

  select coalesce(jsonb_agg(
           jsonb_build_object(
             'id', m.id,
             'code', m.code,
             'name_ar', m.name_ar,
             'name_en', m.name_en,
             'is_online', m.is_online,
             'requires_saved_card', m.requires_saved_card,
             'sort_order', m.sort_order
           ) order by m.sort_order, m.name_ar
         ), '[]'::jsonb)
    into v_methods
    from payments.payment_methods m
   where m.is_active;

  select coalesce(jsonb_agg(
           to_jsonb(page)
           order by page.sort_order, page.name_ar
         ), '[]'::jsonb)
    into v_products
    from (
      select p.id,
             p.category_id,
             p.sku,
             p.name_ar,
             p.name_en,
             p.description_ar,
             p.description_en,
             p.image_url,
             p.sort_order,
             p.is_featured,
             p.prep_minutes,
             c.name_ar as category_name_ar,
             c.name_en as category_name_en,
             r.unit_price,
             r.regular_price,
             r.discount_percentage,
             r.is_available,
             r.unavailable_reason,
             coalesce(bs.quantity_on_hand, 0) as stock_quantity,
             (bs.product_id is not null) as track_stock,
             coalesce(bs.allow_negative, false) as allow_negative,
             (
               bs.product_id is not null
               and not bs.allow_negative
               and bs.quantity_on_hand <= 0
             ) as sold_out,
             coalesce((
               select jsonb_agg(
                        jsonb_build_object(
                          'id', g.id,
                          'name_ar', g.name_ar,
                          'name_en', g.name_en,
                          'selection_type', g.selection_type,
                          'min_select', case
                            when e.is_required
                              then greatest(g.min_select, 1)
                            else g.min_select
                          end,
                          'max_select', case
                            when g.selection_type = 'single' then 1
                            else g.max_select
                          end,
                          'is_required', e.is_required,
                          'sort_order', e.sort_order,
                          'values', coalesce((
                            select jsonb_agg(
                                     jsonb_build_object(
                                       'id', ov.id,
                                       'name_ar', ov.name_ar,
                                       'name_en', ov.name_en,
                                       'price_delta', catalog.option_value_delta(p.id, ov.id),
                                       'is_default', ov.is_default,
                                       'sort_order', ov.sort_order
                                     ) order by ov.sort_order, ov.name_ar
                                   )
                              from catalog.option_values ov
                             where ov.group_id = g.id
                               and ov.is_active
                          ), '[]'::jsonb)
                        ) order by e.sort_order, g.sort_order, g.name_ar
                      )
                 from catalog.effective_product_option_groups(p.id) e
                 join catalog.option_groups g on g.id = e.group_id
                where e.product_id = p.id
                  and g.is_active
                  and exists (
                    select 1 from catalog.option_values av
                     where av.group_id = g.id and av.is_active
                  )
             ), '[]'::jsonb) as option_groups
        from catalog.products p
        join catalog.categories c on c.id = p.category_id
        cross join lateral catalog.resolve_product_base_price(v_branch, p.id) r
        left join inventory.branch_stock bs
          on bs.branch_id = v_branch
         and bs.product_id = p.id
         and bs.variant_key = '00000000-0000-0000-0000-000000000000'::uuid
       where p.is_active
         and p.archived_at is null
         and c.is_active
    ) page;

  return jsonb_build_object(
    'branch_id', v_branch,
    'currency_code', v_currency,
    'tax_rate', v_tax_rate,
    'tax_included', v_tax_included,
    'branches', v_branches,
    'categories', v_categories,
    'payment_methods', v_methods,
    'products', v_products
  );
end;
$fn$;

comment on function public.admin_pos_catalog(uuid) is
  'The POS menu of one branch: products, effective prices, per-product option prices, stock and payment methods.';

revoke all on function public.admin_pos_catalog(uuid) from public, anon;
grant execute on function public.admin_pos_catalog(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 6. The frozen snapshots. Both tables copy the value's price at write time for
--    the receipt and the kitchen ticket, and 103 copies cart rows into order
--    rows rather than recomputing them. Doing the arithmetic at each of those
--    writers would leave the next writer to forget it, so one BEFORE INSERT
--    trigger per table asks the same function the price core asks, exactly like
--    orders.fill_order_item_product_discount (175) fills a column the caller
--    could not know. The FKs guarantee the parent line exists, so the lookup
--    cannot miss.
-- ---------------------------------------------------------------------------
create or replace function orders.fill_cart_item_option_price_delta()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_product uuid;
begin
  select ci.product_id into v_product
    from orders.cart_items ci
   where ci.id = NEW.cart_item_id;

  NEW.price_delta := catalog.option_value_delta(v_product, NEW.option_value_id);
  return NEW;
end;
$fn$;

create or replace function orders.fill_order_item_option_price_delta()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_product uuid;
begin
  select oi.product_id into v_product
    from orders.order_items oi
   where oi.id = NEW.order_item_id;

  NEW.price_delta := catalog.option_value_delta(v_product, NEW.option_value_id);
  return NEW;
end;
$fn$;

revoke all on function orders.fill_cart_item_option_price_delta()
  from public, anon, authenticated;
revoke all on function orders.fill_order_item_option_price_delta()
  from public, anon, authenticated;

drop trigger if exists tr_cart_item_option_price_delta on orders.cart_item_options;
create trigger tr_cart_item_option_price_delta
  before insert on orders.cart_item_options
  for each row execute function orders.fill_cart_item_option_price_delta();

drop trigger if exists tr_order_item_option_price_delta on orders.order_item_options;
create trigger tr_order_item_option_price_delta
  before insert on orders.order_item_options
  for each row execute function orders.fill_order_item_option_price_delta();

notify pgrst, 'reload config';
notify pgrst, 'reload schema';
