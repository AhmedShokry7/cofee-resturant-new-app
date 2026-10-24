-- 159_admin_payment_status_update.sql
create or replace function public.admin_update_payment_status(
  p_order_id uuid,
  p_payment_status text
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
  if p_payment_status not in ('unpaid','pending','paid','failed','refunded') then
    raise exception 'invalid payment status' using errcode = '22023';
  end if;

  update orders.orders
     set payment_status = p_payment_status,
         updated_at = now()
   where id = p_order_id;
end;
$fn$;

revoke all on function public.admin_update_payment_status(uuid, text) from public, anon;
grant execute on function public.admin_update_payment_status(uuid, text) to authenticated;

notify pgrst, 'reload schema';