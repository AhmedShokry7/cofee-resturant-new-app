-- pos_shift_cashier_assignment_test.sql
-- Behaviour test for 206_pos_shift_cashier_assignment.sql on top of the shift
-- model of 182_admin_pos_cashier_shifts.sql.
--
-- STATUS: EXECUTED AND PASSED on 2026-10-28 against the live project
-- webzzasosevzymftgszn, inside the rolled-back transaction below. The report
-- row came back as:
--   verdict = 'reached the end: no assertion failed', shifts_created = 4,
--   drawer_owners = 'AS Assignee, AS Floor, AS Floor, AS Owner'
--
-- Like admin_set_category_image_test.sql: every fixture lives inside one
-- transaction that is rolled back, and every call runs as the real
-- `authenticated` role with real JWT claims, so the authorization arms are
-- exercised instead of asserted about. The shift tables and identity.audit_log
-- are read only after `reset role`, because the client role holds no table
-- privileges at all — which is the point.
--
-- PREREQUISITES: 004/011/013/021/123/137 (identity, RBAC matrix, orders,
-- payments), 182 (the shift tables and RPCs), 187 (the cash-out guard), 206.

begin;

-- ---------------------------------------------------------------------------
-- Fixtures: three branches and nine staff members with different reach.
-- ---------------------------------------------------------------------------
insert into core.branches (id, brand_id, code, name_ar, name_en, address, is_active, settings)
values
  ('4d100000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000001', 'AS-B1', 'فرع الورديات 1', 'Assign Branch 1', 'addr1', true, '{}'::jsonb),
  ('4d200000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000001', 'AS-B2', 'فرع الورديات 2', 'Assign Branch 2', 'addr2', true, '{}'::jsonb),
  ('4d300000-0000-4000-8000-000000000003', '00000000-0000-4000-8000-000000000001', 'AS-B3', 'فرع الورديات 3', 'Assign Branch 3', 'addr3', true, '{}'::jsonb);

insert into auth.users (id, email)
values
  ('5e110000-0000-4000-8000-000000000001', 'as-self@test.local'),
  ('5e110000-0000-4000-8000-000000000002', 'as-assignee@test.local'),
  ('5e110000-0000-4000-8000-000000000003', 'as-third@test.local'),
  ('5e110000-0000-4000-8000-000000000004', 'as-floor@test.local'),
  ('5e110000-0000-4000-8000-000000000005', 'as-otherbranch@test.local'),
  ('5e110000-0000-4000-8000-000000000006', 'as-noperm@test.local'),
  ('5e110000-0000-4000-8000-000000000007', 'as-invited@test.local'),
  ('5e110000-0000-4000-8000-000000000008', 'as-suspended@test.local'),
  ('5e110000-0000-4000-8000-000000000009', 'as-owner@test.local');

insert into identity.staff_members (id, user_id, status, full_name, email)
values
  ('61110000-0000-4000-8000-000000000001', '5e110000-0000-4000-8000-000000000001', 'active',    'AS Self',         'as-self@test.local'),
  ('61110000-0000-4000-8000-000000000002', '5e110000-0000-4000-8000-000000000002', 'active',    'AS Assignee',     'as-assignee@test.local'),
  ('61110000-0000-4000-8000-000000000003', '5e110000-0000-4000-8000-000000000003', 'active',    'AS Third',        'as-third@test.local'),
  ('61110000-0000-4000-8000-000000000004', '5e110000-0000-4000-8000-000000000004', 'active',    'AS Floor',        'as-floor@test.local'),
  ('61110000-0000-4000-8000-000000000005', '5e110000-0000-4000-8000-000000000005', 'active',    'AS Other Branch', 'as-otherbranch@test.local'),
  ('61110000-0000-4000-8000-000000000006', '5e110000-0000-4000-8000-000000000006', 'active',    'AS NoPerm',       'as-noperm@test.local'),
  ('61110000-0000-4000-8000-000000000007', '5e110000-0000-4000-8000-000000000007', 'invited',   'AS Invited',      'as-invited@test.local'),
  ('61110000-0000-4000-8000-000000000008', '5e110000-0000-4000-8000-000000000008', 'suspended', 'AS Suspended',    'as-suspended@test.local'),
  ('61110000-0000-4000-8000-000000000009', '5e110000-0000-4000-8000-000000000009', 'active',    'AS Owner',        'as-owner@test.local');

