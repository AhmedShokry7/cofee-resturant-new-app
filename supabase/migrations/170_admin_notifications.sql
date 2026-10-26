-- 170_admin_notifications.sql
-- Admin notification centre on top of engagement.notifications.
--
-- What the dashboard needs and the schema did not have:
--
--   1. a campaign row, so one composed message can be recognised as one
--      send and audited as one action instead of N unrelated rows;
--   2. a directory that joins the customer, the campaign and the push
--      delivery log, with server-side search, filters and paging;
--   3. headline metrics and a push health report that names the missing
--      configuration instead of leaving "no push arrived" unexplained;
--   4. compose, resend, read and delete functions, each behind its own
--      permission and each writing an audit row.
--
-- The push chain of 097/098/099/100/104 is repeated here because that chain
-- could not be applied from scratch: 097 collided with 097_ai_learned_answers,
-- so 098 and 099 ran against a database without engagement.push_deliveries
-- and aborted. Every statement below is idempotent, so an environment that
-- already has the objects is left unchanged.
--
-- Push health, in one paragraph
-- ------------------------------
-- A push needs four things: the pg_net extension (it queues the request), the
-- Vault secret push_webhook_secret (the trigger authenticates with it), the
-- app setting push_function_url (where the request goes) and the Edge Function
-- secrets PUSH_WEBHOOK_SECRET (must equal the Vault secret) and
-- FIREBASE_SERVICE_ACCOUNT (the Firebase service account key). The database
-- can verify the first three; the last two are visible through the error the
-- Edge Function writes to engagement.push_deliveries. admin_push_health()
-- reports all of it, and the admin page turns it into an actionable checklist.

-- ---------------------------------------------------------------------------
-- 1. Permissions
-- ---------------------------------------------------------------------------
insert into identity.permissions (code, name_ar, name_en, description) values
  ('notifications.send',   'إرسال الإشعارات',  'Send notifications',   'Compose, send and resend notifications to customers.'),
  ('notifications.manage', 'إدارة الإشعارات', 'Manage notifications', 'Delete notifications and change their read state.')
on conflict (code) do update
  set name_ar     = excluded.name_ar,
      name_en     = excluded.name_en,
      description = excluded.description;

insert into identity.role_permissions (role_id, permission_id)
select r.id, p.id
  from identity.roles r
  join identity.permissions p
    on p.code in ('notifications.send', 'notifications.manage')
 where r.code = 'manager'
on conflict do nothing;

-- Owner holds every permission implicitly (identity.has_permission).
-- branch_manager, staff and cashier keep notifications.read only.

-- ---------------------------------------------------------------------------
-- 2. Campaigns
-- ---------------------------------------------------------------------------
create table if not exists engagement.notification_campaigns (
  id               uuid primary key default extensions.gen_random_uuid(),
  type             text not null check (type in ('promo','system','loyalty')),
  title_ar         text not null,
  title_en         text not null,
  body_ar          text not null,
  body_en          text not null,
  audience         text not null check (audience in ('all','push_enabled','has_device','customer')),
  audience_user_id uuid references identity.profiles(id) on delete set null,
  payload          jsonb not null default '{}'::jsonb,
  created_by       uuid references auth.users(id) on delete set null,
  recipient_count  integer not null default 0,
  created_at       timestamptz not null default now()
);

comment on table engagement.notification_campaigns is
  'One row per message composed from the admin dashboard. The notifications it created point back to it through engagement.notifications.campaign_id.';

create index if not exists ix_notification_campaigns_created
  on engagement.notification_campaigns (created_at desc);

alter table engagement.notification_campaigns enable row level security;
revoke all on table engagement.notification_campaigns from anon, authenticated;
grant select on table engagement.notification_campaigns to service_role;

-- ---------------------------------------------------------------------------
-- 3. The notification rows gain the campaign link and the author
-- ---------------------------------------------------------------------------
alter table engagement.notifications
  add column if not exists campaign_id uuid
    references engagement.notification_campaigns(id) on delete set null;

alter table engagement.notifications
  add column if not exists created_by uuid
    references auth.users(id) on delete set null;

comment on column engagement.notifications.campaign_id is
  'The admin campaign that created the row. NULL for order, loyalty and subscription notifications.';

comment on column engagement.notifications.created_by is
  'The staff auth user who composed the row. NULL for automatic notifications.';

create index if not exists ix_notifications_campaign
  on engagement.notifications (campaign_id);
