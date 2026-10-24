-- Fetch scope labels for many coupons in one request rather than one RPC per
-- coupon card. Keep the same public scope information as coupon_scope(text).
create or replace function public.coupon_scopes(p_codes text[])
returns table (
  coupon_code text,
  coupon_id uuid,
  applies_to text,
  scope_kind text,
  scope_id uuid,
  name_ar text,
  name_en text
)
language sql
stable
security definer
set search_path to ''
as $fn$
  with requested as (
    select distinct upper(btrim(code)) as code
      from unnest(coalesce(p_codes, array[]::text[])) as input(code)
     where nullif(btrim(code), '') is not null
  )
  select c.code, c.id, c.applies_to, 'category'::text, cat.id,
         cat.name_ar, cat.name_en
    from requested r
    join marketing.coupons c on c.code = r.code
    join marketing.coupons_categories cc on cc.coupon_id = c.id
    join catalog.categories cat on cat.id = cc.category_id
  union all
  select c.code, c.id, c.applies_to, 'product'::text, p.id,
         p.name_ar, p.name_en
    from requested r
    join marketing.coupons c on c.code = r.code
    join marketing.coupons_products cp on cp.coupon_id = c.id
    join catalog.products p on p.id = cp.product_id
   order by 1, 5;
$fn$;

comment on function public.coupon_scopes(text[]) is
  'Batch coupon scope lookup for lists; equivalent to coupon_scope(text) per code.';

revoke all on function public.coupon_scopes(text[]) from public;
grant execute on function public.coupon_scopes(text[])
  to anon, authenticated, service_role;

notify pgrst, 'reload schema';
