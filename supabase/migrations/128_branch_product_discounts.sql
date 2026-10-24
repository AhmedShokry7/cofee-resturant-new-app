-- 128_branch_product_discounts.sql
--
-- Adds optional branch-specific product discounts and makes resolve_effective_price
-- the single source of truth for the promotional price. Product-level discounts
-- were added by 127; this migration adds the branch override and the
-- use_general_discount flag that distinguishes "no override" from "explicitly
-- disable the general discount for this branch".

alter table catalog.branch_product_pricing
  add column if not exists discount_percentage numeric(5,2)
    check (discount_percentage is null or (discount_percentage >= 0 and discount_percentage <= 100)),
  add column if not exists discount_starts_at timestamptz,
  add column if not exists discount_ends_at timestamptz,
  add column if not exists use_general_discount boolean not null default true;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'ck_bpp_discount_window'
      and conrelid = 'catalog.branch_product_pricing'::regclass
  ) then
    alter table catalog.branch_product_pricing
      add constraint ck_bpp_discount_window check (
        discount_ends_at is null
        or discount_starts_at is null
        or discount_ends_at > discount_starts_at
      );
  end if;
end $$;

-- Refresh the public product view so the new product discount columns are visible.
create or replace view public.products with (security_invoker = true) as
  select p.id, p.category_id, p.sku, p.slug, p.name_ar, p.name_en,
         p.description_ar, p.description_en, p.base_price,
         p.compare_at_price, p.image_url, p.is_active, p.is_featured,
         p.prep_minutes, p.is_calorie_tracked, p.allergens, p.sort_order,
         c.slug  as category_slug,
         c.name_ar as category_name_ar,
         c.name_en as category_name_en,
         p.related_product_ids,
         p.calories,
         p.discount_percentage, p.discount_starts_at, p.discount_ends_at
    from catalog.products p
    join catalog.categories c on c.id = p.category_id;

-- branch_product_pricing already uses select *, so its new columns are exposed.

-- Drop the old signatures first: CREATE OR REPLACE cannot change the return type.
drop function if exists public.resolve_effective_price(uuid, uuid, uuid[]);
drop function if exists catalog.resolve_effective_price(uuid, uuid, uuid[]);

-- Authoritative pricing: regular price = coalesce(branch override, base price).
-- General product discount applies when use_general_discount is true and no
-- active branch-specific discount is configured. Branch-specific discount
-- takes precedence when it is active. Discounts never apply outside their
-- configured time window. Option deltas are added after the discount.
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
  v_base      numeric;
  v_override  numeric;
  v_available boolean;
  v_reason    text;
  v_active    boolean;
  v_archived  timestamptz;
  v_currency  text;
  v_deltas    numeric;
  v_regular   numeric;
  v_now       timestamptz := now();
  v_general_pct numeric;
  v_branch_pct  numeric;
  v_use_general boolean;
  v_branch_start timestamptz;
  v_branch_end   timestamptz;
  v_general_start timestamptz;
  v_general_end   timestamptz;
  v_pct           numeric;
begin
  perform catalog.validate_product_option_selection(p_product_id, p_option_value_ids);

  select p.base_price, p.is_active, p.archived_at,
         p.discount_percentage, p.discount_starts_at, p.discount_ends_at
    into v_base, v_active, v_archived, v_general_pct, v_general_start, v_general_end
    from catalog.products p
   where p.id = p_product_id;

  if not found then
    raise exception 'product % not found', p_product_id using errcode = 'P0002';
  end if;

  select b.currency_code into v_currency from core.brands b limit 1;

  select bpp.price_override, bpp.is_available, bpp.unavailable_reason,
         bpp.discount_percentage, bpp.discount_starts_at, bpp.discount_ends_at,
         bpp.use_general_discount
    into v_override, v_available, v_reason, v_branch_pct, v_branch_start, v_branch_end, v_use_general
    from catalog.branch_product_pricing bpp
   where bpp.branch_id = p_branch_id and bpp.product_id = p_product_id;

  v_available := coalesce(v_available, true);
  if not v_active or v_archived is not null then
    v_available := false;
    v_reason := coalesce(v_reason, 'product inactive');
  end if;

  v_regular := coalesce(v_override, v_base);

  -- General discount is active only inside its window.
  if v_general_pct is null
     or (v_general_start is not null and v_now < v_general_start)
     or (v_general_end is not null and v_now > v_general_end) then
    v_general_pct := 0;
  end if;

  -- Branch discount is active only inside its window.
  if v_branch_pct is null
     or (v_branch_start is not null and v_now < v_branch_start)
     or (v_branch_end is not null and v_now > v_branch_end) then
    v_branch_pct := null;
  end if;

  v_use_general := coalesce(v_use_general, true);

  begin
    if v_branch_pct is not null then
      v_pct := v_branch_pct;
    elsif v_use_general then
      v_pct := v_general_pct;
    else
      v_pct := 0;
    end if;

    select coalesce(sum(ov.price_delta), 0)
      into v_deltas
      from catalog.option_values ov
     where ov.id = any(p_option_value_ids)
       and ov.is_active;

    return query
    select round(v_regular * (1 - v_pct / 100.0) + v_deltas, 2),
           v_currency,
           v_available,
           round(v_deltas, 2),
           v_reason,
           round(v_regular + v_deltas, 2),
           round(v_pct, 2);
  end;
end;
$fn$;

-- Keep the public bridge in sync with the new return shape.
create or replace function public.resolve_effective_price(
  p_branch_id  uuid,
  p_product_id uuid,
  p_option_value_ids uuid[] default '{}'
)
returns table (
  unit_price numeric, currency_code text, is_available boolean,
  option_deltas numeric, unavailable_reason text,
  regular_price numeric, discount_percentage numeric
)
language sql
stable
security invoker
set search_path = ''
as $fn$
  select * from catalog.resolve_effective_price(p_branch_id, p_product_id, p_option_value_ids);
$fn$;

comment on function catalog.resolve_effective_price(uuid, uuid, uuid[]) is
  'Server-side price truth including general and branch-specific discounts.';

-- Keep bulk hydration in sync with the authoritative pricing rules.
create or replace function public.catalog_products_by_ids(
  p_product_ids uuid[],
  p_branch_id uuid default null
)
returns table (
  product jsonb,
  images jsonb,
  effective_price numeric
)
language sql
stable
security invoker
set search_path = ''
as $function$
  select
    to_jsonb(p) as product,
    coalesce(image_rows.items, '[]'::jsonb) as images,
    case
      when p_branch_id is null then p.base_price
      else (select r.unit_price
              from catalog.resolve_effective_price(p_branch_id, p.id, '{}'::uuid[]) r)
    end as effective_price
  from public.products as p
  left join lateral (
    select jsonb_agg(to_jsonb(image) order by image.sort_order) as items
    from public.product_images as image
    where image.product_id = p.id
  ) as image_rows on true
  where p.id = any(coalesce(p_product_ids, array[]::uuid[]));
$function$;

comment on function public.catalog_products_by_ids(uuid[], uuid) is
  'Bulk catalog read with authoritative discounted prices.';

notify pgrst, 'reload schema';
