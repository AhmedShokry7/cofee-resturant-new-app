alter table floor.customer_event_requests
  add column if not exists occasion_name text,
  add column if not exists reminder_minutes integer not null default 1440,
  add column if not exists reminder_at timestamptz,
  add column if not exists reminder_sent_at timestamptz;

alter table floor.customer_event_requests
  drop constraint if exists ck_customer_event_occasion_name,
  add constraint ck_customer_event_occasion_name check (
    occasion_name is null or char_length(btrim(occasion_name)) between 1 and 120
  ),
  drop constraint if exists ck_customer_event_reminder_minutes,
  add constraint ck_customer_event_reminder_minutes check (
    reminder_minutes in (60, 180, 1440)
  );

alter table floor.tables add column if not exists image_url text;

create or replace function public.create_my_customer_event_request(p_payload jsonb)
returns uuid
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_uid uuid := auth.uid();
  v_profile identity.profiles%rowtype;
  v_branch uuid := nullif(p_payload->>'branch_id','')::uuid;
  v_type text := lower(btrim(coalesce(p_payload->>'occasion_type','')));
  v_occasion_name text := nullif(btrim(coalesce(p_payload->>'occasion_name','')), '');
  v_space text := lower(btrim(coalesce(p_payload->>'requested_space_type','any')));
  v_start timestamptz := nullif(p_payload->>'preferred_start_at','')::timestamptz;
  v_end timestamptz := nullif(p_payload->>'preferred_end_at','')::timestamptz;
  v_guests integer := nullif(p_payload->>'guest_count','')::integer;
  v_budget numeric := nullif(p_payload->>'estimated_budget','')::numeric;
  v_reminder_minutes integer := coalesce(nullif(p_payload->>'reminder_minutes','')::integer,1440);
  v_id uuid := gen_random_uuid();
begin
  if v_uid is null then raise exception 'not authenticated' using errcode = '42501'; end if;
  if v_type not in ('birthday','graduation','family_gathering','other') then
    raise exception 'invalid occasion type' using errcode = '22023';
  end if;
  if v_type = 'other' and (v_occasion_name is null or char_length(v_occasion_name) > 120) then
    raise exception 'occasion name is required' using errcode = '22023';
  end if;
  if v_space not in ('any','table','room') then
    raise exception 'invalid space type' using errcode = '22023';
  end if;
  if v_reminder_minutes not in (60,180,1440) then
    raise exception 'invalid reminder time' using errcode = '22023';
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
    id,user_id,branch_id,occasion_type,occasion_name,occasion_date,
    preferred_start_at,preferred_end_at,guest_count,requested_space_type,
    requested_services,estimated_budget,reminder_minutes,customer_name,
    customer_phone,customer_note
  ) values (
    v_id,v_uid,v_branch,v_type,case when v_type='other' then v_occasion_name else null end,
    v_start::date,v_start,v_end,v_guests,v_space,
    nullif(btrim(coalesce(p_payload->>'requested_services','')),''),v_budget,
    v_reminder_minutes,
    coalesce(nullif(btrim(v_profile.full_name),''),'Customer'),
    coalesce(nullif(btrim(v_profile.phone),''),''),
    nullif(btrim(coalesce(p_payload->>'customer_note','')),'')
  );
  return v_id;
end;
$fn$;
revoke all on function public.create_my_customer_event_request(jsonb) from public, anon;
grant execute on function public.create_my_customer_event_request(jsonb) to authenticated;

drop function if exists public.list_customer_reservation_spaces(uuid, text, integer);
create function public.list_customer_reservation_spaces(
  p_branch_id uuid,
  p_reservation_type text,
  p_party_size integer default 2
)
returns table(id uuid, name text, capacity smallint, area text, image_url text)
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_type text := lower(btrim(coalesce(p_reservation_type, '')));
  v_party integer := coalesce(p_party_size, 2);
begin
  if auth.uid() is null then raise exception 'not authenticated' using errcode = '42501'; end if;
  if v_type not in ('table', 'room') then raise exception 'invalid reservation type' using errcode = '22023'; end if;
  if v_party < 1 or v_party > 40 then raise exception 'invalid party size' using errcode = '22023'; end if;
  if not exists (select 1 from core.branches b where b.id = p_branch_id and b.is_active = true) then
    raise exception 'invalid branch' using errcode = '22023';
  end if;
  return query
  select t.id, t.name, t.capacity, t.area, t.image_url
    from floor.tables t
   where t.branch_id = p_branch_id
     and t.is_active = true
     and t.capacity >= v_party
     and ((v_type = 'room' and t.area = 'private_room')
       or (v_type = 'table' and t.area <> 'private_room'))
   order by t.sort_order, t.name;
end;
$fn$;
revoke all on function public.list_customer_reservation_spaces(uuid, text, integer) from public, anon;
grant execute on function public.list_customer_reservation_spaces(uuid, text, integer) to authenticated;

create or replace function public.admin_set_dining_table_image(
  p_branch_id uuid,
  p_name text,
  p_image_url text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_table floor.tables%rowtype;
  v_url text := nullif(btrim(coalesce(p_image_url, '')), '');
begin
  if not identity.is_staff() or not identity.has_permission('tables.manage') then
    raise exception 'missing permission: tables.manage' using errcode = '42501';
  end if;
  if not identity.can_manage_branch(p_branch_id) then
    raise exception 'branch out of scope' using errcode = '42501';
  end if;
  if v_url is not null and (char_length(v_url) > 2048 or v_url !~* '^https?://') then
    return jsonb_build_object('ok', false, 'reason', 'invalid_image_url');
  end if;
  select * into v_table from floor.tables t
   where t.branch_id = p_branch_id and lower(t.name) = lower(btrim(p_name))
   for update;
  if not found then return jsonb_build_object('ok', false, 'reason', 'not_found'); end if;
  update floor.tables set image_url = v_url, updated_at = now() where id = v_table.id;
  return jsonb_build_object('ok', true, 'id', v_table.id);
end;
$fn$;
revoke all on function public.admin_set_dining_table_image(uuid,text,text) from public, anon;
grant execute on function public.admin_set_dining_table_image(uuid,text,text) to authenticated;

create or replace function public.admin_list_dining_table_images(p_branch_id uuid)
returns table(id uuid, image_url text)
language plpgsql
stable
security definer
set search_path = ''
as $fn$
begin
  if not identity.is_staff() or not identity.has_permission('tables.read') then
    raise exception 'missing permission: tables.read' using errcode = '42501';
  end if;
  if not identity.can_manage_branch(p_branch_id) then
    raise exception 'branch out of scope' using errcode = '42501';
  end if;
  return query select t.id, t.image_url from floor.tables t where t.branch_id = p_branch_id;
end;
$fn$;
revoke all on function public.admin_list_dining_table_images(uuid) from public, anon;
grant execute on function public.admin_list_dining_table_images(uuid) to authenticated;

notify pgrst, 'reload schema';
