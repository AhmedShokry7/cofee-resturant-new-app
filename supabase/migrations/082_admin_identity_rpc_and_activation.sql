-- 082_admin_identity_rpc_and_activation.sql
--
-- Secure current-staff RPC and staff activation for the admin application.
--
-- Preconditions:
--   Migrations 079, 080, 081 are applied.
--   identity.provision_staff exists and creates staff with status='invited'.
--
-- Invitation/activation design decision:
--   The current schema has no invitation token, no email verification state on
--   the staff record, and no mechanism to prove that the invited email belongs
--   to the person calling activation. Supabase Auth email confirmation only
--   proves the user controls the email AFTER activation, not before.
--
--   Therefore this migration implements ONLY the safe current-staff RPC.
--   A separate invitation design is required before activation can be safe.

-- ---------------------------------------------------------------------------
-- A. Secure current-staff RPC
--
-- SECURITY DEFINER is used because:
--   1. SECURITY INVOKER would require admin.staff.read to read own record.
--   2. auth.uid() is the sole identity source — no caller-supplied user_id.
--   3. Only returns current user's own active staff record.
--   4. search_path = '' prevents search_path hijacking.
--   5. No write operations — read-only for auth.uid() row.
--
-- RLS on identity.staff_members is bypassed by SECURITY DEFINER, but the
-- function constrains to user_id = auth.uid() explicitly, so no cross-user
-- data exposure is possible.
-- ---------------------------------------------------------------------------

create or replace function public.admin_get_my_staff_record()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_staff_id uuid;
  v_full_name text;
  v_email text;
  v_status text;
  v_accepted_at timestamptz;
  v_roles jsonb;
  v_permissions jsonb;
  v_can_manage_all boolean;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  if not identity.is_staff() then
    raise exception 'not an active staff member' using errcode = '42501';
  end if;

  select sm.id, sm.full_name, sm.email, sm.status, sm.accepted_at
    into v_staff_id, v_full_name, v_email, v_status, v_accepted_at
    from identity.staff_members sm
   where sm.user_id = v_uid and sm.status = 'active';

  if v_staff_id is null then
    raise exception 'staff record not found' using errcode = 'P0002';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
           'role_id', r.id,
           'role_code', r.code,
           'branch_id', sr.branch_id
         ) order by r.code, sr.branch_id), '[]'::jsonb)
    into v_roles
    from identity.staff_roles sr
    join identity.roles r on r.id = sr.role_id
   where sr.staff_id = v_staff_id;

  select coalesce(jsonb_agg(jsonb_build_object(
           'branch_id', sr.branch_id,
           'permissions', coalesce(
             (select jsonb_agg(p.code order by p.code)
              from identity.role_permissions rp
              join identity.permissions p on p.id = rp.permission_id
              where rp.role_id = sr.role_id),
             '[]'::jsonb
           )
         ) order by sr.branch_id), '[]'::jsonb)
    into v_permissions
    from identity.staff_roles sr
   where sr.staff_id = v_staff_id;

  select exists (
    select 1
      from identity.staff_roles sr
     where sr.staff_id = v_staff_id
       and sr.branch_id is null
  ) into v_can_manage_all;

  return jsonb_build_object(
    'staff_id', v_staff_id,
    'full_name', v_full_name,
    'email', v_email,
    'status', v_status,
    'accepted_at', v_accepted_at,
    'roles', v_roles,
    'permissions', v_permissions,
    'can_manage_all_branches', v_can_manage_all
  );
end;
$$;

revoke all on function public.admin_get_my_staff_record() from public;
revoke execute on function public.admin_get_my_staff_record() from anon;
grant execute on function public.admin_get_my_staff_record() to authenticated;

comment on function public.admin_get_my_staff_record() is
  'Returns the current authenticated user active staff record with roles and branch-scoped permissions. SECURITY DEFINER.';

notify pgrst, 'reload schema';

-- ---------------------------------------------------------------------------
-- B. Staff activation — BLOCKED
--
-- The current schema does not contain:
--   - An invitation token or one-time code
--   - A staff email verification state
--   - An expiration timestamp on invitations
--   - Any mechanism to prove the invited email belongs to the caller
--
-- Supabase Auth email confirmation proves control of the email AFTER the
-- account exists, but activation must happen BEFORE the staff record can be
-- used. Without a token or verified invitation, anyone who knows a user_id
-- could activate that user's staff record.
--
-- A separate migration is required with:
--   1. An invitation token column on staff_members
--   2. An expiration timestamp
--   3. A verify-before-activate flow
--   4. An RLS policy that only allows token-based activation
--
-- No activation function is created in this migration.
-- ---------------------------------------------------------------------------
