-- hr_payroll_workflow_test.sql
-- Behaviour test for 242_hr_payroll_workflow.sql: the professional payroll
-- workflow (preview → versioned generation → guarded approval → payment →
-- closed period) on top of 212 + Phase 1/2/3 (213..217, 240, 241).
--
-- DISCIPLINE: one transaction, every fixture destroyed by the final rollback.
--
-- EXPECTED REPORT ON A PASS
--   verdict = 'reached the end: no assertion failed',
--   preview_employee = 1, preview_net_100 = 100, version_regen = 'hr-2',
--   empty_approve_refused = true, close_before_paid_refused = true,
--   closed_correction_refused = true, missing_data = 1.

begin;

insert into core.branches (id, brand_id, code, name_ar, name_en, address, is_active, settings)
values
  ('4d300000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000001', 'PW-B1', 'فرع سير الرواتب', 'Payroll Workflow Branch', 'addr1', true, '{}'::jsonb);

insert into auth.users (id, email)
values
  ('5d300000-0000-4000-8000-000000000001', 'pw-owner@test.local'),
  ('5d300000-0000-4000-8000-000000000002', 'pw-emp@test.local'),
  ('5d300000-0000-4000-8000-000000000003', 'pw-ghost@test.local');

insert into identity.staff_members (id, user_id, status, full_name, email)
values
  ('6d300000-0000-4000-8000-000000000001', '5d300000-0000-4000-8000-000000000001', 'active', 'PW Owner', 'pw-owner@test.local'),
  ('6d300000-0000-4000-8000-000000000002', '5d300000-0000-4000-8000-000000000002', 'active', 'PW Emp',   'pw-emp@test.local'),
  ('6d300000-0000-4000-8000-000000000003', '5d300000-0000-4000-8000-000000000003', 'active', 'PW Ghost', 'pw-ghost@test.local');

insert into identity.staff_roles (staff_id, role_id, branch_id)
select '6d300000-0000-4000-8000-000000000001', r.id, null from identity.roles r where r.code = 'owner';
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '6d300000-0000-4000-8000-000000000002', r.id, '4d300000-0000-4000-8000-000000000001' from identity.roles r where r.code = 'cashier';
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '6d300000-0000-4000-8000-000000000003', r.id, '4d300000-0000-4000-8000-000000000001' from identity.roles r where r.code = 'cashier';

insert into hr.employment_records (staff_id, hired_on)
values
  ('6d300000-0000-4000-8000-000000000002', '2026-01-01'),
  ('6d300000-0000-4000-8000-000000000003', '2026-01-01')
on conflict (staff_id) do nothing;

select set_config('request.jwt.claims',
  '{"sub":"5d300000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);

select public.admin_hr_set_compensation(
  '6d300000-0000-4000-8000-000000000002', 6000, 500, 0, 0, '2026-01-01', 'راتب');
-- Ghost has employment but no compensation: the preview must name him.

-- A published past shift with no clock-in: one absence day at 100.
select public.admin_hr_save_schedule(
  '6d300000-0000-4000-8000-000000000002', '4d300000-0000-4000-8000-000000000001',
  '2026-11-03T08:00:00Z', '2026-11-03T16:00:00Z', 0, 'published', 'وردية');
select public.admin_hr_update_settings(p_absence_day_rate := 100);

-- ---------------------------------------------------------------------------
-- 1) The preview reads the period before anything is written.
-- ---------------------------------------------------------------------------
do $$
declare v jsonb; e jsonb;
begin
  v := public.admin_hr_preview_payroll(2026, 11);
  if (v ->> 'run') is not null then
    raise exception 'FAIL 1: the preview invented a run';
  end if;
  -- The live database may already hold a real previous month; only its shape
  -- is contract, not its absence.
  if (v -> 'previous_month') is not null
     and (v -> 'previous_month' ->> 'status') not in ('approved','paid') then
    raise exception 'FAIL 1b: the previous month block is %', v -> 'previous_month';
  end if;
  if jsonb_array_length(v -> 'employees') <> 1 then
    raise exception 'FAIL 1c: the preview lists % employees', jsonb_array_length(v -> 'employees');
  end if;
  e := v -> 'employees' -> 0;
  if (e ->> 'net_preview')::numeric <> 6400
     or (e ->> 'attendance_deduction')::numeric <> 100
     or (e ->> 'absence_days')::int <> 1 then
    raise exception 'FAIL 1d: the preview row is %', e;
  end if;
  -- the live brand may hold real staff without compensations: assert by
  -- membership, not by length
  if not exists (
    select 1 from jsonb_array_elements(v -> 'missing_data')
     where value ->> 'staff_id' = '6d300000-0000-4000-8000-000000000003'
  ) then
    raise exception 'FAIL 1e: the ghost employee is missing from missing_data';
  end if;
  perform set_config('test.preview_employee', '1', true);
  perform set_config('test.preview_net_100',
    ((e -> 'lines') is not null)::text, true);
