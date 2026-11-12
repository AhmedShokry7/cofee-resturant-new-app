-- hr_leave_cancel_scope_test.sql
-- Behaviour test for 214_hr_leave_cancel_reviewer_scope.sql: the staff scope
-- guard of public.hr_cancel_leave_request, on top of the HR model of
-- 212_hr_workforce.sql.
--
-- DISCIPLINE: one transaction, every fixture destroyed by the final rollback.
-- RUN ONLY AGAINST AN ISOLATED, NON-PRODUCTION DATABASE (or a rehearsal
-- transaction) that already has 212 and the 214 replacement. Every assertion
-- runs as the real authenticated role with real JWT claims.
--
-- PREREQUISITES: 004/013/018/123/137, 212 and the 214 body of
-- public.hr_cancel_leave_request.
--
-- EXPECTED REPORT ON A PASS
--   verdict = 'reached the end: no assertion failed',
--   fixture_cancellations = 3 (p2, a2, p1; a3 stays approved),
--   cancel_audit_rows = 3, emp2_used_days = '2.00' (a3 days remain charged).
--
-- AGAINST THE PRE-214 FUNCTION, FAIL 1 FIRES ON PURPOSE: a branch-1 reviewer
-- cancels a branch-2 leave request — the defect the guard closes.

begin;

-- ---------------------------------------------------------------------------
-- Fixtures: two branches, five staff, one customer. Prefixes 4b/5b/6b are
-- unique to this file so a scratch database can hold another rehearsal.
-- ---------------------------------------------------------------------------
insert into core.branches (id, brand_id, code, name_ar, name_en, address, is_active, settings)
values
  ('4b100000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000001', 'LC-B1', 'فرع الإجازات 1', 'Leave Cancel Branch 1', 'addr1', true, '{}'::jsonb),
  ('4b200000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000001', 'LC-B2', 'فرع الإجازات 2', 'Leave Cancel Branch 2', 'addr2', true, '{}'::jsonb);

insert into auth.users (id, email)
values
  ('5b100000-0000-4000-8000-000000000001', 'lc-global-1@test.local'),
  ('5b100000-0000-4000-8000-000000000002', 'lc-review-1@test.local'),
  ('5b100000-0000-4000-8000-000000000003', 'lc-review-2@test.local'),
  ('5b100000-0000-4000-8000-000000000004', 'lc-emp-1@test.local'),
  ('5b100000-0000-4000-8000-000000000005', 'lc-emp-2@test.local'),
  ('5b100000-0000-4000-8000-000000000006', 'lc-customer@test.local');

insert into identity.profiles (id, full_name, email, phone)
values ('5b100000-0000-4000-8000-000000000006', 'LC Customer', 'lc-customer@test.local', '0500000010')
on conflict (id) do nothing;

insert into identity.staff_members (id, user_id, status, full_name, email)
values
  ('6b100000-0000-4000-8000-000000000001', '5b100000-0000-4000-8000-000000000001', 'active', 'LC Global',     'lc-global-1@test.local'),
  ('6b100000-0000-4000-8000-000000000002', '5b100000-0000-4000-8000-000000000002', 'active', 'LC Review One', 'lc-review-1@test.local'),
  ('6b100000-0000-4000-8000-000000000003', '5b100000-0000-4000-8000-000000000003', 'active', 'LC Review Two', 'lc-review-2@test.local'),
  ('6b100000-0000-4000-8000-000000000004', '5b100000-0000-4000-8000-000000000004', 'active', 'LC Emp One',    'lc-emp-1@test.local'),
  ('6b100000-0000-4000-8000-000000000005', '5b100000-0000-4000-8000-000000000005', 'active', 'LC Emp Two',    'lc-emp-2@test.local');

-- branch_manager carries hr.leave.review (212 grants it), so the two branch
-- reviewers need no extra role. The two employees are plain cashiers.
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '6b100000-0000-4000-8000-000000000001', r.id, null from identity.roles r where r.code = 'manager';
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '6b100000-0000-4000-8000-000000000002', r.id, '4b100000-0000-4000-8000-000000000001' from identity.roles r where r.code = 'branch_manager';
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '6b100000-0000-4000-8000-000000000003', r.id, '4b200000-0000-4000-8000-000000000002' from identity.roles r where r.code = 'branch_manager';
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '6b100000-0000-4000-8000-000000000004', r.id, '4b100000-0000-4000-8000-000000000001' from identity.roles r where r.code = 'cashier';
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '6b100000-0000-4000-8000-000000000005', r.id, '4b200000-0000-4000-8000-000000000002' from identity.roles r where r.code = 'cashier';

-- Annual leave tracks a balance; give each employee 10 days for 2026 and 2027.
insert into hr.leave_balances (staff_id, leave_type_id, year, entitled_days)
select s.id, t.id, y.year, 10
  from hr.leave_types t, identity.staff_members s, (values (2026), (2027)) as y(year)
 where t.code = 'annual'
   and s.id in ('6b100000-0000-4000-8000-000000000004', '6b100000-0000-4000-8000-000000000005');

