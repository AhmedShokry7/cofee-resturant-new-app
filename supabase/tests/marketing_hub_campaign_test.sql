-- P0.5 LOCAL TEST ONLY. Run in isolated non-production DB, never remote.
-- Requires p05_marketing_campaign_engine.PROPOSED.sql.

\set ON_ERROR_STOP on

select case when (select count(*) from marketing.campaigns where status not in (
  'draft','pending_review','approved','scheduled','processing','completed','failed','cancelled')) = 0
  then 'PASS campaign status vocabulary'
  else 'FAIL invalid campaign status' end as campaign_status;

select case when (select count(*) from marketing.campaign_executions where status not in (
  'queued','running','paused','completed','failed','cancelled')) = 0
  then 'PASS execution status vocabulary'
  else 'FAIL invalid execution status' end as execution_status;

select case when (select count(*) from marketing.campaign_recipients where dispatch_status not in (
  'pending','queued','sent','skipped','failed','unknown','cancelled')) = 0
  then 'PASS recipient dispatch vocabulary'
  else 'FAIL invalid dispatch status' end as recipient_status;

select case when (select count(*) from marketing.campaign_attempts where status not in (
  'queued','sent','failed','skipped','unknown')) = 0
  then 'PASS attempt status vocabulary'
  else 'FAIL invalid attempt status' end as attempt_status;

-- Idempotency keys must be unique in the schema.
select case when exists (
  select 1 from pg_constraint
   where conname = 'campaign_executions_idempotency_key_key'
     and conrelid = 'marketing.campaign_executions'::regclass
) then 'PASS execution idempotency unique'
else 'FAIL execution idempotency unique missing' end as exec_idempotency;

select case when exists (
  select 1 from pg_constraint
   where conname = 'campaign_recipients_dedupe_key_key'
     and conrelid = 'marketing.campaign_recipients'::regclass
) then 'PASS recipient dedupe unique'
else 'FAIL recipient dedupe unique missing' end as recipient_dedupe;

-- Dedupe must distinguish execution/version, not campaign-global.
-- Bad (old): campaign:{campaign_id}:{user_id}:{channel}
-- Good: campaign:{campaign_id}:{approved_version_id}:{execution_id}:{user_id}:{channel}
select case when not exists (
  select 1 from marketing.campaign_recipients
   where dedupe_key !~ '^campaign:[0-9a-f-]{36}:[0-9a-f-]{36}:[0-9a-f-]{36}:[0-9a-f-]{36}:(push|email|sms|whatsapp)$'
) then 'PASS dedupe keys include campaign/version/execution/user/channel'
else 'FAIL dedupe key format does not include version/execution' end as dedupe_format;

-- A second recipient for the same execution+user+channel must be impossible:
select case when exists (
  select 1 from pg_constraint
   where conname = 'campaign_recipients_execution_id_user_id_channel_key'
     and conrelid = 'marketing.campaign_recipients'::regclass
) then 'PASS recipient unique per execution/user/channel'
else 'FAIL recipient uniqueness missing' end as recipient_execution_unique;

-- Execution idempotency must be per campaign+approved version, not per campaign:
select case when not exists (
  select 1 from marketing.campaign_executions
   where idempotency_key !~ '^campaign:[0-9a-f-]{36}:[0-9a-f-]{36}$'
) then 'PASS execution idempotency format is campaign:version'
else 'FAIL execution idempotency format' end as exec_idempotency_format;

-- Completion semantics: unknown is not sent, and completed executions must
-- have no pending/queued/failed/unknown recipients in the proposed worker.
select case when not exists (
  select 1 from marketing.campaign_executions e
  join marketing.campaign_recipients r on r.execution_id = e.id
   where e.status = 'completed'
     and r.dispatch_status in ('pending','queued','failed','unknown')
) then 'PASS completed executions have no unresolved recipients'
else 'FAIL completed execution still has unresolved recipients' end as completion;

-- Lifecycle RPCs must exist (functions are created by the campaign engine proposal).
select case when pg_get_functiondef('marketing.list_campaigns()'::regprocedure) is not null
  then 'PASS list_campaigns exists'
else 'FAIL list_campaigns missing' end as rpc_list;

select case when pg_get_functiondef('marketing.schedule_campaign(uuid, timestamptz)'::regprocedure) is not null
  then 'PASS schedule_campaign exists'
else 'FAIL schedule_campaign missing' end as rpc_schedule;

select case when pg_get_functiondef('marketing.approve_campaign(uuid)'::regprocedure) is not null
  then 'PASS approve_campaign exists'
else 'FAIL approve_campaign missing' end as rpc_approve;

-- Client must never be able to run the worker directly.
select case when not has_function_privilege('authenticated','marketing.run_campaign_executions(integer)','EXECUTE')
  then 'PASS worker is not client-executable'
else 'FAIL worker executable by authenticated' end as worker_acl;
