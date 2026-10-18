-- 077_subscription_plan_images.sql
alter table subscriptions.plans
  add column if not exists image_url text;

update subscriptions.plans
   set image_url = coalesce(image_url, 'assets/images/product.png');

-- Recreate list function with image_url.
drop function if exists public.list_subscription_plans(uuid);
drop function if exists subscriptions.list_plans(uuid);

create or replace function subscriptions.list_plans(p_branch_id uuid default null)
returns table (
  id uuid, code text, name_ar text, name_en text, description_ar text, description_en text,
  price numeric, currency_code text, duration_days integer, cups_per_cycle integer,
  bonus_type text, bonus_value numeric, bonus_expires_with_cycle boolean,
  rollover_cap_cups integer, renewal_policy text, auto_renew_supported boolean,
  all_branches boolean, product_scope text, is_active boolean, is_for_sale boolean,
  image_url text
)
language sql
stable
security definer
set search_path = ''
as $fn$
  select p.id, p.code, p.name_ar, p.name_en, p.description_ar, p.description_en,
         p.price, p.currency_code, p.duration_days, p.cups_per_cycle,
         p.bonus_type, p.bonus_value, p.bonus_expires_with_cycle,
         p.rollover_cap_cups, p.renewal_policy, p.auto_renew_supported,
         p.all_branches, p.product_scope, p.is_active, p.is_for_sale,
         p.image_url
    from subscriptions.plans p
   where p.is_active and p.is_for_sale
     and (p.all_branches or p_branch_id is null or exists (
           select 1 from subscriptions.plan_branches pb
            where pb.plan_id = p.id and pb.branch_id = p_branch_id))
   order by p.price;
$fn$;

create or replace function public.list_subscription_plans(p_branch_id uuid default null)
returns table (
  id uuid, code text, name_ar text, name_en text, description_ar text, description_en text,
  price numeric, currency_code text, duration_days integer, cups_per_cycle integer,
  bonus_type text, bonus_value numeric, bonus_expires_with_cycle boolean,
  rollover_cap_cups integer, renewal_policy text, auto_renew_supported boolean,
  all_branches boolean, product_scope text, is_active boolean, is_for_sale boolean,
  image_url text
)
language sql stable security invoker set search_path = ''
as $fn$ select * from subscriptions.list_plans(p_branch_id); $fn$;