-- Pending leave for emp-1 (branch 1) and emp-2 (branch 2), requested by
-- themselves. Approved leave for emp-2 proves the balance refund path.
select set_config('request.jwt.claims',
  '{"sub":"5b100000-0000-4000-8000-000000000004","role":"authenticated","aud":"authenticated"}', true);
select public.hr_request_leave(
  (select id from hr.leave_types where code = 'annual'),
  '2026-12-01', '2026-12-03', 'طلب معلق للفرع الأول', null);
select set_config('test.p1',
  (select id::text from hr.leave_requests
    where staff_id = '6b100000-0000-4000-8000-000000000004' and starts_on = '2026-12-01'), true);

select set_config('request.jwt.claims',
  '{"sub":"5b100000-0000-4000-8000-000000000005","role":"authenticated","aud":"authenticated"}', true);
select public.hr_request_leave(
  (select id from hr.leave_types where code = 'annual'),
  '2026-12-10', '2026-12-12', 'طلب معلق للفرع الثاني', null);
select set_config('test.p2',
  (select id::text from hr.leave_requests
    where staff_id = '6b100000-0000-4000-8000-000000000005' and starts_on = '2026-12-10'), true);

select public.hr_request_leave(
  (select id from hr.leave_types where code = 'annual'),
  '2027-01-05', '2027-01-06', 'طلب معتمد للفرع الثاني', null);
select set_config('test.a2',
  (select id::text from hr.leave_requests
    where staff_id = '6b100000-0000-4000-8000-000000000005' and starts_on = '2027-01-05'), true);

select set_config('request.jwt.claims',
  '{"sub":"5b100000-0000-4000-8000-000000000003","role":"authenticated","aud":"authenticated"}', true);
select public.admin_hr_review_leave(
  current_setting('test.a2')::uuid, true, 'اعتماد الفرع الثاني');

-- ---------------------------------------------------------------------------
-- 1) A foreign-branch reviewer is refused, and the refusal writes nothing.
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"5b100000-0000-4000-8000-000000000002","role":"authenticated","aud":"authenticated"}', true);

do $$
begin
  begin
    perform public.hr_cancel_leave_request(
      current_setting('test.p2')::uuid, 'إلغاء من خارج النطاق');
    raise exception 'FAIL 1: a branch-1 reviewer cancelled a branch-2 leave request';
  exception
    when others then
      if sqlstate <> '42501' then raise; end if;
      if sqlerrm not like '%staff member out of scope%' then raise; end if;
  end;

  if (select status from hr.leave_requests where id = current_setting('test.p2')::uuid) <> 'pending' then
    raise exception 'FAIL 1: the refused cancel changed the request';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 2) The in-scope reviewer cancels a pending request, audited.
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"5b100000-0000-4000-8000-000000000003","role":"authenticated","aud":"authenticated"}', true);
select public.hr_cancel_leave_request(
  current_setting('test.p2')::uuid, 'إلغاء من مراجع نطاقه');

do $$
begin
  if (select status from hr.leave_requests where id = current_setting('test.p2')::uuid) <> 'cancelled' then
    raise exception 'FAIL 2: the in-scope cancel did not take';
  end if;
  if (select count(*) from identity.audit_log
       where action = 'hr.leave.cancel'
         and entity_id = current_setting('test.p2')::uuid) <> 1 then
    raise exception 'FAIL 2: the cancel is not audited';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 3) Cancelling the APPROVED balance-tracked leave returns the days.
-- ---------------------------------------------------------------------------
select public.hr_cancel_leave_request(
  current_setting('test.a2')::uuid, 'إلغاء معتمدة يعيد الرصيد');

do $$
declare v_used numeric(6,2);
begin
  if (select status from hr.leave_requests where id = current_setting('test.a2')::uuid) <> 'cancelled' then
    raise exception 'FAIL 3: the approved cancel did not take';
  end if;
  select used_days into v_used from hr.leave_balances
   where staff_id = '6b100000-0000-4000-8000-000000000005'
     and year = 2027
     and leave_type_id = (select id from hr.leave_types where code = 'annual');
  if v_used <> 0 then
    raise exception 'FAIL 3: the approved cancel left used_days = %', v_used;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 4) The branch-1 reviewer cannot touch the other branch's approved rows, and
--    the refused approved cancel leaves the balance untouched.
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"5b100000-0000-4000-8000-000000000005","role":"authenticated","aud":"authenticated"}', true);
select public.hr_request_leave(
  (select id from hr.leave_types where code = 'annual'),
  '2027-02-01', '2027-02-02', 'طلب معتمد ثانٍ للفرع الثاني', null);