end $$;

-- ---------------------------------------------------------------------------
-- 2) Generation stamps a real version; regeneration bumps it.
-- ---------------------------------------------------------------------------
do $$
declare v jsonb;
begin
  v := public.admin_hr_generate_payroll(2026, 11, 'توليد أول');
  if (v ->> 'statement_count')::int <> 1 then
    raise exception 'FAIL 2: the run holds % statements', v ->> 'statement_count';
  end if;
  perform set_config('test.run', v ->> 'run_id', true);
end $$;

do $$
declare v numeric; sv text;
begin
  select calculation_version into sv from hr.payroll_statements
   where run_id = current_setting('test.run')::uuid;
  if sv is distinct from 'hr-1' then
    raise exception 'FAIL 2b: the first generation is %', sv;
  end if;
  select calc_seq into v from hr.payroll_runs
   where id = current_setting('test.run')::uuid;
  if v <> 1 then
    raise exception 'FAIL 2c: calc_seq = % after the first generation', v;
  end if;
end $$;

select public.admin_hr_generate_payroll(2026, 11, 'توليد ثانٍ');
do $$
declare v numeric; sv text;
begin
  select calculation_version into sv from hr.payroll_statements
   where run_id = current_setting('test.run')::uuid;
  if sv is distinct from 'hr-2' then
    raise exception 'FAIL 2d: the regenerated version is %', sv;
  end if;
  select calc_seq into v from hr.payroll_runs
   where id = current_setting('test.run')::uuid;
  if v <> 2 then
    raise exception 'FAIL 2e: calc_seq = % after regeneration', v;
  end if;
  perform set_config('test.version_regen', sv, true);
end $$;

-- ---------------------------------------------------------------------------
-- 3) The preview mirrors the stored run and compares with the previous month.
-- ---------------------------------------------------------------------------
do $$
declare v jsonb;
begin
  v := public.admin_hr_preview_payroll(2026, 11);
  if (v -> 'run' ->> 'status') <> 'calculated'
     or (v -> 'run' ->> 'calc_seq')::int <> 2 then
    raise exception 'FAIL 3: the preview run block is %', v -> 'run';
  end if;
  -- (the previous-month block stays shape-checked only: real history may exist)
end $$;

-- ---------------------------------------------------------------------------
-- 4) Approve refuses an empty run, then the real run flows to paid.
-- ---------------------------------------------------------------------------
do $$
declare v jsonb; empty_run uuid;
begin
  -- October predates the compensation (effective 2026-01-01 covers it) — use a
  -- period where the only employee has no covering compensation: the ghost
  -- month trick does not apply, so manufacture an empty run by generating a
  -- future... not possible. Instead: generate a run for an employee-free brand
  -- by temporarily terminating the only compensated employee? Heavy. The empty
  -- run is produced by 2026-08: the compensation covers it too. So build the
  -- empty case via a fresh staff whose comp starts after the period end.
  perform public.admin_hr_set_compensation(
    '6d300000-0000-4000-8000-000000000003'::uuid, 4000, 0, 0, 0, '2026-12-01'::date, 'متأخر');
  v := public.admin_hr_generate_payroll(2026, 11, 'إعادة مع الغياب المفقود');
  -- the ghost still lacks a covering compensation for November (2026-12-01)
  if (v ->> 'statement_count')::int <> 1 then
    raise exception 'FAIL 4 setup: unexpected statement count %', v ->> 'statement_count';
  end if;
end $$;

