-- supabase/migrations/219_email_notifications.sql
--
-- WHAT THIS ADDS
--
-- The database half of the mail channel: one switch per customer, one log per
-- delivery, one queue function per notification row, and the one-click
-- unsubscribe write. The Edge Function `send-email` (in supabase/functions) is
-- the piece that reads them.
--
-- APPLY STATE
--
-- Applied to the live project on 2026-10-31 on the owner's instruction and
-- recorded in supabase_migrations.schema_migrations as 219. The remote ledger
-- carries two timestamped versions that no local file matches, so `db push` is
-- not safe on this project: the statements went through the platform query API
-- in the same order this file runs them, then the version was recorded.
--
-- The owner's setup this file depends on, and its state on that date:
--
--   1. The sending domain: NOT DONE. `ofoq.com` is not verified in Resend, so a
--      real send is refused with 403 and the refusal is stored verbatim in
--      engagement.email_deliveries. Until its DNS records exist, no mail leaves.
--   2. The secrets of the function: RESEND_API_KEY, EMAIL_FROM and
--      EMAIL_WEBHOOK_SECRET are set on the project. They live only in function
--      secrets, never in the app and never in a file the repository carries.
--   3. Where the trigger reads its address: core.app_settings.email_function_url
--      and the Vault secret email_webhook_secret were written, and a
--      notification insert then reached the function without any help.
--
-- The unsubscribe rule at the bottom is not reachable through the REST layer
-- from this file alone, because PostgREST publishes only the `public` schema;
-- 220 adds that facade. Until 220, a signed one-click link returned 404.
--
-- Until step 1 exists, every notification behaves exactly as it did before this
-- file: the in-app row is written, and the delivery log records a skip or the
-- provider's refusal.

-- ---------------------------------------------------------------------------
-- 1. The switch: mail is a channel of its own
--
-- push_enabled stays what it is. A customer who wants the order receipt in the
-- mailbox and the promotions nowhere is one row with email_enabled true and
-- promo false; the four type switches are shared with the push because they
-- describe the kind of message, not the way it travels.
-- ---------------------------------------------------------------------------
alter table engagement.notification_preferences
  add column if not exists email_enabled boolean not null default false;

comment on column engagement.notification_preferences.email_enabled is
  'Master gate of the mail channel, independent of push_enabled. False by default: nobody is mailed until they say yes.';

-- The bridge view is `select *`, so the new column is already visible to the
-- function. Recreated only to keep the definition of record next to it.
create or replace view public.notification_preferences
with (security_invoker = true) as
select * from engagement.notification_preferences;

-- ---------------------------------------------------------------------------
-- 2. The log
-- ---------------------------------------------------------------------------
create table if not exists engagement.email_deliveries (
  id                  uuid primary key default extensions.gen_random_uuid(),
  notification_id     uuid references engagement.notifications(id) on delete cascade,
  user_id             uuid not null references identity.profiles(id) on delete cascade,
  status              text not null check (status in ('sent','failed','skipped')),
  error               text,
  created_at          timestamptz not null default now()
);

comment on table engagement.email_deliveries is
  'What the send-email function did with one notification for one customer. Written by the function with the service role.';
comment on column engagement.email_deliveries.error is
  'A skip reason (no_address, email_disabled, type_disabled, email_not_configured) or the short provider answer. Never an address.';

create index if not exists ix_email_deliveries_notification
  on engagement.email_deliveries (notification_id);

create index if not exists ix_email_deliveries_user_created
  on engagement.email_deliveries (user_id, created_at desc);

alter table engagement.email_deliveries enable row level security;

revoke all on table engagement.email_deliveries from anon, authenticated;
grant insert, update, delete on table engagement.email_deliveries to service_role;

create or replace view public.email_deliveries
with (security_invoker = true) as
select * from engagement.email_deliveries;

comment on view public.email_deliveries is
  'Bridge to engagement.email_deliveries. Written by the send-email Edge Function.';

revoke all on public.email_deliveries from anon, authenticated;
grant select, insert, update, delete on public.email_deliveries to service_role;

-- ---------------------------------------------------------------------------
-- 3. The unsubscribe write
--
-- A click from a mail client arrives with no session, so the only thing that
-- may change is this one switch, and it changes through a definer function:
-- the view a request without a session can write is never a general-purpose
-- update door.
-- ---------------------------------------------------------------------------
create or replace function engagement.unsubscribe_email(p_user_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  update engagement.notification_preferences
     set email_enabled = false,
         updated_at    = now()
   where user_id = p_user_id;

  if not found then
    -- No row means the customer never opened a switch, so mail was already
    -- off for them: the answer is honest and nothing is written.
    return false;
  end if;

  return true;
end;
$fn$;

comment on function engagement.unsubscribe_email(uuid) is
  'Turns the mail channel off for one customer. Called by the send-email function for a signed unsubscribe link.';

revoke execute on function engagement.unsubscribe_email(uuid)
  from public, anon, authenticated;
grant execute on function engagement.unsubscribe_email(uuid) to service_role;

-- ---------------------------------------------------------------------------
-- 4. The queue
--
-- The same shape as engagement.enqueue_push: the url comes from
-- core.app_settings, the shared secret from Vault, and a broken configuration
-- returns false instead of aborting the insert that created the notification.
-- ---------------------------------------------------------------------------
create or replace function engagement.enqueue_email(p_notification engagement.notifications)
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
     where name = 'email_webhook_secret'
     limit 1;
  exception when others then
    v_secret := null;
  end;

  select value #>> '{}' into v_url
    from core.app_settings
   where key = 'email_function_url';

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
                  'created_at',          p_notification.created_at
                ),
    headers := jsonb_build_object(
                  'Content-Type',   'application/json',
                  'x-email-secret', v_secret
                ),
    timeout_milliseconds := 5000
  );

  return true;
exception
  when others then
    -- A broken mail configuration must never abort the insert that created
    -- the notification. The in-app row is the source of truth.
    return false;
end;
$fn$;

comment on function engagement.enqueue_email(engagement.notifications) is
  'Queues the mail of one notification through pg_net. Returns false when the mail channel is not configured.';

create or replace function engagement.dispatch_email_notification()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  perform engagement.enqueue_email(new);
  return new;
end;
$fn$;

revoke execute on function engagement.enqueue_email(engagement.notifications)
  from public, anon, authenticated;
revoke execute on function engagement.dispatch_email_notification()
  from public, anon, authenticated;

drop trigger if exists tr_notifications_dispatch_email on engagement.notifications;

create trigger tr_notifications_dispatch_email
  after insert on engagement.notifications
  for each row execute function engagement.dispatch_email_notification();
