-- hr_finance_exceptions_test.sql
-- Behaviour test for 217_hr_finance_exceptions_report.sql on top of 212 and the
-- Phase 1 fixes (213/214/215/216).
--
-- DISCIPLINE: one transaction, every fixture destroyed by the final rollback.
-- PREREQUISITES: 212 + 215 (deferral/suspension) + 217; D2/D3 semantics.
--
-- EXPECTED REPORT ON A PASS
--   verdict = 'reached the end: no assertion failed',
--   deferred_seen = 1, upcoming_seen = 1, outstanding_seen = 1.

begin;

insert into core.branches (id, brand_id, code, name_ar, name_en, address, is_active, settings)
values
  ('4c100000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000001', 'FX-B1', 'فرع الاستثناءات', 'Exceptions Branch', 'addr1', true, '{}'::jsonb);

insert into auth.users (id, email)
values
  ('5c200000-0000-4000-8000-000000000005', 'fx-manager@test.local'),
  ('5c200000-0000-4000-8000-000000000002', 'fx-emp@test.local'),
  ('5c200000-0000-4000-8000-000000000003', 'fx-cashier@test.local'),
  ('5c200000-0000-4000-8000-000000000004', 'fx-customer@test.local');

insert into identity.profiles (id, full_name, email, phone)
values ('5c200000-0000-4000-8000-000000000004', 'FX Customer', 'fx-customer@test.local', '0500000011')
on conflict (id) do nothing;

insert into identity.staff_members (id, user_id, status, full_name, email)
values
  ('6c200000-0000-4000-8000-000000000001', '5c200000-0000-4000-8000-000000000005', 'active', 'FX Manager', 'fx-manager@test.local'),
  ('6c200000-0000-4000-8000-000000000002', '5c200000-0000-4000-8000-000000000002', 'active', 'FX Emp',    'fx-emp@test.local'),
  ('6c200000-0000-4000-8000-000000000003', '5c200000-0000-4000-8000-000000000003', 'active', 'FX Cashier','fx-cashier@test.local');

-- Manager: brand-wide (NULL branch) so can_access_staff passes for everyone.
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '6c200000-0000-4000-8000-000000000001', r.id, null from identity.roles r where r.code = 'owner';
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '6c200000-0000-4000-8000-000000000002', r.id, '4c100000-0000-4000-8000-000000000001' from identity.roles r where r.code = 'cashier';
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '6c200000-0000-4000-8000-000000000003', r.id, '4c100000-0000-4000-8000-000000000001' from identity.roles r where r.code = 'cashier';

insert into hr.employment_records (staff_id, hired_on)
values
  ('6c200000-0000-4000-8000-000000000002', '2026-01-01'),
  ('6c200000-0000-4000-8000-000000000003', '2026-01-01')
on conflict (staff_id) do nothing;

select set_config('request.jwt.claims',
  '{"sub":"5c200000-0000-4000-8000-000000000005","role":"authenticated","aud":"authenticated"}', true);

-- Salary so a future advance is recoverable.
select public.admin_hr_set_compensation(
  '6c200000-0000-4000-8000-000000000002', 6500, 0, 0, 0, '2026-01-01', 'راتب');

-- (1) An approved adjustment with a PAST due date and no run → deferred.
select public.admin_hr_create_adjustment(
  '6c200000-0000-4000-8000-000000000002', 'bonus', 200, 'مكافأة فاتت', '2026-09-01', null);
select set_config('test.adj_past',
  (select id::text from hr.adjustments where reason = 'مكافأة فاتت'), true);
select public.admin_hr_review_adjustment(
  current_setting('test.adj_past')::uuid, true, 'اعتماد فائت');

-- (2) An approved adjustment dated NEXT month → upcoming, not deferred.
select public.admin_hr_create_adjustment(
  '6c200000-0000-4000-8000-000000000002', 'allowance', 100, 'بدل قادم',
  (date_trunc('month', current_date) + interval '1 month + 5 days')::date, null);
