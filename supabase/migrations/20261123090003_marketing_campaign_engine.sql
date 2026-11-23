-- Official migration: Marketing Hub P0.6 (derived from approved local proposal
-- supabase/proposals/p05_marketing_campaign_engine.PROPOSED.sql).
-- Purpose: single-cafe campaign lifecycle, versions, segments, snapshots,
-- executions, recipients, attempts, and lifecycle RPCs (create/edit/review/
-- approve/schedule/cancel/pause/resume/list). Legacy engagement.notification_campaigns untouched.
-- Does NOT change legacy engagement.notification_campaigns or admin_send_notification.
-- Tests: supabase/tests/marketing_hub_campaign_test.sql

create table if not exists marketing.campaign_segments (
  id uuid primary key default extensions.gen_random_uuid(),
  name text not null,
  definition jsonb not null,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists marketing.campaigns (
  id uuid primary key default extensions.gen_random_uuid(),
  name text not null,
  channel text not null check (channel in ('push','email','sms','whatsapp')),
  purpose text not null check (purpose in ('promotions','offers','loyalty_marketing')),
  status text not null default 'draft' check (status in (
    'draft','pending_review','approved','scheduled','processing','completed','failed','cancelled')),
  current_version_id uuid,
  approved_version_id uuid,
  segment_id uuid references marketing.campaign_segments(id) on delete restrict,
  scheduled_for timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint ck_campaigns_schedule check (status <> 'scheduled' or scheduled_for is not null)
);

create table if not exists marketing.campaign_versions (
  id uuid primary key default extensions.gen_random_uuid(),
  campaign_id uuid not null references marketing.campaigns(id) on delete cascade,
  version_no integer not null check (version_no > 0),
  version_status text not null default 'draft' check (version_status in (
    'draft','pending_review','approved','superseded')),
  title_ar text not null,
  title_en text not null,
  body_ar text not null,
  body_en text not null,
  payload jsonb not null default '{}'::jsonb,
  image_url text,
  destination text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (campaign_id, version_no)
);

alter table marketing.campaigns
  add constraint fk_campaigns_current_version
  foreign key (current_version_id)
  references marketing.campaign_versions(id) on delete restrict;

alter table marketing.campaigns
  add constraint fk_campaigns_approved_version
  foreign key (approved_version_id)
  references marketing.campaign_versions(id) on delete restrict;

create table if not exists marketing.campaign_snapshots (
  id uuid primary key default extensions.gen_random_uuid(),
  campaign_id uuid not null references marketing.campaigns(id) on delete cascade,
  campaign_version_id uuid not null references marketing.campaign_versions(id) on delete restrict,
  segment_id uuid references marketing.campaign_segments(id) on delete restrict,
  definition jsonb not null,
  capture_key text not null unique,
  recipient_total integer not null default 0 check (recipient_total >= 0),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists marketing.campaign_executions (
  id uuid primary key default extensions.gen_random_uuid(),
  campaign_id uuid not null references marketing.campaigns(id) on delete cascade,
  campaign_version_id uuid not null references marketing.campaign_versions(id) on delete restrict,
  snapshot_id uuid not null references marketing.campaign_snapshots(id) on delete restrict,
  status text not null default 'queued' check (status in (
    'queued','running','paused','completed','failed','cancelled')),
  scheduled_for timestamptz not null,
  idempotency_key text not null unique,
  total_recipients integer not null default 0 check (total_recipients >= 0),
  processed_count integer not null default 0 check (processed_count >= 0),
  sent_count integer not null default 0 check (sent_count >= 0),
  skipped_count integer not null default 0 check (skipped_count >= 0),
  failed_count integer not null default 0 check (failed_count >= 0),
  unknown_count integer not null default 0 check (unknown_count >= 0),
  lease_owner text,
  lease_until timestamptz,
  started_at timestamptz,
  finished_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists marketing.campaign_recipients (
  id uuid primary key default extensions.gen_random_uuid(),
  execution_id uuid not null references marketing.campaign_executions(id) on delete cascade,
  campaign_id uuid not null references marketing.campaigns(id) on delete cascade,
  user_id uuid not null references identity.profiles(id) on delete cascade,
  channel text not null check (channel in ('push','email','sms','whatsapp')),
  purpose text not null check (purpose in ('promotions','offers','loyalty_marketing')),
  consent_status_at_capture text not null check (consent_status_at_capture in ('granted','revoked','missing')),
  eligibility_status text not null check (eligibility_status in (
    'eligible','suppressed_consent','suppressed_channel','no_device','no_address','email_not_verified','duplicate','cancelled')),
  dispatch_status text not null default 'pending' check (dispatch_status in (
    'pending','queued','sent','skipped','failed','unknown','cancelled')),
  notification_id uuid references engagement.notifications(id) on delete set null,
  -- Dedupe key is per-execution, never global across campaign versions.
  -- Format: campaign:{campaign_id}:{approved_version_id}:{execution_id}:{user_id}:{channel}
  -- A new approved version creates a new execution_id and therefore a new dedupe_key,
  -- so it is not blocked by a previous version's send.
  dedupe_key text not null unique,
  attempt_count integer not null default 0 check (attempt_count >= 0),
  next_attempt_at timestamptz,
  processed_at timestamptz,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (execution_id, user_id, channel)
);

create table if not exists marketing.campaign_attempts (
  id uuid primary key default extensions.gen_random_uuid(),
  execution_id uuid not null references marketing.campaign_executions(id) on delete cascade,
  recipient_id uuid not null references marketing.campaign_recipients(id) on delete cascade,
  channel text not null check (channel in ('push','email','sms','whatsapp')),
  attempt_number integer not null check (attempt_number > 0),
  status text not null default 'queued' check (status in (
    'queued','sent','failed','skipped','unknown')),
  provider_request_id text,
  provider_status text,
  provider_message_id text,
  push_delivery_id uuid references engagement.push_deliveries(id) on delete set null,
  email_delivery_id uuid references engagement.email_deliveries(id) on delete set null,
  retryable boolean not null default false,
  error_code text,
  error_detail text,
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  unique (execution_id, recipient_id, attempt_number)
);

create index if not exists ix_campaigns_status_updated
  on marketing.campaigns (status, updated_at desc);

create index if not exists ix_campaign_executions_queue
  on marketing.campaign_executions (status, scheduled_for)
  where status in ('queued','running','paused');

create index if not exists ix_campaign_recipients_execution_dispatch
  on marketing.campaign_recipients (execution_id, dispatch_status, created_at);

create index if not exists ix_campaign_recipients_user
  on marketing.campaign_recipients (user_id, created_at desc);

create index if not exists ix_campaign_attempts_execution_time
  on marketing.campaign_attempts (execution_id, started_at desc);

alter table marketing.campaign_segments enable row level security;
alter table marketing.campaigns enable row level security;
alter table marketing.campaign_versions enable row level security;
alter table marketing.campaign_snapshots enable row level security;
alter table marketing.campaign_executions enable row level security;
alter table marketing.campaign_recipients enable row level security;
alter table marketing.campaign_attempts enable row level security;

revoke all on marketing.campaign_segments, marketing.campaigns,
  marketing.campaign_versions, marketing.campaign_snapshots,
  marketing.campaign_executions, marketing.campaign_recipients,
  marketing.campaign_attempts
from public, anon, authenticated;

grant select on marketing.campaign_segments, marketing.campaigns,
  marketing.campaign_versions, marketing.campaign_snapshots,
  marketing.campaign_executions, marketing.campaign_recipients,
  marketing.campaign_attempts
to authenticated;

grant select, insert, update, delete on marketing.campaign_segments,
  marketing.campaigns, marketing.campaign_versions, marketing.campaign_snapshots,
  marketing.campaign_executions, marketing.campaign_recipients,
  marketing.campaign_attempts
to service_role;

create policy campaign_segments_read on marketing.campaign_segments
  for select to authenticated
  using (identity.has_permission('marketing.read'));

create policy campaigns_read on marketing.campaigns
  for select to authenticated
  using (identity.has_permission('marketing.read'));

create policy campaign_versions_read on marketing.campaign_versions
  for select to authenticated
  using (identity.has_permission('marketing.read'));

create policy campaign_snapshots_read on marketing.campaign_snapshots
  for select to authenticated
  using (identity.has_permission('marketing.read'));

create policy campaign_executions_read on marketing.campaign_executions
  for select to authenticated
  using (identity.has_permission('marketing.read'));

create policy campaign_recipients_read on marketing.campaign_recipients
  for select to authenticated
  using (identity.has_permission('marketing.read'));

create policy campaign_attempts_read on marketing.campaign_attempts
  for select to authenticated
  using (identity.has_permission('marketing.read'));

-- ---------------------------------------------------------------------------
-- Campaign lifecycle RPCs. All are SECURITY DEFINER, set search_path = '',
-- permission-checked, row-locked, audited. No client may call the worker.
-- ---------------------------------------------------------------------------

create or replace function marketing.list_campaigns()
returns jsonb
language plpgsql stable security definer set search_path = ''
as $fn$
begin
  if not identity.has_permission('marketing.read') then
    raise exception 'missing permission: marketing.read' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', c.id, 'name', c.name, 'channel', c.channel, 'purpose', c.purpose,
      'status', c.status, 'current_version_id', c.current_version_id,
      'approved_version_id', c.approved_version_id,
      'segment_id', c.segment_id, 'scheduled_for', c.scheduled_for,
      'created_by', c.created_by, 'created_at', c.created_at,
      'updated_at', c.updated_at,
      'recipient_total', coalesce((
        select sum(e.total_recipients) from marketing.campaign_executions e
         where e.campaign_id = c.id), 0),
      'sent_total', coalesce((
        select sum(e.sent_count) from marketing.campaign_executions e
         where e.campaign_id = c.id), 0)
    ) order by c.created_at desc)
    from marketing.campaigns c
  ), '[]'::jsonb);
