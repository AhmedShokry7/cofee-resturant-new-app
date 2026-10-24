-- 123_unify_admin_identity.sql
--
-- Identity unification for the admin application.
--
-- Decision (DATABASE_SPEC.md D2): identity.staff_members is the canonical
-- source of staff identity. identity.admins is a legacy duplicate that exists
-- only in the live database and is not created by any migration in the chain.
--
-- This migration:
--   * re-points the identity helper functions and provisioning to staff_members;
--   * re-points the legacy public.admin_get_my_admin_record() shim to
--     staff_members and removes its anonymous/public EXECUTE grant;
--   * leaves identity.admins untouched (data preserved) but marks it legacy;
--   * verifies that no staff_roles rows are orphaned before committing.
--
-- It does NOT:
--   * drop or truncate identity.admins;
--   * delete or recreate any staff record;
--   * reassign roles or permissions;
--   * edit any previously applied migration (including 092).
--
-- IMPORTANT — migration-chain blocker (not fixed here, see the report):
--   092_db_hardening.sql:240 runs
--       alter table identity.admins enable row level security;
--   unconditionally. No migration in 001..091 creates identity.admins, so on a
--   fresh database that statement raises SQLSTATE 42P01 and aborts the chain
--   before this migration (or 093..122) can run. Editing 092 would violate
--   DATABASE_SPEC.md section 11 ("do not modify an applied migration"), so the
--   remediation requires explicit owner approval. The conditional-DDL patch is
--   documented in the task report; it is NOT applied by this file.
--
-- Idempotent: safe to re-run. No production writes are performed by this file
-- being authored; applying it is a separate, owner-approved step.

-- ---------------------------------------------------------------------------
-- A. Canonical identity helpers — all read identity.staff_members.
-- ---------------------------------------------------------------------------

create or replace function identity.is_staff()
returns boolean
language sql
stable
security definer
set search_path = ''
as $fn$
  select exists (
    select 1
    from identity.staff_members
    where user_id = auth.uid()
      and status = 'active'
  );
$fn$;

