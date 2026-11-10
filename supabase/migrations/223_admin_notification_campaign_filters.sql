-- Campaign-level notification directory with campaign/source/date filters. Admin campaigns appear once, with
-- channel/read counts aggregated in SQL before pagination. Automatic events
-- remain one row per notification.
create or replace function public.admin_notifications_filtered(
  p_search text default null,
  p_type text default null,
  p_read boolean default null,
  p_push text default null,
  p_limit integer default 20,
  p_offset integer default 0,
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
  v_limit integer := least(greatest(coalesce(p_limit, 20), 1), 100);
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_total bigint;
  v_rows jsonb;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('notifications.read') then
    raise exception 'missing permission: notifications.read' using errcode = '42501';
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

  with campaign_stats as (
    select c.*,
      r.recipient_count as actual_recipient_count,
      r.read_count,
      r.unread_count,
      coalesce(p.total, 0) as push_total,
      coalesce(p.sent, 0) as push_sent,
      coalesce(p.failed, 0) as push_failed,
      coalesce(p.invalid_token, 0) as push_invalid_token,
      coalesce(p.skipped, 0) as push_skipped,
      p.last_at as push_last_at,
      p.last_error as push_last_error,
      coalesce(e.sent, 0) as email_sent,
      coalesce(e.failed, 0) as email_failed,
      coalesce(e.skipped, 0) as email_skipped
    from engagement.notification_campaigns c
    left join lateral (
      select count(*)::integer as recipient_count,
        count(*) filter (where n.is_read)::integer as read_count,
        count(*) filter (where not n.is_read)::integer as unread_count
      from engagement.notifications n where n.campaign_id = c.id
    ) r on true
    left join lateral (
      select count(*)::integer as total,
        count(*) filter (where d.status = 'sent')::integer as sent,
        count(*) filter (where d.status = 'failed')::integer as failed,
        count(*) filter (where d.status = 'invalid_token')::integer as invalid_token,
        count(*) filter (where d.status = 'skipped')::integer as skipped,
        max(d.created_at) as last_at,
        (array_agg(d.error order by d.created_at desc) filter (where d.error is not null))[1] as last_error
      from engagement.notifications n
      join engagement.push_deliveries d on d.notification_id = n.id
      where n.campaign_id = c.id
    ) p on true
    left join lateral (
      select count(*) filter (where d.status = 'sent')::integer as sent,
        count(*) filter (where d.status = 'failed')::integer as failed,
        count(*) filter (where d.status = 'skipped')::integer as skipped
      from engagement.notifications n
      join engagement.email_deliveries d on d.notification_id = n.id
      where n.campaign_id = c.id
    ) e on true
  ),
  campaigns as (
    select c.created_at,
      'campaign:' || c.id::text as row_id,
      jsonb_build_object(
        'id', 'campaign:' || c.id::text,
        'type', c.type,
        'title_ar', c.title_ar,
        'title_en', c.title_en,
        'body_ar', c.body_ar,
        'body_en', c.body_en,
        'payload', c.payload,
        'related_entity_type', null,
        'related_entity_id', null,
        'is_read', c.unread_count = 0,
        'read_at', null,
        'created_at', c.created_at,
        'customer', jsonb_build_object('id', '', 'full_name', null, 'email', null, 'phone', null, 'avatar_url', null),
        'campaign', jsonb_build_object(
          'id', c.id,
          'audience', c.audience,
          'recipient_count', c.actual_recipient_count,
          'created_at', c.created_at,
          'is_summary', true,
          'read_count', c.read_count,
          'unread_count', c.unread_count,
          'email_sent', c.email_sent,
          'email_failed', c.email_failed,
          'email_skipped', c.email_skipped
        ),
        'push', jsonb_build_object(
          'state', case
            when c.push_total = 0 then 'none'
            when c.push_sent > 0 then 'sent'
            when c.push_failed + c.push_invalid_token > 0 then 'failed'
            when c.push_skipped > 0 then 'skipped'
            else 'none' end,
          'total', c.push_total,
          'sent', c.push_sent,
          'failed', c.push_failed,
          'invalid_token', c.push_invalid_token,
          'skipped', c.push_skipped,
          'last_at', c.push_last_at,
          'last_error', c.push_last_error
        )
      ) as row_data
    from campaign_stats c
    where (p_type is null or c.type = p_type)
      and (p_source is null or p_source = 'campaign')
      and (p_created_from is null or c.created_at >= p_created_from)
      and (p_created_before is null or c.created_at < p_created_before)
      and (p_read is null or (p_read and c.unread_count = 0) or (not p_read and c.unread_count > 0))
      and (
        p_push is null
        or (p_push = 'none' and c.push_total = 0)
        or (p_push = 'sent' and c.push_sent > 0)
        or (p_push = 'failed' and c.push_failed + c.push_invalid_token > 0)
        or (p_push = 'skipped' and c.push_skipped > 0)
      )
      and (
        v_search is null
        or strpos(lower(c.title_ar), v_search) > 0
        or strpos(lower(c.title_en), v_search) > 0
        or strpos(lower(c.body_ar), v_search) > 0
        or strpos(lower(c.body_en), v_search) > 0
        or exists (
          select 1 from engagement.notifications n
          join identity.profiles pr on pr.id = n.user_id
          where n.campaign_id = c.id
            and (strpos(lower(coalesce(pr.full_name, '')), v_search) > 0
              or strpos(lower(coalesce(pr.email, '')), v_search) > 0
              or strpos(lower(coalesce(pr.phone, '')), v_search) > 0)
        )
      )
  ),
  automatic_rows as (
    select n.created_at,
      n.id::text as row_id,
      jsonb_build_object(
        'id', n.id,
        'type', n.type,
        'title_ar', n.title_ar,
        'title_en', n.title_en,
        'body_ar', n.body_ar,
        'body_en', n.body_en,
        'payload', n.payload,
        'related_entity_type', n.related_entity_type,
        'related_entity_id', n.related_entity_id,
        'is_read', n.is_read,
        'read_at', n.read_at,
        'created_at', n.created_at,
        'customer', jsonb_build_object('id', n.user_id, 'full_name', pr.full_name, 'email', pr.email, 'phone', pr.phone, 'avatar_url', pr.avatar_url),
        'campaign', null,
        'push', jsonb_build_object(
          'state', case
            when coalesce(p.total, 0) = 0 then 'none'
            when p.sent > 0 then 'sent'
            when p.failed + p.invalid_token > 0 then 'failed'
            when p.skipped > 0 then 'skipped'
            else 'none' end,
          'total', coalesce(p.total, 0), 'sent', coalesce(p.sent, 0),
          'failed', coalesce(p.failed, 0), 'invalid_token', coalesce(p.invalid_token, 0),
          'skipped', coalesce(p.skipped, 0), 'last_at', p.last_at, 'last_error', p.last_error
        )
      ) as row_data
    from engagement.notifications n
    join identity.profiles pr on pr.id = n.user_id
    left join lateral (
      select count(*)::integer as total,
        count(*) filter (where d.status = 'sent')::integer as sent,
        count(*) filter (where d.status = 'failed')::integer as failed,
        count(*) filter (where d.status = 'invalid_token')::integer as invalid_token,
        count(*) filter (where d.status = 'skipped')::integer as skipped,
        max(d.created_at) as last_at,
        (array_agg(d.error order by d.created_at desc) filter (where d.error is not null))[1] as last_error
      from engagement.push_deliveries d where d.notification_id = n.id
    ) p on true
    where n.campaign_id is null
      and (p_source is null or p_source = 'automatic')
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
  ),
  entries as (
    select * from campaigns
    union all
    select * from automatic_rows
  ),
  page as (
    select * from entries order by created_at desc, row_id desc limit v_limit offset v_offset
  )
  select (select count(*) from entries),
    coalesce((select jsonb_agg(row_data order by created_at desc, row_id desc) from page), '[]'::jsonb)
  into v_total, v_rows;

  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$fn$;

comment on function public.admin_notifications_filtered(text, text, boolean, text, integer, integer, text, timestamptz, timestamptz) is
  'Paged notification directory ordered newest first, with campaign/source/date filters and aggregated channel counts.';

revoke all on function public.admin_notifications_filtered(text, text, boolean, text, integer, integer, text, timestamptz, timestamptz) from public, anon;
grant execute on function public.admin_notifications_filtered(text, text, boolean, text, integer, integer, text, timestamptz, timestamptz) to authenticated;

select pg_notify('pgrst', 'reload schema');