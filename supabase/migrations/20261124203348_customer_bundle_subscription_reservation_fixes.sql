-- Fix customer bundle, product subscription, and reservation flows.
-- This migration is additive and keeps existing customer data intact.

begin;

-- The bundle repository persists this timestamp when a customer reuses a bundle.
alter table public.customer_bundles
  add column if not exists last_used_at timestamptz;

create or replace function public.tg_set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = pg_catalog.now();
  return new;
end;
$$;

-- The customer UI offers daily, weekly, and monthly recurrence.
alter table subscriptions.customer_product_subscriptions
  drop constraint if exists ck_cps_recurrence;
alter table subscriptions.customer_product_subscriptions
  add constraint ck_cps_recurrence
  check (recurrence_type in ('daily', 'weekly', 'monthly'));

create or replace function subscriptions.customer_product_subscription_next_run(
  p_from timestamptz,
  p_recurrence_type text,
  p_interval_value integer
)
returns timestamptz
language sql
immutable
set search_path = ''
as $$
  select case
    when p_recurrence_type = 'daily'
      then p_from + make_interval(days => greatest(1, coalesce(p_interval_value, 1)))
    when p_recurrence_type = 'weekly'
      then p_from + make_interval(weeks => greatest(1, coalesce(p_interval_value, 1)))
    else p_from + make_interval(months => greatest(1, coalesce(p_interval_value, 1)))
  end;
$$;

-- Keep validation aligned with the recurrence choices accepted by the table.
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
  v_interval integer := greatest(1, least(coalesce((p_payload->>'interval_value')::int, 1), 12));
  v_start date := coalesce((p_payload->>'start_date')::date, current_date);
  v_branch uuid := nullif(p_payload->>'branch_id', '')::uuid;
  v_fulfillment text := lower(btrim(coalesce(p_payload->>'fulfillment_type', 'pickup')));
  v_delivery uuid := nullif(p_payload->>'delivery_address_id', '')::uuid;
  v_notes text := nullif(btrim(coalesce(p_payload->>'notes', '')), '');
  v_next_run timestamptz;
  v_item jsonb;
  v_product uuid;
  v_qty integer;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if v_recurrence not in ('daily', 'weekly', 'monthly') then
    raise exception 'invalid recurrence_type';
  end if;
  if v_fulfillment not in ('pickup', 'delivery') then
    raise exception 'invalid fulfillment_type';
  end if;
  if v_branch is null then
    raise exception 'branch_id required';
  end if;
  if not exists (
    select 1 from core.branches b where b.id = v_branch and b.is_active = true
  ) then
    raise exception 'invalid branch';
  end if;
  if v_fulfillment = 'delivery' and v_delivery is not null then
    if not exists (
      select 1 from identity.customer_addresses a
       where a.id = v_delivery and a.user_id = v_uid
    ) then
      raise exception 'invalid delivery address';
    end if;
  end if;

  v_next_run := subscriptions.customer_product_subscription_next_run(
    v_start::timestamptz, v_recurrence, v_interval
  );
  if v_next_run < now() then
    v_next_run := subscriptions.customer_product_subscription_next_run(
      now(), v_recurrence, v_interval
    );
  end if;

  insert into subscriptions.customer_product_subscriptions (
    id, user_id, name, status, recurrence_type, interval_value, start_date,
    next_run_at, branch_id, fulfillment_type, delivery_address_id, notes
  ) values (
    v_id, v_uid, v_name, 'active', v_recurrence, v_interval, v_start,
    v_next_run, v_branch, v_fulfillment, v_delivery, v_notes
  );

  for v_item in
    select * from jsonb_array_elements(coalesce(p_payload->'items', '[]'::jsonb))
  loop
    v_product := nullif(v_item->>'product_id', '')::uuid;
    v_qty := greatest(1, least(coalesce((v_item->>'quantity')::int, 1), 99));
    if v_product is null then
      continue;
    end if;
    if not exists (
      select 1 from catalog.products p where p.id = v_product and p.is_active = true
    ) then
      raise exception 'invalid product %', v_product;
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
    raise exception 'at least one item required';
  end if;

  return v_id;
end;
$$;
revoke all on function public.create_customer_product_subscription(jsonb) from public, anon;
grant execute on function public.create_customer_product_subscription(jsonb) to authenticated;

-- A customer request may be submitted without a table assignment. Staff must
-- assign an active table before approving it; assigned reservations retain the
-- existing branch and overlap checks.
create or replace function floor.validate_reservation()
returns trigger
language plpgsql
set search_path = ''
as $fn$
declare
  v_table_branch uuid;
  v_table_active boolean;
  v_start timestamptz;
  v_end timestamptz;
  v_buffer interval := interval '15 minutes';
  v_conflict uuid;
begin
  if new.reserved_for is null then
    raise exception 'reservation time is required' using errcode = '23502';
  end if;

  new.duration_minutes := coalesce(new.duration_minutes, 90);
  if new.duration_minutes < 30 or new.duration_minutes > 480 then
    raise exception 'invalid reservation duration' using errcode = '22023';
  end if;

  if new.table_id is null then
    if new.source <> 'customer' or new.status <> 'pending' then
      raise exception 'reservation table is required' using errcode = '23502';
    end if;
    if not exists (
      select 1 from core.branches b
       where b.id = new.branch_id and b.is_active = true
    ) then
      raise exception 'invalid branch' using errcode = '23503';
    end if;
  else
    select t.branch_id, t.is_active
      into v_table_branch, v_table_active
      from floor.tables t
     where t.id = new.table_id
     for share;

    if v_table_branch is null then
      raise exception 'table not found' using errcode = '23503';
    end if;

    new.branch_id := v_table_branch;
    if new.status in ('approved', 'confirmed', 'seated') and not v_table_active then
      raise exception 'table is inactive' using errcode = '23514';
    end if;
  end if;

  new.reserved_until := new.reserved_for + make_interval(mins => new.duration_minutes);
  new.requested_end_at := coalesce(new.requested_end_at, new.reserved_until);

  if new.table_id is not null and new.status in ('approved', 'confirmed', 'seated') then
    v_start := new.reserved_for - v_buffer;
    v_end := new.reserved_until + v_buffer;

    select r.id into v_conflict
      from floor.reservations r
     where r.table_id = new.table_id
       and r.id is distinct from new.id
       and r.status in ('approved', 'confirmed', 'seated')
       and tstzrange(r.reserved_for - v_buffer, r.reserved_until + v_buffer, '[)')
           && tstzrange(v_start, v_end, '[)')
     limit 1
     for share;

    if v_conflict is not null then
      raise exception 'reservation overlaps another booking' using errcode = '23P01';
    end if;
  end if;

  return new;
end;
$fn$;

commit;
