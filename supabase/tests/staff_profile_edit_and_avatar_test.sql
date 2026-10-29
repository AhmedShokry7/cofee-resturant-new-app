-- staff_profile_edit_and_avatar_test.sql
-- Behaviour test for 209_staff_profile_edit_and_avatar.sql: the dashboard can
-- edit a staff account it is entitled to edit, give it a picture, and cannot
-- edit one it is not.
--
-- HOW TO RUN
--   Plain SQL for the Supabase SQL Editor or psql, as the owner role. Everything
--   sits in one transaction that is rolled back at the end, so no fixture, no
--   audit row and no picture path survives the run. Against a database without
--   209 the RPCs are missing and the first scenario fails with "function does not
--   exist" — that is the expected answer.
--
-- WHY THE HELIPAD
--   Every scenario has to run AS a different staff account, so the session role
--   is `authenticated` with JWT claims pointing at that uid. The answer cannot be
--   collected by an expression written in the caller's statement: PostgreSQL
--   evaluates the arguments before the helper runs, so the claims would be one
--   scenario behind. Each helper therefore sets the claims first and calls the
--   RPC inside itself. They are SECURITY INVOKER, so the RLS of the storage and
--   staff tables is still measured against `authenticated`, not the test session.
--
-- WHAT EACH SECTION PROVES
--   1  scope: an owner edits anyone; a global manager edits staff but never an
--      owner; a branch manager reaches only staff of their own branch
--   2  the lockout guard: no one may change their own status, a name alone is
--      still editable
--   3  validation answers with a reason and writes nothing
--   4  status bookkeeping: suspended_at follows the status, and the edit is
--      audited
--   5  the picture: only a path inside staff/<that staff id>/ is accepted, and a
--      bad shape is refused as a reason rather than as a constraint error
--   6  the avatars bucket obeys the new policies: an admin reads and writes staff
--      folders, a cashier can do neither, and a customer folder is still closed
--   7  the direct table path is closed by the table privilege, and the guard the
--      new policy calls answers per account and per row
--   8  admin_staff() carries avatar_url without losing a field
--   9  the static end state: bucket private, policies shaped and closed to anon,
--      functions definer with an empty search_path and no anon grant

begin;

-- ---------------------------------------------------------------------------
-- Fixtures: two branches, five staff accounts across them, one plain customer.
--
-- The role matrix is the live one: only owner and manager hold admin.staff.*,
-- and admin.staff.* is what the helpers answer from.
-- ---------------------------------------------------------------------------
insert into core.branches (id, brand_id, code, name_ar, name_en, address, is_active, settings)
values
  ('574ffbb0-0000-4000-8000-000000000001',
   '00000000-0000-4000-8000-000000000001', 'EDIT-B1', 'فرع الاختبار', 'Edit Branch 1',
   'addr', true, '{}'::jsonb),
  ('574ffbb0-0000-4000-8000-000000000002',
   '00000000-0000-4000-8000-000000000001', 'EDIT-B2', 'فرع اختبار ثاني', 'Edit Branch 2',
   'addr', true, '{}'::jsonb);

insert into auth.users (id, email)
values
  ('574ff00d-0000-4000-8000-000000000001', 'edit-owner@test.local'),
  ('574ff00d-0000-4000-8000-000000000002', 'edit-global-manager@test.local'),
  ('574ff00d-0000-4000-8000-000000000003', 'edit-branch-manager@test.local'),
  ('574ff00d-0000-4000-8000-000000000004', 'edit-cashier-b1@test.local'),
  ('574ff00d-0000-4000-8000-000000000005', 'edit-cashier-b2@test.local'),
  ('574ff00d-0000-4000-8000-000000000006', 'edit-customer@test.local');

insert into identity.staff_members (id, user_id, status, full_name, email)
values
  ('574ff0de-0000-4000-8000-000000000001',
   '574ff00d-0000-4000-8000-000000000001', 'active', 'Platform Owner', 'edit-owner@test.local'),
  ('574ff0de-0000-4000-8000-000000000002',
   '574ff00d-0000-4000-8000-000000000002', 'active', 'Global Manager', 'edit-global-manager@test.local'),
  ('574ff0de-0000-4000-8000-000000000003',
   '574ff00d-0000-4000-8000-000000000003', 'active', 'Branch Manager One', 'edit-branch-manager@test.local'),
  ('574ff0de-0000-4000-8000-000000000004',
   '574ff00d-0000-4000-8000-000000000004', 'active', 'Cashier One', 'edit-cashier-b1@test.local'),
  ('574ff0de-0000-4000-8000-000000000005',
   '574ff00d-0000-4000-8000-000000000005', 'invited', 'Cashier Two', 'edit-cashier-b2@test.local');

insert into identity.staff_roles (staff_id, role_id, branch_id)
values
  ('574ff0de-0000-4000-8000-000000000001',
   (select id from identity.roles where code = 'owner'), null),
  ('574ff0de-0000-4000-8000-000000000002',
   (select id from identity.roles where code = 'manager'), null),
  ('574ff0de-0000-4000-8000-000000000003',
   (select id from identity.roles where code = 'manager'),
   '574ffbb0-0000-4000-8000-000000000001'),
  ('574ff0de-0000-4000-8000-000000000004',
   (select id from identity.roles where code = 'cashier'),
   '574ffbb0-0000-4000-8000-000000000001'),
  ('574ff0de-0000-4000-8000-000000000005',
   (select id from identity.roles where code = 'cashier'),
   '574ffbb0-0000-4000-8000-000000000002');