end;
$fn$;

create or replace function marketing.get_campaign(p_campaign_id uuid)
returns jsonb
language plpgsql stable security definer set search_path = ''
as $fn$
declare v jsonb;
begin
  if not identity.has_permission('marketing.read') then
    raise exception 'missing permission: marketing.read' using errcode = '42501';
  end if;
  select to_jsonb(c) into v from marketing.campaigns c where c.id = p_campaign_id;
  if v is null then raise exception 'campaign not found' using errcode = 'P0002'; end if;
  return v || jsonb_build_object(
    'current_version', (select to_jsonb(vv) from marketing.campaign_versions vv where vv.id = c.current_version_id),
    'approved_version', (select to_jsonb(vv) from marketing.campaign_versions vv where vv.id = c.approved_version_id),
    'executions', coalesce((select jsonb_agg(to_jsonb(e) order by e.created_at desc)
      from marketing.campaign_executions e where e.campaign_id = c.id), '[]'::jsonb));
end;
$fn$;

create or replace function marketing.create_campaign(
  p_name text, p_channel text, p_purpose text, p_segment_id uuid default null
) returns uuid
language plpgsql security definer set search_path = ''
as $fn$
declare v_id uuid;
begin
  if not identity.has_permission('marketing.create') then
    raise exception 'missing permission: marketing.create' using errcode = '42501';
  end if;
  if nullif(trim(p_name), '') is null
     or p_channel not in ('push','email','sms','whatsapp')
     or p_purpose not in ('promotions','offers','loyalty_marketing') then
    raise exception 'invalid campaign payload' using errcode = '22023';
  end if;
  insert into marketing.campaigns (name, channel, purpose, segment_id, created_by)
  values (trim(p_name), p_channel, p_purpose, p_segment_id, auth.uid())
  returning id into v_id;
  perform identity.audit('marketing.campaign.create', 'marketing.campaign', v_id, null,
    jsonb_build_object('name', trim(p_name), 'channel', p_channel, 'purpose', p_purpose));
  return v_id;
