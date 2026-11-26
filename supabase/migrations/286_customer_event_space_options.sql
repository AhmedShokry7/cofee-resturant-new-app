alter table floor.customer_event_requests
  add column if not exists quoted_space_options jsonb not null default '[]'::jsonb;

create or replace function public.admin_offer_customer_event_request_options(
  p_id uuid,
  p_quote_amount numeric,
  p_space_ids uuid[],
  p_quoted_start_at timestamptz,
  p_quoted_end_at timestamptz,
  p_quote_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_event floor.customer_event_requests%rowtype;
  v_staff uuid;
  v_amount numeric(12,2);
  v_options jsonb;
  v_first_space uuid;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('tables.manage') then
    raise exception 'missing permission: tables.manage' using errcode = '42501';
  end if;
  select * into v_event from floor.customer_event_requests e where e.id=p_id for update;
  if not found then return jsonb_build_object('ok',false,'reason','not_found'); end if;
  if not identity.can_manage_branch(v_event.branch_id) then
    raise exception 'branch out of scope' using errcode = '42501';
  end if;
  if v_event.status not in ('pending','quoted','quote_declined') then
    return jsonb_build_object('ok',false,'reason','invalid_status');
  end if;
  if p_quote_amount is null or p_quote_amount < 0 or p_quote_amount > 10000000
     or p_quote_note is not null and char_length(p_quote_note)>1000 then
    return jsonb_build_object('ok',false,'reason','invalid_quote');
  end if;
  if p_quoted_start_at is null or p_quoted_end_at is null
     or p_quoted_start_at<=now() or p_quoted_end_at<=p_quoted_start_at
     or p_quoted_end_at-p_quoted_start_at<interval '30 minutes'
     or p_quoted_end_at-p_quoted_start_at>interval '8 hours'
     or p_quoted_start_at::date>current_date+365 then
    return jsonb_build_object('ok',false,'reason','invalid_time');
  end if;
  if p_space_ids is null or cardinality(p_space_ids)<1 or cardinality(p_space_ids)>30 then
    return jsonb_build_object('ok',false,'reason','invalid_space');
  end if;
  if (select count(distinct x.id) from unnest(p_space_ids) x(id))<>cardinality(p_space_ids)
     or (select count(*) from floor.tables t where t.id=any(p_space_ids)
          and t.branch_id=v_event.branch_id and t.is_active
          and t.capacity>=v_event.guest_count
          and (v_event.requested_space_type='any'
            or (v_event.requested_space_type='room')=(t.area='private_room')))
          <> cardinality(p_space_ids) then
    return jsonb_build_object('ok',false,'reason','invalid_space');
  end if;
  select jsonb_agg(jsonb_build_object(
    'id',t.id,'name',t.name,'image_url',t.image_url,'capacity',t.capacity,
    'space_type',case when t.area='private_room' then 'room' else 'table' end
  ) order by array_position(p_space_ids,t.id)), (array_agg(t.id order by array_position(p_space_ids,t.id)))[1]
    into v_options,v_first_space
    from floor.tables t where t.id=any(p_space_ids);
  select s.id into v_staff from identity.staff_members s where s.user_id=auth.uid() limit 1;
  v_amount:=round(p_quote_amount,2);
  update floor.customer_event_requests set
    status='quoted', quote_amount=v_amount,
    quote_note=nullif(btrim(coalesce(p_quote_note,'')),''),
    quoted_space_id=v_first_space, quoted_space_options=coalesce(v_options,'[]'::jsonb),
    quoted_start_at=p_quoted_start_at, quoted_end_at=p_quoted_end_at,
    quote_expires_at=now()+interval '48 hours', reviewed_by=coalesce(v_staff,reviewed_by),
    reviewed_at=now(), updated_at=now()
   where id=v_event.id;
  insert into engagement.notifications(user_id,type,title_ar,title_en,body_ar,body_en,payload,
    related_entity_type,related_entity_id,dedupe_key)
  values(v_event.user_id,'system','وصلك عرض لحجز مناسبتك','You received an offer for your event',
    'أرسل الفرع عرضًا بقيمة '||v_amount::text||' ريال مع عدة أماكن للاختيار. افتح حجوزاتي لمراجعة الصور واختيار المكان المناسب.',
    'The branch sent a '||v_amount::text||' SAR offer with venue options. Open My Reservations to review photos and choose a place.',
    jsonb_build_object('destination','my_reservations','event_request_id',v_event.id),
    'event_request',v_event.id,'event_quote:'||v_event.id::text||':'||gen_random_uuid()::text);
  return jsonb_build_object('ok',true,'reason','quoted');
end;
$fn$;
revoke all on function public.admin_offer_customer_event_request_options(uuid,numeric,uuid[],timestamptz,timestamptz,text) from public,anon;
grant execute on function public.admin_offer_customer_event_request_options(uuid,numeric,uuid[],timestamptz,timestamptz,text) to authenticated;

create or replace function public.respond_my_customer_event_quote(
  p_id uuid, p_accept boolean, p_space_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_event floor.customer_event_requests%rowtype;
  v_space floor.tables%rowtype;
  v_reservation uuid:=gen_random_uuid();
  v_type text;
  v_duration integer;
begin
  if auth.uid() is null then raise exception 'not authenticated' using errcode='42501'; end if;
  if p_accept is null then raise exception 'response is required' using errcode='22023'; end if;
  select * into v_event from floor.customer_event_requests e where e.id=p_id and e.user_id=auth.uid() for update;
  if not found or v_event.status<>'quoted' then return jsonb_build_object('ok',false,'reason','quote_not_available'); end if;
  if v_event.quote_expires_at is not null and v_event.quote_expires_at<=now() then
    return jsonb_build_object('ok',false,'reason','quote_expired');
  end if;
  if not p_accept then
    update floor.customer_event_requests set status='quote_declined',customer_responded_at=now(),updated_at=now() where id=v_event.id;
    return jsonb_build_object('ok',true,'reason','quote_declined');
  end if;
  if p_space_id is null or (jsonb_array_length(v_event.quoted_space_options)>0
      and not exists(select 1 from jsonb_array_elements(v_event.quoted_space_options) as opts(option) where option->>'id'=p_space_id::text)) then
    return jsonb_build_object('ok',false,'reason','space_unavailable');
  end if;
  select * into v_space from floor.tables t where t.id=p_space_id and t.branch_id=v_event.branch_id and t.is_active for update;
  if not found then return jsonb_build_object('ok',false,'reason','space_unavailable'); end if;
  if v_space.capacity<v_event.guest_count then return jsonb_build_object('ok',false,'reason','space_capacity_changed'); end if;
  if v_event.requested_space_type='room' and v_space.area<>'private_room'
     or v_event.requested_space_type='table' and v_space.area='private_room' then
    return jsonb_build_object('ok',false,'reason','space_type_changed');
  end if;
  v_type:=case when v_space.area='private_room' then 'room' else 'table' end;
  v_duration:=(extract(epoch from (v_event.quoted_end_at-v_event.quoted_start_at))/60)::integer;
  insert into floor.reservations(id,branch_id,table_id,user_id,source,status,reservation_type,
    reserved_for,duration_minutes,requested_end_at,reserved_until,party_size,customer_name,customer_phone,
    customer_note,note,linked_event_id)
  values(v_reservation,v_event.branch_id,v_space.id,v_event.user_id,'customer','confirmed',v_type,
    v_event.quoted_start_at,v_duration,v_event.quoted_end_at,v_event.quoted_end_at,v_event.guest_count,
    v_event.customer_name,v_event.customer_phone,coalesce(v_event.customer_note,''),coalesce(v_event.customer_note,''),v_event.id);
  update floor.customer_event_requests set status='confirmed',quoted_space_id=v_space.id,
    reservation_id=v_reservation,customer_responded_at=now(),updated_at=now() where id=v_event.id;
  return jsonb_build_object('ok',true,'reason','confirmed','reservation_id',v_reservation);
exception when sqlstate '23P01' then return jsonb_build_object('ok',false,'reason','space_busy');
end;
$fn$;
revoke all on function public.respond_my_customer_event_quote(uuid,boolean,uuid) from public,anon;
grant execute on function public.respond_my_customer_event_quote(uuid,boolean,uuid) to authenticated;

notify pgrst,'reload schema';