-- What every scenario answered with. The scenarios run as `authenticated`, so
-- the journal has to be reachable by that role: a temp table cannot be granted
-- to anyone, which is why this is an ordinary table created inside the same
-- transaction. The rollback removes the table, its rows and its grant together.
create table public.staff_edit_test_journal (
  step text primary key,
  result jsonb,
  error text,
  code text
);
-- This project runs an `ensure_rls` event trigger on ddl_command_end, which
-- enables RLS on every table a script creates. The journal holds the answers of
-- the scenarios themselves, so it is turned back off before it is granted.
alter table public.staff_edit_test_journal disable row level security;
grant select, insert on table public.staff_edit_test_journal to authenticated;

create or replace function pg_temp.become(p_uid uuid)
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims',
    jsonb_build_object('sub', p_uid::text, 'role', 'authenticated',
                       'aud', 'authenticated')::text, true);
end $$;

create or replace function pg_temp.journal_as(
  p_uid uuid, p_step text, p_result jsonb, p_error text default null)
returns void
language plpgsql
as $$
begin
  perform pg_temp.become(p_uid);
  insert into public.staff_edit_test_journal (step, result) values (p_step, p_result);
exception when others then
  insert into public.staff_edit_test_journal (step, error, code) values (p_step, sqlerrm, sqlstate);
end $$;

--- Runs admin_update_staff as the given account.
create or replace function pg_temp.edit_as(
  p_uid uuid, p_step text, p_target uuid,
  p_name text default null, p_email text default null, p_status text default null)
returns void
language plpgsql
as $$
begin
  perform pg_temp.become(p_uid);
  insert into public.staff_edit_test_journal (step, result)
  values (p_step, public.admin_update_staff(p_target, p_name, p_email, p_status));
exception when others then
  insert into public.staff_edit_test_journal (step, error, code) values (p_step, sqlerrm, sqlstate);
end $$;

--- Runs admin_set_staff_image as the given account.
create or replace function pg_temp.picture_as(
  p_uid uuid, p_step text, p_target uuid, p_path text)
returns void
language plpgsql
as $$
begin
  perform pg_temp.become(p_uid);
  insert into public.staff_edit_test_journal (step, result)
  values (p_step, public.admin_set_staff_image(p_target, p_path));
exception when others then
  insert into public.staff_edit_test_journal (step, error, code) values (p_step, sqlerrm, sqlstate);
end $$;

--- Counts the staff pictures of the bucket the given account can see.
---
--- Only the folders this script plants are counted: a real account may already
--- own a picture in `avatars/staff/<id>/`, and the number a policy lets through
--- must not depend on how many accounts happen to exist.
create or replace function pg_temp.read_photos_as(p_uid uuid, p_step text)
returns void
language plpgsql
as $$
declare v int;
begin
  perform pg_temp.become(p_uid);
  select count(*) into v from storage.objects
   where bucket_id = 'avatars' and name like 'staff/574ff0de%';
  insert into public.staff_edit_test_journal (step, result) values (p_step, jsonb_build_object('seen', v));
exception when others then
  insert into public.staff_edit_test_journal (step, error, code) values (p_step, sqlerrm, sqlstate);
end $$;

--- Puts an object in the bucket as the given account; the policy is the gate.
create or replace function pg_temp.write_photo_as(
  p_uid uuid, p_step text, p_object text)
returns void
language plpgsql
as $$
begin
  perform pg_temp.become(p_uid);
  insert into storage.objects (bucket_id, name, owner)
  values ('avatars', p_object, p_uid);
  insert into public.staff_edit_test_journal (step, result) values (p_step, jsonb_build_object('ok', true));
exception when others then
  insert into public.staff_edit_test_journal (step, error, code) values (p_step, sqlerrm, sqlstate);
end $$;

--- Updates a staff row through the table, and records how many rows RLS let go.
create or replace function pg_temp.raw_update_as(
  p_uid uuid, p_step text, p_target uuid)
returns void
language plpgsql
as $$
declare v int;
begin
  perform pg_temp.become(p_uid);
  update identity.staff_members
     set full_name = 'Through The Table'
   where id = p_target;
  get diagnostics v = row_count;
  insert into public.staff_edit_test_journal (step, result) values (p_step, jsonb_build_object('rows', v));
exception when others then
  insert into public.staff_edit_test_journal (step, error, code) values (p_step, sqlerrm, sqlstate);
end $$;

--- Reads the directory as the given account.
create or replace function pg_temp.directory_as(p_uid uuid, p_step text)
returns void
language plpgsql
as $$
begin
  perform pg_temp.become(p_uid);
  insert into public.staff_edit_test_journal (step, result) values (p_step, public.admin_staff());
exception when others then
  insert into public.staff_edit_test_journal (step, error, code) values (p_step, sqlerrm, sqlstate);
end $$;

--- Asks the guard the table policy calls, with that account's claims. The
--  function is executable by `authenticated`, so this is the same answer the
--  UPDATE policy would compute for the same row.
create or replace function pg_temp.guard_as(p_uid uuid, p_step text, p_target uuid)
returns void
language plpgsql
as $$
declare v boolean;
begin
  perform pg_temp.become(p_uid);
  select identity.can_edit_staff(p_target) into v;
  insert into public.staff_edit_test_journal (step, result)
  values (p_step, jsonb_build_object('allowed', v));
