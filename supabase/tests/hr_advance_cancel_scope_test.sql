-- hr_advance_cancel_scope_test.sql
-- Behaviour test for 213_hr_advance_cancel_staff_scope.PROPOSED.sql: the staff
-- scope guard of public.admin_hr_cancel_advance, on top of the HR model of
-- 212_hr_workforce.sql.
--
-- STATUS: EXECUTED AND PASSED on 2026-10-31 against the live project
-- webzzasosevzymftgszn, inside one transaction that also applied the 213 function
-- replacement and then rolled both back. The report row came back exactly as the
-- EXPECTED REPORT below: verdict 'reached the end: no assertion failed',
-- statuses_a1_to_a8 'cancelled,cancelled,disbursed,cancelled,cancelled,cancelled,cancelled,pending',
-- fixture_cancellations = 6, cancel_audit_rows = 6. The residue check after the
-- rollback found 0 fixture branches, 0 fixture staff rows, 0 fixture advances and
-- `admin_hr_cancel_advance` still without the guard — so 213 remains a proposal,
-- not a deployed change.
--
-- One defect was found by running it: section 6 made its two cancels as branch 2's
-- finance holder but inherited branch 1's claims from section 5, so the new guard
-- refused them (42501 'staff member out of scope'). The claims switch that section
-- needed is now in the file, outside the block.
--
-- Against the unpatched function section 3 FAILS on purpose, which is exactly the
-- defect being reported. Keep the discipline of supabase/tests/hr_workforce_test.sql:
-- one transaction, every fixture destroyed by the final rollback, and the report
-- row recorded here so the next reader knows what was actually observed.
--
-- RUN ONLY AGAINST AN ISOLATED, NON-PRODUCTION DATABASE (or a rehearsal
-- transaction like the one above) that already has 212 and the 213 replacement.
-- Plain SQL for the Supabase SQL Editor or psql. Every assertion runs as the real
-- authenticated role with real JWT claims, so the authorization arms are executed
-- rather than asserted about.
--
-- PREREQUISITES: 004/013/018/123/137 (identity, RBAC helpers and the role matrix),
-- 212 (the hr schema, its 36 definer RPCs and the hr.* permission codes) and the
-- 213 body of public.admin_hr_cancel_advance.
--
-- EXPECTED REPORT ON A PASS
--   statuses_a1_to_a8 = 'cancelled,cancelled,disbursed,cancelled,cancelled,cancelled,cancelled,pending'
--   (A3 stays disbursed with 100.00 recovered and A8 stays pending: both were
--   only ever attacked, never legitimately closed),
--   fixture_cancellations = 6, cancel_audit_rows = 6.
--
-- WHAT THIS PROVES, IN ORDER
--   1  the read side already scopes advances, so an out-of-scope manager never
--      sees the row this test then tries to cancel
--   2  admin_hr_review_advance refuses a foreign-branch advance — the guard 212
--      already has, and the pattern 213 copies
--   3  admin_hr_cancel_advance now refuses it too, and its sibling
--      admin_hr_disburse_advance still refuses it, on the same advance
--   4  the refusal writes nothing: the advance keeps its status and note, and no
--      hr.advance.cancel audit row exists
--   5  the in-scope finance holder still cancels, and that cancel is audited
--   6  the other branch's finance holder can still cancel the same advance, so
--      nobody is stranded by the guard
--   7  a self-cancel still works: can_access_staff passes on the caller's own id
--      before any branch comparison, so the guard cannot lock an employee out of
--      their own pending request
--   8  the guard sits LAST: the disbursed-needs-finance and already-recovered
--      refusals still answer first, in the same order as before 213
--   9  a global scope (manager with a NULL branch, and the owner) is unchanged
--  10  the arms that existed before 213 keep their own messages: a plain staff
--      member with no finance permission, an unknown advance id, a signed-in
--      customer
--
-- WHAT IS NOT TESTED HERE
--   Payroll settlement (a settled advance belongs to a payroll run, which is
--   212's own section 8 territory) and concurrency: the FOR UPDATE this function
--   already takes serialises two cancels of the same row, and a single session
--   cannot observe that.

begin;

-- ---------------------------------------------------------------------------
-- Fixtures: two branches, seven staff with five different reaches, one customer.
-- The uuid prefixes (4f/5c/6f) are unique to this file so a scratch database can
-- hold another rehearsal's fixtures at the same time.
-- ---------------------------------------------------------------------------
insert into core.branches (id, brand_id, code, name_ar, name_en, address, is_active, settings)
values
  ('4f100000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000001', 'CS-B1', 'فرع الحرس 1', 'Cancel Scope Branch 1', 'addr1', true, '{}'::jsonb),
  ('4f200000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000001', 'CS-B2', 'فرع الحرس 2', 'Cancel Scope Branch 2', 'addr2', true, '{}'::jsonb);

insert into auth.users (id, email)
values
  ('5c100000-0000-4000-8000-000000000001', 'cs-owner@test.local'),
  ('5c100000-0000-4000-8000-000000000002', 'cs-global@test.local'),
  ('5c100000-0000-4000-8000-000000000003', 'cs-finance-1@test.local'),
  ('5c100000-0000-4000-8000-000000000004', 'cs-finance-2@test.local'),
  ('5c100000-0000-4000-8000-000000000005', 'cs-emp-1@test.local'),
  ('5c100000-0000-4000-8000-000000000006', 'cs-emp-2@test.local'),
  ('5c100000-0000-4000-8000-000000000007', 'cs-emp-3@test.local'),
  ('5c100000-0000-4000-8000-000000000008', 'cs-emp-4@test.local'),
  ('5c100000-0000-4000-8000-000000000009', 'cs-customer@test.local');

insert into identity.profiles (id, full_name, email, phone)
values ('5c100000-0000-4000-8000-000000000009', 'CS Customer', 'cs-customer@test.local', '0500000009')
on conflict (id) do nothing;

insert into identity.staff_members (id, user_id, status, full_name, email)
values
  ('6f100000-0000-4000-8000-000000000001', '5c100000-0000-4000-8000-000000000001', 'active', 'CS Owner',        'cs-owner@test.local'),
  ('6f100000-0000-4000-8000-000000000002', '5c100000-0000-4000-8000-000000000002', 'active', 'CS Global',       'cs-global@test.local'),
  ('6f100000-0000-4000-8000-000000000003', '5c100000-0000-4000-8000-000000000003', 'active', 'CS Finance One',  'cs-finance-1@test.local'),
  ('6f100000-0000-4000-8000-000000000004', '5c100000-0000-4000-8000-000000000004', 'active', 'CS Finance Two',  'cs-finance-2@test.local'),
  ('6f100000-0000-4000-8000-000000000005', '5c100000-0000-4000-8000-000000000005', 'active', 'CS Emp One',      'cs-emp-1@test.local'),
  ('6f100000-0000-4000-8000-000000000006', '5c100000-0000-4000-8000-000000000006', 'active', 'CS Emp Two',      'cs-emp-2@test.local'),
  ('6f100000-0000-4000-8000-000000000007', '5c100000-0000-4000-8000-000000000007', 'active', 'CS Emp Three',    'cs-emp-3@test.local'),
  ('6f100000-0000-4000-8000-000000000008', '5c100000-0000-4000-8000-000000000008', 'active', 'CS Emp Four',     'cs-emp-4@test.local');

-- A NULL branch on staff_roles is what identity.manages_all_branches() reads, so
-- it is the whole difference between the two global shapes and the two branch
-- finance holders. hr.finance.adjust reaches branch_manager through 212:5782, so
-- these fixtures need no extra role of their own.
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '6f100000-0000-4000-8000-000000000001', r.id, null from identity.roles r where r.code = 'owner';
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '6f100000-0000-4000-8000-000000000002', r.id, null from identity.roles r where r.code = 'manager';
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '6f100000-0000-4000-8000-000000000003', r.id, '4f100000-0000-4000-8000-000000000001' from identity.roles r where r.code = 'branch_manager';
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '6f100000-0000-4000-8000-000000000004', r.id, '4f200000-0000-4000-8000-000000000002' from identity.roles r where r.code = 'branch_manager';
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '6f100000-0000-4000-8000-000000000005', r.id, '4f100000-0000-4000-8000-000000000001' from identity.roles r where r.code = 'cashier';
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '6f100000-0000-4000-8000-000000000006', r.id, '4f200000-0000-4000-8000-000000000002' from identity.roles r where r.code = 'cashier';
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '6f100000-0000-4000-8000-000000000007', r.id, '4f100000-0000-4000-8000-000000000001' from identity.roles r where r.code = 'cashier';
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '6f100000-0000-4000-8000-000000000008', r.id, '4f200000-0000-4000-8000-000000000002' from identity.roles r where r.code = 'cashier';

set local role authenticated;

-- ---------------------------------------------------------------------------
-- 0. The four advances the fixtures open up front, each by its own employee.
--    A1 Emp One (branch 1) pending
--    A2 Emp Two (branch 2) pending        — the row branch 1 must not cancel
--    A3 Emp Three (branch 1) pending
--    A5 Emp Four (branch 2) pending       — approved below, then branch 1 tries it
--    hr_request_advance refuses a second open request for the same person, so
--    every later advance for an employee comes after theirs closed.
-- ---------------------------------------------------------------------------
-- Each request runs as its own employee. The claims are set outside the block on
-- purpose: a DO block that raises discards every write it made, and a local
-- setting made inside it goes with them.
select set_config('request.jwt.claims',
  '{"sub":"5c100000-0000-4000-8000-000000000005","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v jsonb;
begin
  v := public.hr_request_advance(900, null, 'ظرف عائلي');
  perform set_config('test.a1', v ->> 'id', true);
end $$;

select set_config('request.jwt.claims',
  '{"sub":"5c100000-0000-4000-8000-000000000006","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v jsonb;
begin
  v := public.hr_request_advance(1200, null, 'إصلاح سيارة');
  perform set_config('test.a2', v ->> 'id', true);
end $$;

select set_config('request.jwt.claims',
  '{"sub":"5c100000-0000-4000-8000-000000000007","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v jsonb;
begin
  v := public.hr_request_advance(600, null, 'مصروف مدرسي');
  perform set_config('test.a3', v ->> 'id', true);
end $$;

select set_config('request.jwt.claims',
  '{"sub":"5c100000-0000-4000-8000-000000000008","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v jsonb;
begin
  v := public.hr_request_advance(750, null, 'سداد إيجار');
  perform set_config('test.a5', v ->> 'id', true);
end $$;

do $$
begin
  if current_setting('test.a1') is null or current_setting('test.a5') is null then
    raise exception 'FAIL 0: an advance request did not open';
  end if;
end $$;

-- Finance One approves A1 (their own branch) and Finance Two approves A5 (their
-- own branch), because section 3 needs A5 in the state the pre-213 attack needed:
-- approved, money not yet handed over, and a caller from the other branch.
select set_config('request.jwt.claims',
  '{"sub":"5c100000-0000-4000-8000-000000000003","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v jsonb;
begin
  v := public.admin_hr_review_advance(current_setting('test.a1')::uuid, true, null, 'معتمد من فرع ١');
  if (v ->> 'status') <> 'approved' then
    raise exception 'FAIL 0: the in-scope approval of A1 returned %', v ->> 'status';
  end if;
end $$;

select set_config('request.jwt.claims',
  '{"sub":"5c100000-0000-4000-8000-000000000004","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v jsonb;
begin
  v := public.admin_hr_review_advance(current_setting('test.a5')::uuid, true, null, 'معتمد من فرع ٢');
  if (v ->> 'status') <> 'approved' then
    raise exception 'FAIL 0: the in-scope approval of A5 returned %', v ->> 'status';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 1. The read side already scopes advances (212:4327).
--    Finance One sees A1 and not A2, so the row section 3 attacks is one this
--    administrator can never reach through the screen.
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"5c100000-0000-4000-8000-000000000003","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v jsonb;
begin
  v := public.admin_hr_advances(null, null, 50);
  if v is null or jsonb_array_length(v) = 0 then
    raise exception 'FAIL 1: the finance holder of branch 1 saw no advance at all';
  end if;
  if not exists (select 1 from jsonb_array_elements(v) r where r ->> 'id' = current_setting('test.a1')) then
    raise exception 'FAIL 1: A1, an advance of branch 1, is missing from the list';
  end if;
  if exists (select 1 from jsonb_array_elements(v) r where r ->> 'id' = current_setting('test.a2')) then
    raise exception 'FAIL 1: the list of branch 1 leaked an advance of branch 2';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 2. admin_hr_review_advance already refuses a foreign-branch advance.
--    This is the guard 213 copies, asserted first so a red section 3 cannot be
--    blamed on the helper being broken.
-- ---------------------------------------------------------------------------
do $$
begin
  perform public.admin_hr_review_advance(current_setting('test.a2')::uuid, true, null, 'محاولة من فرع ١');
  raise exception 'FAIL 2: a branch-1 finance holder reviewed a branch-2 advance';
exception
  when others then
    if sqlstate <> '42501' then raise; end if;
    if sqlerrm not like '%staff member out of scope%' then raise; end if;
end $$;

-- ---------------------------------------------------------------------------
-- 3. THE GUARD: admin_hr_cancel_advance now refuses it too — and its sibling
--    admin_hr_disburse_advance still does, on the same approved A5 row. Before
--    213 this section is the defect: the disburse was refused and the cancel
--    succeeded on one and the same advance.
-- ---------------------------------------------------------------------------
do $$
begin
  perform public.admin_hr_disburse_advance(current_setting('test.a5')::uuid, 'محاولة تسليم من فرع ١');
  raise exception 'FAIL 3a: a branch-1 finance holder disbursed a branch-2 advance';
exception
  when others then
    if sqlstate <> '42501' then raise; end if;
    if sqlerrm not like '%staff member out of scope%' then raise; end if;
end $$;

do $$
begin
  perform public.admin_hr_cancel_advance(current_setting('test.a5')::uuid, 'محاولة إلغاء من فرع ١');
  raise exception 'FAIL 3b: 213 did not take effect — a branch-1 finance holder cancelled the approved advance of a branch-2 employee';
exception
  when others then
    if sqlstate <> '42501' then raise; end if;
    if sqlerrm not like '%staff member out of scope%' then raise; end if;
end $$;

-- The same on a pending advance, because cancel is reachable in that state too.
do $$
begin
  perform public.admin_hr_cancel_advance(current_setting('test.a2')::uuid, 'محاولة إلغاء من فرع ١');
  raise exception 'FAIL 3c: a branch-1 finance holder cancelled a pending branch-2 advance';
exception
  when others then
    if sqlstate <> '42501' then raise; end if;
    if sqlerrm not like '%staff member out of scope%' then raise; end if;
end $$;

-- ---------------------------------------------------------------------------
-- 4. The refusals left nothing behind.
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"5c100000-0000-4000-8000-000000000004","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v jsonb;
begin
  v := public.admin_hr_advances(null, null, 50);
  if not exists (select 1 from jsonb_array_elements(v) r
                  where r ->> 'id' = current_setting('test.a2') and r ->> 'status' = 'pending') then
    raise exception 'FAIL 4: A2 is no longer the pending advance the branch-1 refusals found';
  end if;
  if not exists (select 1 from jsonb_array_elements(v) r
                  where r ->> 'id' = current_setting('test.a5') and r ->> 'status' = 'approved') then
    raise exception 'FAIL 4: the refused cancel moved A5 out of approved';
  end if;
  if exists (select 1 from jsonb_array_elements(v) r
              where r ->> 'id' = current_setting('test.a5')
                and r ->> 'review_note' = 'محاولة إلغاء من فرع ١') then
    raise exception 'FAIL 4: the refused cancel wrote its note onto A5';
  end if;
end $$;

reset role;

do $$
declare c bigint;
begin
  select count(*) into c from identity.audit_log
   where action = 'hr.advance.cancel'
     and entity_id in (current_setting('test.a2')::uuid, current_setting('test.a5')::uuid);
  if c <> 0 then
    raise exception 'FAIL 4: the refused cancels left % audit row(s) for hr.advance.cancel', c;
  end if;
end $$;

set local role authenticated;

-- ---------------------------------------------------------------------------
-- 5. The in-scope finance holder still cancels, and that cancel is audited.
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"5c100000-0000-4000-8000-000000000003","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v jsonb;
begin
  v := public.admin_hr_cancel_advance(current_setting('test.a1')::uuid, 'أُلغي بأمر المدير');
  if v is null or (v ->> 'status') <> 'cancelled' then
    raise exception 'FAIL 5: the in-scope finance holder could not cancel A1 (% )', v;
  end if;
end $$;

reset role;

do $$
begin
  if not exists (select 1 from identity.audit_log
                  where action = 'hr.advance.cancel'
                    and entity_id = current_setting('test.a1')::uuid
                    and actor_user_id = '5c100000-0000-4000-8000-000000000003') then
    raise exception 'FAIL 5: the accepted cancel of A1 was not audited to its actor';
  end if;
end $$;

set local role authenticated;

-- ---------------------------------------------------------------------------
-- 6. Nobody is stranded: the finance holder of the target's own branch still
--    cancels both advances that branch 1 was refused on.
-- ---------------------------------------------------------------------------
-- The claims still carry branch 1's holder from section 5. These two calls are
-- made by branch 2's holder, so they need their own statement outside the block.
select set_config('request.jwt.claims',
  '{"sub":"5c100000-0000-4000-8000-000000000004","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v jsonb;
begin
  v := public.admin_hr_cancel_advance(current_setting('test.a5')::uuid, 'أُلغي بأمر مدير فرع ٢');
  if v is null or (v ->> 'status') <> 'cancelled' then
    raise exception 'FAIL 6a: the branch-2 finance holder could not cancel its own A5';
  end if;
  v := public.admin_hr_cancel_advance(current_setting('test.a2')::uuid, 'أُلغي بأمر مدير فرع ٢');
  if v is null or (v ->> 'status') <> 'cancelled' then
    raise exception 'FAIL 6b: the branch-2 finance holder could not cancel its own A2';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 7. A self-cancel still works.
--    hr.can_access_staff passes on me.id = p_staff_id before any branch
--    comparison, so the guard cannot lock an employee out of their own request.
--    Emp One is free again after A1 closed.
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"5c100000-0000-4000-8000-000000000005","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v jsonb;
begin
  v := public.hr_request_advance(300, null, 'طلب ثانٍ بعد الإلغاء');
  perform set_config('test.a4', v ->> 'id', true);
  if v is null or (v ->> 'status') <> 'pending' then
    raise exception 'FAIL 7: the second request of Emp One did not open';
  end if;
end $$;

do $$
declare v jsonb;
begin
  v := public.admin_hr_cancel_advance(current_setting('test.a4')::uuid, 'عدلت عن الطلب');
  if v is null or (v ->> 'status') <> 'cancelled' then
    raise exception 'FAIL 7: an employee could not cancel their own pending advance (%)', v;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 8. The guard runs LAST, so the refusals that used to answer still do.
--    8a: an out-of-scope finance holder meets the money reason, not the scope.
--    8b: the requester of a disbursed advance without finance permission gets
--        the finance sentence, which sits before the new line.
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"5c100000-0000-4000-8000-000000000003","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v jsonb;
begin
  v := public.admin_hr_review_advance(current_setting('test.a3')::uuid, true, 300, 'معتمد');
  if (v ->> 'status') <> 'approved' then
    raise exception 'FAIL 8: A3 was not approved (%)', v ->> 'status';
  end if;
end $$;

do $$
declare v jsonb;
begin
  v := public.admin_hr_disburse_advance(current_setting('test.a3')::uuid, 'سلّم نقدًا');
  if (v ->> 'status') <> 'disbursed' then
    raise exception 'FAIL 8: A3 was not disbursed (%)', v ->> 'status';
  end if;
end $$;

select set_config('request.jwt.claims',
  '{"sub":"5c100000-0000-4000-8000-000000000007","role":"authenticated","aud":"authenticated"}', true);

do $$
begin
  perform public.admin_hr_cancel_advance(current_setting('test.a3')::uuid, 'الموظف يريد الإلغاء');
  raise exception 'FAIL 8a: the requester cancelled their own disbursed advance without finance permission';
exception
  when others then
    if sqlstate <> '42501' then raise; end if;
    if sqlerrm not like '%can only be cancelled by finance%' then raise; end if;
end $$;

-- A partially recovered advance, written the way payroll would have written it.
-- This is a fixture, not a claim about the payroll RPCs: only a real run settles
-- an advance, and section 8 only needs the column value the guard reads.
reset role;
update hr.salary_advances
   set settled_amount = 100.00
 where id = current_setting('test.a3')::uuid;
set local role authenticated;

select set_config('request.jwt.claims',
  '{"sub":"5c100000-0000-4000-8000-000000000004","role":"authenticated","aud":"authenticated"}', true);

do $$
begin
  perform public.admin_hr_cancel_advance(current_setting('test.a3')::uuid, 'محاولة من فرع ٢');
  raise exception 'FAIL 8b: an out-of-scope caller cancelled a partly recovered advance';
exception
  when others then
    if sqlstate <> '23514' then raise; end if;
    if sqlerrm not like '%part of this advance is already recovered%' then raise; end if;
end $$;

-- ---------------------------------------------------------------------------
-- 9. A global scope is unchanged: manager with a NULL branch, then the owner.
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"5c100000-0000-4000-8000-000000000008","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v jsonb;
begin
  v := public.hr_request_advance(450, null, 'طلب رابع');
  perform set_config('test.a6', v ->> 'id', true);
  if v is null or (v ->> 'status') <> 'pending' then
    raise exception 'FAIL 9: the second request of Emp Four did not open';
  end if;
end $$;

select set_config('request.jwt.claims',
  '{"sub":"5c100000-0000-4000-8000-000000000002","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v jsonb;
begin
  v := public.admin_hr_cancel_advance(current_setting('test.a6')::uuid, 'ألغاه مدير العلامة');
  if v is null or (v ->> 'status') <> 'cancelled' then
    raise exception 'FAIL 9a: the brand manager lost a cancel it was always allowed (%)', v;
  end if;
end $$;

select set_config('request.jwt.claims',
  '{"sub":"5c100000-0000-4000-8000-000000000008","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v jsonb;
begin
  v := public.hr_request_advance(500, null, 'طلب خامس');
  perform set_config('test.a7', v ->> 'id', true);
end $$;

select set_config('request.jwt.claims',
  '{"sub":"5c100000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v jsonb;
begin
  v := public.admin_hr_cancel_advance(current_setting('test.a7')::uuid, 'ألغاه المالك');
  if v is null or (v ->> 'status') <> 'cancelled' then
    raise exception 'FAIL 9b: the owner lost a cancel it was always allowed (%)', v;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 10. The arms that existed before 213 keep their own answers.
--     A7 is cancelled, so Emp Four opens A8 as the target of these calls.
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"5c100000-0000-4000-8000-000000000008","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v jsonb;
begin
  v := public.hr_request_advance(200, null, 'طلب سادس');
  perform set_config('test.a8', v ->> 'id', true);
end $$;

-- A plain cashier of the other branch: no hr.finance.adjust at all, so the
-- pre-existing 'advance out of scope' answers before the new line is reached.
select set_config('request.jwt.claims',
  '{"sub":"5c100000-0000-4000-8000-000000000005","role":"authenticated","aud":"authenticated"}', true);

do $$
begin
  perform public.admin_hr_cancel_advance(current_setting('test.a8')::uuid, 'محاولة كاشير');
  raise exception 'FAIL 10a: a cashier cancelled another employee''s advance';
exception
  when others then
    if sqlstate <> '42501' then raise; end if;
    if sqlerrm not like '%advance out of scope%' then raise; end if;
end $$;

-- An id that is not an advance.
do $$
begin
  perform public.admin_hr_cancel_advance('00000000-0000-4000-8000-000000000000'::uuid, 'لا شيء');
  raise exception 'FAIL 10b: an unknown advance id was accepted';
exception
  when others then
    if sqlstate <> 'P0002' then raise; end if;
    if sqlerrm not like '%advance not found%' then raise; end if;
end $$;

-- A signed-in customer is not staff.
select set_config('request.jwt.claims',
  '{"sub":"5c100000-0000-4000-8000-000000000009","role":"authenticated","aud":"authenticated"}', true);

do $$
begin
  perform public.admin_hr_cancel_advance(current_setting('test.a8')::uuid, 'العميل');
  raise exception 'FAIL 10c: a customer reached the advance cancel RPC';
exception
  when others then
    if sqlstate <> '42501' then raise; end if;
    if sqlerrm not like '%not authenticated%' then raise; end if;
end $$;

-- Only the owner reads these tables: every assertion above ran as the
-- authenticated role, which has no table privileges at all, which is the point.
reset role;

-- Every section above raises on the first mismatch, so reaching this line is
-- itself the proof. This row is the report a runner prints. The transaction
-- still rolls back, so none of it stays in the database.
-- Every fixture shares the transaction timestamp, so created_at cannot order
-- them; the report names each advance by its fixture id instead.
select
  'reached the end: no assertion failed' as verdict,
  (select string_agg(fx.status_text, ',' order by fx.n)
     from (
       select 1 as n, a.status as status_text from hr.salary_advances a where a.id = current_setting('test.a1')::uuid
       union all select 2, a.status from hr.salary_advances a where a.id = current_setting('test.a2')::uuid
       union all select 3, a.status from hr.salary_advances a where a.id = current_setting('test.a3')::uuid
       union all select 4, a.status from hr.salary_advances a where a.id = current_setting('test.a4')::uuid
       union all select 5, a.status from hr.salary_advances a where a.id = current_setting('test.a5')::uuid
       union all select 6, a.status from hr.salary_advances a where a.id = current_setting('test.a6')::uuid
       union all select 7, a.status from hr.salary_advances a where a.id = current_setting('test.a7')::uuid
       union all select 8, a.status from hr.salary_advances a where a.id = current_setting('test.a8')::uuid
     ) fx) as statuses_a1_to_a8,
  -- Measured against the fixture ids, not the table: the live database may
  -- already hold advances and audit rows of its own.
  (select count(*) from hr.salary_advances a
    where a.status = 'cancelled'
      and a.id in (current_setting('test.a1')::uuid, current_setting('test.a2')::uuid,
                   current_setting('test.a4')::uuid, current_setting('test.a5')::uuid,
                   current_setting('test.a6')::uuid, current_setting('test.a7')::uuid)) as fixture_cancellations,
  (select count(*) from identity.audit_log l
    where l.action = 'hr.advance.cancel'
      and l.entity_id in (current_setting('test.a1')::uuid, current_setting('test.a2')::uuid,
                          current_setting('test.a4')::uuid, current_setting('test.a5')::uuid,
                          current_setting('test.a6')::uuid, current_setting('test.a7')::uuid)) as cancel_audit_rows;

rollback;