end;
$fn$;

create or replace function marketing.create_campaign_version(
  p_campaign_id uuid, p_title_ar text, p_title_en text,
  p_body_ar text, p_body_en text,
  p_payload jsonb default '{}'::jsonb,
  p_image_url text default null, p_destination text default null
) returns uuid
language plpgsql security definer set search_path = ''
as $fn$
declare
  v_campaign record;
  v_id uuid;
  v_no integer;
begin
  if not identity.has_permission('marketing.create') then
    raise exception 'missing permission: marketing.create' using errcode = '42501';
  end if;
  select * into v_campaign from marketing.campaigns where id = p_campaign_id for update;
  if not found then raise exception 'campaign not found' using errcode = 'P0002'; end if;
  if v_campaign.status in ('scheduled','processing') then
    raise exception 'campaign is locked by an execution' using errcode = '42501';
  end if;
  if nullif(trim(p_title_ar), '') is null or nullif(trim(p_title_en), '') is null
     or nullif(trim(p_body_ar), '') is null or nullif(trim(p_body_en), '') is null then
    raise exception 'campaign content is incomplete' using errcode = '22023';
  end if;
  select coalesce(max(version_no), 0) + 1 into v_no
    from marketing.campaign_versions where campaign_id = p_campaign_id;
  insert into marketing.campaign_versions
    (campaign_id, version_no, version_status, title_ar, title_en, body_ar, body_en,
     payload, image_url, destination, created_by)
  values (p_campaign_id, v_no, 'draft', trim(p_title_ar), trim(p_title_en),
          trim(p_body_ar), trim(p_body_en), coalesce(p_payload, '{}'::jsonb),
          p_image_url, p_destination, auth.uid())
  returning id into v_id;
  -- New draft supersedes any schedule context; approved_version_id remains
  -- as history but schedule requires status = 'approved' (re-approval).
  update marketing.campaigns
     set current_version_id = v_id, status = 'draft', scheduled_for = null, updated_at = now()
   where id = p_campaign_id;
  perform identity.audit('marketing.campaign.create_version', 'marketing.campaign', p_campaign_id,
    null, jsonb_build_object('version_id', v_id, 'version_no', v_no));
  return v_id;