exception when others then
  insert into public.staff_edit_test_journal (step, error, code) values (p_step, sqlerrm, sqlstate);
end $$;

-- ---------------------------------------------------------------------------
-- 1. Scope.
-- ---------------------------------------------------------------------------
set local role authenticated;

select pg_temp.edit_as('574ff00d-0000-4000-8000-000000000001', 'owner_edits_cashier',
  '574ff0de-0000-4000-8000-000000000004', p_name := 'Cashier One Of B1');
select pg_temp.edit_as('574ff00d-0000-4000-8000-000000000002', 'global_edits_branch_manager',
  '574ff0de-0000-4000-8000-000000000003', p_name := 'Branch Manager Renamed');
select pg_temp.edit_as('574ff00d-0000-4000-8000-000000000003', 'branch_edits_own_cashier',
  '574ff0de-0000-4000-8000-000000000004', p_name := 'Cashier One Kept');
select pg_temp.edit_as('574ff00d-0000-4000-8000-000000000003', 'branch_edits_other_cashier',
  '574ff0de-0000-4000-8000-000000000005', p_name := 'Held Across Branches');
select pg_temp.edit_as('574ff00d-0000-4000-8000-000000000003', 'branch_edits_owner',
  '574ff0de-0000-4000-8000-000000000001', p_name := 'Held At The Top');
select pg_temp.edit_as('574ff00d-0000-4000-8000-000000000002', 'global_edits_owner',
  '574ff0de-0000-4000-8000-000000000001', p_name := 'Manager Rewrites Owner');
select pg_temp.edit_as('574ff00d-0000-4000-8000-000000000004', 'cashier_edits_peer',
  '574ff0de-0000-4000-8000-000000000005', p_name := 'Cashier Rewrites Peer');
select pg_temp.edit_as('574ff00d-0000-4000-8000-000000000006', 'customer_edits_staff',
  '574ff0de-0000-4000-8000-000000000004', p_name := 'Customer Rewrites Staff');
select pg_temp.edit_as('574ff00d-0000-4000-8000-000000000001', 'owner_edits_unknown',
  '574ff0de-0000-4000-8000-00000000dead', p_name := 'Nobody');

reset role;

do $$
declare v jsonb;
begin
  select result into v from public.staff_edit_test_journal where step = 'owner_edits_cashier';
  if v is distinct from jsonb_build_object('ok', true) then
    raise exception 'FAIL 1.1: an owner could not edit a cashier: % / %',
      v, (select error from public.staff_edit_test_journal where step = 'owner_edits_cashier');
  end if;

  select result into v from public.staff_edit_test_journal where step = 'global_edits_branch_manager';
  if v is distinct from jsonb_build_object('ok', true) then
    raise exception 'FAIL 1.2: a global manager could not edit a branch manager: %', v;
  end if;

  select result into v from public.staff_edit_test_journal where step = 'branch_edits_own_cashier';
  if v is distinct from jsonb_build_object('ok', true) then
    raise exception 'FAIL 1.3: a manager could not edit staff of their own branch: %', v;
  end if;

  if (select code from public.staff_edit_test_journal where step = 'branch_edits_other_cashier') <> '42501' then
    raise exception 'FAIL 1.4: a branch manager reached another branch: %',
      (select coalesce(code, 'accepted') from public.staff_edit_test_journal where step = 'branch_edits_other_cashier');
  end if;
  if exists (select 1 from identity.staff_members
              where id = '574ff0de-0000-4000-8000-000000000005'
                and full_name = 'Held Across Branches') then
    raise exception 'FAIL 1.4: the refused edit still changed the row';
  end if;

  if (select code from public.staff_edit_test_journal where step = 'branch_edits_owner') <> '42501' then
    raise exception 'FAIL 1.5: a branch manager reached an owner';
  end if;
  if (select code from public.staff_edit_test_journal where step = 'global_edits_owner') <> '42501' then
    raise exception 'FAIL 1.6: a manager reached an owner';
  end if;
  if (select code from public.staff_edit_test_journal where step = 'cashier_edits_peer') <> '42501' then
    raise exception 'FAIL 1.7: a cashier without admin.staff.write edited a peer';
  end if;
  if (select code from public.staff_edit_test_journal where step = 'customer_edits_staff') <> '42501' then
    raise exception 'FAIL 1.8: a customer reached a staff account';
  end if;
  if (select code from public.staff_edit_test_journal where step = 'owner_edits_unknown') <> '42501' then
    raise exception 'FAIL 1.9: an unknown staff id was not refused';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 2. The lockout guard: no one changes their own status; a name alone is fine.
-- ---------------------------------------------------------------------------
set local role authenticated;

select pg_temp.edit_as('574ff00d-0000-4000-8000-000000000001', 'self_suspend',
  '574ff0de-0000-4000-8000-000000000001', p_status := 'suspended');
select pg_temp.edit_as('574ff00d-0000-4000-8000-000000000001', 'self_rename',
  '574ff0de-0000-4000-8000-000000000001', p_name := 'Platform Owner Renamed');

reset role;

