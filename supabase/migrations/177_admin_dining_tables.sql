-- 177_admin_dining_tables.sql
-- Dining tables, private rooms and reservations for the admin app and the POS.
--
-- The counter used a free-text table number, so two cashiers could open the
-- same table, and there was no place to record a guest booking. This migration:
--   1. adds the tables.read / tables.manage permissions and their role grants;
--   2. creates floor.tables (tables and private rooms) and floor.reservations;
--   3. derives table availability from active orders and current reservations;
--   4. adds permission-checked CRUD RPCs for the tables and reservations page;
--   5. links orders to a real table and reservation;
--   6. replaces direct POS checkout with an atomic table-aware RPC.
--
-- Reads and writes only go through the RPCs below. The floor schema itself is
-- not exposed to the API roles.

-- ---------------------------------------------------------------------------
-- 1. Permissions and role grants
-- ---------------------------------------------------------------------------
insert into identity.permissions (code, name_ar, name_en, description) values
  ('tables.read',
   'عرض الصالة والطاولات',
   'View tables and rooms',
   'See the dining floor, table statuses and reservations.'),
  ('tables.manage',
   'إدارة الصالة والطاولات',
   'Manage tables and rooms',
   'Create and edit tables, rooms and reservations, and move guests through '
   'their reservation status.')
on conflict (code) do update
  set name_ar     = excluded.name_ar,
      name_en     = excluded.name_en,
      description = excluded.description;

-- The counter team runs the floor in a café: cashiers can add a booking and
-- seat a guest, so they receive both permissions. Kitchen staff do not.
insert into identity.role_permissions (role_id, permission_id)
select r.id, p.id
  from identity.roles r
  join identity.permissions p
    on p.code in ('tables.read', 'tables.manage')
 where r.code in ('manager', 'branch_manager', 'cashier')
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- 2. Schema
-- ---------------------------------------------------------------------------
create schema if not exists floor;

create table if not exists floor.tables (
  id          uuid primary key default extensions.gen_random_uuid(),
  branch_id   uuid not null references core.branches(id) on delete cascade,
  name        text not null,
  area        text not null default 'hall'
                check (area in ('hall', 'terrace', 'private_room', 'other')),
  capacity    smallint not null default 2
                check (capacity between 1 and 40),
  is_active   boolean not null default true,
  sort_order  integer not null default 0,
  note        text not null default '',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint ck_floor_table_name check (
    btrim(name) <> '' and char_length(name) <= 20
  ),
  constraint ck_floor_table_note check (char_length(note) <= 240)
);

comment on table floor.tables is
  'Dining tables and private rooms. The name is the short label printed on '
  'the floor plan and snapshotted into orders.orders.table_number.';

-- Table names are unique per branch regardless of case, because the POS also
-- resolves legacy table numbers by label.
create unique index if not exists uq_floor_table_name
  on floor.tables (branch_id, lower(name));

create index if not exists ix_floor_tables_branch
  on floor.tables (branch_id, is_active, sort_order);

create table if not exists floor.reservations (
  id                uuid primary key default extensions.gen_random_uuid(),
  branch_id         uuid not null references core.branches(id) on delete cascade,
  table_id          uuid not null references floor.tables(id) on delete restrict,
  customer_name     text not null,
  customer_phone    text not null default '',
  party_size        smallint not null check (party_size between 1 and 40),
  reserved_for      timestamptz not null,
  duration_minutes  smallint not null default 90
                      check (duration_minutes between 30 and 480),
  status            text not null default 'confirmed'
                      check (status in
                        ('confirmed', 'seated', 'completed', 'cancelled', 'no_show')),
  note              text not null default '',
  order_id          uuid references orders.orders(id) on delete set null,
  created_by        uuid references identity.profiles(id) on delete set null,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  seated_at         timestamptz,
  completed_at      timestamptz,
  cancelled_at      timestamptz,
  constraint ck_floor_reservation_name check (
    btrim(customer_name) <> '' and char_length(customer_name) <= 120
  ),
  constraint ck_floor_reservation_phone check (char_length(customer_phone) <= 40),
  constraint ck_floor_reservation_note check (char_length(note) <= 500)
);

comment on table floor.reservations is
  'Guest bookings for a dining table or private room, optionally linked to '
  'the order opened when the guest is seated.';

create index if not exists ix_floor_reservations_branch
  on floor.reservations (branch_id, reserved_for);
create index if not exists ix_floor_reservations_table
  on floor.reservations (table_id, reserved_for);
create index if not exists ix_floor_reservations_status
  on floor.reservations (status, reserved_for);
create index if not exists ix_floor_reservations_order
  on floor.reservations (order_id)
  where order_id is not null;

-- ---------------------------------------------------------------------------
-- 3. Bookkeeping triggers
-- ---------------------------------------------------------------------------
create or replace function floor.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $fn$
begin
  new.updated_at := now();
  return new;
end;
$fn$;

revoke all on function floor.touch_updated_at() from public, anon, authenticated;

drop trigger if exists tr_floor_tables_updated_at on floor.tables;
create trigger tr_floor_tables_updated_at
  before update on floor.tables
  for each row execute function floor.touch_updated_at();

drop trigger if exists tr_floor_reservations_updated_at on floor.reservations;
create trigger tr_floor_reservations_updated_at
  before update on floor.reservations
  for each row execute function floor.touch_updated_at();

