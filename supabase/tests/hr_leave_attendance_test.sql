-- hr_leave_attendance_test.sql
-- Behaviour test for 240_hr_leave_attendance.sql: decision D1 — approved leave
-- meets attendance and payroll without double counting.
--
-- DISCIPLINE: one transaction, every fixture destroyed by the final rollback.
-- PREREQUISITES: 212 + Phase 1 (213..217) + 240.
--
-- EXPECTED REPORT ON A PASS
--   verdict = 'reached the end: no assertion failed',
--   baseline_absence = 1, after_paid_leave_absence = 0, paid_days = 1,
--   unpaid_days = 1, unpaid_deducted = 150, rate_zero_deduction = 0,
--   cross_year_balance = '2/0' (2026 used / 2027 used), refund_balance = 1.

begin;

-- ---------------------------------------------------------------------------
-- Fixtures: one branch, one owner (acts for everything), one employee.
-- ---------------------------------------------------------------------------
insert into core.branches (id, brand_id, code, name_ar, name_en, address, is_active, settings)
values
  ('4d100000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000001', 'LA-B1', 'فرع الإجازة والحضور', 'Leave Attendance Branch', 'addr1', true, '{}'::jsonb);

insert into auth.users (id, email)
values
  ('5d200000-0000-4000-8000-000000000001', 'la-owner@test.local'),
  ('5d200000-0000-4000-8000-000000000002', 'la-emp@test.local'),
  ('5d200000-0000-4000-8000-000000000003', 'la-customer@test.local');

insert into identity.profiles (id, full_name, email, phone)
values ('5d200000-0000-4000-8000-000000000003', 'LA Customer', 'la-customer@test.local', '0500000012')
on conflict (id) do nothing;

insert into identity.staff_members (id, user_id, status, full_name, email)
values
  ('6d200000-0000-4000-8000-000000000001', '5d200000-0000-4000-8000-000000000001', 'active', 'LA Owner', 'la-owner@test.local'),
  ('6d200000-0000-4000-8000-000000000002', '5d200000-0000-4000-8000-000000000002', 'active', 'LA Emp',   'la-emp@test.local');

insert into identity.staff_roles (staff_id, role_id, branch_id)
select '6d200000-0000-4000-8000-000000000001', r.id, null from identity.roles r where r.code = 'owner';
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '6d200000-0000-4000-8000-000000000002', r.id, '4d100000-0000-4000-8000-000000000001' from identity.roles r where r.code = 'cashier';

insert into hr.employment_records (staff_id, hired_on)
values ('6d200000-0000-4000-8000-000000000002', '2026-01-01')
on conflict (staff_id) do nothing;

select set_config('request.jwt.claims',
  '{"sub":"5d200000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);

-- Gross 6500: basic 6000 + housing 500. Absence rate 100/day.
select public.admin_hr_set_compensation(
  '6d200000-0000-4000-8000-000000000002', 6000, 500, 0, 0, '2026-01-01', 'راتب');
select public.admin_hr_update_settings(
  p_absence_day_rate := 100, p_unpaid_leave_day_rate := 0);

-- Annual balance 2026 and 2027, 10 days each.
insert into hr.leave_balances (staff_id, leave_type_id, year, entitled_days)
select '6d200000-0000-4000-8000-000000000002', t.id, y.year, 10
  from hr.leave_types t, (values (2026), (2027)) as y(year)
 where t.code = 'annual';

-- Two published past shifts: Nov 3 (will become PAID leave) and Nov 10 (UNPAID).
select public.admin_hr_save_schedule(
  '6d200000-0000-4000-8000-000000000002', '4d100000-0000-4000-8000-000000000001',
  '2026-11-03T08:00:00Z', '2026-11-03T16:00:00Z', 0, 'published', 'وردية ٣ نوفمبر');
select public.admin_hr_save_schedule(
  '6d200000-0000-4000-8000-000000000002', '4d100000-0000-4000-8000-000000000001',
  '2026-11-10T08:00:00Z', '2026-11-10T16:00:00Z', 0, 'published', 'وردية ١٠ نوفمبر');

-- ---------------------------------------------------------------------------
-- 1) Baseline: no clock-in on a published past shift is absence.
-- ---------------------------------------------------------------------------
do $$
declare v record;
begin
  select * into v from hr.attendance_metrics_v2(
    '6d200000-0000-4000-8000-000000000002', '2026-11-01', '2026-11-30');
  if v.absence_days <> 2 or v.paid_leave_days <> 0 or v.unpaid_leave_days <> 0 then
    raise exception 'FAIL 1: baseline metrics are %/%/% (absence/paid/unpaid)',
      v.absence_days, v.paid_leave_days, v.unpaid_leave_days;
  end if;
  perform set_config('test.baseline_absence', v.absence_days::text, true);
end $$;

