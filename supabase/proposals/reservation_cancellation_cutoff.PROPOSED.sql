-- SUPERSEDED: reviewed and applied as migrations/20261126195000_reservation_cancellation_cutoff.sql. Do not deploy this draft.
-- PROPOSAL ONLY. Do not apply until reviewed and explicitly approved.
-- Store branch-level cancellation deadlines in core.branches.settings.
-- Values are minutes before the reserved start. Zero means cancel until start.

begin;

create or replace function public.admin_get_reservation_cancellation_policy(
  p_branch_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_settings jsonb;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('tables.read')
     and not identity.has_permission('tables.manage') then
    raise exception 'missing permission: tables.read' using errcode = '42501';
  end if;
  if not identity.is_admin() and not identity.can_manage_branch(p_branch_id) then
    raise exception 'branch out of scope' using errcode = '42501';
  end if;
  select b.settings into v_settings from core.branches b where b.id=p_branch_id;
  if not found then return jsonb_build_object('ok',false,'reason','not_found'); end if;
  return jsonb_build_object(
    'ok',true,
    'table_cutoff_minutes',case when coalesce(v_settings->>'reservation_cancel_cutoff_minutes','') ~ '^[0-9]{1,5}$' then (v_settings->>'reservation_cancel_cutoff_minutes')::integer else 0 end,
    'event_cutoff_minutes',case when coalesce(v_settings->>'event_cancel_cutoff_minutes','') ~ '^[0-9]{1,5}$' then (v_settings->>'event_cancel_cutoff_minutes')::integer else 0 end
  );
end;
$$;
revoke all on function public.admin_get_reservation_cancellation_policy(uuid) from public, anon;
grant execute on function public.admin_get_reservation_cancellation_policy(uuid) to authenticated;

create or replace function public.admin_set_reservation_cancellation_policy(
  p_branch_id uuid,
  p_table_cutoff_minutes integer,
  p_event_cutoff_minutes integer
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('tables.manage') then
    raise exception 'missing permission: tables.manage' using errcode = '42501';
  end if;
  if not identity.is_admin() and not identity.can_manage_branch(p_branch_id) then
    raise exception 'branch out of scope' using errcode = '42501';
  end if;
  if p_table_cutoff_minutes not between 0 and 10080
     or p_event_cutoff_minutes not between 0 and 10080 then
    return jsonb_build_object('ok',false,'reason','invalid_cutoff');
  end if;
  update core.branches b
     set settings = coalesce(b.settings,'{}'::jsonb) || jsonb_build_object(
       'reservation_cancel_cutoff_minutes',p_table_cutoff_minutes,
       'event_cancel_cutoff_minutes',p_event_cutoff_minutes
     ),
         updated_at=now()
   where b.id=p_branch_id;
  if not found then return jsonb_build_object('ok',false,'reason','not_found'); end if;
  return jsonb_build_object('ok',true,'reason','');
end;
$$;
revoke all on function public.admin_set_reservation_cancellation_policy(uuid,integer,integer) from public, anon;
grant execute on function public.admin_set_reservation_cancellation_policy(uuid,integer,integer) to authenticated;

-- Add customer_can_cancel without removing or renaming any existing response
-- fields. Older app builds ignore the additional JSON key.
create or replace function public.list_my_reservations()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not authenticated' using errcode = '42501'; end if;
  return coalesce((
    select jsonb_agg(row_to_json(x)::jsonb order by x.reserved_for desc)
    from (
      select r.id,r.branch_id,r.table_id,r.user_id,r.source,r.status,
             r.reservation_type,r.reserved_for,r.requested_end_at,
             r.reserved_until,r.duration_minutes,r.party_size,r.customer_name,
             r.customer_phone,r.note,r.customer_note,r.admin_note,
             r.cancellation_reason,r.reviewed_at,r.created_at,r.updated_at,
             b.name_ar as branch_name_ar,b.name_en as branch_name_en,
             t.name as table_name,t.area as table_area,
             (r.status in ('pending','approved','confirmed') and
              r.reserved_for > now() + make_interval(mins =>
                case when coalesce(b.settings->>
                  case when r.linked_event_id is not null then 'event_cancel_cutoff_minutes'
                       else 'reservation_cancel_cutoff_minutes' end,'') ~ '^[0-9]{1,5}$'
                  then (b.settings->>
                    case when r.linked_event_id is not null then 'event_cancel_cutoff_minutes'
                         else 'reservation_cancel_cutoff_minutes' end)::integer
                  else 0 end
              )) as customer_can_cancel
        from floor.reservations r
        left join core.branches b on b.id=r.branch_id
        left join floor.tables t on t.id=r.table_id
       where r.user_id=v_uid
       order by r.reserved_for desc
    ) x
  ),'[]'::jsonb);
end;
$$;
revoke all on function public.list_my_reservations() from public, anon;
grant execute on function public.list_my_reservations() to authenticated;

create or replace function public.list_my_customer_event_requests()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not authenticated' using errcode = '42501'; end if;
  return coalesce((
    select jsonb_agg(row_to_json(x)::jsonb order by x.created_at desc)
    from (
      select e.*,b.name_ar as branch_name_ar,b.name_en as branch_name_en,
             t.name as quoted_space_name,
             (e.status in ('pending','quoted','quote_declined') or
              (e.status='confirmed' and r.status in ('pending','approved','confirmed') and
               r.reserved_for > now() + make_interval(mins =>
                 case when coalesce(b.settings->>'event_cancel_cutoff_minutes','') ~ '^[0-9]{1,5}$'
                   then (b.settings->>'event_cancel_cutoff_minutes')::integer else 0 end
               ))) as customer_can_cancel
        from floor.customer_event_requests e
        join core.branches b on b.id=e.branch_id
        left join floor.tables t on t.id=e.quoted_space_id
        left join floor.reservations r on r.id=e.reservation_id
       where e.user_id=v_uid
    ) x
  ),'[]'::jsonb);
end;
$$;
revoke all on function public.list_my_customer_event_requests() from public, anon;
grant execute on function public.list_my_customer_event_requests() to authenticated;

-- Keep the existing boolean RPC contract. A false result means the row was
-- absent, owned by another customer, in a terminal state, or past its cutoff.
create or replace function public.cancel_my_reservation(p_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_res floor.reservations%rowtype;
  v_cutoff integer;
begin
  if v_uid is null then raise exception 'not authenticated' using errcode = '42501'; end if;
  select * into v_res from floor.reservations r
   where r.id=p_id and r.user_id=v_uid for update;
  if not found or v_res.status not in ('pending','approved','confirmed') then return false; end if;

  select coalesce((b.settings->>
    case when v_res.linked_event_id is not null
         then 'event_cancel_cutoff_minutes'
         else 'reservation_cancel_cutoff_minutes' end
  )::integer,0)
    into v_cutoff from core.branches b where b.id=v_res.branch_id;
  if v_res.reserved_for <= now() + make_interval(mins => v_cutoff) then return false; end if;

  update floor.reservations
     set status='cancelled',cancelled_at=now(),updated_at=now()
   where id=v_res.id;
  if v_res.linked_event_id is not null then
    update floor.customer_event_requests
       set status='cancelled',cancelled_at=now(),updated_at=now()
     where id=v_res.linked_event_id and user_id=v_uid and status='confirmed';
  end if;
  return true;
end;
$$;
revoke all on function public.cancel_my_reservation(uuid) from public, anon;
grant execute on function public.cancel_my_reservation(uuid) to authenticated;

-- Pending/quoted event requests have no confirmed reservation, so they can be
-- withdrawn at any time. Confirmed events use the event-specific cutoff and
-- update both the event request and its linked reservation atomically.
create or replace function public.cancel_my_customer_event_request(p_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_event floor.customer_event_requests%rowtype;
  v_res floor.reservations%rowtype;
  v_cutoff integer;
begin
  if v_uid is null then raise exception 'not authenticated' using errcode = '42501'; end if;
  -- Read first without locking to establish whether this is a draft request
  -- or a confirmed event. Confirmed cancellations lock reservation then event,
  -- matching cancel_my_reservation and avoiding an inverse lock order.
  select * into v_event from floor.customer_event_requests e
   where e.id=p_id and e.user_id=v_uid;
  if not found then return false; end if;
  if v_event.status in ('pending','quoted','quote_declined') then
    update floor.customer_event_requests
       set status='cancelled',cancelled_at=now(),updated_at=now()
     where id=v_event.id and user_id=v_uid
       and status in ('pending','quoted','quote_declined');
    return found;
  end if;
  if v_event.status <> 'confirmed' or v_event.reservation_id is null then return false; end if;

  select * into v_res from floor.reservations r
   where r.id=v_event.reservation_id and r.user_id=v_uid for update;
  if not found or v_res.status not in ('pending','approved','confirmed') then return false; end if;
  select * into v_event from floor.customer_event_requests e
   where e.id=p_id and e.user_id=v_uid for update;
  if not found or v_event.status <> 'confirmed'
     or v_event.reservation_id <> v_res.id then return false; end if;
  select coalesce((b.settings->>'event_cancel_cutoff_minutes')::integer,0)
    into v_cutoff from core.branches b where b.id=v_event.branch_id;
  if v_res.reserved_for <= now() + make_interval(mins => v_cutoff) then return false; end if;

  update floor.reservations
     set status='cancelled',cancelled_at=now(),updated_at=now()
   where id=v_res.id;
  update floor.customer_event_requests
     set status='cancelled',cancelled_at=now(),updated_at=now()
   where id=v_event.id;
  return true;
end;
$$;
revoke all on function public.cancel_my_customer_event_request(uuid) from public, anon;
grant execute on function public.cancel_my_customer_event_request(uuid) to authenticated;

commit;

