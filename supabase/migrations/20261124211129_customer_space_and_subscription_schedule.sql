begin;

-- Customer-safe, read-only choices for the reservation form. floor.tables is
-- intentionally private, so expose only active spaces at an active branch.
create or replace function public.list_customer_reservation_spaces(
  p_branch_id uuid,
  p_reservation_type text,
  p_party_size integer default 2
)
returns table(id uuid, name text, capacity smallint, area text)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_type text := lower(btrim(coalesce(p_reservation_type, '')));
  v_party integer := coalesce(p_party_size, 2);
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if v_type not in ('table', 'room') then
    raise exception 'invalid reservation type' using errcode = '22023';
  end if;
  if v_party < 1 or v_party > 40 then
    raise exception 'invalid party size' using errcode = '22023';
  end if;
  if not exists (
    select 1 from core.branches b
     where b.id = p_branch_id and b.is_active = true
  ) then
    raise exception 'invalid branch' using errcode = '22023';
  end if;

  return query
  select t.id, t.name, t.capacity, t.area
    from floor.tables t
   where t.branch_id = p_branch_id
     and t.is_active = true
     and t.capacity >= v_party
     and ((v_type = 'room' and t.area = 'private_room')
       or (v_type = 'table' and t.area <> 'private_room'))
   order by t.sort_order, t.name;
end;
$$;
revoke all on function public.list_customer_reservation_spaces(uuid, text, integer) from public, anon;
grant execute on function public.list_customer_reservation_spaces(uuid, text, integer) to authenticated;

-- The existing subscription model is a recurring order schedule. The first
-- run must be the selected date/time; subsequent runs advance by the interval.
create or replace function public.create_customer_product_subscription(p_payload jsonb)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_id uuid := gen_random_uuid();
  v_name text := nullif(btrim(coalesce(p_payload->>'name', '')), '');
  v_recurrence text := lower(btrim(coalesce(p_payload->>'recurrence_type', 'weekly')));
  v_interval integer := coalesce((p_payload->>'interval_value')::int, 1);
  v_start date := coalesce((p_payload->>'start_date')::date, current_date);
  v_first_run timestamptz := coalesce(
    (p_payload->>'first_run_at')::timestamptz,
    (coalesce((p_payload->>'start_date')::date, current_date))::timestamptz
  );
  v_branch uuid := nullif(p_payload->>'branch_id', '')::uuid;
  v_fulfillment text := lower(btrim(coalesce(p_payload->>'fulfillment_type', 'pickup')));
  v_delivery uuid := nullif(p_payload->>'delivery_address_id', '')::uuid;
  v_notes text := nullif(btrim(coalesce(p_payload->>'notes', '')), '');
  v_item jsonb;
  v_product uuid;
  v_qty integer;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if v_recurrence not in ('daily', 'weekly', 'monthly') then
    raise exception 'invalid recurrence_type' using errcode = '22023';
  end if;
  if v_interval < 1 or v_interval > 12 then
    raise exception 'interval_value must be between 1 and 12' using errcode = '22023';
  end if;
  if v_first_run <= now() then
    raise exception 'first order time must be in the future' using errcode = '22023';
  end if;
  if v_fulfillment not in ('pickup', 'delivery') then
    raise exception 'invalid fulfillment_type' using errcode = '22023';
  end if;
  if v_branch is null or not exists (
    select 1 from core.branches b where b.id = v_branch and b.is_active = true
  ) then
    raise exception 'invalid branch' using errcode = '22023';
  end if;
  if v_fulfillment = 'delivery' then
    if v_delivery is null or not exists (
      select 1 from identity.customer_addresses a
       where a.id = v_delivery and a.user_id = v_uid and a.archived_at is null
    ) then
      raise exception 'valid delivery address required' using errcode = '22023';
    end if;
  elsif v_delivery is not null then
    raise exception 'pickup subscription cannot include a delivery address' using errcode = '22023';
  end if;

  insert into subscriptions.customer_product_subscriptions (
    id, user_id, name, status, recurrence_type, interval_value, start_date,
    next_run_at, branch_id, fulfillment_type, delivery_address_id, notes
  ) values (
    v_id, v_uid, v_name, 'active', v_recurrence, v_interval, v_start,
    v_first_run, v_branch, v_fulfillment, v_delivery, v_notes
  );

  for v_item in
    select value from jsonb_array_elements(coalesce(p_payload->'items', '[]'::jsonb))
  loop
    v_product := nullif(v_item->>'product_id', '')::uuid;
    v_qty := coalesce((v_item->>'quantity')::int, 1);
    if v_product is null or v_qty < 1 or v_qty > 99 then
      raise exception 'invalid subscription item' using errcode = '22023';
    end if;
    if not exists (
      select 1 from catalog.products p where p.id = v_product and p.is_active = true
    ) then
      raise exception 'invalid product' using errcode = '22023';
    end if;
    insert into subscriptions.customer_product_subscription_items (
      subscription_id, product_id, quantity, selected_options, note
    ) values (
      v_id, v_product, v_qty,
      coalesce(v_item->'selected_options', '{}'::jsonb),
      nullif(btrim(coalesce(v_item->>'note', '')), '')
    );
  end loop;

  if not exists (
    select 1 from subscriptions.customer_product_subscription_items i
     where i.subscription_id = v_id
  ) then
    raise exception 'at least one item required' using errcode = '22023';
  end if;
  return v_id;
