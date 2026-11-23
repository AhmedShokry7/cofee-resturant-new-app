-- P0.5 LOCAL TEST ONLY. Run in isolated non-production DB, never remote.
-- Requires p05_marketing_worker_delivery.PROPOSED.sql.
-- Fixtures: scheduled execution with recipients; run worker twice and verify
-- only one notification per dedupe_key and no duplicate recipients.

\set ON_ERROR_STOP on

select case when has_function_privilege('service_role','marketing.run_campaign_executions(integer)','EXECUTE')
  then 'PASS worker executable by service_role'
  else 'FAIL worker not executable by service_role' end as worker_service_role;

select case when not has_function_privilege('authenticated','marketing.run_campaign_executions(integer)','EXECUTE')
  then 'PASS worker not executable by authenticated'
  else 'FAIL worker executable by authenticated' end as worker_authenticated;

-- After a worker run in fixtures:
--   count(*) from engagement.notifications where dedupe_key like 'campaign:%'
-- must equal count(*) from marketing.campaign_recipients where dispatch_status='queued'
-- for the first run, and must not increase on the second run.
select case when not exists (
  select 1
  from marketing.campaign_recipients r
  join engagement.notifications n on n.id = r.notification_id
  where r.dispatch_status = 'sent'
    and not exists (
      select 1 from engagement.push_deliveries d where d.notification_id = n.id and d.status = 'sent'
    )
    and not exists (
      select 1 from engagement.email_deliveries d where d.notification_id = n.id and d.status = 'sent'
    )
) then 'PASS no recipient marked sent without provider evidence'
else 'FAIL recipient marked sent without provider evidence' end as sent_evidence;
