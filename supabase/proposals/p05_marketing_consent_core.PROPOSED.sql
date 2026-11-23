-- SUPERSEDED: official migration is supabase/migrations/*.sql (P0.7, applied). This proposal is now a historical reference only.
-- P0.5 LOCAL PROPOSAL ONLY. Do NOT apply without separate approval.
-- File: p05_marketing_consent_core.PROPOSED.sql
-- Purpose: explicit marketing consent for Push/Email. SMS/WhatsApp tables are
-- modeled but delivery remains disabled.
-- Dependencies: 003 profiles, 016 notification_preferences/device_tokens,
--   018 identity.has_permission, 023 schema USAGE on marketing.
-- Scope: marketing.consent_events + marketing.consent_states.
-- Rollback: disable new RPCs/UI; export events/states privately before any
--   object removal. Do not delete append-only events as rollback.
-- Tests: supabase/tests/marketing_hub_consent_test.sql

create table if not exists marketing.consent_events (
  event_id     uuid primary key default extensions.gen_random_uuid(),
  event_seq    bigint generated always as identity,
  user_id      uuid not null references identity.profiles(id) on delete cascade,
  channel      text not null check (channel in ('push','email','sms','whatsapp')),
  purpose      text not null check (purpose in ('promotions','offers','loyalty_marketing')),
  action       text not null check (action in ('granted','revoked')),
  source       text not null check (source in (
                 'in_app_settings','registration','checkout',
                 'admin_support','import','system')),
  recorded_by  uuid references auth.users(id) on delete set null,
  metadata     jsonb not null default '{}'::jsonb,
  created_at   timestamptz not null default now()
);

create index if not exists ix_consent_events_user_key_seq
  on marketing.consent_events (user_id, channel, purpose, event_seq desc);

create index if not exists ix_consent_events_channel_purpose_time
  on marketing.consent_events (channel, purpose, created_at desc, event_seq desc);

create table if not exists marketing.consent_states (
  user_id        uuid not null references identity.profiles(id) on delete cascade,
  channel        text not null check (channel in ('push','email','sms','whatsapp')),
  purpose        text not null check (purpose in ('promotions','offers','loyalty_marketing')),
  status         text not null check (status in ('granted','revoked')),
  last_event_id  uuid not null references marketing.consent_events(event_id) on delete restrict,
  last_event_seq bigint not null,
  updated_at     timestamptz not null default now(),
  primary key (user_id, channel, purpose)
);

create index if not exists ix_consent_states_channel_purpose_status
  on marketing.consent_states (channel, purpose, status, user_id);

-- Trigger backstop: duplicates the monotonic upsert logic inline so it does
-- not depend on a callable helper function.
create or replace function marketing.apply_consent_state()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  insert into marketing.consent_states
    (user_id, channel, purpose, status, last_event_id, last_event_seq, updated_at)
  values
    (new.user_id, new.channel, new.purpose,
     case when new.action = 'granted' then 'granted' else 'revoked' end,
     new.event_id, new.event_seq, now())
  on conflict (user_id, channel, purpose)
  do update
     set status = excluded.status,
         last_event_id = excluded.last_event_id,
         last_event_seq = excluded.last_event_seq,
         updated_at = now()
   where excluded.last_event_seq > marketing.consent_states.last_event_seq;
  return null;
end;
$fn$;

drop trigger if exists tr_consent_events_apply_state on marketing.consent_events;
create trigger tr_consent_events_apply_state
  after insert on marketing.consent_events
  for each row execute function marketing.apply_consent_state();

-- Trusted recorder. Service-role/internal only; never granted to clients.
create or replace function marketing.record_consent_event_trusted(
  p_user_id uuid,
  p_channel text,
  p_purpose text,
  p_action text,
  p_source text,
  p_recorded_by uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_event uuid;
  v_seq bigint;
begin
  if p_user_id is null
     or p_channel not in ('push','email','sms','whatsapp')
     or p_purpose not in ('promotions','offers','loyalty_marketing')
     or p_action not in ('granted','revoked')
     or p_source not in ('in_app_settings','registration','checkout','admin_support','import','system')
  then
    raise exception 'invalid consent event' using errcode = '22023';
  end if;

  perform pg_advisory_xact_lock(hashtext(p_user_id::text || ':' || p_channel || ':' || p_purpose));

  insert into marketing.consent_events
    (user_id, channel, purpose, action, source, recorded_by)
  values
    (p_user_id, p_channel, p_purpose, p_action, p_source,
     coalesce(p_recorded_by, auth.uid()))
  returning event_id, event_seq into v_event, v_seq;

  insert into marketing.consent_states
    (user_id, channel, purpose, status, last_event_id, last_event_seq, updated_at)
  values
    (p_user_id, p_channel, p_purpose,
     case when p_action = 'granted' then 'granted' else 'revoked' end,
     v_event, v_seq, now())
  on conflict (user_id, channel, purpose)
  do update
     set status = excluded.status,
         last_event_id = excluded.last_event_id,
         last_event_seq = excluded.last_event_seq,
         updated_at = now()
   where excluded.last_event_seq > marketing.consent_states.last_event_seq;

  perform identity.audit(
    case when p_action = 'granted' then 'marketing.consent.grant' else 'marketing.consent.revoke' end,
    'marketing.consent',
    v_event,
    null,
    jsonb_build_object(
      'user_id', p_user_id,
      'channel', p_channel,
      'purpose', p_purpose,
      'source', p_source,
      'event_seq', v_seq
    )
  );

  return v_event;
end;
$fn$;

-- Customer wrapper: fixed user, fixed source, no user_id/source parameters.
create or replace function public.set_my_marketing_consent(
  p_channel text,
  p_purpose text,
  p_granted boolean
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if auth.uid() is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  return marketing.record_consent_event_trusted(
    auth.uid(), p_channel, p_purpose,
    case when coalesce(p_granted, false) then 'granted' else 'revoked' end,
    'in_app_settings', null);
end;
$fn$;

create or replace function public.my_marketing_consents()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $fn$
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'channel', channel,
      'purpose', purpose,
      'status', status,
      'updated_at', updated_at
    ) order by channel, purpose
  ), '[]'::jsonb)
  from marketing.consent_states
  where user_id = auth.uid()
$fn$;

create or replace function public.admin_marketing_consents(p_user_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
begin
  if not identity.has_permission('marketing.consent.read') then
    raise exception 'missing permission: marketing.consent.read' using errcode = '42501';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'channel', channel,
      'purpose', purpose,
      'status', status,
      'last_event_seq', last_event_seq,
      'updated_at', updated_at
    ) order by channel, purpose)
    from marketing.consent_states
    where user_id = p_user_id
  ), '[]'::jsonb);
end;
$fn$;

-- Internal-only checks. Not exposed to authenticated.
create or replace function marketing.is_marketing_consented_internal(
  p_user_id uuid, p_channel text, p_purpose text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $fn$
  select coalesce((
    select status = 'granted'
      from marketing.consent_states
     where user_id = p_user_id
       and channel = p_channel
       and purpose = p_purpose
  ), false)
$fn$;

create or replace function marketing.marketing_channel_enabled_internal(
  p_user_id uuid, p_channel text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $fn$
  select case p_channel
    when 'push' then exists (
      select 1
        from engagement.notification_preferences pref
        join engagement.device_tokens tok on tok.user_id = pref.user_id
       where pref.user_id = p_user_id
         and pref.push_enabled
         and nullif(trim(tok.token), '') is not null
         and tok.last_seen_at > now() - interval '90 days'
    )
    when 'email' then exists (
      select 1
        from identity.profiles p
        join engagement.notification_preferences pref on pref.user_id = p.id
        join auth.users u on u.id = p.id
       where p.id = p_user_id
         and nullif(trim(p.email), '') is not null
         and lower(u.email) = lower(p.email)
         and u.email_confirmed_at is not null
         and pref.email_enabled
    )
    else false
  end
$fn$;

create or replace function marketing.is_marketing_deliverable_internal(
  p_user_id uuid, p_channel text, p_purpose text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $fn$
  select marketing.is_marketing_consented_internal(p_user_id, p_channel, p_purpose)
     and marketing.marketing_channel_enabled_internal(p_user_id, p_channel)
$fn$;

alter table marketing.consent_events enable row level security;
alter table marketing.consent_states enable row level security;

grant usage on schema marketing to authenticated;
revoke all on marketing.consent_events from public, anon;
revoke all on marketing.consent_states from public, anon;

grant select on marketing.consent_events to authenticated;
grant select on marketing.consent_states to authenticated;
grant select, insert, update, delete on marketing.consent_events to service_role;
grant select, insert, update, delete on marketing.consent_states to service_role;
revoke update, delete on marketing.consent_events from authenticated;

create policy consent_events_select_own on marketing.consent_events
  for select to authenticated
  using (user_id = auth.uid());

create policy consent_events_select_staff on marketing.consent_events
  for select to authenticated
  using (identity.has_permission('marketing.consent.read'));

create policy consent_states_select_own on marketing.consent_states
  for select to authenticated
  using (user_id = auth.uid());

create policy consent_states_select_staff on marketing.consent_states
  for select to authenticated
  using (identity.has_permission('marketing.consent.read'));

-- Security Definer closure: no client EXECUTE on internal functions.
revoke all on function marketing.apply_consent_state()
  from public, anon, authenticated;
revoke all on function marketing.record_consent_event_trusted(uuid, text, text, text, text, uuid)
  from public, anon, authenticated;
revoke all on function marketing.is_marketing_consented_internal(uuid, text, text)
  from public, anon, authenticated;
revoke all on function marketing.marketing_channel_enabled_internal(uuid, text)
  from public, anon, authenticated;
revoke all on function marketing.is_marketing_deliverable_internal(uuid, text, text)
  from public, anon, authenticated;

grant execute on function marketing.record_consent_event_trusted(uuid, text, text, text, text, uuid)
  to service_role;
grant execute on function marketing.is_marketing_consented_internal(uuid, text, text) to service_role;
grant execute on function marketing.marketing_channel_enabled_internal(uuid, text) to service_role;
grant execute on function marketing.is_marketing_deliverable_internal(uuid, text, text) to service_role;

revoke all on function public.set_my_marketing_consent(text, text, boolean) from public, anon;
grant execute on function public.set_my_marketing_consent(text, text, boolean) to authenticated;

revoke all on function public.my_marketing_consents() from public, anon;
grant execute on function public.my_marketing_consents() to authenticated;

revoke all on function public.admin_marketing_consents(uuid) from public, anon;
grant execute on function public.admin_marketing_consents(uuid) to authenticated;

notify pgrst, 'reload schema';
