-- 080_admin_staff_provisioning_and_customer_read.sql
--
-- Database-only remediation for secure staff provisioning and admin customer
-- read access. No application code is changed.

-- ---------------------------------------------------------------------------
-- Permission for customer management (least-privilege read).
-- ---------------------------------------------------------------------------
insert into identity.permissions (code, name_ar, name_en, description)
values ('customers.read', 'قراءة العملاء', 'Read customers', 'Read customer profiles and addresses')
on conflict (code) do nothing;

-- Grant to roles that legitimately manage customers.
insert into identity.role_permissions (role_id, permission_id)
select r.id, p.id
from identity.roles r
cross join identity.permissions p
where r.code in ('owner', 'manager')
  and p.code = 'customers.read'
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- Admin read access to customer data (RLS, staff only).
-- ---------------------------------------------------------------------------
drop policy if exists profiles_select_staff on identity.profiles;
create policy profiles_select_staff
  on identity.profiles
  for select
  to authenticated
  using (identity.has_permission('customers.read'));

drop policy if exists customer_addresses_select_staff on identity.customer_addresses;
create policy customer_addresses_select_staff
  on identity.customer_addresses
  for select
  to authenticated
  using (identity.has_permission('customers.read'));

-- ---------------------------------------------------------------------------
-- Secure staff provisioning path (assumes the auth.users row already exists,
-- e.g. created by an invitation flow using the service role).
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

-- Least-privilege grants for the provisioning RPC.
revoke all on function identity.provision_staff(uuid, text, text, text, uuid) from public;
revoke execute on function identity.provision_staff(uuid, text, text, text, uuid) from anon;
grant execute on function identity.provision_staff(uuid, text, text, text, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Branch-scoped role assignment: prevent cross-branch privilege grants.
-- ---------------------------------------------------------------------------
drop policy if exists staff_roles_write_permitted on identity.staff_roles;
create policy staff_roles_write_permitted
  on identity.staff_roles
  for all
  to authenticated
  using (
    identity.has_permission('admin.role.write')
  )
  with check (
    identity.has_permission('admin.role.write')
    and (
      (branch_id is null and identity.manages_all_branches())
      or (branch_id is not null and identity.can_manage_branch(branch_id))
    )
  );

-- staff_members insert policy for provisioning.
drop policy if exists staff_members_insert_permitted on identity.staff_members;
create policy staff_members_insert_permitted
  on identity.staff_members
  for insert
  to authenticated
  with check (identity.has_permission('admin.staff.write'));

notify pgrst, 'reload schema';
