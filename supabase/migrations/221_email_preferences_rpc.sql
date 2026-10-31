-- supabase/migrations/221_email_preferences_rpc.sql
--
-- WHY THIS EXISTS
--
-- 219 gave the mail channel its column, its log and its trigger, and 220 made
-- the unsubscribe reachable. What is still missing is the customer's own door:
-- `public.set_push_preferences` takes five switches and no `p_email_enabled`, so
-- no customer can turn mail on and the admin panel can never mail anybody. The
-- column exists, the send-email function honours it (verified against
-- production: `skipped / email_disabled` when it is false), but nothing writes
-- it. This file opens that door and makes the panel see the channel.
--
-- WHAT CHANGES
--
--   1. set_push_preferences grows a sixth, nullable switch. The old five-argument
--      function is dropped rather than left beside it: two overloads of the same
--      name would make an unqualified call ambiguous for the REST layer. A build
--      that still sends five keys keeps working, because the new argument
--      defaults to null, which means "leave what the server holds".
--   2. push_preferences answers the missing row with email_enabled false, the
--      same way it already answers push_enabled false. A customer who never
--      opened a switch is not mailed, and is not asked about it by the server.
--   3. admin_notification_metrics counts the mail channel next to the push one,
--      so the panel shows who can be mailed before a campaign is sent rather
--      than after it silently delivered nothing.

-- ---------------------------------------------------------------------------
-- 1. The customer writes the mail switch through the same door as the others
-- ---------------------------------------------------------------------------
drop function if exists public.set_push_preferences(
  boolean, boolean, boolean, boolean, boolean);

