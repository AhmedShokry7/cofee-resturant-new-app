-- 192_cashier_orders_cancel.sql
--
-- Owner decision (2026-10-27): the cashier role may cancel orders.
--
-- Why this is a migration and not a dashboard edit: migration 137 seeds
-- identity.role_permissions and deliberately leaves 'orders.cancel' out of the
-- cashier set, so a database rebuilt from this chain would take the permission
-- away again. The POS screen already routes a cancelled sale through
-- orders.cancel_order, which demands orders.cancel, so without this grant the
-- cashier hits a dead end the UI does not warn about.
--
-- Scope: the grant only makes orders.cancel_order reachable. The status matrix
-- in orders.status_transitions (13 edges) still decides which transitions any
-- role can perform, and identity.can_manage_branch() still limits the rows to
-- the staff member's own branch.

insert into identity.role_permissions (role_id, permission_id)
select r.id, p.id
  from identity.roles r
  join identity.permissions p on p.code = 'orders.cancel'
 where r.code = 'cashier'
on conflict do nothing;
