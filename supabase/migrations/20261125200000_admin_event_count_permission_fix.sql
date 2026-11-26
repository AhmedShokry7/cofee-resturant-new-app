begin;

create or replace function public.admin_nav_counts()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_unread_orders integer := 0;
  v_unread_kitchen integer := 0;
  v_event_requests integer := 0;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  if identity.has_permission('orders.read') then
    select count(*) into v_unread_orders
      from orders.orders o
     where o.status = 'pending'
       and o.viewed_at is null
       and identity.can_manage_branch(o.branch_id);
  end if;

  if identity.has_permission('kitchen.read') then
    select count(*) into v_unread_kitchen
      from kitchen.tickets t
     where t.status in ('queued', 'preparing', 'ready')
       and t.viewed_at is null
       and identity.can_manage_branch(t.branch_id);
  end if;

  if identity.has_permission('tables.read')
     or identity.has_permission('tables.manage') then
    select count(*) into v_event_requests
      from floor.customer_event_requests e
     where e.status in ('pending', 'quote_declined')
       and identity.can_manage_branch(e.branch_id);
  end if;

  return jsonb_build_object(
    'unread_orders', v_unread_orders,
    'unread_kitchen', v_unread_kitchen,
    'event_requests', v_event_requests
  );
end;
$fn$;

comment on function public.admin_nav_counts() is
  'Counts unread orders and kitchen tickets, plus customer event requests awaiting branch review in the caller scope.';

revoke all on function public.admin_nav_counts() from public, anon;
grant execute on function public.admin_nav_counts() to authenticated;

commit;
