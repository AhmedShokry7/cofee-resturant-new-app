begin;

create table if not exists floor.customer_event_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  branch_id uuid not null references core.branches(id) on delete restrict,
  occasion_type text not null,
  occasion_date date not null,
  preferred_start_at timestamptz not null,
  preferred_end_at timestamptz not null,
  guest_count integer not null,
  requested_space_type text not null default 'any',
  requested_services text,
  estimated_budget numeric(12,2),
  customer_name text not null,
  customer_phone text not null default '',
  customer_note text,
  status text not null default 'pending',
  quote_amount numeric(12,2),
  quote_note text,
  quoted_space_id uuid references floor.tables(id) on delete set null,
  quoted_start_at timestamptz,
  quoted_end_at timestamptz,
  quote_expires_at timestamptz,
  reservation_id uuid references floor.reservations(id) on delete set null,
  reviewed_by uuid references identity.staff_members(id) on delete set null,
  reviewed_at timestamptz,
  customer_responded_at timestamptz,
  cancelled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint ck_customer_event_occasion check (
    occasion_type in ('birthday','graduation','family_gathering','other')
  ),
  constraint ck_customer_event_guest_count check (guest_count between 2 and 40),
  constraint ck_customer_event_space_type check (
    requested_space_type in ('any','table','room')
  ),
  constraint ck_customer_event_services check (
    requested_services is null or char_length(requested_services) <= 500
  ),
  constraint ck_customer_event_budget check (
    estimated_budget is null or estimated_budget between 0 and 10000000
  ),
  constraint ck_customer_event_name check (
    char_length(btrim(customer_name)) between 1 and 120
  ),
  constraint ck_customer_event_phone check (char_length(customer_phone) <= 40),
  constraint ck_customer_event_note check (
    customer_note is null or char_length(customer_note) <= 500
  ),
  constraint ck_customer_event_status check (
    status in ('pending','quoted','quote_declined','rejected','confirmed','cancelled')
  ),
  constraint ck_customer_event_quote check (
    quote_amount is null or quote_amount >= 0
  ),
  constraint ck_customer_event_quote_note check (
    quote_note is null or char_length(quote_note) <= 1000
  ),
  constraint ck_customer_event_requested_window check (
    preferred_end_at > preferred_start_at
    and preferred_end_at - preferred_start_at <= interval '8 hours'
  ),
  constraint ck_customer_event_quoted_window check (
    quoted_end_at is null or (
      quoted_start_at is not null and quoted_end_at > quoted_start_at
      and quoted_end_at - quoted_start_at <= interval '8 hours'
    )
  )
);

create index if not exists ix_customer_event_user_created
  on floor.customer_event_requests(user_id, created_at desc);
create index if not exists ix_customer_event_branch_status_date
  on floor.customer_event_requests(branch_id, status, occasion_date, created_at desc);
create index if not exists ix_floor_reservations_linked_event
  on floor.reservations(linked_event_id) where linked_event_id is not null;

alter table floor.customer_event_requests enable row level security;
drop policy if exists customer_event_requests_select_own
  on floor.customer_event_requests;
create policy customer_event_requests_select_own
  on floor.customer_event_requests for select to authenticated
  using (user_id = auth.uid());
grant select on floor.customer_event_requests to authenticated;
revoke insert, update, delete on floor.customer_event_requests
  from anon, authenticated;

create or replace function public.create_my_customer_event_request(p_payload jsonb)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_profile identity.profiles%rowtype;
  v_branch uuid := nullif(p_payload->>'branch_id','')::uuid;
  v_type text := lower(btrim(coalesce(p_payload->>'occasion_type','')));
  v_space text := lower(btrim(coalesce(p_payload->>'requested_space_type','any')));
  v_start timestamptz := nullif(p_payload->>'preferred_start_at','')::timestamptz;
  v_end timestamptz := nullif(p_payload->>'preferred_end_at','')::timestamptz;
  v_guests integer := nullif(p_payload->>'guest_count','')::integer;
  v_budget numeric := nullif(p_payload->>'estimated_budget','')::numeric;
  v_id uuid := gen_random_uuid();