-- A reservation must point at a table of its own branch. A confirmed or seated
-- reservation holds its table for its whole window, so two overlapping guest
-- bookings on the same table are rejected. The advisory lock closes the race
-- between two simultaneous bookings.
create or replace function floor.validate_reservation()
returns trigger
language plpgsql
set search_path = ''
as $fn$
begin
  if not exists (
    select 1
      from floor.tables t
     where t.id = new.table_id
       and t.branch_id = new.branch_id
  ) then
    raise exception 'reservation table belongs to another branch'
      using errcode = '23514';
  end if;

  if new.status in ('confirmed', 'seated') then
    perform pg_advisory_xact_lock(
      hashtext('floor.reservation:' || new.table_id::text)
    );

    if exists (
      select 1
        from floor.reservations r
       where r.table_id = new.table_id
         and r.id is distinct from new.id
         and r.status in ('confirmed', 'seated')
         and r.reserved_for <
               new.reserved_for + make_interval(mins => new.duration_minutes)
         and new.reserved_for <
               r.reserved_for + make_interval(mins => r.duration_minutes)
    ) then
      raise exception 'reservation overlaps another booking on this table'
        using errcode = '23505';
    end if;
  end if;

  return new;
end;
$fn$;

revoke all on function floor.validate_reservation()
  from public, anon, authenticated;

drop trigger if exists tr_floor_reservations_validate on floor.reservations;
create trigger tr_floor_reservations_validate
  before insert or update of table_id, branch_id, reserved_for,
    duration_minutes, status
  on floor.reservations
  for each row execute function floor.validate_reservation();

-- Closing an order that was opened for a seated reservation closes the
-- reservation too, so the floor plan frees the table and the guest history is
-- complete.
create or replace function floor.sync_reservation_with_order()
returns trigger
language plpgsql
set search_path = ''
as $fn$
begin
  if new.dining_reservation_id is not null
     and new.status in ('completed', 'cancelled')
     and old.status not in ('completed', 'cancelled') then
    update floor.reservations
       set status = case
             when new.status = 'cancelled' then 'cancelled'
             else 'completed'
           end,
           completed_at = case
             when new.status = 'completed' then now()
             else completed_at
           end,
           cancelled_at = case
             when new.status = 'cancelled' then now()
             else cancelled_at
           end
     where id = new.dining_reservation_id
       and status = 'seated';
  end if;
  return new;
end;
$fn$;

revoke all on function floor.sync_reservation_with_order()
  from public, anon, authenticated;

drop trigger if exists tr_orders_sync_reservation on orders.orders;
create trigger tr_orders_sync_reservation
  after update of status on orders.orders
  for each row execute function floor.sync_reservation_with_order();

-- ---------------------------------------------------------------------------
-- 4. Link orders to a real floor table and reservation
-- ---------------------------------------------------------------------------
alter table orders.orders
  add column if not exists floor_table_id uuid
    references floor.tables(id) on delete set null;

alter table orders.orders
  add column if not exists dining_reservation_id uuid
    references floor.reservations(id) on delete set null;

comment on column orders.orders.floor_table_id is
  'The real dining table selected at the POS. table_number keeps the printed '
  'label so historical orders stay readable after a rename.';
comment on column orders.orders.dining_reservation_id is
  'The seated reservation this order belongs to, when the guest had a booking.';

create index if not exists ix_orders_floor_table
  on orders.orders (floor_table_id, status)
  where floor_table_id is not null;

create index if not exists ix_orders_dining_reservation
  on orders.orders (dining_reservation_id)
  where dining_reservation_id is not null;