end;
$fn$;

create or replace function marketing.submit_campaign_for_review(p_campaign_id uuid)
returns void language plpgsql security definer set search_path = ''
as $fn$
begin
  if not identity.has_permission('marketing.create') then
    raise exception 'missing permission: marketing.create' using errcode = '42501';
  end if;
  update marketing.campaign_versions vv
     set version_status = 'pending_review'
    from marketing.campaigns c
   where c.id = p_campaign_id and vv.id = c.current_version_id and c.status = 'draft';
  if not found then raise exception 'only draft campaigns can be submitted' using errcode = '22023'; end if;
  update marketing.campaigns set status = 'pending_review', updated_at = now()
   where id = p_campaign_id;
  perform identity.audit('marketing.campaign.submit_review', 'marketing.campaign', p_campaign_id, null, null);
end;
$fn$;

create or replace function marketing.approve_campaign(p_campaign_id uuid)
returns void language plpgsql security definer set search_path = ''
as $fn$
declare v record;
begin
  if not identity.has_permission('marketing.review') then
    raise exception 'missing permission: marketing.review' using errcode = '42501';
  end if;
  select * into v from marketing.campaigns where id = p_campaign_id for update;
  if not found then raise exception 'campaign not found' using errcode = 'P0002'; end if;
  if v.created_by = auth.uid() then
    raise exception 'creator cannot approve their own campaign' using errcode = '42501';
  end if;
  if v.status <> 'pending_review' then
    raise exception 'only pending_review campaigns can be approved' using errcode = '22023';
  end if;
  update marketing.campaign_versions set version_status = 'superseded'
   where campaign_id = p_campaign_id and version_status = 'approved';
  update marketing.campaign_versions set version_status = 'approved'
   where id = v.current_version_id;
  update marketing.campaigns
     set status = 'approved', approved_version_id = current_version_id,
         reviewed_by = auth.uid(), reviewed_at = now(), updated_at = now()
   where id = p_campaign_id;
  perform identity.audit('marketing.campaign.approve', 'marketing.campaign', p_campaign_id, null,
    jsonb_build_object('approved_version_id', v.current_version_id));