do $$
declare v jsonb;
begin
  select result into v from public.staff_edit_test_journal where step = 'self_suspend';
  if v is distinct from jsonb_build_object('ok', false, 'reason', 'self_status') then
    raise exception 'FAIL 2: an owner could suspend their own account: %', v;
  end if;
  if (select status from identity.staff_members
       where id = '574ff0de-0000-4000-8000-000000000001') <> 'active' then
    raise exception 'FAIL 2: the refused self-suspend changed the status anyway';
  end if;

  select result into v from public.staff_edit_test_journal where step = 'self_rename';
  if v is distinct from jsonb_build_object('ok', true) then
    raise exception 'FAIL 2: an owner could not rename their own account: %', v;
  end if;
  if (select full_name from identity.staff_members
       where id = '574ff0de-0000-4000-8000-000000000001') <> 'Platform Owner Renamed' then
    raise exception 'FAIL 2: the accepted self-rename did not reach the row';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 3. Validation answers with a reason and writes nothing.
-- ---------------------------------------------------------------------------
set local role authenticated;

select pg_temp.edit_as('574ff00d-0000-4000-8000-000000000001', 'short_name',
  '574ff0de-0000-4000-8000-000000000004', p_name := 'x');
select pg_temp.edit_as('574ff00d-0000-4000-8000-000000000001', 'blank_name',
  '574ff0de-0000-4000-8000-000000000004', p_name := '   ');
select pg_temp.edit_as('574ff00d-0000-4000-8000-000000000001', 'bad_email',
  '574ff0de-0000-4000-8000-000000000004', p_email := 'not-an-email');
select pg_temp.edit_as('574ff00d-0000-4000-8000-000000000001', 'taken_email',
  '574ff0de-0000-4000-8000-000000000004', p_email := 'edit-cashier-b2@test.local');
select pg_temp.edit_as('574ff00d-0000-4000-8000-000000000001', 'bad_status',
  '574ff0de-0000-4000-8000-000000000004', p_status := 'deleted');
-- Mixed case is stored the way the column demands it: lower case.
select pg_temp.edit_as('574ff00d-0000-4000-8000-000000000001', 'good_email',
  '574ff0de-0000-4000-8000-000000000004', p_email := 'Renamed.Cashier@TEST.local');

reset role;

do $$
declare v jsonb;
begin
  select result into v from public.staff_edit_test_journal where step = 'short_name';
  if v is distinct from jsonb_build_object('ok', false, 'reason', 'invalid_name') then
    raise exception 'FAIL 3: a one-letter name was accepted: %', v;
  end if;
  select result into v from public.staff_edit_test_journal where step = 'blank_name';
  if v is distinct from jsonb_build_object('ok', false, 'reason', 'invalid_name') then
    raise exception 'FAIL 3: a blank name was accepted: %', v;
  end if;
  select result into v from public.staff_edit_test_journal where step = 'bad_email';
  if v is distinct from jsonb_build_object('ok', false, 'reason', 'invalid_email') then
    raise exception 'FAIL 3: a malformed email was accepted: %', v;
  end if;
  select result into v from public.staff_edit_test_journal where step = 'taken_email';
  if v is distinct from jsonb_build_object('ok', false, 'reason', 'duplicate_email') then
    raise exception 'FAIL 3: a duplicate email was accepted: %', v;
  end if;
  select result into v from public.staff_edit_test_journal where step = 'bad_status';
  if v is distinct from jsonb_build_object('ok', false, 'reason', 'invalid_status') then
    raise exception 'FAIL 3: a status outside the column constraint was accepted: %', v;
  end if;
  if (select full_name from identity.staff_members
       where id = '574ff0de-0000-4000-8000-000000000004') <> 'Cashier One Kept' then
    raise exception 'FAIL 3: a refused edit overwrote the name';
  end if;

  select result into v from public.staff_edit_test_journal where step = 'good_email';
  if v is distinct from jsonb_build_object('ok', true) then
    raise exception 'FAIL 3: a valid email was refused: % / %',
      v, (select error from public.staff_edit_test_journal where step = 'good_email');
  end if;
  if (select email from identity.staff_members
       where id = '574ff0de-0000-4000-8000-000000000004') <> 'renamed.cashier@test.local' then
    raise exception 'FAIL 3: the email was not lower-cased before the unique check';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 4. Status bookkeeping and the audit trail.
-- ---------------------------------------------------------------------------
set local role authenticated;

select pg_temp.edit_as('574ff00d-0000-4000-8000-000000000001', 'suspend',
  '574ff0de-0000-4000-8000-000000000004', p_status := 'suspended');
select pg_temp.edit_as('574ff00d-0000-4000-8000-000000000001', 'reactivate',
  '574ff0de-0000-4000-8000-000000000004', p_status := 'active');

reset role;