create function public.set_push_preferences(
  p_push_enabled boolean default null,
  p_email_enabled boolean default null,
  p_order_status boolean default null,
  p_promo boolean default null,
  p_loyalty boolean default null,
  p_system boolean default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if auth.uid() is null then
    raise exception 'Not signed in.' using errcode = '28000';
  end if;

  insert into engagement.notification_preferences
    (user_id, order_status, promo, loyalty, system, push_enabled, email_enabled,
     updated_at)
  values
    (auth.uid(),
     coalesce(p_order_status, true),
     coalesce(p_promo, true),
     coalesce(p_loyalty, true),
     coalesce(p_system, true),
     coalesce(p_push_enabled, false),
     coalesce(p_email_enabled, false),
     now())
  on conflict (user_id) do update
    set order_status = coalesce(p_order_status, engagement.notification_preferences.order_status),
        promo        = coalesce(p_promo, engagement.notification_preferences.promo),
        loyalty      = coalesce(p_loyalty, engagement.notification_preferences.loyalty),
        system       = coalesce(p_system, engagement.notification_preferences.system),
        push_enabled = coalesce(p_push_enabled, engagement.notification_preferences.push_enabled),
        email_enabled = coalesce(p_email_enabled, engagement.notification_preferences.email_enabled),
        updated_at   = now();

  return public.push_preferences();
end;
$fn$;

comment on function public.set_push_preferences(boolean, boolean, boolean, boolean, boolean, boolean) is
  'Writes the push and mail switches of the signed-in customer. A null argument leaves that switch as the server holds it.';

revoke all on function public.set_push_preferences(
  boolean, boolean, boolean, boolean, boolean, boolean) from public, anon;
grant execute on function public.set_push_preferences(
  boolean, boolean, boolean, boolean, boolean, boolean)
  to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 2. The read carries the mail gate for a customer with no row yet
-- ---------------------------------------------------------------------------
create or replace function public.push_preferences()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_row jsonb;
begin
  select to_jsonb(p) into v_row
    from engagement.notification_preferences p
   where p.user_id = auth.uid();

  if v_row is null then
    return jsonb_build_object(
      'user_id',       auth.uid(),
      'order_status',  true,
      'promo',         true,
      'loyalty',       true,
      'system',        true,
      'push_enabled',  false,
      'email_enabled', false,
      'updated_at',    null
    );
  end if;
  return v_row;
end;
$fn$;

comment on function public.push_preferences() is
  'The switches of the signed-in customer, or the default row: both channels off, every type on.';

revoke all on function public.push_preferences() from public, anon;
grant execute on function public.push_preferences() to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 3. The panel sees the mail channel before it sends into it
-- ---------------------------------------------------------------------------
create or replace function public.admin_notification_metrics()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_result jsonb;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('notifications.read') then
    raise exception 'missing permission: notifications.read' using errcode = '42501';
  end if;

  select jsonb_build_object(
    'total',            count(*),
    'unread',           count(*) filter (where not n.is_read),
    'today',            count(*) filter (where n.created_at >= date_trunc('day', now())),
    'this_month',       count(*) filter (where n.created_at >= date_trunc('month', now())),
    'admin_sent',       count(*) filter (where n.campaign_id is not null),
    'admin_sent_month', count(*) filter (
                          where n.campaign_id is not null
                            and n.created_at >= date_trunc('month', now())),
    'campaigns',        count(distinct n.campaign_id) filter (where n.campaign_id is not null),
    'by_type', jsonb_build_object(
      'order_status', count(*) filter (where n.type = 'order_status'),
      'promo',        count(*) filter (where n.type = 'promo'),
      'system',       count(*) filter (where n.type = 'system'),
      'loyalty',      count(*) filter (where n.type = 'loyalty'),
      'subscription', count(*) filter (where n.type = 'subscription')
    )
  )
  into v_result
  from engagement.notifications n;

  return v_result || jsonb_build_object(
    'customers_total',
      (select count(*) from identity.profiles),
    'push_enabled_customers',
      (select count(*) from engagement.notification_preferences where push_enabled),
    'reachable_customers',
      (select count(*)
         from identity.profiles p
         join engagement.notification_preferences pref on pref.user_id = p.id
        where pref.push_enabled
          and exists (select 1 from engagement.device_tokens t where t.user_id = p.id)),
    'devices_total',
      (select count(*) from engagement.device_tokens),
    'push', (
      select jsonb_build_object(
        'sent',          count(*) filter (where d.status = 'sent'),
        'failed',        count(*) filter (where d.status = 'failed'),
        'skipped',       count(*) filter (where d.status = 'skipped'),
        'invalid_token', count(*) filter (where d.status = 'invalid_token')
      )
        from engagement.push_deliveries d
       where d.created_at >= now() - interval '30 days'
    ),
    'push_success_rate', (
      select case
               when count(*) filter (where d.status in ('sent','failed','invalid_token')) = 0
                 then null
               else round(
                 100.0 * count(*) filter (where d.status = 'sent')
                 / count(*) filter (where d.status in ('sent','failed','invalid_token')),
                 1)
             end
      from engagement.push_deliveries d
      where d.created_at >= now() - interval '30 days'
    ),
    'email_enabled_customers',
      (select count(*) from engagement.notification_preferences where email_enabled),
    'emailable_customers',
      (select count(*)
         from identity.profiles p
         join engagement.notification_preferences pref on pref.user_id = p.id
        where pref.email_enabled
          and nullif(trim(p.email), '') is not null),
    'email', (
      select jsonb_build_object(
        'sent',    count(*) filter (where d.status = 'sent'),
        'failed',  count(*) filter (where d.status = 'failed'),
        'skipped', count(*) filter (where d.status = 'skipped'),
        'last_error', (
          select e.error from engagement.email_deliveries e
           where e.status = 'failed'
           order by e.created_at desc limit 1
        )
      )
        from engagement.email_deliveries d
       where d.created_at >= now() - interval '30 days'
    ),
    'email_success_rate', (
      select case
               when count(*) filter (where d.status in ('sent','failed')) = 0
                 then null
               else round(
                 100.0 * count(*) filter (where d.status = 'sent')
                 / count(*) filter (where d.status in ('sent','failed')),
                 1)
             end
      from engagement.email_deliveries d
      where d.created_at >= now() - interval '30 days'
    )
  );
end;
$fn$;

comment on function public.admin_notification_metrics() is
  'Counters of the notifications screen, for both channels: push reaches a device token, mail reaches an opted-in address.';

revoke all on function public.admin_notification_metrics() from public, anon;
grant execute on function public.admin_notification_metrics()
  to authenticated, service_role;

-- The REST layer caches function signatures, so the new sixth argument stays
-- invisible to the app until the schema cache is reloaded.
select pg_notify('pgrst', 'reload schema');
