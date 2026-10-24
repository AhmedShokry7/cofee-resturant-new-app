-- 150_admin_subscriptions.sql
create or replace function public.admin_subscriptions()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('subscriptions.manage') then
    raise exception 'missing permission: subscriptions.manage' using errcode = '42501';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', s.id,
      'user_id', s.user_id,
      'customer_name', p.full_name,
      'customer_email', p.email,
      'plan_id', s.plan_id,
      'plan_name_ar', pl.name_ar,
      'plan_name_en', pl.name_en,
      'plan_price', pl.price,
      'currency_code', pl.currency_code,
      'status', s.status,
      'starts_at', s.starts_at,
      'ends_at', s.ends_at,
      'cups_entitled', s.cups_entitled,
      'cups_used', s.cups_used,
      'cups_carried_over', s.cups_carried_over,
      'cups_reserved', s.cups_reserved,
      'bonus_balance', s.bonus_balance,
      'auto_renew', s.auto_renew,
      'payment_reference', s.payment_reference,
      'created_at', s.created_at
    ) order by s.created_at desc)
    from subscriptions.subscriptions s
    left join identity.profiles p on p.id = s.user_id
    left join subscriptions.plans pl on pl.id = s.plan_id
  ), '[]'::jsonb);
end;
$fn$;

revoke all on function public.admin_subscriptions() from public, anon;
grant execute on function public.admin_subscriptions() to authenticated;
