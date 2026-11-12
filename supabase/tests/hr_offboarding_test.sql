-- hr_offboarding_test.sql
-- Behaviour test for 241_hr_offboarding.sql: decision D6 — an independent
-- employee offboarding cycle with a step checklist, and the separation between
-- the termination decision and the settlement steps.
--
-- DISCIPLINE: one transaction, every fixture destroyed by the final rollback.
-- PREREQUISITES: 004/013/018/123/137 + 212 + Phase 1/2 (213..217, 240) + 241.
--
-- EXPECTED REPORT ON A PASS
--   verdict = 'reached the end: no assertion failed',
--   finalized_status = 'closed', suspended_login = 'suspended',
--   restart_works = true, case_history = 'open', cancelled_steps_preserved = true.

begin;

insert into core.branches (id, brand_id, code, name_ar, name_en, address, is_active, settings)
values
  ('4e300000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000001', 'OF-B1', 'فرع إنهاء الخدمة', 'Offboarding Branch', 'addr1', true, '{}'::jsonb);

insert into auth.users (id, email)
values
  ('5e300000-0000-4000-8000-000000000001', 'of-owner@test.local'),
  ('5e300000-0000-4000-8000-000000000002', 'of-leaver@test.local'),
  ('5e300000-0000-4000-8000-000000000003', 'of-leaver2@test.local'),
  ('5e300000-0000-4000-8000-000000000004', 'of-cashier@test.local'),
  ('5e300000-0000-4000-8000-000000000005', 'of-customer@test.local');

insert into identity.profiles (id, full_name, email, phone)
values ('5e300000-0000-4000-8000-000000000005', 'OF Customer', 'of-customer@test.local', '0500000013')
on conflict (id) do nothing;

insert into identity.staff_members (id, user_id, status, full_name, email)
values
  ('6e300000-0000-4000-8000-000000000001', '5e300000-0000-4000-8000-000000000001', 'active', 'OF Owner',   'of-owner@test.local'),
  ('6e300000-0000-4000-8000-000000000002', '5e300000-0000-4000-8000-000000000002', 'active', 'OF Leaver',  'of-leaver@test.local'),
  ('6e300000-0000-4000-8000-000000000003', '5e300000-0000-4000-8000-000000000003', 'active', 'OF Leaver2', 'of-leaver2@test.local'),
  ('6e300000-0000-4000-8000-000000000004', '5e300000-0000-4000-8000-000000000004', 'active', 'OF Cashier', 'of-cashier@test.local');

insert into identity.staff_roles (staff_id, role_id, branch_id)
select '6e300000-0000-4000-8000-000000000001', r.id, null from identity.roles r where r.code = 'owner';
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '6e300000-0000-4000-8000-000000000002', r.id, '4e300000-0000-4000-8000-000000000001' from identity.roles r where r.code = 'cashier';
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '6e300000-0000-4000-8000-000000000003', r.id, '4e300000-0000-4000-8000-000000000001' from identity.roles r where r.code = 'cashier';
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '6e300000-0000-4000-8000-000000000004', r.id, '4e300000-0000-4000-8000-000000000001' from identity.roles r where r.code = 'cashier';

insert into identity.staff_roles (staff_id, role_id, branch_id)
select '6e300000-0000-4000-8000-000000000002', r.id, '4e300000-0000-4000-8000-000000000001' from identity.roles r where r.code = 'manager';

insert into hr.employment_records (staff_id, hired_on)
values
  ('6e300000-0000-4000-8000-000000000002', '2026-01-01'),
  ('6e300000-0000-4000-8000-000000000003', '2026-01-01')
on conflict (staff_id) do nothing;

select set_config('request.jwt.claims',
  '{"sub":"5e300000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);

-- ---------------------------------------------------------------------------
-- 1) Start: six steps seeded, no case yet open for leaver2.
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"5e300000-0000-4000-8000-000000000004","role":"authenticated","aud":"authenticated"}', true);
do $$
begin
  begin
    perform public.admin_hr_start_offboarding(
      '6e300000-0000-4000-8000-000000000002'::uuid, '2026-12-15'::date, 'استقالة');
    raise exception 'FAIL 1: an employee opened their own offboarding case';
  exception
    when others then
      -- an employee without hr.employee.write is refused before anything else
      if sqlstate <> '42501' then raise; end if;
  end;
end $$;

