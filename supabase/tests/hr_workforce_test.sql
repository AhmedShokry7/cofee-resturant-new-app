-- hr_workforce_test.sql
-- Behaviour test for 212_hr_workforce.sql: the HR and workforce module.
--
-- STATUS: EXECUTED AND PASSED on 2026-10-29 against the live project
-- webzzasosevzymftgszn, inside the single rolled-back transaction below, with
-- `supabase db query --linked -f <this file>` run from app/admin_app. Every
-- fixture dies with the rollback, so the rehearsal leaves no HR row, no payroll
-- run and no audit entry in the database. The report row came back as:
--   verdict = 'reached the end: no assertion failed', employment_files = 7
--   (the six fixtures plus the one staff member the live database already had),
--   schedules = 3, sessions = 2, corrections = 2, leave_requests = 2,
--   runs = 'paid 8 / approved 9 / paid 10',
--   advance_people = 'HR Manager, HR Cashier One',
--   adjustments = 'deduction 500.00 approved, deduction 30.00 approved',
--   discrepancy = 'deduction_approved / attributed 6d000000-…-0004',
--   shift_variance_kept = '-50.00', hr_audit_rows = 36
-- Because the live database is not empty, every directory and ledger assertion
-- below is measured against the fixture ids rather than a row count.
--
-- PREREQUISITE: 212 applied (15 hr tables, 36 public.admin_hr_* definer RPCs,
-- 15 hr.* permission codes, tr_staff_employment_record, tr_pos_shift_discrepancy).
-- Against a database without 212 the fixtures fail with 42P01, which is the
-- expected answer, not a bug in the test.
--
-- WHAT THIS PROVES, IN ORDER
--   1  nothing in the hr schema is reachable without an RPC, not even for the
--      owner, who passes every permission check
--   2  every RPC refuses a cashier, a customer and a signed-out anon with the
--      message that names what it is missing
--   3  the directory answers inside the branch scope of identity.staff_roles,
--      and never carries a salary
--   4  attendance is stamped by the server clock, one open session per person,
--      and a dispute is a pending request until someone else approves it
--   5  two live schedules for one person cannot overlap
--   6  a salary is effective-dated: one start per date, no backdating behind a
--      later record
--   7  money moves only after an approved, audited decision: an advance is
--      requested, cross-reviewed, disbursed, and only then deducted
--   8  a pending adjustment deducts nothing; the same row approved by a second
--      person is the only reason it appears; once a run snapshots it, it cannot
--      be reversed; and calculating, approving and paying are three different
--      people, on a run that needs all-branch scope to be generated at all
--   9  a closed drawer with a variance opens a review record and edits nothing
--      else; a shortage becomes a deduction only after it is confirmed against a
--      named employee, only with the policy switch on, and only inside the
--      percentage cap, and one variance can only ever produce that one deduction
--  10  leave needs a balance, is capped by it, and is never reviewed by the
--      requester
--  11  every decision above is written to identity.audit_log, and the money ones
--      are already critical without a client change
--
-- WHAT IS NOT TESTED HERE
--   Concurrency (the advisory locks in set_compensation, save_schedule and
--   generate_payroll) and Realtime. A single session cannot observe a lock: a
--   test that re-reads its own row twice passes whether the lock existed or not.
--
-- FOUR CONTRACT FACTS THIS REHEARSAL ESTABLISHED, BECAUSE THEY ARE NOT OBVIOUS
--   a  The denial the authenticated role gets on any hr table or hr.* function
--      is "permission denied for schema hr": 212 grants no USAGE on the schema,
--      so the message names the schema rather than the object. The precise
--      per-object shape is asserted through has_*_privilege instead of wording.
--   b  A permission check answers before a scope check. A manager whose role row
--      is bound to one branch still holds the manager codes, so what refuses
--      them is the employee or the branch outside their reach, never a code.
--   c  A PL/pgSQL block that catches an error discards every write that same
--      block had already made, so a successful action and the refusal of a
--      repeat of it live in separate blocks. Section 4 is the case that proves
--      the rule: sharing one block left the approved session still open.
--   d  Enabling cashier deductions is refused while the percentage cap is zero
--      ('cashier deductions need a positive cap'), so the switch and the cap are
--      set in one write here. A cap of 0.4 percent of a 6500 gross is 26.00,
--      which is what keeps the 30.00 shortage out of the October payslip until
--      the cap is raised.

begin;

-- ---------------------------------------------------------------------------
-- Fixtures: two branches, six staff with six different reaches, one customer,
-- one open drawer.
-- ---------------------------------------------------------------------------
insert into core.branches (id, brand_id, code, name_ar, name_en, address, is_active, settings)
values
  ('4e100000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000001', 'HR-B1', 'فرع التدريب 1', 'HR Training Branch 1', 'addr1', true, '{}'::jsonb),
  ('4e200000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000001', 'HR-B2', 'فرع التدريب 2', 'HR Training Branch 2', 'addr2', true, '{}'::jsonb);

insert into auth.users (id, email)
values
  ('5d000000-0000-4000-8000-000000000001', 'hr-owner@test.local'),
  ('5d000000-0000-4000-8000-000000000002', 'hr-manager@test.local'),
  ('5d000000-0000-4000-8000-000000000003', 'hr-branch-manager@test.local'),
  ('5d000000-0000-4000-8000-000000000004', 'hr-cashier-one@test.local'),
  ('5d000000-0000-4000-8000-000000000005', 'hr-cashier-two@test.local'),
  ('5d000000-0000-4000-8000-000000000006', 'hr-approver@test.local'),
  ('5d000000-0000-4000-8000-000000000007', 'hr-customer@test.local');

insert into identity.profiles (id, full_name, email, phone)
values ('5d000000-0000-4000-8000-000000000007', 'HR Customer', 'hr-customer@test.local', '0500000007')
on conflict (id) do nothing;

insert into identity.staff_members (id, user_id, status, full_name, email)
values
  ('6d000000-0000-4000-8000-000000000001', '5d000000-0000-4000-8000-000000000001', 'active', 'HR Owner',         'hr-owner@test.local'),
  ('6d000000-0000-4000-8000-000000000002', '5d000000-0000-4000-8000-000000000002', 'active', 'HR Manager',       'hr-manager@test.local'),
  ('6d000000-0000-4000-8000-000000000003', '5d000000-0000-4000-8000-000000000003', 'active', 'HR Branch Manager', 'hr-branch-manager@test.local'),
  ('6d000000-0000-4000-8000-000000000004', '5d000000-0000-4000-8000-000000000004', 'active', 'HR Cashier One',   'hr-cashier-one@test.local'),
  ('6d000000-0000-4000-8000-000000000005', '5d000000-0000-4000-8000-000000000005', 'active', 'HR Cashier Two',   'hr-cashier-two@test.local'),
  ('6d000000-0000-4000-8000-000000000006', '5d000000-0000-4000-8000-000000000006', 'active', 'HR Approver',      'hr-approver@test.local');

-- A NULL branch on staff_roles is what identity.manages_all_branches() reads, so
-- it is the difference between a brand manager and a manager who answers for one
-- branch. Both shapes exist here on purpose.
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '6d000000-0000-4000-8000-000000000001', r.id, null from identity.roles r where r.code = 'owner';
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '6d000000-0000-4000-8000-000000000002', r.id, null from identity.roles r where r.code = 'manager';
-- The brand manager also works a shift in branch 1. Without a branch row of
-- their own they could never be a valid attribution target there, and the
-- self-attribution guard of section 9 would be unreachable behind the branch
-- membership check.
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '6d000000-0000-4000-8000-000000000002', r.id, '4e100000-0000-4000-8000-000000000001' from identity.roles r where r.code = 'cashier';
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '6d000000-0000-4000-8000-000000000003', r.id, '4e200000-0000-4000-8000-000000000002' from identity.roles r where r.code = 'branch_manager';
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '6d000000-0000-4000-8000-000000000003', r.id, '4e200000-0000-4000-8000-000000000002' from identity.roles r where r.code = 'manager';
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '6d000000-0000-4000-8000-000000000004', r.id, '4e100000-0000-4000-8000-000000000001' from identity.roles r where r.code = 'cashier';
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '6d000000-0000-4000-8000-000000000005', r.id, '4e200000-0000-4000-8000-000000000002' from identity.roles r where r.code = 'cashier';

-- 212 deliberately leaves hr.payroll.approve and hr.payroll.pay with the owner,
-- because identity.has_permission short-circuits that role. A test role holding
-- those codes is the only way to see what the codes guard, so this fixture makes
-- one and the rollback drops it. It grants nothing that 212 grants to manager or
-- branch_manager, and it is not a product decision.
insert into identity.roles (code, name_ar, name_en, description, is_system)
values ('hr_test_approver', 'دور اختبار الرواتب', 'Payroll test approver role',
        'Behaviour-test role for 212: holds the payroll codes 212 leaves with the owner', false);

insert into identity.role_permissions (role_id, permission_id)
select r.id, p.id
  from identity.roles r
  join identity.permissions p on p.code in (
    'hr.payroll.read', 'hr.payroll.manage', 'hr.payroll.approve', 'hr.payroll.pay'
  )
 where r.code = 'hr_test_approver';

insert into identity.staff_roles (staff_id, role_id, branch_id)
select '6d000000-0000-4000-8000-000000000006', r.id, null from identity.roles r where r.code = 'hr_test_approver';

-- The drawer section 10 closes. It stays open until the privileged update there,
-- which is what fires tr_pos_shift_discrepancy.
insert into payments.pos_shifts (id, branch_id, status, opening_float, opened_by, note)
values ('7e000000-0000-4000-8000-000000000001', '4e100000-0000-4000-8000-000000000001',
        'open', 100.00, '6d000000-0000-4000-8000-000000000004', 'HR training drawer');

do $$
begin
  perform set_config('test.annual', (select id::text from hr.leave_types where code = 'annual'), true);
  perform set_config('test.sick',    (select id::text from hr.leave_types where code = 'sick'),    true);
  if current_setting('test.annual') is null or current_setting('test.sick') is null then
    raise exception 'FAIL 0: 212 did not seed the annual and sick leave types';
  end if;
  -- The policy row ships with every rate at zero and the deduction switch off.
  if (select count(*) from hr.settings where id = 1
        and absence_day_rate = 0 and late_minute_rate = 0 and early_minute_rate = 0
        and max_salary_deduction_percent = 0 and cashier_deduction_allowed = false) <> 1 then
    raise exception 'FAIL 0: hr.settings did not start as a no-money-movement policy';
  end if;
end $$;

set local role authenticated;

