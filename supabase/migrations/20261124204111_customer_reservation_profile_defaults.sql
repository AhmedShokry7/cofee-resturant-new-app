-- Customer requests get safe display/contact defaults from the signed-in
-- profile when the client does not include them.
begin;

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
  v_table uuid := nullif(p_payload->>'table_id', '')::uuid;
  v_reserved_for timestamptz := (p_payload->>'reserved_for')::timestamptz;
  v_duration integer := greatest(30, least(coalesce((p_payload->>'duration_minutes')::int, 90), 480));
  v_party integer := greatest(1, least(coalesce((p_payload->>'party_size')::int, 2), 50));
  v_name text := nullif(btrim(coalesce(p_payload->>'customer_name', '')), '');
  v_phone text := nullif(btrim(coalesce(p_payload->>'customer_phone', '')), '');
  v_note text := nullif(btrim(coalesce(p_payload->>'note', '')), '');
  v_customer_note text := nullif(btrim(coalesce(p_payload->>'customer_note', '')), '');
  v_type text := lower(btrim(coalesce(p_payload->>'reservation_type', 'table')));
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if v_branch is null then
    raise exception 'branch_id required';
  end if;
  if v_reserved_for is null then
    raise exception 'reserved_for required';
  end if;
  if v_reserved_for < now() - interval '5 minutes' then
    raise exception 'reservation must be in the future';
  end if;
  if not exists (
    select 1 from core.branches b where b.id = v_branch and b.is_active = true
  ) then
    raise exception 'invalid branch';
  end if;
  if v_table is not null and not exists (
    select 1 from floor.tables t
     where t.id = v_table and t.branch_id = v_branch and t.is_active = true
  ) then
    raise exception 'invalid table';
  end if;

  select
    coalesce(v_name, nullif(btrim(p.full_name), ''), nullif(btrim(p.phone), ''), 'Customer'),
    coalesce(v_phone, nullif(btrim(p.phone), ''), '')
    into v_name, v_phone
    from identity.profiles p
   where p.id = v_uid;
  v_name := coalesce(v_name, 'Customer');
  v_phone := coalesce(v_phone, '');

  insert into floor.reservations (
    id, branch_id, table_id, user_id, source, status, reserved_for,
    duration_minutes, party_size, customer_name, customer_phone, note,
    customer_note, reserved_until, requested_end_at
  ) values (
    v_id, v_branch, v_table, v_uid, 'customer', 'pending', v_reserved_for,
    v_duration, v_party, v_name, v_phone, v_note,
    coalesce(v_customer_note, v_note),
    v_reserved_for + make_interval(mins => v_duration),
    v_reserved_for + make_interval(mins => v_duration)
  );

  return v_id;
end;
$$;
revoke all on function public.create_customer_reservation(jsonb) from public, anon;
grant execute on function public.create_customer_reservation(jsonb) to authenticated;

commit;