create index if not exists ix_notifications_created
  on engagement.notifications (created_at desc);
create index if not exists ix_notifications_type_created
  on engagement.notifications (type, created_at desc);

-- 114 added 'subscription'. Repeated so a database that skipped 114 still
-- accepts every type the triggers write.
alter table engagement.notifications
  drop constraint if exists notifications_type_check;
alter table engagement.notifications
  add constraint notifications_type_check
  check (type in ('order_status','promo','system','loyalty','subscription'));

-- The public bridge view public.notifications was created with `select *`
-- before these columns existed, so it deliberately does not expose
-- campaign_id or created_by to the customer app. Do not recreate it here.

-- ---------------------------------------------------------------------------
-- 4. The push chain, repeated and hardened
-- ---------------------------------------------------------------------------
create table if not exists engagement.push_deliveries (
  id                  uuid primary key default extensions.gen_random_uuid(),
  notification_id     uuid references engagement.notifications(id) on delete cascade,
  user_id             uuid not null references identity.profiles(id) on delete cascade,
  platform            text not null check (platform in ('ios','android','web')),
  status              text not null check (status in ('sent','failed','skipped','invalid_token')),
  provider_message_id text,
  error               text,
  created_at          timestamptz not null default now()
);

create index if not exists ix_push_deliveries_notification
  on engagement.push_deliveries (notification_id);
create index if not exists ix_push_deliveries_user_created
  on engagement.push_deliveries (user_id, created_at desc);

alter table engagement.push_deliveries enable row level security;
revoke all on table engagement.push_deliveries from anon, authenticated;
grant select on table engagement.push_deliveries to service_role;

alter table engagement.device_tokens
  add column if not exists locale text;

grant insert, update, delete on table engagement.device_tokens to authenticated;
grant insert, update, delete on table engagement.device_tokens to service_role;
grant insert, update, delete on table engagement.push_deliveries to service_role;
revoke all on table engagement.device_tokens from anon;

-- The Edge Function reads and writes through the public schema, which is what
-- PostgREST serves. Both views are rebuilt with an explicit column list so a
-- later column cannot freeze them again.
drop view if exists public.device_tokens;

create view public.device_tokens with (security_invoker = true) as
  select id,
         user_id,
         platform,
         token,
         app_version,
         device_name,
         locale,
         last_seen_at,
         created_at
    from engagement.device_tokens;

grant select, insert, update, delete on public.device_tokens to authenticated;
grant select, insert, update, delete on public.device_tokens to service_role;
revoke all on public.device_tokens from anon;

create or replace view public.push_deliveries with (security_invoker = true) as
  select * from engagement.push_deliveries;

grant select on public.push_deliveries to service_role;
revoke all on public.push_deliveries from anon, authenticated;

-- The 4-argument overload from 097/104 and the 5-argument overload from 100
-- both had defaults, so PostgREST could not choose between them. The
-- 5-argument one below covers every caller.
drop function if exists public.register_device_token(text, text, text, text);