do $$
declare v jsonb;
begin
  select result into v from public.staff_edit_test_journal where step = 'suspend';
  if v is distinct from jsonb_build_object('ok', true) then
    raise exception 'FAIL 4: suspending a cashier failed: %', v;
  end if;

  select result into v from public.staff_edit_test_journal where step = 'reactivate';
  if v is distinct from jsonb_build_object('ok', true) then
    raise exception 'FAIL 4: reactivating a cashier failed: %', v;
  end if;
  if not (select status = 'active' and suspended_at is null from identity.staff_members
           where id = '574ff0de-0000-4000-8000-000000000004') then
    raise exception 'FAIL 4: an active account still carries a suspended_at';
  end if;

  -- The suspension did leave its mark while it lasted.
  if not exists (
    select 1 from identity.audit_log
     where action = 'staff.update'
       and entity_id = '574ff0de-0000-4000-8000-000000000004'
       and new_values ->> 'status' = 'suspended'
  ) then
    raise exception 'FAIL 4: the suspension is not in the audit trail';
  end if;

  if not exists (
    select 1 from identity.audit_log
     where action = 'staff.update'
       and entity_id = '574ff0de-0000-4000-8000-000000000004'
       and old_values ? 'status'
       and old_values ? 'email'
  ) then
    raise exception 'FAIL 4: the edit wrote no audit row with old values';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 5. The picture: a path of this account's own folder, nothing else.
-- ---------------------------------------------------------------------------
set local role authenticated;

select pg_temp.picture_as('574ff00d-0000-4000-8000-000000000001', 'own_path',
  '574ff0de-0000-4000-8000-000000000004',
  'staff/574ff0de-0000-4000-8000-000000000004/avatar_1730000000.jpg');
select pg_temp.picture_as('574ff00d-0000-4000-8000-000000000001', 'other_path',
  '574ff0de-0000-4000-8000-000000000004',
  'staff/574ff0de-0000-4000-8000-000000000005/avatar_1730000000.jpg');
select pg_temp.picture_as('574ff00d-0000-4000-8000-000000000001', 'public_url',
  '574ff0de-0000-4000-8000-000000000004', 'https://example.test/a.jpg');
select pg_temp.picture_as('574ff00d-0000-4000-8000-000000000001', 'nested_path',
  '574ff0de-0000-4000-8000-000000000004',
  'staff/574ff0de-0000-4000-8000-000000000004/sub/avatar.jpg');
select pg_temp.picture_as('574ff00d-0000-4000-8000-000000000001', 'customer_folder',
  '574ff0de-0000-4000-8000-000000000004', '574ff00d-0000-4000-8000-000000000006/avatar.jpg');

reset role;

do $$
declare v jsonb;
begin
  select result into v from public.staff_edit_test_journal where step = 'own_path';
  if v is distinct from jsonb_build_object('ok', true) then
    raise exception 'FAIL 5: a path inside the account folder was refused: %', v;
  end if;
  if (select avatar_url from identity.staff_members
       where id = '574ff0de-0000-4000-8000-000000000004')
     <> 'staff/574ff0de-0000-4000-8000-000000000004/avatar_1730000000.jpg' then
    raise exception 'FAIL 5: the accepted path is not what the row holds';
  end if;

  select result into v from public.staff_edit_test_journal where step = 'other_path';
  if v is distinct from jsonb_build_object('ok', false, 'reason', 'invalid_path') then
    raise exception 'FAIL 5: a path of another account folder was accepted: %', v;
  end if;
  select result into v from public.staff_edit_test_journal where step = 'public_url';
  if v is distinct from jsonb_build_object('ok', false, 'reason', 'invalid_path') then
    raise exception 'FAIL 5: a full URL was stored instead of refused: %', v;
  end if;
  select result into v from public.staff_edit_test_journal where step = 'nested_path';
  if v is distinct from jsonb_build_object('ok', false, 'reason', 'invalid_path') then
    raise exception 'FAIL 5: a nested path was accepted: %', v;
  end if;
  select result into v from public.staff_edit_test_journal where step = 'customer_folder';
  if v is distinct from jsonb_build_object('ok', false, 'reason', 'invalid_path') then
    raise exception 'FAIL 5: a customer folder was accepted: %', v;
  end if;
  -- None of the refusals moved the row off the accepted path.
  if (select avatar_url from identity.staff_members
       where id = '574ff0de-0000-4000-8000-000000000004') is null then
    raise exception 'FAIL 5: a refused path cleared the stored picture';
  end if;
end $$;

-- 5b. The same scope as the edit: a manager pictures their own staff only.
set local role authenticated;
select pg_temp.picture_as('574ff00d-0000-4000-8000-000000000003', 'branch_sets_image',
  '574ff0de-0000-4000-8000-000000000004',
  'staff/574ff0de-0000-4000-8000-000000000004/avatar_2.jpg');
select pg_temp.picture_as('574ff00d-0000-4000-8000-000000000003', 'branch_sets_other_image',
  '574ff0de-0000-4000-8000-000000000005',
  'staff/574ff0de-0000-4000-8000-000000000005/avatar_2.jpg');
-- And clearing, which the dashboard does before it deletes the file.
select pg_temp.picture_as('574ff00d-0000-4000-8000-000000000001', 'cleared',
  '574ff0de-0000-4000-8000-000000000004', null);
reset role;

