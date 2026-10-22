-- 104_push_notifications.sql
--
-- RENAMED from `097_push_notifications.sql`.  The body is unchanged.
--
-- Why the version changed
-- -----------------------
-- The Supabase CLI applies a migration whose file name matches
-- `^([0-9]+)_(.*)\.sql$` and records the numeric part in
-- `supabase_migrations.schema_migrations`, whose primary key is the version.
-- The repository carried TWO files with version 097:
--
--   097_ai_learned_answers.sql
--   097_push_notifications.sql
--
-- The CLI sorts them lexicographically, applies the AI file first and writes
-- the row `('097', ...)`.  The push file then tries to write the same row and
-- fails with `23505 duplicate key value violates unique constraint
-- "schema_migrations_pkey"`, so the whole push-notification migration was
-- rolled back and `supabase db push` aborted - permanently, because every
-- later attempt hits the same duplicate.
--
-- `098_push_delivery_locale_and_grants.sql` grants on
-- `engagement.push_deliveries` and `099_push_bridge_views.sql` reads from it,
-- so both of them fail with `42P01` while the push file is missing.
--
-- How the effects of both files are preserved
-- ------------------------------------------
-- The version 097 in the migration ledger belongs to
-- `097_ai_learned_answers.sql` (the lexicographically first of the two, and
-- the only one the CLI could ever apply).  This file keeps every statement of
-- the former `097_push_notifications.sql` and is now applied as version 104,
-- after 101-103.  Every statement in it is idempotent
-- (`create table if not exists`, `create or replace function`,
-- `create index if not exists`, `drop trigger if exists`, `on conflict do
-- update`), so an environment where the push objects were created by hand
-- applies it without a change.
--
-- Because 098 and 099 now run before this file, the two statements that
-- depend on the delivery log (the grant of 098 and the bridge view of 099)
-- are repeated at the end of this file.  The end state is therefore the same
-- in every environment.
--
-- The AI file is untouched and keeps version 097.
--
-- Push delivery, end to end:
--
--   1. the app registers its FCM token        (public.register_device_token)
--   2. the app reads / changes its switches    (public.push_preferences,
--                                               public.set_push_preferences)
--   3. every new engagement.notifications row is handed to the send-push
--      Edge Function by a trigger
--   4. the Edge Function records what it did   (engagement.push_deliveries)
--   5. engagement.notifications joins the supabase_realtime publication, so
--      the in-app list updates while the app is open
--
-- WHY pg_net AND NOT A DASHBOARD WEBHOOK
-- ---------------------------------------
-- Both are the same mechanism. pg_net is used here because the trigger lives
-- in the repository next to the triggers that create the notifications, so
-- the delivery path is reviewed with the rest of the database. pg_net queues
-- the request and returns, so the insert that raised the notification never
-- waits for FCM, and a broken push configuration can never abort it.
--
-- WHY THE IN-APP RECORD STAYS THE SOURCE OF TRUTH
-- ----------------------------------------------
-- engagement.notifications is written by the order and loyalty triggers and
-- is what the app reads. The push is only a delivery attempt of that record:
-- if FCM is down, or the customer denied the permission, or the phone has no
-- token yet, the customer still sees the notification in the app. The
-- delivery log keeps the difference between "not sent" and "not delivered"
-- visible.

-- ---------------------------------------------------------------------------
-- Delivery log. One row per push attempt, written by the Edge Function.
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

comment on table engagement.push_deliveries is
  'One row per push attempt. Written by the send-push Edge Function only.';

create index if not exists ix_push_deliveries_notification
  on engagement.push_deliveries (notification_id);

create index if not exists ix_push_deliveries_user_created
  on engagement.push_deliveries (user_id, created_at desc);

alter table engagement.push_deliveries enable row level security;

revoke all on table engagement.push_deliveries from anon, authenticated;
grant select on table engagement.push_deliveries to service_role;

-- There is no policy on the delivery log: the client never reads it, only the
-- Edge Function does, and service_role bypasses row level security.

-- ---------------------------------------------------------------------------
-- Device tokens. The table already exists (migration 016) but nothing could
-- write to it: PostgREST serves only the public schema and the bridge view
-- was read-only. The RPCs below are the write path.
-- ---------------------------------------------------------------------------
grant insert, update, delete on table engagement.device_tokens to authenticated;
revoke all on table engagement.device_tokens from anon;

-- ---------------------------------------------------------------------------
-- public.register_device_token
--
-- The token belongs to the device, not to the account: the same phone can
-- sign in as another customer later. The unique key is (platform, token), so
-- a token that changes hands has to be moved rather than duplicated, and
-- that is why this runs as SECURITY DEFINER: as the caller it could not
-- touch the row that belongs to the previous owner.
-- ---------------------------------------------------------------------------
create or replace function public.register_device_token(
  p_platform    text,
  p_token       text,
  p_app_version text default null,
  p_device_name text default null
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
    (user_id, platform, token, app_version, device_name, last_seen_at)
  values
    (v_user, p_platform, p_token, p_app_version, p_device_name, now())
  on conflict (platform, token) do update
    set user_id       = excluded.user_id,
        app_version   = excluded.app_version,
        device_name   = excluded.device_name,
        last_seen_at  = now()
  returning id into v_id;

  return v_id;
end;
$fn$;

comment on function public.register_device_token(text, text, text, text) is
  'Stores the FCM token of the signed-in customer and moves it to that '
  'customer when the device changed accounts.';

-- ---------------------------------------------------------------------------
-- public.unregister_device_token
--
-- Called when the customer signs out, so the next person who uses the phone
-- does not receive the notifications of the previous one.
-- ---------------------------------------------------------------------------
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

comment on function public.unregister_device_token(text) is
  'Removes the FCM token of the signed-in customer.';

-- ---------------------------------------------------------------------------
-- public.push_preferences
--
-- Always returns a row, even when the customer never opened the settings:
-- the defaults are the table defaults, so the app does not have to know
-- whether the row exists.
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
      'updated_at',    null
    );
  end if;

  return v_row;
