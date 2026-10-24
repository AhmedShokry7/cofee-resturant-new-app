-- 133_discount_badge_data.sql
--
-- The client shows a discount badge and a struck-through old price. Until now
-- the badge percentage was derived from the two prices:
--
--   percent = (oldPrice - price) / oldPrice * 100
--
-- and oldPrice was the admin's compare_at_price. A product with
-- compare_at_price = 50 and base_price = 40 and no discount at all therefore
-- announced a 20% discount that did not exist, and the same product was
-- announced with a different percentage on every screen that read its price
-- from a different function.
--
-- The percentage is now the one the server actually applied.
-- catalog.resolve_effective_price already returns the discount it used and the
-- regular price it started from, so the three list functions return them as
-- well and the badge has one honest source.
--
-- The featured list also regains the category names. Migration 066 added them
-- so a "Popular" card could label itself, and migrations 129 and 130 dropped
-- and recreated the function without them, which left every card with a blank
-- subtitle.

-- ---------------------------------------------------------------------------
-- The price of a product, the price it came from and the discount that was
-- applied to it.
-- ---------------------------------------------------------------------------
drop function if exists catalog.promotional_price(uuid, uuid);

create or replace function catalog.promotional_price(
  p_branch_id  uuid,
  p_product_id uuid
)
returns table (
  unit_price          numeric,
  regular_price       numeric,
  discount_percentage numeric,
  is_available        boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_price     numeric;
  v_available boolean;
begin
  begin
    return query
      select r.unit_price, r.regular_price, r.discount_percentage, r.is_available
        from catalog.resolve_effective_price(p_branch_id, p_product_id, '{}'::uuid[]) r;
    return;
  exception
    when others then
      null;
  end;

  -- A product with a required option group cannot be priced without a
  -- selection. The list still has to show it, so the regular price is used
  -- instead of failing the whole page.
  select coalesce(
           (select bpp.price_override
              from catalog.branch_product_pricing bpp
             where bpp.branch_id = p_branch_id
               and bpp.product_id = p_product_id),
           (select p.base_price
              from catalog.products p
             where p.id = p_product_id)),
         coalesce(
           (select bpp.is_available
              from catalog.branch_product_pricing bpp
             where bpp.branch_id = p_branch_id
               and bpp.product_id = p_product_id),
           true)
    into v_price, v_available;

  return query select v_price, v_price, 0::numeric, v_available;
end;
$fn$;

comment on function catalog.promotional_price(uuid, uuid) is
  'The price a customer sees for a product, the regular price it came from and the discount that was applied to it. Falls back to the regular price when the product cannot be priced without an option selection.';

revoke all on function catalog.promotional_price(uuid, uuid) from public;
grant execute on function catalog.promotional_price(uuid, uuid)
  to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- The search list prices every row with the authoritative rules.
-- ---------------------------------------------------------------------------
drop function if exists catalog.search_products(text, uuid, uuid, numeric, numeric, text, integer, integer);

create or replace function catalog.search_products(
  p_query       text default null,
  p_branch_id   uuid  default null,
  p_category_id uuid  default null,
  p_min_price   numeric default null,
  p_max_price   numeric default null,
  p_sort        text  default 'relevance',
  p_page        integer default 1,
  p_page_size   integer default 20
)
returns table (
  id            uuid,
  slug          text,
  name_ar       text,
  name_en       text,
  description_ar text,
  description_en text,
  image_url     text,
  base_price    numeric,
  effective_price numeric,
  is_available  boolean,
  category_id   uuid,
  category_name_ar text,
  category_name_en text,
  rank          real,
  total_count   bigint,
  regular_price numeric,
  discount_percentage numeric
)
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_q       text;
  v_page    integer := greatest(coalesce(p_page, 1), 1);
  v_size    integer := least(greatest(coalesce(p_page_size, 20), 1), 100);
  v_offset  integer;
begin
  v_q := nullif(btrim(coalesce(p_query, '')), '');
  v_offset := (v_page - 1) * v_size;

  return query
  with q as (
    select case when v_q is null then null
                else core.normalize_ar(v_q) end as nq
  ),
  scored as (
    select
      p.id, p.slug, p.name_ar, p.name_en, p.description_ar, p.description_en,
      p.image_url, p.base_price, p.category_id,
      c.name_ar as cname_ar, c.name_en as cname_en,
      coalesce(pp.unit_price, p.base_price) as eff_price,
      coalesce(pp.regular_price, p.base_price) as reg_price,
      coalesce(pp.discount_percentage, 0) as disc_pct,
      coalesce(pp.is_available, p.is_active, false) as avail,
      case
        when v_q is null then 0::real
        when ps.body_norm = v_q then 100::real
        when ps.body_norm like v_q || ' %' then 60::real
        when ps.body_norm like '% ' || v_q || ' %' then 40::real
        else extensions.similarity(ps.body_norm, v_q) * 20
      end + coalesce(
        (select max(extensions.similarity(a.alias_normalized, v_q)) * 30
           from catalog.product_aliases a
          where a.product_id = p.id), 0
      ) as rnk
    from catalog.products p
    join catalog.categories c on c.id = p.category_id
    left join catalog.product_search ps on ps.product_id = p.id
    left join lateral catalog.promotional_price(p_branch_id, p.id) pp on true
    cross join q
    where p.is_active and p.archived_at is null
      and (p_category_id is null or p.category_id = p_category_id)
      and (p_min_price is null or coalesce(pp.unit_price, p.base_price) >= p_min_price)
      and (p_max_price is null or coalesce(pp.unit_price, p.base_price) <= p_max_price)
      and (
        v_q is null
        or ps.body_norm like '%' || v_q || '%'
        or extensions.similarity(ps.body_norm, v_q) > 0.25
        or exists (
          select 1 from catalog.product_aliases a
          where a.product_id = p.id
            and (a.alias_normalized like '%' || v_q || '%'
                 or extensions.similarity(a.alias_normalized, v_q) > 0.3)
        )
      )
  )
  select
    s.id, s.slug, s.name_ar, s.name_en, s.description_ar, s.description_en,
    s.image_url, s.base_price, round(s.eff_price, 2), s.avail,
    s.category_id, s.cname_ar, s.cname_en,
    round(s.rnk::numeric, 4)::real,
    (select count(*) from scored),
    round(s.reg_price, 2),
    round(s.disc_pct, 2)
  from scored s
  order by
    case when p_sort = 'priceLowHigh'  then s.eff_price end asc nulls last,
    case when p_sort = 'priceHighLow'  then s.eff_price end desc nulls last,
    case when p_sort = 'nameAsc'       then s.name_en end asc nulls last,
    case when p_sort = 'relevance' or p_sort is null then s.rnk end desc,
    s.name_en asc
  limit v_size offset v_offset;
end;
$fn$;

comment on function catalog.search_products(text, uuid, uuid, numeric, numeric, text, integer, integer) is
  'Catalogue search. The price of every row comes from the authoritative pricing rules, and the row also carries the regular price and the discount that was applied.';

grant execute on function catalog.search_products(text, uuid, uuid, numeric, numeric, text, integer, integer)
  to anon, authenticated;

-- ---------------------------------------------------------------------------
-- The public bridge carries the same columns.
-- ---------------------------------------------------------------------------
drop function if exists public.search_products(text, uuid, uuid, numeric, numeric, text, integer, integer);

create or replace function public.search_products(
  p_query       text default null,
  p_branch_id   uuid  default null,
  p_category_id uuid  default null,
  p_min_price   numeric default null,
  p_max_price   numeric default null,
  p_sort        text  default 'relevance',
  p_page        integer default 1,
  p_page_size   integer default 20
)
returns table (
  id uuid, slug text, name_ar text, name_en text,
  description_ar text, description_en text, image_url text,
  base_price numeric, effective_price numeric, is_available boolean,
  category_id uuid, category_name_ar text, category_name_en text,
  rank real, total_count bigint,
  regular_price numeric, discount_percentage numeric
)
language sql
stable
security invoker
set search_path = ''
as $fn$
  select * from catalog.search_products(
    p_query, p_branch_id, p_category_id, p_min_price, p_max_price,
    p_sort, p_page, p_page_size);
$fn$;

revoke all on function public.search_products(text, uuid, uuid, numeric, numeric, text, integer, integer) from public;
grant execute on function public.search_products(text, uuid, uuid, numeric, numeric, text, integer, integer)
  to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- The featured list carries the same columns, and its category names.
-- ---------------------------------------------------------------------------
drop function if exists catalog.get_featured(uuid, integer);

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
    category_name_en  text,
    regular_price     numeric,
    discount_percentage numeric
  )
  language plpgsql
  stable
  security definer
  set search_path = ''