end;
$$;
revoke all on function public.create_customer_product_subscription(jsonb) from public, anon;
grant execute on function public.create_customer_product_subscription(jsonb) to authenticated;

-- Return the selected space and type to the customer's reservation list.
create or replace function public.list_my_reservations()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(row_to_json(x)::jsonb order by x.reserved_for desc)
      from (
        select r.id, r.branch_id, r.table_id, r.user_id, r.source, r.status,
               r.reservation_type, r.reserved_for, r.reserved_until,
               r.requested_end_at, r.duration_minutes, r.party_size,
               r.customer_name, r.customer_phone, r.note, r.customer_note,
               r.admin_note, r.cancellation_reason, r.reviewed_at,
               r.created_at, r.updated_at, b.name_ar as branch_name_ar,
               b.name_en as branch_name_en, t.name as table_name,
               t.area as table_area
          from floor.reservations r
          left join core.branches b on b.id = r.branch_id
          left join floor.tables t on t.id = r.table_id
         where r.user_id = v_uid
         order by r.reserved_for desc
      ) x
  ), '[]'::jsonb);
end;
$$;
revoke all on function public.list_my_reservations() from public, anon;
grant execute on function public.list_my_reservations() to authenticated;

-- Requests without an assigned resource remain pending and staff can assign
-- the requested type. Assigned customer requests must point to a matching
-- active room/table in the same branch and have enough capacity.
create or replace function public.create_customer_reservation(p_payload jsonb)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_id uuid := gen_random_uuid();
  v_branch uuid := nullif(p_payload->>'branch_id', '')::uuid;
  v_space uuid := nullif(p_payload->>'table_id', '')::uuid;
  v_reserved_for timestamptz := (p_payload->>'reserved_for')::timestamptz;
  v_duration integer := coalesce((p_payload->>'duration_minutes')::int, 90);
  v_party integer := coalesce((p_payload->>'party_size')::int, 2);
  v_type text := lower(btrim(coalesce(p_payload->>'reservation_type', 'table')));
  v_name text;
  v_phone text;
  v_note text := nullif(btrim(coalesce(p_payload->>'note', '')), '');
  v_area text;
  v_capacity smallint;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if v_type not in ('table', 'room') then
    raise exception 'invalid reservation type' using errcode = '22023';
  end if;
  if v_branch is null or not exists (
    select 1 from core.branches b where b.id = v_branch and b.is_active = true
  ) then
    raise exception 'invalid branch' using errcode = '22023';
  end if;
  if v_reserved_for is null or v_reserved_for <= now() then
    raise exception 'reservation must be in the future' using errcode = '22023';
  end if;
  if v_duration < 30 or v_duration > 480 then
    raise exception 'invalid reservation duration' using errcode = '22023';
  end if;
  if v_party < 1 or v_party > 40 then
    raise exception 'invalid party size' using errcode = '22023';
  end if;
  if v_space is not null then
    select t.area, t.capacity into v_area, v_capacity
      from floor.tables t
     where t.id = v_space and t.branch_id = v_branch and t.is_active = true;
    if not found then
      raise exception 'selected room or table is unavailable' using errcode = '22023';
    end if;
    if (v_type = 'room' and v_area <> 'private_room')
       or (v_type = 'table' and v_area = 'private_room') then
      raise exception 'selected space does not match reservation type' using errcode = '22023';
    end if;
    if v_capacity < v_party then
      raise exception 'selected space does not fit party size' using errcode = '22023';
    end if;
  end if;

  select coalesce(nullif(btrim(p.full_name), ''), nullif(btrim(p.phone), ''), 'Customer'),
         coalesce(nullif(btrim(p.phone), ''), '')
    into v_name, v_phone
    from identity.profiles p where p.id = v_uid;
  v_name := coalesce(v_name, 'Customer');
  v_phone := coalesce(v_phone, '');

  insert into floor.reservations (
    id, branch_id, table_id, user_id, source, status, reservation_type,
    reserved_for, duration_minutes, party_size, customer_name, customer_phone,
    note, customer_note, reserved_until, requested_end_at
  ) values (
    v_id, v_branch, v_space, v_uid, 'customer', 'pending', v_type,
    v_reserved_for, v_duration, v_party, v_name, v_phone, coalesce(v_note, ''),
    v_note, v_reserved_for + make_interval(mins => v_duration),
    v_reserved_for + make_interval(mins => v_duration)
  );
  return v_id;
end;
$$;
revoke all on function public.create_customer_reservation(jsonb) from public, anon;
grant execute on function public.create_customer_reservation(jsonb) to authenticated;

commit;
