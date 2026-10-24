-- 132_search_products_discounts.sql
--
-- The search list priced the products itself:
--
--   coalesce(bpp.price_override, p.base_price) as eff_price
--
-- so it ignored the product discount, the branch discount and the discount
-- window. The same product was shown at its full price in the search results
-- and at its discounted price in the menu, in the cart and on the invoice, so
-- the list and the basket disagreed.
--
-- catalog.resolve_effective_price is the one place that decides a price (added
-- by 128), and catalog.get_featured already uses it (129). The search list uses
-- it as well, so one rule decides the price everywhere.
--
-- The price is read through a new helper, catalog.promotional_price, because
-- resolve_effective_price validates the option selection: a product with a
-- required option group cannot be priced without a selection, and a list read
-- must not fail because of one product. The helper falls back to the regular
-- price in that case and to nothing else. The same helper replaces the direct
-- call in catalog.get_featured, which had the same exposure.

-- ---------------------------------------------------------------------------
-- The price a customer sees for a product, with the discounts applied.
-- ---------------------------------------------------------------------------
create or replace function catalog.promotional_price(
  p_branch_id  uuid,
  p_product_id uuid
)
returns table (
  unit_price   numeric,
  is_available boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $fn$
begin
  return query
    select r.unit_price, r.is_available
      from catalog.resolve_effective_price(p_branch_id, p_product_id, '{}'::uuid[]) r;
exception
  when others then
    -- A product with a required option group cannot be priced without a
    -- selection. The list still has to show it, so the regular price is used
    -- instead of failing the whole page.
    return query
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
               true);
end;
$fn$;

comment on function catalog.promotional_price(uuid, uuid) is
  'The price a customer sees for a product, with the general and the branch discount applied. Falls back to the regular price when the product cannot be priced without an option selection.';

revoke all on function catalog.promotional_price(uuid, uuid) from public;
grant execute on function catalog.promotional_price(uuid, uuid) to service_role;

-- ---------------------------------------------------------------------------
-- The search list prices every row with the authoritative rules.
-- ---------------------------------------------------------------------------
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
  total_count   bigint
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
    (select count(*) from scored)
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
  'Catalogue search. The price of every row comes from the authoritative pricing rules, discounts included.';

-- ---------------------------------------------------------------------------
-- The featured list reads the price the same way.
-- ---------------------------------------------------------------------------
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
  set search_path = ''
as $function$
begin
  return query
  with manual as (
    select p.id, p.name_ar, p.name_en, p.image_url,
           (select pp.unit_price from catalog.promotional_price(p_branch_id, p.id) pp) as price,
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
           (select pp.unit_price from catalog.promotional_price(p_branch_id, p.id) pp) as price,
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
