-- 224_option_group_scope.sql
--
-- WHAT THIS ADDS
-- An option group (a set of sizes, a set of extras) can now say WHICH products it
-- is offered on, instead of that being a hand-written row per product:
--
--   applies_to = 'products'  the explicit rows in catalog.product_option_groups,
--                            which is exactly today's behaviour (the default, so
--                            every existing group keeps the products it has now);
--   applies_to = 'category'  every active product of the categories listed in the
--                            new catalog.option_group_categories;
--   applies_to = 'all'       every product, with no rows to maintain.
--
-- A product row in catalog.product_option_groups can also opt a single product out
-- of a broad group (`is_excluded`), so "sugar on every drink except the V60" is one
-- row rather than a rule in the app.
--
-- WHY ONE FUNCTION OWNS THE RULE
-- The binding set is read by four places: the price RPC, the cart RPC, order
-- placement (all through catalog.validate_product_option_selection), the POS menu,
-- and the customer app's product screen. If each of them re-implemented "which
-- groups apply", a scope change would have to be remembered in five files and the
-- server would happily price an option the screen never offered. So
-- catalog.effective_product_option_groups() is the only place that decides, and
-- every reader goes through it.
--
-- The function is SECURITY INVOKER on purpose. The public view over it is
-- `with (security_invoker = true)` like every other bridge view in 032, so an
-- anonymous catalogue read still runs under the caller's own role and the RLS
-- policies of 020 decide which rows exist. Making it DEFINER would have been
-- shorter and would have leaked inactive products' bindings to `anon`.

-- ---------------------------------------------------------------------------
-- 1. The scope column and the two join shapes.
-- ---------------------------------------------------------------------------
alter table catalog.option_groups
  add column if not exists applies_to text not null default 'products';

comment on column catalog.option_groups.applies_to is
  'Which products offer this group: all, the categories in option_group_categories, or the rows in product_option_groups.';

do $do$
begin
  if not exists (
    select 1 from pg_constraint
     where conrelid = 'catalog.option_groups'::regclass
       and conname  = 'ck_option_groups_applies_to'
  ) then
    alter table catalog.option_groups
      add constraint ck_option_groups_applies_to
      check (applies_to in ('all', 'category', 'products'));
  end if;
end;
$do$;

create table if not exists catalog.option_group_categories (
  group_id    uuid not null references catalog.option_groups(id) on delete cascade,
  category_id uuid not null references catalog.categories(id)    on delete cascade,
  sort_order  integer not null default 0,
  is_required boolean not null default false,
  primary key (group_id, category_id)
);

comment on table catalog.option_group_categories is
  'Categories a group is offered on when option_groups.applies_to = ''category''.';

create index if not exists ix_option_group_categories_category
  on catalog.option_group_categories (category_id);

-- RLS off by default on a fresh table; 018 turns it on for the rest of the
-- catalogue and without it here every grant would be an unfiltered read.
alter table catalog.option_group_categories enable row level security;

alter table catalog.product_option_groups
  add column if not exists is_excluded boolean not null default false;

comment on column catalog.product_option_groups.is_excluded is
  'True opts this product out of a group that applies_to = all or category. Ignored for products-bound groups.';

-- ---------------------------------------------------------------------------
-- 2. The single owner of "which groups does this product offer".
-- ---------------------------------------------------------------------------
create or replace function catalog.effective_product_option_groups(
  p_product_id uuid default null
)
returns table (
  product_id  uuid,
  group_id    uuid,
  sort_order  integer,
  is_required boolean
)
language plpgsql
stable
security invoker
set search_path = ''
as $fn$
begin
  return query
  select p.id,
         g.id,
         -- A narrower binding wins over a broader one, and both fall back to the
         -- group's own display order. Sorting on the code instead would render the
         -- sizes as Large, Medium, Small.
         coalesce(b.sort_order, gc.sort_order, g.sort_order),
         -- Any level can make a group required; none can relax one (046 rule).
         coalesce(b.is_required, false)
           or coalesce(gc.is_required, false)
           or g.is_required
    from catalog.products p
    join catalog.option_groups g
      on g.is_active
    left join catalog.product_option_groups b
      on b.product_id = p.id
     and b.group_id = g.id
    left join catalog.option_group_categories gc
      on gc.group_id = g.id
     and gc.category_id = p.category_id
   where (p_product_id is null or p.id = p_product_id)
     and not coalesce(b.is_excluded, false)
     and case g.applies_to
           when 'all'     then true
           when 'category' then gc.group_id is not null
           else b.group_id is not null
         end;
end;
$fn$;

comment on function catalog.effective_product_option_groups(uuid) is
  'The only definition of which option groups a product offers: scope plus opt-outs.';

