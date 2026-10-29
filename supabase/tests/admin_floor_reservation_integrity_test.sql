-- admin_floor_reservation_integrity_test.sql
-- Behaviour test for migration 207: a hall booking could not be written at all,
-- a booked table read as free, and the hall accepted a seat the counter refuses.
--
-- STATUS: EXECUTED ON 2026-10-28 against webzzasosevzymftgszn, ALL ELEVEN CASES
-- PASSED, EVERY FIXTURE ROLLED BACK. Two earlier runs failed and both failures
-- were the test's own: case 1 read the live booking after later calls had
-- completed it (the parked-snapshot rule), and two assertions assigned a `->>`
-- text to a jsonb variable (22P02). Neither was a defect in 207.
--
-- Plain SQL for the Supabase SQL Editor, `supabase db query --linked -f`, or
-- psql: one transaction, every fixture rolled back at the end, and every call
-- made as a real role with real JWT claims so the guard arms run rather than
-- being asserted about.
--
-- WHY THIS NEEDS A TEST AT ALL. Both defects were invisible to a screenshot: the
-- booking died inside the INSERT as 23503 and Dart showed a generic failure, and
-- the status leak only mattered because `DiningTableStatus.fromValue`
-- (lib/core/models/dining_enums.dart:34-42) has no 'confirmed' case and falls
-- through to `available`. So the test has to prove three things at once: the
-- booking is really written by an account that has no customer profile, the
-- overview speaks the table vocabulary in every bucket, and the seat window is
-- now enforced in the database. It also has to prove that the validations 207
-- does not touch — capacity, past time, overlap, the terminal statuses, the
-- permission gates — still refuse, so the fix cannot have quietly widened
-- anything.
--
-- WHAT THE FIXTURES SET UP
--   BR    one branch under the seeded brand, so the metrics count only fixtures.
--   T1    active, capacity 4 — the in-window booking.
--   T2    active, capacity 6 — the booking five hours out.
--   T3    active, capacity 2 — the refusals.
--   T4    INACTIVE — must stay out of the `tables` metric.
--   MGR   active staff whose role row is manager (branch null = all) → holds
--         tables.read and tables.manage.
--   KCH   active staff whose role is kitchen → holds no tables permission.
--   CUS   a signed-in customer: an auth.users row only.
--   The premise case 1 depends on is not assumed: 003's signup trigger writes an
--   identity.profiles row for every auth user and 188's staff trigger removes it
--   again, so the fixture parks whether MGR still has a profile before any call
--   runs. A database where staff accounts keep profiles would answer 'true' and
--   case 1 would be reporting a different situation than the live one.
--
-- PREREQUISITES: 003/005 (profiles, branches), 007/137 (RBAC and its reference
-- data), 116 (audit log), 123 (can_manage_branch), 177 (floor schema, tables and
-- reservation RPCs), 188 (the staff/customer split), 207.

begin;

-- ---------------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from core.brands) then
    raise exception 'FAIL: the chain seeded no brand, so the branch fixture has no parent';
  end if;
end $$;

insert into core.branches (id, brand_id, code, name_ar, name_en, address, is_active)
select 'afd00000-0000-4000-8000-000000000001', b.id,
       'AF-FLOOR-TEST', 'فرع اختبار الصالة', 'Floor Test Branch', 'Test address', true
  from core.brands b order by b.id limit 1;

insert into floor.tables (id, branch_id, name, area, capacity, is_active, sort_order, note)
values
  ('afd00000-0000-4000-8000-000000000011', 'afd00000-0000-4000-8000-000000000001', 'AF-1', 'hall', 4, true,  1, ''),
  ('afd00000-0000-4000-8000-000000000012', 'afd00000-0000-4000-8000-000000000001', 'AF-2', 'hall', 6, true,  2, ''),
  ('afd00000-0000-4000-8000-000000000013', 'afd00000-0000-4000-8000-000000000001', 'AF-3', 'hall', 2, true,  3, ''),
  ('afd00000-0000-4000-8000-000000000014', 'afd00000-0000-4000-8000-000000000001', 'AF-4', 'hall', 2, false, 4, '');

