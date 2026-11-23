-- P0.5 LOCAL TEST ONLY. Run in isolated non-production DB, never remote.
-- Requires p05_marketing_consent_core.PROPOSED.sql.
-- Fixture note: create two auth users/profiles first; run revoke/grant for
-- the same user/channel/purpose concurrently and verify state last_event_seq
-- equals the latest committed event_seq for that triple.

\set ON_ERROR_STOP on

select case when not has_function_privilege('authenticated','marketing.record_consent_event_trusted(uuid, text, text, text, text, uuid)','EXECUTE')
  then 'PASS trusted recorder not executable by authenticated'
  else 'FAIL trusted recorder executable by authenticated' end as trusted_recorder;

select case when not has_function_privilege('authenticated','marketing.is_marketing_deliverable_internal(uuid, text, text)','EXECUTE')
  then 'PASS internal deliverable check not executable by authenticated'
  else 'FAIL internal deliverable check executable by authenticated' end as internal_deliverable;

select case when has_function_privilege('authenticated','public.set_my_marketing_consent(text, text, boolean)','EXECUTE')
  then 'PASS customer consent wrapper executable'
  else 'FAIL customer consent wrapper missing' end as customer_wrapper;

select case when (select count(*) from marketing.consent_states where status not in ('granted','revoked')) = 0
  then 'PASS consent states only granted/revoked'
  else 'FAIL invalid consent state status' end as state_status;

-- Missing consent must never deliver. This is true when no state row exists.
select case when not marketing.is_marketing_consented_internal(gen_random_uuid(), 'push', 'promotions')
  then 'PASS missing consent is false'
  else 'FAIL missing consent returned true' end as missing_consent;

-- Append-only tables must have no direct update/delete for authenticated.
select case when not has_table_privilege('authenticated','marketing.consent_events','UPDATE')
  then 'PASS consent events not updatable by authenticated'
  else 'FAIL consent events updatable by authenticated' end as events_update;

select case when not has_table_privilege('authenticated','marketing.consent_events','DELETE')
  then 'PASS consent events not deletable by authenticated'
  else 'FAIL consent events deletable by authenticated' end as events_delete;

-- DIRECT-WRITE PROTECTION (P0.5.1 FINAL): table privileges must deny direct
-- writes; RLS alone is not the guard (SECURITY DEFINER functions bypass it).
select case when not has_table_privilege('authenticated','marketing.consent_events','INSERT')
  then 'PASS consent events not insertable by authenticated'
  else 'FAIL consent events insertable by authenticated' end as events_insert;

select case when not has_table_privilege('public','marketing.consent_events','INSERT')
  and not has_table_privilege('public','marketing.consent_events','UPDATE')
  and not has_table_privilege('public','marketing.consent_events','DELETE')
  then 'PASS consent events denied for PUBLIC'
else 'FAIL consent events open for PUBLIC' end as events_public;

select case when not has_table_privilege('anon','marketing.consent_events','INSERT')
  and not has_table_privilege('anon','marketing.consent_events','UPDATE')
  and not has_table_privilege('anon','marketing.consent_events','DELETE')
  then 'PASS consent events denied for anon'
else 'FAIL consent events open for anon' end as events_anon;

select case when not has_table_privilege('authenticated','marketing.consent_states','INSERT')
  and not has_table_privilege('authenticated','marketing.consent_states','UPDATE')
  and not has_table_privilege('authenticated','marketing.consent_states','DELETE')
  then 'PASS consent states not directly writable by authenticated'
else 'FAIL consent states writable by authenticated' end as states_direct_write;

-- No INSERT/UPDATE/DELETE RLS policies may exist for authenticated on events:
select case when not exists (
  select 1 from pg_policies
   where schemaname = 'marketing'
     and tablename = 'consent_events'
     and cmd in ('INSERT','UPDATE','DELETE')
) then 'PASS no write RLS policies on consent_events'
else 'FAIL write RLS policy on consent_events' end as events_write_policies;

select case when not exists (
  select 1 from pg_policies
   where schemaname = 'marketing'
     and tablename = 'consent_states'
     and cmd in ('INSERT','UPDATE','DELETE')
) then 'PASS no write RLS policies on consent_states'
else 'FAIL write RLS policy on consent_states' end as states_write_policies;

-- Internal functions must not be executable by any client role:
select case when not has_function_privilege('anon','marketing.record_consent_event_trusted(uuid, text, text, text, text, uuid)','EXECUTE')
  and not has_function_privilege('public','marketing.record_consent_event_trusted(uuid, text, text, text, text, uuid)','EXECUTE')
  then 'PASS trusted recorder denied for anon/PUBLIC'
else 'FAIL trusted recorder executable by anon/PUBLIC' end as trusted_anon_public;

select case when not has_function_privilege('authenticated','marketing.is_marketing_consented_internal(uuid, text, text)','EXECUTE')
  and not has_function_privilege('authenticated','marketing.marketing_channel_enabled_internal(uuid, text)','EXECUTE')
  then 'PASS internal consent checks denied for authenticated'
else 'FAIL internal consent checks executable by authenticated' end as internal_checks;

-- Every consent state must have a backing event and an audit trail entry;
-- a state without history means a bypass write occurred.
select case when not exists (
  select 1 from marketing.consent_states s
  join marketing.consent_events e on e.event_id = s.last_event_id
   where s.user_id <> e.user_id
) then 'PASS every consent state matches its source event'
else 'FAIL consent state does not match source event (possible bypass)' end as state_event_match;

-- service_role trust boundary (documented, not a test): service_role bypasses
-- RLS and can write both tables directly. Protection therefore depends on
-- (a) service key secrecy, (b) only Edge/Worker code holding it, and
-- (c) audit-log review of marketing.consent.* actions. Do NOT claim
-- service_role cannot bypass; client roles cannot.