end;
$fn$;

comment on function public.push_preferences() is
  'The push switches of the signed-in customer, with the defaults filled in.';

-- ---------------------------------------------------------------------------
-- public.set_push_preferences
--
-- A null argument leaves that field alone, so the app can change one switch
-- without sending the whole object.
-- ---------------------------------------------------------------------------
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

comment on function public.set_push_preferences(boolean, boolean, boolean, boolean, boolean) is
  'Changes the push switches of the signed-in customer. A null argument is left alone.';

-- ---------------------------------------------------------------------------
-- The dispatch trigger
--
-- The secret and the function URL are configuration, not code: the secret
-- lives in Vault and the URL in core.app_settings. When either is missing
-- the trigger does nothing, and the notification still exists in the app.
-- ---------------------------------------------------------------------------
insert into core.app_settings (key, value, value_type, is_public, description)
values (
  'push_function_url',
  to_jsonb('https://webzzasosevzymftgszn.supabase.co/functions/v1/send-push'::text),
  'string',
  false,
  'Edge Function that delivers the notifications of engagement.notifications to FCM.'
)
on conflict (key) do update
  set value       = excluded.value,
      value_type  = excluded.value_type,
      description = excluded.description,
      updated_at  = now();

create or replace function engagement.dispatch_push_notification()
returns trigger
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
     where name = 'push_webhook_secret';
  exception when others then
    v_secret := null;
  end;

  select value #>> '{}' into v_url
    from core.app_settings
   where key = 'push_function_url';

  if v_secret is null or v_url is null then
    return new;
  end if;

  perform net.http_post(
    url     := v_url,
    body    := jsonb_build_object(
                  'notification_id',      new.id,
                  'user_id',              new.user_id,
                  'type',                 new.type,
                  'title_ar',             new.title_ar,
                  'title_en',             new.title_en,
                  'body_ar',              new.body_ar,
                  'body_en',              new.body_en,
                  'payload',              new.payload,
                  'related_entity_type',  new.related_entity_type,
                  'related_entity_id',    new.related_entity_id,
                  'created_at',           new.created_at
                ),
    headers := jsonb_build_object(
                  'Content-Type',  'application/json',
                  'x-push-secret', v_secret
                ),
    timeout_milliseconds := 5000
  );

  return new;
exception
  when others then
    -- The in-app record is the source of truth. A push that cannot be
    -- queued must never abort the insert that created the notification.
    return new;
end;
$fn$;

comment on function engagement.dispatch_push_notification() is
  'Queues the notification for the send-push Edge Function. Never fails the insert.';

drop trigger if exists tr_notifications_dispatch_push on engagement.notifications;

create trigger tr_notifications_dispatch_push
  after insert on engagement.notifications
  for each row execute function engagement.dispatch_push_notification();

-- ---------------------------------------------------------------------------
-- Realtime
--
-- The app reads the notifications with a plain select, so a new notification
-- is only visible the next time the screen opens. With the table in the
-- publication the running app is told about it, which is what keeps the
-- unread badge honest.
-- ---------------------------------------------------------------------------
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
-- Grants
-- ---------------------------------------------------------------------------
grant execute on function
  public.register_device_token(text, text, text, text),
  public.unregister_device_token(text),
  public.push_preferences(),
  public.set_push_preferences(boolean, boolean, boolean, boolean, boolean)
  to authenticated;

revoke execute on function
  public.register_device_token(text, text, text, text),
  public.unregister_device_token(text),
  public.push_preferences(),
  public.set_push_preferences(boolean, boolean, boolean, boolean, boolean)
  from public, anon;

revoke execute on function engagement.dispatch_push_notification() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- The effects of 098 and 099, repeated here
-- ---------------------------------------------------------------------------
-- 098 grants the service role write access to the delivery log, and 099
-- creates the `public.push_deliveries` bridge the Edge Function writes
-- through.  Both files run BEFORE this one now (their versions are 098 and
-- 099, this file is 104), so in a replay from scratch they meet a database
-- without the delivery log and skip that part.  The statements are repeated
-- here so the end state is the same in every environment: the delivery log
-- exists, the bridge exists, and the service role may write it.
grant insert, update, delete on table engagement.push_deliveries to service_role;

create or replace view public.push_deliveries with (security_invoker = true) as
  select * from engagement.push_deliveries;

comment on view public.push_deliveries is
  'Bridge to engagement.push_deliveries. Written by the send-push Edge Function.';

grant select on public.push_deliveries to service_role;
revoke all on public.push_deliveries from anon, authenticated;

notify pgrst, 'reload config';
notify pgrst, 'reload schema';