insert into auth.users (id, email)
values
  ('afd00000-0000-4000-8000-000000000021', 'afl-manager@test.local'),
  ('afd00000-0000-4000-8000-000000000022', 'afl-kitchen@test.local'),
  ('afd00000-0000-4000-8000-000000000023', 'afl-customer@test.local');

insert into identity.staff_members (id, user_id, status, full_name, email)
values
  ('afd00000-0000-4000-8000-000000000031', 'afd00000-0000-4000-8000-000000000021', 'active', 'AF Floor Manager', 'afl-manager@test.local'),
  ('afd00000-0000-4000-8000-000000000032', 'afd00000-0000-4000-8000-000000000022', 'active', 'AF Kitchen Staff', 'afl-kitchen@test.local');

insert into identity.staff_roles (staff_id, role_id, branch_id)
select 'afd00000-0000-4000-8000-000000000031', r.id, null
  from identity.roles r where r.code = 'manager';

insert into identity.staff_roles (staff_id, role_id, branch_id)
select 'afd00000-0000-4000-8000-000000000032', r.id, null
  from identity.roles r where r.code = 'kitchen';

-- The premise of case 1, parked before any call: does the staff account still
-- hold the customer row the signup trigger wrote?
select set_config(
  'test.afl_mgr_has_profile',
  (select exists (
     select 1 from identity.profiles
      where id = 'afd00000-0000-4000-8000-000000000021'
   )::text),
  true
);

-- ---------------------------------------------------------------------------
-- The calls, all made as the roles the app really uses. Only the last
-- row-returning statement of the run comes back through the CLI, so every answer
-- is parked in a transaction-local setting and read in the cases below. The
-- snapshots park the whole overview payload: the calls all finish before the
-- first assertion runs, so a case that read the live floor afterwards would see
-- the last fixture mutation rather than its own moment. The numbers on the calls
-- are their order in the run, not the assertion cases that read them.
-- ---------------------------------------------------------------------------
set local role authenticated;

select set_config('request.jwt.claims',
  '{"sub":"afd00000-0000-4000-8000-000000000021","role":"authenticated","aud":"authenticated"}', true);

-- 1: the manager books a table whose window is open now. This is the call that
--    died on foreign key reservations_created_by_fkey before 207.
do $$
declare v jsonb;
begin
  select public.admin_save_dining_reservation(jsonb_build_object(
    'table_id', 'afd00000-0000-4000-8000-000000000011',
    'customer_name', 'ضيف داخل النافذة',
    'customer_phone', '01000000001',
    'party_size', 2,
    'reserved_for', (now() + interval '10 minutes')::text,
    'duration_minutes', 90,
    'note', '')) into v;
  perform set_config('test.afl_create_t1', coalesce(v::text, 'NULL'), true);
  perform set_config('test.afl_r1', coalesce(v->>'reservation_id', ''), true);
exception when others then
  perform set_config('test.afl_create_t1', 'RAISED:' || sqlstate || ':' || sqlerrm, true);
  perform set_config('test.afl_r1', '', true);
end $$;

-- 2: the floor as the hall page reads it, with one confirmed booking in its window.
do $$
declare v jsonb;
begin
  select public.admin_dining_overview('afd00000-0000-4000-8000-000000000001'::uuid) into v;
  perform set_config('test.afl_snap1', coalesce(v::text, 'NULL'), true);
exception when others then
  perform set_config('test.afl_snap1', 'RAISED:' || sqlstate || ':' || sqlerrm, true);
end $$;

