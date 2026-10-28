-- ---------------------------------------------------------------------------
-- 189_replay_catchup_for_cli_skipped_files.sql
--
-- WHY THIS EXISTS
-- The Supabase CLI only applies a file named `^([0-9]+)_(.*)\.sql$` and records
-- the numeric part in `supabase_migrations.schema_migrations`. Four files in this
-- directory carry a letter suffix and are therefore invisible to the CLI:
--
--   004b_identity_03_permissions_name_en.sql
--   004c_identity_04_permission_code_pattern.sql
--   007b_catalog_05_categories_slug.sql
--   012b_inventory_02_variant_key_validation.sql
--
-- They were each written as a "corrective migration" after a gap was found while
-- seeding, and they were applied by hand into the development project, so the
-- live database is correct today. The problem is the opposite direction: an
-- environment built only from the numbered chain -- `supabase db reset`, a new
-- project, a CI template -- never runs them, and that database is unusable:
--
--   * identity.permissions has no `name_en`, so every permission label is
--     single-language and decision D4 (bilingual by construction) is broken;
--   * identity.permissions.code is CHECKed as `^[a-z_]+\.[a-z_]+$`, which
--     rejects the real codes the app writes (`catalog.product.write`,
--     `orders.status.update`), so RBAC seeding fails outright;
--   * catalog.categories has no `slug`, which is the column the catalogue
--     repositories and the admin URLs resolve categories by;
--   * inventory.branch_stock keeps the `variant_key -> catalog.option_values`
--     foreign key, which rejects the "no variant" sentinel
--     00000000-0000-0000-0000-000000000000, so no stock row can be created at
--     all under decision D8.
--
-- WHAT THIS DOES
-- Re-applies the four effects, statement for statement, in the original order,
-- using only the idempotent forms the originals already used
-- (`add column if not exists`, `drop constraint if exists`, `create or replace
-- function`, `drop/create trigger`, a guarded `add constraint`). Nothing is
-- rewritten, renamed or "improved". `test/migration_chain_test.dart` holds the
-- map from each skipped file to this migration and fails if the effect is ever
-- removed from here.
--
-- Running it against a database that already has these effects (the development
-- project) changes nothing: every statement either re-applies an identical
-- definition or is skipped by its own guard.
--
-- WHAT IS NOT CHANGED
-- * The four skipped files stay exactly where they are. An environment that ran
--   them by hand is untouched, and deleting them would erase the record of what
--   was applied there.
-- * The 002b effect already reached the numbered chain through 050; it is not
--   repeated here.
-- * No data, no RLS policy, no grant, no business rule.
--
-- ROLLBACK
-- This migration only moves the schema toward the state the hand-applied files
-- already produced, so there is nothing to roll back to on an existing project.
-- To undo deliberately, restore the narrow CHECK, drop the two variant triggers
-- and re-add the stock foreign key, and drop `permissions.name_en` and
-- `categories.slug` -- which would put the database behind the app.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- 1. 004b_identity_03_permissions_name_en.sql
--    identity.permissions had name_ar but no name_en.
-- ---------------------------------------------------------------------------
alter table identity.permissions
  add column if not exists name_en text;

update identity.permissions
   set name_en = code
 where name_en is null;

alter table identity.permissions
  alter column name_en set not null;

comment on column identity.permissions.name_en is
  'English label. Required by D4 (bilingual by construction).';

-- ---------------------------------------------------------------------------
-- 2. 004c_identity_04_permission_code_pattern.sql
--    The original CHECK allowed exactly one dot, so real codes such as
--    catalog.product.write were rejected. Widened to one or more segments.
-- ---------------------------------------------------------------------------
alter table identity.permissions
  drop constraint if exists permissions_code_check;

alter table identity.permissions
  add constraint permissions_code_check
  check (code ~ '^[a-z_]+(\.[a-z_]+)+$');

comment on constraint permissions_code_check on identity.permissions is
  'Lowercase, dot-separated segments. Allows catalog.product.write as well as orders.read.';

-- ---------------------------------------------------------------------------
-- 3. 007b_catalog_05_categories_slug.sql
--    catalog.categories had no slug; the app resolved categories by name string.
-- ---------------------------------------------------------------------------
alter table catalog.categories
  add column if not exists slug text;

update catalog.categories
   set slug = core.slugify(name_en)
 where slug is null;

alter table catalog.categories
  alter column slug set not null;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'categories_slug_unique' and conrelid = 'catalog.categories'::regclass
  ) then
    alter table catalog.categories
      add constraint categories_slug_unique unique (slug);
  end if;
end $$;

create index if not exists ix_categories_slug on catalog.categories (slug);

comment on column catalog.categories.slug is
  'Stable public identifier for the category. Replaces name-string matching (CategoryModel.label).';

-- ---------------------------------------------------------------------------
-- 4. 012b_inventory_02_variant_key_validation.sql
--    variant_key pointed at catalog.option_values with a foreign key, but the
--    D8 sentinel has no option_values row, so stock could never be written. A
--    conditional foreign key is not expressible, so the invariant moves into a
--    deferred trigger.
-- ---------------------------------------------------------------------------
alter table inventory.branch_stock
  drop constraint if exists fk_branch_stock_variant;

create or replace function inventory.validate_stock_variant()
returns trigger
language plpgsql
as $fn$
declare
  v_sentinel constant uuid := '00000000-0000-0000-0000-000000000000'::uuid;
begin
  if new.variant_key = v_sentinel then
    return new;
  end if;

  if not exists (
    select 1
    from catalog.option_values ov
    join catalog.product_option_groups pog on pog.group_id = ov.group_id
    where ov.id = new.variant_key
      and pog.product_id = new.product_id
  ) then
    raise exception
      'variant_key % is not an option offered by product %', new.variant_key, new.product_id
      using errcode = '23503';
  end if;

  return new;
end;
$fn$;

comment on function inventory.validate_stock_variant() is
  'Enforces that variant_key is either the sentinel or a real option bound to the product.';

drop trigger if exists tr_branch_stock_variant on inventory.branch_stock;
create constraint trigger tr_branch_stock_variant
  after insert or update of variant_key, product_id on inventory.branch_stock
  deferrable initially deferred
  for each row execute function inventory.validate_stock_variant();

-- stock_movements carries the same column; validate it the same way.
alter table inventory.stock_movements
  drop constraint if exists fk_movements_variant;

create or replace function inventory.validate_movement_variant()
returns trigger
language plpgsql
as $fn$
declare
  v_sentinel constant uuid := '00000000-0000-0000-0000-000000000000'::uuid;
begin
  if new.variant_key = v_sentinel then
    return new;
  end if;
  if not exists (select 1 from catalog.option_values ov where ov.id = new.variant_key) then
    raise exception 'unknown variant_key %', new.variant_key using errcode = '23503';
  end if;
  return new;
end;
$fn$;

drop trigger if exists tr_movements_variant on inventory.stock_movements;
create constraint trigger tr_movements_variant
  after insert on inventory.stock_movements
  deferrable initially deferred
  for each row execute function inventory.validate_movement_variant();

notify pgrst, 'reload schema';
