-- Retain subscription/payment/usage history while removing a subscription from
-- the admin directory. Active subscriptions are stopped before they are hidden.
alter table subscriptions.subscriptions
  add column if not exists admin_removed_at timestamptz;

create or replace function public.admin_remove_subscription(p_subscription_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_subscription subscriptions.subscriptions%rowtype;
  v_actor uuid := auth.uid();
  v_old jsonb;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('subscriptions.manage') then
    raise exception 'missing permission: subscriptions.manage' using errcode = '42501';
  end if;

  select * into v_subscription
    from subscriptions.subscriptions
   where id = p_subscription_id
   for update;

  if not found then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;
  if v_subscription.admin_removed_at is not null then
    return jsonb_build_object('ok', true, 'already_removed', true);
  end if;
  if v_subscription.cups_reserved > 0 then
    return jsonb_build_object('ok', false, 'reason', 'reserved_cups');
  end if;

  v_old := jsonb_build_object(
    'status', v_subscription.status,
    'admin_removed_at', v_subscription.admin_removed_at,
    'auto_renew', v_subscription.auto_renew
  );

  update subscriptions.subscriptions
     set admin_removed_at = now(),
         status = case when status in ('active', 'pending_payment')
                       then 'cancelled' else status end,
         auto_renew = false,
         ends_at = case when status in ('active', 'pending_payment')
                        then least(coalesce(ends_at, now()), now())
                        else ends_at end
   where id = v_subscription.id;

  insert into subscriptions.subscription_events
    (subscription_id, user_id, event_type, payload)
  values (
    v_subscription.id,
    v_subscription.user_id,
    'removed_from_admin',
    jsonb_build_object(
      'actor_user_id', v_actor,
      'previous_status', v_subscription.status,
      'payment_refunded', false
    )
  );

  perform identity.audit(
    'subscription.remove',
    'subscription',
    v_subscription.id,
    v_old,
    jsonb_build_object(
      'admin_removed_at', now(),
      'status', case when v_subscription.status in ('active', 'pending_payment')
                     then 'cancelled' else v_subscription.status end,
      'payment_refunded', false
    )
  );

  return jsonb_build_object('ok', true);
end;
$fn$;

revoke all on function public.admin_remove_subscription(uuid) from public, anon;
grant execute on function public.admin_remove_subscription(uuid) to authenticated;

-- Keep the existing staff/permission checks and projection intact, while
-- excluding only records deliberately hidden by this administrative action.
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
      'customer_phone', p.phone,
      'avatar_url', p.avatar_url,
      'plan_id', s.plan_id,
      'plan_code', pl.code,
      'plan_name_ar', pl.name_ar,
      'plan_name_en', pl.name_en,
      'plan_price', pl.price,
      'currency_code', pl.currency_code,
      'plan_duration_days', pl.duration_days,
      'status', case
        when s.status = 'active' and s.ends_at is not null and s.ends_at <= now()
          then 'expired'
        else s.status
      end,
      'starts_at', s.starts_at,
      'ends_at', s.ends_at,
      'bonus_expires_at', s.bonus_expires_at,
      'cups_entitled', s.cups_entitled,
      'cups_used', s.cups_used,
      'cups_carried_over', s.cups_carried_over,
      'cups_reserved', s.cups_reserved,
      'bonus_balance', s.bonus_balance,
      'auto_renew', s.auto_renew,
      'payment_reference', s.payment_reference,
      'payment_method_code', paid.method_code,
      'payment_method_name_ar', paid.method_name_ar,
      'payment_method_name_en', paid.method_name_en,
      'created_at', s.created_at,
      'usage_count', coalesce(u.usage_count, 0),
      'last_used_at', u.last_used_at
    ) order by s.created_at desc)
    from subscriptions.subscriptions s
    left join identity.profiles p on p.id = s.user_id
    left join subscriptions.plans pl on pl.id = s.plan_id
    left join lateral (
      select count(*)::int as usage_count, max(usage.created_at) as last_used_at
      from subscriptions.subscription_usage usage
      where usage.subscription_id = s.id
    ) u on true
    left join lateral (
      select m.code as method_code, m.name_ar as method_name_ar,
             m.name_en as method_name_en
      from payments.payment_transactions t
      left join payments.payment_methods m on m.id = t.method_id
      where t.subscription_id = s.id
      order by t.created_at desc
      limit 1
    ) paid on true
    where s.admin_removed_at is null
  ), '[]'::jsonb);
end;
$fn$;

revoke all on function public.admin_subscriptions() from public, anon;
grant execute on function public.admin_subscriptions() to authenticated;

notify pgrst, 'reload schema';
