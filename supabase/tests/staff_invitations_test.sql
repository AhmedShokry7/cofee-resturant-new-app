-- staff_invitations_test.sql
-- Behaviour test for 210_staff_invitations.sql: an admin creates an invitation,
-- shares its code, withdraws it, and the invited person turns it into their own
-- staff account from the sign-in screen.
--
-- HOW TO RUN
--   Plain SQL for the Supabase SQL Editor or psql, as the owner role. Everything
--   sits in one transaction that is rolled back at the end, so no fixture, no
--   invitation, no staff row and no audit entry survives the run. Against a
--   database without 210 the functions are missing and the first scenario fails
--   with "function does not exist" — that is the expected answer.
--
-- WHY THE HELIPAD
--   Every scenario has to run AS a different account, so the session role is
--   `authenticated` with JWT claims pointing at that uid. The answer cannot be
--   collected by an expression written in the caller's statement: PostgreSQL
--   evaluates the arguments before the helper runs, so the claims would be one
--   scenario behind. Each helper therefore sets the claims first and calls the
--   RPC inside itself. They are SECURITY INVOKER, so the RLS of the new table is
--   still measured against `authenticated`, not against the test session.
--
-- WHAT EACH SECTION PROVES
--   1  who may invite: the write permission, the branch scope, the owner role,
--      the answers a malformed invitation gets instead of a row, and the roles
--      and branches the dialog is offered per caller
--   2  who may see a code: the list carries the token only to the account that
--      wrote it and to whoever manages every branch, and an expired row is
--      reported as expired
--   3  what a stranger may learn: the lookup answers the invited email and role
--      for a live code and nothing else, never the code itself
--   4  accepting: the email of the session must be the invited email, the staff
--      row and its role are created, the customer profile the account signed up
--      with is converted, an account pinned by customer data is refused, and the
--      code is spent
--   5  withdrawing: only the scope that could write the invitation can cancel it,
--      and a withdrawn row stops answering
--   6  the static end state: the table is closed, the functions are definers with
--      an empty search_path, and only the lookup reaches anon

begin;

-- ---------------------------------------------------------------------------
-- Fixtures: two branches, the live role matrix, and one read-only role the
-- project does not ship, so that "can read" and "can share a code" are separate.
-- ---------------------------------------------------------------------------
insert into core.branches (id, brand_id, code, name_ar, name_en, address, is_active, settings)
values
  ('5751ffb0-0000-4000-8000-000000000001',
   '00000000-0000-4000-8000-000000000001', 'INV-B1', 'فرع الدعوات', 'Invite Branch 1',
   'addr', true, '{}'::jsonb),
  ('5751ffb0-0000-4000-8000-000000000002',
   '00000000-0000-4000-8000-000000000001', 'INV-B2', 'فرع الدعوات الثاني', 'Invite Branch 2',
   'addr', true, '{}'::jsonb);

-- admin.staff.read without admin.staff.write: no shipped role is shaped like it,
-- and the difference is exactly what section 2 measures.
insert into identity.roles (id, code, name_ar, name_en, is_system)
values ('5751b000-0000-4000-8000-0000000000aa', 'hr_viewer', 'قارئ الملفات', 'File Reader', false);

insert into identity.role_permissions (role_id, permission_id)
values ('5751b000-0000-4000-8000-0000000000aa',
        (select id from identity.permissions where code = 'admin.staff.read'));

insert into auth.users (id, email)
values
  ('5751f00d-0000-4000-8000-000000000001', 'invite-owner@test.local'),
  ('5751f00d-0000-4000-8000-000000000002', 'invite-global-manager@test.local'),
  ('5751f00d-0000-4000-8000-000000000003', 'invite-branch-manager@test.local'),
  ('5751f00d-0000-4000-8000-000000000004', 'invite-cashier@test.local'),
  ('5751f00d-0000-4000-8000-000000000005', 'invite-hr@test.local'),
  ('5751f00d-0000-4000-8000-000000000006', 'invite-customer@test.local');

insert into identity.staff_members (id, user_id, status, full_name, email)
values
  ('5751f0de-0000-4000-8000-000000000001',
   '5751f00d-0000-4000-8000-000000000001', 'active', 'Platform Owner', 'invite-owner@test.local'),
  ('5751f0de-0000-4000-8000-000000000002',
   '5751f00d-0000-4000-8000-000000000002', 'active', 'Global Manager', 'invite-global-manager@test.local'),
  ('5751f0de-0000-4000-8000-000000000003',
   '5751f00d-0000-4000-8000-000000000003', 'active', 'Branch Manager One', 'invite-branch-manager@test.local'),
  ('5751f0de-0000-4000-8000-000000000004',
   '5751f00d-0000-4000-8000-000000000004', 'active', 'Cashier One', 'invite-cashier@test.local'),
  ('5751f0de-0000-4000-8000-000000000005',
   '5751f00d-0000-4000-8000-000000000005', 'active', 'File Reader', 'invite-hr@test.local');

insert into identity.staff_roles (staff_id, role_id, branch_id)
values
  ('5751f0de-0000-4000-8000-000000000001',
   (select id from identity.roles where code = 'owner'), null),
  ('5751f0de-0000-4000-8000-000000000002',
   (select id from identity.roles where code = 'manager'), null),
  ('5751f0de-0000-4000-8000-000000000003',
   (select id from identity.roles where code = 'manager'),
   '5751ffb0-0000-4000-8000-000000000001'),
  ('5751f0de-0000-4000-8000-000000000004',
   (select id from identity.roles where code = 'cashier'),
   '5751ffb0-0000-4000-8000-000000000001'),
  ('5751f0de-0000-4000-8000-000000000005', '5751b000-0000-4000-8000-0000000000aa',
   '5751ffb0-0000-4000-8000-000000000001');

-- ---------------------------------------------------------------------------
-- The journal every scenario answers into, and the helpers that run a scenario
-- as one account.
-- ---------------------------------------------------------------------------
create table public.staff_invite_test_journal (
  step text primary key,
  result jsonb,
  error text,
  code text
);
-- This project runs an `ensure_rls` event trigger on ddl_command_end for the
-- `public` schema, so a script table arrives with RLS already on. The journal
-- holds the answers of the scenarios themselves, so it is turned back off before
-- it is granted.
alter table public.staff_invite_test_journal disable row level security;
grant select, insert on table public.staff_invite_test_journal to authenticated, anon;

