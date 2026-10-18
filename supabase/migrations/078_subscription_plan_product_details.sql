-- 078_subscription_plan_product_details.sql
create or replace function subscriptions.plan_products_list(p_plan_id uuid)
returns table (
  product_id uuid,
  name_ar text,
  name_en text,
  image_url text,
  base_price numeric
)
language sql
stable
security definer
set search_path = ''
as $fn$
  select pr.id, pr.name_ar, pr.name_en, pr.image_url, pr.base_price
    from subscriptions.plan_products pp
    join catalog.products pr on pr.id = pp.product_id
   where pp.plan_id = p_plan_id
     and pr.is_active
   order by pr.name_en;
$fn$;

create or replace function public.subscription_plan_products(p_plan_id uuid)
returns table (
  product_id uuid,
  name_ar text,
  name_en text,
  image_url text,
  base_price numeric
)
language sql stable security invoker set search_path = ''
as $fn$ select * from subscriptions.plan_products_list(p_plan_id); $fn$;

grant execute on function public.subscription_plan_products(uuid) to anon, authenticated;