begin
  if v_uid is null then raise exception 'not authenticated' using errcode = '42501'; end if;
  if v_type not in ('birthday','graduation','family_gathering','other') then
    raise exception 'invalid occasion type' using errcode = '22023';
  end if;
  if v_space not in ('any','table','room') then
    raise exception 'invalid space type' using errcode = '22023';
  end if;
  if v_branch is null or not exists (
    select 1 from core.branches b where b.id=v_branch and b.is_active
  ) then raise exception 'invalid branch' using errcode = '22023'; end if;
  if v_start is null or v_start <= now() or v_end is null
     or v_end <= v_start or v_end-v_start < interval '30 minutes'
     or v_end-v_start > interval '8 hours' then
    raise exception 'invalid event time' using errcode = '22023';
  end if;
  if v_start::date < current_date or v_start::date > current_date + 365 then
    raise exception 'event date must be within the next year' using errcode = '22023';
  end if;
  if v_guests is null or v_guests < 2 or v_guests > 40 then
    raise exception 'invalid guest count' using errcode = '22023';
  end if;
  if v_budget is not null and (v_budget < 0 or v_budget > 10000000) then
    raise exception 'invalid budget' using errcode = '22023';
  end if;
  select * into v_profile from identity.profiles p where p.id=v_uid;
  insert into floor.customer_event_requests(
    id,user_id,branch_id,occasion_type,occasion_date,preferred_start_at,
    preferred_end_at,guest_count,requested_space_type,requested_services,
    estimated_budget,customer_name,customer_phone,customer_note
  ) values (
    v_id,v_uid,v_branch,v_type,v_start::date,v_start,v_end,v_guests,v_space,
    nullif(btrim(coalesce(p_payload->>'requested_services','')),''),v_budget,
    coalesce(nullif(btrim(v_profile.full_name),''),'Customer'),
    coalesce(nullif(btrim(v_profile.phone),''),''),
    nullif(btrim(coalesce(p_payload->>'customer_note','')),'')
  );
  return v_id;
end;
$$;
revoke all on function public.create_my_customer_event_request(jsonb) from public, anon;
grant execute on function public.create_my_customer_event_request(jsonb) to authenticated;

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
      select e.*, b.name_ar as branch_name_ar, b.name_en as branch_name_en,
             t.name as quoted_space_name
        from floor.customer_event_requests e
        join core.branches b on b.id=e.branch_id
        left join floor.tables t on t.id=e.quoted_space_id
       where e.user_id=v_uid
    ) x
  ), '[]'::jsonb);
end;
$$;
revoke all on function public.list_my_customer_event_requests() from public, anon;
grant execute on function public.list_my_customer_event_requests() to authenticated;

-- Keep all customer booking fields in one response, including room/table type.
create or replace function public.list_my_reservations()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not authenticated' using errcode = '42501'; end if;
  return coalesce((
    select jsonb_agg(row_to_json(x)::jsonb order by x.reserved_for desc)
    from (
      select r.id, r.branch_id, r.table_id, r.user_id, r.source, r.status,
             r.reservation_type, r.reserved_for, r.requested_end_at,
             r.reserved_until, r.duration_minutes, r.party_size, r.customer_name,
             r.customer_phone, r.note, r.customer_note, r.admin_note,
             r.cancellation_reason, r.reviewed_at, r.created_at, r.updated_at,
             b.name_ar as branch_name_ar, b.name_en as branch_name_en,
             t.name as table_name, t.area as table_area
        from floor.reservations r
        left join core.branches b on b.id=r.branch_id
        left join floor.tables t on t.id=r.table_id
       where r.user_id=v_uid
       order by r.reserved_for desc
    ) x
  ), '[]'::jsonb);
end;
$$;
revoke all on function public.list_my_reservations() from public, anon;
grant execute on function public.list_my_reservations() to authenticated;