do $$
declare v jsonb;
begin
  select result into v from public.staff_edit_test_journal where step = 'branch_sets_image';
  if v is distinct from jsonb_build_object('ok', true) then
    raise exception 'FAIL 5b: a manager could not picture their own cashier: %', v;
  end if;
  if (select code from public.staff_edit_test_journal where step = 'branch_sets_other_image') <> '42501' then
    raise exception 'FAIL 5b: a manager pictured staff of another branch';
  end if;

  select result into v from public.staff_edit_test_journal where step = 'cleared';
  if v is distinct from jsonb_build_object('ok', true) then
    raise exception 'FAIL 5b: clearing the picture failed: %', v;
  end if;
  if (select avatar_url from identity.staff_members
       where id = '574ff0de-0000-4000-8000-000000000004') is not null then
    raise exception 'FAIL 5b: the cleared row still names a picture';
  end if;

  -- The picture writes are audited too, and the row they replaced is kept.
  if not exists (
    select 1 from identity.audit_log
     where action = 'staff.image'
       and entity_id = '574ff0de-0000-4000-8000-000000000004'
       and new_values ->> 'avatar_url' is null
       and old_values ->> 'avatar_url' like 'staff/%'
  ) then
    raise exception 'FAIL 5b: the clear is not in the audit trail with the path it replaced';
  end if;
end $$;

-- The column repeats the rule for hand-written SQL.
do $$
begin
  update identity.staff_members
     set avatar_url = 'placed/by/hand.jpg'
   where id = '574ff0de-0000-4000-8000-000000000005';
  raise exception 'FAIL 5c: a path outside staff/<id>/ reached the column';
exception
  when others then
    if sqlstate <> '23514' then raise; end if;
end $$;

-- ---------------------------------------------------------------------------
-- 6. The bucket: an admin reads and writes staff folders, a cashier neither.
-- ---------------------------------------------------------------------------
insert into storage.objects (bucket_id, name, owner)
values
  ('avatars', 'staff/574ff0de-0000-4000-8000-000000000004/avatar_1730000000.jpg',
   '574ff00d-0000-4000-8000-000000000001');

set local role authenticated;

select pg_temp.read_photos_as('574ff00d-0000-4000-8000-000000000001', 'admin_reads');
select pg_temp.write_photo_as('574ff00d-0000-4000-8000-000000000001', 'admin_writes',
  'staff/574ff0de-0000-4000-8000-000000000005/avatar_2.jpg');
select pg_temp.read_photos_as('574ff00d-0000-4000-8000-000000000004', 'cashier_reads');
select pg_temp.write_photo_as('574ff00d-0000-4000-8000-000000000004', 'cashier_writes',
  'staff/574ff0de-0000-4000-8000-000000000004/planted.jpg');
-- The customer folders of 084 stay closed to an admin.
select pg_temp.write_photo_as('574ff00d-0000-4000-8000-000000000001', 'admin_writes_customer',
  '574ff00d-0000-4000-8000-000000000006/planted.jpg');

reset role;

do $$
declare v jsonb;
begin
  select result into v from public.staff_edit_test_journal where step = 'admin_reads';
  if v is distinct from jsonb_build_object('seen', 1) then
    raise exception 'FAIL 6: an owner with admin.staff.read sees % staff pictures', v;
  end if;

  select result into v from public.staff_edit_test_journal where step = 'admin_writes';
  if v is distinct from jsonb_build_object('ok', true) then
    raise exception 'FAIL 6: an admin could not put a picture in a staff folder: % / %',
      v, (select error from public.staff_edit_test_journal where step = 'admin_writes');
  end if;

  select result into v from public.staff_edit_test_journal where step = 'cashier_reads';
  if v is distinct from jsonb_build_object('seen', 0) then
    raise exception 'FAIL 6: a cashier without admin.staff.read sees % staff pictures', v;
  end if;

  if (select code from public.staff_edit_test_journal where step = 'cashier_writes') <> '42501' then
    raise exception 'FAIL 6: a cashier without admin.staff.write wrote a staff picture: %',
      coalesce((select code from public.staff_edit_test_journal where step = 'cashier_writes'), 'accepted');
  end if;

  if (select code from public.staff_edit_test_journal where step = 'admin_writes_customer') <> '42501' then
    raise exception 'FAIL 6: the staff policies let an admin write into a customer folder';
  end if;

  -- What the admin did write exists, and its folder is the staff one.
  if not exists (select 1 from storage.objects
                  where bucket_id = 'avatars'
                    and name = 'staff/574ff0de-0000-4000-8000-000000000005/avatar_2.jpg') then
    raise exception 'FAIL 6: the accepted upload left no object behind';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 7. The direct table path.
--
--    Two facts, measured rather than assumed:
--      * `authenticated` holds no SELECT on identity.staff_members, so a raw
--        update is refused by the table privilege before any policy is read.
--        The old wide 019 policy was therefore never a live door for the
--        dashboard; the tightened one is what would bind the day that grant
--        returns, which is why section 9 asserts its shape.
--      * the predicate that policy calls answers per account and per row, and
--        it is executable by `authenticated`, so the scope is measured here
--        through the same function RLS would use.
-- ---------------------------------------------------------------------------
set local role authenticated;
select pg_temp.raw_update_as('574ff00d-0000-4000-8000-000000000003', 'raw_in_scope',
  '574ff0de-0000-4000-8000-000000000004');
select pg_temp.raw_update_as('574ff00d-0000-4000-8000-000000000003', 'raw_out_of_scope',
  '574ff0de-0000-4000-8000-000000000005');
select pg_temp.guard_as('574ff00d-0000-4000-8000-000000000003', 'guard_own_cashier',
  '574ff0de-0000-4000-8000-000000000004');
select pg_temp.guard_as('574ff00d-0000-4000-8000-000000000003', 'guard_other_branch',
  '574ff0de-0000-4000-8000-000000000005');
