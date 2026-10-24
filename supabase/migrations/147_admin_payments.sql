-- 147_admin_payments.sql
create or replace function public.admin_payments()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('payments.read') then
    raise exception 'missing permission: payments.read' using errcode = '42501';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', t.id,
      'order_id', t.order_id,
      'order_number', o.order_number,
      'customer_name', p.full_name,
      'provider', t.provider,
      'provider_reference', t.provider_reference,
      'amount', t.amount,
      'currency_code', t.currency_code,
      'status', t.status,
      'paid_at', t.paid_at,
      'refunded_at', t.refunded_at,
      'card_brand', t.card_brand,
      'card_last4', t.card_last4,
      'card_holder_name', t.card_holder_name,
      'verified_by_server', t.verified_by_server,
      'created_at', t.created_at
    ) order by t.created_at desc)
    from payments.payment_transactions t
    left join orders.orders o on o.id = t.order_id
    left join identity.profiles p on p.id = o.user_id
  ), '[]'::jsonb);
end;
$fn$;

revoke all on function public.admin_payments() from public, anon;
grant execute on function public.admin_payments() to authenticated;
