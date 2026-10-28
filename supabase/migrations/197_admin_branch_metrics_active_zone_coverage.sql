-- 197_admin_branch_metrics_active_zone_coverage.sql
--
-- Closes decision D2 of supabase/proposals/196_body_drift_owner_decisions.PROPOSED.sql.
--
-- The live public.admin_branch_metrics lost two lines of the zones_covered
-- sub-select that 171 wrote:
--
--     join core.branches b on b.id = dzb.branch_id
--     … and b.is_active
--
-- so the branches dashboard counted a delivery zone as covered even when every
-- branch attached to it is closed. The rest of the function still narrows on
-- active (dz.is_active, the 'active'/'without_location' filters), which is what
-- makes the omission a drift rather than a different definition.
--
-- This file replays the 171 body verbatim. It is a read-only dashboard metric:
-- no write path, no invoice and no permission depends on it. The only visible
-- effect is that zones_covered can go down when a zone is attached only to
-- inactive branches.

create or replace function public.admin_branch_metrics()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('settings.write') then
    raise exception 'missing permission: settings.write' using errcode = '42501';
  end if;

  return (
    select jsonb_build_object(
      'total', count(*),
      'active', count(*) filter (where b.is_active),
      'inactive', count(*) filter (where not b.is_active),
      'without_location', count(*) filter (
        where b.latitude is null or b.longitude is null
      ),
      'zones_covered', (
        select count(distinct dzb.zone_id)
          from core.delivery_zone_branches dzb
          join core.delivery_zones dz on dz.id = dzb.zone_id
          join core.branches b on b.id = dzb.branch_id
         where dz.is_active
           and b.is_active
      ),
      'orders_30d', (
        select count(*)
          from orders.orders o
         where o.status <> 'cancelled'
           and o.placed_at >= now() - interval '30 days'
      ),
      'staff_assigned', (
        select count(distinct sr.staff_id)
          from identity.staff_roles sr
          join identity.staff_members sm on sm.id = sr.staff_id
         where sr.branch_id is not null
           and sm.status = 'active'
      )
    )
    from core.branches b
  );
end;
$fn$;

comment on function public.admin_branch_metrics is
  'Branch counts, active delivery coverage and 30-day order volume.';

revoke all on function public.admin_branch_metrics() from public, anon;
grant execute on function public.admin_branch_metrics() to authenticated;

notify pgrst, 'reload schema';
