-- 066_featured_category_names.sql
--
-- HomeCubit turns every get_featured row into a ProductModel so the shared
-- ProductCard can render it, and that card shows the category name in its
-- subtitle slot. get_featured returned no category columns at all, so
-- HomeCubit had to pass category: '' and every "Popular" card on the home page
-- rendered a blank subtitle line.
--
-- The products themselves are categorised — public.products already carries
-- category_name_ar/category_name_en — so this is a missing column, not
-- missing data.
--
-- Fix: return the category names from catalog.get_featured and from its public
-- bridge. The function signatures are unchanged, so the existing grants in
-- 036_public_bridge_harden_grants.sql keep applying.

-- Drop first: CREATE OR REPLACE cannot change a function's return type.
drop function if exists catalog.get_featured(uuid, integer);
drop function if exists public.get_featured(uuid, integer);
--
-- Left join, not inner: a product with no category must still appear in the
-- carousel, it just shows no subtitle — the same as any other uncategorised
-- card. An inner join would silently hide featured products instead.

create or replace function catalog.get_featured(
  p_branch_id uuid,
  p_limit integer default 10
)
  returns table (
    product_id        uuid,
    name_ar           text,
    name_en           text,
    image_url         text,
    effective_price   numeric,
    source            text,
    category_name_ar  text,
    category_name_en  text
  )
  language plpgsql
  stable
  security definer
  set search_path to ''
as $function$
begin
  return query
  with manual as (
    select p.id, p.name_ar, p.name_en, p.image_url,
           coalesce(bpp.price_override, p.base_price) as price,
           'manual'::text as src,
           c.name_ar as category_ar, c.name_en as category_en
      from catalog.products p
      left join catalog.branch_product_pricing bpp
        on bpp.product_id = p.id
       and bpp.branch_id is not distinct from p_branch_id
      left join catalog.categories c on c.id = p.category_id
     where p.is_featured and p.is_active and p.archived_at is null
       and coalesce(bpp.is_featured, p.is_featured)
       and coalesce(bpp.is_available, true)
     limit coalesce(p_limit, 10)
  ),
  computed as (
    select bs.product_id, p.name_ar, p.name_en, p.image_url,
           coalesce(bpp.price_override, p.base_price) as price,
           'best_seller'::text as src,
           c.name_ar as category_ar, c.name_en as category_en,
           row_number() over (order by bs.units_sold desc) as rn
      from catalog.get_best_sellers(p_branch_id, '30 days', 50) bs
      join catalog.products p on p.id = bs.product_id
      left join catalog.branch_product_pricing bpp
        on bpp.product_id = p.id
       and bpp.branch_id is not distinct from p_branch_id
      left join catalog.categories c on c.id = p.category_id
  )
  select m.id, m.name_ar, m.name_en, m.image_url, round(m.price, 2), m.src,
         m.category_ar, m.category_en
    from manual m
  union all
  select c.product_id, c.name_ar, c.name_en, c.image_url, round(c.price, 2), c.src,
         c.category_ar, c.category_en
    from computed c
   where not exists (select 1 from manual m where m.id = c.product_id)
     and c.rn <= coalesce(p_limit, 10)
   order by 6, 5
   limit coalesce(p_limit, 10);
end;
$function$;

comment on function catalog.get_featured(uuid, integer) is
  'Admin-pinned featured products first, then best sellers. p_branch_id may be '
  'null, in which case base prices and the product-level featured flag apply. '
  'Category names are included so clients can label a card without a second '
  'query; they are null when the product has no category.';

-- ---------------------------------------------------------------------------
-- Public bridge. The declared return table must list the new columns, because
-- `select *` on a changed source would otherwise fail to match.
-- ---------------------------------------------------------------------------

create or replace function public.get_featured(
  p_branch_id uuid,
  p_limit integer default 10
)
returns table (
  product_id uuid, name_ar text, name_en text, image_url text,
  effective_price numeric, source text,
  category_name_ar text, category_name_en text
)
language sql
stable
security invoker
set search_path to ''
as $fn$
  select * from catalog.get_featured(p_branch_id, p_limit);
$fn$;