create or replace function pg_temp.become(p_uid uuid)
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims',
    jsonb_build_object('sub', p_uid::text, 'role', 'authenticated',
                       'aud', 'authenticated')::text, true);
end $$;

create or replace function pg_temp.become_anon()
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims',
    jsonb_build_object('role', 'anon')::text, true);
end $$;

--- Runs admin_invite_staff as the given account.
create or replace function pg_temp.invite_as(
  p_uid uuid, p_step text, p_email text, p_name text, p_role text,
  p_branch uuid default null)
returns void
language plpgsql
as $$
begin
  perform pg_temp.become(p_uid);
  insert into public.staff_invite_test_journal (step, result)
  values (p_step, public.admin_invite_staff(p_email, p_name, p_role, p_branch));
exception when others then
  insert into public.staff_invite_test_journal (step, error, code) values (p_step, sqlerrm, sqlstate);
end $$;

--- Runs admin_staff_invite_options() as the given account.
create or replace function pg_temp.options_as(p_uid uuid, p_step text)
returns void
language plpgsql
as $$
begin
  perform pg_temp.become(p_uid);
  insert into public.staff_invite_test_journal (step, result)
  values (p_step, public.admin_staff_invite_options());
exception when others then
  insert into public.staff_invite_test_journal (step, error, code) values (p_step, sqlerrm, sqlstate);
end $$;

--- Runs admin_staff_invitations() as the given account.
create or replace function pg_temp.list_as(p_uid uuid, p_step text)
returns void
language plpgsql
as $$
begin
  perform pg_temp.become(p_uid);
  insert into public.staff_invite_test_journal (step, result)
  values (p_step, public.admin_staff_invitations());
exception when others then
  insert into public.staff_invite_test_journal (step, error, code) values (p_step, sqlerrm, sqlstate);
end $$;

--- Runs admin_cancel_invitation as the given account.
create or replace function pg_temp.cancel_as(p_uid uuid, p_step text, p_id uuid)
returns void
language plpgsql
as $$
begin
  perform pg_temp.become(p_uid);
  insert into public.staff_invite_test_journal (step, result)
  values (p_step, public.admin_cancel_invitation(p_id));
exception when others then
  insert into public.staff_invite_test_journal (step, error, code) values (p_step, sqlerrm, sqlstate);
end $$;

--- Runs admin_accept_invitation as the given account.
create or replace function pg_temp.accept_as(p_uid uuid, p_step text, p_token uuid)
returns void
language plpgsql
as $$
begin
  perform pg_temp.become(p_uid);
  insert into public.staff_invite_test_journal (step, result)
  values (p_step, public.admin_accept_invitation(p_token));
exception when others then
  insert into public.staff_invite_test_journal (step, error, code) values (p_step, sqlerrm, sqlstate);
end $$;

-- ---------------------------------------------------------------------------
-- 1. Who may invite, what a malformed invitation answers, and what the dialog
--    is allowed to offer them.
-- ---------------------------------------------------------------------------
set local role authenticated;

-- The owner invites a cashier into branch one.
select pg_temp.invite_as('5751f00d-0000-4000-8000-000000000001', 'owner_invites_cashier',
  'Invited.Hire@TEST.local', 'Hire One', 'cashier',
  '5751ffb0-0000-4000-8000-000000000001');
-- A global manager may invite, and may offer an invitation with no branch.
select pg_temp.invite_as('5751f00d-0000-4000-8000-000000000002', 'global_invites_manager',
  'invited.global@test.local', 'Manager Two', 'manager');
-- The branch manager reaches their own branch and nobody else's.
select pg_temp.invite_as('5751f00d-0000-4000-8000-000000000003', 'branch_invites_own',
  'invited.other@test.local', 'Hire Two', 'cashier',
  '5751ffb0-0000-4000-8000-000000000001');
select pg_temp.invite_as('5751f00d-0000-4000-8000-000000000003', 'branch_invites_other',
  'invited.b2@test.local', 'Hire Three', 'cashier',
  '5751ffb0-0000-4000-8000-000000000002');
select pg_temp.invite_as('5751f00d-0000-4000-8000-000000000003', 'branch_invites_global',
  'invited.globalbranch@test.local', 'Manager Three', 'manager');
-- A cashier holds neither staff permission, and a customer holds neither at all.
select pg_temp.invite_as('5751f00d-0000-4000-8000-000000000004', 'cashier_invites',
  'invited.nobody@test.local', 'Nobody', 'cashier',
  '5751ffb0-0000-4000-8000-000000000001');
select pg_temp.invite_as('5751f00d-0000-4000-8000-000000000006', 'customer_invites',
  'invited.nobody@test.local', 'Nobody', 'cashier',
  '5751ffb0-0000-4000-8000-000000000001');
-- Only an owner may hand out the top role.
select pg_temp.invite_as('5751f00d-0000-4000-8000-000000000002', 'manager_invites_owner',
  'invited.boss@test.local', 'Boss', 'owner');
select pg_temp.invite_as('5751f00d-0000-4000-8000-000000000001', 'owner_invites_owner',
  'invited.secondowner@test.local', 'Second Owner', 'owner');
-- The answers that are the caller's mistake rather than a refusal.
select pg_temp.invite_as('5751f00d-0000-4000-8000-000000000001', 'bad_email',
  'not-an-email', 'Bad Email', 'cashier',
  '5751ffb0-0000-4000-8000-000000000001');
select pg_temp.invite_as('5751f00d-0000-4000-8000-000000000001', 'blank_name',
  'invited.blank@test.local', '   ', 'cashier',
  '5751ffb0-0000-4000-8000-000000000001');
select pg_temp.invite_as('5751f00d-0000-4000-8000-000000000001', 'unknown_role',
  'invited.role@test.local', 'Ghost', 'no_such_role',
  '5751ffb0-0000-4000-8000-000000000001');
select pg_temp.invite_as('5751f00d-0000-4000-8000-000000000001', 'unknown_branch',
  'invited.branch@test.local', 'Ghost', 'cashier',
  '5751ffb0-0000-4000-8000-00000000000d');
select pg_temp.invite_as('5751f00d-0000-4000-8000-000000000001', 'twice_cashier',
  'invited.hire@test.local', 'Hire One', 'cashier',
  '5751ffb0-0000-4000-8000-000000000001');
