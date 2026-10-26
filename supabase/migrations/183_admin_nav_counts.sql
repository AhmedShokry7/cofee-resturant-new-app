-- 183_admin_nav_counts.sql
-- The live counters behind the sidebar badges.
--
-- The navigation panel tells the staff how much work is waiting without
-- opening a page: orders that still need confirmation, and kitchen tickets
-- that have not been started yet. Both counters are computed on the server so
-- the dashboard never downloads whole directories just to count them.
--
-- What counts as work:
--   * new orders     orders.orders with status 'pending'. A POS sale is born
--                    'confirmed' and paid at the counter, so it belongs to the
--                    kitchen queue instead of waiting for a confirmation.
--   * kitchen queue  kitchen.tickets with status 'queued'.
--
-- Both counters are limited to the branches the caller may manage, exactly
-- like the kitchen board. A counter the caller cannot act on is not shown.

create or replace function public.admin_nav_counts()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_new_orders    integer := 0;
  v_kitchen_queue integer := 0;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  if identity.has_permission('orders.read') then
    select count(*) into v_new_orders
      from orders.orders o
     where o.status = 'pending'
       and identity.can_manage_branch(o.branch_id);
  end if;

  if identity.has_permission('kitchen.read') then
    select count(*) into v_kitchen_queue
      from kitchen.tickets t
     where t.status = 'queued'
       and identity.can_manage_branch(t.branch_id);
  end if;

  return jsonb_build_object(
    'new_orders', v_new_orders,
    'kitchen_queue', v_kitchen_queue
  );
end;
$fn$;

comment on function public.admin_nav_counts() is
  'Pending orders and queued kitchen tickets in the branches the caller can manage.';

revoke all on function public.admin_nav_counts() from public, anon;
grant execute on function public.admin_nav_counts() to authenticated;
