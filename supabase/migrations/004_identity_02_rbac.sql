-- 004_identity_02_rbac.sql
-- Decision D2: staff are NOT customers. staff_members is separate from
-- profiles and is never auto-populated -- creation is invitation only.
--
-- A valid email maps to exactly one auth.users row, therefore one person can be
-- a customer OR staff, never both under the same email. That constraint is
-- technical, not a design gap, and is recorded in DATABASE_SPEC.md section 2.2.

create table if not exists identity.staff_members (
  id           uuid primary key default extensions.gen_random_uuid(),
  user_id      uuid not null unique references auth.users(id) on delete restrict,
  status       text not null default 'invited'
                 check (status in ('invited','active','suspended')),
  full_name    text not null,
  email        text not null unique,
  invited_by   uuid references identity.staff_members(id) on delete set null,
  invited_at   timestamptz not null default now(),
  accepted_at  timestamptz,
  suspended_at timestamptz,
  created_at   timestamptz not null default now(),
  constraint ck_staff_email_lowercase check (email = lower(email))
);

comment on table identity.staff_members is
  'Back-office staff. Separate from profiles. Only an existing auth.users row may be promoted.';

create index if not exists ix_staff_status on identity.staff_members (status);
create index if not exists ix_staff_invited_by on identity.staff_members (invited_by);

-- ---------------------------------------------------------------------------
-- Roles / permissions
-- ---------------------------------------------------------------------------
create table if not exists identity.roles (
  id          uuid primary key default extensions.gen_random_uuid(),
  code        text not null unique check (code ~ '^[a-z_]+$'),
  name_ar     text not null,
  name_en     text not null,
  description text,
  is_system   boolean not null default false,
  created_at  timestamptz not null default now()
);

comment on table identity.roles is
  'Admin roles. is_system roles cannot be deleted.';

create table if not exists identity.permissions (
  id          uuid primary key default extensions.gen_random_uuid(),
  code        text not null unique check (code ~ '^[a-z_]+\.[a-z_]+$'),
  name_ar     text not null,
  description text
);

comment on table identity.permissions is
  'Permission codes follow <domain>.<action>, e.g. catalog.product.write.';

create table if not exists identity.role_permissions (
  role_id       uuid not null references identity.roles(id) on delete cascade,
  permission_id uuid not null references identity.permissions(id) on delete cascade,
  primary key (role_id, permission_id)
);

create index if not exists ix_role_permissions_perm
  on identity.role_permissions (permission_id);

-- ---------------------------------------------------------------------------
-- Role assignment, optionally scoped to a single branch (D1).
-- branch_id NULL means "all branches" (owner only).
-- ---------------------------------------------------------------------------
create table if not exists identity.staff_roles (
  staff_id  uuid not null references identity.staff_members(id) on delete cascade,
  role_id   uuid not null references identity.roles(id) on delete restrict,
  branch_id uuid,
  granted_by uuid references identity.staff_members(id) on delete set null,
  created_at timestamptz not null default now(),
  primary key (staff_id, role_id)
);

comment on table identity.staff_roles is
  'Staff to role mapping. branch_id NULL = all branches. One role per staff (PK).';

-- NULL is not equal to NULL, so a plain UNIQUE(staff_id, role_id, branch_id)
-- would happily accept duplicate all-branch grants. Use an expression index.
create unique index if not exists uq_staff_role_scope
  on identity.staff_roles (staff_id, role_id, coalesce(branch_id, '00000000-0000-0000-0000-000000000000'::uuid));

create index if not exists ix_staff_roles_branch on identity.staff_roles (branch_id);

-- ---------------------------------------------------------------------------
-- Audit log. Written only by triggers and SECURITY DEFINER functions.
-- Never writable by a client.
-- ---------------------------------------------------------------------------
create table if not exists identity.audit_log (
  id            bigserial primary key,
  actor_user_id uuid references auth.users(id) on delete set null,
  actor_role    text,
  action        text not null,
  entity_type   text not null,
  entity_id     uuid,
  branch_id     uuid,
  old_values    jsonb,
  new_values    jsonb,
  ip            inet,
  created_at    timestamptz not null default now(),
  constraint ck_audit_no_secrets check (
    coalesce(old_values::text,'') !~* '(password|secret|token|api[_-]?key)'
    and coalesce(new_values::text,'') !~* '(password|secret|token|api[_-]?key)'
  )
);

comment on table identity.audit_log is
  'Audit trail for sensitive operations. A CHECK guard blocks password/secret/token keys.';

create index if not exists ix_audit_entity
  on identity.audit_log (entity_type, entity_id, created_at desc);
create index if not exists ix_audit_actor
  on identity.audit_log (actor_user_id, created_at desc);
create index if not exists ix_audit_branch
  on identity.audit_log (branch_id, created_at desc);

create or replace function identity.audit(
  p_action text,
  p_entity_type text,
  p_entity_id uuid default null,
  p_old jsonb default null,
  p_new jsonb default null,
  p_branch_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  insert into identity.audit_log
    (actor_user_id, actor_role, action, entity_type, entity_id, branch_id, old_values, new_values)
  values
    (auth.uid(), auth.role(), p_action, p_entity_type, p_entity_id, p_branch_id, p_old, p_new);
end;
$fn$;

comment on function identity.audit is
  'Append an audit row, stamping the caller identity. SECURITY DEFINER, empty search_path.';

-- NOTE: the D9 read view identity.user_points joins loyalty.loyalty_accounts,
-- which does not exist until 014. Postgres resolves view relations at CREATE
-- time, so the view is created in 014 instead.