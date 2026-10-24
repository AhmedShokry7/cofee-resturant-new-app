-- 145_admin_order_status_update.sql
create or replace function public.admin_update_order_status(
  p_order_id uuid,
  p_status text
)
returns void
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('orders.status.update') then
    raise exception 'missing permission: orders.status.update' using errcode = '42501';
  end if;
  if p_status not in ('pending','confirmed','preparing','ready','out_for_delivery','completed','cancelled') then
    raise exception 'invalid status' using errcode = '22023';
  end if;

  update orders.orders
     set status = p_status,
         completed_at = case when p_status = 'completed' then now() else completed_at end,
         cancelled_at = case when p_status = 'cancelled' then now() else cancelled_at end,
         updated_at = now()
   where id = p_order_id;
end;
$fn$;

revoke all on function public.admin_update_order_status(uuid, text) from public, anon;
grant execute on function public.admin_update_order_status(uuid, text) to authenticated;