-- 3: a second guest books five hours out, which no other table can see as live.
do $$
declare v jsonb;
begin
  select public.admin_save_dining_reservation(jsonb_build_object(
    'table_id', 'afd00000-0000-4000-8000-000000000012',
    'customer_name', 'ضيف بعيد',
    'customer_phone', '01000000002',
    'party_size', 2,
    'reserved_for', (now() + interval '5 hours')::text,
    'duration_minutes', 60,
    'note', '')) into v;
  perform set_config('test.afl_create_t2', coalesce(v::text, 'NULL'), true);
  perform set_config('test.afl_r2', coalesce(v->>'reservation_id', ''), true);
exception when others then
  perform set_config('test.afl_create_t2', 'RAISED:' || sqlstate || ':' || sqlerrm, true);
  perform set_config('test.afl_r2', '', true);
end $$;

-- 4: seating that far-ahead booking. The counter refused this for years
--    (177:1234); the hall function accepted it until 207.
do $$
declare v jsonb;
begin
  select public.admin_set_dining_reservation_status(
    nullif(current_setting('test.afl_r2', true), '')::uuid, 'seated') into v;
  perform set_config('test.afl_seat_far', coalesce(v::text, 'NULL'), true);
exception when others then
  perform set_config('test.afl_seat_far', 'RAISED:' || sqlstate || ':' || sqlerrm, true);
end $$;

-- 5: seating inside the window stays allowed.
do $$
declare v jsonb;
begin
  select public.admin_set_dining_reservation_status(
    nullif(current_setting('test.afl_r1', true), '')::uuid, 'seated') into v;
  perform set_config('test.afl_seat_ok', coalesce(v::text, 'NULL'), true);
exception when others then
  perform set_config('test.afl_seat_ok', 'RAISED:' || sqlstate || ':' || sqlerrm, true);
end $$;

do $$
declare v jsonb;
begin
  select public.admin_dining_overview('afd00000-0000-4000-8000-000000000001'::uuid) into v;
  perform set_config('test.afl_snap2', coalesce(v::text, 'NULL'), true);
exception when others then
  perform set_config('test.afl_snap2', 'RAISED:' || sqlstate || ':' || sqlerrm, true);
end $$;

-- 6: the guest leaves, and the table must come back to the floor as available.
do $$
declare v jsonb;
begin
  select public.admin_set_dining_reservation_status(
    nullif(current_setting('test.afl_r1', true), '')::uuid, 'completed') into v;
  perform set_config('test.afl_complete', coalesce(v::text, 'NULL'), true);
exception when others then
  perform set_config('test.afl_complete', 'RAISED:' || sqlstate || ':' || sqlerrm, true);
end $$;

do $$
declare v jsonb;
begin
  select public.admin_dining_overview('afd00000-0000-4000-8000-000000000001'::uuid) into v;
  perform set_config('test.afl_snap3', coalesce(v::text, 'NULL'), true);
exception when others then
  perform set_config('test.afl_snap3', 'RAISED:' || sqlstate || ':' || sqlerrm, true);
end $$;

-- 7: a booking that has ended cannot be reopened by seating the guest again.
do $$
declare v jsonb;
begin
  select public.admin_set_dining_reservation_status(
    nullif(current_setting('test.afl_r1', true), '')::uuid, 'seated') into v;
  perform set_config('test.afl_reopen', coalesce(v::text, 'NULL'), true);
exception when others then
  perform set_config('test.afl_reopen', 'RAISED:' || sqlstate || ':' || sqlerrm, true);
end $$;

-- 8/9/10: the three validations 207 leaves alone, each refused on its own merit.
do $$
declare v jsonb;
begin
  select public.admin_save_dining_reservation(jsonb_build_object(
    'table_id', 'afd00000-0000-4000-8000-000000000013',
    'customer_name', 'حفل كبير',
    'party_size', 9,
    'reserved_for', (now() + interval '3 hours')::text,
    'duration_minutes', 60)) into v;
  perform set_config('test.afl_party', coalesce(v::text, 'NULL'), true);
exception when others then
  perform set_config('test.afl_party', 'RAISED:' || sqlstate || ':' || sqlerrm, true);
