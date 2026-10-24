-- 129_get_featured_discounts.sql
-- Keeps get_featured in sync with resolve_effective_price.
drop function if exists catalog.get_featured(uuid, integer);

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
           case when p_branch_id is null
                then p.base_price
                else (select r.unit_price from catalog.resolve_effective_price(p_branch_id, p.id, '{}'::uuid[]) r)
           end as price,
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
           case when p_branch_id is null
                then p.base_price
                else (select r.unit_price from catalog.resolve_effective_price(p_branch_id, p.id, '{}'::uuid[]) r)
           end as price,
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
  'Featured products with authoritative discounted prices.';

notify pgrst, 'reload schema';