as $function$
begin
  return query
  with manual as (
    select p.id, p.name_ar, p.name_en, p.image_url,
           pp.unit_price as price,
           pp.regular_price as regular,
           pp.discount_percentage as pct,
           'manual'::text as src,
           c.name_ar as category_ar, c.name_en as category_en
      from catalog.products p
      left join catalog.branch_product_pricing bpp
        on bpp.product_id = p.id
       and bpp.branch_id is not distinct from p_branch_id
      left join catalog.categories c on c.id = p.category_id
      left join lateral catalog.promotional_price(p_branch_id, p.id) pp on true
     where p.is_featured and p.is_active and p.archived_at is null
       and coalesce(bpp.is_featured, p.is_featured)
       and coalesce(bpp.is_available, true)
    limit coalesce(p_limit, 10)
  ),
  computed as (
    select bs.product_id, p.name_ar, p.name_en, p.image_url,
           pp.unit_price as price,
           pp.regular_price as regular,
           pp.discount_percentage as pct,
           'best_seller'::text as src,
           c.name_ar as category_ar, c.name_en as category_en,
           row_number() over (order by bs.units_sold desc) as rn
      from catalog.get_best_sellers(p_branch_id, '30 days', 50) bs
      join catalog.products p on p.id = bs.product_id
      left join catalog.branch_product_pricing bpp
        on bpp.product_id = p.id
       and bpp.branch_id is not distinct from p_branch_id
      left join catalog.categories c on c.id = p.category_id
      left join lateral catalog.promotional_price(p_branch_id, p.id) pp on true
  )
  select m.id, m.name_ar, m.name_en, m.image_url, round(m.price, 2), m.src,
         m.category_ar, m.category_en, round(m.regular, 2), round(m.pct, 2)
    from manual m
  union all
  select c.product_id, c.name_ar, c.name_en, c.image_url, round(c.price, 2), c.src,
         c.category_ar, c.category_en, round(c.regular, 2), round(c.pct, 2)
    from computed c
   where not exists (select 1 from manual m where m.id = c.product_id)
     and c.rn <= coalesce(p_limit, 10)
   order by 6, 5
   limit coalesce(p_limit, 10);
