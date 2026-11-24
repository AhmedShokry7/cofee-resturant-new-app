-- Create and activate a paid customer subscription from the admin counter.
-- The staff member confirms that payment was received; the RPC atomically
-- records that counter payment, the subscription cycle, and the audit event.

insert into payments.payment_methods
  (code, name_ar, name_en, is_active, is_online, sort_order, requires_saved_card)
values
  ('pos', 'شبكة (نقطة البيع)', 'Card terminal (POS)', true, false, 5, false)
on conflict (code) do nothing;

create or replace function public.admin_subscription_customers(p_search text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_term text := nullif(btrim(left(coalesce(p_search, ''), 80)), '');
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('subscriptions.manage') then
    raise exception 'missing permission: subscriptions.manage' using errcode = '42501';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', matched.id,
      'full_name', matched.full_name,
      'email', matched.email,
      'phone', matched.phone
    ) order by matched.sort_rank, matched.full_name nulls last, matched.email)
    from (
      select p.id, p.full_name, p.email, p.phone,
        case when v_term is not null
          and coalesce(p.phone, '') ilike '%' || v_term || '%' then 0 else 1 end as sort_rank
      from identity.profiles p
      where not p.is_blacklisted
        and (v_term is null
          or coalesce(p.full_name, '') ilike '%' || v_term || '%'
          or coalesce(p.email, '') ilike '%' || v_term || '%'
          or coalesce(p.phone, '') ilike '%' || v_term || '%')
      order by sort_rank, p.full_name nulls last, p.email
      limit 20
    ) matched
  ), '[]'::jsonb);
end;
$fn$;

revoke all on function public.admin_subscription_customers(text) from public, anon;
grant execute on function public.admin_subscription_customers(text) to authenticated;

create or replace function public.admin_subscription_payment_methods()
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
      'id', m.id,
      'code', m.code,
      'name_ar', m.name_ar,
      'name_en', m.name_en
    ) order by m.sort_order, m.name_ar)
    from payments.payment_methods m
    where m.is_active
      and (m.code = 'cash' or (not m.is_online and not m.requires_saved_card))
  ), '[]'::jsonb);
end;
$fn$;

revoke all on function public.admin_subscription_payment_methods() from public, anon;
grant execute on function public.admin_subscription_payment_methods() to authenticated;