-- ---------------------------------------------------------------------------
-- 5. Admin overview
-- ---------------------------------------------------------------------------
create or replace function public.admin_dining_overview(
  p_branch_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_target       uuid;
  v_branches     jsonb;
  v_tables       jsonb := '[]'::jsonb;
  v_reservations jsonb := '[]'::jsonb;
  v_metrics      jsonb;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('tables.read') then
    raise exception 'missing permission: tables.read' using errcode = '42501';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
           'id', b.id,
           'code', b.code,
           'name_ar', b.name_ar,
           'name_en', b.name_en,
           'is_active', b.is_active
         ) order by b.name_ar, b.name_en), '[]'::jsonb)
    into v_branches
    from core.branches b
   where b.is_active
     and identity.can_manage_branch(b.id);

  v_target := p_branch_id;
  if v_target is null then
    select b.id
      into v_target
      from core.branches b
     where b.is_active
       and identity.can_manage_branch(b.id)
     order by b.name_ar, b.name_en
     limit 1;
  end if;

  if v_target is null then
    return jsonb_build_object(
      'branch_id', null,
      'branches', v_branches,
      'tables', '[]'::jsonb,
      'reservations', '[]'::jsonb,
      'metrics', jsonb_build_object(
        'tables', 0,
        'available', 0,
        'occupied', 0,
        'reserved', 0,
        'reservations_today', 0,
        'upcoming', 0
      )
    );
  end if;

  if not exists (
    select 1 from core.branches b
     where b.id = v_target
       and identity.can_manage_branch(b.id)
  ) then
    raise exception 'branch out of scope' using errcode = '42501';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
           'id', t.id,
           'branch_id', t.branch_id,
           'name', t.name,
           'area', t.area,
           'capacity', t.capacity,
           'is_active', t.is_active,
           'sort_order', t.sort_order,
           'note', t.note,
           'status', case
             when not t.is_active then 'inactive'
             when ao.id is not null then 'occupied'
             when cr.id is not null then cr.status
             else 'available'
           end,
           'active_order', case
             when ao.id is null then null
             else jsonb_build_object(
               'id', ao.id,
               'order_number', ao.order_number,
               'status', ao.status,
               'grand_total', ao.grand_total,
               'placed_at', ao.placed_at,
               'reservation_id', ao.dining_reservation_id
             )
           end,
           'reservation', case
             when cr.id is null then null
             else jsonb_build_object(
               'id', cr.id,
               'customer_name', cr.customer_name,
               'customer_phone', cr.customer_phone,
               'party_size', cr.party_size,
               'reserved_for', cr.reserved_for,
               'duration_minutes', cr.duration_minutes,
               'status', cr.status,
               'note', cr.note,
               'order_id', cr.order_id
             )
           end,
           'next_reservation', case
             when nr.id is null then null
             else jsonb_build_object(
               'id', nr.id,
               'customer_name', nr.customer_name,
               'customer_phone', nr.customer_phone,
               'party_size', nr.party_size,
               'reserved_for', nr.reserved_for,
               'duration_minutes', nr.duration_minutes,
               'status', nr.status,
               'note', nr.note,
               'order_id', nr.order_id
             )
           end
         ) order by
           case t.area
             when 'hall' then 1
             when 'terrace' then 2
             when 'private_room' then 3
             else 4
           end,
           t.sort_order,
           t.name), '[]'::jsonb)
    into v_tables
    from floor.tables t
    left join lateral (
      select o.id, o.order_number, o.status, o.grand_total, o.placed_at,
             o.dining_reservation_id
        from orders.orders o
       where o.floor_table_id = t.id
         and o.status not in ('completed', 'cancelled')
       order by o.placed_at desc
       limit 1
    ) ao on true
    left join lateral (
      select r.id, r.customer_name, r.customer_phone, r.party_size,
             r.reserved_for, r.duration_minutes, r.status, r.note, r.order_id
        from floor.reservations r
       where r.table_id = t.id
         and (
           r.status = 'seated'
           or (
             r.status = 'confirmed'
             and r.reserved_for <= now() + interval '30 minutes'
             and r.reserved_for + make_interval(mins => r.duration_minutes) > now()
           )
         )
       order by r.reserved_for
       limit 1
    ) cr on true
    left join lateral (
      select r.id, r.customer_name, r.customer_phone, r.party_size,
             r.reserved_for, r.duration_minutes, r.status, r.note, r.order_id
        from floor.reservations r
       where r.table_id = t.id
         and r.status = 'confirmed'
         and r.reserved_for > now()
         and r.id is distinct from cr.id
       order by r.reserved_for
       limit 1
    ) nr on true
   where t.branch_id = v_target;

  select coalesce(jsonb_agg(reservation_row order by reserved_for), '[]'::jsonb)
    into v_reservations
    from (
      select jsonb_build_object(
               'id', r.id,
               'branch_id', r.branch_id,
               'table_id', r.table_id,
               'table_name', t.name,
               'area', t.area,
               'customer_name', r.customer_name,
               'customer_phone', r.customer_phone,
               'party_size', r.party_size,
               'reserved_for', r.reserved_for,
               'duration_minutes', r.duration_minutes,
               'status', r.status,
               'note', r.note,
               'order_id', r.order_id,
               'created_at', r.created_at
             ) as reservation_row,
             r.reserved_for
        from floor.reservations r
        join floor.tables t on t.id = r.table_id
       where r.branch_id = v_target
         and r.reserved_for >= date_trunc('day', now())
         and r.reserved_for < date_trunc('day', now()) + interval '30 days'
       order by r.reserved_for
       limit 300
    ) rows;

  select jsonb_build_object(
           'tables', count(*) filter (where item->>'status' <> 'inactive'),
           'available', count(*) filter (where item->>'status' = 'available'),
           'occupied', count(*) filter (where item->>'status' = 'occupied'),
           'reserved', count(*) filter (where item->>'status' in ('reserved', 'seated'))
         )
    into v_metrics
    from jsonb_array_elements(v_tables) item;

  v_metrics := v_metrics || jsonb_build_object(
    'reservations_today', (
      select count(*)
        from floor.reservations r
       where r.branch_id = v_target
         and r.status in ('confirmed', 'seated')
         and r.reserved_for >= date_trunc('day', now())
         and r.reserved_for < date_trunc('day', now()) + interval '1 day'
    ),
    'upcoming', (
      select count(*)
        from floor.reservations r
       where r.branch_id = v_target
         and r.status = 'confirmed'
         and r.reserved_for >= now()
         and r.reserved_for < now() + interval '7 days'
    )
  );

  return jsonb_build_object(
    'branch_id', v_target,
    'branches', v_branches,
    'tables', v_tables,
    'reservations', v_reservations,
    'metrics', v_metrics
  );
end;
$fn$;

comment on function public.admin_dining_overview(uuid) is
  'Dining tables, live statuses, today/upcoming reservations and metrics for '
  'one accessible branch.';