select pg_temp.invite_as('5751f00d-0000-4000-8000-000000000001', 'staff_email',
  'invite-cashier@test.local', 'Already Staff', 'cashier',
  '5751ffb0-0000-4000-8000-000000000001');

-- The same dialog asks the database what it may offer before it paints the
-- pickers, so each of these answers is measured against the caller's own scope.
select pg_temp.options_as('5751f00d-0000-4000-8000-000000000001', 'owner_options');
select pg_temp.options_as('5751f00d-0000-4000-8000-000000000002', 'global_options');
select pg_temp.options_as('5751f00d-0000-4000-8000-000000000003', 'branch_options');
select pg_temp.options_as('5751f00d-0000-4000-8000-000000000004', 'cashier_options');
select pg_temp.options_as('5751f00d-0000-4000-8000-000000000005', 'reader_options');
select pg_temp.options_as('5751f00d-0000-4000-8000-000000000006', 'customer_options');

reset role;

do $$
declare v jsonb;
begin
  select result into v from public.staff_invite_test_journal where step = 'owner_invites_cashier';
  if v is null or (v ->> 'ok') <> 'true' then
    raise exception 'FAIL 1.1: the owner could not invite: % / %',
      v, (select error from public.staff_invite_test_journal where step = 'owner_invites_cashier');
  end if;
  -- Mixed case was stored the way the column demands it, and the code came back
  -- exactly once, to the account that wrote the row.
  if v ->> 'email' <> 'invited.hire@test.local' then
    raise exception 'FAIL 1.1: the invitation email was not lower-cased: %', v;
  end if;
  if char_length(coalesce(v ->> 'token', '')) <> 36 then
    raise exception 'FAIL 1.2: no code was handed back to the inviter: %', v;
  end if;
  if not exists (select 1 from identity.staff_invitations
                  where email = 'invited.hire@test.local') then
    raise exception 'FAIL 1.2: the accepted invitation wrote no row';
  end if;

  select result into v from public.staff_invite_test_journal where step = 'global_invites_manager';
  if v is null or (v ->> 'ok') <> 'true' then
    raise exception 'FAIL 1.3: a global manager could not invite: % / %',
      v, (select error from public.staff_invite_test_journal where step = 'global_invites_manager');
  end if;
  if (select branch_id from identity.staff_invitations
       where email = 'invited.global@test.local') is not null then
    raise exception 'FAIL 1.3: a global invitation carries a branch';
  end if;

  select result into v from public.staff_invite_test_journal where step = 'branch_invites_own';
  if v is null or (v ->> 'ok') <> 'true' then
    raise exception 'FAIL 1.4: the branch manager could not invite into their own branch: % / %',
      v, (select error from public.staff_invite_test_journal where step = 'branch_invites_own');
  end if;

  select result into v from public.staff_invite_test_journal where step = 'branch_invites_other';
  if v is distinct from jsonb_build_object('ok', false, 'reason', 'not_your_branch') then
    raise exception 'FAIL 1.5: a manager reached another branch: %', v;
  end if;
  select result into v from public.staff_invite_test_journal where step = 'branch_invites_global';
  if v is distinct from jsonb_build_object('ok', false, 'reason', 'not_your_branch') then
    raise exception 'FAIL 1.6: a branch manager offered an invitation with no branch: %', v;
  end if;

  if (select code from public.staff_invite_test_journal where step = 'cashier_invites') <> '42501' then
    raise exception 'FAIL 1.7: a cashier without admin.staff.write invited someone';
  end if;
  if (select code from public.staff_invite_test_journal where step = 'customer_invites') <> '42501' then
    raise exception 'FAIL 1.8: a customer reached the invitation door';
  end if;

  select result into v from public.staff_invite_test_journal where step = 'manager_invites_owner';
  if v is distinct from jsonb_build_object('ok', false, 'reason', 'owner_only') then
    raise exception 'FAIL 1.9: a manager handed out the owner role: %', v;
  end if;
  select result into v from public.staff_invite_test_journal where step = 'owner_invites_owner';
  if v is null or (v ->> 'ok') <> 'true' then
    raise exception 'FAIL 1.9: an owner could not invite another owner: % / %',
      v, (select error from public.staff_invite_test_journal where step = 'owner_invites_owner');
  end if;

  select result into v from public.staff_invite_test_journal where step = 'bad_email';
  if v is distinct from jsonb_build_object('ok', false, 'reason', 'invalid_email') then
    raise exception 'FAIL 1.10: a malformed email was invited: %', v;
  end if;
  select result into v from public.staff_invite_test_journal where step = 'blank_name';
  if v is distinct from jsonb_build_object('ok', false, 'reason', 'invalid_name') then
    raise exception 'FAIL 1.10: a blank name was invited: %', v;
  end if;
  select result into v from public.staff_invite_test_journal where step = 'unknown_role';
  if v is distinct from jsonb_build_object('ok', false, 'reason', 'unknown_role') then
    raise exception 'FAIL 1.10: a role that does not exist was invited: %', v;
  end if;
  select result into v from public.staff_invite_test_journal where step = 'unknown_branch';
  if v is distinct from jsonb_build_object('ok', false, 'reason', 'unknown_branch') then
    raise exception 'FAIL 1.10: a branch that does not exist was invited into: %', v;
  end if;
  select result into v from public.staff_invite_test_journal where step = 'twice_cashier';
  if v is null or (v ->> 'reason') <> 'already_invited' then
    raise exception 'FAIL 1.10: the same email was invited twice: %', v;
  end if;
  if not exists (select 1 from identity.staff_invitations
                  where id::text = (v ->> 'invitation_id')) then
    raise exception 'FAIL 1.10: already_invited did not point at the live row: %', v;
  end if;
  select result into v from public.staff_invite_test_journal where step = 'staff_email';
  if v is distinct from jsonb_build_object('ok', false, 'reason', 'already_staff') then
    raise exception 'FAIL 1.11: an account that is already staff was invited: %', v;
  end if;

  -- What each caller is offered is cut to what the create step above would
  -- accept from them: the dialog cannot hand out a role or a branch it would
  -- then refuse.
  select result into v from public.staff_invite_test_journal where step = 'owner_options';
  if v is null or (v ->> 'ok') <> 'true' then
    raise exception 'FAIL 1.12: the owner could not read the offer list: % / %',
      v, (select error from public.staff_invite_test_journal where step = 'owner_options');
  end if;
  if not exists (select 1 from jsonb_array_elements(v -> 'roles') e
                  where e ->> 'code' = 'owner') then
    raise exception 'FAIL 1.12: an owner was not offered the owner role: %', v;
  end if;
  if (select count(*) from jsonb_array_elements(v -> 'branches') e
       where e ->> 'id' in ('5751ffb0-0000-4000-8000-000000000001',
                            '5751ffb0-0000-4000-8000-000000000002')) <> 2 then
    raise exception 'FAIL 1.12: an owner was offered fewer than both branches: %', v;
  end if;
  if (v ->> 'can_offer_any_branch') <> 'true' then
    raise exception 'FAIL 1.12: an owner cannot offer an invitation with no branch: %', v;
  end if;

  select result into v from public.staff_invite_test_journal where step = 'global_options';
  if exists (select 1 from jsonb_array_elements(v -> 'roles') e
              where e ->> 'code' = 'owner') then
    raise exception 'FAIL 1.13: a manager was offered the owner role: %', v;
  end if;
  if (v ->> 'can_offer_any_branch') <> 'true' then
    raise exception 'FAIL 1.13: a global manager cannot offer a branch-free invitation: %', v;
  end if;

  select result into v from public.staff_invite_test_journal where step = 'branch_options';
  if (select count(*) from jsonb_array_elements(v -> 'branches') e) <> 1
     or not exists (select 1 from jsonb_array_elements(v -> 'branches') e
                     where e ->> 'id' = '5751ffb0-0000-4000-8000-000000000001') then
    raise exception 'FAIL 1.14: a branch manager was offered a branch outside their scope: %', v;
  end if;
  if (v ->> 'can_offer_any_branch') <> 'false' then
    raise exception 'FAIL 1.14: a branch manager was allowed to drop the branch: %', v;
  end if;

  if (select code from public.staff_invite_test_journal where step = 'cashier_options') <> '42501' then
    raise exception 'FAIL 1.15: a cashier with no staff permission read the offer list';
  end if;
  if (select code from public.staff_invite_test_journal where step = 'reader_options') <> '42501' then
    raise exception 'FAIL 1.15: a read-only account read the offer list';
  end if;
  if (select code from public.staff_invite_test_journal where step = 'customer_options') <> '42501' then
    raise exception 'FAIL 1.15: a customer read the offer list';
  end if;

  -- The refusals wrote nothing.
  if exists (select 1 from identity.staff_invitations
              where email in ('invited.b2@test.local', 'invited.nobody@test.local',
                              'invited.boss@test.local', 'invited.role@test.local',
                              'invited.branch@test.local', 'invited.blank@test.local',
                              'invited.globalbranch@test.local', 'not-an-email')) then
    raise exception 'FAIL 1.16: a refused invitation reached the table anyway';
  end if;

  if (select count(*) from identity.audit_log where action = 'staff.invite') <> 4 then
    raise exception 'FAIL 1.17: the invitations that were written were not audited: %',
      (select count(*) from identity.audit_log where action = 'staff.invite');
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 2. Who may see a code, and what an expired row answers.
--
-- Two states the functions cannot be asked to create on their own: a code whose
-- week is over, and one that was withdrawn. They are planted here, and every
-- count below is scoped to what this script owns.
-- ---------------------------------------------------------------------------
insert into identity.staff_invitations
       (id, email, full_name, role_code, branch_id, token, status, expires_at, invited_by)
