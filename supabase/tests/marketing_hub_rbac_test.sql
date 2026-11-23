-- P0.5 LOCAL TEST ONLY. Run in isolated non-production DB, never remote.
-- Requires p05_marketing_rbac_edge_integration.PROPOSED.sql and existing RBAC.

\set ON_ERROR_STOP on

select case when exists (
  select 1 from identity.permissions
   where code in ('marketing.read','marketing.create','marketing.review','marketing.schedule','marketing.send','marketing.consent.read','marketing.consent.write')
) then 'PASS marketing permissions seeded'
else 'FAIL marketing permissions missing' end as permissions;

-- marketing.consent.write must not be granted to manager by default.
select case when not exists (
  select 1
  from identity.roles r
  join identity.role_permissions rp on rp.role_id = r.id
  join identity.permissions p on p.id = rp.permission_id
   where r.code = 'manager' and p.code = 'marketing.consent.write'
) then 'PASS manager does not hold consent write by default'
else 'FAIL manager holds consent write by default' end as manager_consent_write;

-- Branch manager receives read only by default.
select case when not exists (
  select 1
  from identity.roles r
  join identity.role_permissions rp on rp.role_id = r.id
  join identity.permissions p on p.id = rp.permission_id
   where r.code = 'branch_manager' and p.code like 'marketing.%' and p.code <> 'marketing.read'
) then 'PASS branch_manager marketing defaults are read-only'
else 'FAIL branch_manager has extra marketing permissions' end as branch_manager;

-- Escalation guard must exist in the RPC itself (not just the UI).
select case when pg_get_functiondef('public.admin_set_role_permission(uuid, text, boolean)'::regprocedure)
  like '%owner-only permission%'
  then 'PASS admin_set_role_permission has owner-only guard'
else 'FAIL admin_set_role_permission missing owner-only guard' end as rpc_guard;

select case when pg_get_functiondef('public.admin_set_role_permission(uuid, text, boolean)'::regprocedure)
  like '%cannot modify a role you hold%'
  then 'PASS admin_set_role_permission blocks self-escalation'
else 'FAIL admin_set_role_permission missing self-escalation guard' end as self_guard;

-- Cashier receives no marketing permissions by default.
select case when not exists (
  select 1
  from identity.roles r
  join identity.role_permissions rp on rp.role_id = r.id
  join identity.permissions p on p.id = rp.permission_id
   where r.code = 'cashier' and p.code like 'marketing.%'
) then 'PASS cashier has no marketing permissions by default'
else 'FAIL cashier has marketing permissions by default' end as cashier;
