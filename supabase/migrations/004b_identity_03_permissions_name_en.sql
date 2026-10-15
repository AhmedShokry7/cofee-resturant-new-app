-- 004b_identity_03_permissions_name_en.sql
--
-- Gap found while seeding: identity.permissions had name_ar but no name_en,
-- which breaks decision D4 (every human-readable label is bilingual).
-- roles, branches, categories and products all carry both.
--
-- Added as a corrective migration rather than an edit of 004, per
-- DATABASE_SPEC.md section 11.

alter table identity.permissions
  add column if not exists name_en text;

update identity.permissions
   set name_en = code
 where name_en is null;

alter table identity.permissions
  alter column name_en set not null;

comment on column identity.permissions.name_en is
  'English label. Required by D4 (bilingual by construction).';