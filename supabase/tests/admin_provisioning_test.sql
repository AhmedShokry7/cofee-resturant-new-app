-- admin_provisioning_test.sql
-- Behaviour tests for identity.provision_staff (migration 080).
-- RUN ONLY ON AN ISOLATED, NON-PRODUCTION DATABASE.

\set ON_ERROR_STOP on

begin;

insert into core.branches (id, brand_id, code, name_ar, name_en, address, is_active, settings)
values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '00000000-0000-4000-8000-000000000001', 'PA', 'فرع A', 'Branch A', 'addrA', true, '{}'::jsonb),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', '00000000-0000-4000-8000-000000000001', 'PB', 'فرع B', 'Branch B', 'addrB', true, '{}'::jsonb);

insert into auth.users (id, email)
values
  ('11111111-1111-4111-8111-111111111111', 'prov-owner@test.local'),
  ('22222222-2222-4222-8222-222222222222', 'prov-new@test.local'),
  ('33333333-3333-4333-8333-333333333333', 'prov-manager@test.local');

insert into identity.staff_members (id, user_id, status, full_name, email)
values
  ('aaaaaaaa-0000-4000-8000-000000000001', '11111111-1111-4111-8111-111111111111', 'active', 'Owner', 'prov-owner@test.local');

insert into identity.staff_roles (staff_id, role_id, branch_id)
select 'aaaaaaaa-0000-4000-8000-000000000001', r.id, null
from identity.roles r where r.code = 'owner';

insert into identity.staff_members (id, user_id, status, full_name, email)
values
  ('bbbbbbbb-0000-4000-8000-000000000002', '33333333-3333-4333-8333-333333333333', 'active', 'Manager', 'prov-manager@test.local');

insert into identity.staff_roles (staff_id, role_id, branch_id)
select 'bbbbbbbb-0000-4000-8000-000000000002', r.id, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'::uuid
from identity.roles r where r.code = 'manager';

-- ---------------------------------------------------------------------------
-- 1. Owner provisions a new manager for branch A (success)
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated","aud":"authenticated"}', true);

select identity.provision_staff(
  '22222222-2222-4222-8222-222222222222'::uuid,
  'New Staff',
  'prov-new@test.local',
  'manager',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'::uuid
);

do $$
begin
  if not exists (select 1 from identity.staff_members where user_id = '22222222-2222-4222-8222-222222222222'::uuid and status = 'invited') then
    raise exception 'FAIL: provisioned staff not created';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 2. Manager cannot provision an owner
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"33333333-3333-4333-8333-333333333333","role":"authenticated","aud":"authenticated"}', true);

do $$
begin
  perform identity.provision_staff(
    '22222222-2222-4222-8222-222222222222'::uuid,
    'Escalation',
    'prov-new@test.local',
    'owner',
    null
  );
  raise exception 'FAIL: manager provisioned owner';
exception
  when others then
    if sqlstate <> '42501' then raise; end if;
end $$;

-- ---------------------------------------------------------------------------
-- 3. Manager cannot assign a role for a branch they do not manage
-- ---------------------------------------------------------------------------
do $$
begin
  perform identity.provision_staff(
    '22222222-2222-4222-8222-222222222222'::uuid,
    'Cross Branch',
    'prov-new@test.local',
    'cashier',
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'::uuid
  );
  raise exception 'FAIL: cross-branch provisioning succeeded';
exception
  when others then
    if sqlstate <> '42501' then raise; end if;
end $$;

reset role;

rollback;