-- Cashiers of branch 1: the caller, the assignee, a third name, and two that
-- must never hold a drawer (invited, suspended).
insert into identity.staff_roles (staff_id, role_id, branch_id)
select s.staff_id, r.id, '4d100000-0000-4000-8000-000000000001'::uuid
from (values
  ('61110000-0000-4000-8000-000000000001'::uuid),
  ('61110000-0000-4000-8000-000000000002'),
  ('61110000-0000-4000-8000-000000000003'),
  ('61110000-0000-4000-8000-000000000007'),
  ('61110000-0000-4000-8000-000000000008')
) s(staff_id), identity.roles r where r.code = 'cashier';

-- A cashier whose role covers every branch, so they reach branches 2 and 3.
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '61110000-0000-4000-8000-000000000004', r.id, null
from identity.roles r where r.code = 'cashier';

-- A cashier of branch 2 only.
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '61110000-0000-4000-8000-000000000005', r.id, '4d200000-0000-4000-8000-000000000002'::uuid
from identity.roles r where r.code = 'cashier';

-- Branch 1, but a role without pos.manage.
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '61110000-0000-4000-8000-000000000006', r.id, '4d100000-0000-4000-8000-000000000001'::uuid
from identity.roles r where r.code = 'staff';

-- The owner role carries no role_permissions rows; identity.has_permission
-- short-circuits it (123:68-77) and the candidate rule must do the same.
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '61110000-0000-4000-8000-000000000009', r.id, null
from identity.roles r where r.code = 'owner';

set local role authenticated;

-- ---------------------------------------------------------------------------
-- 1. the picker lists branch 1's eligible cashiers and nobody else
--    Only the fixture rows are counted: the rehearsal runs against a live
--    project whose own owner staff also qualifies, and that row is not ours to
--    assert about. self, assignee, third, the all-branch cashier, fixture owner.
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"5e110000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v jsonb;
declare v_fixture integer;
begin
  v := public.admin_pos_cashiers('4d100000-0000-4000-8000-000000000001');
  select count(*)
    into v_fixture
    from jsonb_array_elements(v) e
   where (e ->> 'id')::uuid >= '61110000-0000-4000-8000-000000000000'
     and (e ->> 'id')::uuid <  '61120000-0000-4000-8000-000000000000';
  if v_fixture <> 5 then
    raise exception 'FAIL 1: branch 1 offers % fixture cashiers, expected 5', v_fixture;
  end if;
  if exists (
    select 1 from jsonb_array_elements(v) e
     where e ->> 'id' in ('61110000-0000-4000-8000-000000000005',   -- other branch
                          '61110000-0000-4000-8000-000000000006',   -- no pos.manage
                          '61110000-0000-4000-8000-000000000007',   -- invited
                          '61110000-0000-4000-8000-000000000008')   -- suspended
  ) then
    raise exception 'FAIL 1: the picker leaked a staff member that must not hold this drawer';
  end if;
  if (select count(*) from jsonb_array_elements(v) e where (e ->> 'is_self')::boolean) <> 1 then
    raise exception 'FAIL 1: the picker must mark exactly one row as the caller';
  end if;
  if not exists (
    select 1 from jsonb_array_elements(v) e
     where e ->> 'id' = '61110000-0000-4000-8000-000000000001'
       and (e ->> 'is_self')::boolean
  ) then
    raise exception 'FAIL 1: the caller row is not the one flagged as self';
  end if;
  if exists (
    select 1 from jsonb_array_elements(v) e
     where coalesce(e ->> 'full_name', '') = ''
  ) then
    raise exception 'FAIL 1: a cashier row came back without a name';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 2. the reader keeps the same three authorization arms as the drawer itself