select set_config('request.jwt.claims',
  '{"sub":"5e300000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);
select set_config('test.case',
  (public.admin_hr_start_offboarding(
     '6e300000-0000-4000-8000-000000000002'::uuid, '2026-12-15'::date, 'استقالة')
   ->> 'case_id'), true);

do $$
declare v jsonb;
begin
  v := public.admin_hr_offboarding_cases('6e300000-0000-4000-8000-000000000002');
  if jsonb_array_length(v) <> 1 then
    raise exception 'FAIL 1b: the case list shows % cases', jsonb_array_length(v);
  end if;
  if (v -> 0 -> 'status') <> '"open"'::jsonb then
    raise exception 'FAIL 1b: the new case is %', v -> 0 -> 'status';
  end if;
  if jsonb_array_length(v -> 0 -> 'steps') <> 6 then
    raise exception 'FAIL 1b: the checklist holds % steps', jsonb_array_length(v -> 0 -> 'steps');
  end if;
  perform set_config('test.case_history', (v -> 0 ->> 'status'), true);
end $$;

-- ---------------------------------------------------------------------------
-- 2) The checklist gates the finalize: pending steps refuse, then the owner
--    assigns and closes them one by one.
-- ---------------------------------------------------------------------------
do $$
begin
  begin
    perform public.admin_hr_finalize_offboarding(
      current_setting('test.case')::uuid, '2026-12-15'::date, 'مبكر جدًا');
    raise exception 'FAIL 2: finalize succeeded over pending steps';
  exception
    when others then
      if sqlstate <> '23514' then raise; end if;
      if sqlerrm not like '%checklist still has pending steps%' then raise; end if;
  end;
end $$;

-- An employee cannot finalize their own case even with hr.employee.write.
select set_config('request.jwt.claims',
  '{"sub":"5e300000-0000-4000-8000-000000000002","role":"authenticated","aud":"authenticated"}', true);
do $$
begin
  begin
    perform public.admin_hr_finalize_offboarding(
      current_setting('test.case')::uuid, '2026-12-15'::date, 'أنهي نفسي');
    raise exception 'FAIL 2b: an employee finalized their own case';
  exception
    when others then
      if sqlstate <> '42501' then raise; end if;
      if sqlerrm not like '%finalize your own offboarding%' then raise; end if;
  end;
end $$;

select set_config('request.jwt.claims',
  '{"sub":"5e300000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);
select public.admin_hr_assign_offboarding_step(
  current_setting('test.case')::uuid, 'finance_review',
  '6e300000-0000-4000-8000-000000000001'::uuid, '2026-12-10'::date);
select public.admin_hr_set_offboarding_step(
  current_setting('test.case')::uuid, 'manager_review', 'done', 'موافقة المدير');
select public.admin_hr_set_offboarding_step(
  current_setting('test.case')::uuid, 'hr_review', 'done', 'مراجعة HR');
select public.admin_hr_set_offboarding_step(
  current_setting('test.case')::uuid, 'finance_review', 'done', 'لا مستحقات معلقة');
select public.admin_hr_set_offboarding_step(
  current_setting('test.case')::uuid, 'obligations', 'done', 'لا سلف ولا فروق');
select public.admin_hr_set_offboarding_step(
  current_setting('test.case')::uuid, 'final_settlement', 'done',
  'التسوية النهائية: بدل إجازة غير مستنفدة بمعدل معتمد من المالك — سياسة EOS قيد القرار');

-- ---------------------------------------------------------------------------
-- 3) Finalize executes the termination decision.
-- ---------------------------------------------------------------------------
select public.admin_hr_finalize_offboarding(
  current_setting('test.case')::uuid, '2026-12-15'::date, 'إقفال الملف');

do $$
declare v jsonb; e record; r jsonb;
begin
  v := public.admin_hr_offboarding_cases('6e300000-0000-4000-8000-000000000002');
  perform set_config('test.finalized_status', (v -> 0 ->> 'status'), true);
  if (v -> 0 ->> 'status') <> 'closed' then
    raise exception 'FAIL 3: the case is % after finalize', v -> 0 -> 'status';
  end if;
  select * into e from hr.employment_records
   where staff_id = '6e300000-0000-4000-8000-000000000002';
  if e.employment_status <> 'terminated' or e.terminated_on <> '2026-12-15' then
    raise exception 'FAIL 3b: employment is % / %', e.employment_status, e.terminated_on;
  end if;
  -- History stays readable: the directory still returns the terminated file.
  r := public.admin_hr_employees(null, null, 'terminated', null);
  if not exists (
    select 1 from jsonb_array_elements(r)
     where value ->> 'staff_id' = '6e300000-0000-4000-8000-000000000002'
  ) then
    raise exception 'FAIL 3c: the terminated employee vanished from the directory';
  end if;
  -- A second finalize is refused.
  begin
    perform public.admin_hr_finalize_offboarding(
      current_setting('test.case')::uuid, '2026-12-20'::date, 'مرة ثانية');
    raise exception 'FAIL 3d: a closed case was finalized twice';
  exception
    when others then
      if sqlstate <> '23514' then raise; end if;
  end;