end;
$fn$;

create or replace function marketing.return_campaign_to_draft(
  p_campaign_id uuid, p_reason text default null
) returns void language plpgsql security definer set search_path = ''
as $fn$
begin
  if not identity.has_permission('marketing.review') then
    raise exception 'missing permission: marketing.review' using errcode = '42501';
  end if;
  update marketing.campaign_versions vv
     set version_status = 'draft'
    from marketing.campaigns c
   where c.id = p_campaign_id and vv.id = c.current_version_id and c.status = 'pending_review';
  if not found then raise exception 'only pending_review campaigns can be returned' using errcode = '22023'; end if;
  update marketing.campaigns set status = 'draft', updated_at = now() where id = p_campaign_id;
  perform identity.audit('marketing.campaign.return_to_draft', 'marketing.campaign', p_campaign_id,
    null, jsonb_build_object('reason', p_reason));
end;
$fn$;

create or replace function marketing.schedule_campaign(
  p_campaign_id uuid, p_scheduled_for timestamptz
) returns uuid
language plpgsql security definer set search_path = ''
as $fn$
declare
  v record;
  v_execution uuid;
  v_snapshot uuid;
  v_total integer;
begin
  if not identity.has_permission('marketing.schedule') then
    raise exception 'missing permission: marketing.schedule' using errcode = '42501';
  end if;
  if p_scheduled_for is null or p_scheduled_for < now() then
    raise exception 'scheduled_for must be in the future' using errcode = '22023';
  end if;
  select * into v from marketing.campaigns where id = p_campaign_id for update;
  if not found then raise exception 'campaign not found' using errcode = 'P0002'; end if;
  if v.status <> 'approved' or v.approved_version_id is null then
    raise exception 'only approved campaigns can be scheduled' using errcode = '22023';
  end if;
  -- Idempotent: scheduling the same approved version returns the existing execution.
  select e.id into v_execution from marketing.campaign_executions e
   where e.campaign_id = p_campaign_id and e.campaign_version_id = v.approved_version_id;
  if v_execution is not null then
    return v_execution;
  end if;
  -- Freeze audience snapshot: every profile with consent/eligibility evidence.
  insert into marketing.campaign_snapshots
    (campaign_id, campaign_version_id, segment_id, definition, capture_key, created_by)
  values (p_campaign_id, v.approved_version_id, v.segment_id,
          coalesce((select s.definition from marketing.campaign_segments s where s.id = v.segment_id), '{}'::jsonb),
          'snapshot:' || p_campaign_id::text || ':' || v.approved_version_id::text,
          auth.uid())
  on conflict (capture_key) do nothing
  returning id into v_snapshot;
  if v_snapshot is null then
    select s.id into v_snapshot from marketing.campaign_snapshots s
     where s.capture_key = 'snapshot:' || p_campaign_id::text || ':' || v.approved_version_id::text;
  end if;
  insert into marketing.campaign_executions
    (campaign_id, campaign_version_id, snapshot_id, status, scheduled_for,
     idempotency_key, total_recipients)
  values (p_campaign_id, v.approved_version_id, v_snapshot, 'queued', p_scheduled_for,
          'campaign:' || p_campaign_id::text || ':' || v.approved_version_id::text, 0)
  on conflict (idempotency_key) do nothing
  returning id into v_execution;
  if v_execution is null then
    select e.id into v_execution from marketing.campaign_executions e
     where e.idempotency_key = 'campaign:' || p_campaign_id::text || ':' || v.approved_version_id::text;
    return v_execution;
  end if;
  insert into marketing.campaign_recipients
    (execution_id, campaign_id, user_id, channel, purpose,
     consent_status_at_capture, eligibility_status, dedupe_key)
  select v_execution, p_campaign_id, p.id, v.channel, v.purpose,
         coalesce((select s.status from marketing.consent_states s
                    where s.user_id = p.id and s.channel = v.channel and s.purpose = v.purpose), 'missing'),
         case when marketing.is_marketing_deliverable_internal(p.id, v.channel, v.purpose)
           then 'eligible' else 'suppressed_consent' end,
         'campaign:' || p_campaign_id::text || ':' || v.approved_version_id::text || ':'
           || v_execution::text || ':' || p.id::text || ':' || v.channel
    from identity.profiles p;
  get diagnostics v_total = row_count;
  update marketing.campaign_executions set total_recipients = v_total, updated_at = now()
   where id = v_execution;
  update marketing.campaign_snapshots set recipient_total = v_total where id = v_snapshot;
  update marketing.campaigns set status = 'scheduled', scheduled_for = p_scheduled_for, updated_at = now()
   where id = p_campaign_id;
  perform identity.audit('marketing.campaign.schedule', 'marketing.campaign', p_campaign_id, null,
    jsonb_build_object('execution_id', v_execution, 'scheduled_for', p_scheduled_for, 'recipients', v_total));
  return v_execution;
