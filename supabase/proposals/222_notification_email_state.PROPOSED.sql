-- supabase/proposals/222_notification_email_state.PROPOSED.sql
--
-- STATUS: NOT APPLIED. This file is a proposal. Nothing here has touched
-- production; it is meant to be pasted into the Supabase SQL Editor of project
-- `webzzasosevzymftgszn` once the owner approves it.
--
-- WHY THIS EXISTS
--
-- 219 gave mail its log, 221 gave the panel its counters. What the directory
-- still cannot say is the per-message half: `admin_notifications` (170) builds
-- each row from `engagement.push_deliveries` only, so a campaign whose mail was
-- refused by the provider — verified on production, notification `4f8549a9`:
-- push `sent`, mail `failed / resend 403 ... domain is not verified` — reads in
-- the list as plain "delivered". The counters at the top of the screen admit
-- the refusal, the row next to them hides it, and the operator has no way to
-- tell which customer missed the message.
--
-- `engagement.email_deliveries` has row level security enabled and no policy,
-- so a client cannot read it directly, and the `public.email_deliveries` view
-- (security_invoker) answers zero rows to every role. That is deliberate: the
-- log holds customer addresses. The read therefore goes through a definer
-- function with the same guard the directory already uses.
--
-- WHAT CHANGES
--
--   1. One new function, `admin_notification_email_state(p_ids uuid[])`. It
--      takes the ids currently on screen and returns, per id, the mail counts,
--      the newest error and a state word built by the same rule the push object
--      uses: sent beats failed, failed beats skipped, an empty log is `none`.
--   2. `admin_notifications` is not touched. An extra call that the page makes
--      beside the ones it already makes cannot regress the directory, and the
--      two channels stay separable if a third ever appears.
--
-- WHAT DOES NOT CHANGE
--
-- No table, column, trigger, policy or view. No write path. A staff member who
-- lacks `notifications.read` gets the same 42501 the directory gives them.

-- ---------------------------------------------------------------------------
-- 1. The mail state of the rows the admin is looking at
-- ---------------------------------------------------------------------------
create or replace function public.admin_notification_email_state(
  p_ids uuid[] default '{}'
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_rows jsonb;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('notifications.read') then
    raise exception 'missing permission: notifications.read' using errcode = '42501';
  end if;

  -- The list is bounded by the page the caller was already allowed to read, so
  -- this cannot be turned into a scan of the whole mail log.
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'notification_id', m.notification_id,
        'state',           m.state,
        'total',           m.total,
        'sent',            m.sent,
        'failed',          m.failed,
        'skipped',         m.skipped,
        'last_at',         m.last_at,
        'last_error',      m.last_error
      )
      order by m.notification_id
    ),
    '[]'::jsonb
  )
  into v_rows
  from (
    select
      e.notification_id,
      count(*)                                              as total,
      count(*) filter (where e.status = 'sent')             as sent,
      count(*) filter (where e.status = 'failed')           as failed,
      count(*) filter (where e.status = 'skipped')          as skipped,
      max(e.created_at)                                     as last_at,
      (array_agg(e.error order by e.created_at desc)
         filter (where e.error is not null))[1]            as last_error,
      case
        when count(*) filter (where e.status = 'sent') > 0 then 'sent'
        when count(*) filter (where e.status = 'failed') > 0 then 'failed'
        when count(*) filter (where e.status = 'skipped') > 0 then 'skipped'
        else 'none'
      end                                                   as state
    from engagement.email_deliveries e
    where e.notification_id = any (
      (coalesce(p_ids, '{}'::uuid[]))[1:200]
    )
    group by e.notification_id
  ) m;

  return v_rows;
end;
$fn$;

comment on function public.admin_notification_email_state(p_ids uuid[]) is
  'Per-notification mail delivery state for the rows the admin directory is showing; read-only, definer, guarded by notifications.read.';

revoke all on function public.admin_notification_email_state(uuid[])
  from public, anon;
grant execute on function public.admin_notification_email_state(uuid[])
  to authenticated, service_role;

-- The REST layer caches function signatures, so the new function stays
-- invisible to the app until the schema cache is reloaded.
select pg_notify('pgrst', 'reload schema');
