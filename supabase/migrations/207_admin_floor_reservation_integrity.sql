-- Migration 207: the hall could not be booked, and booked tables read as free.
--
-- THE PROBLEM
--   1. A staff account could not book the hall. 177_admin_dining_tables.sql:95
--      put `floor.reservations.created_by` under a foreign key to
--      `identity.profiles(id)`, and `admin_save_dining_reservation` stamps that
--      column with `auth.uid()` (177:929-937). Since
--      188_separate_customer_and_staff_accounts a staff login has no `profiles`
--      row at all — the staff row is its only identity record — so booking from
--      the hall page or from the counter aborted with 23503 ("key
--      (created_by)=... is not present in table "profiles""). Reproduced live on
--      2026-10-28 with the only active staff account. Disclosed in full: the
--      same database holds one older booking, id c0c3277e-a25c-4459-ad8a-3f09bbde5c53,
--      authored by that very uid at 13:12 UTC the same day, while its author had
--      no profile row. The live history does not say how that row got in (the
--      constraint's own creation is not timestamped), and the failure reproduced
--      29 minutes later, so "no booking has ever succeeded" would be an
--      overclaim. What is proven is the rule the column cannot satisfy: 188's
--      steady state leaves every staff uid absent from identity.profiles. Under
--      this migration that row becomes valid rather than repaired — its author
--      does exist in auth.users, which is the table the edge now points at.
--   2. A booked table looked free. `admin_dining_overview` returned the raw
--      reservation status as the *table* status (177:353, `when cr.id is not
--      null then cr.status`), so the value 'confirmed' reached
--      `DiningTableStatus.fromValue` (lib/core/models/dining_enums.dart:34-42),
--      which has no such case and falls through to `available`. The card then
--      offered "book this table", and the metrics bucket
--      `status in ('reserved','seated')` (177:477) counted nothing: measured
--      live tables=6 available=5 occupied=0 reserved=0 with the booked table
--      outside every bucket. `admin_pos_tables` (177:1105-1110) already maps the
--      same row to seated/reserved, so the hall function is the outlier.
--   3. Seating had two rules. The counter refuses a booking more than two hours
--      early (177:1234, 'too_early') while `admin_set_dining_reservation_status`
--      (177:989-1032) accepted any time, including a booking from last week; the
--      hall page only imitated the rule in Dart (tables_page.dart:205-208).
--
-- WHAT CHANGES
--   1. `floor.reservations.created_by` now references `auth.users(id)` with the
--      same `on delete set null` as `kitchen.tickets.completed_by`, the existing
--      precedent for a staff-written column in this schema family.
--   2. `admin_dining_overview` projects the table status in the vocabulary every
--      consumer already speaks: seated for a seated booking, reserved for a
--      confirmed one. The metrics bucket becomes meaningful by the same change.
--   3. `admin_set_dining_reservation_status` refuses to seat a guest more than
--      two hours before the booking and returns 'too_early' like the counter.
--   4. `floor.tables` and `floor.reservations` get `enable row level security`,
--      which is already true live, so a rebuilt database matches it.
--
-- WHAT DOES NOT CHANGE
--   Both functions keep their signature, `security definer` + `set search_path =
--   ''`, permission gates (`tables.read` / `tables.manage`), branch scoping,
--   audit writes and every other projection field. Their live bodies were
--   compared character by character against 177 before this file was written, so
--   nothing else is replayed. No policy, grant, trigger or column other than the
--   FK target above is touched: `floor.*` stays unreadable from the client (no
--   grants, no policies, not in the realtime publication) and no reservation row
--   is rewritten — an existing booking keeps its stored status, only its
--   presentation changes. Seating a booking whose window already passed stays
--   possible, and a second seated booking on one table stays possible; both are
--   lifecycle decisions left to the owner.
--
-- CHECKLIST
--   [x] FK delete action copied from kitchen.tickets.completed_by (confdeltype
--       'n' on both, read from pg_constraint).
--   [x] Rehearsed inside `begin; ... rollback;` on webzzasosevzymftgszn before
--       applying: booking created by a staff account with no profile, overview
--       reports 'reserved' and counts it, seating 3 hours early returns
--       'too_early', seating inside the window still succeeds.
--   [x] Behaviour test kept beside it:
--       supabase/tests/admin_floor_reservation_integrity_test.sql
--
-- STATUS: APPLIED to webzzasosevzymftgszn on 2026-10-28 and recorded in
--   supabase_migrations.schema_migrations. Its behaviour test ran against the
--   applied state the same day — eleven cases, all passed, every fixture rolled
--   back. Two runs failed first and both were the test's own bugs (an assertion
--   that read a live row after later calls had moved it, and two `->>` texts
--   assigned to jsonb variables), not defects in this file.
--
-- Read-back after applying:
--   select conname, confrelid::regclass from pg_constraint
--    where conname = 'reservations_created_by_fkey';
--   select (public.admin_dining_overview(null)->'metrics')::text;

-- ---------------------------------------------------------------------------
-- 1. A staff account has no identity.profiles row, so the booking author can
--    only be the authentication user.
-- ---------------------------------------------------------------------------
alter table floor.reservations
  drop constraint reservations_created_by_fkey;

alter table floor.reservations
  add constraint reservations_created_by_fkey
  foreign key (created_by) references auth.users(id)
  on delete set null;

-- ---------------------------------------------------------------------------
-- 2. The table status is one of available/reserved/seated/occupied/inactive.
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
             when cr.id is not null then
               case when cr.status = 'seated' then 'seated'
                    else 'reserved' end
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
-- 3. Seating follows the counter's window, so one action has one rule.
-- ---------------------------------------------------------------------------
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
    if v_reservation.reserved_for > now() + interval '2 hours' then
      return jsonb_build_object('ok', false, 'reason', 'too_early');
    end if;
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
-- 4. Live parity. `floor.*` already runs with row level security enabled and no
--    policies, which denies every client-side read and leaves the definer
--    functions as the only path. Stating it here keeps a rebuilt database
--    identical to the live one; it changes no behaviour today.
-- ---------------------------------------------------------------------------
alter table floor.tables enable row level security;
alter table floor.reservations enable row level security;
