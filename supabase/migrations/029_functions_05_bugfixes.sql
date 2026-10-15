-- 029_functions_05_bugfixes.sql
--
-- Two defects found by running the acceptance suite as a real `authenticated`
-- session. Both are runtime failures, not caught by DDL.
--
-- BUG 1 -- catalog.search_products
--   similarity(text,text) is provided by pg_trgm, which Supabase installs into
--   the `extensions` schema. Because every SECURITY DEFINER function here pins
--   search_path = '', the unqualified call could not be resolved:
--       42883 function similarity(text, text) does not exist
--   Fix: qualify as extensions.similarity().
--
-- BUG 2 -- orders.upsert_cart_item
--   RETURNS TABLE declares an OUT parameter named cart_item_id, which then
--   collides with the cart_item_options.cart_item_id column inside plpgsql:
--       42702 column reference "cart_item_id" is ambiguous
--   Fix: qualify the column reference. The OUT parameter names are kept
--   unchanged so the client contract is stable.

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

-- ---------------------------------------------------------------------------
create or replace function orders.upsert_cart_item(
  p_branch_id       uuid,
  p_product_id      uuid,
  p_quantity        integer default 1,
  p_note            text default '',
  p_option_value_ids uuid[] default '{}'
)
returns table (
  cart_item_id uuid,
  unit_price   numeric,
  line_total   numeric,
  item_count   integer
)
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_uid    uuid := auth.uid();
  v_cart   uuid;
  v_price  numeric;
  v_avail  boolean;
  v_reason text;
  v_item   uuid;
  v_line   numeric;
  v_count  integer;
begin
  if v_uid is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if p_quantity is null or p_quantity < 1 then
    raise exception 'quantity must be at least 1' using errcode = '23514';
  end if;

  select r.unit_price, r.is_available, r.unavailable_reason
    into v_price, v_avail, v_reason
    from catalog.resolve_effective_price(p_branch_id, p_product_id, p_option_value_ids) r;

  if not v_avail then
    raise exception 'product % is not available at this branch: %',
      p_product_id, coalesce(v_reason, 'unavailable') using errcode = '23514';
  end if;

  v_cart := orders.get_or_create_cart(p_branch_id);

  insert into orders.cart_items (cart_id, product_id, quantity, note, unit_price, line_total)
  values (v_cart, p_product_id, least(p_quantity, 99), coalesce(p_note, ''),
          v_price, round(v_price * least(p_quantity, 99), 2))
  on conflict (cart_id, product_id, note) do update
    set quantity = least(orders.cart_items.quantity + excluded.quantity, 99),
        unit_price = excluded.unit_price,
        line_total = round(excluded.unit_price *
                           least(orders.cart_items.quantity + excluded.quantity, 99), 2)
  returning orders.cart_items.id into v_item;

  -- qualify: the OUT parameter is also called cart_item_id
  delete from orders.cart_item_options
   where orders.cart_item_options.cart_item_id = v_item;

  insert into orders.cart_item_options
    (cart_item_id, option_value_id, option_name_ar, option_name_en, price_delta)
  select v_item, ov.id, ov.name_ar, ov.name_en, ov.price_delta
    from catalog.option_values ov
   where ov.id = any(p_option_value_ids);

  select ci.unit_price, ci.line_total into v_price, v_line
    from orders.cart_items ci where ci.id = v_item;

  select coalesce(sum(ci.quantity), 0)::integer into v_count
    from orders.cart_items ci where ci.cart_id = v_cart;

  return query select v_item, v_price, v_line, v_count;
end;
$fn$;

-- ---------------------------------------------------------------------------
-- Same ambiguity class, checked across the whole SECURITY DEFINER surface.
-- These two are rewritten only if the pattern is actually present.
-- ---------------------------------------------------------------------------
do $$
declare
  v_bad text;
begin
  select string_agg(x, ', ') into v_bad
  from (
    select p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')' as x
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
     where n.nspname in ('identity','core','catalog','orders','inventory',
                         'loyalty','marketing','engagement')
       and p.prorettype = 'record'::regtype
       and pg_get_functiondef(p.oid) ~
           'where [a-z_]+ = (v_|p_|[a-z_]+;)'
  ) t;
  if v_bad is not null then
    raise notice 'functions with a bare column in WHERE worth reviewing: %', v_bad;
  end if;
end $$;