-- ===========================================================================
-- 1. Nothing in hr is reachable without an RPC.
-- ===========================================================================
select set_config('request.jwt.claims',
  '{"sub":"5d000000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);

-- RLS with zero policies is the second door, not the first one: the role has no
-- table privileges at all, so even the owner cannot read the schema directly.
do $$
declare
  v_tables text[] := array['hr.attendance_sessions','hr.payroll_runs','hr.settings','hr.cashier_discrepancies'];
  t text;
begin
  foreach t in array v_tables loop
    begin
      execute 'select count(*) from ' || t;
      raise exception 'FAIL 1: the authenticated role read % directly', t;
    exception
      when insufficient_privilege then
        null;
    end;
  end loop;
end $$;

do $$
begin
  begin
    insert into hr.work_schedules (staff_id, branch_id, scheduled_start, scheduled_end, created_by)
    values ('6d000000-0000-4000-8000-000000000004', '4e100000-0000-4000-8000-000000000001',
            now(), now() + interval '8 hours', '6d000000-0000-4000-8000-000000000004');
    raise exception 'FAIL 1: the authenticated role wrote hr.work_schedules directly';
  exception
    when insufficient_privilege then
      -- The denial lands on the schema before it reaches the table: 212 grants
      -- no USAGE on hr at all. Either wording proves the door is shut; the
      -- catalog assertions below name the exact missing privilege.
      if not (sqlerrm like '%permission denied for table work_schedules%'
              or sqlerrm like '%permission denied for schema hr%') then raise; end if;
  end;
  begin
    update hr.settings set absence_day_rate = 99 where id = 1;
    raise exception 'FAIL 1: the authenticated role edited the HR policy row';
  exception
    when insufficient_privilege then
      if not (sqlerrm like '%permission denied for table settings%'
              or sqlerrm like '%permission denied for schema hr%') then raise; end if;
  end;
end $$;

-- The authorization helpers are definer internals, not client surface.
do $$
begin
  begin
    perform hr.require_permission('hr.employee.read');
    raise exception 'FAIL 1: the authenticated role called hr.require_permission';
  exception
    when insufficient_privilege then
      if not (sqlerrm like '%permission denied for function require_permission%'
              or sqlerrm like '%permission denied for schema hr%') then raise; end if;
  end;
  begin
    perform hr.capture_pos_discrepancy();
    raise exception 'FAIL 1: the authenticated role called the discrepancy trigger function';
  exception
    when insufficient_privilege then
      if not (sqlerrm like '%permission denied for function capture_pos_discrepancy%'
              or sqlerrm like '%permission denied for schema hr%') then raise; end if;
  end;
end $$;

reset role;
do $$
begin
  -- The precise shape of the deny-by-default grant, independent of wording:
  -- the role cannot enter the schema, cannot touch a single table, and can only
  -- reach the public wrapper.
  if has_schema_privilege('authenticated', 'hr', 'USAGE') then
    raise exception 'FAIL 1: authenticated has USAGE on schema hr';
  end if;
  if (select count(*) from pg_class c join pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'hr' and c.relkind = 'r'
          and has_table_privilege('authenticated', c.oid, 'SELECT')) <> 0 then
    raise exception 'FAIL 1: authenticated reads at least one hr table directly';
  end if;
  if (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'hr'
          and has_function_privilege('authenticated', p.oid, 'EXECUTE')) <> 0 then
    raise exception 'FAIL 1: authenticated executes at least one hr internal function';
  end if;
  if not has_function_privilege('authenticated',
       'public.admin_hr_employees(text,uuid,text,text)', 'EXECUTE') then
    raise exception 'FAIL 1: the directory wrapper is not callable by authenticated';
  end if;
end $$;

set local role authenticated;

-- ===========================================================================
-- 2. The refusals every RPC owes before it reads anything.
-- ===========================================================================
select set_config('request.jwt.claims',
  '{"sub":"5d000000-0000-4000-8000-000000000004","role":"authenticated","aud":"authenticated"}', true);

-- A cashier holds no hr.* code, and each RPC names the code it wanted.
do $$
begin
  begin
    perform public.admin_hr_employees(null, null, null, null);
    raise exception 'FAIL 2a: a cashier read the employee directory';
  exception
    when others then
      if sqlstate <> '42501' then raise; end if;
      if sqlerrm not like '%missing permission: hr.employee.read%' then raise; end if;
  end;
  begin
    perform public.admin_hr_generate_payroll(2026, 9);
    raise exception 'FAIL 2a: a cashier generated a payroll run';
  exception
    when others then
      if sqlstate <> '42501' then raise; end if;
      if sqlerrm not like '%missing permission: hr.payroll.manage%' then raise; end if;
  end;
  begin
    perform public.admin_hr_approve_payroll(extensions.gen_random_uuid());
    raise exception 'FAIL 2a: a cashier approved a payroll run';
  exception
    when others then
      if sqlstate <> '42501' then raise; end if;
      if sqlerrm not like '%missing permission: hr.payroll.approve%' then raise; end if;
  end;
  begin
    perform public.admin_hr_pay_payroll(extensions.gen_random_uuid());
    raise exception 'FAIL 2a: a cashier marked a run paid';
  exception
    when others then
      if sqlstate <> '42501' then raise; end if;
      if sqlerrm not like '%missing permission: hr.payroll.pay%' then raise; end if;
  end;
  begin
    perform public.admin_hr_adjustments(null, null, null, null);
    raise exception 'FAIL 2a: a cashier read the adjustments ledger';
  exception
    when others then
      if sqlstate <> '42501' then raise; end if;
      -- The ledger opens for either payroll.read or finance.adjust; the cashier
      -- holds neither, so the refusal names the code it checked first.
      if sqlerrm not like '%missing permission: hr.payroll.read%' then raise; end if;
  end;
  begin
    perform public.admin_hr_update_settings(p_cashier_deduction_allowed := true);
    raise exception 'FAIL 2a: a cashier edited the HR policy';
  exception
    when others then
      if sqlstate <> '42501' then raise; end if;
      if sqlerrm not like '%missing permission: hr.settings.manage%' then raise; end if;
  end;
  -- The permission arm runs before the scope arm, so this names the code the
  -- cashier lacks rather than the employee they cannot reach.
  begin
    perform public.admin_hr_set_compensation(
      '6d000000-0000-4000-8000-000000000005', 4000, 0, 0, 0, '2026-01-01', null);
    raise exception 'FAIL 2a: a cashier set a salary';
  exception
    when others then
      if sqlstate <> '42501' then raise; end if;
      if sqlerrm not like '%missing permission: hr.compensation.manage%' then raise; end if;
  end;
end $$;

-- A customer account is not staff at all, so 212 says that before naming a code.
select set_config('request.jwt.claims',
  '{"sub":"5d000000-0000-4000-8000-000000000007","role":"authenticated","aud":"authenticated"}', true);

do $$
begin
  begin
    perform public.admin_hr_employees(null, null, null, null);
    raise exception 'FAIL 2b: a customer read the employee directory';
  exception
    when others then
      if sqlstate <> '42501' then raise; end if;
      if sqlerrm not like '%not authenticated%' then raise; end if;
  end;
  -- The self-service surface a cashier legitimately owns still refuses them.
  begin
    perform public.hr_clock_in('4e100000-0000-4000-8000-000000000001', null);
    raise exception 'FAIL 2b: a customer clocked in';
  exception
    when others then
      if sqlstate <> '42501' then raise; end if;
      if sqlerrm not like '%not authenticated%' then raise; end if;
  end;
  begin
    perform public.hr_request_leave(current_setting('test.annual')::uuid,
                                    current_date, current_date + 1, 'عطلة', null);
    raise exception 'FAIL 2b: a customer requested leave';
  exception
    when others then
      if sqlstate <> '42501' then raise; end if;
      if sqlerrm not like '%not authenticated%' then raise; end if;
  end;
end $$;

-- Signed out: the public wrappers are revoked from anon, so the call never
-- reaches a body that could be tricked.
reset role;
set local role anon;

do $$
begin
  begin
    perform public.admin_hr_employees(null, null, null, null);
    raise exception 'FAIL 2c: anon read the employee directory';
  exception
    when others then
      if sqlstate <> '42501' then raise; end if;
      if sqlerrm not like '%permission denied for function admin_hr_employees%' then raise; end if;
  end;
  begin
    perform public.admin_hr_review_discrepancy(
      extensions.gen_random_uuid(), 'deduct', 'x', null, null, 10);
    raise exception 'FAIL 2c: anon reviewed a cashier discrepancy';
  exception
    when others then
      if sqlstate <> '42501' then raise; end if;
      if sqlerrm not like '%permission denied for function admin_hr_review_discrepancy%' then raise; end if;
  end;
end $$;

set local role authenticated;

-- ===========================================================================
-- 3. The directory answers inside the branch scope, and never carries money.
-- ===========================================================================
select set_config('request.jwt.claims',
  '{"sub":"5d000000-0000-4000-8000-000000000002","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v jsonb;
declare seen text;
begin
  v := public.admin_hr_employees(null, null, null, null);
  if v is null then
    raise exception 'FAIL 3a: the directory returned nothing';
  end if;
  -- Measured against the fixtures, not against the row count: the live database
  -- carries the staff the rehearsal did not create, and the scope rule has to
  -- hold on top of them.
  select string_agg(substring(e ->> 'staff_id' from 1 for 36), ',' order by e ->> 'staff_id')
    into seen
    from jsonb_array_elements(v) e
   where e ->> 'staff_id' like '6d000000%';
  if seen <> '6d000000-0000-4000-8000-000000000001,6d000000-0000-4000-8000-000000000002,'
          || '6d000000-0000-4000-8000-000000000003,6d000000-0000-4000-8000-000000000004,'
          || '6d000000-0000-4000-8000-000000000005,6d000000-0000-4000-8000-000000000006' then
    raise exception 'FAIL 3a: the brand manager sees %, expected all six fixture staff', seen;
  end if;
  if not jsonb_path_exists(v, '$[*] ? (@.staff_id == "6d000000-0000-4000-8000-000000000004")') then
    raise exception 'FAIL 3a: the brand manager cannot see the branch 1 cashier';
  end if;
  if exists (select 1 from jsonb_array_elements(v) e where e ? 'basic_salary') then
    raise exception 'FAIL 3a: the employee directory carried a salary';
  end if;
  -- The file arrives with the row: the employment trigger wrote it on insert.
  if not jsonb_path_exists(v, '$[*] ? (@.full_name == "HR Cashier One" && @.employment_status == "active")') then
    raise exception 'FAIL 3a: the directory row lost its employment file';
  end if;

  -- One branch, filtered: the answer is that branch's staff, not the brand's.
  v := public.admin_hr_employees(null, '4e200000-0000-4000-8000-000000000002', null, null);
  select string_agg(substring(e ->> 'staff_id' from 1 for 36), ',' order by e ->> 'staff_id')
    into seen
    from jsonb_array_elements(v) e
   where e ->> 'staff_id' like '6d000000%';
  if seen <> '6d000000-0000-4000-8000-000000000003,6d000000-0000-4000-8000-000000000005' then
    raise exception 'FAIL 3a: the branch 2 filter answers %, expected the branch 2 manager and cashier', seen;
  end if;
end $$;

-- An unknown status is a refused input, not an empty answer.
do $$
begin
  begin
    perform public.admin_hr_employees(null, null, 'resigned', null);
    raise exception 'FAIL 3a: an unknown employment status was accepted';
  exception
    when others then
      if sqlstate <> '22023' then raise; end if;
      if sqlerrm not like '%invalid employment status%' then raise; end if;
  end;
end $$;

-- The branch 2 manager answers for branch 2 only.
select set_config('request.jwt.claims',
  '{"sub":"5d000000-0000-4000-8000-000000000003","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v jsonb;
declare seen text;
begin
  v := public.admin_hr_employees(null, null, null, null);
  if jsonb_path_exists(v, '$[*] ? (@.staff_id == "6d000000-0000-4000-8000-000000000004")') then
    raise exception 'FAIL 3b: the branch 2 manager saw the branch 1 cashier';
  end if;
  if not jsonb_path_exists(v, '$[*] ? (@.staff_id == "6d000000-0000-4000-8000-000000000005")') then
    raise exception 'FAIL 3b: the branch 2 manager lost their own branch cashier';
  end if;
  -- Their whole reach, measured on the fixtures: themselves and the branch 2
  -- cashier. Not the owner, not the brand manager, not the other branch.
  select string_agg(e ->> 'staff_id', ',' order by e ->> 'staff_id')
    into seen
    from jsonb_array_elements(v) e
   where e ->> 'staff_id' like '6d000000%';
  if seen <> '6d000000-0000-4000-8000-000000000003,6d000000-0000-4000-8000-000000000005' then
    raise exception 'FAIL 3b: the branch 2 manager sees %, expected only their own branch staff', seen;
  end if;
end $$;

-- Reaching across the branch is refused with the scope message, before any
-- schedule, salary or finance write is attempted.
do $$
begin
  begin
    perform public.admin_hr_save_schedule(
      '6d000000-0000-4000-8000-000000000004', '4e100000-0000-4000-8000-000000000001',
      '2026-11-03T09:00:00Z', '2026-11-03T17:00:00Z', 0, 'published', null, null);
    raise exception 'FAIL 3b: the branch 2 manager scheduled a branch 1 employee';
  exception
    when others then
      if sqlstate <> '42501' then raise; end if;
      if sqlerrm not like '%staff member out of scope%' then raise; end if;
  end;
  -- A staff member they DO reach, scheduled into a branch they do not reach:
  -- this is the arm identity.can_manage_branch owns, and it answers after the
  -- staff check rather than before it.
  begin
    perform public.admin_hr_save_schedule(
      '6d000000-0000-4000-8000-000000000005', '4e100000-0000-4000-8000-000000000001',
      '2026-11-04T08:00:00Z', '2026-11-04T16:00:00Z', 0, 'draft', null, null);
    raise exception 'FAIL 3b: a branch 2 manager scheduled into branch 1';
  exception
    when others then
      if sqlstate <> '42501' then raise; end if;
      if sqlerrm not like '%branch out of scope%' then raise; end if;
  end;
  -- Compensation is a manager code, and this fixture holds the manager role on
  -- one branch only: the code is theirs, the person is not. The scope check
  -- still runs after the permission check, so the refusal names the staff.
  -- The call that would succeed for their own branch is deliberately not made
  -- here: a second salary record would change every payslip total the payroll
  -- sections below assert to the cent.
  begin
    perform public.admin_hr_set_compensation(
      '6d000000-0000-4000-8000-000000000004', 4000, 0, 0, 0, '2026-01-01', null);
    raise exception 'FAIL 3b: a branch-scoped manager set a salary outside their branch';
  exception
    when others then
      if sqlstate <> '42501' then raise; end if;
      if sqlerrm not like '%staff member out of scope%' then raise; end if;
  end;
end $$;

-- ===========================================================================
-- 4. Attendance: the server clock, one open session, a disputed row is a request.
-- ===========================================================================
select set_config('request.jwt.claims',
  '{"sub":"5d000000-0000-4000-8000-000000000004","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v jsonb;
begin
  begin
    perform public.hr_clock_in('4e200000-0000-4000-8000-000000000002', null);
    raise exception 'FAIL 4: a cashier clocked in on another branch';
  exception
    when others then
      if sqlstate <> '42501' then raise; end if;
      if sqlerrm not like '%branch out of scope%' then raise; end if;
  end;

  v := public.hr_clock_in('4e100000-0000-4000-8000-000000000001', 'start of day');
  if v is null or (v ->> 'id') is null then
    raise exception 'FAIL 4: the clock-in returned nothing';
  end if;
  if (v ->> 'is_open')::boolean is not true then
    raise exception 'FAIL 4: a fresh clock-in is not an open session';
  end if;
  -- The clock is the server clock: no client-chosen timestamp can land here.
  if abs(extract(epoch from ((v ->> 'clock_in')::timestamptz - now()))) > 60 then
    raise exception 'FAIL 4: clock_in % is not the server clock', v ->> 'clock_in';
  end if;
  perform set_config('test.session', v ->> 'id', true);

  begin
    perform public.hr_clock_in('4e100000-0000-4000-8000-000000000001', 'again');
    raise exception 'FAIL 4: a second open session was created';
  exception
    when others then
      if sqlstate <> '23505' then raise; end if;
      if sqlerrm not like '%already clocked in%' then raise; end if;
  end;
end $$;

-- An employee may dispute their own record. What they get is a pending request;
-- the session row is untouched until someone else reviews it.
do $$
declare v jsonb;
begin
  begin
    perform public.admin_hr_request_attendance_correction(
      '6d000000-0000-4000-8000-000000000004', current_setting('test.session')::uuid,
      null, null, '   ');
    raise exception 'FAIL 4: a correction without a reason was accepted';
  exception
    when others then
      if sqlstate <> '22023' then raise; end if;
      if sqlerrm not like '%needs a reason%' then raise; end if;
  end;
  begin
    perform public.admin_hr_request_attendance_correction(
      '6d000000-0000-4000-8000-000000000004', null, null, null, 'nothing to change');
    raise exception 'FAIL 4: a correction with no change was accepted';
  exception
    when others then
      if sqlstate <> '22023' then raise; end if;
      if sqlerrm not like '%no change proposed%' then raise; end if;
  end;

  v := public.admin_hr_request_attendance_correction(
    '6d000000-0000-4000-8000-000000000004', current_setting('test.session')::uuid,
    null, '2026-12-31T18:00:00Z', 'نسيت أسجل الخروج');
  if v is null or (v ->> 'status') <> 'pending' then
    raise exception 'FAIL 4: the correction request is not pending';
  end if;
  if (v ->> 'session_id') <> current_setting('test.session') then
    raise exception 'FAIL 4: the correction lost the session it disputes';
  end if;
  perform set_config('test.correction', v ->> 'id', true);

  -- Two pending corrections on one session would be two answers; the partial
  -- unique index allows one.
  begin
    perform public.admin_hr_request_attendance_correction(
      '6d000000-0000-4000-8000-000000000004', current_setting('test.session')::uuid,
      null, '2026-12-31T19:00:00Z', 'تصحيح آخر');
    raise exception 'FAIL 4: a second pending correction on the same session was accepted';
  exception
    when others then
      if sqlstate <> '23505' then raise; end if;
  end;
end $$;

-- A manager may correct anyone in scope; reviewing your own dispute is refused.
select set_config('request.jwt.claims',
  '{"sub":"5d000000-0000-4000-8000-000000000003","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v jsonb;
begin
  -- No branch on the row means there is nothing to record attendance against.
  -- The target is the test approver: unlike the brand manager, who now also
  -- works a branch 1 shift, this fixture has no branch role row at all.
  perform set_config('request.jwt.claims',
    '{"sub":"5d000000-0000-4000-8000-000000000002","role":"authenticated","aud":"authenticated"}', true);
  begin
    perform public.admin_hr_request_attendance_correction(
      '6d000000-0000-4000-8000-000000000006', null,
      '2026-10-28T09:00:00Z', '2026-10-28T17:00:00Z', 'مناوبة بلا تسجيل');
    raise exception 'FAIL 4: a correction was accepted for an employee with no branch';
  exception
    when others then
      if sqlstate <> '22023' then raise; end if;
      if sqlerrm not like '%no branch to record attendance in%' then raise; end if;
  end;

  perform set_config('request.jwt.claims',
    '{"sub":"5d000000-0000-4000-8000-000000000003","role":"authenticated","aud":"authenticated"}', true);
  v := public.admin_hr_request_attendance_correction(
    '6d000000-0000-4000-8000-000000000003', null,
    '2026-10-28T09:00:00Z', '2026-10-28T17:00:00Z', 'مناوبة بلا تسجيل');
  if v is null then
    raise exception 'FAIL 4: the branch manager could not dispute their own day';
  end if;
  perform set_config('test.correction2', v ->> 'id', true);

  begin
    perform public.admin_hr_review_attendance_correction(
      current_setting('test.correction2')::uuid, true, 'موافقة ذاتية');
    raise exception 'FAIL 4: a manager approved their own attendance correction';
  exception
    when others then
      if sqlstate <> '42501' then raise; end if;
      if sqlerrm not like '%cannot approve your own attendance correction%' then raise; end if;
  end;
end $$;

reset role;
do $$
declare
  v_clock_out timestamptz;
  v_status    text;
begin
  select clock_out into v_clock_out from hr.attendance_sessions
   where id = current_setting('test.session')::uuid;
  if v_clock_out is not null then
    raise exception 'FAIL 4: the pending correction already rewrote the session';
  end if;
  select status into v_status from hr.attendance_corrections where id = current_setting('test.correction')::uuid;
  if v_status <> 'pending' then
    raise exception 'FAIL 4: the correction row is % before any review', v_status;
  end if;
  if (select count(*) from hr.attendance_sessions) <> 1 then
    raise exception 'FAIL 4: a request created an attendance session of its own';
  end if;
end $$;

-- Now the brand manager reviews both disputes: the cashier's session is rewritten,
-- the branch manager's request becomes a new session, and a reviewed row cannot
-- be reviewed twice.
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"5d000000-0000-4000-8000-000000000002","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v jsonb;
begin
  v := public.admin_hr_review_attendance_correction(
    current_setting('test.correction')::uuid, true, 'مقبول');
  if v is null or (v ->> 'status') <> 'approved' then
    raise exception 'FAIL 4: the cashier correction was not approved';
  end if;
end $$;

-- A reviewed row answers nobody, not even the reviewer who approved it. This
-- lives in its own block on purpose: a PL/pgSQL block that catches an error
-- discards every write that same block had already made, which would undo the
-- approval above and test nothing.
do $$
begin
  begin
    perform public.admin_hr_review_attendance_correction(
      current_setting('test.correction')::uuid, false, 'ثانية');
    raise exception 'FAIL 4: a reviewed correction was reviewed again';
  exception
    when others then
      if sqlstate <> '23514' then raise; end if;
      if sqlerrm not like '%already reviewed%' then raise; end if;
  end;
end $$;

do $$
declare v jsonb;
begin
  v := public.admin_hr_review_attendance_correction(
    current_setting('test.correction2')::uuid, true, 'مقبول');
  if v is null then
    raise exception 'FAIL 4: the branch manager correction was not approved';
  end if;
end $$;

-- The cashier's own session is closed by the approval, so a clock-out now has
-- nothing to close.
select set_config('request.jwt.claims',
  '{"sub":"5d000000-0000-4000-8000-000000000004","role":"authenticated","aud":"authenticated"}', true);

do $$
begin
  begin
    perform public.hr_clock_out(null);
    raise exception 'FAIL 4: a clock-out closed a session that was already closed';
  exception
    when others then
      if sqlstate <> '23514' then raise; end if;
      if sqlerrm not like '%no open attendance session%' then raise; end if;
  end;
end $$;

reset role;
do $$
declare v_out timestamptz;
begin
  if (select count(*) from hr.attendance_sessions) <> 2 then
    raise exception 'FAIL 4: expected two attendance sessions after the two approvals, found %',
      (select count(*) from hr.attendance_sessions);
  end if;
  if (select count(*) from hr.attendance_sessions where clock_out is null) <> 0 then
    raise exception 'FAIL 4: an approval left a session open';
  end if;

  -- The approved clock-out is the value the employee proposed, written by the
  -- reviewer into the session the request pointed at.
  select clock_out into v_out from hr.attendance_sessions
   where id = current_setting('test.session')::uuid;
  if v_out is distinct from timestamptz '2026-12-31 18:00:00+00' then
    raise exception 'FAIL 4: the approved correction left clock_out at %', v_out;
  end if;
end $$;

-- ===========================================================================
-- 5. Schedules: expected work, and one person cannot be in two places.
-- ===========================================================================
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"5d000000-0000-4000-8000-000000000002","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v jsonb;
begin
  v := public.admin_hr_save_schedule(
    '6d000000-0000-4000-8000-000000000004', '4e100000-0000-4000-8000-000000000001',
    '2026-11-03T09:00:00Z', '2026-11-03T17:00:00Z', 60, 'published', 'مناوبة صباحية', null);
  if v is null or (v ->> 'id') is null then
    raise exception 'FAIL 5: the first schedule was not created';
  end if;
  if (v ->> 'status') <> 'published' then
    raise exception 'FAIL 5: the schedule lost the status it was given';
  end if;
  perform set_config('test.schedule', v ->> 'id', true);

  -- Overlap arms, each refused by the trigger before a row exists.
  begin
    perform public.admin_hr_save_schedule(
      '6d000000-0000-4000-8000-000000000004', '4e100000-0000-4000-8000-000000000001',
      '2026-11-03T16:00:00Z', '2026-11-03T20:00:00Z', 0, 'draft', null, null);
    raise exception 'FAIL 5: an overlapping schedule was accepted';
  exception
    when others then
      if sqlstate <> '23505' then raise; end if;
      if sqlerrm not like '%overlapping work schedule%' then raise; end if;
  end;

  -- A shift is a window, not a length choice.
  begin
    perform public.admin_hr_save_schedule(
      '6d000000-0000-4000-8000-000000000004', '4e100000-0000-4000-8000-000000000001',
      '2026-11-04T17:00:00Z', '2026-11-04T09:00:00Z', 0, 'draft', null, null);
    raise exception 'FAIL 5: a schedule ending before it starts was accepted';
  exception
    when others then
      if sqlstate <> '22023' then raise; end if;
      if sqlerrm not like '%invalid schedule window%' then raise; end if;
  end;
  begin
    perform public.admin_hr_save_schedule(
      '6d000000-0000-4000-8000-000000000004', '4e100000-0000-4000-8000-000000000001',
      '2026-11-04T08:00:00Z', '2026-11-05T08:01:00Z', 0, 'draft', null, null);
    raise exception 'FAIL 5: a schedule longer than 24 hours was accepted';
  exception
    when others then
      if sqlstate <> '22023' then raise; end if;
      if sqlerrm not like '%cannot exceed 24 hours%' then raise; end if;
  end;
  begin
    perform public.admin_hr_save_schedule(
      '6d000000-0000-4000-8000-000000000004', '4e100000-0000-4000-8000-000000000001',
      '2026-11-04T08:00:00Z', '2026-11-04T16:00:00Z', 300, 'draft', null, null);
    raise exception 'FAIL 5: a break longer than the shift was accepted';
  exception
    when others then
      if sqlstate <> '22023' then raise; end if;
      if sqlerrm not like '%invalid break length%' then raise; end if;
  end;
  begin
    perform public.admin_hr_save_schedule(
      '6d000000-0000-4000-8000-000000000004', '4e100000-0000-4000-8000-000000000001',
      '2026-11-04T08:00:00Z', '2026-11-04T16:00:00Z', 0, 'archived', null, null);
    raise exception 'FAIL 5: an unknown schedule status was accepted';
  exception
    when others then
      if sqlstate <> '22023' then raise; end if;
      if sqlerrm not like '%invalid schedule status%' then raise; end if;
  end;

  -- A brand manager reaches every branch, so the scope arm cannot refuse a
  -- branch that does not exist: the existence check answers instead, and it
  -- still refuses the write.
  begin
    perform public.admin_hr_save_schedule(
      '6d000000-0000-4000-8000-000000000004', '4e900000-0000-4000-8000-000000000009',
      '2026-11-04T08:00:00Z', '2026-11-04T16:00:00Z', 0, 'draft', null, null);
    raise exception 'FAIL 5: a schedule was written for a branch that does not exist';
  exception
    when others then
      if sqlstate <> 'P0002' then raise; end if;
      if sqlerrm not like '%branch not found or inactive%' then raise; end if;
  end;

  -- The same person, a later window: the overlap check is a window test, not a
  -- per-day limit.
  v := public.admin_hr_save_schedule(
    '6d000000-0000-4000-8000-000000000004', '4e100000-0000-4000-8000-000000000001',
    '2026-11-03T20:00:00Z', '2026-11-03T22:00:00Z', 0, 'draft', null, null);
  if v is null then
    raise exception 'FAIL 5: a non-overlapping schedule for the same day was refused';
  end if;
end $$;

-- Cancelling frees the window again.
do $$
declare v jsonb;
begin
  v := public.admin_hr_set_schedule_status(
    current_setting('test.schedule')::uuid, 'cancelled');
  if v is null or (v ->> 'status') <> 'cancelled' then
    raise exception 'FAIL 5: cancelling the published schedule returned %', v;
  end if;

  -- The exact window that overlapped before is now free: the guard excludes
  -- cancelled rows instead of leaving a cancelled shift blocking the person.
  v := public.admin_hr_save_schedule(
    '6d000000-0000-4000-8000-000000000004', '4e100000-0000-4000-8000-000000000001',
    '2026-11-03T09:00:00Z', '2026-11-03T17:00:00Z', 60, 'published', 'مناوبة بديلة', null);
  if v is null then
    raise exception 'FAIL 5: the window of a cancelled schedule stayed blocked';
  end if;
end $$;

-- ===========================================================================
-- 6. Compensation is effective-dated: one start per date, no backdating.
-- ===========================================================================
do $$
declare v jsonb;
begin
  begin
    perform public.admin_hr_set_compensation(
      '6d000000-0000-4000-8000-000000000004', -1, 0, 0, 0, '2026-01-01', null);
    raise exception 'FAIL 6: a negative basic salary was accepted';
  exception
    when others then
      if sqlstate <> '22023' then raise; end if;
      if sqlerrm not like '%invalid basic salary%' then raise; end if;
  end;
  begin
    perform public.admin_hr_set_compensation(
      '6d000000-0000-4000-8000-000000000004', 5000, -100, 0, 0, '2026-01-01', null);
    raise exception 'FAIL 6: a negative allowance was accepted';
  exception
    when others then
      if sqlstate <> '22023' then raise; end if;
      if sqlerrm not like '%allowances cannot be negative%' then raise; end if;
  end;

  v := public.admin_hr_set_compensation(
    '6d000000-0000-4000-8000-000000000004', 5000, 1000, 500, 0, '2026-01-01', 'راتب البداية');
  if v is null or (v ->> 'basic_salary')::numeric <> 5000 then
    raise exception 'FAIL 6: the first salary record did not land';
  end if;

  begin
    perform public.admin_hr_set_compensation(
      '6d000000-0000-4000-8000-000000000004', 5200, 0, 0, 0, '2026-01-01', null);
    raise exception 'FAIL 6: two salary records start on the same date';
  exception
    when others then
      if sqlstate <> '23505' then raise; end if;
      if sqlerrm not like '%already starts on this date%' then raise; end if;
  end;

  -- A later date closes the open-ended record instead of overlapping it.
  v := public.admin_hr_set_compensation(
    '6d000000-0000-4000-8000-000000000004', 5000, 1000, 500, 0, '2026-06-01', 'بدون تغيير');
  if v is null then
    raise exception 'FAIL 6: the mid-year salary record did not land';
  end if;

  begin
    perform public.admin_hr_set_compensation(
      '6d000000-0000-4000-8000-000000000004', 6000, 0, 0, 0, '2026-03-01', 'تراجع');
    raise exception 'FAIL 6: a salary record was backdated behind a later one';
  exception
    when others then
      if sqlstate <> '22023' then raise; end if;
      if sqlerrm not like '%cannot backdate before a later compensation record%' then raise; end if;
  end;
end $$;

reset role;
do $$
begin
  if (select count(*) from hr.compensations where staff_id = '6d000000-0000-4000-8000-000000000004') <> 2 then
    raise exception 'FAIL 6: the salary history is not two records';
  end if;
  if (select effective_to from hr.compensations
       where staff_id = '6d000000-0000-4000-8000-000000000004' and effective_from = '2026-01-01')
     <> date '2026-05-31' then
    raise exception 'FAIL 6: the new record did not close the one it replaces';
  end if;
  -- Gross stays 6500 through every period this test generates.
  if (select basic_salary + housing_allowance + transport_allowance + other_allowance
        from hr.compensations
       where staff_id = '6d000000-0000-4000-8000-000000000004' and effective_from = '2026-06-01') <> 6500 then
    raise exception 'FAIL 6: the gross used by the arithmetic below is not 6500';
  end if;
end $$;

set local role authenticated;

-- ===========================================================================
-- 7. An advance moves money only through request, cross-review and disbursement.
-- ===========================================================================
select set_config('request.jwt.claims',
  '{"sub":"5d000000-0000-4000-8000-000000000004","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v jsonb;
begin
  begin
    perform public.hr_request_advance(0, null, 'سبب');
    raise exception 'FAIL 7: a zero advance request was accepted';
  exception
    when others then
      if sqlstate <> '22023' then raise; end if;
      if sqlerrm not like '%advance amount must be positive%' then raise; end if;
  end;
  begin
    perform public.hr_request_advance(1200, null, '   ');
    raise exception 'FAIL 7: an advance without a reason was accepted';
  exception
    when others then
      if sqlstate <> '22023' then raise; end if;
      if sqlerrm not like '%needs a reason%' then raise; end if;
  end;
  begin
    perform public.hr_request_advance(1200, 5000, 'سبب');
    raise exception 'FAIL 7: an installment larger than the advance was accepted';
  exception
    when others then
      if sqlstate <> '22023' then raise; end if;
      if sqlerrm not like '%installment must be positive and no larger%' then raise; end if;
  end;

  v := public.hr_request_advance(1200, 300, 'ظرف عائلي');
  if v is null or (v ->> 'status') <> 'pending' then
    raise exception 'FAIL 7: the advance request did not open as pending';
  end if;
  perform set_config('test.advance', v ->> 'id', true);

  begin
    perform public.hr_request_advance(600, null, 'طلب ثانٍ');
    raise exception 'FAIL 7: a second open advance request was accepted';
  exception
    when others then
      if sqlstate <> '23505' then raise; end if;
      if sqlerrm not like '%advance request is already open%' then raise; end if;
  end;

  -- The requester holds no finance code: their own request cannot be reviewed
  -- by them, and the refusal names the code first.
  begin
    perform public.admin_hr_review_advance(current_setting('test.advance')::uuid, true, null, null);
    raise exception 'FAIL 7: a cashier reviewed an advance';
  exception
    when others then
      if sqlstate <> '42501' then raise; end if;
      if sqlerrm not like '%missing permission: hr.finance.adjust%' then raise; end if;
  end;
end $$;

-- A manager may review someone else's request; their own is refused.
select set_config('request.jwt.claims',
  '{"sub":"5d000000-0000-4000-8000-000000000002","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v jsonb;
begin
  begin
    perform public.admin_hr_review_advance(current_setting('test.advance')::uuid, true, 9999, 'سقف خاطئ');
    raise exception 'FAIL 7: an installment above the outstanding amount was approved';
  exception
    when others then
      if sqlstate <> '22023' then raise; end if;
      if sqlerrm not like '%installment must be positive and no larger than the outstanding%' then raise; end if;
  end;

  v := public.admin_hr_review_advance(current_setting('test.advance')::uuid, true, 300, 'معتمد');
  if v is null or (v ->> 'status') <> 'approved' then
    raise exception 'FAIL 7: the advance was not approved';
  end if;

  -- Approved, not yet paid out: disbursing is a separate, audited step.
  v := public.admin_hr_disburse_advance(current_setting('test.advance')::uuid, 'سلّمت نقدًا');
  if v is null then
    raise exception 'FAIL 7: the approved advance could not be disbursed';
  end if;
  begin
    perform public.admin_hr_disburse_advance(current_setting('test.advance')::uuid, 'مرة أخرى');
    raise exception 'FAIL 7: a disbursed advance was disbursed again';
  exception
    when others then
      if sqlstate <> '23514' then raise; end if;
      if sqlerrm not like '%only an approved advance can be disbursed%' then raise; end if;
  end;

  -- The manager's own request, reviewed by the manager: refused even though they
  -- hold the code.
  v := public.hr_request_advance(900, null, 'طلب المدير');
  perform set_config('test.advance2', v ->> 'id', true);
  begin
    perform public.admin_hr_review_advance(current_setting('test.advance2')::uuid, true, null, 'ذاتي');
    raise exception 'FAIL 7: a manager approved their own advance request';
  exception
    when others then
      if sqlstate <> '42501' then raise; end if;
      if sqlerrm not like '%cannot review your own advance request%' then raise; end if;
  end;
end $$;

-- August sees exactly one deduction: the installment of the disbursed advance.
do $$
declare v jsonb;
begin
  begin
    perform public.admin_hr_generate_payroll(1999, 1);
    raise exception 'FAIL 7: a payroll year of 1999 was accepted';
  exception
    when others then
      if sqlstate <> '22023' then raise; end if;
      if sqlerrm not like '%invalid payroll year%' then raise; end if;
  end;
  begin
    perform public.admin_hr_generate_payroll(2026, 13);
    raise exception 'FAIL 7: a payroll month of 13 was accepted';
  exception
    when others then
      if sqlstate <> '22023' then raise; end if;
      if sqlerrm not like '%invalid payroll month%' then raise; end if;
  end;
  begin
    perform public.admin_hr_generate_payroll(2026, 12);
    raise exception 'FAIL 7: a period that has not started was calculated';
  exception
    when others then
      if sqlstate <> '22023' then raise; end if;
      if sqlerrm not like '%has not started yet%' then raise; end if;
  end;

  v := public.admin_hr_generate_payroll(2026, 8, 'احتساب أغسطس');
  if v is null or (v ->> 'status') <> 'calculated' then
    raise exception 'FAIL 7: the August run did not calculate';
  end if;
  if (v ->> 'statement_count')::int <> 1 then
    raise exception 'FAIL 7: August pays % employees, expected only the cashier with a salary',
      v ->> 'statement_count';
  end if;
  if (v ->> 'total_deductions')::numeric <> 300 or (v ->> 'total_net')::numeric <> 6200 then
    raise exception 'FAIL 7: August is net % with deductions %; expected 6200 / 300',
      v ->> 'total_net', v ->> 'total_deductions';
  end if;
  perform set_config('test.run8', v ->> 'run_id', true);
end $$;

-- The run itself is approved by the role that holds the code, never the
-- calculator: this one did not calculate it.
select set_config('request.jwt.claims',
  '{"sub":"5d000000-0000-4000-8000-000000000006","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v jsonb;
begin
  v := public.admin_hr_approve_payroll(current_setting('test.run8')::uuid, 'اعتماد أغسطس');
  if v is null or (v ->> 'status') <> 'approved' then
    raise exception 'FAIL 7: the August run was not approved';
  end if;
  v := public.admin_hr_pay_payroll(current_setting('test.run8')::uuid, 'صُرف');
  if v is null or (v ->> 'status') <> 'paid' then
    raise exception 'FAIL 7: the approved August run was not marked paid';
  end if;
end $$;

reset role;
do $$
declare v hr.salary_advances%rowtype;
begin
  select * into v from hr.salary_advances where id = current_setting('test.advance')::uuid;
  if v.status <> 'disbursed' or v.settled_amount <> 300 or round(v.amount - v.settled_amount, 2) <> 900 then
    raise exception 'FAIL 7: approving August settled the advance as % / % of %',
      v.status, v.settled_amount, v.amount;
  end if;
  if (select count(*) from hr.payroll_line_items where payroll_run_id = current_setting('test.run8')::uuid
        and source_type = 'salary_advance') <> 1 then
    raise exception 'FAIL 7: the August run has no advance line to settle from';
  end if;
  if (select count(*) from hr.payroll_line_items where payroll_run_id = current_setting('test.run8')::uuid
        and kind = 'deduction' and source_type = 'adjustment') <> 0 then
    raise exception 'FAIL 7: August deducted an adjustment that no one approved';
  end if;
end $$;

set local role authenticated;

-- ===========================================================================
-- 8. September: an adjustment is money only once a second person approved it.
-- ===========================================================================
select set_config('request.jwt.claims',
  '{"sub":"5d000000-0000-4000-8000-000000000002","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v jsonb;
begin
  begin
    perform public.admin_hr_create_adjustment(null, 'deduction', 500, 'سبب', '2026-09-15', null);
    raise exception 'FAIL 8: an adjustment with no employee was accepted';
  exception
    when others then
      if sqlstate <> '22023' then raise; end if;
      if sqlerrm not like '%staff member is required%' then raise; end if;
  end;
  begin
    perform public.admin_hr_create_adjustment(
      '6d000000-0000-4000-8000-000000000004', 'discount', 500, 'سبب', '2026-09-15', null);
    raise exception 'FAIL 8: an unknown adjustment kind was accepted';
  exception
    when others then
      if sqlstate <> '22023' then raise; end if;
      if sqlerrm not like '%invalid adjustment kind%' then raise; end if;
  end;
  begin
    perform public.admin_hr_create_adjustment(
      '6d000000-0000-4000-8000-000000000004', 'deduction', 0, 'سبب', '2026-09-15', null);
    raise exception 'FAIL 8: an adjustment of zero was accepted';
  exception
    when others then
      if sqlstate <> '22023' then raise; end if;
      if sqlerrm not like '%adjustment amount must be positive%' then raise; end if;
  end;
  begin
    perform public.admin_hr_create_adjustment(
      '6d000000-0000-4000-8000-000000000004', 'deduction', 500, '  ', '2026-09-15', null);
    raise exception 'FAIL 8: an adjustment without a reason was accepted';
  exception
    when others then
      if sqlstate <> '22023' then raise; end if;
      if sqlerrm not like '%adjustment needs a reason%' then raise; end if;
  end;
  begin
    perform public.admin_hr_create_adjustment(
      '6d000000-0000-4000-8000-000000000004', 'overtime', 200, 'ساعات', '2026-09-15', -2);
    raise exception 'FAIL 8: a negative quantity was accepted';
  exception
    when others then
      if sqlstate <> '22023' then raise; end if;
      if sqlerrm not like '%quantity must be positive%' then raise; end if;
  end;

  v := public.admin_hr_create_adjustment(
    '6d000000-0000-4000-8000-000000000004', 'deduction', 500, 'خصم مخالفة', '2026-09-15', null);
  if v is null or (v ->> 'status') <> 'pending' then
    raise exception 'FAIL 8: the adjustment did not open as pending';
  end if;
  perform set_config('test.adjustment', v ->> 'id', true);

  -- The requester cannot approve their own decision. This is the rule that stops
  -- a shortage or a penalty from being booked by the person who wrote it.
  begin
    perform public.admin_hr_review_adjustment(current_setting('test.adjustment')::uuid, true, 'أوافق');
    raise exception 'FAIL 8: a manager approved their own adjustment';
  exception
    when others then
      if sqlstate <> '42501' then raise; end if;
      if sqlerrm not like '%cannot approve your own adjustment%' then raise; end if;
  end;

  -- And while it is pending, the money does not move.
  v := public.admin_hr_generate_payroll(2026, 9, 'قبل الاعتماد');
  if (v ->> 'total_deductions')::numeric <> 300 then
    raise exception 'FAIL 8: September deducted % before the adjustment was approved; only the 300 advance installment is allowed',
      v ->> 'total_deductions';
  end if;
  if (v ->> 'total_net')::numeric <> 6200 then
    raise exception 'FAIL 8: an unapproved adjustment changed the net to %', v ->> 'total_net';
  end if;
  perform set_config('test.run9', v ->> 'run_id', true);
end $$;

reset role;
do $$
declare
  v_run uuid := current_setting('test.run9')::uuid;
  v_adj uuid := current_setting('test.adjustment')::uuid;
begin
  if (select count(*) from hr.payroll_line_items l
        where l.payroll_run_id = v_run and l.source_type = 'adjustment') <> 0 then
    raise exception 'FAIL 8: a pending adjustment was written into the payslip';
  end if;
  if (select payroll_run_id from hr.adjustments where id = v_adj) is not null then
    raise exception 'FAIL 8: a pending adjustment was claimed by a payroll run';
  end if;
end $$;

-- A second person approves it, and only then does September change.
select set_config('request.jwt.claims',
  '{"sub":"5d000000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v jsonb;
begin
  v := public.admin_hr_review_adjustment(current_setting('test.adjustment')::uuid, true, 'معتمد بعد المراجعة');
  if v is null or (v ->> 'status') <> 'approved' then
    raise exception 'FAIL 8: the owner could not approve the pending adjustment';
  end if;
end $$;

select set_config('request.jwt.claims',
  '{"sub":"5d000000-0000-4000-8000-000000000002","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v jsonb;
begin
  v := public.admin_hr_generate_payroll(2026, 9, 'بعد الاعتماد');
  if (v ->> 'total_deductions')::numeric <> 800 or (v ->> 'total_net')::numeric <> 5700 then
    raise exception 'FAIL 8: September after approval is net % with deductions %; expected 5700 / 800',
      v ->> 'total_net', v ->> 'total_deductions';
  end if;
  if (v ->> 'run_id') <> current_setting('test.run9') then
    raise exception 'FAIL 8: recalculating a period opened a second run instead of replacing it';
  end if;

  -- Calculating, approving and paying are three hands. The manager holds every
  -- hr code except these two.
  begin
    perform public.admin_hr_approve_payroll(current_setting('test.run9')::uuid, 'سأعتمد');
    raise exception 'FAIL 8: a manager approved a payroll run';
  exception
    when others then
      if sqlstate <> '42501' then raise; end if;
      if sqlerrm not like '%missing permission: hr.payroll.approve%' then raise; end if;
  end;
  begin
    perform public.admin_hr_pay_payroll(current_setting('test.run9')::uuid, 'سأصرف');
    raise exception 'FAIL 8: a manager marked a payroll run paid';
  exception
    when others then
      if sqlstate <> '42501' then raise; end if;
      if sqlerrm not like '%missing permission: hr.payroll.pay%' then raise; end if;
  end;

  -- A run that was only calculated cannot be paid.
  perform set_config('request.jwt.claims',
    '{"sub":"5d000000-0000-4000-8000-000000000006","role":"authenticated","aud":"authenticated"}', true);
  begin
    perform public.admin_hr_pay_payroll(current_setting('test.run9')::uuid, 'بلا اعتماد');
    raise exception 'FAIL 8: a calculated run was marked paid';
  exception
    when others then
      if sqlstate <> '23514' then raise; end if;
      if sqlerrm not like '%only an approved run can be marked paid%' then raise; end if;
  end;

  v := public.admin_hr_approve_payroll(current_setting('test.run9')::uuid, 'معتمد');
  if v is null or (v ->> 'status') <> 'approved' then
    raise exception 'FAIL 8: the approver role could not approve a calculated run';
  end if;

  -- Once a run snapshots an adjustment, reversing that adjustment would rewrite
  -- a paid payslip, so the answer is a correction instead.
  perform set_config('request.jwt.claims',
    '{"sub":"5d000000-0000-4000-8000-000000000002","role":"authenticated","aud":"authenticated"}', true);
  begin
    perform public.admin_hr_reverse_adjustment(current_setting('test.adjustment')::uuid, 'خطأ');
    raise exception 'FAIL 8: an adjustment inside a payroll snapshot was reversed';
  exception
    when others then
      if sqlstate <> '23514' then raise; end if;
      if sqlerrm not like '%already in a payroll snapshot; create a correction%' then raise; end if;
  end;

  -- And the period itself is closed for recalculation.
  begin
    perform public.admin_hr_generate_payroll(2026, 9, 'إعادة');
    raise exception 'FAIL 8: an approved period was recalculated';
  exception
    when others then
      if sqlstate <> '23514' then raise; end if;
      if sqlerrm not like '%already approved; use a correction%' then raise; end if;
  end;
end $$;

-- All-branch scope is a second requirement, not a courtesy: a manager tied to one
-- branch holds hr.payroll.manage and is still refused.
select set_config('request.jwt.claims',
  '{"sub":"5d000000-0000-4000-8000-000000000003","role":"authenticated","aud":"authenticated"}', true);

do $$
begin
  begin
    perform public.admin_hr_generate_payroll(2026, 7);
    raise exception 'FAIL 8: a branch-scoped manager calculated a brand payroll run';
  exception
    when others then
      if sqlstate <> '42501' then raise; end if;
      if sqlerrm not like '%need all-branch scope%' then raise; end if;
  end;
end $$;

-- Reversing without a reason is refused before any row is read.
select set_config('request.jwt.claims',
  '{"sub":"5d000000-0000-4000-8000-000000000002","role":"authenticated","aud":"authenticated"}', true);

do $$
begin
  begin
    perform public.admin_hr_reverse_adjustment(current_setting('test.adjustment')::uuid, '   ');
    raise exception 'FAIL 8: a reversal without a reason was accepted';
  exception
    when others then
      if sqlstate <> '22023' then raise; end if;
      if sqlerrm not like '%a reversal needs a reason%' then raise; end if;
  end;
  begin
    perform public.admin_hr_reverse_adjustment(extensions.gen_random_uuid(), 'غير موجود');
    raise exception 'FAIL 8: an unknown adjustment was reversed';
  exception
    when others then
      if sqlstate <> 'P0002' then raise; end if;
      if sqlerrm not like '%adjustment not found%' then raise; end if;
  end;
end $$;

-- ===========================================================================
-- 9. A drawer variance opens a review, and only a review can open a deduction.
-- ===========================================================================
reset role;
update payments.pos_shifts
   set status = 'closed',
       closed_by = '6d000000-0000-4000-8000-000000000001',
       closed_at = '2026-10-28T23:00:00Z',
       cash_sales = 0, card_sales = 0, sales_total = 0, order_count = 0,
       cash_in_total = 0, cash_out_total = 0,
       expected_cash = 100.00, counted_cash = 50.00, variance = -50.00,
       close_note = 'counted short'
 where id = '7e000000-0000-4000-8000-000000000001';

do $$
declare v hr.cashier_discrepancies%rowtype;
begin
  select * into v from hr.cashier_discrepancies
   where shift_id = '7e000000-0000-4000-8000-000000000001';
  if not found then
    raise exception 'FAIL 9: closing a drawer with a -50 variance opened no review record';
  end if;
  if v.status <> 'pending_review' or v.attributed_staff_id is not null
     or v.amount <> 50.00 or v.signed_variance <> -50.00 then
    raise exception 'FAIL 9: the review row is % / attributed % / amount %',
      v.status, v.attributed_staff_id, v.amount;
  end if;
  if v.drawer_cashier_id <> '6d000000-0000-4000-8000-000000000004' then
    raise exception 'FAIL 9: the review row lost who held the drawer';
  end if;
  if exists (select 1 from hr.adjustments a where a.source_type = 'cashier_discrepancy') then
    raise exception 'FAIL 9: the variance alone created a salary deduction';
  end if;
  if (select variance from payments.pos_shifts where id = '7e000000-0000-4000-8000-000000000001') <> -50.00 then
    raise exception 'FAIL 9: the HR capture changed the shift numbers';
  end if;
  perform set_config('test.discrepancy', v.id::text, true);
  -- Zero variance stays nobody's problem.
  if (select count(*) from hr.cashier_discrepancies) <> 1 then
    raise exception 'FAIL 9: the discrepancy table holds more than the one short drawer';
  end if;
end $$;

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"5d000000-0000-4000-8000-000000000003","role":"authenticated","aud":"authenticated"}', true);

-- The branch 2 manager reads the finance ledger but never a branch 1 drawer.
do $$
declare v jsonb;
begin
  v := public.admin_hr_discrepancies(null, null, 20);
  if jsonb_array_length(v) <> 0 then
    raise exception 'FAIL 9: the branch 2 manager saw a branch 1 discrepancy';
  end if;
  begin
    perform public.admin_hr_discrepancies('suspect', null, 20);
    raise exception 'FAIL 9: an unknown discrepancy status was accepted';
  exception
    when others then
      if sqlstate <> '22023' then raise; end if;
      if sqlerrm not like '%invalid discrepancy status%' then raise; end if;
  end;
end $$;

select set_config('request.jwt.claims',
  '{"sub":"5d000000-0000-4000-8000-000000000002","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v jsonb;
begin
  v := public.admin_hr_discrepancies(null, null, 20);
  if jsonb_array_length(v) <> 1 then
    raise exception 'FAIL 9: the brand manager sees % discrepancies, expected 1', jsonb_array_length(v);
  end if;
  if (v -> 0 ->> 'status') <> 'pending_review' then
    raise exception 'FAIL 9: the review row is % in the list', v -> 0 ->> 'status';
  end if;
  if (v -> 0 -> 'deduction_adjustment_id') <> 'null'::jsonb then
    raise exception 'FAIL 9: the list invented a deduction for an unreviewed variance';
  end if;

  -- The order of the decision: nothing is taken before someone names a person
  -- and a reason.
  begin
    perform public.admin_hr_review_discrepancy(
      current_setting('test.discrepancy')::uuid, 'deduct', 'خصم', null, null, 30);
    raise exception 'FAIL 9: a deduction was approved before the variance was confirmed';
  exception
    when others then
      if sqlstate <> '23514' then raise; end if;
      if sqlerrm not like '%confirm the discrepancy before approving a deduction%' then raise; end if;
  end;
  begin
    perform public.admin_hr_review_discrepancy(
      current_setting('test.discrepancy')::uuid, 'confirm', 'نسيت', null, null, null);
    raise exception 'FAIL 9: a variance was confirmed with no one named';
  exception
    when others then
      if sqlstate <> '22023' then raise; end if;
      if sqlerrm not like '%requires naming the responsible employee%' then raise; end if;
  end;
  -- The person named has to work in the branch where the drawer was counted.
  begin
    perform public.admin_hr_review_discrepancy(
      current_setting('test.discrepancy')::uuid, 'confirm', 'نسيت', null,
      '6d000000-0000-4000-8000-000000000005', null);
    raise exception 'FAIL 9: a shortage was attributed to an employee of another branch';
  exception
    when others then
      if sqlstate <> '22023' then raise; end if;
      if sqlerrm not like '%does not work in this branch%' then raise; end if;
  end;
  -- And a reviewer cannot blame themselves and then collect.
  begin
    perform public.admin_hr_review_discrepancy(
      current_setting('test.discrepancy')::uuid, 'confirm', 'خطأي', null,
      '6d000000-0000-4000-8000-000000000002', null);
    raise exception 'FAIL 9: a manager attributed a shortage to themselves';
  exception
    when others then
      if sqlstate <> '42501' then raise; end if;
      if sqlerrm not like '%cannot attribute a shortage to themselves%' then raise; end if;
  end;
  begin
    perform public.admin_hr_review_discrepancy(
      current_setting('test.discrepancy')::uuid, 'unknown_action', null, null, null, null);
    raise exception 'FAIL 9: an unknown discrepancy action was accepted';
  exception
    when others then
      if sqlstate <> '22023' then raise; end if;
      if sqlerrm not like '%unknown discrepancy action%' then raise; end if;
  end;

  v := public.admin_hr_review_discrepancy(
    current_setting('test.discrepancy')::uuid, 'confirm', 'مراجعة الكاميرا والتسوية',
    'شريط 12:40', '6d000000-0000-4000-8000-000000000004', null);
  if v is null or (v ->> 'status') <> 'confirmed' then
    raise exception 'FAIL 9: the variance could not be confirmed against the drawer cashier';
  end if;
end $$;

-- Confirming a variance is a decision about who was responsible, not a money
-- movement. Read with the owner's privileges because the authenticated role has
-- no path to this table at all.
reset role;
do $$
begin
  if exists (select 1 from hr.adjustments a where a.source_type = 'cashier_discrepancy') then
    raise exception 'FAIL 9: confirming a variance created a deduction by itself';
  end if;
  if (select status from hr.cashier_discrepancies
       where id = current_setting('test.discrepancy')::uuid) <> 'confirmed' then
    raise exception 'FAIL 9: the confirmed variance is not stored as confirmed';
  end if;
end $$;

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"5d000000-0000-4000-8000-000000000002","role":"authenticated","aud":"authenticated"}', true);

do $$
begin
  -- Confirmed is still not a permission to take money: the policy switch is off
  -- by default, and stays off until someone with hr.settings.manage turns it on.
  begin
    perform public.admin_hr_review_discrepancy(
      current_setting('test.discrepancy')::uuid, 'deduct', 'خصم 30', null, null, 30);
    raise exception 'FAIL 9: a deduction was taken while the policy switch is off';
  exception
    when others then
      if sqlstate <> '23514' then raise; end if;
      if sqlerrm not like '%cashier deductions are disabled in the HR settings%' then raise; end if;
  end;
end $$;

-- Turning the switch on is itself an audited settings write, and the product
-- will not turn it on over a zero cap: an enabled switch that can never deduct
-- is a decision nobody can read off the payslip.
do $$
declare v jsonb;
begin
  begin
    perform public.admin_hr_update_settings(p_cashier_deduction_allowed := true);
    raise exception 'FAIL 9: the deduction switch turned on over a zero cap';
  exception
    when others then
      if sqlstate <> '22023' then raise; end if;
      if sqlerrm not like '%cashier deductions need a positive cap%' then raise; end if;
  end;

  v := public.admin_hr_update_settings(
    p_cashier_deduction_allowed := true, p_max_salary_deduction_percent := 0.4);
  if v is null or (v ->> 'cashier_deduction_allowed')::boolean is not true then
    raise exception 'FAIL 9: the deduction switch did not turn on';
  end if;
  -- 0.4 percent of the 6500 gross is 26.00: a cap that is real but smaller than
  -- the 30.00 shortage below, so the next payroll run must skip this deduction
  -- rather than silently take a different amount.
  if (v ->> 'max_salary_deduction_percent')::numeric <> 0.4 then
    raise exception 'FAIL 9: the cap did not land at 0.4 percent (%)',
      v ->> 'max_salary_deduction_percent';
  end if;
  begin
    perform public.admin_hr_update_settings(p_max_salary_deduction_percent := 150);
    raise exception 'FAIL 9: a deduction cap above 100 percent was accepted';
  exception
    when others then
      if sqlstate <> '22023' then raise; end if;
  end;

  -- The switch on is not a blank cheque: the amount and the reason still matter.
  begin
    perform public.admin_hr_review_discrepancy(
      current_setting('test.discrepancy')::uuid, 'deduct', null, null, null, 30);
    raise exception 'FAIL 9: a deduction with no note was approved';
  exception
    when others then
      if sqlstate <> '22023' then raise; end if;
      if sqlerrm not like '%needs a note explaining the decision%' then raise; end if;
  end;
  begin
    perform public.admin_hr_review_discrepancy(
      current_setting('test.discrepancy')::uuid, 'deduct', 'خصم', null, null, 60);
    raise exception 'FAIL 9: a deduction larger than the shortage was approved';
  exception
    when others then
      if sqlstate <> '22023' then raise; end if;
      if sqlerrm not like '%no larger than the discrepancy%' then raise; end if;
  end;

  v := public.admin_hr_review_discrepancy(
    current_setting('test.discrepancy')::uuid, 'deduct', 'عجز مؤكد بعد المراجعة', null, null, 30);
  if v is null or (v ->> 'status') <> 'deduction_approved' then
    raise exception 'FAIL 9: the approved deduction left the review row at %', v ->> 'status';
  end if;
  if (v ->> 'deduction_adjustment_id') is null then
    raise exception 'FAIL 9: the deduction was not linked back to the review row';
  end if;
  perform set_config('test.shortage', v ->> 'deduction_adjustment_id', true);

  -- One variance, one deduction. The approved deduction moves the review row
  -- out of 'confirmed', so the state guard is what answers a second request;
  -- the source-uniqueness check behind it never has to.
  begin
    perform public.admin_hr_review_discrepancy(
      current_setting('test.discrepancy')::uuid, 'deduct', 'مرة ثانية', null, null, 10);
    raise exception 'FAIL 9: a second deduction was approved for one variance';
  exception
    when others then
      if sqlstate <> '23514' then raise; end if;
      if sqlerrm not like '%confirm the discrepancy before approving a deduction%' then raise; end if;
  end;
end $$;

reset role;
do $$
declare v hr.adjustments%rowtype;
begin
  select * into v from hr.adjustments where id = current_setting('test.shortage')::uuid;
  if not found then
    raise exception 'FAIL 9: the approved deduction has no adjustment row';
  end if;
  if v.kind <> 'deduction' or v.amount <> 30 or v.status <> 'approved'
     or v.source_type <> 'cashier_discrepancy'
     or v.staff_id <> '6d000000-0000-4000-8000-000000000004' then
    raise exception 'FAIL 9: the deduction row is % % % from %', v.kind, v.amount, v.status, v.source_type;
  end if;
  if v.reviewed_by is null or v.reviewed_at is null then
    raise exception 'FAIL 9: a salary deduction was booked without a reviewer';
  end if;
  -- One variance, one deduction row: the state guard above is not the only
  -- thing keeping the ledger clean.
  if (select count(*) from hr.adjustments
       where source_type = 'cashier_discrepancy'
         and source_id = current_setting('test.discrepancy')::uuid) <> 1 then
    raise exception 'FAIL 9: one variance produced % deduction rows',
      (select count(*) from hr.adjustments
        where source_type = 'cashier_discrepancy'
          and source_id = current_setting('test.discrepancy')::uuid);
  end if;
end $$;

-- October: the shortage is approved and the switch is on, but the cap is 0.4
-- percent of a 6500 gross, which is 26.00. An approved deduction the cap cannot
-- cover stays out of the payslip rather than being paid at a smaller amount.
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"5d000000-0000-4000-8000-000000000006","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v jsonb;
begin
  v := public.admin_hr_generate_payroll(2026, 10, 'أكتوبر بسقف ٠٫٤٪');
  if v is null then
    raise exception 'FAIL 9: October did not calculate';
  end if;
  if (v ->> 'total_deductions')::numeric <> 300 then
    raise exception 'FAIL 9: October deducted % under a cap of 26.00; the 30.00 shortage must stay out',
      v ->> 'total_deductions';
  end if;
  if (v ->> 'total_net')::numeric <> 6200 then
    raise exception 'FAIL 9: October net is % with the cap under the shortage, expected 6200',
      v ->> 'total_net';
  end if;
  perform set_config('test.run10', v ->> 'run_id', true);

  -- The calculator of this run holds the approve code and is still refused.
  begin
    perform public.admin_hr_approve_payroll(current_setting('test.run10')::uuid, 'أنا احتسبتها');
    raise exception 'FAIL 9: the person who calculated a run approved it';
  exception
    when others then
      if sqlstate <> '42501' then raise; end if;
      if sqlerrm not like '%the person who calculated this run cannot approve it%' then raise; end if;
  end;
end $$;

reset role;
do $$
begin
  if (select payroll_run_id from hr.adjustments where id = current_setting('test.shortage')::uuid) is not null then
    raise exception 'FAIL 9: a cap below the shortage still let it into a payslip';
  end if;
end $$;

-- A cap that covers the shortage, and the same approved row is finally taken.
select set_config('request.jwt.claims',
  '{"sub":"5d000000-0000-4000-8000-000000000002","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v jsonb;
begin
  v := public.admin_hr_update_settings(p_max_salary_deduction_percent := 5);
  if (v ->> 'max_salary_deduction_percent')::numeric <> 5 then
    raise exception 'FAIL 9: the cap did not become 5 percent';
  end if;

  perform set_config('request.jwt.claims',
    '{"sub":"5d000000-0000-4000-8000-000000000006","role":"authenticated","aud":"authenticated"}', true);
  v := public.admin_hr_generate_payroll(2026, 10, 'أكتوبر بسقف ٥٪');
  if (v ->> 'total_deductions')::numeric <> 330 or (v ->> 'total_net')::numeric <> 6170 then
    raise exception 'FAIL 9: October with a 5 percent cap is net % and deductions %; expected 6170 / 330',
      v ->> 'total_net', v ->> 'total_deductions';
  end if;
  if (v ->> 'run_id') <> current_setting('test.run10') then
    raise exception 'FAIL 9: recalculating October opened a second run';
  end if;
end $$;

reset role;
do $$
declare v jsonb;
begin
  if (select payroll_run_id from hr.adjustments where id = current_setting('test.shortage')::uuid)
     is distinct from current_setting('test.run10')::uuid then
    raise exception 'FAIL 9: the shortage with a real cap was not claimed by October';
  end if;
  select jsonb_build_object(
    'categories', coalesce((select jsonb_agg(l.category order by l.category)
                              from hr.payroll_line_items l
                             where l.payroll_run_id = current_setting('test.run10')::uuid), '[]'::jsonb),
    'kinds', coalesce((select jsonb_agg(distinct l.kind order by l.kind)
                         from hr.payroll_line_items l
                        where l.payroll_run_id = current_setting('test.run10')::uuid), '[]'::jsonb)
  ) into v;
  if v -> 'categories' ? 'cashier_shortage' is not true then
    raise exception 'FAIL 9: October payslip lines are %, with no cashier_shortage', v -> 'categories';
  end if;
  if v -> 'categories' ? 'advance' is not true then
    raise exception 'FAIL 9: October payslip lines lost the advance installment: %', v -> 'categories';
  end if;
end $$;

-- October is approved by someone who did not calculate it, and paid.
select set_config('request.jwt.claims',
  '{"sub":"5d000000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v jsonb;
begin
  v := public.admin_hr_approve_payroll(current_setting('test.run10')::uuid, 'اعتماد المالك');
  if v is null or (v ->> 'status') <> 'approved' then
    raise exception 'FAIL 9: the owner could not approve the October run';
  end if;
  v := public.admin_hr_pay_payroll(current_setting('test.run10')::uuid, 'صُرف أكتوبر');
  if v is null or (v ->> 'status') <> 'paid' then
    raise exception 'FAIL 9: the approved October run was not marked paid';
  end if;
  -- A paid run is a receipt, not a draft.
  begin
    perform public.admin_hr_approve_payroll(current_setting('test.run10')::uuid, 'ثانية');
    raise exception 'FAIL 9: a paid run was approved again';
  exception
    when others then
      if sqlstate <> '23514' then raise; end if;
      if sqlerrm not like '%only a calculated run can be approved%' then raise; end if;
  end;
end $$;

-- ===========================================================================
-- 10. Leave: a balance first, a second reviewer always.
-- ===========================================================================
select set_config('request.jwt.claims',
  '{"sub":"5d000000-0000-4000-8000-000000000004","role":"authenticated","aud":"authenticated"}', true);

do $$
begin
  -- A tracking type with no entitlement for the year is a refused request, not a
  -- zero-day answer.
  begin
    perform public.hr_request_leave(current_setting('test.annual')::uuid,
                                    '2026-12-01', '2026-12-02', 'سفر', null);
    raise exception 'FAIL 10: leave was granted against an unconfigured balance';
  exception
    when others then
      if sqlstate <> '22023' then raise; end if;
      if sqlerrm not like '%balance is not configured for this year%' then raise; end if;
  end;
  begin
    perform public.hr_request_leave(current_setting('test.annual')::uuid,
                                    '2026-12-05', '2026-12-01', 'تواريخ', null);
    raise exception 'FAIL 10: leave ending before it starts was accepted';
  exception
    when others then
      if sqlstate <> '22023' then raise; end if;
      if sqlerrm not like '%invalid leave dates%' then raise; end if;
  end;
  begin
    perform public.hr_request_leave(extensions.gen_random_uuid(),
                                    '2026-12-01', '2026-12-02', 'نوع', null);
    raise exception 'FAIL 10: an unknown leave type was accepted';
  exception
    when others then
      if sqlstate <> 'P0002' then raise; end if;
      if sqlerrm not like '%leave type not found%' then raise; end if;
  end;
end $$;

-- The reviewer sets the entitlement; they cannot approve their own request.
select set_config('request.jwt.claims',
  '{"sub":"5d000000-0000-4000-8000-000000000002","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v jsonb;
begin
  begin
    perform public.admin_hr_set_leave_balance(
      '6d000000-0000-4000-8000-000000000004', current_setting('test.annual')::uuid, 1999, 20);
    raise exception 'FAIL 10: a balance was set for an impossible year';
  exception
    when others then
      if sqlstate <> '22023' then raise; end if;
      if sqlerrm not like '%invalid leave year%' then raise; end if;
  end;
  -- The sick type does not track a balance, so it has none to set.
  begin
    perform public.admin_hr_set_leave_balance(
      '6d000000-0000-4000-8000-000000000004', current_setting('test.sick')::uuid, 2026, 5);
    raise exception 'FAIL 10: an entitlement was set on a type that does not track one';
  exception
    when others then
      if sqlstate <> '22023' then raise; end if;
  end;

  v := public.admin_hr_set_leave_balance(
    '6d000000-0000-4000-8000-000000000004', current_setting('test.annual')::uuid, 2026, 20);
  if v is null or (v ->> 'remaining_days')::numeric <> 20 then
    raise exception 'FAIL 10: the annual entitlement did not land';
  end if;
end $$;

select set_config('request.jwt.claims',
  '{"sub":"5d000000-0000-4000-8000-000000000004","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v jsonb;
begin
  begin
    perform public.hr_request_leave(current_setting('test.annual')::uuid,
                                    '2026-12-01', '2026-12-30', 'شهر كامل', null);
    raise exception 'FAIL 10: leave longer than the balance was requested';
  exception
    when others then
      if sqlstate <> '22023' then raise; end if;
      if sqlerrm not like '%insufficient leave balance%' then raise; end if;
  end;
  -- A type that needs a document refuses the request, not the approval.
  begin
    perform public.hr_request_leave(current_setting('test.sick')::uuid,
                                    '2026-11-01', '2026-11-02', 'مرض', null);
    raise exception 'FAIL 10: sick leave without a document was accepted';
  exception
    when others then
      if sqlstate <> '22023' then raise; end if;
      if sqlerrm not like '%requires a supporting document%' then raise; end if;
  end;

  v := public.hr_request_leave(current_setting('test.annual')::uuid,
                               '2026-12-01', '2026-12-02', 'سفر', null);
  if v is null or (v ->> 'status') <> 'pending' or (v ->> 'days')::int <> 2 then
    raise exception 'FAIL 10: the two-day request did not open as pending';
  end if;
  perform set_config('test.leave', v ->> 'id', true);

  begin
    perform public.hr_request_leave(current_setting('test.annual')::uuid,
                                    '2026-12-02', '2026-12-03', 'تداخل', null);
    raise exception 'FAIL 10: an overlapping leave request was accepted';
  exception
    when others then
      if sqlstate <> '23505' then raise; end if;
      if sqlerrm not like '%overlapping leave request%' then raise; end if;
  end;
end $$;

-- The requester cannot approve their own leave, whoever they are.
select set_config('request.jwt.claims',
  '{"sub":"5d000000-0000-4000-8000-000000000002","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v jsonb;
begin
  -- The reviewer needs an entitlement of their own before they can stand in
  -- the requester's seat; the product refuses a request with no balance.
  v := public.admin_hr_set_leave_balance(
    '6d000000-0000-4000-8000-000000000002', current_setting('test.annual')::uuid, 2026, 20);
  if v is null then
    raise exception 'FAIL 10: the reviewer entitlement did not land';
  end if;

  v := public.hr_request_leave(current_setting('test.annual')::uuid,
                               '2026-12-10', '2026-12-11', 'إجازة المدير', null);
  begin
    perform public.admin_hr_review_leave((v ->> 'id')::uuid, true, 'أوافق');
    raise exception 'FAIL 10: a manager approved their own leave request';
  exception
    when others then
      if sqlstate <> '42501' then raise; end if;
      if sqlerrm not like '%cannot approve your own leave request%' then raise; end if;
  end;
  -- The manager may, however, approve the cashier's two days: the balance pays.
  v := public.admin_hr_review_leave(current_setting('test.leave')::uuid, true, 'معتمد');
  if v is null or (v ->> 'status') <> 'approved' or (v ->> 'days')::int <> 2 then
    raise exception 'FAIL 10: the leave request was not approved';
  end if;
  begin
    perform public.admin_hr_review_leave(current_setting('test.leave')::uuid, false, 'ثانية');
    raise exception 'FAIL 10: an approved leave request was reviewed again';
  exception
    when others then
      if sqlstate <> '23514' then raise; end if;
      if sqlerrm not like '%already reviewed%' then raise; end if;
  end;
end $$;

reset role;
do $$
declare v hr.leave_balances%rowtype;
begin
  select * into v from hr.leave_balances
   where staff_id = '6d000000-0000-4000-8000-000000000004'
     and leave_type_id = current_setting('test.annual')::uuid
     and year = 2026;
  if v.used_days <> 2 or v.entitled_days <> 20 then
    raise exception 'FAIL 10: the approved leave left the balance at % of %', v.used_days, v.entitled_days;
  end if;
end $$;

-- ===========================================================================
-- 11. Every decision above is written down, and the money ones are critical.
-- ===========================================================================
select set_config('request.jwt.claims',
  '{"sub":"5d000000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);

reset role;
do $$
declare
  v_actions text[] := array[
    'hr.attendance.clock_in', 'hr.attendance.correction.approve',
    'hr.schedule.create', 'hr.compensation.save', 'hr.advance.request',
    'hr.advance.approve', 'hr.advance.disburse', 'hr.adjustment.create',
    'hr.adjustment.approve', 'hr.payroll.calculate', 'hr.payroll.approve',
    'hr.payroll.pay', 'hr.discrepancy.confirm', 'hr.discrepancy.deduct',
    'hr.leave.request', 'hr.leave.approve', 'hr.settings.update'
  ];
  a text;
  v_missing text := '';
begin
  foreach a in array v_actions loop
    if not exists (select 1 from identity.audit_log au where au.action = a) then
      v_missing := v_missing || a || ', ';
    end if;
  end loop;
  if v_missing <> '' then
    raise exception 'FAIL 11: no audit row for %', rtrim(v_missing, ', ');
  end if;
  -- The client marks these red without a code change.
  if not identity.audit_is_critical('hr.payroll.approve')
     or not identity.audit_is_critical('hr.adjustment.approve')
     or not identity.audit_is_critical('hr.discrepancy.deduct')
     or not identity.audit_is_critical('hr.leave.balance.set') then
    raise exception 'FAIL 11: an HR money action is not treated as critical';
  end if;
  if identity.audit_is_critical('hr.attendance.clock_in') then
    raise exception 'FAIL 11: clocking in was flagged as a critical action';
  end if;
  -- A deduction booked from a variance is never attributed to an anonymous hand.
  if exists (
    select 1 from hr.adjustments where source_type = 'cashier_discrepancy'
      and (reviewed_by is null or reviewed_at is null)
  ) then
    raise exception 'FAIL 11: a shortage deduction exists without a reviewer';
  end if;
end $$;

-- The report a runner prints. Everything above raises on the first mismatch, so
-- reaching this row is itself the proof, and the rollback keeps none of it.
select
  'reached the end: no assertion failed' as verdict,
  (select count(*) from hr.employment_records) as employment_files,
  (select count(*) from hr.work_schedules) as schedules,
  (select count(*) from hr.attendance_sessions) as sessions,
  (select count(*) from hr.attendance_corrections) as corrections,
  (select count(*) from hr.leave_requests) as leave_requests,
  (select string_agg(status || ' ' || period_month::text, ' / ' order by period_month)
     from hr.payroll_runs) as runs,
  (select string_agg(staff_name, ', ') from (
     select sm.full_name as staff_name from hr.salary_advances a
       join identity.staff_members sm on sm.id = a.staff_id
      group by sm.full_name) s) as advance_people,
  (select string_agg(kind || ' ' || amount::text || ' ' || status, ', ' order by created_at)
     from hr.adjustments) as adjustments,
  (select status || ' / attributed ' || coalesce(attributed_staff_id::text, 'nobody')
     from hr.cashier_discrepancies limit 1) as discrepancy,
  (select variance::text from payments.pos_shifts
    where id = '7e000000-0000-4000-8000-000000000001') as shift_variance_kept,
  (select count(*) from identity.audit_log where action like 'hr.%') as hr_audit_rows;

rollback;