end;
$fn$;

create or replace function marketing.cancel_campaign(p_campaign_id uuid)
returns void language plpgsql security definer set search_path = ''
as $fn$
begin
  if not identity.has_permission('marketing.send') then
    raise exception 'missing permission: marketing.send' using errcode = '42501';
  end if;
  update marketing.campaign_executions
     set status = 'cancelled', lease_until = null, finished_at = now(), updated_at = now()
   where campaign_id = p_campaign_id and status = 'queued';
  update marketing.campaign_recipients r
     set dispatch_status = 'cancelled', eligibility_status = 'cancelled', updated_at = now()
    from marketing.campaign_executions e
   where e.id = r.execution_id and e.campaign_id = p_campaign_id
     and e.status = 'cancelled' and r.dispatch_status = 'pending';
  update marketing.campaigns
     set status = 'cancelled', scheduled_for = null, updated_at = now()
   where id = p_campaign_id and status in ('draft','pending_review','approved','scheduled');
  if not found then raise exception 'campaign cannot be cancelled now' using errcode = '22023'; end if;
  perform identity.audit('marketing.campaign.cancel', 'marketing.campaign', p_campaign_id, null, null);
end;
$fn$;

create or replace function marketing.pause_execution(p_execution_id uuid)
returns void language plpgsql security definer set search_path = ''
as $fn$
begin
  if not identity.has_permission('marketing.send') then
    raise exception 'missing permission: marketing.send' using errcode = '42501';
  end if;
  update marketing.campaign_executions set status = 'paused', updated_at = now()
   where id = p_execution_id and status = 'running';
  if not found then raise exception 'only running executions can be paused' using errcode = '22023'; end if;
  perform identity.audit('marketing.execution.pause', 'marketing.execution', p_execution_id, null, null);
end;
$fn$;

create or replace function marketing.resume_execution(p_execution_id uuid)
returns void language plpgsql security definer set search_path = ''
as $fn$
begin
  if not identity.has_permission('marketing.send') then
    raise exception 'missing permission: marketing.send' using errcode = '42501';
  end if;
  update marketing.campaign_executions
     set status = 'queued', lease_owner = null, lease_until = null, updated_at = now()
   where id = p_execution_id and status = 'paused';
  if not found then raise exception 'only paused executions can be resumed' using errcode = '22023'; end if;
  perform identity.audit('marketing.execution.resume', 'marketing.execution', p_execution_id, null, null);