create or replace function public.cancel_my_customer_event_request(p_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then raise exception 'not authenticated' using errcode = '42501'; end if;
  update floor.customer_event_requests
     set status='cancelled', cancelled_at=now(), updated_at=now()
   where id=p_id and user_id=auth.uid()
     and status in ('pending','quoted','quote_declined');
  return found;
end;
$$;
revoke all on function public.cancel_my_customer_event_request(uuid) from public, anon;
grant execute on function public.cancel_my_customer_event_request(uuid) to authenticated;

create or replace function public.respond_my_customer_event_quote(
  p_id uuid, p_accept boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_event floor.customer_event_requests%rowtype;
  v_space floor.tables%rowtype;
  v_reservation uuid := gen_random_uuid();
  v_type text;
  v_duration integer;
begin
  if auth.uid() is null then raise exception 'not authenticated' using errcode = '42501'; end if;
  if p_accept is null then raise exception 'response is required' using errcode = '22023'; end if;
  select * into v_event from floor.customer_event_requests e
   where e.id=p_id and e.user_id=auth.uid() for update;
  if not found or v_event.status <> 'quoted' then
    return jsonb_build_object('ok',false,'reason','quote_not_available');
  end if;
  if v_event.quote_expires_at is not null and v_event.quote_expires_at <= now() then
    return jsonb_build_object('ok',false,'reason','quote_expired');
  end if;
  if not p_accept then
    update floor.customer_event_requests
       set status='quote_declined', customer_responded_at=now(), updated_at=now()
     where id=v_event.id;
    return jsonb_build_object('ok',true,'reason','quote_declined');
  end if;
  if v_event.quoted_space_id is null or v_event.quoted_start_at is null
     or v_event.quoted_end_at is null then
    raise exception 'quote is missing venue details' using errcode = '23514';
  end if;
  select * into v_space from floor.tables t
   where t.id=v_event.quoted_space_id and t.branch_id=v_event.branch_id
     and t.is_active for update;
  if not found then return jsonb_build_object('ok',false,'reason','space_unavailable'); end if;
  if v_space.capacity < v_event.guest_count then
    return jsonb_build_object('ok',false,'reason','space_capacity_changed');
  end if;
  if v_event.requested_space_type='room' and v_space.area<>'private_room' then
    return jsonb_build_object('ok',false,'reason','space_type_changed');
  end if;
  if v_event.requested_space_type='table' and v_space.area='private_room' then
    return jsonb_build_object('ok',false,'reason','space_type_changed');
  end if;
  v_type := case when v_space.area='private_room' then 'room' else 'table' end;
  v_duration := (extract(epoch from (v_event.quoted_end_at-v_event.quoted_start_at))/60)::integer;
  insert into floor.reservations(
    id,branch_id,table_id,user_id,source,status,reservation_type,
    reserved_for,duration_minutes,requested_end_at,reserved_until,party_size,
    customer_name,customer_phone,customer_note,note,linked_event_id
  ) values (
    v_reservation,v_event.branch_id,v_space.id,v_event.user_id,'customer',
    'confirmed',v_type,v_event.quoted_start_at,v_duration,v_event.quoted_end_at,
    v_event.quoted_end_at,v_event.guest_count,v_event.customer_name,
    v_event.customer_phone,coalesce(v_event.customer_note,''),
    coalesce(v_event.customer_note,''),v_event.id
  );
  update floor.customer_event_requests
     set status='confirmed', reservation_id=v_reservation,
         customer_responded_at=now(), updated_at=now()
   where id=v_event.id;
  return jsonb_build_object('ok',true,'reason','confirmed','reservation_id',v_reservation);
exception when sqlstate '23P01' then
  return jsonb_build_object('ok',false,'reason','space_busy');
end;
$$;
revoke all on function public.respond_my_customer_event_quote(uuid,boolean) from public, anon;
grant execute on function public.respond_my_customer_event_quote(uuid,boolean) to authenticated;

create or replace function public.admin_list_customer_event_requests(
  p_branch_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare v_branch uuid := p_branch_id;
begin
  if not identity.is_staff() then raise exception 'not authenticated' using errcode = '42501'; end if;
  if not identity.has_permission('tables.read') and not identity.has_permission('tables.manage') then raise exception 'missing permission: tables.read' using errcode = '42501'; end if;
  if v_branch is null then raise exception 'branch_id required' using errcode = '22023'; end if;
  if not identity.can_manage_branch(v_branch) then
    raise exception 'branch out of scope' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(row_to_json(x)::jsonb order by x.created_at desc)
    from (
      select e.*, b.name_ar as branch_name_ar, b.name_en as branch_name_en,
             t.name as quoted_space_name
        from floor.customer_event_requests e
        join core.branches b on b.id=e.branch_id
        left join floor.tables t on t.id=e.quoted_space_id
       where (v_branch is null or e.branch_id=v_branch)
       order by e.created_at desc limit 100
    ) x
  ), '[]'::jsonb);
end;
$$;
revoke all on function public.admin_list_customer_event_requests(uuid) from public, anon;
grant execute on function public.admin_list_customer_event_requests(uuid) to authenticated;

create or replace function public.admin_offer_customer_event_request(
  p_id uuid, p_quote_amount numeric, p_space_id uuid,
  p_quoted_start_at timestamptz, p_quoted_end_at timestamptz,
  p_quote_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_event floor.customer_event_requests%rowtype;
  v_space floor.tables%rowtype;
  v_staff uuid;
begin
  if not identity.is_staff() then raise exception 'not authenticated' using errcode = '42501'; end if;
  if not identity.has_permission('tables.manage') then
    raise exception 'missing permission: tables.manage' using errcode = '42501';
  end if;
  select * into v_event from floor.customer_event_requests e where e.id=p_id for update;
  if not found then return jsonb_build_object('ok',false,'reason','not_found'); end if;
  if not identity.can_manage_branch(v_event.branch_id) then raise exception 'branch out of scope' using errcode = '42501'; end if;
  if v_event.status not in ('pending','quoted','quote_declined') then
    return jsonb_build_object('ok',false,'reason','invalid_status');
  end if;
  if p_quote_amount is null or p_quote_amount<0 or p_quote_amount>10000000
     or p_quote_note is not null and char_length(p_quote_note)>1000 then
    return jsonb_build_object('ok',false,'reason','invalid_quote');
  end if;
  if p_quoted_start_at is null or p_quoted_end_at is null
     or p_quoted_start_at<=now() or p_quoted_end_at<=p_quoted_start_at
     or p_quoted_end_at-p_quoted_start_at<interval '30 minutes'
     or p_quoted_end_at-p_quoted_start_at>interval '8 hours'
     or p_quoted_start_at::date > current_date + 365 then
    return jsonb_build_object('ok',false,'reason','invalid_time');
  end if;
  select * into v_space from floor.tables t
   where t.id=p_space_id and t.branch_id=v_event.branch_id and t.is_active;
  if not found or v_space.capacity<v_event.guest_count then
    return jsonb_build_object('ok',false,'reason','invalid_space');
  end if;
  if v_event.requested_space_type='room' and v_space.area<>'private_room'
     or v_event.requested_space_type='table' and v_space.area='private_room' then
    return jsonb_build_object('ok',false,'reason','space_type_mismatch');
  end if;
  select s.id into v_staff from identity.staff_members s where s.user_id=auth.uid() limit 1;
  update floor.customer_event_requests set
    status='quoted', quote_amount=round(p_quote_amount,2),
    quote_note=nullif(btrim(coalesce(p_quote_note,'')),''),
    quoted_space_id=p_space_id, quoted_start_at=p_quoted_start_at,
    quoted_end_at=p_quoted_end_at, quote_expires_at=now()+interval '48 hours',
    reviewed_by=coalesce(v_staff,reviewed_by), reviewed_at=now(), updated_at=now()
   where id=v_event.id;
  return jsonb_build_object('ok',true,'reason','quoted');
end;
$$;
revoke all on function public.admin_offer_customer_event_request(uuid,numeric,uuid,timestamptz,timestamptz,text) from public, anon;
grant execute on function public.admin_offer_customer_event_request(uuid,numeric,uuid,timestamptz,timestamptz,text) to authenticated;

create or replace function public.admin_reject_customer_event_request(
  p_id uuid, p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare v_event floor.customer_event_requests%rowtype; v_staff uuid;
begin
  if not identity.is_staff() then raise exception 'not authenticated' using errcode = '42501'; end if;
  if not identity.has_permission('tables.manage') then raise exception 'missing permission: tables.manage' using errcode = '42501'; end if;
  select * into v_event from floor.customer_event_requests e where e.id=p_id for update;
  if not found then return jsonb_build_object('ok',false,'reason','not_found'); end if;
  if not identity.can_manage_branch(v_event.branch_id) then raise exception 'branch out of scope' using errcode = '42501'; end if;
  if v_event.status not in ('pending','quote_declined') then return jsonb_build_object('ok',false,'reason','invalid_status'); end if;
  if p_note is not null and char_length(p_note)>1000 then return jsonb_build_object('ok',false,'reason','invalid_note'); end if;
  select s.id into v_staff from identity.staff_members s where s.user_id=auth.uid() limit 1;
  update floor.customer_event_requests set status='rejected', quote_note=nullif(btrim(coalesce(p_note,'')),''), reviewed_by=coalesce(v_staff,reviewed_by), reviewed_at=now(), updated_at=now() where id=v_event.id;
  return jsonb_build_object('ok',true,'reason','rejected');
end;
$$;
revoke all on function public.admin_reject_customer_event_request(uuid,text) from public, anon;
grant execute on function public.admin_reject_customer_event_request(uuid,text) to authenticated;

commit;