end $$;

do $$
declare v jsonb;
begin
  select public.admin_save_dining_reservation(jsonb_build_object(
    'table_id', 'afd00000-0000-4000-8000-000000000013',
    'customer_name', 'موعد أمس',
    'party_size', 2,
    'reserved_for', (now() - interval '1 hour')::text,
    'duration_minutes', 60)) into v;
  perform set_config('test.afl_past', coalesce(v::text, 'NULL'), true);
exception when others then
  perform set_config('test.afl_past', 'RAISED:' || sqlstate || ':' || sqlerrm, true);
end $$;

do $$
declare v jsonb;
begin
  select public.admin_save_dining_reservation(jsonb_build_object(
    'table_id', 'afd00000-0000-4000-8000-000000000012',
    'customer_name', 'ضيف متداخل',
    'party_size', 2,
    'reserved_for', (now() + interval '5 hours 30 minutes')::text,
    'duration_minutes', 30)) into v;
  perform set_config('test.afl_overlap', coalesce(v::text, 'NULL'), true);
exception when others then
  perform set_config('test.afl_overlap', 'RAISED:' || sqlstate || ':' || sqlerrm, true);
end $$;

-- 11: staff who holds no tables permission — active, but the kitchen role.
select set_config('request.jwt.claims',
  '{"sub":"afd00000-0000-4000-8000-000000000022","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v jsonb;
begin
  select public.admin_dining_overview('afd00000-0000-4000-8000-000000000001'::uuid) into v;
  perform set_config('test.afl_kitchen_read', coalesce(v::text, 'NULL'), true);
exception when others then
  perform set_config('test.afl_kitchen_read', 'RAISED:' || sqlstate || ':' || sqlerrm, true);
end $$;

do $$
declare v jsonb;
begin
  select public.admin_save_dining_reservation(jsonb_build_object(
    'table_id', 'afd00000-0000-4000-8000-000000000013',
    'customer_name', 'ضيف المطبخ',
    'party_size', 2,
    'reserved_for', (now() + interval '3 hours')::text)) into v;
  perform set_config('test.afl_kitchen_write', coalesce(v::text, 'NULL'), true);
exception when others then
  perform set_config('test.afl_kitchen_write', 'RAISED:' || sqlstate || ':' || sqlerrm, true);
end $$;

-- 12: a signed-in customer, not staff at all.
select set_config('request.jwt.claims',
  '{"sub":"afd00000-0000-4000-8000-000000000023","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v jsonb;
begin
  select public.admin_dining_overview(null) into v;
  perform set_config('test.afl_customer_read', coalesce(v::text, 'NULL'), true);
exception when others then
  perform set_config('test.afl_customer_read', 'RAISED:' || sqlstate || ':' || sqlerrm, true);
end $$;

do $$
declare v jsonb;
begin
  select public.admin_set_dining_reservation_status(
    nullif(current_setting('test.afl_r2', true), '')::uuid, 'cancelled') into v;
  perform set_config('test.afl_customer_write', coalesce(v::text, 'NULL'), true);
exception when others then
  perform set_config('test.afl_customer_write', 'RAISED:' || sqlstate || ':' || sqlerrm, true);
end $$;

reset role;

-- 13: anon has no claims and no EXECUTE.
set local role anon;

do $$
declare v jsonb;
begin
  select public.admin_dining_overview(null) into v;
  perform set_config('test.afl_anon', coalesce(v::text, 'NULL'), true);
exception when others then
  perform set_config('test.afl_anon', 'RAISED:' || sqlstate || ':' || sqlerrm, true);
end $$;

reset role;

-- ---------------------------------------------------------------------------
-- 1. The booking is written, and it is written by an account that has no
--    customer profile — the exact shape of a staff login since 188. This is the
--    case that answered 23503 before 207.
-- ---------------------------------------------------------------------------
do $$
declare
  raw text := current_setting('test.afl_create_t1', true);
  answer jsonb;
  v_created_by uuid;
begin
  if raw is null then
    raise exception 'FAIL 1: the booking call never parked an answer';
  end if;
  if left(raw, 6) = 'RAISED' then
    raise exception 'FAIL 1: the manager''s booking raised: %', raw;
  end if;
  answer := raw::jsonb;
  if answer ->> 'ok' <> 'true' then
    raise exception 'FAIL 1: the booking answered %', answer;
  end if;

  if current_setting('test.afl_mgr_has_profile') <> 'false' then
    raise exception 'FAIL 1: the staff fixture still holds an identity.profiles row, so this run proves nothing about the 188 split';
  end if;

  -- Only the author is read from the live row: it is a column no later call
  -- touches. What the booking's own status was at creation is case 2's job,
  -- because every call finishes before this assertion runs and the floor has
  -- moved on by then — the snapshot parked after the create is the honest read.
  select created_by into v_created_by
    from floor.reservations
   where id = current_setting('test.afl_r1')::uuid;
  if v_created_by <> 'afd00000-0000-4000-8000-000000000021'::uuid then
    raise exception 'FAIL 1: the booking was authored by % instead of the manager uid', v_created_by;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 2. A confirmed booking inside its window reads as a reserved table, in the
--    vocabulary the Dart enum speaks, while the booking itself keeps reporting
--    its own status. Before 207 this row carried 'confirmed' and the hall drew
--    the table as available.
-- ---------------------------------------------------------------------------
do $$
declare
  raw text := current_setting('test.afl_snap1', true);
  snap jsonb;
  item jsonb;
  v_status text;
  m jsonb;
begin
  if raw is null then
    raise exception 'FAIL 2: the first overview never parked an answer';
  end if;
  if left(raw, 6) = 'RAISED' then
    raise exception 'FAIL 2: the overview raised: %', raw;
  end if;
  snap := raw::jsonb;

  select t into item from jsonb_array_elements(snap->'tables') t
   where t->>'id' = 'afd00000-0000-4000-8000-000000000011';
  if item is null then
    raise exception 'FAIL 2: the overview does not carry the booked table';
  end if;
  if item->>'status' <> 'reserved' then
    raise exception 'FAIL 2: a booked table in its window read as %', item->>'status';
  end if;
  if item->'reservation'->>'status' <> 'confirmed' then
    raise exception 'FAIL 2: the booking lost its own status: %', item->'reservation';
  end if;
  if item->'reservation'->>'customer_name' <> 'ضيف داخل النافذة' then
    raise exception 'FAIL 2: the in-window reservation object is not the fixture booking: %', item->'reservation';
  end if;

  select t->>'status' into v_status from jsonb_array_elements(snap->'tables') t
   where t->>'id' = 'afd00000-0000-4000-8000-000000000013';
  if v_status <> 'available' then
    raise exception 'FAIL 2: a free table read as %', v_status;
  end if;

  select t->>'status' into v_status from jsonb_array_elements(snap->'tables') t
   where t->>'id' = 'afd00000-0000-4000-8000-000000000014';
  if v_status <> 'inactive' then
    raise exception 'FAIL 2: a deactivated table read as %', v_status;
  end if;

  m := snap->'metrics';
  if (m->>'tables')::int <> 3 or (m->>'available')::int <> 2
     or (m->>'reserved')::int <> 1 or (m->>'occupied')::int <> 0 then
    raise exception 'FAIL 2: three tables, one of them booked, counted %', m;
  end if;
  if (m->>'reservations_today')::int <> 1 or (m->>'upcoming')::int <> 1 then
    raise exception 'FAIL 2: the booking did not reach the today/upcoming buckets: %', m;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 3. The two-hour window is now the hall's rule too. The refusal is an answer,
--    not an error, and the booking is left exactly as it was.
-- ---------------------------------------------------------------------------
do $$
declare
  raw text := current_setting('test.afl_seat_far', true);
  answer jsonb;
  v_status text;
  v_seated_at timestamptz;
begin
  if raw is null then
    raise exception 'FAIL 3: the early seat never parked an answer';
  end if;
  if left(raw, 6) = 'RAISED' then
    raise exception 'FAIL 3: seating five hours early raised instead of answering: %', raw;
  end if;
  answer := raw::jsonb;
  if answer ->> 'ok' <> 'false' or answer ->> 'reason' <> 'too_early' then
    raise exception 'FAIL 3: seating five hours early answered %', answer;
  end if;

  -- This live read is safe where case 1's is not: nothing after the refused seat
  -- touches this booking — the overlap attempt was refused and the customer's
  -- cancel raised — so its end state is still the state the refusal left.
  select status, seated_at into v_status, v_seated_at
    from floor.reservations
   where id = current_setting('test.afl_r2')::uuid;
  if v_status <> 'confirmed' or v_seated_at is not null then
    raise exception 'FAIL 3: the refused seat still moved the booking to % at %', v_status, v_seated_at;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 4. Seating inside the window works, the card reads 'seated', and the far
--    booking is still visible as the table's next reservation — the projection
--    207 did not touch.
-- ---------------------------------------------------------------------------
do $$
declare
  raw text := current_setting('test.afl_seat_ok', true);
  answer jsonb;
  snap jsonb;
  item jsonb;
  m jsonb;
begin
  if raw is null then
    raise exception 'FAIL 4: the seat inside the window never parked an answer';
  end if;
  if left(raw, 6) = 'RAISED' then
    raise exception 'FAIL 4: seating inside the window raised: %', raw;
  end if;
  answer := raw::jsonb;
  if answer ->> 'ok' <> 'true' or answer ->> 'status' <> 'seated' then
    raise exception 'FAIL 4: seating inside the window answered %', answer;
  end if;

  raw := current_setting('test.afl_snap2', true);
  if raw is null or left(raw, 6) = 'RAISED' then
    raise exception 'FAIL 4: the overview after seating answered %', raw;
  end if;
  snap := raw::jsonb;

  select t into item from jsonb_array_elements(snap->'tables') t
   where t->>'id' = 'afd00000-0000-4000-8000-000000000011';
  if item->>'status' <> 'seated' then
    raise exception 'FAIL 4: a seated guest read as table status %', item->>'status';
  end if;
  if item->'reservation'->>'status' <> 'seated' then
    raise exception 'FAIL 4: the table shows % while the guest is seated', item->'reservation'->>'status';
  end if;

  select t into item from jsonb_array_elements(snap->'tables') t
   where t->>'id' = 'afd00000-0000-4000-8000-000000000012';
  if item->>'status' <> 'available' then
    raise exception 'FAIL 4: a table booked five hours out read as %', item->>'status';
  end if;
  if item->'next_reservation'->>'customer_name' <> 'ضيف بعيد' then
    raise exception 'FAIL 4: the next reservation projection was changed: %', item->'next_reservation';
  end if;

  m := snap->'metrics';
  if (m->>'reserved')::int <> 1 or (m->>'available')::int <> 2 then
    raise exception 'FAIL 4: one seated guest counted as %', m;
  end if;
  if (m->>'reservations_today')::int <> 2 or (m->>'upcoming')::int <> 1 then
    raise exception 'FAIL 4: the seated guest plus a confirmed booking counted %', m;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 5. Ending the visit returns the table to the floor, and the reservation
--    buckets drop it. The booked table has to come back as available: the same
--    projection that was wrong for 'confirmed' must not be wrong for a terminal
--    status either.
-- ---------------------------------------------------------------------------
do $$
declare
  raw text := current_setting('test.afl_complete', true);
  answer jsonb;
  snap jsonb;
  v_status text;
  m jsonb;
begin
  if raw is null then
    raise exception 'FAIL 5: the completion never parked an answer';
  end if;
  if left(raw, 6) = 'RAISED' then
    raise exception 'FAIL 5: completing the booking raised: %', raw;
  end if;
  answer := raw::jsonb;
  if answer ->> 'ok' <> 'true' then
    raise exception 'FAIL 5: completing the booking answered %', answer;
  end if;

  raw := current_setting('test.afl_snap3', true);
  if raw is null or left(raw, 6) = 'RAISED' then
    raise exception 'FAIL 5: the overview after completing answered %', raw;
  end if;
  snap := raw::jsonb;

  select t->>'status' into v_status from jsonb_array_elements(snap->'tables') t
   where t->>'id' = 'afd00000-0000-4000-8000-000000000011';
  if v_status <> 'available' then
    raise exception 'FAIL 5: a table whose guest left read as %', v_status;
  end if;

  m := snap->'metrics';
  if (m->>'tables')::int <> 3 or (m->>'available')::int <> 3 or (m->>'reserved')::int <> 0 then
    raise exception 'FAIL 5: after the guest left the floor counted %', m;
  end if;
  if (m->>'reservations_today')::int <> 1 then
    raise exception 'FAIL 5: the completed booking stayed in today: %', m;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 6. The validations 207 does not touch still refuse, and none of them wrote a
--    row: the fixture branch holds exactly the two bookings this run made.
-- ---------------------------------------------------------------------------
do $$
declare
  raw text;
  v_count int;
begin
  raw := current_setting('test.afl_reopen', true);
  if raw is null or left(raw, 6) = 'RAISED' then
    raise exception 'FAIL 6: reopening a completed booking answered %', raw;
  end if;
  if raw::jsonb ->> 'reason' <> 'invalid_status' then
    raise exception 'FAIL 6: a completed booking was reopened by: %', raw;
  end if;

  foreach raw in array array['test.afl_party', 'test.afl_past', 'test.afl_overlap'] loop
    if current_setting(raw, true) is null then
      raise exception 'FAIL 6: the % call never parked an answer', raw;
    end if;
    if left(current_setting(raw, true), 6) = 'RAISED' then
      raise exception 'FAIL 6: the % validation raised: %', raw, current_setting(raw, true);
    end if;
  end loop;

  if current_setting('test.afl_party')::jsonb ->> 'reason' <> 'party_too_large' then
    raise exception 'FAIL 6: a party of 9 on a table of 2 answered %', current_setting('test.afl_party');
  end if;
  if current_setting('test.afl_past')::jsonb ->> 'reason' <> 'invalid_time' then
    raise exception 'FAIL 6: a booking in the past answered %', current_setting('test.afl_past');
  end if;
  if current_setting('test.afl_overlap')::jsonb ->> 'reason' <> 'overlap' then
    raise exception 'FAIL 6: a booking that overlaps the 5-hour one answered %', current_setting('test.afl_overlap');
  end if;

  select count(*) into v_count from floor.reservations
   where branch_id = 'afd00000-0000-4000-8000-000000000001';
  if v_count <> 2 then
    raise exception 'FAIL 6: the refusals left % reservation rows in the fixture branch, expected 2', v_count;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 7/8/9. The refusals: staff without the tables permission, a customer, anon.
-- ---------------------------------------------------------------------------
do $$
begin
  if current_setting('test.afl_kitchen_read', true) <> 'RAISED:42501:missing permission: tables.read' then
    raise exception 'FAIL 7: the kitchen staff read the floor as: %', current_setting('test.afl_kitchen_read', true);
  end if;
  if current_setting('test.afl_kitchen_write', true) <> 'RAISED:42501:missing permission: tables.manage' then
    raise exception 'FAIL 7: the kitchen staff booked a table as: %', current_setting('test.afl_kitchen_write', true);
  end if;
  if current_setting('test.afl_customer_read', true) <> 'RAISED:42501:not authenticated' then
    raise exception 'FAIL 8: a customer read the floor as: %', current_setting('test.afl_customer_read', true);
  end if;
  if current_setting('test.afl_customer_write', true) <> 'RAISED:42501:not authenticated' then
    raise exception 'FAIL 8: a customer moved a booking as: %', current_setting('test.afl_customer_write', true);
  end if;
  if left(current_setting('test.afl_anon', true), 6) <> 'RAISED' then
    raise exception 'FAIL 9: anon was allowed to read the floor: %', current_setting('test.afl_anon', true);
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 10. The audit trail: two creates, one seat, one completion — each matched by
--     its payload rather than by created_at, because every row written in one
--     transaction shares that timestamp.
-- ---------------------------------------------------------------------------
do $$
declare v_found int;
begin
  select count(*) into v_found from identity.audit_log a
   where a.action = 'floor.reservation.create'
     and a.entity_id in (current_setting('test.afl_r1')::uuid, current_setting('test.afl_r2')::uuid);
  if v_found <> 2 then
    raise exception 'FAIL 10: the two bookings produced % create audit rows, expected 2', v_found;
  end if;

  select count(*) into v_found from identity.audit_log a
   where a.action = 'floor.reservation.update';
  if v_found <> 0 then
    raise exception 'FAIL 10: % update audit rows came from a run that never edited a booking', v_found;
  end if;

  select count(*) into v_found from identity.audit_log a
   where a.action = 'floor.reservation.status'
     and a.entity_id = current_setting('test.afl_r1')::uuid
     and ((a.old_values ->> 'status' = 'confirmed' and a.new_values ->> 'status' = 'seated')
       or (a.old_values ->> 'status' = 'seated' and a.new_values ->> 'status' = 'completed'));
  if v_found <> 2 then
    raise exception 'FAIL 10: the seat and the completion left % status audit rows, expected 2', v_found;
  end if;

  select count(*) into v_found from identity.audit_log a
   where a.actor_user_id in ('afd00000-0000-4000-8000-000000000021'::uuid,
                             'afd00000-0000-4000-8000-000000000022'::uuid,
                             'afd00000-0000-4000-8000-000000000023'::uuid)
     and a.action not in ('floor.reservation.create', 'floor.reservation.status');
  if v_found <> 0 then
    raise exception 'FAIL 10: the fixture actors wrote % audit rows of another action', v_found;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 11. The database posture 207 asserts: the author column follows the same edge
--     kitchen.tickets.completed_by uses, and the floor stays closed to the API
--     roles so the definer functions remain the only path.
-- ---------------------------------------------------------------------------
do $$
declare
  v_target text;
  v_del text;
  v_rls boolean;
  v_policies int;
begin
  select confrelid::regclass::text, confdeltype into v_target, v_del
    from pg_constraint
   where conname = 'reservations_created_by_fkey';
  if v_target <> 'auth.users' then
    raise exception 'FAIL 11: created_by still references %', v_target;
  end if;
  if v_del <> 'n' then
    raise exception 'FAIL 11: the booking author edge deletes with %, expected set null', v_del;
  end if;

  select relrowsecurity into v_rls from pg_class
   where oid = 'floor.reservations'::regclass;
  if not v_rls then
    raise exception 'FAIL 11: floor.reservations runs without row level security';
  end if;
  select relrowsecurity into v_rls from pg_class
   where oid = 'floor.tables'::regclass;
  if not v_rls then
    raise exception 'FAIL 11: floor.tables runs without row level security';
  end if;

  select count(*) into v_policies from pg_policies where schemaname = 'floor';
  if v_policies <> 0 then
    raise exception 'FAIL 11: the floor now has % client policies; the RPCs were the only read path', v_policies;
  end if;

  if pg_catalog.has_table_privilege('authenticated', 'floor.reservations', 'SELECT') then
    raise exception 'FAIL 11: authenticated can select floor.reservations directly';
  end if;
end $$;

select 'all eleven cases passed' as result;

rollback;