end;
$fn$;

create or replace function marketing.list_campaign_recipients(
  p_execution_id uuid, p_limit integer default 200
) returns jsonb
language plpgsql stable security definer set search_path = ''
as $fn$
begin
  if not identity.has_permission('marketing.read') then
    raise exception 'missing permission: marketing.read' using errcode = '42501';
  end if;
  return coalesce((select jsonb_agg(to_jsonb(r) order by r.created_at)
    from (select * from marketing.campaign_recipients
           where execution_id = p_execution_id
           order by created_at limit least(greatest(coalesce(p_limit, 200), 1), 1000)) r
  ), '[]'::jsonb);
end;
$fn$;

create or replace function marketing.list_campaign_attempts(p_execution_id uuid)
returns jsonb
language plpgsql stable security definer set search_path = ''
as $fn$
begin
  if not identity.has_permission('marketing.read') then
    raise exception 'missing permission: marketing.read' using errcode = '42501';
  end if;
  return coalesce((select jsonb_agg(to_jsonb(a) order by a.started_at desc)
    from marketing.campaign_attempts a where a.execution_id = p_execution_id
  ), '[]'::jsonb);
end;
$fn$;

-- RPC grants: authenticated may call; each function re-checks its permission.
revoke all on function marketing.list_campaigns() from public, anon;
grant execute on function marketing.list_campaigns() to authenticated;
revoke all on function marketing.get_campaign(uuid) from public, anon;
grant execute on function marketing.get_campaign(uuid) to authenticated;
revoke all on function marketing.create_campaign(text, text, text, uuid) from public, anon;
grant execute on function marketing.create_campaign(text, text, text, uuid) to authenticated;
revoke all on function marketing.create_campaign_version(uuid, text, text, text, text, jsonb, text, text) from public, anon;
grant execute on function marketing.create_campaign_version(uuid, text, text, text, text, jsonb, text, text) to authenticated;
revoke all on function marketing.submit_campaign_for_review(uuid) from public, anon;
grant execute on function marketing.submit_campaign_for_review(uuid) to authenticated;
revoke all on function marketing.approve_campaign(uuid) from public, anon;
grant execute on function marketing.approve_campaign(uuid) to authenticated;
revoke all on function marketing.return_campaign_to_draft(uuid, text) from public, anon;
grant execute on function marketing.return_campaign_to_draft(uuid, text) to authenticated;
revoke all on function marketing.schedule_campaign(uuid, timestamptz) from public, anon;
grant execute on function marketing.schedule_campaign(uuid, timestamptz) to authenticated;
revoke all on function marketing.cancel_campaign(uuid) from public, anon;
grant execute on function marketing.cancel_campaign(uuid) to authenticated;
revoke all on function marketing.pause_execution(uuid) from public, anon;
grant execute on function marketing.pause_execution(uuid) to authenticated;
revoke all on function marketing.resume_execution(uuid) from public, anon;
grant execute on function marketing.resume_execution(uuid) to authenticated;
revoke all on function marketing.list_campaign_recipients(uuid, integer) from public, anon;
grant execute on function marketing.list_campaign_recipients(uuid, integer) to authenticated;
revoke all on function marketing.list_campaign_attempts(uuid) from public, anon;
grant execute on function marketing.list_campaign_attempts(uuid) to authenticated;

-- RPC contracts are implemented above as SECURITY DEFINER functions. They:
--   * use identity.has_permission(...)
--   * lock campaigns FOR UPDATE on transitions
--   * call identity.audit for every state change
--   * never mutate an approved version
--   * make schedule_campaign idempotent for the same approved version
--   * keep legacy engagement.notification_campaigns untouched.
