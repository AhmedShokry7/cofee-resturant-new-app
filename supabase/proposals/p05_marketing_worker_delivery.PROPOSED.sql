-- SUPERSEDED: official migration is supabase/migrations/*.sql (P0.7, applied). This proposal is now a historical reference only.
-- P0.5 LOCAL PROPOSAL ONLY. Do NOT apply without separate approval.
-- File: p05_marketing_worker_delivery.PROPOSED.sql
-- Purpose: single delivery start path, claim/lease, consent re-check,
-- idempotency, retry, unknown reconciliation, no double-send.
-- Dependencies: p05_marketing_campaign_engine, p05_marketing_consent_core,
--   engagement.notifications triggers (push + email), push_deliveries/email_deliveries.
-- Important verified fact: inserting engagement.notifications triggers BOTH
-- push and email enqueue. Campaign worker therefore relies on DB-backed
-- channel gating in send-push/send-email via marketing.campaign_recipients.
-- Tests: supabase/tests/marketing_hub_worker_test.sql

create or replace function marketing.run_campaign_executions(p_limit integer default 200)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_limit integer := least(greatest(coalesce(p_limit, 200), 1), 1000);
  v_claimed integer := 0;
  v_processed integer := 0;
  v_sent integer := 0;
  v_skipped integer := 0;
  v_failed integer := 0;
  v_unknown integer := 0;
  v_exec record;
  v_rec record;
  v_version record;
  v_notification_id uuid;
  v_attempt_no integer;
  v_attempt_id uuid;
begin
  -- Claim due executions. SKIP LOCKED prevents two workers claiming one row.
  for v_exec in
    select *
      from marketing.campaign_executions
     where (status = 'queued' and scheduled_for <= now())
        or (status = 'running' and lease_until is not null and lease_until < now())
     order by scheduled_for
     for update skip locked
     limit v_limit
  loop
    update marketing.campaign_executions
       set status = 'running',
           lease_owner = pg_backend_pid()::text,
           lease_until = now() + interval '5 minutes',
           started_at = coalesce(started_at, now()),
           updated_at = now()
     where id = v_exec.id;

    v_claimed := v_claimed + 1;

    select * into v_version
      from marketing.campaign_versions
     where id = v_exec.campaign_version_id;

    update marketing.campaigns
       set status = 'processing', updated_at = now()
     where id = v_exec.campaign_id
       and status in ('scheduled','processing');

    for v_rec in
      select *
        from marketing.campaign_recipients
       where execution_id = v_exec.id
         and dispatch_status in ('pending','failed')
         and (next_attempt_at is null or next_attempt_at <= now())
       order by created_at
       for update skip locked
       limit 200
    loop
      -- Re-check campaign/execution before every recipient.
      perform 1
        from marketing.campaign_executions e
        join marketing.campaigns c on c.id = e.campaign_id
       where e.id = v_exec.id
         and e.status = 'running'
         and c.status = 'processing';

      if not found then
        exit;
      end if;

      -- Idempotent retry guard: a recipient that already has a notification
      -- linked must never trigger a second send.
      if v_rec.notification_id is not null then
        continue;
      end if;

      v_attempt_no := v_rec.attempt_count + 1;

      -- Current consent/reachability is authoritative; snapshot is evidence only.
      if not marketing.is_marketing_deliverable_internal(v_rec.user_id, v_rec.channel, v_rec.purpose) then
        update marketing.campaign_recipients
           set dispatch_status = 'skipped',
               eligibility_status = case
                 when not marketing.is_marketing_consented_internal(v_rec.user_id, v_rec.channel, v_rec.purpose)
                   then 'suppressed_consent'
                 else 'suppressed_channel'
               end,
               processed_at = now(),
               updated_at = now()
         where id = v_rec.id;
        v_processed := v_processed + 1;
        v_skipped := v_skipped + 1;
        continue;
      end if;

      -- EDGE ROUTING / RACE CLOSURE (P0.5.1 FINAL):
      -- This insert, the campaign_attempt row, and the recipient link below
      -- all happen inside the SAME transaction (function body). The
      -- engagement.notifications AFTER INSERT triggers call pg_net http_post,
      -- which only QUEUES the HTTP request; pg_net delivers it after COMMIT.
      -- Therefore send-push / send-email can only observe the link after
      -- campaign_recipients.notification_id is visible. There is no window in
      -- which Edge sends before the target channel is known. Operational
      -- (non-campaign) notifications have no recipient row and keep legacy
      -- preference behavior; their types are never promo/loyalty, so the
      -- marketing consent/channel gate does not apply to them.
      v_notification_id := extensions.gen_random_uuid();
      insert into engagement.notifications
        (id, user_id, type, title_ar, title_en, body_ar, body_en,
         payload, related_entity_type, related_entity_id,
         campaign_id, created_by, dedupe_key)
      values
        (v_notification_id, v_rec.user_id,
         case when v_rec.purpose = 'loyalty_marketing' then 'loyalty' else 'promo' end,
         v_version.title_ar, v_version.title_en, v_version.body_ar, v_version.body_en,
         coalesce(v_version.payload, '{}'::jsonb) || jsonb_build_object(
           'marketing_campaign_id', v_exec.campaign_id,
           'marketing_execution_id', v_exec.id,
           'marketing_recipient_id', v_rec.id,
           'marketing_channel', v_rec.channel,
           'marketing_purpose', v_rec.purpose),
         null, null, null, null,
         v_rec.dedupe_key)
      on conflict (user_id, dedupe_key) where dedupe_key is not null
      do nothing
      returning id into v_notification_id;

      if v_notification_id is null then
        select n.id into v_notification_id
          from engagement.notifications n
         where n.user_id = v_rec.user_id
           and n.dedupe_key = v_rec.dedupe_key;

        update marketing.campaign_recipients
           set dispatch_status = 'skipped',
               eligibility_status = 'duplicate',
               notification_id = v_notification_id,
               updated_at = now()
         where id = v_rec.id;

        v_processed := v_processed + 1;
        v_skipped := v_skipped + 1;
        continue;
      end if;

      insert into marketing.campaign_attempts
        (execution_id, recipient_id, channel, attempt_number, status)
      values
        (v_exec.id, v_rec.id, v_rec.channel, v_attempt_no, 'queued')
      returning id into v_attempt_id;

      update marketing.campaign_recipients
         set dispatch_status = 'queued',
             notification_id = v_notification_id,
             attempt_count = v_attempt_no,
             updated_at = now()
       where id = v_rec.id;

      -- Heartbeat after each recipient so a long batch keeps its lease.
      update marketing.campaign_executions
         set lease_until = now() + interval '5 minutes',
             updated_at = now()
       where id = v_exec.id;

      v_processed := v_processed + 1;
    end loop;

    -- Completion check: unknown never counts as sent.
    if not exists (
      select 1 from marketing.campaign_recipients
       where execution_id = v_exec.id
         and dispatch_status in ('pending','queued','failed','unknown')
    ) then
      update marketing.campaign_executions
         set status = 'completed',
             finished_at = now(),
             lease_until = null,
             updated_at = now()
       where id = v_exec.id;

      update marketing.campaigns
         set status = 'completed', updated_at = now()
       where id = v_exec.campaign_id;
    end if;
  end loop;

  return jsonb_build_object(
    'claimed', v_claimed,
    'processed', v_processed,
    'sent', v_sent,
    'skipped', v_skipped,
    'failed', v_failed,
    'unknown', v_unknown
  );
end;
$fn$;

revoke all on function marketing.run_campaign_executions(integer)
  from public, anon, authenticated;
grant execute on function marketing.run_campaign_executions(integer) to service_role;

-- Reconciliation is intentionally separate from dispatch: provider logs are
-- evidence, notification rows are not proof of delivery. A future approved
-- migration adds marketing.reconcile_campaign_attempts() that maps
-- push_deliveries/email_deliveries into campaign_attempts and only then marks
-- recipients sent/failed/skipped. Unknown rows are never auto-retried.