revoke all on function public.admin_dining_overview(uuid) from public, anon;
grant execute on function public.admin_dining_overview(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 6. Table CRUD
-- ---------------------------------------------------------------------------
create or replace function public.admin_save_dining_table(p_table jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_id       uuid := nullif(btrim(coalesce(p_table->>'id', '')), '')::uuid;
  v_branch   uuid := nullif(btrim(coalesce(p_table->>'branch_id', '')), '')::uuid;
  v_name     text := btrim(coalesce(p_table->>'name', ''));
  v_area     text := coalesce(nullif(btrim(p_table->>'area'), ''), 'hall');
  v_capacity integer := coalesce((p_table->>'capacity')::integer, 2);
  v_active   boolean := coalesce((p_table->>'is_active')::boolean, true);
  v_note     text := btrim(coalesce(p_table->>'note', ''));
  v_sort     integer := coalesce((p_table->>'sort_order')::integer, 0);
  v_existing floor.tables%rowtype;
  v_old      jsonb;
  v_row      jsonb;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('tables.manage') then
    raise exception 'missing permission: tables.manage' using errcode = '42501';
  end if;

  if v_name = '' then
    return jsonb_build_object('ok', false, 'reason', 'invalid_name');
  end if;
  if char_length(v_name) > 20 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_name');
  end if;
  if v_area not in ('hall', 'terrace', 'private_room', 'other') then
    return jsonb_build_object('ok', false, 'reason', 'invalid_area');
  end if;
  if v_capacity < 1 or v_capacity > 40 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_capacity');
  end if;
  if char_length(v_note) > 240 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_note');
  end if;

  if v_id is null then
    if v_branch is null then
      return jsonb_build_object('ok', false, 'reason', 'invalid_branch');
    end if;
    if not exists (
      select 1 from core.branches b
       where b.id = v_branch
         and b.is_active
         and identity.can_manage_branch(b.id)
    ) then
      return jsonb_build_object('ok', false, 'reason', 'invalid_branch');
    end if;
    if v_sort = 0 then
      select coalesce(max(t.sort_order), 0) + 1
        into v_sort
        from floor.tables t
       where t.branch_id = v_branch;
    end if;

    begin
      insert into floor.tables (
        branch_id, name, area, capacity, is_active, sort_order, note
      ) values (
        v_branch, v_name, v_area, v_capacity, v_active, v_sort, v_note
      )
      returning to_jsonb(floor.tables.*) into v_row;

      v_id := (v_row->>'id')::uuid;
    exception when unique_violation then
      return jsonb_build_object('ok', false, 'reason', 'duplicate_name');
    end;

    perform identity.audit(
      'floor.table.create',
      'floor_table',
      v_id,
      null,
      v_row,
      v_branch
    );
  else
    select * into v_existing
      from floor.tables t
     where t.id = v_id
     for update;

    if not found then
      return jsonb_build_object('ok', false, 'reason', 'not_found');
    end if;
    if not identity.can_manage_branch(v_existing.branch_id) then
      raise exception 'branch out of scope' using errcode = '42501';
    end if;
    if v_branch is not null and v_branch <> v_existing.branch_id then
      return jsonb_build_object('ok', false, 'reason', 'invalid_branch');
    end if;

    v_old := to_jsonb(v_existing);
    begin
      update floor.tables
         set name = v_name,
             area = v_area,
             capacity = v_capacity,
             is_active = v_active,
             sort_order = v_sort,
             note = v_note
       where id = v_id
      returning to_jsonb(floor.tables.*) into v_row;
    exception when unique_violation then
      return jsonb_build_object('ok', false, 'reason', 'duplicate_name');
    end;

    perform identity.audit(
      'floor.table.update',
      'floor_table',
      v_id,
      v_old,
      v_row,
      v_existing.branch_id
    );
  end if;

  return jsonb_build_object('ok', true, 'table_id', v_id, 'reason', '');
end;
$fn$;

comment on function public.admin_save_dining_table(jsonb) is
  'Create or update a table/room after validating its branch, label, area and '
  'capacity. Duplicate labels are reported, not raised.';

revoke all on function public.admin_save_dining_table(jsonb) from public, anon;
grant execute on function public.admin_save_dining_table(jsonb) to authenticated;

create or replace function public.admin_set_dining_table_active(
  p_table_id uuid,
  p_active   boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_table floor.tables%rowtype;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('tables.manage') then
    raise exception 'missing permission: tables.manage' using errcode = '42501';
  end if;

  select * into v_table
    from floor.tables t
   where t.id = p_table_id
   for update;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;
  if not identity.can_manage_branch(v_table.branch_id) then
    raise exception 'branch out of scope' using errcode = '42501';
  end if;

  if v_table.is_active = p_active then
    return jsonb_build_object('ok', true, 'reason', '');
  end if;

  if not p_active and (
    exists (
      select 1 from orders.orders o
       where o.floor_table_id = p_table_id
         and o.status not in ('completed', 'cancelled')
    )
    or exists (
      select 1 from floor.reservations r
       where r.table_id = p_table_id
         and r.status in ('confirmed', 'seated')
    )
  ) then
    return jsonb_build_object('ok', false, 'reason', 'in_use');
  end if;

  update floor.tables
     set is_active = p_active
   where id = p_table_id;

  perform identity.audit(
    'floor.table.active',
    'floor_table',
    p_table_id,
    jsonb_build_object('is_active', v_table.is_active),
    jsonb_build_object('is_active', p_active),
    v_table.branch_id
  );

  return jsonb_build_object('ok', true, 'reason', '');
end;
$fn$;

comment on function public.admin_set_dining_table_active(uuid, boolean) is
  'Activate or deactivate a table. An occupied or reserved table cannot be '
  'deactivated until it is free.';

revoke all on function public.admin_set_dining_table_active(uuid, boolean)
  from public, anon;
grant execute on function public.admin_set_dining_table_active(uuid, boolean)
  to authenticated;

create or replace function public.admin_delete_dining_table(p_table_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_table floor.tables%rowtype;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('tables.manage') then
    raise exception 'missing permission: tables.manage' using errcode = '42501';
  end if;

  select * into v_table
    from floor.tables t
   where t.id = p_table_id
   for update;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;
  if not identity.can_manage_branch(v_table.branch_id) then
    raise exception 'branch out of scope' using errcode = '42501';
  end if;

  if exists (
    select 1 from orders.orders o
     where o.floor_table_id = p_table_id
       and o.status not in ('completed', 'cancelled')
  ) or exists (
    select 1 from floor.reservations r
     where r.table_id = p_table_id
       and r.status in ('confirmed', 'seated')
  ) then
    return jsonb_build_object('ok', false, 'reason', 'in_use');
  end if;

  if exists (
    select 1 from orders.orders o where o.floor_table_id = p_table_id
  ) or exists (
    select 1 from floor.reservations r where r.table_id = p_table_id
  ) then
    -- History keeps referencing the table, so the safe action is deactivation.
    return jsonb_build_object('ok', false, 'reason', 'has_history');
  end if;

  perform identity.audit(
    'floor.table.delete',
    'floor_table',
    p_table_id,
    to_jsonb(v_table),
    null,
    v_table.branch_id
  );

  delete from floor.tables where id = p_table_id;
  return jsonb_build_object('ok', true, 'reason', '');
end;
$fn$;

comment on function public.admin_delete_dining_table(uuid) is
  'Delete an unused table. Tables with orders or reservations must be '
  'deactivated instead so their history stays intact.';

revoke all on function public.admin_delete_dining_table(uuid) from public, anon;
grant execute on function public.admin_delete_dining_table(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 7. Reservation CRUD
-- ---------------------------------------------------------------------------
create or replace function public.admin_save_dining_reservation(
  p_reservation jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_id         uuid := nullif(btrim(coalesce(p_reservation->>'id', '')), '')::uuid;
  v_table_id   uuid := nullif(btrim(coalesce(p_reservation->>'table_id', '')), '')::uuid;
  v_name       text := btrim(coalesce(p_reservation->>'customer_name', ''));
  v_phone      text := btrim(coalesce(p_reservation->>'customer_phone', ''));
  v_party      integer := coalesce((p_reservation->>'party_size')::integer, 0);
  v_for        timestamptz := (p_reservation->>'reserved_for')::timestamptz;
  v_duration   integer := coalesce((p_reservation->>'duration_minutes')::integer, 90);
  v_note       text := btrim(coalesce(p_reservation->>'note', ''));
  v_table      floor.tables%rowtype;
  v_existing   floor.reservations%rowtype;
  v_created    boolean := false;
  v_old        jsonb;
  v_row        jsonb;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('tables.manage') then
    raise exception 'missing permission: tables.manage' using errcode = '42501';
  end if;

  if v_name = '' or char_length(v_name) > 120 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_name');
  end if;
  if char_length(v_phone) > 40 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_phone');
  end if;
  if v_party < 1 or v_party > 40 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_party');
  end if;
  if v_duration < 30 or v_duration > 480 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_duration');
  end if;
  if char_length(v_note) > 500 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_note');
  end if;
  if v_for is null then
    return jsonb_build_object('ok', false, 'reason', 'invalid_time');
  end if;

  if v_id is not null then
    select * into v_existing
      from floor.reservations r
     where r.id = v_id
     for update;
    if not found then
      return jsonb_build_object('ok', false, 'reason', 'not_found');
    end if;
    if not identity.can_manage_branch(v_existing.branch_id) then
      raise exception 'branch out of scope' using errcode = '42501';
    end if;
    if v_existing.status not in ('confirmed', 'seated') then
      return jsonb_build_object('ok', false, 'reason', 'closed_reservation');
    end if;
    v_table_id := coalesce(v_table_id, v_existing.table_id);
    v_old := to_jsonb(v_existing);
  end if;

  if v_table_id is null then
    return jsonb_build_object('ok', false, 'reason', 'invalid_table');
  end if;

  select * into v_table
    from floor.tables t
   where t.id = v_table_id
   for update;
  if not found or not v_table.is_active then
    return jsonb_build_object('ok', false, 'reason', 'invalid_table');
  end if;
  if not identity.can_manage_branch(v_table.branch_id) then
    raise exception 'branch out of scope' using errcode = '42501';
  end if;
  -- A seated guest is already at a table; moving the booking would detach the
  -- open order from the floor plan. The counter must complete or cancel first.
  if v_id is not null and v_existing.status = 'seated'
     and v_table_id <> v_existing.table_id then
    return jsonb_build_object('ok', false, 'reason', 'seated_table_locked');
  end if;
  if v_party > v_table.capacity then
    return jsonb_build_object('ok', false, 'reason', 'party_too_large');
  end if;
  if v_id is null and v_for < now() - interval '5 minutes' then
    return jsonb_build_object('ok', false, 'reason', 'invalid_time');
  end if;

  if exists (
    select 1
      from floor.reservations r
     where r.table_id = v_table_id
       and r.id is distinct from v_id
       and r.status in ('confirmed', 'seated')
       and r.reserved_for < v_for + make_interval(mins => v_duration)
       and v_for < r.reserved_for + make_interval(mins => r.duration_minutes)
  ) then
    return jsonb_build_object('ok', false, 'reason', 'overlap');
  end if;

  begin
    if v_id is null then
      insert into floor.reservations (
        branch_id, table_id, customer_name, customer_phone, party_size,
        reserved_for, duration_minutes, note, created_by
      ) values (
        v_table.branch_id, v_table_id, v_name, v_phone, v_party,
        v_for, v_duration, v_note, auth.uid()
      )
      returning to_jsonb(floor.reservations.*) into v_row;

      v_id := (v_row->>'id')::uuid;
      v_created := true;
    else
      update floor.reservations
         set table_id = v_table_id,
             branch_id = v_table.branch_id,
             customer_name = v_name,
             customer_phone = v_phone,
             party_size = v_party,
             reserved_for = v_for,
             duration_minutes = v_duration,
             note = v_note
       where id = v_id
      returning to_jsonb(floor.reservations.*) into v_row;
    end if;
  exception when unique_violation then
    return jsonb_build_object('ok', false, 'reason', 'overlap');
  end;

  perform identity.audit(
    case when v_created
      then 'floor.reservation.create'
      else 'floor.reservation.update'
    end,
    'floor_reservation',
    v_id,
    v_old,
    v_row,
    v_table.branch_id
  );

  return jsonb_build_object(
    'ok', true,
    'reservation_id', v_id,
    'reason', ''
  );
end;
$fn$;

comment on function public.admin_save_dining_reservation(jsonb) is
  'Create or update a booking after validating the table capacity and the '
  'non-overlapping reservation window.';

revoke all on function public.admin_save_dining_reservation(jsonb)
  from public, anon;
grant execute on function public.admin_save_dining_reservation(jsonb)
  to authenticated;

create or replace function public.admin_set_dining_reservation_status(
  p_reservation_id uuid,
  p_status         text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_reservation floor.reservations%rowtype;
  v_cancelled   boolean := p_status = 'cancelled';
  v_completed   boolean := p_status = 'completed';
  v_seated      boolean := p_status = 'seated';
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('tables.manage') then
    raise exception 'missing permission: tables.manage' using errcode = '42501';
  end if;

  if p_status not in ('seated', 'completed', 'cancelled', 'no_show') then
    return jsonb_build_object('ok', false, 'reason', 'invalid_status');
  end if;

  select * into v_reservation
    from floor.reservations r
   where r.id = p_reservation_id
   for update;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;
  if not identity.can_manage_branch(v_reservation.branch_id) then
    raise exception 'branch out of scope' using errcode = '42501';
  end if;

  if v_reservation.status = p_status then
    return jsonb_build_object('ok', true, 'status', p_status, 'reason', '');
  end if;

  if not (
    (v_reservation.status = 'confirmed'
      and p_status in ('seated', 'cancelled', 'no_show'))
    or (v_reservation.status = 'seated'
      and p_status in ('completed', 'cancelled'))
  ) then
    return jsonb_build_object('ok', false, 'reason', 'invalid_status');
  end if;

  if v_seated then
    if not exists (
      select 1 from floor.tables t
       where t.id = v_reservation.table_id
         and t.is_active
    ) then
      return jsonb_build_object('ok', false, 'reason', 'invalid_table');
    end if;
    if exists (
      select 1 from orders.orders o
       where o.floor_table_id = v_reservation.table_id
         and o.status not in ('completed', 'cancelled')
    ) then
      return jsonb_build_object('ok', false, 'reason', 'table_busy');
    end if;
  end if;

  update floor.reservations
     set status = p_status,
         seated_at = case
           when v_seated then coalesce(seated_at, now())
           else seated_at
         end,
         completed_at = case
           when v_completed then now()
           else completed_at
         end,
         cancelled_at = case
           when v_cancelled or p_status = 'no_show' then now()
           else cancelled_at
         end
   where id = p_reservation_id;

  perform identity.audit(
    'floor.reservation.status',
    'floor_reservation',
    p_reservation_id,
    jsonb_build_object('status', v_reservation.status),
    jsonb_build_object('status', p_status),
    v_reservation.branch_id
  );

  return jsonb_build_object('ok', true, 'status', p_status, 'reason', '');
end;
$fn$;

comment on function public.admin_set_dining_reservation_status(uuid, text) is
  'Move a reservation through confirmed -> seated -> completed, or cancel and '
  'mark a no-show. Terminal statuses cannot be reopened.';

revoke all on function public.admin_set_dining_reservation_status(uuid, text)
  from public, anon;
grant execute on function public.admin_set_dining_reservation_status(uuid, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 8. POS: live tables, seating a booked guest, table-aware checkout
-- ---------------------------------------------------------------------------
create or replace function public.admin_pos_tables(p_branch_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('pos.manage') then
    raise exception 'missing permission: pos.manage' using errcode = '42501';
  end if;

  if not exists (
    select 1 from core.branches b
     where b.id = p_branch_id
       and b.is_active
       and identity.can_manage_branch(b.id)
  ) then
    raise exception 'branch not found or inactive' using errcode = 'P0002';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'id', t.id,
             'name', t.name,
             'area', t.area,
             'capacity', t.capacity,
             'note', t.note,
             'status', case
               when ao.id is not null then 'occupied'
               when cr.status = 'seated' then 'seated'
               when cr.id is not null then 'reserved'
               else 'available'
             end,
             'active_order', case
               when ao.id is null then null
               else jsonb_build_object(
                 'order_number', ao.order_number,
                 'status', ao.status,
                 'grand_total', ao.grand_total,
                 'placed_at', ao.placed_at
               )
             end,
             'reservation', case
               when cr.id is null then null
               else jsonb_build_object(
                 'id', cr.id,
                 'customer_name', cr.customer_name,
                 'customer_phone', cr.customer_phone,
                 'party_size', cr.party_size,
                 'reserved_for', cr.reserved_for,
                 'duration_minutes', cr.duration_minutes,
                 'status', cr.status,
                 'note', cr.note
               )
             end,
             'next_reservation', case
               when nr.id is null then null
               else jsonb_build_object(
                 'id', nr.id,
                 'customer_name', nr.customer_name,
                 'party_size', nr.party_size,
                 'reserved_for', nr.reserved_for,
                 'duration_minutes', nr.duration_minutes,
                 'status', nr.status
               )
             end
           ) order by
             case t.area
               when 'hall' then 1
               when 'terrace' then 2
               when 'private_room' then 3
               else 4
             end,
             t.sort_order,
             t.name)
      from floor.tables t
      left join lateral (
        select o.id, o.order_number, o.status, o.grand_total, o.placed_at
          from orders.orders o
         where o.floor_table_id = t.id
           and o.status not in ('completed', 'cancelled')
         order by o.placed_at desc
         limit 1
      ) ao on true
      left join lateral (
        select r.id, r.customer_name, r.customer_phone, r.party_size,
               r.reserved_for, r.duration_minutes, r.status, r.note
          from floor.reservations r
         where r.table_id = t.id
           and (
             r.status = 'seated'
             or (
               r.status = 'confirmed'
               and r.reserved_for <= now() + interval '30 minutes'
               and r.reserved_for + make_interval(mins => r.duration_minutes) > now()
             )
           )
         order by r.reserved_for
         limit 1
      ) cr on true
      left join lateral (
        select r.id, r.customer_name, r.party_size, r.reserved_for,
               r.duration_minutes, r.status
          from floor.reservations r
         where r.table_id = t.id
           and r.status = 'confirmed'
           and r.reserved_for > now()
           and r.id is distinct from cr.id
         order by r.reserved_for
         limit 1
      ) nr on true
     where t.branch_id = p_branch_id
       and t.is_active
  ), '[]'::jsonb);
end;
$fn$;

comment on function public.admin_pos_tables(uuid) is
  'Active tables of a branch with their live status, current order and guest '
  'reservation for the counter.';

revoke all on function public.admin_pos_tables(uuid) from public, anon;
grant execute on function public.admin_pos_tables(uuid) to authenticated;

create or replace function public.admin_pos_seat_reservation(
  p_reservation_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_reservation floor.reservations%rowtype;
  v_table       floor.tables%rowtype;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('pos.manage') then
    raise exception 'missing permission: pos.manage' using errcode = '42501';
  end if;

  select * into v_reservation
    from floor.reservations r
   where r.id = p_reservation_id
   for update;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;
  if not identity.can_manage_branch(v_reservation.branch_id) then
    raise exception 'branch out of scope' using errcode = '42501';
  end if;
  if v_reservation.status <> 'confirmed' then
    return jsonb_build_object('ok', false, 'reason', 'invalid_status');
  end if;
  if v_reservation.reserved_for > now() + interval '2 hours' then
    return jsonb_build_object('ok', false, 'reason', 'too_early');
  end if;

  select * into v_table
    from floor.tables t
   where t.id = v_reservation.table_id;
  if not found or not v_table.is_active then
    return jsonb_build_object('ok', false, 'reason', 'invalid_table');
  end if;

  if exists (
    select 1 from orders.orders o
     where o.floor_table_id = v_reservation.table_id
       and o.status not in ('completed', 'cancelled')
  ) then
    return jsonb_build_object('ok', false, 'reason', 'table_busy');
  end if;

  update floor.reservations
     set status = 'seated',
         seated_at = coalesce(seated_at, now())
   where id = p_reservation_id;

  perform identity.audit(
    'pos.reservation.seat',
    'floor_reservation',
    p_reservation_id,
    jsonb_build_object('status', v_reservation.status),
    jsonb_build_object('status', 'seated'),
    v_reservation.branch_id
  );

  return jsonb_build_object(
    'ok', true,
    'table_id', v_reservation.table_id,
    'reason', ''
  );
end;
$fn$;

comment on function public.admin_pos_seat_reservation(uuid) is
  'Mark a booked guest as seated from the counter so their table can be '
  'opened for the order.';

revoke all on function public.admin_pos_seat_reservation(uuid)
  from public, anon;
grant execute on function public.admin_pos_seat_reservation(uuid)
  to authenticated;

-- The table-aware checkout wraps the proven 8-argument checkout from 176:
-- it validates and locks the selected table, links a seated reservation, then
-- delegates pricing, stock, payment and kitchen dispatch. Idempotent retries
-- return the same order before touching the table again.
create or replace function public.admin_pos_place_table_order(
  p_branch_id         uuid,
  p_lines             jsonb,
  p_fulfillment_type  text,
  p_payment_method_id uuid,
  p_idempotency_key   text,
  p_table_id          uuid,
  p_note              text default null,
  p_customer_id       uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_existing           orders.orders%rowtype;
  v_table              floor.tables%rowtype;
  v_reservation_id     uuid;
  v_active_order       text;
  v_result             jsonb;
  v_order_id           uuid;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('pos.manage') then
    raise exception 'missing permission: pos.manage' using errcode = '42501';
  end if;

  if p_idempotency_key is null or btrim(p_idempotency_key) = '' then
    raise exception 'idempotency key required' using errcode = '22023';
  end if;

  -- Retries must return the existing order without re-checking occupancy.
  select * into v_existing
    from orders.orders o
   where o.idempotency_key = p_idempotency_key;
  if found then
    if v_existing.order_source <> 'pos' then
      raise exception 'idempotency key already used by another order'
        using errcode = '23505';
    end if;
    return public.admin_pos_place_order(
      p_branch_id,
      p_lines,
      p_fulfillment_type,
      p_payment_method_id,
      p_idempotency_key,
      v_existing.table_number,
      p_note,
      p_customer_id
    );
  end if;

  if p_fulfillment_type is distinct from 'dine_in' then
    raise exception 'pos orders are dine-in only' using errcode = '22023';
  end if;
  if p_table_id is null then
    raise exception 'table is required for dine-in' using errcode = '23514';
  end if;

  select * into v_table
    from floor.tables t
   where t.id = p_table_id
     and t.branch_id = p_branch_id
     and t.is_active;
  if not found then
    raise exception 'table is not available' using errcode = '23514';
  end if;
  if not identity.can_manage_branch(p_branch_id) then
    raise exception 'branch out of scope' using errcode = '42501';
  end if;

  perform pg_advisory_xact_lock(hashtext('floor.table:' || p_table_id::text));

  -- The same key may have committed while this call waited for the lock.
  select * into v_existing
    from orders.orders o
   where o.idempotency_key = p_idempotency_key;
  if found then
    return public.admin_pos_place_order(
      p_branch_id,
      p_lines,
      p_fulfillment_type,
      p_payment_method_id,
      p_idempotency_key,
      v_existing.table_number,
      p_note,
      p_customer_id
    );
  end if;

  select o.order_number
    into v_active_order
    from orders.orders o
   where o.floor_table_id = p_table_id
     and o.status not in ('completed', 'cancelled')
   order by o.placed_at desc
   limit 1;
  if found then
    raise exception 'table is occupied' using errcode = '23514';
  end if;

  select r.id
    into v_reservation_id
    from floor.reservations r
   where r.table_id = p_table_id
     and r.status = 'seated'
   order by r.reserved_for
   limit 1;

  if v_reservation_id is null and exists (
    select 1
      from floor.reservations r
     where r.table_id = p_table_id
       and r.status = 'confirmed'
       and r.reserved_for <= now() + interval '30 minutes'
       and r.reserved_for + make_interval(mins => r.duration_minutes) > now()
  ) then
    raise exception 'table is reserved' using errcode = '23514';
  end if;

  v_result := public.admin_pos_place_order(
    p_branch_id,
    p_lines,
    'dine_in',
    p_payment_method_id,
    p_idempotency_key,
    v_table.name,
    p_note,
    p_customer_id
  );
  v_order_id := (v_result->>'order_id')::uuid;

  update orders.orders
     set floor_table_id = p_table_id,
         dining_reservation_id = v_reservation_id
   where id = v_order_id;

  if v_reservation_id is not null then
    update floor.reservations
       set order_id = v_order_id
     where id = v_reservation_id
       and (order_id is null or order_id = v_order_id);
  end if;

  return v_result || jsonb_build_object(
    'table_id', p_table_id,
    'table_name', v_table.name,
    'reservation_id', v_reservation_id
  );
end;
$fn$;

comment on function public.admin_pos_place_table_order(
  uuid, jsonb, text, uuid, text, uuid, text, uuid
) is
  'Atomic POS checkout for a real dining table: locks the table, checks '
  'occupancy and bookings, links a seated reservation, then delegates to the '
  'priced, stock-aware, kitchen-dispatching checkout.';

revoke all on function public.admin_pos_place_table_order(
  uuid, jsonb, text, uuid, text, uuid, text, uuid
) from public, anon;
grant execute on function public.admin_pos_place_table_order(
  uuid, jsonb, text, uuid, text, uuid, text, uuid
) to authenticated;

-- The label-only checkout cannot enforce the floor plan, so it is no longer
-- callable by API roles. The table-aware wrapper above calls it internally as
-- the function owner.
revoke execute on function public.admin_pos_place_order(
  uuid, jsonb, text, uuid, text, text, text, uuid
) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 9. Documentation
-- ---------------------------------------------------------------------------
comment on schema floor is
  'Dining tables, private rooms and guest reservations. Accessed through the '
  'permission-checked public.admin_* RPCs.';

notify pgrst, 'reload schema';