select pg_temp.guard_as('574ff00d-0000-4000-8000-000000000003', 'guard_owner_row',
  '574ff0de-0000-4000-8000-000000000001');
select pg_temp.guard_as('574ff00d-0000-4000-8000-000000000001', 'guard_owner_as_owner',
  '574ff0de-0000-4000-8000-000000000001');
select pg_temp.guard_as('574ff00d-0000-4000-8000-000000000002', 'guard_owner_as_manager',
  '574ff0de-0000-4000-8000-000000000001');
select pg_temp.guard_as('574ff00d-0000-4000-8000-000000000006', 'guard_as_customer',
  '574ff0de-0000-4000-8000-000000000004');
select pg_temp.guard_as('574ff00d-0000-4000-8000-000000000001', 'guard_unknown_row',
  '574ff0de-0000-4000-8000-00000000dead');
reset role;

do $$
declare v jsonb;
begin
  -- Neither a permitted nor a forbidden raw update reaches the table.
  if (select code from public.staff_edit_test_journal where step = 'raw_in_scope') <> '42501' then
    raise exception 'FAIL 7.1: the dashboard role can update staff_members directly: %',
      coalesce((select code from public.staff_edit_test_journal
                 where step = 'raw_in_scope'), 'accepted');
  end if;
  if (select code from public.staff_edit_test_journal where step = 'raw_out_of_scope') <> '42501' then
    raise exception 'FAIL 7.1: a raw update against another branch went through';
  end if;
  if exists (select 1 from identity.staff_members
              where full_name = 'Through The Table') then
    raise exception 'FAIL 7.1: a refused raw update still renamed a row';
  end if;

  -- The predicate the policy calls.
  select result into v from public.staff_edit_test_journal where step = 'guard_own_cashier';
  if v is distinct from jsonb_build_object('allowed', true) then
    raise exception 'FAIL 7.2: a branch manager cannot reach their own cashier: %', v;
  end if;
  select result into v from public.staff_edit_test_journal where step = 'guard_other_branch';
  if v is distinct from jsonb_build_object('allowed', false) then
    raise exception 'FAIL 7.3: the guard let a branch manager reach another branch: %', v;
  end if;
  select result into v from public.staff_edit_test_journal where step = 'guard_owner_row';
  if v is distinct from jsonb_build_object('allowed', false) then
    raise exception 'FAIL 7.4: the guard let a branch manager reach an owner: %', v;
  end if;
  select result into v from public.staff_edit_test_journal where step = 'guard_owner_as_owner';
  if v is distinct from jsonb_build_object('allowed', true) then
    raise exception 'FAIL 7.5: an owner cannot reach their own row: %', v;
  end if;
  select result into v from public.staff_edit_test_journal where step = 'guard_owner_as_manager';
  if v is distinct from jsonb_build_object('allowed', false) then
    raise exception 'FAIL 7.6: a global manager can edit an owner: %', v;
  end if;
  select result into v from public.staff_edit_test_journal where step = 'guard_as_customer';
  if v is distinct from jsonb_build_object('allowed', false) then
    raise exception 'FAIL 7.7: a customer passes the staff guard: %', v;
  end if;
  select result into v from public.staff_edit_test_journal where step = 'guard_unknown_row';
  if v is distinct from jsonb_build_object('allowed', false) then
    raise exception 'FAIL 7.8: an unknown staff id passes the guard: %', v;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 8. The directory carries the picture path.
-- ---------------------------------------------------------------------------
update identity.staff_members
   set avatar_url = 'staff/574ff0de-0000-4000-8000-000000000004/avatar_1730000000.jpg'
 where id = '574ff0de-0000-4000-8000-000000000004';

set local role authenticated;
select pg_temp.directory_as('574ff00d-0000-4000-8000-000000000001', 'directory');
-- A cashier is not in the directory audience: admin.staff.read is the gate.
select pg_temp.directory_as('574ff00d-0000-4000-8000-000000000004', 'directory_cashier');
reset role;

do $$
declare v jsonb;
declare row jsonb;
declare missing int;
begin
  select result into v from public.staff_edit_test_journal where step = 'directory';
  if v is null or jsonb_array_length(v) < 5 then
    raise exception 'FAIL 8: admin_staff() did not return the directory: % / %',
      v, (select error from public.staff_edit_test_journal where step = 'directory');
  end if;

  select count(*) into missing from jsonb_array_elements(v) e
   where not (e.value ? 'avatar_url')
      or not (e.value ? 'id')
      or not (e.value ? 'roles')
      or not (e.value ? 'permissions')
      or not (e.value ? 'status');
  if missing <> 0 then
    raise exception 'FAIL 8: % directory rows lost a field', missing;
  end if;

  select e.value into row from jsonb_array_elements(v) e
   where e.value ->> 'id' = '574ff0de-0000-4000-8000-000000000004';
  if row ->> 'avatar_url' <> 'staff/574ff0de-0000-4000-8000-000000000004/avatar_1730000000.jpg' then
    raise exception 'FAIL 8: the picture path is missing from the directory: %', row;
  end if;
  if row ->> 'full_name' <> 'Cashier One Kept' then
    raise exception 'FAIL 8: the directory shows a name none of the edits wrote: %', row;
  end if;

  if (select code from public.staff_edit_test_journal where step = 'directory_cashier') <> '42501' then
    raise exception 'FAIL 8: a cashier without admin.staff.read read the directory';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 9. The static end state.
