-- 024_functions_02_catalog.sql
--
-- Catalog RPCs. Each one exists for a stated reason (spec section 8), not
-- because "functions are faster".
--
--   resolve_effective_price -> the client must not decide the price
--   search_products        -> normalization + trigram + aliases + pagination
--                              is a compound query, not a View
--   get_best_sellers       -> aggregate over completed orders, needs a window
--   get_featured           -> manual override merged with computed ranking
--
-- Every SECURITY DEFINER function pins search_path = '' and qualifies names.

-- ---------------------------------------------------------------------------
-- Effective price for a product at a branch, including option deltas.
--
-- Closes the hole where CartItem.unitPrice was client-supplied and
-- loyalty_page.dart:22-26 could pass unitPrice: 0 for a free item.
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
  unavailable_reason text
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
begin
  select p.base_price, p.is_active, p.archived_at
    into v_base, v_active, v_archived
    from catalog.products p
   where p.id = p_product_id;

  if not found then
    raise exception 'product % not found', p_product_id using errcode = 'P0002';
  end if;

  select b.currency_code into v_currency from core.brands b limit 1;

  -- Branch override wins over the base price.
  select bpp.price_override, bpp.is_available, bpp.unavailable_reason
    into v_override, v_available, v_reason
    from catalog.branch_product_pricing bpp
   where bpp.branch_id = p_branch_id and bpp.product_id = p_product_id;

  -- No branch row means "available everywhere", unless the product itself is off.
  v_available := coalesce(v_available, true);
  if not v_active or v_archived is not null then
    v_available := false;
    v_reason := coalesce(v_reason, 'product inactive');
  end if;

  select coalesce(sum(ov.price_delta), 0)
    into v_deltas
    from catalog.option_values ov
   where ov.id = any(p_option_value_ids)
     and ov.is_active;

  -- Options are only valid if they belong to a group actually offered by
  -- this product. Prevents smuggling in an unrelated cheap group.
  if exists (
    select 1
    from catalog.option_values ov
    where ov.id = any(p_option_value_ids)
      and not exists (
        select 1
        from catalog.product_option_groups pog
        join catalog.option_values ov2 on ov2.group_id = pog.group_id
        where pog.product_id = p_product_id and ov2.id = ov.id
      )
  ) then
    raise exception 'option not available for product %', p_product_id
      using errcode = '23514';
  end if;

  return query
    select round(coalesce(v_override, v_base) + v_deltas, 2),
           v_currency,
           v_available,
           round(v_deltas, 2),
           v_reason;
end;
$fn$;

comment on function catalog.resolve_effective_price(uuid, uuid, uuid[]) is
  'Server-side price truth. The client cannot override the result.';

-- ---------------------------------------------------------------------------
-- Search (D6). Arabic input is normalized, then matched against the
-- denormalised trigram index, with aliases folded in.
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
      coalesce(bpp.price_override, p.base_price) as eff_price,
      coalesce(bpp.is_available, p.is_active, false) as avail,
      -- ranking: exact prefix beats word-prefix beats trigram similarity
      case
        when v_q is null then 0::real
        when ps.body_norm = v_q then 100::real
        when ps.body_norm like v_q || ' %' then 60::real
        when ps.body_norm like '% ' || v_q || ' %' then 40::real
        else similarity(ps.body_norm, v_q) * 20
      end + coalesce(
        (select max(similarity(a.alias_normalized, v_q)) * 30
           from catalog.product_aliases a
          where a.product_id = p.id), 0
      ) as rnk
    from catalog.products p
    join catalog.categories c on c.id = p.category_id
    left join catalog.product_search ps on ps.product_id = p.id
    left join catalog.branch_product_pricing bpp
           on bpp.product_id = p.id and bpp.branch_id = p_branch_id
    cross join q
    where p.is_active and p.archived_at is null
      and (p_category_id is null or p.category_id = p_category_id)
      and (p_min_price is null or coalesce(bpp.price_override, p.base_price) >= p_min_price)
      and (p_max_price is null or coalesce(bpp.price_override, p.base_price) <= p_max_price)
      and (
        v_q is null
        or ps.body_norm like '%' || v_q || '%'
        or similarity(ps.body_norm, v_q) > 0.25
        or exists (
          select 1 from catalog.product_aliases a
          where a.product_id = p.id
            and (a.alias_normalized like '%' || v_q || '%'
                 or similarity(a.alias_normalized, v_q) > 0.3)
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

comment on function catalog.search_products is
  'Unified product search. Normalizes Arabic, matches aliases, applies branch pricing, paginates.';

-- ---------------------------------------------------------------------------
-- Best sellers, computed from COMPLETED orders inside a period.
-- This replaces home_popular_section.dart:13 which just showed the whole
-- menu in array order.
-- ---------------------------------------------------------------------------
create or replace function catalog.get_best_sellers(
  p_branch_id uuid,
  p_period interval default '30 days',
  p_limit integer default 10
)
returns table (
  product_id uuid,
  name_ar text,
  name_en text,
  image_url text,
  units_sold bigint,
  revenue numeric
)
language sql
stable
security definer
set search_path = ''
as $fn$
  select oi.product_id,
         min(oi.product_name_ar),
         min(oi.product_name_en),
         min(oi.image_snapshot),
         sum(oi.quantity)::bigint,
         round(sum(oi.line_total), 2)
    from orders.order_items oi
    join orders.orders o on o.id = oi.order_id
   where o.status = 'completed'
     and o.placed_at >= now() - coalesce(p_period, '30 days'::interval)
     and (p_branch_id is null or o.branch_id = p_branch_id)
     and oi.product_id is not null
   group by oi.product_id
   order by sum(oi.quantity) desc, sum(oi.line_total) desc
   limit least(greatest(coalesce(p_limit, 10), 1), 50);
$fn$;

comment on function catalog.get_best_sellers is
  'Best sellers from completed orders in a period. Empty result is a valid answer, not an error.';

-- ---------------------------------------------------------------------------
-- Featured: manual is_featured override merged with the computed ranking,
-- with a clear precedence so the result is explainable.
-- ---------------------------------------------------------------------------
create or replace function catalog.get_featured(
  p_branch_id uuid,
  p_limit integer default 10
)
returns table (
  product_id uuid,
  name_ar text,
  name_en text,
  image_url text,
  effective_price numeric,
  source text
)
language plpgsql
stable
security definer
set search_path = ''
as $fn$
begin
  return query
  with manual as (
    select p.id, p.name_ar, p.name_en, p.image_url,
           coalesce(bpp.price_override, p.base_price) as price,
           'manual'::text as src
      from catalog.products p
      join catalog.branch_product_pricing bpp
        on bpp.product_id = p.id and bpp.branch_id = p_branch_id
     where p.is_featured and p.is_active and p.archived_at is null
       and bpp.is_featured and bpp.is_available
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
             on bpp.product_id = p.id and bpp.branch_id = p_branch_id
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
$fn$;

comment on function catalog.get_featured is
  'Featured products: manual is_featured first, then best sellers. source column explains each row.';