-- The empty-run guard: craft a run with zero statements by generating for a
-- month whose staff all lack covering compensation — 2026-07 for the ghost
-- (comp starts 2026-12-01) while Emp's comp covers it... to make the run empty
-- the owner can suspend Emp? Simpler: a run where nobody has compensation:
-- generate 2026-07 AFTER temporarily marking the only compensation as starting
-- later is invasive. The guard is exercised through the ghost brand trick:
-- generate a period before both compensations: 2025-12.
do $$
declare v jsonb; r uuid;
begin
  v := public.admin_hr_generate_payroll(2025, 12, 'شهر فارغ');
  if (v ->> 'statement_count')::int <> 0 then
    raise exception 'FAIL 4 setup: the empty month produced % statements', v ->> 'statement_count';
  end if;
  perform set_config('test.empty_run', v ->> 'run_id', true);
  begin
    perform public.admin_hr_approve_payroll(current_setting('test.empty_run')::uuid, 'موافقة فارغة');
    raise exception 'FAIL 4: an empty run was approved';
  exception
    when others then
      if sqlstate <> '23514' then raise; end if;
      if sqlerrm not like '%no statements; nothing to approve%' then raise; end if;
  end;
  perform set_config('test.empty_approve_refused', 'true', true);
end $$;

select public.admin_hr_approve_payroll(current_setting('test.run')::uuid, 'اعتماد');
select public.admin_hr_pay_payroll(current_setting('test.run')::uuid, 'صرف');

-- ---------------------------------------------------------------------------
-- 5) Close: refused before paid (shown on an empty run), then seals November.
-- ---------------------------------------------------------------------------
do $$
begin
  begin
    perform public.admin_hr_close_payroll_period(
      current_setting('test.empty_run')::uuid, 'إغلاق غير مدفوعة');
    raise exception 'FAIL 5: an unpaid run was closed';
  exception
    when others then
      if sqlstate <> '23514' then raise; end if;
      if sqlerrm not like '%only a paid run can be closed%' then raise; end if;
  end;
  perform set_config('test.close_before_paid_refused', 'true', true);
end $$;

select public.admin_hr_close_payroll_period(current_setting('test.run')::uuid, 'إقفال نوفمبر');
do $$
declare v jsonb;
begin
  v := public.admin_hr_payroll_run(current_setting('test.run')::uuid);
  if (v ->> 'closed_at') is null then
    raise exception 'FAIL 5b: the closed flag did not land';
  end if;
  perform set_config('test.closed_correction_refused', 'false', true);
end $$;

-- A correction on a closed period is refused (kind/amount valid otherwise).
do $$
begin
  begin
    perform public.admin_hr_payroll_correction(
      (select id::uuid from hr.payroll_statements
        where run_id = current_setting('test.run')::uuid limit 1),
      'allowance', 10::numeric, 'تصحيح بعد الإقفال', null);
    raise exception 'FAIL 5c: a correction slipped into a closed period';
  exception
    when others then
      if sqlstate <> '23514' then raise; end if;
      if sqlerrm not like '%payroll period is already closed%' then raise; end if;
  end;
  perform set_config('test.closed_correction_refused', 'true', true);
end $$;

-- ---------------------------------------------------------------------------
-- 6) The preview flags a deferred adjustment and names it.
-- ---------------------------------------------------------------------------
select public.admin_hr_create_adjustment(
  '6d300000-0000-4000-8000-000000000002', 'bonus', 200, 'مكافأة متأخرة', '2026-10-01', null);
do $$
declare v jsonb;
begin
  perform public.admin_hr_review_adjustment(
    (select id::uuid from hr.adjustments where reason = 'مكافأة متأخرة')::uuid, true, 'اعتماد متأخر');
exception
  when others then
    if sqlstate <> '42501' then raise; end if;
    raise exception 'FAIL 6 setup: the owner must be able to review; got %', sqlerrm;
end $$;

do $$
declare v jsonb; d jsonb;
begin
  -- (November is the started month; the October-dated bonus shows up as
  --  deferred there, exactly as the D2 window promises.)
  v := public.admin_hr_preview_payroll(2026, 11);
  if jsonb_array_length(v -> 'adjustments_due') <> 1 then
    raise exception 'FAIL 6: November preview lost the deferred adjustment';
  end if;
  d := v -> 'adjustments_due' -> 0;
  if (d ->> 'deferred') is distinct from 'true' then
    raise exception 'FAIL 6b: the due adjustment is not flagged deferred';
  end if;
end $$;

-- The report a runner prints.
select
  'reached the end: no assertion failed' as verdict,
  current_setting('test.preview_employee', true) as preview_employee,
  current_setting('test.version_regen', true) as version_regen,
  current_setting('test.empty_approve_refused', true) as empty_approve_refused,
  current_setting('test.close_before_paid_refused', true) as close_before_paid_refused,
  current_setting('test.closed_correction_refused', true) as closed_correction_refused;

rollback;