select set_config('test.a3',
  (select id::text from hr.leave_requests
    where staff_id = '6b100000-0000-4000-8000-000000000005' and starts_on = '2027-02-01'), true);

select set_config('request.jwt.claims',
  '{"sub":"5b100000-0000-4000-8000-000000000003","role":"authenticated","aud":"authenticated"}', true);
select public.admin_hr_review_leave(
  current_setting('test.a3')::uuid, true, 'اعتماد ثانٍ');

select set_config('request.jwt.claims',
  '{"sub":"5b100000-0000-4000-8000-000000000002","role":"authenticated","aud":"authenticated"}', true);
do $$
declare v_used numeric(6,2);
begin
  begin
    perform public.hr_cancel_leave_request(
      current_setting('test.a3')::uuid, 'خارج النطاق على معتمدة');
    raise exception 'FAIL 4: a branch-1 reviewer cancelled an approved branch-2 leave';
  exception
    when others then
      if sqlstate <> '42501' then raise; end if;
      if sqlerrm not like '%staff member out of scope%' then raise; end if;
  end;

  select used_days into v_used from hr.leave_balances
   where staff_id = '6b100000-0000-4000-8000-000000000005'
     and year = 2027
     and leave_type_id = (select id from hr.leave_types where code = 'annual');
  if v_used <> 2 then
    raise exception 'FAIL 4: the refused approved cancel left used_days = %; expected 2 (a3 days)', v_used;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 5) A self-cancel works for an employee with no review permission.
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"5b100000-0000-4000-8000-000000000004","role":"authenticated","aud":"authenticated"}', true);
select public.hr_cancel_leave_request(
  current_setting('test.p1')::uuid, 'إلغاء ذاتي');

do $$
begin
  if (select status from hr.leave_requests where id = current_setting('test.p1')::uuid) <> 'cancelled' then
    raise exception 'FAIL 5: the self-cancel did not take';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 6) The state guard keeps its own refusal order.
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"5b100000-0000-4000-8000-000000000003","role":"authenticated","aud":"authenticated"}', true);
do $$
begin
  begin
    perform public.hr_cancel_leave_request(
      current_setting('test.p1')::uuid, 'مرفوضة لا تلغى');
    raise exception 'FAIL 6: a rejected request was cancellable';
  exception
    when others then
      if sqlstate <> '23514' then raise; end if;
      if sqlerrm not like '%cannot be cancelled in its current state%' then raise; end if;
  end;
end $$;

-- ---------------------------------------------------------------------------
-- 7) A global scope is unchanged: the NULL-branch manager passes the scope arm.
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"5b100000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);
do $$
begin
  begin
    perform public.hr_cancel_leave_request(
      current_setting('test.p1')::uuid, 'نطاق عام قبل حالة الرفض');
    raise exception 'FAIL 7: a cancelled request was cancellable';
  exception
    when others then
      if sqlstate <> '23514' then raise; end if;
      if sqlerrm like '%staff member out of scope%' then
        raise exception 'FAIL 7: the guard refused a global caller';
      end if;
  end;
end $$;

-- ---------------------------------------------------------------------------
-- 8) An unknown id and a signed-in customer keep their own refusals.
-- ---------------------------------------------------------------------------
do $$
begin
  begin
    perform public.hr_cancel_leave_request(
      '6b999999-0000-4000-8000-000000000099', null);
    raise exception 'FAIL 8: an unknown request was cancellable';
  exception
    when others then
      if sqlstate <> 'P0002' then raise; end if;
  end;
end $$;

select set_config('request.jwt.claims',
  '{"sub":"5b100000-0000-4000-8000-000000000006","role":"authenticated","aud":"authenticated"}', true);
do $$
begin
  begin
    perform public.hr_cancel_leave_request(
      current_setting('test.p2')::uuid, null);
    raise exception 'FAIL 8: a customer cancelled a leave request';
  exception
    when others then
      if sqlstate <> '42501' then raise; end if;
      if sqlerrm not like '%not authenticated%' then raise; end if;
  end;
end $$;

-- The report a runner prints.
select
  'reached the end: no assertion failed' as verdict,
  (select count(*) from hr.leave_requests
    where id in (current_setting('test.p1')::uuid,
                 current_setting('test.p2')::uuid,
                 current_setting('test.a2')::uuid,
                 current_setting('test.a3')::uuid)
      and status = 'cancelled') as fixture_cancellations,
  (select count(*) from identity.audit_log
    where action = 'hr.leave.cancel'
      and entity_id in (current_setting('test.p1')::uuid,
                        current_setting('test.p2')::uuid,
                        current_setting('test.a2')::uuid,
                        current_setting('test.a3')::uuid)) as cancel_audit_rows,
  (select used_days::text from hr.leave_balances
    where staff_id = '6b100000-0000-4000-8000-000000000005' and year = 2027) as emp2_used_days;

rollback;
