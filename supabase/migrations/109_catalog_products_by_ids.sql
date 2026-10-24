-- Bulk product hydration used by cart restore, bundle contents, reward cards,
-- and related-product sections. Product JSON, image rows, and branch price are
-- assembled inside Postgres so the client makes one read request instead of
-- one product lookup per id plus separate image/price requests.
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
    coalesce(price.price_override, p.base_price) as effective_price
  from public.products as p
  left join public.branch_product_pricing as price
    on price.product_id = p.id
   and price.branch_id = p_branch_id
  left join lateral (
    select jsonb_agg(to_jsonb(image) order by image.sort_order) as items
    from public.product_images as image
    where image.product_id = p.id
  ) as image_rows on true
  where p.id = any(coalesce(p_product_ids, array[]::uuid[]));
$function$;

comment on function public.catalog_products_by_ids(uuid[], uuid) is
  'Bulk catalog read: product JSON, ordered image rows and optional branch price in one request.';

revoke all on function public.catalog_products_by_ids(uuid[], uuid)
  from public, anon, authenticated;
grant execute on function public.catalog_products_by_ids(uuid[], uuid)
  to anon, authenticated;

notify pgrst, 'reload schema';
