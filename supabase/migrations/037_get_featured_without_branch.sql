-- 037_get_featured_without_branch.sql
--
-- get_featured() joined catalog.branch_product_pricing with
--   on bpp.product_id = p.id and bpp.branch_id = p_branch_id
-- which is an inner join, so p_branch_id = NULL matched no pricing row and the
-- function returned nothing at all.
--
-- That is the state the app is in on a cold start: HomeCubit passes branchId
-- null until the customer picks a branch, so the home "Popular" section would
-- render empty for every first-time visitor even though catalog.products
-- pins six featured products.
--
-- Fix: match the pricing row with `is not distinct from`, which also accepts
-- NULL, and turn the joins into left joins. When no branch is selected the
-- product's own base price, featured flag and availability are used instead.
-- A selected branch keeps full precedence.

create or replace function catalog.get_featured(
  p_branch_id uuid,
  p_limit integer default 10
)
  returns table (
    product_id uuid,
    name_ar     text,
    name_en     text,
    image_url   text,
    effective_price numeric,
    source      text
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
           'manual'::text as src
      from catalog.products p
      left join catalog.branch_product_pricing bpp
        on bpp.product_id = p.id
       and bpp.branch_id is not distinct from p_branch_id
     where p.is_featured and p.is_active and p.archived_at is null
       and coalesce(bpp.is_featured, p.is_featured)
       and coalesce(bpp.is_available, true)
    limit coalesce(p_limit, 10)
  ),
  computed as (
    select bs.product_id, p.name_ar, p.name_en, p.image_url,
           coalesce(bpp.price_override, p.base_price) as price,
           'best_seller'::text as src,
           row_number() over (order by bs.units_sold desc) as rn
      from catalog.get_best_sellers(p_branch_id, '30 days', 50) bs
      join catalog.products p on p.id = bs.product_id
      left join catalog.branch_product_pricing bpp
        on bpp.product_id = p.id
       and bpp.branch_id is not distinct from p_branch_id
  )
  select m.id, m.name_ar, m.name_en, m.image_url, round(m.price, 2), m.src
    from manual m
  union all
  select c.product_id, c.name_ar, c.name_en, c.image_url, round(c.price, 2), c.src
    from computed c
   where not exists (select 1 from manual m where m.id = c.product_id)
     and c.rn <= coalesce(p_limit, 10)
   order by 6, 5
   limit coalesce(p_limit, 10);
end;
$function$;

comment on function catalog.get_featured(uuid, integer) is
  'Admin-pinned featured products first, then best sellers. p_branch_id may be '
  'null, in which case base prices and the product-level featured flag apply.';