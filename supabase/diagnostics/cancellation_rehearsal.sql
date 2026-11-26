-- Approved by user: branch cancellation cutoffs, preserving live response fields.
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
  if not identity.has_permission('settings.read')
     and not identity.has_permission('settings.write') then
    raise exception 'missing permission: settings.read' using errcode = '42501';
  end if;
  if not identity.can_manage_branch(p_branch_id) then
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
  if not identity.has_permission('settings.write') then
    raise exception 'missing permission: settings.write' using errcode = '42501';
  end if;
  if not identity.can_manage_branch(p_branch_id) then
    raise exception 'branch out of scope' using errcode = '42501';
  end if;
  if p_table_cutoff_minutes is null or p_event_cutoff_minutes is null or p_table_cutoff_minutes not between 0 and 10080
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
             r.cancellation_reason,r.reviewed_at,r.created_at,r.updated_at,r.linked_event_id,e.occasion_name,e.occasion_type,
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
        left join floor.customer_event_requests e on e.id=r.linked_event_id
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
             t.name as quoted_space_name,t.image_url as quoted_space_image_url,
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

notify pgrst, 'reload schema';



insert into core.branches(id,brand_id,code,name_ar,name_en,address) select 'bca00000-0000-4000-8000-000000000001',id,'CANCEL-CUTOFF-TEST','اختبار','Cutoff test','test' from core.brands limit 1;
insert into auth.users(id,email) values ('bca00000-0000-4000-8000-000000000021','cutoff-admin@test.local'),('bca00000-0000-4000-8000-000000000023','cutoff-customer@test.local');
insert into identity.staff_members(id,user_id,status,full_name,email) values ('bca00000-0000-4000-8000-000000000031','bca00000-0000-4000-8000-000000000021','active','Cutoff test','cutoff-admin@test.local');
insert into identity.staff_roles(staff_id,role_id,branch_id) select 'bca00000-0000-4000-8000-000000000031',id,null from identity.roles where code='owner';
insert into floor.tables(id,branch_id,name,area,capacity) select ('bca00000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'bca00000-0000-4000-8000-000000000001','Cutoff '||n,'hall',4 from generate_series(11,15) n;
insert into floor.reservations(id,branch_id,table_id,user_id,source,status,customer_name,party_size,reserved_for,reserved_until,duration_minutes)
select ('bca00000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'bca00000-0000-4000-8000-000000000001',('bca00000-0000-4000-8000-'||lpad((n-30)::text,12,'0'))::uuid,'bca00000-0000-4000-8000-000000000023','customer','confirmed','Test',2,now()+make_interval(mins=>m),now()+make_interval(mins=>m+30),30 from (values (41,30),(42,60),(43,120),(44,720),(45,2880)) v(n,m);
insert into floor.customer_event_requests(id,user_id,branch_id,occasion_type,occasion_date,preferred_start_at,preferred_end_at,guest_count,requested_space_type,customer_name,status,reservation_id)
select ('bca00000-0000-4000-8000-'||lpad((n+10)::text,12,'0'))::uuid,user_id,branch_id,'birthday',reserved_for::date,reserved_for,reserved_until,2,'table','Test','confirmed',id from floor.reservations cross join (values (44),(45)) v(n) where id=('bca00000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid;
update floor.reservations set linked_event_id=('bca00000-0000-4000-8000-'||lpad((n+10)::text,12,'0'))::uuid from (values (44),(45)) v(n) where id=('bca00000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"bca00000-0000-4000-8000-000000000021","role":"authenticated"}',true);
do $$ declare v jsonb; begin
 v:=public.admin_set_reservation_cancellation_policy('bca00000-0000-4000-8000-000000000001',60,1440);
 if v->>'ok'<>'true' then raise exception 'save failed'; end if;
 v:=public.admin_get_reservation_cancellation_policy('bca00000-0000-4000-8000-000000000001');
 if (v->>'table_cutoff_minutes')::int<>60 or (v->>'event_cutoff_minutes')::int<>1440 then raise exception 'readback failed'; end if;
 if public.admin_set_reservation_cancellation_policy('bca00000-0000-4000-8000-000000000001',null,1440)->>'ok'<>'false' then raise exception 'null accepted'; end if;
 if public.admin_set_reservation_cancellation_policy('bca00000-0000-4000-8000-000000000001',-1,1440)->>'ok'<>'false' then raise exception 'negative accepted'; end if;
 if public.cancel_my_reservation('bca00000-0000-4000-8000-000000000043') then raise exception 'other owner allowed'; end if;
end $$;
select set_config('request.jwt.claims','{"sub":"bca00000-0000-4000-8000-000000000023","role":"authenticated"}',true);
do $$ declare v jsonb; begin
 begin
 perform public.admin_set_reservation_cancellation_policy('bca00000-0000-4000-8000-000000000001',0,0);
 raise exception 'customer allowed settings write';
 exception when insufficient_privilege then null; end;
 if public.cancel_my_reservation('bca00000-0000-4000-8000-000000000041') then raise exception 'inside cutoff accepted'; end if;
 if public.cancel_my_reservation('bca00000-0000-4000-8000-000000000042') then raise exception 'exact cutoff accepted'; end if;
 if not public.cancel_my_reservation('bca00000-0000-4000-8000-000000000043') then raise exception 'outside cutoff denied'; end if;
 if public.cancel_my_reservation('bca00000-0000-4000-8000-000000000043') then raise exception 'duplicate cancellation accepted'; end if;
 if public.cancel_my_customer_event_request('bca00000-0000-4000-8000-000000000054') then raise exception 'event inside cutoff accepted'; end if;
 if public.cancel_my_reservation('bca00000-0000-4000-8000-000000000044') then raise exception 'event bypass via reservation'; end if;
 if not public.cancel_my_customer_event_request('bca00000-0000-4000-8000-000000000055') then raise exception 'event outside cutoff denied'; end if;
 select value into v from jsonb_array_elements(public.list_my_reservations()) where value->>'id'='bca00000-0000-4000-8000-000000000044';
 if v->>'customer_can_cancel'<>'false' or not(v ? 'occasion_name') then raise exception 'reservation contract incorrect'; end if;
 select value into v from jsonb_array_elements(public.list_my_customer_event_requests()) where value->>'id'='bca00000-0000-4000-8000-000000000055';
 if v->>'status'<>'cancelled' or not(v ? 'quoted_space_image_url') then raise exception 'event contract incorrect'; end if;
end $$;
reset role;
do $$ begin
 if (select status from floor.reservations where id='bca00000-0000-4000-8000-000000000045')<>'cancelled' then raise exception 'event/reservation not atomic'; end if;
end $$;
rollback;
select 'PASS: settings read/write, invalid input, customer permission, ownership, cutoff boundary, repeat cancellation, event cutoff and linked reservation, response contracts; all fixtures rolled back' as result;


