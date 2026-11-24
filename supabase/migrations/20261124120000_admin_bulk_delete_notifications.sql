-- Admin bulk delete of per-recipient notification history.
--
-- Scope is deliberately narrow:
--   * only engagement.notifications rows with campaign_id is null (the same
--     rows the admin directory lists as automatic events) can be deleted;
--   * campaign summaries, notification_campaigns, marketing campaigns and
--     templates are never touched;
--   * push/email delivery logs cascade with the row; the marketing engine's
--     notification_id is set null by its own FK;
--   * every deleted row writes one identity.audit entry, like
--     public.admin_delete_notification.
-- Both functions require identity.is_staff() and notifications.manage, and
-- the id lookup mirrors the filters of public.admin_notifications_filtered.

create or replace function public.admin_notification_ids_for_delete(
  p_search text default null,
  p_type text default null,
  p_read boolean default null,
  p_push text default null,
  p_source text default null,
  p_created_from timestamptz default null,
  p_created_before timestamptz default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_search text := nullif(lower(trim(coalesce(p_search, ''))), '');
  v_max constant integer := 1000;
  v_ids uuid[];
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('notifications.manage') then
    raise exception 'missing permission: notifications.manage' using errcode = '42501';
  end if;
  if p_type is not null and p_type not in ('order_status','promo','system','loyalty','subscription') then
    raise exception 'invalid notification type' using errcode = '22023';
  end if;
  if p_push is not null and p_push not in ('sent','failed','skipped','none') then
    raise exception 'invalid push state' using errcode = '22023';
  end if;
  if p_source is not null and p_source not in ('campaign','automatic') then
    raise exception 'invalid notification source' using errcode = '22023';
  end if;

  -- Campaign rows are summaries in the directory and are never deletable.
  if p_source = 'campaign' then
    return jsonb_build_object('total', 0, 'too_many', false, 'ids', '[]'::jsonb);
  end if;

  select coalesce(array_agg(m.id order by m.created_at desc, m.id desc), '{}'::uuid[])
    into v_ids
  from (
    select n.id, n.created_at
    from engagement.notifications n
    join identity.profiles pr on pr.id = n.user_id
    left join lateral (
      select count(*)::integer as total,
        count(*) filter (where d.status = 'sent')::integer as sent,
        count(*) filter (where d.status = 'failed')::integer as failed,
        count(*) filter (where d.status = 'invalid_token')::integer as invalid_token,
        count(*) filter (where d.status = 'skipped')::integer as skipped
      from engagement.push_deliveries d where d.notification_id = n.id
    ) p on true
    where n.campaign_id is null
      and (p_created_from is null or n.created_at >= p_created_from)
      and (p_created_before is null or n.created_at < p_created_before)
      and (p_type is null or n.type = p_type)
      and (p_read is null or n.is_read = p_read)
      and (
        p_push is null
        or (p_push = 'none' and coalesce(p.total, 0) = 0)
        or (p_push = 'sent' and p.sent > 0)
        or (p_push = 'failed' and p.sent = 0 and p.failed + p.invalid_token > 0)
        or (p_push = 'skipped' and p.sent = 0 and p.failed + p.invalid_token = 0 and p.skipped > 0)
      )
      and (v_search is null
        or strpos(lower(n.title_ar), v_search) > 0
        or strpos(lower(n.title_en), v_search) > 0
        or strpos(lower(n.body_ar), v_search) > 0
        or strpos(lower(n.body_en), v_search) > 0
        or strpos(lower(coalesce(pr.full_name, '')), v_search) > 0
        or strpos(lower(coalesce(pr.email, '')), v_search) > 0
        or strpos(lower(coalesce(pr.phone, '')), v_search) > 0)
  ) m;

  if cardinality(v_ids) > v_max then
    return jsonb_build_object('total', cardinality(v_ids), 'too_many', true, 'ids', '[]'::jsonb);
  end if;
  return jsonb_build_object('total', cardinality(v_ids), 'too_many', false, 'ids', to_jsonb(v_ids));
end;
$fn$;

comment on function public.admin_notification_ids_for_delete(text, text, boolean, text, text, timestamptz, timestamptz) is
  'Ids of deletable (per-recipient) notifications matching the admin directory filters. Staff with notifications.manage only. Returns too_many when more than 1000 match.';

revoke all on function public.admin_notification_ids_for_delete(text, text, boolean, text, text, timestamptz, timestamptz) from public, anon;
grant execute on function public.admin_notification_ids_for_delete(text, text, boolean, text, text, timestamptz, timestamptz) to authenticated;

create or replace function public.admin_delete_notifications(p_notification_ids uuid[])
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_requested uuid[];
  v_row record;
  v_deleted uuid[] := '{}'::uuid[];
  v_found uuid[] := '{}'::uuid[];
  v_protected uuid[] := '{}'::uuid[];
  v_missing uuid[];
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('notifications.manage') then
    raise exception 'missing permission: notifications.manage' using errcode = '42501';
  end if;

  v_requested := array(select distinct x from unnest(coalesce(p_notification_ids, '{}'::uuid[])) as x);
  if cardinality(v_requested) > 100 then
    raise exception 'too many notifications in one request' using errcode = '22023';
  end if;
  if cardinality(v_requested) = 0 then
    return jsonb_build_object('ok', true, 'deleted_ids', '[]'::jsonb, 'not_found_ids', '[]'::jsonb, 'protected_ids', '[]'::jsonb);
  end if;

  for v_row in
    select n.id, n.user_id, n.type, n.is_read, n.created_at, n.campaign_id
    from engagement.notifications n
    where n.id = any(v_requested)
    order by n.created_at, n.id
    for update
  loop
    v_found := array_append(v_found, v_row.id);
    if v_row.campaign_id is not null then
      v_protected := array_append(v_protected, v_row.id);
      continue;
    end if;
    delete from engagement.notifications where id = v_row.id;
    perform identity.audit(
      'engagement.notification.delete',
      'notification',
      v_row.id,
      jsonb_build_object(
        'type', v_row.type,
        'user_id', v_row.user_id,
        'campaign_id', null,
        'is_read', v_row.is_read,
        'created_at', v_row.created_at,
        'bulk', true
      ),
      null
    );
    v_deleted := array_append(v_deleted, v_row.id);
  end loop;

  v_missing := array(select x from unnest(v_requested) as x where x <> all(v_found));
  return jsonb_build_object(
    'ok', true,
    'deleted_ids', to_jsonb(v_deleted),
    'not_found_ids', to_jsonb(v_missing),
    'protected_ids', to_jsonb(v_protected)
  );
end;
$fn$;

comment on function public.admin_delete_notifications(uuid[]) is
  'Deletes up to 100 per-recipient notification rows and returns per-id outcomes (deleted, not found, protected campaign-linked). Staff with notifications.manage only; audits each deleted row.';

revoke all on function public.admin_delete_notifications(uuid[]) from public, anon;
grant execute on function public.admin_delete_notifications(uuid[]) to authenticated;
