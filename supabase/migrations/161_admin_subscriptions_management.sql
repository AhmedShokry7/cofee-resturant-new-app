-- 161_admin_subscriptions_management.sql
-- Large-app subscription administration: effective status, customer contact,
-- usage history and a guarded admin cancellation entry point.

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
      'plan_id', s.plan_id,
      'plan_code', pl.code,
      'plan_name_ar', pl.name_ar,
      'plan_name_en', pl.name_en,
      'plan_price', pl.price,
      'currency_code', pl.currency_code,
      'plan_duration_days', pl.duration_days,
      'status', case
        when s.status = 'active'
          and s.ends_at is not null
          and s.ends_at <= now() then 'expired'
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
      'created_at', s.created_at,
      'usage_count', coalesce(u.usage_count, 0),
      'last_used_at', u.last_used_at
    ) order by s.created_at desc)
    from subscriptions.subscriptions s
    left join identity.profiles p on p.id = s.user_id
    left join subscriptions.plans pl on pl.id = s.plan_id
    left join lateral (
      select
        count(*)::int as usage_count,
        max(usage.created_at) as last_used_at
      from subscriptions.subscription_usage usage
      where usage.subscription_id = s.id
    ) u on true
  ), '[]'::jsonb);
end;
$fn$;

revoke all on function public.admin_subscriptions() from public, anon;
grant execute on function public.admin_subscriptions() to authenticated;

create or replace function public.admin_subscription_usage(p_subscription_id uuid)
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
    select jsonb_agg(row_data order by created_at desc)
    from (
      select
        jsonb_build_object(
          'id', usage.id,
          'quantity', usage.quantity,
          'method', usage.method,
          'created_at', usage.created_at,
          'branch_name_ar', b.name_ar,
          'branch_name_en', b.name_en,
          'product_name_ar', pr.name_ar,
          'product_name_en', pr.name_en,
          'order_id', usage.order_id,
          'order_number', o.order_number
        ) as row_data,
        usage.created_at
      from subscriptions.subscription_usage usage
      left join core.branches b on b.id = usage.branch_id
      left join catalog.products pr on pr.id = usage.product_id
      left join orders.orders o on o.id = usage.order_id
      where usage.subscription_id = p_subscription_id
      order by usage.created_at desc
      limit 100
    ) usage_rows
  ), '[]'::jsonb);
end;
$fn$;

revoke all on function public.admin_subscription_usage(uuid) from public, anon;
grant execute on function public.admin_subscription_usage(uuid) to authenticated;

create or replace function public.admin_cancel_subscription(p_subscription_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_subscription subscriptions.subscriptions%rowtype;
  v_actor uuid := auth.uid();
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
  if v_subscription.status not in ('active', 'pending_payment')
     or (
       v_subscription.status = 'active'
       and v_subscription.ends_at is not null
       and v_subscription.ends_at <= now()
     ) then
    return jsonb_build_object('ok', false, 'reason', 'not_cancellable');
  end if;
  if v_subscription.cups_reserved > 0 then
    return jsonb_build_object('ok', false, 'reason', 'reserved_cups');
  end if;

  update subscriptions.subscriptions
     set status = 'cancelled',
         auto_renew = false,
         ends_at = least(coalesce(ends_at, now()), now())
   where id = v_subscription.id;

  insert into subscriptions.subscription_events
    (subscription_id, user_id, event_type, payload)
  values
    (v_subscription.id, v_subscription.user_id, 'cancelled_by_admin',
     jsonb_build_object('actor', v_actor));

  return jsonb_build_object('ok', true);
end;
$fn$;

revoke all on function public.admin_cancel_subscription(uuid) from public, anon;
grant execute on function public.admin_cancel_subscription(uuid) to authenticated;

-- The customer dialog already renders a subscriptions section when the details
-- payload contains one, so return the customer's latest subscriptions there.
create or replace function public.admin_customer_details(p_customer_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('customers.read') then
    raise exception 'missing permission: customers.read' using errcode = '42501';
  end if;

  return (
    select jsonb_build_object(
      'profile', jsonb_build_object(
        'id', p.id,
        'full_name', p.full_name,
        'email', p.email,
        'phone', p.phone,
        'avatar_url', p.avatar_url,
        'language', p.language,
        'last_seen_at', p.last_seen_at,
        'created_at', p.created_at,
        'updated_at', p.updated_at,
        'is_vip', p.is_vip,
        'is_blacklisted', p.is_blacklisted,
        'admin_notes', p.admin_notes
      ),
      'addresses', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', a.id,
          'label', a.label,
          'details', a.details,
          'is_default', a.is_default
        ) order by a.created_at)
        from identity.customer_addresses a
        where a.user_id = p.id and a.archived_at is null
      ), '[]'::jsonb),
      'orders', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', o.id,
          'branch_id', o.branch_id,
          'status', o.status,
          'grand_total', o.grand_total,
          'placed_at', o.placed_at,
          'items', coalesce((
            select jsonb_agg(jsonb_build_object(
              'product_name_ar', pr2.name_ar,
              'product_name_en', pr2.name_en,
              'quantity', oi.quantity,
              'unit_price', oi.unit_price,
              'line_total', oi.line_total
            ) order by oi.id)
            from orders.order_items oi
            left join catalog.products pr2 on pr2.id = oi.product_id
            where oi.order_id = o.id
          ), '[]'::jsonb)
        ) order by o.placed_at desc)
        from orders.orders o
        where o.user_id = p.id
      ), '[]'::jsonb),
      'subscriptions', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', recent.id,
          'status', case
            when recent.status = 'active'
              and recent.ends_at is not null
              and recent.ends_at <= now() then 'expired'
            else recent.status
          end,
          'starts_at', recent.starts_at,
          'ends_at', recent.ends_at,
          'cups_entitled', recent.cups_entitled,
          'cups_used', recent.cups_used,
          'cups_carried_over', recent.cups_carried_over,
          'cups_reserved', recent.cups_reserved,
          'auto_renew', recent.auto_renew,
          'plan', jsonb_build_object(
            'name_ar', pl.name_ar,
            'name_en', pl.name_en
          )
        ) order by recent.created_at desc)
        from (
          select sub.*
            from subscriptions.subscriptions sub
           where sub.user_id = p.id
           order by sub.created_at desc
           limit 20
        ) recent
        left join subscriptions.plans pl on pl.id = recent.plan_id
      ), '[]'::jsonb)
    )
    from identity.profiles p
    where p.id = p_customer_id
  );
end;
$fn$;

revoke all on function public.admin_customer_details(uuid) from public, anon;
grant execute on function public.admin_customer_details(uuid) to authenticated;
