begin;

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

commit;