create or replace function public.admin_create_paid_subscription(
  p_user_id uuid,
  p_plan_id uuid,
  p_payment_method_id uuid,
  p_payment_confirmed boolean,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_uid uuid := auth.uid();
  v_plan subscriptions.plans%rowtype;
  v_method payments.payment_methods%rowtype;
  v_existing subscriptions.subscriptions%rowtype;
  v_previous subscriptions.subscriptions%rowtype;
  v_new uuid;
  v_reference text;
  v_start timestamptz := now();
  v_end timestamptz;
  v_carry integer := 0;
  v_unused integer;
begin
  if v_uid is null or not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('subscriptions.manage') then
    raise exception 'missing permission: subscriptions.manage' using errcode = '42501';
  end if;
  if p_user_id is null or p_plan_id is null
     or coalesce(btrim(p_idempotency_key), '') = '' then
    return jsonb_build_object('ok', false, 'reason', 'invalid_payload');
  end if;
  if char_length(p_idempotency_key) > 120 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_payload');
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_idempotency_key, 0));

  select * into v_existing
    from subscriptions.subscriptions
   where idempotency_key = p_idempotency_key
   for update;
  if found then
    if v_existing.user_id <> p_user_id or v_existing.plan_id <> p_plan_id
       or v_existing.status <> 'active' then
      return jsonb_build_object('ok', false, 'reason', 'idempotency_conflict');
    end if;
    return jsonb_build_object(
      'ok', true,
      'subscription_id', v_existing.id,
      'payment_reference', v_existing.payment_reference,
      'reused', true
    );
  end if;

  if not exists (
    select 1 from identity.profiles p
    where p.id = p_user_id and not p.is_blacklisted
  ) or exists (
    select 1 from identity.staff_members s where s.user_id = p_user_id
  ) then
    return jsonb_build_object('ok', false, 'reason', 'customer_unavailable');
  end if;

  select * into v_plan
    from subscriptions.plans
   where id = p_plan_id and is_active and is_for_sale
   for update;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'plan_unavailable');
  end if;

  if v_plan.price > 0 then
    if p_payment_confirmed is not true then
      return jsonb_build_object('ok', false, 'reason', 'payment_confirmation_required');
    end if;
    if p_payment_method_id is null then
      return jsonb_build_object('ok', false, 'reason', 'payment_method_required');
    end if;
    select * into v_method
      from payments.payment_methods
     where id = p_payment_method_id
       and is_active
       and (code = 'cash' or (not is_online and not requires_saved_card))
     for share;
    if not found then
      return jsonb_build_object('ok', false, 'reason', 'payment_method_unavailable');
    end if;
  end if;

  v_reference := p_idempotency_key;
  v_end := v_start + (v_plan.duration_days || ' days')::interval;

  -- Preserve the same one-time rollover rules as customer payment activation.
  select * into v_previous
    from subscriptions.subscriptions
   where user_id = p_user_id
     and rollover_applied = false
     and status in ('active', 'expired')
   order by ends_at desc nulls last
   limit 1
   for update;
  if found then
    v_unused := greatest(
      v_previous.cups_entitled + v_previous.cups_carried_over
        - v_previous.cups_used - v_previous.cups_reserved,
      0
    );
    v_carry := least(v_unused, v_plan.rollover_cap_cups);
    update subscriptions.subscriptions
       set status = 'expired', rollover_applied = true
     where id = v_previous.id;
  end if;

  insert into subscriptions.subscriptions (
    user_id, plan_id, status, starts_at, ends_at,
    cups_entitled, cups_used, cups_carried_over,
    bonus_balance, bonus_expires_at, auto_renew,
    payment_reference, idempotency_key, rollover_applied
  ) values (
    p_user_id, v_plan.id, 'active', v_start, v_end,
    v_plan.cups_per_cycle, 0, v_carry,
    case when v_plan.bonus_type = 'none' then 0 else v_plan.bonus_value end,
    case when v_plan.bonus_expires_with_cycle then v_end else null end,
    v_plan.renewal_policy = 'auto' and v_plan.auto_renew_supported,
    v_reference, p_idempotency_key, true
  ) returning id into v_new;

  if v_plan.price > 0 then
    insert into payments.payment_transactions (
      subscription_id, method_id, provider, provider_reference,
      amount, currency_code, status, paid_at, verified_by_server
    ) values (
      v_new, v_method.id, 'admin_counter', v_reference,
      v_plan.price, v_plan.currency_code, 'captured', v_start, true
    );
  else
    v_reference := 'admin-free:' || v_new::text;
    update subscriptions.subscriptions
       set payment_reference = v_reference
     where id = v_new;
  end if;

  insert into subscriptions.subscription_events
    (subscription_id, user_id, event_type, payload)
  values (
    v_new, p_user_id, 'activated_by_admin',
    jsonb_build_object(
      'plan_id', v_plan.id,
      'price', v_plan.price,
      'currency_code', v_plan.currency_code,
      'payment_method_id', case when v_plan.price > 0 then v_method.id else null end,
      'payment_reference', v_reference,
      'actor_user_id', v_uid,
      'carry', v_carry
    )
  );

  perform identity.audit(
    'subscription.create.admin',
    'subscription',
    v_new,
    null,
    jsonb_build_object(
      'customer_id', p_user_id,
      'plan_id', v_plan.id,
      'price', v_plan.price,
      'currency_code', v_plan.currency_code,
      'payment_method_id', case when v_plan.price > 0 then v_method.id else null end,
      'payment_reference', v_reference
    )
  );

  return jsonb_build_object(
    'ok', true,
    'subscription_id', v_new,
    'payment_reference', v_reference,
    'reused', false
  );
end;
$fn$;

revoke all on function public.admin_create_paid_subscription(uuid, uuid, uuid, boolean, text)
  from public, anon;
grant execute on function public.admin_create_paid_subscription(uuid, uuid, uuid, boolean, text)
  to authenticated;

-- Keep the registered payment-method label visible in subscription details.
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
  ), '[]'::jsonb);
end;
$fn$;

revoke all on function public.admin_subscriptions() from public, anon;
grant execute on function public.admin_subscriptions() to authenticated;

notify pgrst, 'reload schema';