end;
$function$;

comment on function catalog.get_featured(uuid, integer) is
  'Featured products with authoritative discounted prices, the regular price they came from and the category names.';

grant execute on function catalog.get_featured(uuid, integer) to anon, authenticated;

drop function if exists public.get_featured(uuid, integer);

create or replace function public.get_featured(
  p_branch_id uuid,
  p_limit integer default 10
)
returns table (
  product_id uuid, name_ar text, name_en text, image_url text,
  effective_price numeric, source text,
  category_name_ar text, category_name_en text,
  regular_price numeric, discount_percentage numeric
)
language sql
stable
security invoker
set search_path = ''
as $function$
  select * from catalog.get_featured(p_branch_id, p_limit);
$function$;

revoke all on function public.get_featured(uuid, integer) from public;
grant execute on function public.get_featured(uuid, integer)
  to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- The bulk read carries the same columns.
-- ---------------------------------------------------------------------------
drop function if exists public.catalog_products_by_ids(uuid[], uuid);

create or replace function public.catalog_products_by_ids(
  p_product_ids uuid[],
  p_branch_id uuid default null
)
returns table (
  product jsonb,
  images jsonb,
  effective_price numeric,
  regular_price numeric,
  discount_percentage numeric
)
language sql
stable
security invoker
set search_path = ''
as $function$
  select
    to_jsonb(p) as product,
    coalesce(image_rows.items, '[]'::jsonb) as images,
    coalesce(pr.unit_price, p.base_price) as effective_price,
    coalesce(pr.regular_price, p.base_price) as regular_price,
    coalesce(pr.discount_percentage, 0) as discount_percentage
  from public.products as p
  left join lateral catalog.promotional_price(p_branch_id, p.id) pr on true
  left join lateral (
    select jsonb_agg(to_jsonb(image) order by image.sort_order) as items
    from public.product_images as image
    where image.product_id = p.id
  ) as image_rows on true
  where p.id = any(coalesce(p_product_ids, array[]::uuid[]));
$function$;

comment on function public.catalog_products_by_ids(uuid[], uuid) is
  'Bulk catalog read: product JSON, ordered image rows, the discounted price, the regular price and the discount that was applied, in one request.';

revoke all on function public.catalog_products_by_ids(uuid[], uuid)
  from public, anon, authenticated;
grant execute on function public.catalog_products_by_ids(uuid[], uuid)
  to anon, authenticated;

notify pgrst, 'reload schema';