-- ---------------------------------------------------------------------------
-- Cashier of branch 2 asking about branch 1.
select set_config('request.jwt.claims',
  '{"sub":"5e110000-0000-4000-8000-000000000005","role":"authenticated","aud":"authenticated"}', true);

do $$
begin
  perform public.admin_pos_cashiers('4d100000-0000-4000-8000-000000000001');
  raise exception 'FAIL 2a: a branch cashier listed another branch''s staff';
exception
  when others then
    if sqlstate <> '42501' then raise; end if;
    if sqlerrm not like '%branch out of scope%' then raise; end if;
end $$;

-- Same branch, a role without pos.manage.
select set_config('request.jwt.claims',
  '{"sub":"5e110000-0000-4000-8000-000000000006","role":"authenticated","aud":"authenticated"}', true);

do $$
begin
  perform public.admin_pos_cashiers('4d100000-0000-4000-8000-000000000001');
  raise exception 'FAIL 2b: staff without pos.manage read the cashier list';
exception
  when others then
    if sqlstate <> '42501' then raise; end if;
    if sqlerrm not like '%missing permission: pos.manage%' then raise; end if;
end $$;

-- Invited, never activated.
select set_config('request.jwt.claims',
  '{"sub":"5e110000-0000-4000-8000-000000000007","role":"authenticated","aud":"authenticated"}', true);

do $$
begin
  perform public.admin_pos_cashiers('4d100000-0000-4000-8000-000000000001');
  raise exception 'FAIL 2c: an invited staff member read the cashier list';
exception
  when others then
    if sqlstate <> '42501' then raise; end if;
    if sqlerrm not like '%not authenticated%' then raise; end if;
end $$;

-- ---------------------------------------------------------------------------
-- 3. opening for an eligible cashier of the branch puts the drawer on them
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"5e110000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v jsonb;
begin
  v := public.admin_pos_open_shift(
    '4d100000-0000-4000-8000-000000000001', 200.00, 'AS assigned',
    '61110000-0000-4000-8000-000000000002');
  if v is null then
    raise exception 'FAIL 3: the assigned open returned nothing';
  end if;
  if (v ->> 'opened_by_name') <> 'AS Assignee' then
    raise exception 'FAIL 3: the drawer belongs to %, expected AS Assignee', v ->> 'opened_by_name';
  end if;
  if (v ->> 'already_open')::boolean then
    raise exception 'FAIL 3: a fresh branch reported an existing shift';
  end if;
  if (v ->> 'expected_cash')::numeric <> 200.00 then
    raise exception 'FAIL 3: the float is %, expected 200.00', v ->> 'expected_cash';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 4. a second open on the same branch stays idempotent and does NOT reassign
-- ---------------------------------------------------------------------------
do $$
declare v jsonb;
begin
  v := public.admin_pos_open_shift(
    '4d100000-0000-4000-8000-000000000001', 999.00, 'AS second try',
    '61110000-0000-4000-8000-000000000003');
  if not (v ->> 'already_open')::boolean then
    raise exception 'FAIL 4: the second open created a second drawer';
  end if;
  if (v ->> 'opened_by_name') <> 'AS Assignee' then
    raise exception 'FAIL 4: the live drawer moved to %, expected AS Assignee',
      v ->> 'opened_by_name';
  end if;
  if (v ->> 'opening_float')::numeric <> 200.00 then
    raise exception 'FAIL 4: the second open rewrote the float to %', v ->> 'opening_float';
  end if;
end $$;