create or replace function public.register_device_token(
  p_platform    text,
  p_token       text,
  p_app_version text default null,
  p_device_name text default null,
  p_locale      text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_user uuid := auth.uid();
  v_id   uuid;
begin
  if v_user is null then
    raise exception 'Not signed in.' using errcode = '28000';
  end if;

  if p_platform is null or p_platform not in ('android','ios','web') then
    raise exception 'Unsupported platform.' using errcode = '22023';
  end if;

  if p_token is null or length(trim(p_token)) < 8 then
    raise exception 'Invalid token.' using errcode = '22023';
  end if;

  insert into engagement.device_tokens
    (user_id, platform, token, app_version, device_name, locale, last_seen_at)
  values
    (v_user, p_platform, p_token, p_app_version, p_device_name,
     case when lower(coalesce(p_locale, '')) like 'ar%' then 'ar'
          when lower(coalesce(p_locale, '')) like 'en%' then 'en'
          else null end,
     now())
  on conflict (platform, token) do update
    set user_id      = excluded.user_id,
        app_version  = excluded.app_version,
        device_name  = excluded.device_name,
        locale       = excluded.locale,
        last_seen_at = now()
  returning id into v_id;

  return v_id;
end;
$fn$;

create or replace function public.unregister_device_token(p_token text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_count integer;
begin
  if auth.uid() is null then
    raise exception 'Not signed in.' using errcode = '28000';
  end if;
  if p_token is null or trim(p_token) = '' then
    return false;
  end if;

  delete from engagement.device_tokens
   where token = p_token
     and user_id = auth.uid();

  get diagnostics v_count = row_count;
  return v_count > 0;
end;
$fn$;

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
      'user_id',      auth.uid(),
      'order_status', true,
      'promo',        true,
      'loyalty',      true,
      'system',       true,
      'push_enabled', false,
      'updated_at',   null
    );
  end if;
  return v_row;
end;
$fn$;

create or replace function public.set_push_preferences(
  p_push_enabled boolean default null,
  p_order_status boolean default null,
  p_promo        boolean default null,
  p_loyalty      boolean default null,
  p_system       boolean default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if auth.uid() is null then
    raise exception 'Not signed in.' using errcode = '28000';
  end if;

  insert into engagement.notification_preferences
    (user_id, order_status, promo, loyalty, system, push_enabled, updated_at)
  values
    (auth.uid(),
     coalesce(p_order_status, true),
     coalesce(p_promo, true),
     coalesce(p_loyalty, true),
     coalesce(p_system, true),
     coalesce(p_push_enabled, false),
     now())
  on conflict (user_id) do update
    set order_status = coalesce(p_order_status, engagement.notification_preferences.order_status),
        promo        = coalesce(p_promo, engagement.notification_preferences.promo),
        loyalty      = coalesce(p_loyalty, engagement.notification_preferences.loyalty),
        system       = coalesce(p_system, engagement.notification_preferences.system),
        push_enabled = coalesce(p_push_enabled, engagement.notification_preferences.push_enabled),
        updated_at   = now();

  return public.push_preferences();
end;
$fn$;

grant execute on function
  public.register_device_token(text, text, text, text, text),
  public.unregister_device_token(text),
  public.push_preferences(),
  public.set_push_preferences(boolean, boolean, boolean, boolean, boolean)
  to authenticated;

revoke execute on function
  public.register_device_token(text, text, text, text, text),
  public.unregister_device_token(text),
  public.push_preferences(),
  public.set_push_preferences(boolean, boolean, boolean, boolean, boolean)
  from public, anon;

insert into core.app_settings (key, value, value_type, is_public, description)
values (
  'push_function_url',
  to_jsonb('https://webzzasosevzymftgszn.supabase.co/functions/v1/send-push'::text),
  'string',
  false,
  'Edge Function that delivers engagement.notifications to FCM.'
)
on conflict (key) do update
  set value       = excluded.value,
      value_type  = excluded.value_type,
      description = excluded.description,
      updated_at  = now();

-- Queues one notification. Returns false when the configuration that the
-- database can see is incomplete, so admin_resend_notification can tell the
-- difference between "queued" and "nothing to queue".
create or replace function engagement.enqueue_push(p_notification engagement.notifications)
returns boolean
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_secret text;
  v_url    text;
begin
  begin
    select decrypted_secret into v_secret
      from vault.decrypted_secrets
     where name = 'push_webhook_secret'
     limit 1;
  exception when others then
    v_secret := null;
  end;

  select value #>> '{}' into v_url
    from core.app_settings
   where key = 'push_function_url';

  if v_secret is null or v_url is null or trim(v_url) = '' then
    return false;
  end if;

  perform net.http_post(
    url     := v_url,
    body    := jsonb_build_object(
                  'notification_id',     p_notification.id,
                  'user_id',             p_notification.user_id,
                  'type',                p_notification.type,
                  'title_ar',            p_notification.title_ar,
                  'title_en',            p_notification.title_en,
                  'body_ar',             p_notification.body_ar,
                  'body_en',             p_notification.body_en,
                  'payload',             p_notification.payload,
                  'related_entity_type', p_notification.related_entity_type,
                  'related_entity_id',   p_notification.related_entity_id,
                  'created_at',          p_notification.created_at
                ),
    headers := jsonb_build_object(
                  'Content-Type',  'application/json',
                  'x-push-secret', v_secret
                ),
    timeout_milliseconds := 5000
  );

  return true;
exception
  when others then
    -- A broken push configuration must never abort the insert that created
    -- the notification. The in-app row is the source of truth.
    return false;
end;
$fn$;

create or replace function engagement.dispatch_push_notification()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  perform engagement.enqueue_push(new);
  return new;
end;
$fn$;

drop trigger if exists tr_notifications_dispatch_push on engagement.notifications;

create trigger tr_notifications_dispatch_push
  after insert on engagement.notifications
  for each row execute function engagement.dispatch_push_notification();

revoke execute on function engagement.enqueue_push(engagement.notifications)
  from public, anon, authenticated;
revoke execute on function engagement.dispatch_push_notification()
  from public, anon, authenticated;

-- Realtime keeps the unread badge honest while the customer app is open.
do $$
begin
  if not exists (
    select 1
      from pg_publication_tables
     where pubname    = 'supabase_realtime'
       and schemaname = 'engagement'
       and tablename  = 'notifications'
  ) then
    alter publication supabase_realtime add table engagement.notifications;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. Push health
-- ---------------------------------------------------------------------------
create or replace function public.admin_push_health()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_vault_available  boolean := false;
  v_secret           boolean := false;
  v_function_url     text;
  v_pg_net           boolean;
  v_trigger          boolean;
  v_http_status      integer;
  v_http_error       text;
  v_http_at          timestamptz;
  v_deliveries       jsonb;
  v_last_success     timestamptz;
  v_last_failure     timestamptz;
  v_last_error       text;
  v_last_error_at    timestamptz;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('notifications.read') then
    raise exception 'missing permission: notifications.read' using errcode = '42501';
  end if;

  begin
    select exists (
      select 1 from vault.decrypted_secrets where name = 'push_webhook_secret'
    ) into v_secret;
    v_vault_available := true;
  exception when others then
    v_vault_available := false;
    v_secret := false;
  end;

  select value #>> '{}' into v_function_url
    from core.app_settings
   where key = 'push_function_url';

  v_pg_net := exists (
    select 1 from pg_extension where extname = 'pg_net'
  );

  v_trigger := exists (
    select 1
      from pg_trigger
     where tgname = 'tr_notifications_dispatch_push'
       and tgrelid = to_regclass('engagement.notifications')
       and not tgisinternal
  );

  begin
    if to_regclass('net._http_response') is not null then
      select r.status_code, r.error_msg, r.created
        into v_http_status, v_http_error, v_http_at
        from net._http_response r
       order by r.created desc
       limit 1;
    end if;
  exception when others then
    v_http_status := null;
    v_http_error := null;
    v_http_at := null;
  end;

  select
    jsonb_build_object(
      'sent',          count(*) filter (where status = 'sent'),
      'failed',        count(*) filter (where status = 'failed'),
      'skipped',       count(*) filter (where status = 'skipped'),
      'invalid_token', count(*) filter (where status = 'invalid_token')
    ),
    max(created_at) filter (where status = 'sent'),
    max(created_at) filter (where status in ('failed','invalid_token'))
  into v_deliveries, v_last_success, v_last_failure
  from engagement.push_deliveries
  where created_at >= now() - interval '30 days';

  select d.error, d.created_at
    into v_last_error, v_last_error_at
    from engagement.push_deliveries d
   where d.error is not null
   order by d.created_at desc
   limit 1;

  return jsonb_build_object(
    'vault_available',           v_vault_available,
    'webhook_secret_configured', v_secret,
    'pg_net_installed',          v_pg_net,
    'dispatch_trigger_installed', v_trigger,
    'function_url',              v_function_url,
    'function_url_configured',
      v_function_url is not null and trim(v_function_url) <> '',
    'devices_total',
      (select count(*) from engagement.device_tokens),
    'devices_android',
      (select count(*) from engagement.device_tokens where platform = 'android'),
    'devices_ios',
      (select count(*) from engagement.device_tokens where platform = 'ios'),
    'devices_with_locale',
      (select count(*) from engagement.device_tokens where locale is not null),
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
    'deliveries_30d',            v_deliveries,
    'last_success_at',           v_last_success,
    'last_failure_at',           v_last_failure,
    'last_error',                v_last_error,
    'last_error_at',             v_last_error_at,
    'last_webhook_status',       v_http_status,
    'last_webhook_error',        v_http_error,
    'last_webhook_at',           v_http_at
  );
end;
$fn$;

comment on function public.admin_push_health is
  'Everything the dashboard can verify about the push path, plus the last delivery and webhook errors.';

revoke all on function public.admin_push_health() from public, anon;
grant execute on function public.admin_push_health() to authenticated;

-- ---------------------------------------------------------------------------
-- 6. Metrics
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
    )
  );
