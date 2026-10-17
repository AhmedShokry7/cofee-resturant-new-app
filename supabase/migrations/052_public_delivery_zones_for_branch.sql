-- 052_public_delivery_zones_for_branch.sql
--
-- Problem 5 (delivery): the checkout needs to show the delivery zones the
-- selected branch actually serves, with their fee and minimum order. The
-- `public` bridge already exposes `public.delivery_zones` but not the
-- `delivery_zone_branches` linkage, so the client cannot filter by branch.
--
-- This adds a read-only bridge RPC that returns the active zones joined to the
-- requested branch. It is SECURITY INVOKER (the base tables already allow
-- public read via RLS), stable, and exposes no write path.

create function public.delivery_zones_for_branch(p_branch_id uuid)
returns table (
  id uuid,
  name_ar text,
  name_en text,
  delivery_fee numeric,
  min_order_amount numeric,
  estimated_minutes integer
)
language sql
stable
set search_path = ''
as $fn$
  select dz.id, dz.name_ar, dz.name_en, dz.delivery_fee,
         dz.min_order_amount, dz.estimated_minutes
    from core.delivery_zones dz
    join core.delivery_zone_branches dzb on dzb.zone_id = dz.id
   where dzb.branch_id = p_branch_id
     and dz.is_active
   order by dz.delivery_fee, dz.name_en;
$fn$;

-- `public` carries a default ACL that grants `anon`, so grant explicitly and
-- drop the implicit PUBLIC grant to keep the surface intentional.
revoke all on function public.delivery_zones_for_branch(uuid) from public;
grant execute on function public.delivery_zones_for_branch(uuid)
  to anon, authenticated, service_role;