-- From here the caller is the all-branch cashier, so branches 2 and 3 are in
-- scope; the branch check runs before the eligibility check, and a branch-1
-- caller would only ever prove the branch arm again.
select set_config('request.jwt.claims',
  '{"sub":"5e110000-0000-4000-8000-000000000004","role":"authenticated","aud":"authenticated"}', true);

-- ---------------------------------------------------------------------------
-- 5. every ineligible name is refused, and branch 3 stays closed
-- ---------------------------------------------------------------------------
do $$
declare candidate uuid;
begin
  for candidate in
    select * from (values
      ('61110000-0000-4000-8000-000000000005'::uuid),  -- cashier of another branch
      ('61110000-0000-4000-8000-000000000006'::uuid),  -- branch 1, no pos.manage
      ('61110000-0000-4000-8000-000000000007'::uuid),  -- invited
      ('61110000-0000-4000-8000-000000000008'::uuid),  -- suspended
      ('61110000-0000-4000-8000-000000000fff'::uuid)  -- nobody at all
    ) v(id)
  loop
    begin
      perform public.admin_pos_open_shift(
        '4d300000-0000-4000-8000-000000000003', 50.00, 'AS rejected', candidate);
      raise exception 'FAIL 5: cashier % was accepted for branch 3', candidate;
    exception
      when others then
        if sqlstate <> '22023' then raise; end if;
        if sqlerrm not like '%cashier not eligible for this branch%' then raise; end if;
    end;
  end loop;
end $$;

-- The shift table is not readable from the client role, so the "nothing was
-- left behind" arm runs as the owner and hands the role back afterwards.
reset role;
do $$
begin
  if exists (
    select 1 from payments.pos_shifts
     where branch_id = '4d300000-0000-4000-8000-000000000003'
  ) then
    raise exception 'FAIL 5b: a rejected assignment still created a shift row';
  end if;
end $$;
select set_config('request.jwt.claims',
  '{"sub":"5e110000-0000-4000-8000-000000000004","role":"authenticated","aud":"authenticated"}', true);
set local role authenticated;

-- ---------------------------------------------------------------------------
-- 6. opening without a name keeps the old behaviour: the caller owns the drawer
-- ---------------------------------------------------------------------------
do $$
declare v jsonb;
begin
  v := public.admin_pos_open_shift('4d300000-0000-4000-8000-000000000003', 50.00, 'AS self');
  if (v ->> 'opened_by_name') <> 'AS Floor' then
    raise exception 'FAIL 6: a nameless open produced the drawer of %, expected AS Floor',
      v ->> 'opened_by_name';
  end if;
  v := public.admin_pos_close_shift((v ->> 'id')::uuid, 50.00, 'AS self close');
  if (v ->> 'status') <> 'closed' then
    raise exception 'FAIL 6: the rehearsal drawer could not be closed again';
  end if;
  -- Handing the caller their own id is the same call, not an eligibility test.
  v := public.admin_pos_open_shift(
    '4d300000-0000-4000-8000-000000000003', 10.00, 'AS self id',
    '61110000-0000-4000-8000-000000000004');
  if (v ->> 'opened_by_name') <> 'AS Floor' then
    raise exception 'FAIL 6: passing the caller''s own id was refused or reassigned';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 7. the owner role is assignable although it holds no role_permissions rows
-- ---------------------------------------------------------------------------
do $$
declare v jsonb;
begin
  v := public.admin_pos_open_shift(
    '4d200000-0000-4000-8000-000000000002', 30.00, 'AS floor for owner',
    '61110000-0000-4000-8000-000000000009');
  if (v ->> 'opened_by_name') <> 'AS Owner' then
    raise exception 'FAIL 7: the owner-role staff was not assignable, drawer is %',
      v ->> 'opened_by_name';
  end if;
  -- Branch 2 offers its own cashier, the all-branch cashier and the fixture
  -- owner; the project's own staff row is filtered out the same way as above.
  if (
    select count(*)
      from jsonb_array_elements(
             public.admin_pos_cashiers('4d200000-0000-4000-8000-000000000002')) e
     where (e ->> 'id')::uuid >= '61110000-0000-4000-8000-000000000000'
       and (e ->> 'id')::uuid <  '61120000-0000-4000-8000-000000000000'
  ) <> 3 then
    raise exception 'FAIL 7: branch 2 does not offer exactly its three eligible names';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 8. the surface the app calls: one signature, executable by authenticated,