end;
$fn$;

comment on function public.admin_notification_metrics is
  'Notification totals, type split, reachable customers and 30-day push delivery rate.';

revoke all on function public.admin_notification_metrics() from public, anon;
grant execute on function public.admin_notification_metrics() to authenticated;

-- ---------------------------------------------------------------------------
-- 7. Directory with server-side search, filters and paging
-- ---------------------------------------------------------------------------
create or replace function public.admin_notifications(
  p_search text default null,
  p_type   text default null,
  p_read   boolean default null,
  p_push   text default null,
  p_limit  integer default 20,
  p_offset integer default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_search text := nullif(lower(trim(coalesce(p_search, ''))), '');
  v_limit  integer := least(greatest(coalesce(p_limit, 20), 1), 100);
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_total  bigint;
  v_rows   jsonb;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('notifications.read') then
    raise exception 'missing permission: notifications.read' using errcode = '42501';
  end if;
  if p_type is not null
     and p_type not in ('order_status','promo','system','loyalty','subscription') then
    raise exception 'invalid notification type' using errcode = '22023';
  end if;
  if p_push is not null
     and p_push not in ('sent','failed','skipped','none') then
    raise exception 'invalid push state' using errcode = '22023';
  end if;

  with filtered as (
    select
      n.*,
      pr.full_name,
      pr.email,
      pr.phone,
      pr.avatar_url,
      c.audience,
      c.recipient_count,
      c.created_at as campaign_created_at,
      coalesce(d.total, 0)          as delivery_total,
      coalesce(d.sent, 0)           as delivery_sent,
      coalesce(d.failed, 0)         as delivery_failed,
      coalesce(d.invalid_token, 0)  as delivery_invalid_token,
      coalesce(d.skipped, 0)        as delivery_skipped,
      d.last_at                     as delivery_last_at,
      d.last_error                  as delivery_last_error,
      case
        when coalesce(d.total, 0) = 0 then 'none'
        when d.sent > 0 then 'sent'
        when d.failed + d.invalid_token > 0 then 'failed'
        when d.skipped > 0 then 'skipped'
        else 'none'
      end as push_state
    from engagement.notifications n
    join identity.profiles pr on pr.id = n.user_id
    left join engagement.notification_campaigns c on c.id = n.campaign_id
    left join lateral (
      select
        count(*)                                                          as total,
        count(*) filter (where dd.status = 'sent')                        as sent,
        count(*) filter (where dd.status = 'failed')                      as failed,
        count(*) filter (where dd.status = 'invalid_token')               as invalid_token,
        count(*) filter (where dd.status = 'skipped')                     as skipped,
        max(dd.created_at)                                                as last_at,
        (array_agg(dd.error order by dd.created_at desc)
          filter (where dd.error is not null))[1]                         as last_error
      from engagement.push_deliveries dd
      where dd.notification_id = n.id
    ) d on true
    where (
      v_search is null
      or strpos(lower(n.title_ar), v_search) > 0
      or strpos(lower(n.title_en), v_search) > 0
      or strpos(lower(n.body_ar), v_search) > 0
      or strpos(lower(n.body_en), v_search) > 0
      or strpos(lower(coalesce(pr.full_name, '')), v_search) > 0
      or strpos(lower(coalesce(pr.email, '')), v_search) > 0
      or strpos(lower(coalesce(pr.phone, '')), v_search) > 0
    )
    and (p_type is null or n.type = p_type)
    and (p_read is null or n.is_read = p_read)
    and (
      p_push is null
      or (p_push = 'none'    and coalesce(d.total, 0) = 0)
      or (p_push = 'sent'    and d.sent > 0)
      or (p_push = 'failed'  and d.sent = 0
          and d.failed + d.invalid_token > 0)
      or (p_push = 'skipped' and d.sent = 0
          and d.failed + d.invalid_token = 0 and d.skipped > 0)
    )
  ),
  page as (
    select f.*, count(*) over () as total_count
    from filtered f
    order by f.created_at desc
    limit v_limit offset v_offset
  )
  select
    coalesce(max(p.total_count), (select count(*) from filtered)),
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id',                  p.id,
          'type',                p.type,
          'title_ar',            p.title_ar,
          'title_en',            p.title_en,
          'body_ar',             p.body_ar,
          'body_en',             p.body_en,
          'payload',             p.payload,
          'related_entity_type', p.related_entity_type,
          'related_entity_id',   p.related_entity_id,
          'is_read',             p.is_read,
          'read_at',             p.read_at,
          'created_at',          p.created_at,
          'customer', jsonb_build_object(
            'id',         p.user_id,
            'full_name',  p.full_name,
            'email',      p.email,
            'phone',      p.phone,
            'avatar_url', p.avatar_url
          ),
          'campaign', case
            when p.campaign_id is null then null
            else jsonb_build_object(
              'id',              p.campaign_id,
              'audience',        p.audience,
              'recipient_count', p.recipient_count,
              'created_at',      p.campaign_created_at
            )
          end,
          'push', jsonb_build_object(
            'state',         p.push_state,
            'total',         p.delivery_total,
            'sent',          p.delivery_sent,
            'failed',        p.delivery_failed,
            'invalid_token', p.delivery_invalid_token,
            'skipped',       p.delivery_skipped,
            'last_at',       p.delivery_last_at,
            'last_error',    p.delivery_last_error
          )
        )
        order by p.created_at desc
      ),
      '[]'::jsonb
    )
  into v_total, v_rows
  from page p;

  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$fn$;