revoke all on function catalog.effective_product_option_groups(uuid) from public;
grant execute on function catalog.effective_product_option_groups(uuid)
  to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 3. The verifier now asks that function instead of reading the binding table.
--    Everything else about the contract is unchanged (046).
-- ---------------------------------------------------------------------------
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

  if not exists (
    select 1 from catalog.products p
     where p.id = p_product_id
  ) then
    raise exception 'product % not found', p_product_id using errcode = 'P0002';
  end if;

  -- Activated values may only come from a group that applies to this product and
  -- from an active value. This covers foreign, cross-product and inactive cases.
  if exists (
    select 1
      from unnest(v_distinct) as d(value_id)
     where not exists (
       select 1
         from catalog.effective_product_option_groups(p_product_id) e
         join catalog.option_groups og on og.id = e.group_id
         join catalog.option_values ov on ov.group_id = e.group_id
        where ov.id = d.value_id
          and ov.is_active
          and og.is_active
     )
  ) then
    raise exception 'option not available for product %', p_product_id
      using errcode = '23514';
  end if;

  -- Rules are applied independently per group that applies.
  for v_group in
    select
      e.group_id,
      e.is_required,
      og.selection_type,
      og.min_select,
      og.max_select
    from catalog.effective_product_option_groups(p_product_id) e
    join catalog.option_groups og on og.id = e.group_id
   where og.is_active
  loop
    v_min := v_group.min_select;
    if v_group.is_required then
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
  'Server-side contract for product option selections: applicability (224 scope), membership, active status, uniqueness, min/max and required groups.';

revoke all on function
  catalog.validate_product_option_selection(uuid, uuid[])
  from public;

grant execute on function
  catalog.validate_product_option_selection(uuid, uuid[])
  to service_role;

-- ---------------------------------------------------------------------------
-- 4. Bridge views, grants and RLS, in the shape of 032 / 023 / 020.
-- ---------------------------------------------------------------------------
create or replace view public.option_group_categories
  with (security_invoker = true) as
  select * from catalog.option_group_categories;

-- 032 wrote these two views as `select *`, and a view's `*` is expanded when the
-- view is created, not when it is queried. Without rebuilding them the dashboard
-- would read a catalogue whose `applies_to` and `is_excluded` do not exist --
-- measured live on the first run of this migration.
create or replace view public.option_groups
  with (security_invoker = true) as
  select * from catalog.option_groups;

create or replace view public.product_option_groups
  with (security_invoker = true) as
  select * from catalog.product_option_groups;

-- The resolved answer the customer app reads, in place of the raw binding rows.
create or replace view public.product_option_groups_effective
  with (security_invoker = true) as
  select * from catalog.effective_product_option_groups(null::uuid);

-- Least privilege, the 023 + 030 split: everyone may read the mapping, only
-- staff may write it, and RLS still gates every row.
grant select on catalog.option_group_categories to anon, authenticated;
grant insert, update, delete on catalog.option_group_categories to authenticated;

-- Clients touch the views, so the views need their own grants (131).
grant select on public.option_group_categories to anon, authenticated;
grant select on public.product_option_groups_effective to anon, authenticated;
grant insert, update, delete on public.option_group_categories to authenticated;

-- The raw binding table is still readable (it always was) and now carries
-- opt-outs; the effective view is built from it and from the categories, so
-- `anon` must be able to read both or the whole resolution raises 42501.
drop policy if exists option_group_categories_public_read on catalog.option_group_categories;
create policy option_group_categories_public_read on catalog.option_group_categories
  for select to anon, authenticated
  using (true);

drop policy if exists option_group_categories_admin_write on catalog.option_group_categories;
create policy option_group_categories_admin_write on catalog.option_group_categories
  for all to authenticated
  using (identity.has_permission('catalog.product.write'))
  with check (identity.has_permission('catalog.product.write'));

-- ---------------------------------------------------------------------------
-- 5. The dashboard writes these tables through the bridge views, exactly like
--    the catalogue writes of 184. The two rebuilt views above are what makes
--    `applies_to` and `is_excluded` writable from the dashboard at all.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- 6. The POS menu offers exactly what the customer app offers. It used to read
--    catalog.product_option_groups directly, so a group scoped to a category or
--    to every product would have been priced by validate_product_option_selection
--    and still never shown to the cashier.
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
                                       'price_delta', ov.price_delta,
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
  'The POS menu of one branch: products, effective prices, stock, options and payment methods.';

revoke all on function public.admin_pos_catalog(uuid) from public, anon;
grant execute on function public.admin_pos_catalog(uuid) to authenticated;

notify pgrst, 'reload config';
notify pgrst, 'reload schema';