--    with the helper and the tables still closed to the client role
-- ---------------------------------------------------------------------------
reset role;

do $$
declare v_args text;
begin
  select pg_get_function_arguments(p.oid)
    into v_args
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'admin_pos_open_shift';
  if v_args is null then
    raise exception 'FAIL 8: admin_pos_open_shift is gone';
  end if;
  if v_args not like '%p_cashier_id%' then
    raise exception 'FAIL 8: the live signature has no cashier parameter: %', v_args;
  end if;
  if (select count(*)
        from pg_proc p join pg_namespace n on n.oid = p.pronamespace
       where n.nspname = 'public' and p.proname = 'admin_pos_open_shift') <> 1 then
    raise exception 'FAIL 8: two open_shift overloads are live, which makes the REST call ambiguous';
  end if;
  if has_function_privilege('authenticated',
        'payments.pos_shift_cashier_candidates(uuid)', 'execute') then
    raise exception 'FAIL 8: the eligibility helper is executable from the client role';
  end if;
  if has_table_privilege('authenticated', 'payments.pos_shifts', 'select') then
    raise exception 'FAIL 8: the client role can read the shift table directly';
  end if;
end $$;

do $$
begin
  if not has_function_privilege('authenticated', 'public.admin_pos_cashiers(uuid)', 'execute') then
    raise exception 'FAIL 8b: authenticated cannot call the cashier picker';
  end if;
  if not has_function_privilege(
       'authenticated', 'public.admin_pos_open_shift(uuid, numeric, text, uuid)', 'execute') then
    raise exception 'FAIL 8c: authenticated cannot open a shift any more';
  end if;
  if has_function_privilege('anon', 'public.admin_pos_cashiers(uuid)', 'execute') then
    raise exception 'FAIL 8d: the anonymous role can call the cashier picker';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 9. the audit row names both the operator and the cashier put on the drawer
-- ---------------------------------------------------------------------------
do $$
declare a jsonb;
begin
  select al.new_values into a
    from identity.audit_log al
   where al.action = 'pos.shift.open'
     and al.new_values ->> 'cashier_name' = 'AS Assignee'
   order by al.created_at desc
   limit 1;
  if a is null then
    raise exception 'FAIL 9: no audit row names the assigned cashier';
  end if;
  if (a ->> 'assigned_by_operator')::boolean is not true then
    raise exception 'FAIL 9: the audit row does not say the drawer was assigned: %', a;
  end if;
  if (a ->> 'operator_staff_id') <> '61110000-0000-4000-8000-000000000001' then
    raise exception 'FAIL 9: the audit row lost the operator: %', a ->> 'operator_staff_id';
  end if;
end $$;

-- Reaching the report is itself the proof: every section above raises on the
-- first mismatch. The transaction rolls back, so none of this stays.
select
  'reached the end: no assertion failed' as verdict,
  (select count(*) from payments.pos_shifts
    where branch_id in ('4d100000-0000-4000-8000-000000000001',
                        '4d200000-0000-4000-8000-000000000002',
                        '4d300000-0000-4000-8000-000000000003')) as shifts_created,
  (select string_agg(sm.full_name, ', ' order by sm.full_name)
     from payments.pos_shifts s
     join identity.staff_members sm on sm.id = s.opened_by
    where s.branch_id in ('4d100000-0000-4000-8000-000000000001',
                          '4d200000-0000-4000-8000-000000000002',
                          '4d300000-0000-4000-8000-000000000003')) as drawer_owners;

rollback;