comment on function public.admin_notifications is
  'Paged admin notification directory with customer, campaign and push delivery state.';

revoke all on function public.admin_notifications(text, text, boolean, text, integer, integer)
  from public, anon;
grant execute on function public.admin_notifications(text, text, boolean, text, integer, integer)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 8. Customers for the composer, with their push readiness
-- ---------------------------------------------------------------------------
create or replace function public.admin_notification_customers(
  p_search text default null,
  p_limit  integer default 20
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_search text := nullif(lower(trim(coalesce(p_search, ''))), '');
  v_limit  integer := least(greatest(coalesce(p_limit, 20), 1), 50);
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('notifications.send') then
    raise exception 'missing permission: notifications.send' using errcode = '42501';
  end if;

  return coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'id',           p.id,
        'full_name',    p.full_name,
        'email',        p.email,
        'phone',        p.phone,
        'avatar_url',   p.avatar_url,
        'push_enabled', coalesce(pref.push_enabled, false),
        'device_count', (
          select count(*) from engagement.device_tokens t where t.user_id = p.id
        ),
        'has_push', coalesce(pref.push_enabled, false)
          and exists (select 1 from engagement.device_tokens t where t.user_id = p.id)
      )
      order by coalesce(p.full_name, p.email, p.phone, p.id::text)
    )
    from (
      select *
        from identity.profiles pr
       where v_search is null
          or strpos(lower(coalesce(pr.full_name, '')), v_search) > 0
          or strpos(lower(coalesce(pr.email, '')), v_search) > 0
          or strpos(lower(coalesce(pr.phone, '')), v_search) > 0
       order by pr.created_at desc
       limit v_limit
    ) p
    left join engagement.notification_preferences pref on pref.user_id = p.id
  ), '[]'::jsonb);