select set_config('test.adj_future',
  (select id::text from hr.adjustments where reason = 'بدل قادم'), true);
select public.admin_hr_review_adjustment(
  current_setting('test.adj_future')::uuid, true, 'اعتماد قادم');

-- (3) A disbursed advance with outstanding money → outstanding section.
select set_config('request.jwt.claims',
  '{"sub":"5c200000-0000-4000-8000-000000000002","role":"authenticated","aud":"authenticated"}', true);
select public.hr_request_advance(1200, 300, 'سلفة للتقرير');
select set_config('test.adv',
  (select id::text from hr.salary_advances where reason = 'سلفة للتقرير'), true);

select set_config('request.jwt.claims',
  '{"sub":"5c200000-0000-4000-8000-000000000005","role":"authenticated","aud":"authenticated"}', true);
select public.admin_hr_review_advance(
  current_setting('test.adv')::uuid, true, 300, 'اعتماد قسط');
select public.admin_hr_disburse_advance(
  current_setting('test.adv')::uuid, 'صرف');

-- ---------------------------------------------------------------------------
-- The report as the finance holder.
-- ---------------------------------------------------------------------------
do $$
declare v jsonb;
begin
  v := public.admin_hr_finance_exceptions();

  if (select count(*) from jsonb_array_elements(v -> 'deferred_adjustments')
       where value ->> 'id' = current_setting('test.adj_past')::text) <> 1 then
    raise exception 'FAIL 1: the deferred adjustment is missing from the report';
  end if;
  if (select count(*) from jsonb_array_elements(v -> 'upcoming_adjustments')
       where value ->> 'id' = current_setting('test.adj_future')::text) <> 1 then
    raise exception 'FAIL 2: the upcoming adjustment is missing from the report';
  end if;
  if (select count(*) from jsonb_array_elements(v -> 'outstanding_advances')
       where value ->> 'id' = current_setting('test.adv')::text
         and (value ->> 'outstanding')::numeric = 1200) <> 1 then
    raise exception 'FAIL 3: the outstanding advance is missing or wrong';
  end if;
  if jsonb_array_length(v -> 'terminated_open') <> 0 then
    raise exception 'FAIL 4: no terminated employee exists in the fixture';
  end if;
  perform set_config('test.deferred_seen', '1', true);
  perform set_config('test.upcoming_seen', '1', true);
  perform set_config('test.outstanding_seen', '1', true);
end $$;

-- ---------------------------------------------------------------------------
-- A cashier with no finance permission is refused.
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"5c200000-0000-4000-8000-000000000003","role":"authenticated","aud":"authenticated"}', true);
do $$
begin
  begin
    perform public.admin_hr_finance_exceptions();
    raise exception 'FAIL 5: a cashier read the finance exceptions report';
  exception
    when others then
      if sqlstate <> '42501' then raise; end if;
      if sqlerrm not like '%missing permission: hr.finance.adjust%' then raise; end if;
  end;
end $$;

-- A signed-in customer is refused before any code is consulted.
select set_config('request.jwt.claims',
  '{"sub":"5c200000-0000-4000-8000-000000000004","role":"authenticated","aud":"authenticated"}', true);
do $$
begin
  begin
    perform public.admin_hr_finance_exceptions();
    raise exception 'FAIL 6: a customer read the finance exceptions report';
  exception
    when others then
      if sqlstate <> '42501' then raise; end if;
      if sqlerrm not like '%not authenticated%' then raise; end if;
  end;
end $$;

-- The report a runner prints.
select
  'reached the end: no assertion failed' as verdict,
  current_setting('test.deferred_seen', true) as deferred_seen,
  current_setting('test.upcoming_seen', true) as upcoming_seen,
  current_setting('test.outstanding_seen', true) as outstanding_seen;

rollback;