-- November payroll deducts one absence day at 100.
do $$
declare v jsonb; r jsonb;
begin
  v := public.admin_hr_generate_payroll(2026, 11, 'أساس قبل الإجازات');
  if (v ->> 'total_deductions')::numeric <> 200 then
    raise exception 'FAIL 1b: November deducted %; expected 200 (two absence days)',
      v ->> 'total_deductions';
  end if;
  perform set_config('test.run', v ->> 'run_id', true);
end $$;

-- ---------------------------------------------------------------------------
-- 2) PAID approved leave covers Nov 3: absence disappears, no deduction.
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"5d200000-0000-4000-8000-000000000002","role":"authenticated","aud":"authenticated"}', true);
select public.hr_request_leave(
  (select id from hr.leave_types where code = 'annual'),
  '2026-11-03', '2026-11-03', 'إجازة سنوية ليوم واحد', null);
select set_config('test.leave_paid',
  (select id::text from hr.leave_requests where reason = 'إجازة سنوية ليوم واحد'), true);

select set_config('request.jwt.claims',
  '{"sub":"5d200000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);
select public.admin_hr_review_leave(
  current_setting('test.leave_paid')::uuid, true, 'موافقة الإجازة السنوية');

do $$
declare v record; r jsonb;
begin
  select * into v from hr.attendance_metrics_v2(
    '6d200000-0000-4000-8000-000000000002', '2026-11-01', '2026-11-30');
  if v.absence_days <> 1 or v.paid_leave_days <> 1 then
    raise exception 'FAIL 2: after paid leave absence=% paid=%', v.absence_days, v.paid_leave_days;
  end if;
  perform set_config('test.after_paid_leave_absence', v.absence_days::text, true);
  perform set_config('test.paid_days', v.paid_leave_days::text, true);

  r := public.admin_hr_generate_payroll(2026, 11, 'بعد الإجازة المدفوعة');
  -- Nov 10 is still a bare absence at this point: 100, from @attendance only.
  if (r ->> 'total_deductions')::numeric <> 100 then
    raise exception 'FAIL 2b: after the paid leave deductions are %; expected 100',
      r ->> 'total_deductions';
  end if;
  if not exists (
    select 1 from hr.payroll_line_items l
     where l.payroll_run_id = current_setting('test.run')::uuid
       and l.label = '@attendance' and l.amount = 100
  ) then
    raise exception 'FAIL 2c: the remaining absence day lost its @attendance line';
  end if;
  if exists (
    select 1 from hr.payroll_line_items l
     where l.payroll_run_id = current_setting('test.run')::uuid
       and l.label = '@unpaid_leave'
  ) then
    raise exception 'FAIL 2d: an @unpaid_leave line appeared before any unpaid leave';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 3) UNPAID approved leave covers Nov 10 with a configured rate: its own line.
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"5d200000-0000-4000-8000-000000000002","role":"authenticated","aud":"authenticated"}', true);
select public.hr_request_leave(
  (select id from hr.leave_types where code = 'unpaid'),
  '2026-11-10', '2026-11-10', 'إجازة بدون راتب ليوم', null);
select set_config('test.leave_unpaid',
  (select id::text from hr.leave_requests where reason = 'إجازة بدون راتب ليوم'), true);

select set_config('request.jwt.claims',
  '{"sub":"5d200000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);
select public.admin_hr_review_leave(
  current_setting('test.leave_unpaid')::uuid, true, 'موافقة غير المدفوعة');
select public.admin_hr_update_settings(p_unpaid_leave_day_rate := 150);

do $$
declare v record; r jsonb;
begin
  select * into v from hr.attendance_metrics_v2(
    '6d200000-0000-4000-8000-000000000002', '2026-11-01', '2026-11-30');
  if v.absence_days <> 0 or v.paid_leave_days <> 1 or v.unpaid_leave_days <> 1 then
    raise exception 'FAIL 3: unpaid metrics are %/%/%',
      v.absence_days, v.paid_leave_days, v.unpaid_leave_days;
  end if;
  perform set_config('test.unpaid_days', v.unpaid_leave_days::text, true);

  r := public.admin_hr_generate_payroll(2026, 11, 'بعد غير المدفوعة');
  if (r ->> 'total_deductions')::numeric <> 150 then
    raise exception 'FAIL 3b: unpaid leave deduction is %; expected 150',
      r ->> 'total_deductions';
  end if;
  perform set_config('test.unpaid_deducted', (r ->> 'total_deductions')::text, true);
  if not exists (
    select 1 from hr.payroll_line_items l
     where l.payroll_run_id = current_setting('test.run')::uuid
       and l.label = '@unpaid_leave' and l.amount = 150
  ) then
    raise exception 'FAIL 3c: the @unpaid_leave line is missing';
  end if;
  if exists (
    select 1 from hr.payroll_line_items l
     where l.payroll_run_id = current_setting('test.run')::uuid
       and l.label = '@attendance'
  ) then
    raise exception 'FAIL 3d: an @attendance line appeared for a leave day';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 4) Rate zero returns the money to zero without re-classifying the day.