-- ---------------------------------------------------------------------------
do $$
declare n int;
begin
  if (select public from storage.buckets where id = 'avatars') then
    raise exception 'FAIL 9: the avatars bucket was made public';
  end if;

  -- Four customer-folder policies of 084/208 plus four staff-folder ones.
  select count(*) into n from pg_policies
   where schemaname = 'storage' and tablename = 'objects'
     and policyname like 'avatars_%';
  if n <> 8 then
    raise exception 'FAIL 9: expected eight avatars policies, found %', n;
  end if;

  if exists (select 1 from pg_policies
              where schemaname = 'storage' and tablename = 'objects'
                and policyname like 'avatars_%'
                and roles::text like '%anon%') then
    raise exception 'FAIL 9: an avatars policy reached anon';
  end if;

  -- The write policies of the staff folders name the write permission only.
  if exists (select 1 from pg_policies
              where schemaname = 'storage' and tablename = 'objects'
                and policyname like 'avatars_%_staff_folder'
                and cmd <> 'SELECT'
                and coalesce(qual, '') like '%admin.staff.read%') then
    raise exception 'FAIL 9: a staff write policy accepts a read permission';
  end if;

  if not exists (select 1 from pg_policies
                  where schemaname = 'storage' and tablename = 'objects'
                    and policyname = 'avatars_select_staff_folder'
                    and cmd = 'SELECT'
                    and qual like '%admin.staff.read%'
                    and qual like '%staff%') then
    raise exception 'FAIL 9: the staff select policy lost its shape';
  end if;

  if not exists (select 1 from pg_policies
                  where schemaname = 'storage' and tablename = 'objects'
                    and policyname = 'avatars_delete_own_folder'
                    and qual ~ 'auth\.uid\(\)') then
    raise exception 'FAIL 9: the owner-only delete policy of 084 is gone';
  end if;

  -- The direct table update is scope-bound.
  if not exists (select 1 from pg_policies
                  where schemaname = 'identity' and tablename = 'staff_members'
                    and policyname = 'staff_update_permitted'
                    and qual like '%can_edit_staff%'
                    and with_check like '%can_edit_staff%') then
    raise exception 'FAIL 9: staff_update_permitted is still the wide 019 policy';
  end if;

  -- The three new functions: definer, an empty search_path and nothing else in
  -- it. PostgreSQL stores `set search_path = ''` as the element
  -- 'search_path=""' — the quoted form is what pg_proc actually holds, so both
  -- spellings are accepted rather than one guessed literal.
  if exists (select 1 from pg_proc pr
              join pg_namespace n on n.oid = pr.pronamespace
             where ((n.nspname = 'identity' and pr.proname = 'can_edit_staff')
                 or (n.nspname = 'public' and pr.proname in
                     ('admin_update_staff', 'admin_set_staff_image')))
               and (not pr.prosecdef
                    or pr.proconfig is null
                    or array_length(pr.proconfig, 1) <> 1
                    or pr.proconfig[1] not in ('search_path=', 'search_path=""'))) then
    raise exception 'FAIL 9: a new function is not a definer with only an empty search_path';
  end if;

  if exists (select 1 from pg_proc pr
              join pg_namespace n on n.oid = pr.pronamespace
             where ((n.nspname = 'identity' and pr.proname = 'can_edit_staff')
                 or (n.nspname = 'public' and pr.proname in
                     ('admin_update_staff', 'admin_set_staff_image')))
               and (pr.proacl is null or pr.proacl::text like '%=*%')) then
    raise exception 'FAIL 9: an edit function still carries a PUBLIC grant';
  end if;

  if has_function_privilege('anon', 'identity.can_edit_staff(uuid)', 'EXECUTE')
     or has_function_privilege('anon', 'public.admin_update_staff(uuid,text,text,text)', 'EXECUTE')
     or has_function_privilege('anon', 'public.admin_set_staff_image(uuid,text)', 'EXECUTE') then
    raise exception 'FAIL 9: an edit function is reachable by anon';
  end if;

  if not (has_function_privilege('authenticated', 'identity.can_edit_staff(uuid)', 'EXECUTE')
      and has_function_privilege('authenticated', 'public.admin_update_staff(uuid,text,text,text)', 'EXECUTE')
      and has_function_privilege('authenticated', 'public.admin_set_staff_image(uuid,text)', 'EXECUTE')) then
    raise exception 'FAIL 9: the dashboard role cannot execute the new functions';
  end if;

  if not exists (select 1 from pg_attribute a
                  join pg_class c on c.oid = a.attrelid
                  join pg_namespace n on n.oid = c.relnamespace
                 where n.nspname = 'identity' and c.relname = 'staff_members'
                   and a.attname = 'avatar_url' and a.attnum > 0) then
    raise exception 'FAIL 9: staff_members.avatar_url was not added';
  end if;
end $$;

select
  'reached the end: no assertion failed' as verdict,
  (select full_name from identity.staff_members
    where id = '574ff0de-0000-4000-8000-000000000004') as edited_name,
  (select email from identity.staff_members
    where id = '574ff0de-0000-4000-8000-000000000004') as edited_email,
  (select count(*) from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname like 'avatars_%') as avatars_policies,
  (select count(*) from identity.audit_log
    where action like 'staff.%') as staff_audit_rows;

rollback;