end;
$fn$;

comment on function public.admin_notification_customers is
  'Customer picker for the composer, with push opt-in and registered device count.';

revoke all on function public.admin_notification_customers(text, integer)
  from public, anon;
grant execute on function public.admin_notification_customers(text, integer)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 9. Audience size before sending
-- ---------------------------------------------------------------------------
create or replace function public.admin_notification_audience(
  p_type     text,
  p_audience text default 'all',
  p_user_id  uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_count integer;
  v_push  integer;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('notifications.send') then
    raise exception 'missing permission: notifications.send' using errcode = '42501';
  end if;
  if p_type is null or p_type not in ('promo','system','loyalty') then
    raise exception 'invalid campaign type' using errcode = '22023';
  end if;
  if p_audience is null
     or p_audience not in ('all','push_enabled','has_device','customer') then
    raise exception 'invalid audience' using errcode = '22023';
  end if;

  select
    count(*),
    count(*) filter (
      where coalesce(pref.push_enabled, false)
        and exists (select 1 from engagement.device_tokens t where t.user_id = p.id)
    )
  into v_count, v_push
  from identity.profiles p
  left join engagement.notification_preferences pref on pref.user_id = p.id
  where (p_audience = 'customer' or not exists (
           select 1 from identity.staff_members sm where sm.user_id = p.id
         ))
    and (p_audience <> 'customer' or p.id = p_user_id)
    and (p_audience <> 'push_enabled' or coalesce(pref.push_enabled, false))
    and (p_audience <> 'has_device' or exists (
           select 1 from engagement.device_tokens t where t.user_id = p.id
         ))
    and case p_type
          when 'promo'   then coalesce(pref.promo, true)
          when 'loyalty' then coalesce(pref.loyalty, true)
          when 'system'  then coalesce(pref.system, true)
          else true
        end;

  return jsonb_build_object('count', v_count, 'push_ready', v_push);
end;
$fn$;

comment on function public.admin_notification_audience is
  'How many customers a campaign would reach, and how many of them have a push-ready device.';

revoke all on function public.admin_notification_audience(text, text, uuid)
  from public, anon;
grant execute on function public.admin_notification_audience(text, text, uuid)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 10. Compose and send
-- ---------------------------------------------------------------------------
create or replace function public.admin_send_notification(
  p_type      text,
  p_title_ar  text,
  p_title_en  text,
  p_body_ar   text,
  p_body_en   text,
  p_audience  text default 'all',
  p_user_id   uuid default null,
  p_payload   jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_title_ar   text := trim(coalesce(p_title_ar, ''));
  v_title_en   text := trim(coalesce(p_title_en, ''));
  v_body_ar    text := trim(coalesce(p_body_ar, ''));
  v_body_en    text := trim(coalesce(p_body_en, ''));
  v_payload    jsonb := coalesce(p_payload, '{}'::jsonb);
  v_campaign   uuid;
  v_recipients integer := 0;
  v_push_ready integer := 0;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('notifications.send') then
    raise exception 'missing permission: notifications.send' using errcode = '42501';
  end if;

  if p_type is null or p_type not in ('promo','system','loyalty') then
    raise exception 'invalid campaign type' using errcode = '22023';
  end if;
  if p_audience is null
     or p_audience not in ('all','push_enabled','has_device','customer') then
    raise exception 'invalid audience' using errcode = '22023';
  end if;
  if p_audience = 'customer' and p_user_id is null then
    raise exception 'a specific customer is required' using errcode = '22023';
  end if;
  if v_title_ar = '' or v_title_en = '' or v_body_ar = '' or v_body_en = '' then
    raise exception 'title and body are required in both languages' using errcode = '22023';
  end if;
  if char_length(v_title_ar) > 160 or char_length(v_title_en) > 160 then
    raise exception 'title is too long' using errcode = '22023';
  end if;
  if char_length(v_body_ar) > 1000 or char_length(v_body_en) > 1000 then
    raise exception 'body is too long' using errcode = '22023';
  end if;
  if jsonb_typeof(v_payload) <> 'object' then
    raise exception 'payload must be a JSON object' using errcode = '22023';
  end if;
  if p_audience = 'customer'
     and not exists (select 1 from identity.profiles where id = p_user_id) then
    return jsonb_build_object('ok', false, 'reason', 'customer_not_found');
  end if;

  insert into engagement.notification_campaigns
    (type, title_ar, title_en, body_ar, body_en, audience,
     audience_user_id, payload, created_by, recipient_count)
  values
    (p_type, v_title_ar, v_title_en, v_body_ar, v_body_en, p_audience,
     case when p_audience = 'customer' then p_user_id else null end,
     v_payload, auth.uid(), 0)
  returning id into v_campaign;

  insert into engagement.notifications
    (user_id, type, title_ar, title_en, body_ar, body_en,
     payload, campaign_id, created_by, dedupe_key)
  select
    p.id,
    p_type,
    v_title_ar,
    v_title_en,
    v_body_ar,
    v_body_en,
    v_payload,
    v_campaign,
    auth.uid(),
    'campaign:' || v_campaign::text || ':' || p.id::text
  from identity.profiles p
  left join engagement.notification_preferences pref on pref.user_id = p.id
  where (p_audience = 'customer' or not exists (
           select 1 from identity.staff_members sm where sm.user_id = p.id
         ))
    and (p_audience <> 'customer' or p.id = p_user_id)
    and (p_audience <> 'push_enabled' or coalesce(pref.push_enabled, false))
    and (p_audience <> 'has_device' or exists (
           select 1 from engagement.device_tokens t where t.user_id = p.id
         ))
    and case p_type
          when 'promo'   then coalesce(pref.promo, true)
          when 'loyalty' then coalesce(pref.loyalty, true)
          when 'system'  then coalesce(pref.system, true)
          else true
        end
  on conflict (user_id, dedupe_key) where dedupe_key is not null do nothing;

  get diagnostics v_recipients = row_count;

  if v_recipients = 0 then
    delete from engagement.notification_campaigns where id = v_campaign;
    return jsonb_build_object('ok', false, 'reason', 'no_recipients');
  end if;

  select count(*) into v_push_ready
    from engagement.notifications n
   where n.campaign_id = v_campaign
     and exists (
       select 1 from engagement.notification_preferences pref
        where pref.user_id = n.user_id and pref.push_enabled
     )
     and exists (
       select 1 from engagement.device_tokens t where t.user_id = n.user_id
     );

  update engagement.notification_campaigns
     set recipient_count = v_recipients
   where id = v_campaign;

  perform identity.audit(
    'engagement.notification.send',
    'notification_campaign',
    v_campaign,
    null,
    jsonb_build_object(
      'type',          p_type,
      'audience',      p_audience,
      'audience_user', case when p_audience = 'customer' then p_user_id else null end,
      'recipients',    v_recipients
    )
  );

  return jsonb_build_object(
    'ok',           true,
    'campaign_id',  v_campaign,
    'recipients',   v_recipients,
    'push_ready',   v_push_ready
  );
end;
$fn$;

comment on function public.admin_send_notification is
  'Creates one campaign and one notification per matching customer; the insert trigger queues the pushes.';

revoke all on function public.admin_send_notification(text, text, text, text, text, text, uuid, jsonb)
  from public, anon;
grant execute on function public.admin_send_notification(text, text, text, text, text, text, uuid, jsonb)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 11. Resend the push of an existing notification
-- ---------------------------------------------------------------------------
create or replace function public.admin_resend_notification(p_notification_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_row    engagement.notifications%rowtype;
  v_queued boolean;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('notifications.send') then
    raise exception 'missing permission: notifications.send' using errcode = '42501';
  end if;

  select * into v_row
    from engagement.notifications
   where id = p_notification_id;

  if not found then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;

  v_queued := engagement.enqueue_push(v_row);

  perform identity.audit(
    'engagement.notification.resend',
    'notification',
    p_notification_id,
    null,
    jsonb_build_object('queued', v_queued)
  );

  return jsonb_build_object(
    'ok',     true,
    'queued', v_queued,
    'reason', case when v_queued then null else 'push_not_configured' end
  );
end;
$fn$;

comment on function public.admin_resend_notification is
  'Queues the push of an existing notification again and records the attempt in the audit log.';

revoke all on function public.admin_resend_notification(uuid) from public, anon;
grant execute on function public.admin_resend_notification(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 12. Read state and delete
-- ---------------------------------------------------------------------------
create or replace function public.admin_set_notification_read(
  p_notification_id uuid,
  p_read boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_read boolean := coalesce(p_read, true);
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('notifications.manage') then
    raise exception 'missing permission: notifications.manage' using errcode = '42501';
  end if;

  update engagement.notifications
     set is_read = v_read,
         read_at = case when v_read then coalesce(read_at, now()) else null end
   where id = p_notification_id;

  if not found then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;

  perform identity.audit(
    'engagement.notification.read',
    'notification',
    p_notification_id,
    null,
    jsonb_build_object('is_read', v_read)
  );

  return jsonb_build_object('ok', true);
end;
$fn$;

comment on function public.admin_set_notification_read is
  'Marks a notification read or unread on behalf of support.';

revoke all on function public.admin_set_notification_read(uuid, boolean)
  from public, anon;
grant execute on function public.admin_set_notification_read(uuid, boolean)
  to authenticated;

create or replace function public.admin_delete_notification(p_notification_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_row engagement.notifications%rowtype;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('notifications.manage') then
    raise exception 'missing permission: notifications.manage' using errcode = '42501';
  end if;

  select * into v_row
    from engagement.notifications
   where id = p_notification_id;

  if not found then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;

  delete from engagement.notifications where id = p_notification_id;

  perform identity.audit(
    'engagement.notification.delete',
    'notification',
    p_notification_id,
    jsonb_build_object(
      'type',        v_row.type,
      'user_id',     v_row.user_id,
      'campaign_id', v_row.campaign_id,
      'is_read',     v_row.is_read,
      'created_at',  v_row.created_at
    ),
    null
  );

  return jsonb_build_object('ok', true);
end;
$fn$;

comment on function public.admin_delete_notification is
  'Deletes one notification; its delivery rows cascade and the audit row keeps the identity of the deleted record.';

revoke all on function public.admin_delete_notification(uuid) from public, anon;
grant execute on function public.admin_delete_notification(uuid) to authenticated;

notify pgrst, 'reload config';
notify pgrst, 'reload schema';