create or replace function identity.has_permission(p_code text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $fn$
  select exists (
    select 1
    from identity.staff_members sm
    join identity.staff_roles sr on sr.staff_id = sm.id
    join identity.roles r on r.id = sr.role_id
    where sm.user_id = auth.uid()
      and sm.status = 'active'
      and (
        r.code = 'owner'
        or exists (
          select 1
          from identity.role_permissions rp
          join identity.permissions p on p.id = rp.permission_id
          where rp.role_id = r.id
            and p.code = p_code
        )
      )
  );
$fn$;

create or replace function identity.can_manage_branch(p_branch_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $fn$
  select exists (
    select 1
    from identity.staff_members sm
    join identity.staff_roles sr on sr.staff_id = sm.id
    where sm.user_id = auth.uid()
      and sm.status = 'active'
      and (sr.branch_id is null or sr.branch_id = p_branch_id)
  );
$fn$;

create or replace function identity.manages_all_branches()
returns boolean
language sql
stable
security definer
set search_path = ''
as $fn$
  select exists (
    select 1
    from identity.staff_members sm
    join identity.staff_roles sr on sr.staff_id = sm.id
    where sm.user_id = auth.uid()
      and sm.status = 'active'
      and sr.branch_id is null
  );
$fn$;

-- ---------------------------------------------------------------------------
-- B. Secure staff provisioning — canonical source is staff_members.
--    Body reproduced from 080_admin_staff_provisioning_and_customer_read.sql
--    (the only difference from the live version is the target table).
-- ---------------------------------------------------------------------------

create or replace function identity.provision_staff(
  p_user_id uuid,
  p_full_name text,
  p_email text,
  p_role_code text,
  p_branch_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_staff_id uuid;
  v_role_id uuid;
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  if not identity.has_permission('admin.staff.write') then
    raise exception 'admin.staff.write permission required' using errcode = '42501';
  end if;
  if not identity.has_permission('admin.role.write') then
    raise exception 'admin.role.write permission required' using errcode = '42501';
  end if;

  if not exists (select 1 from auth.users where id = p_user_id) then
    raise exception 'auth user % not found', p_user_id using errcode = 'P0002';
  end if;

  if nullif(btrim(coalesce(p_full_name, '')), '') is null then
    raise exception 'full name required' using errcode = '22023';
  end if;
  if nullif(btrim(coalesce(p_email, '')), '') is null then
    raise exception 'email required' using errcode = '22023';
  end if;

  select id into v_role_id
    from identity.roles
   where code = p_role_code;
  if v_role_id is null then
    raise exception 'unknown role %', p_role_code using errcode = '22023';
  end if;

  -- Prevent privilege escalation: only an active owner may provision an owner.
  if p_role_code = 'owner' and not exists (
    select 1
    from identity.staff_members sm
    join identity.staff_roles sr on sr.staff_id = sm.id
    join identity.roles r on r.id = sr.role_id
    where sm.user_id = v_uid
      and sm.status = 'active'
      and r.code = 'owner'
  ) then
    raise exception 'only owners may provision owners' using errcode = '42501';
  end if;

  if p_branch_id is null then
    if not identity.manages_all_branches() then
      raise exception 'all-branch staff assignment requires global scope' using errcode = '42501';
    end if;
  else
    if not identity.can_manage_branch(p_branch_id) then
      raise exception 'you do not manage this branch' using errcode = '42501';
    end if;
  end if;

  if exists (select 1 from identity.staff_members where user_id = p_user_id) then
    raise exception 'staff member already exists for this user' using errcode = '23505';
  end if;

  insert into identity.staff_members (user_id, status, full_name, email)
  values (p_user_id, 'invited', btrim(p_full_name), lower(btrim(p_email)))
  returning id into v_staff_id;

  insert into identity.staff_roles (staff_id, role_id, branch_id, granted_by)
  select v_staff_id, v_role_id, p_branch_id, sm.id
    from identity.staff_members sm
   where sm.user_id = auth.uid()
  on conflict do nothing;

  perform identity.audit(
    'staff.provision',
    'staff_member',
    v_staff_id,
    null,
    jsonb_build_object('user_id', p_user_id, 'role', p_role_code, 'branch_id', p_branch_id),
    p_branch_id
  );

  return v_staff_id;
end;
$fn$;

comment on function identity.provision_staff(uuid, text, text, text, uuid) is
  'Invite/activate a staff member securely (admin.staff.write + admin.role.write).';

-- Least-privilege grants (idempotent).
revoke all on function identity.provision_staff(uuid, text, text, text, uuid) from public;
revoke execute on function identity.provision_staff(uuid, text, text, text, uuid) from anon;
grant execute on function identity.provision_staff(uuid, text, text, text, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- C. Legacy authentication RPC: admin_get_my_admin_record().
--
-- The migration chain (082) creates admin_get_my_staff_record() on
-- staff_members. The older admin_get_my_admin_record() exists only in the live
-- database and reads identity.admins. To keep any lingering caller working
-- without a second identity source, this shim now delegates to the canonical
-- function. Anonymous/public EXECUTE is revoked; only authenticated staff may
-- call it. The canonical client path (admin_auth_repository.dart) uses
-- admin_get_my_staff_record() directly.
-- ---------------------------------------------------------------------------

create or replace function public.admin_get_my_admin_record()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $fn$
  select public.admin_get_my_staff_record();
$fn$;

-- Harden grants: the function must never be callable by anon or PUBLIC.
revoke all on function public.admin_get_my_admin_record() from public;
revoke execute on function public.admin_get_my_admin_record() from anon;
grant execute on function public.admin_get_my_admin_record() to authenticated;

comment on function public.admin_get_my_admin_record() is
  'DEPRECATED shim: delegates to public.admin_get_my_staff_record(). Retained for backward compatibility only; new code must use admin_get_my_staff_record().';

-- ---------------------------------------------------------------------------
-- D. Mark identity.admins as legacy (conditional — absent on fresh builds).
--    The table and its data are preserved. No trigger is added: writes are not
--    blocked, but every identity function now reads staff_members exclusively,
--    so admins can no longer drift through the application path.
-- ---------------------------------------------------------------------------

do $$
begin
  if exists (
    select 1
    from pg_tables
    where schemaname = 'identity'
      and tablename = 'admins'
  ) then
    execute 'comment on table identity.admins is ''LEGACY (deprecated): duplicate of identity.staff_members. Canonical source is identity.staff_members (DATABASE_SPEC.md D2). Retained for backward compatibility and historical data; do not write to it.''';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- E. Pre-flight verification (read-only; raises only on proven inconsistency).
-- ---------------------------------------------------------------------------

do $$
declare
  v_staff integer;
  v_admins integer;
  v_orphan_roles integer;
  v_orphan_granted_by integer;
begin
  select count(*) into v_staff
  from identity.staff_members;

  if exists (
    select 1
    from pg_tables
    where schemaname = 'identity'
      and tablename = 'admins'
  ) then
    execute 'select count(*) from identity.admins' into v_admins;
    raise notice 'identity.admins rows: %, identity.staff_members rows: %', v_admins, v_staff;
  else
    raise notice 'identity.admins is absent; canonical source identity.staff_members has % rows', v_staff;
  end if;

  select count(*) into v_orphan_roles
  from identity.staff_roles sr
  where not exists (
    select 1
    from identity.staff_members sm
    where sm.id = sr.staff_id
  );

  select count(*) into v_orphan_granted_by
  from identity.staff_roles sr
  where sr.granted_by is not null
    and not exists (
      select 1
      from identity.staff_members sm
      where sm.id = sr.granted_by
    );

  if v_orphan_roles > 0 or v_orphan_granted_by > 0 then
    raise exception 'identity unification precondition failed: orphaned staff_roles (staff_id=%, granted_by=%)',
      v_orphan_roles, v_orphan_granted_by
      using errcode = '23514';
  end if;

  raise notice 'identity unification: % staff_members, 0 orphaned staff_roles/granted_by', v_staff;
end $$;

notify pgrst, 'reload schema';