-- ---------------------------------------------------------------------------
select public.admin_hr_update_settings(p_unpaid_leave_day_rate := 0);
do $$
declare r jsonb;
begin
  r := public.admin_hr_generate_payroll(2026, 11, 'بصفر المعدل');
  if (r ->> 'total_deductions')::numeric <> 0 then
    raise exception 'FAIL 4: a zero rate still cost %', r ->> 'total_deductions';
  end if;
  perform set_config('test.rate_zero_deduction', (r ->> 'total_deductions')::text, true);
end $$;

-- ---------------------------------------------------------------------------
-- 5) Cross-year paid leave: charged to the START year only, covered by date.
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"5d200000-0000-4000-8000-000000000002","role":"authenticated","aud":"authenticated"}', true);
select public.hr_request_leave(
  (select id from hr.leave_types where code = 'annual'),
  '2026-12-31', '2027-01-01', 'إجازة تعبر السنة', null);
select set_config('test.leave_cross',
  (select id::text from hr.leave_requests where reason = 'إجازة تعبر السنة'), true);

select set_config('request.jwt.claims',
  '{"sub":"5d200000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);
select public.admin_hr_review_leave(
  current_setting('test.leave_cross')::uuid, true, 'موافقة العابرة');

-- A published shift on Jan 1 2027 must be leave-covered by date overlap.
select public.admin_hr_save_schedule(
  '6d200000-0000-4000-8000-000000000002', '4d100000-0000-4000-8000-000000000001',
  '2027-01-01T08:00:00Z', '2027-01-01T16:00:00Z', 0, 'published', 'وردية رأس السنة');

do $$
declare v record; b2026 numeric; b2027 numeric;
begin
  select * into v from hr.attendance_metrics_v2(
    '6d200000-0000-4000-8000-000000000002', '2026-12-01', '2027-01-31');
  -- Coverage is counted over PUBLISHED shifts: only Jan 1 has one here.
  if v.paid_leave_days <> 1 then
    raise exception 'FAIL 5: cross-year covered shifts = %; expected 1 (the Jan 1 shift)',
      v.paid_leave_days;
  end if;
  select used_days into b2026 from hr.leave_balances
   where staff_id = '6d200000-0000-4000-8000-000000000002'
     and year = 2026
     and leave_type_id = (select id from hr.leave_types where code = 'annual');
  select used_days into b2027 from hr.leave_balances
   where staff_id = '6d200000-0000-4000-8000-000000000002'
     and year = 2027
     and leave_type_id = (select id from hr.leave_types where code = 'annual');
  -- 2026 carries 3 days at this point: Nov 3 (1) + the cross-year days (2).
  if b2026 <> 3 or b2027 <> 0 then
    raise exception 'FAIL 5b: cross-year charging is %/% (2026/2027)', b2026, b2027;
  end if;
  perform set_config('test.cross_year_balance', b2026::text || '/' || b2027::text, true);
end $$;

-- ---------------------------------------------------------------------------
-- 6) Overlap guard: a second leave over the same days is refused.
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"5d200000-0000-4000-8000-000000000002","role":"authenticated","aud":"authenticated"}', true);
do $$
begin
  begin
    perform public.hr_request_leave(
      (select id from hr.leave_types where code = 'annual'),
      '2026-11-03', '2026-11-05', 'تداخل مقصود', null);
    raise exception 'FAIL 6: an overlapping leave request was accepted';
  exception
    when others then
      if sqlstate <> '23505' then raise; end if;
      if sqlerrm not like '%overlapping leave request%' then raise; end if;
  end;
end $$;

-- ---------------------------------------------------------------------------
-- 7) Cancelling the approved paid leave refunds the balance.
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"5d200000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);
select public.hr_cancel_leave_request(
  current_setting('test.leave_paid')::uuid, 'إلغاء لاختبار الرد');
do $$
declare b2026 numeric;
begin
  select used_days into b2026 from hr.leave_balances
   where staff_id = '6d200000-0000-4000-8000-000000000002'
     and year = 2026
     and leave_type_id = (select id from hr.leave_types where code = 'annual');
  -- Cancelling the Nov 3 day refunds it; the two cross-year days remain.
  if b2026 <> 2 then
    raise exception 'FAIL 7: balance after refund is %; expected 2 (cross-year days only)', b2026;
  end if;
  perform set_config('test.refund_balance', b2026::text, true);
end $$;

-- The report a runner prints.
select
  'reached the end: no assertion failed' as verdict,
  current_setting('test.baseline_absence', true) as baseline_absence,
  current_setting('test.after_paid_leave_absence', true) as after_paid_leave_absence,
  current_setting('test.paid_days', true) as paid_days,
  current_setting('test.unpaid_days', true) as unpaid_days,
  current_setting('test.unpaid_deducted', true) as unpaid_deducted,
  current_setting('test.rate_zero_deduction', true) as rate_zero_deduction,
  current_setting('test.cross_year_balance', true) as cross_year_balance,
  current_setting('test.refund_balance', true) as refund_balance;

rollback;