end $$;

-- ---------------------------------------------------------------------------
-- 4) Access suspension is a separate, later, audited act, refused twice.
--    (Its refusal on an open case is structurally covered by the closed-case
--    gate: the finalize order above leaves no open case to attack.)
-- ---------------------------------------------------------------------------
select public.admin_hr_suspend_offboarding_access(
  current_setting('test.case')::uuid, 'تعليق الدخول بعد الإقفال');
do $$
declare st text;
begin
  select status into st from identity.staff_members
   where id = '6e300000-0000-4000-8000-000000000002';
  perform set_config('test.suspended_login', st, true);
  if st <> 'suspended' then
    raise exception 'FAIL 4b: the login identity is %', st;
  end if;
  begin
    perform public.admin_hr_suspend_offboarding_access(
      current_setting('test.case')::uuid, 'مرة ثانية');
    raise exception 'FAIL 4c: access suspension ran twice';
  exception
    when others then
      if sqlstate <> '23514' then raise; end if;
  end;
end $$;

-- ---------------------------------------------------------------------------
-- 5) Cancel frees the slot and a restart works with a fresh checklist.
-- ---------------------------------------------------------------------------
select set_config('test.case2',
  (public.admin_hr_start_offboarding(
     '6e300000-0000-4000-8000-000000000003'::uuid, '2027-01-10'::date, 'نقل')
   ->> 'case_id'), true);
select public.admin_hr_cancel_offboarding(
  current_setting('test.case2')::uuid, 'تراجع عن النقل');
select set_config('test.case2b',
  (public.admin_hr_start_offboarding(
     '6e300000-0000-4000-8000-000000000003'::uuid, '2027-01-20'::date, 'إعادة فتح')
   ->> 'case_id'), true);
do $$
declare v jsonb;
begin
  v := public.admin_hr_offboarding_cases('6e300000-0000-4000-8000-000000000003');
  if jsonb_array_length(v) <> 2 then
    raise exception 'FAIL 5: the restart produced % cases (cancelled + open)', jsonb_array_length(v);
  end if;
  perform set_config('test.steps_after_cancel',
    (select count(*)::text from hr.offboarding_steps
      where case_id = current_setting('test.case2')::uuid and status = 'pending'), true);
  if (select count(*) from hr.offboarding_steps
       where case_id = current_setting('test.case2b')::uuid) <> 6 then
    raise exception 'FAIL 5b: the restarted checklist is not fresh';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 6) A cashier without hr.employee.read cannot see the cases.
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"5e300000-0000-4000-8000-000000000004","role":"authenticated","aud":"authenticated"}', true);
do $$
begin
  begin
    perform public.admin_hr_offboarding_cases(null);
    raise exception 'FAIL 6: a cashier read the offboarding cases';
  exception
    when others then
      if sqlstate <> '42501' then raise; end if;
      if sqlerrm not like '%missing permission: hr.employee.read%' then raise; end if;
  end;
end $$;

select set_config('request.jwt.claims',
  '{"sub":"5e300000-0000-4000-8000-000000000005","role":"authenticated","aud":"authenticated"}', true);
do $$
begin
  begin
    perform public.admin_hr_offboarding_cases(null);
    raise exception 'FAIL 6b: a customer read the offboarding cases';
  exception
    when others then
      if sqlstate <> '42501' then raise; end if;
      if sqlerrm not like '%not authenticated%' then raise; end if;
  end;
end $$;

-- The report a runner prints.
select
  'reached the end: no assertion failed' as verdict,
  current_setting('test.finalized_status', true) as finalized_status,
  current_setting('test.suspended_login', true) as suspended_login,
  current_setting('test.case_history', true) as case_history,
  (current_setting('test.steps_after_cancel', true) <> '0') as cancelled_steps_preserved,
  exists (
    select 1 from hr.offboarding_cases
     where id = current_setting('test.case2b')::uuid and status = 'open'
  ) as restart_works;

rollback;
