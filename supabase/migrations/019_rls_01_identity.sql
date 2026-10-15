-- 019_rls_01_identity.sql
-- Policies for the identity schema (D2: customer vs staff separation).

-- ---------------------------------------------------------------------------
-- profiles: strictly owner-scoped.
-- NOTE: there is deliberately NO policy that would let a user set a role,
-- because no role column exists on profiles. Roles live in staff_members,
-- which a customer can never write.
-- ---------------------------------------------------------------------------
create policy profiles_select_own on identity.profiles
  for select to authenticated
  using (id = auth.uid());

create policy profiles_insert_own on identity.profiles
  for insert to authenticated
  with check (id = auth.uid());

create policy profiles_update_own on identity.profiles
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- ---------------------------------------------------------------------------
-- customer_addresses: owner only.
-- ---------------------------------------------------------------------------
create policy addresses_all_own on identity.customer_addresses
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- staff_members: customers can see nothing. Staff need admin.staff.read.
-- There is NO insert policy for authenticated: a customer cannot promote
-- themselves, and staff creation goes through a SECURITY DEFINER path.
-- ---------------------------------------------------------------------------
create policy staff_select_permitted on identity.staff_members
  for select to authenticated
  using (identity.has_permission('admin.staff.read'));

create policy staff_update_permitted on identity.staff_members
  for update to authenticated
  using (identity.has_permission('admin.staff.write'))
  with check (identity.has_permission('admin.staff.write'));

-- ---------------------------------------------------------------------------
-- roles / permissions: read-only reference for permitted staff.
-- ---------------------------------------------------------------------------
create policy roles_select_permitted on identity.roles
  for select to authenticated
  using (identity.has_permission('admin.role.read'));

create policy permissions_select_permitted on identity.permissions
  for select to authenticated
  using (identity.has_permission('admin.role.read'));

create policy role_permissions_select_permitted on identity.role_permissions
  for select to authenticated
  using (identity.has_permission('admin.role.read'));

create policy staff_roles_select_permitted on identity.staff_roles
  for select to authenticated
  using (identity.has_permission('admin.staff.read'));

create policy staff_roles_write_permitted on identity.staff_roles
  for all to authenticated
  using (identity.has_permission('admin.role.write'))
  with check (identity.has_permission('admin.role.write'));

-- ---------------------------------------------------------------------------
-- audit_log: read for audit.read, and NO write policy at all.
-- Rows are appended only by the identity.audit() SECURITY DEFINER function.
-- ---------------------------------------------------------------------------
create policy audit_select_permitted on identity.audit_log
  for select to authenticated
  using (identity.has_permission('audit.read'));