values
  ('5751ee00-0000-4000-8000-000000000001', 'invited.expired@test.local', 'Stale Invite',
   'cashier', '5751ffb0-0000-4000-8000-000000000001',
   '5751ee01-0000-4000-8000-000000000001', 'pending', now() - interval '1 hour',
   '5751f0de-0000-4000-8000-000000000001'),
  ('5751ee00-0000-4000-8000-000000000002', 'invited.cancelled@test.local', 'Withdrawn Invite',
   'cashier', '5751ffb0-0000-4000-8000-000000000001',
   '5751ee01-0000-4000-8000-000000000002', 'cancelled', now() + interval '7 days',
   '5751f0de-0000-4000-8000-000000000001'),
  ('5751ee00-0000-4000-8000-000000000003', 'invited.otherbranch@test.local', 'Other Branch Invite',
   'cashier', '5751ffb0-0000-4000-8000-000000000002',
   '5751ee01-0000-4000-8000-000000000003', 'pending', now() + interval '7 days',
   '5751f0de-0000-4000-8000-000000000001');

-- The three rows below were written by the RPC, so their identity and their code
-- are random. The scenarios that follow run as client roles, and a client role
-- may not read this table at all — which is the point of section 6 — so what is
-- left of the script names these rows by constants instead.
update identity.staff_invitations
   set id = '5751ee00-0000-4000-8000-000000000010',
       token = '5751ee01-0000-4000-8000-000000000010'
 where email = 'invited.hire@test.local';
update identity.staff_invitations
   set id = '5751ee00-0000-4000-8000-000000000011',
       token = '5751ee01-0000-4000-8000-000000000011'
 where email = 'invited.other@test.local';
update identity.staff_invitations
   set id = '5751ee00-0000-4000-8000-000000000012'
 where email = 'invited.global@test.local';

set local role authenticated;

select pg_temp.list_as('5751f00d-0000-4000-8000-000000000001', 'list_owner');
select pg_temp.list_as('5751f00d-0000-4000-8000-000000000003', 'list_branch_manager');
select pg_temp.list_as('5751f00d-0000-4000-8000-000000000005', 'list_reader');
select pg_temp.list_as('5751f00d-0000-4000-8000-000000000004', 'list_cashier');
select pg_temp.list_as('5751f00d-0000-4000-8000-000000000006', 'list_customer');

reset role;

