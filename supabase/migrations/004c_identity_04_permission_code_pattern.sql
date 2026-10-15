-- 004c_identity_04_permission_code_pattern.sql
--
-- Gap found while seeding: the permissions.code CHECK was
--   ^[a-z_]+\.[a-z_]+$
-- which permits exactly one dot, so real codes such as
--   catalog.product.write
--   catalog.category.write
--   admin.staff.write
--   orders.status.update
-- were rejected. The spec already described permissions as <domain>.<action>
-- and used three-segment examples, so the constraint was narrower than the
-- intended vocabulary.
--
-- Widened to one or more dot-separated lowercase segments.
-- Corrective migration, not an edit of 004.

alter table identity.permissions
  drop constraint if exists permissions_code_check;

alter table identity.permissions
  add constraint permissions_code_check
  check (code ~ '^[a-z_]+(\.[a-z_]+)+$');

comment on constraint permissions_code_check on identity.permissions is
  'Lowercase, dot-separated segments. Allows catalog.product.write as well as orders.read.';