do $$
declare v jsonb; one jsonb;
begin
  select result into v from public.staff_invite_test_journal where step = 'list_owner';
  if jsonb_array_length(v) <> 7 then
    raise exception 'FAIL 2.1: the owner sees % invitations, expected 7', jsonb_array_length(v);
  end if;

  -- The expired row is reported as it behaves, not as it is stored.
  select e into one from jsonb_array_elements(v) e where e ->> 'email' = 'invited.expired@test.local';
  if one ->> 'status' <> 'expired' then
    raise exception 'FAIL 2.2: an expired invitation was listed as %', one ->> 'status';
  end if;
  if one ? 'token' and one -> 'token' <> 'null'::jsonb then
    raise exception 'FAIL 2.2: a dead code was still carried to the screen: %', one;
  end if;

  -- The cashier invitation was written by the owner, so its code travels.
  select e into one from jsonb_array_elements(v) e where e ->> 'email' = 'invited.hire@test.local';
  if char_length(coalesce(one #>> '{token}', '')) <> 36 then
    raise exception 'FAIL 2.3: the creator was not given their own code back: %', one;
  end if;
  if one ->> 'invited_by_name' <> 'Platform Owner' then
    raise exception 'FAIL 2.3: the list does not say who invited: %', one;
  end if;
  if one ->> 'branch_name_ar' is null then
    raise exception 'FAIL 2.3: the list lost the branch of the invitation: %', one;
  end if;

  -- A manager of one branch sees the rows and no code they did not write.
  select result into v from public.staff_invite_test_journal where step = 'list_branch_manager';
  select e into one from jsonb_array_elements(v) e where e ->> 'email' = 'invited.hire@test.local';
  if one ? 'token' and one -> 'token' <> 'null'::jsonb then
    raise exception 'FAIL 2.4: another branch manager was handed a code: %', one;
  end if;
  select e into one from jsonb_array_elements(v) e where e ->> 'email' = 'invited.other@test.local';
  if char_length(coalesce(one #>> '{token}', '')) <> 36 then
    raise exception 'FAIL 2.4: the writer of a code cannot re-share it: %', one;
  end if;

  -- Reading the list is not writing invitations, and it is not holding codes.
  select result into v from public.staff_invite_test_journal where step = 'list_reader';
  if v is null then
    raise exception 'FAIL 2.5: admin.staff.read alone could not list: %',
      (select error from public.staff_invite_test_journal where step = 'list_reader');
  end if;
  if exists (select 1 from jsonb_array_elements(v) e
              where e ? 'token' and e -> 'token' <> 'null'::jsonb) then
    raise exception 'FAIL 2.5: a read-only account was given a code';
  end if;

  if (select code from public.staff_invite_test_journal where step = 'list_cashier') <> '42501' then
    raise exception 'FAIL 2.6: a cashier without admin.staff.read listed the invitations';
  end if;
  if (select code from public.staff_invite_test_journal where step = 'list_customer') <> '42501' then
    raise exception 'FAIL 2.6: a customer listed the invitations';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 3. What a stranger holding a code may learn before signing up.
--
-- The claims are set while the session is still the owner role, and the answers
-- are then collected as `anon` by plain statements: nothing in this section runs
-- through a pg_temp helper of another role.
-- ---------------------------------------------------------------------------
select pg_temp.become_anon();
set local role anon;

insert into public.staff_invite_test_journal (step, result)
values ('lookup_live', public.admin_invitation_lookup(
  '5751ee01-0000-4000-8000-000000000010'));
insert into public.staff_invite_test_journal (step, result)
values ('lookup_expired', public.admin_invitation_lookup('5751ee01-0000-4000-8000-000000000001'));
insert into public.staff_invite_test_journal (step, result)
values ('lookup_cancelled', public.admin_invitation_lookup('5751ee01-0000-4000-8000-000000000002'));
insert into public.staff_invite_test_journal (step, result)
values ('lookup_unknown', public.admin_invitation_lookup('5751ee01-0000-4000-8000-0000000000ff'));
insert into public.staff_invite_test_journal (step, result)
values ('lookup_null', public.admin_invitation_lookup(null::uuid));

reset role;

do $$
declare v jsonb;
begin
  select result into v from public.staff_invite_test_journal where step = 'lookup_live';
  if v is null or (v ->> 'ok') <> 'true' then
    raise exception 'FAIL 3.1: an anonymous lookup of a live code failed: % / %',
      v, (select error from public.staff_invite_test_journal where step = 'lookup_live');
  end if;
  if v ->> 'email' <> 'invited.hire@test.local' or v ->> 'role_code' <> 'cashier' then
    raise exception 'FAIL 3.1: the lookup answered the wrong invitation: %', v;
  end if;
  -- The code is what the person already typed; giving it back is not information.
  if v ? 'token' then
    raise exception 'FAIL 3.1: the lookup echoed the code back: %', v;
  end if;
  -- And nothing about the account behind the invitation.
  if v ? 'staff_id' or v ? 'invitation_id' or v ? 'invited_by' then
    raise exception 'FAIL 3.1: the lookup leaked an identifier: %', v;
  end if;

  select result into v from public.staff_invite_test_journal where step = 'lookup_expired';
  if v is distinct from jsonb_build_object('ok', false, 'reason', 'expired') then
    raise exception 'FAIL 3.2: an expired code still invited: %', v;
  end if;
  select result into v from public.staff_invite_test_journal where step = 'lookup_cancelled';
  if v is distinct from jsonb_build_object('ok', false, 'reason', 'cancelled') then
    raise exception 'FAIL 3.3: a withdrawn code still invited: %', v;
  end if;
  select result into v from public.staff_invite_test_journal where step = 'lookup_unknown';
  if v is distinct from jsonb_build_object('ok', false, 'reason', 'unknown') then
    raise exception 'FAIL 3.4: a code that was never written answered: %', v;
  end if;
  select result into v from public.staff_invite_test_journal where step = 'lookup_null';
  if v is distinct from jsonb_build_object('ok', false, 'reason', 'unknown') then
    raise exception 'FAIL 3.4: an empty code answered something other than unknown: %', v;
  end if;
end $$;

-- A signed-in account that is nobody in the back office is still not staff, so
-- the door that answers before the sign-in answers for it too.
set local role authenticated;
select pg_temp.become('5751f00d-0000-4000-8000-000000000006');
insert into public.staff_invite_test_journal (step, result)
values ('lookup_signed_in',
  public.admin_invitation_lookup('5751ee01-0000-4000-8000-000000000010'));
reset role;

do $$
declare v jsonb;
begin
  select result into v from public.staff_invite_test_journal where step = 'lookup_signed_in';
  if v is null or (v ->> 'ok') <> 'true' then
    raise exception 'FAIL 3.5: a signed-in non-staff could not look a code up: % / %',
      v, (select error from public.staff_invite_test_journal where step = 'lookup_signed_in');
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 4. Accepting: the code and the email of the session must agree.
--
-- The invitee signs up the way the app will do it, so `identity.handle_new_user`
-- has already given them a customer profile: that is the row the accept step is
-- allowed to remove.
-- ---------------------------------------------------------------------------
insert into auth.users (id, email)
values
  ('5751f00d-0000-4000-8000-000000000010', 'invited.hire@test.local'),
  ('5751f00d-0000-4000-8000-000000000011', 'someone.else@test.local'),
  ('5751f00d-0000-4000-8000-000000000012', 'invited.expired@test.local'),
  ('5751f00d-0000-4000-8000-000000000013', 'invited.pinned@test.local'),
  ('5751f00d-0000-4000-8000-000000000014', 'invited.cancelled@test.local');

-- An invitation for the account that owns customer data, and one planted for an
-- account that is already staff: the create RPC refuses both, so the accept step
-- would never be asked about them without these rows.
insert into identity.staff_invitations (email, full_name, role_code, branch_id, token, invited_by)
values
  ('invited.pinned@test.local', 'Pinned Person', 'cashier',
   '5751ffb0-0000-4000-8000-000000000001',
   '5751ee01-0000-4000-8000-000000000013', '5751f0de-0000-4000-8000-000000000001'),
  ('invite-cashier@test.local', 'Cashier One', 'cashier',
   '5751ffb0-0000-4000-8000-000000000001',
   '5751ee01-0000-4000-8000-000000000014', '5751f0de-0000-4000-8000-000000000001');

-- The pinned account has something to lose. The only reference in the project
-- that refuses to let a profile go is `orders.orders.user_id`, and a real order
-- row would drag the kitchen, notification and subscription triggers into this
-- script, so the blocking condition is planted the way 188's own trigger sees it:
-- a row that must not outlive the profile. The rollback removes the table with
-- everything else.
create table public.staff_invite_test_pin (
  user_id uuid not null references identity.profiles(id) on delete restrict
);
alter table public.staff_invite_test_pin disable row level security;
insert into public.staff_invite_test_pin (user_id)
values ('5751f00d-0000-4000-8000-000000000013');

set local role authenticated;

-- The code of the cashier-to-be, typed by the wrong account.
select pg_temp.accept_as('5751f00d-0000-4000-8000-000000000011', 'accept_wrong_email',
  '5751ee01-0000-4000-8000-000000000010');

reset role;

do $$
declare v jsonb;
begin
  select result into v from public.staff_invite_test_journal where step = 'accept_wrong_email';
  if v is distinct from jsonb_build_object('ok', false, 'reason', 'email_mismatch') then
    raise exception 'FAIL 4.1: a leaked code was accepted by the wrong email: % / %',
      v, (select error from public.staff_invite_test_journal where step = 'accept_wrong_email');
  end if;
  -- The refusal spends nothing: the invited person can still use their own code.
  if (select status from identity.staff_invitations
       where email = 'invited.hire@test.local') <> 'pending' then
    raise exception 'FAIL 4.1: the mismatch burned the invitation';
  end if;
  if exists (select 1 from identity.staff_members
              where user_id = '5751f00d-0000-4000-8000-000000000011') then
    raise exception 'FAIL 4.1: the wrong account became staff';
  end if;
end $$;

set local role authenticated;

-- And by the account it was written for.
select pg_temp.accept_as('5751f00d-0000-4000-8000-000000000010', 'accept_cashier',
  '5751ee01-0000-4000-8000-000000000010');
-- The same code a second time, from the account that mistyped it before.
select pg_temp.accept_as('5751f00d-0000-4000-8000-000000000011', 'accept_twice',
  '5751ee01-0000-4000-8000-000000000010');
-- A code whose week is over, typed by the very email it invited.
select pg_temp.accept_as('5751f00d-0000-4000-8000-000000000012', 'accept_expired',
  '5751ee01-0000-4000-8000-000000000001');
-- A withdrawn one, by its own email.
select pg_temp.accept_as('5751f00d-0000-4000-8000-000000000014', 'accept_cancelled',
  '5751ee01-0000-4000-8000-000000000002');
-- An account that already is staff, with a code planted for its own email.
select pg_temp.accept_as('5751f00d-0000-4000-8000-000000000004', 'accept_is_staff',
  '5751ee01-0000-4000-8000-000000000014');
-- A customer whose history pins the profile to the account.
select pg_temp.accept_as('5751f00d-0000-4000-8000-000000000013', 'accept_pinned',
  '5751ee01-0000-4000-8000-000000000013');
-- A session whose auth row has no email at all.
select pg_temp.accept_as('5751f00d-0000-4000-8000-0000000000ff', 'accept_ghost',
  '5751ee01-0000-4000-8000-000000000003');

reset role;

do $$
declare v jsonb; cashier_code uuid;
begin
  select result into v from public.staff_invite_test_journal where step = 'accept_cashier';
  if v is null or (v ->> 'ok') <> 'true' then
    raise exception 'FAIL 4.2: the invited email could not accept its own code: % / %',
      v, (select error from public.staff_invite_test_journal where step = 'accept_cashier');
  end if;
  if v ->> 'role_code' <> 'cashier'
     or (v ->> 'branch_id') <> '5751ffb0-0000-4000-8000-000000000001' then
    raise exception 'FAIL 4.2: the accept answer lost the role or the branch: %', v;
  end if;

  -- The account is now the staff member the invitation promised.
  if not exists (select 1 from identity.staff_members
                  where id::text = (v ->> 'staff_id')
                    and user_id = '5751f00d-0000-4000-8000-000000000010'
                    and status = 'active'
                    and full_name = 'Hire One'
                    and email = 'invited.hire@test.local'
                    and invited_by = '5751f0de-0000-4000-8000-000000000001'
                    and accepted_at is not null) then
    raise exception 'FAIL 4.3: no staff row was written for the accepted invitation: %', v;
  end if;
  if not exists (select 1 from identity.staff_roles sr
                  join identity.roles r on r.id = sr.role_id
                 where sr.staff_id::text = (v ->> 'staff_id')
                   and r.code = 'cashier'
                   and sr.branch_id = '5751ffb0-0000-4000-8000-000000000001'
                   and sr.granted_by = '5751f0de-0000-4000-8000-000000000001') then
    raise exception 'FAIL 4.3: the role of the invitation was not granted';
  end if;
  -- The customer profile the signup gave them is gone: 188 allows one identity.
  if exists (select 1 from identity.profiles
              where id = '5751f00d-0000-4000-8000-000000000010') then
    raise exception 'FAIL 4.3: the account is a customer and a staff member';
  end if;

  if (select status from identity.staff_invitations
       where email = 'invited.hire@test.local') <> 'accepted' then
    raise exception 'FAIL 4.4: the used code left the invitation pending';
  end if;
  if (select accepted_user_id from identity.staff_invitations
       where email = 'invited.hire@test.local')
     <> '5751f00d-0000-4000-8000-000000000010' then
    raise exception 'FAIL 4.4: the invitation does not say who used the code';
  end if;

  select result into v from public.staff_invite_test_journal where step = 'accept_twice';
  if v is distinct from jsonb_build_object('ok', false, 'reason', 'accepted') then
    raise exception 'FAIL 4.5: a spent code was accepted a second time: %', v;
  end if;
  if (select count(*) from identity.staff_members
       where email = 'invited.hire@test.local') <> 1 then
    raise exception 'FAIL 4.5: the second accept wrote a second staff row';
  end if;

  -- The code is spent, so even the door that used to answer it goes quiet.
  select token into cashier_code from identity.staff_invitations
   where email = 'invited.hire@test.local';
  select public.admin_invitation_lookup(cashier_code) into v;
  if v is distinct from jsonb_build_object('ok', false, 'reason', 'accepted') then
    raise exception 'FAIL 4.5: the lookup still describes a used code: %', v;
  end if;

  select result into v from public.staff_invite_test_journal where step = 'accept_expired';
  if v is distinct from jsonb_build_object('ok', false, 'reason', 'expired') then
    raise exception 'FAIL 4.6: a stale code was accepted: %', v;
  end if;
  select result into v from public.staff_invite_test_journal where step = 'accept_cancelled';
  if v is distinct from jsonb_build_object('ok', false, 'reason', 'cancelled') then
    raise exception 'FAIL 4.7: a withdrawn code was accepted: %', v;
  end if;
  select result into v from public.staff_invite_test_journal where step = 'accept_is_staff';
  if v is distinct from jsonb_build_object('ok', false, 'reason', 'already_staff') then
    raise exception 'FAIL 4.8: an existing staff account accepted a code: %', v;
  end if;
  select result into v from public.staff_invite_test_journal where step = 'accept_pinned';
  if v is distinct from jsonb_build_object('ok', false, 'reason', 'customer_history') then
    raise exception 'FAIL 4.9: an account with customer history was turned into staff: % / %',
      v, (select error from public.staff_invite_test_journal where step = 'accept_pinned');
  end if;
  if exists (select 1 from identity.staff_members
              where user_id = '5751f00d-0000-4000-8000-000000000013') then
    raise exception 'FAIL 4.9: the refused account kept a staff row behind it';
  end if;
  if not exists (select 1 from identity.profiles
                  where id = '5751f00d-0000-4000-8000-000000000013') then
    raise exception 'FAIL 4.9: the refused accept deleted the customer profile';
  end if;
  if (select status from identity.staff_invitations
       where email = 'invited.pinned@test.local') <> 'pending' then
    raise exception 'FAIL 4.9: the refused accept spent the invitation';
  end if;

  -- A uid with no auth row has no email to compare, which is its own answer.
  select result into v from public.staff_invite_test_journal where step = 'accept_ghost';
  if v is distinct from jsonb_build_object('ok', false, 'reason', 'no_email') then
    raise exception 'FAIL 4.10: a session without an email answered %', v;
  end if;

  if (select count(*) from identity.audit_log
       where action = 'staff.invite.accept') <> 1 then
    raise exception 'FAIL 4.11: the one accept that worked was audited % times',
      (select count(*) from identity.audit_log where action = 'staff.invite.accept');
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 5. Withdrawing: the scope that could write the invitation can take it back.
-- ---------------------------------------------------------------------------
set local role authenticated;

select pg_temp.cancel_as('5751f00d-0000-4000-8000-000000000003', 'cancel_foreign_branch',
  '5751ee00-0000-4000-8000-000000000003');
select pg_temp.cancel_as('5751f00d-0000-4000-8000-000000000004', 'cancel_as_cashier',
  '5751ee00-0000-4000-8000-000000000003');
select pg_temp.cancel_as('5751f00d-0000-4000-8000-000000000005', 'cancel_as_reader',
  '5751ee00-0000-4000-8000-000000000003');
select pg_temp.cancel_as('5751f00d-0000-4000-8000-000000000002', 'cancel_global_invitation',
  '5751ee00-0000-4000-8000-000000000012');
select pg_temp.cancel_as('5751f00d-0000-4000-8000-000000000002', 'cancel_twice',
  '5751ee00-0000-4000-8000-000000000012');
select pg_temp.cancel_as('5751f00d-0000-4000-8000-000000000002', 'cancel_used',
  '5751ee00-0000-4000-8000-000000000010');
select pg_temp.cancel_as('5751f00d-0000-4000-8000-000000000002', 'cancel_unknown',
  '5751ee00-0000-4000-8000-0000000000ff');
-- The branch manager withdraws what their own branch wrote.
select pg_temp.cancel_as('5751f00d-0000-4000-8000-000000000003', 'cancel_own_branch',
  '5751ee00-0000-4000-8000-000000000011');

reset role;

do $$
declare v jsonb;
begin
  if (select code from public.staff_invite_test_journal where step = 'cancel_foreign_branch')
     <> '42501' then
    raise exception 'FAIL 5.1: a manager cancelled an invitation of another branch';
  end if;
  if (select code from public.staff_invite_test_journal where step = 'cancel_as_cashier')
     <> '42501' then
    raise exception 'FAIL 5.2: a cashier cancelled an invitation';
  end if;
  if (select code from public.staff_invite_test_journal where step = 'cancel_as_reader')
     <> '42501' then
    raise exception 'FAIL 5.2: admin.staff.read alone cancelled an invitation';
  end if;

  select result into v from public.staff_invite_test_journal where step = 'cancel_global_invitation';
  if v is distinct from jsonb_build_object('ok', true) then
    raise exception 'FAIL 5.3: a global manager could not withdraw an invitation: % / %',
      v, (select error from public.staff_invite_test_journal where step = 'cancel_global_invitation');
  end if;
  if (select status from identity.staff_invitations
       where email = 'invited.global@test.local') <> 'cancelled' then
    raise exception 'FAIL 5.3: the withdrawal did not reach the row';
  end if;

  select result into v from public.staff_invite_test_journal where step = 'cancel_twice';
  if v is distinct from jsonb_build_object('ok', false, 'reason', 'not_pending') then
    raise exception 'FAIL 5.4: a cancelled invitation was cancelled again: %', v;
  end if;
  select result into v from public.staff_invite_test_journal where step = 'cancel_used';
  if v is distinct from jsonb_build_object('ok', false, 'reason', 'not_pending') then
    raise exception 'FAIL 5.5: an accepted invitation was cancelled: %', v;
  end if;
  select result into v from public.staff_invite_test_journal where step = 'cancel_unknown';
  if v is distinct from jsonb_build_object('ok', false, 'reason', 'not_found') then
    raise exception 'FAIL 5.6: an unknown invitation id answered something else: %', v;
  end if;

  select result into v from public.staff_invite_test_journal where step = 'cancel_own_branch';
  if v is distinct from jsonb_build_object('ok', true) then
    raise exception 'FAIL 5.7: a manager could not withdraw their own branch: % / %',
      v, (select error from public.staff_invite_test_journal where step = 'cancel_own_branch');
  end if;
  -- The row that was just withdrawn answers as withdrawn, where it answered as an
  -- invitation a moment before.
  if (select public.admin_invitation_lookup(
        '5751ee01-0000-4000-8000-000000000011'::uuid))
     is distinct from jsonb_build_object('ok', false, 'reason', 'cancelled') then
    raise exception 'FAIL 5.8: a code of a withdrawn invitation still answered';
  end if;

  if (select count(*) from identity.audit_log where action = 'staff.invite.cancel') <> 2 then
    raise exception 'FAIL 5.9: the two withdrawals were audited % times',
      (select count(*) from identity.audit_log where action = 'staff.invite.cancel');
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 6. The static end state.
-- ---------------------------------------------------------------------------
do $$
declare v_count int;
begin
  -- Closed to every client role, with no policy to open it again.
  if not (select t.relrowsecurity from pg_class t
           join pg_namespace ns on ns.oid = t.relnamespace
          where ns.nspname = 'identity' and t.relname = 'staff_invitations') then
    raise exception 'FAIL 6: the invitations table has no row level security';
  end if;
  select count(*) into v_count from pg_policies
   where schemaname = 'identity' and tablename = 'staff_invitations';
  if v_count <> 0 then
    raise exception 'FAIL 6: the invitations table has % policies', v_count;
  end if;
  select count(*) into v_count from information_schema.role_table_grants
   where table_schema = 'identity' and table_name = 'staff_invitations'
     and grantee in ('anon', 'authenticated', 'service_role');
  if v_count <> 0 then
    raise exception 'FAIL 6: a client role holds a direct privilege on the invitations table';
  end if;

  -- The six functions are the only doors, and each is a definer with no path.
  select count(*) into v_count from pg_proc pr
    join pg_namespace ns on ns.oid = pr.pronamespace
   where ns.nspname = 'public'
     and pr.proname in ('admin_invite_staff', 'admin_staff_invite_options',
                        'admin_staff_invitations',
                        'admin_cancel_invitation', 'admin_invitation_lookup',
                        'admin_accept_invitation')
     and pr.prosecdef
     and array_to_string(pr.proconfig, ',') = 'search_path=""';
  if v_count <> 6 then
    raise exception 'FAIL 6: % of the six functions are definers with an empty search_path', v_count;
  end if;

  -- Only the lookup answers to a visitor without an account.
  if not has_function_privilege('anon', 'public.admin_invitation_lookup(uuid)', 'EXECUTE') then
    raise exception 'FAIL 6: the dashboard cannot look a code up before signing in';
  end if;
  if has_function_privilege('anon', 'public.admin_invite_staff(text,text,text,uuid)', 'EXECUTE')
     or has_function_privilege('anon', 'public.admin_staff_invite_options()', 'EXECUTE')
     or has_function_privilege('anon', 'public.admin_staff_invitations()', 'EXECUTE')
     or has_function_privilege('anon', 'public.admin_cancel_invitation(uuid)', 'EXECUTE')
     or has_function_privilege('anon', 'public.admin_accept_invitation(uuid)', 'EXECUTE') then
    raise exception 'FAIL 6: an invitation function is reachable by anon';
  end if;
  if not has_function_privilege('authenticated', 'public.admin_accept_invitation(uuid)', 'EXECUTE') then
    raise exception 'FAIL 6: the invited account cannot execute the accept step';
  end if;

  -- One code per row, and a row that never got a date still has a deadline.
  select count(*) into v_count from pg_constraint
   where conrelid = 'identity.staff_invitations'::regclass and contype = 'u';
  if v_count <> 1 then
    raise exception 'FAIL 6: the token column is not unique on its own (% unique constraints)', v_count;
  end if;
  if (select column_default from information_schema.columns
         where table_schema = 'identity' and table_name = 'staff_invitations'
           and column_name = 'expires_at') is null then
    raise exception 'FAIL 6: an invitation without a date has no deadline';
  end if;

  -- The staff directory still answers with the account the invitation hired.
  if not exists (select 1 from identity.staff_members sm
                  where sm.email = 'invited.hire@test.local'
                    and sm.status = 'active') then
    raise exception 'FAIL 6: the hired account is not in the directory';
  end if;
end $$;

select
  'reached the end: no assertion failed' as verdict,
  (select count(*) from identity.staff_invitations) as invitations,
  (select count(*) from identity.staff_invitations where status = 'pending') as still_pending,
  (select count(*) from identity.staff_invitations where status = 'accepted') as accepted,
  (select full_name from identity.staff_members
    where email = 'invited.hire@test.local') as hired,
  (select count(*) from identity.audit_log
    where action like 'staff.invite%') as invite_audit_rows;

rollback;
