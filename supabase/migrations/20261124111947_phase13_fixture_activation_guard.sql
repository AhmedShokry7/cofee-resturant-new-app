-- Enforce the Phase 1.3 fixture's private status at the database boundary.
-- These constraints affect only the three run-specific fixture rows.
begin;

alter table core.branches add constraint phase13_branch_must_stay_inactive
  check (id <> '10dbfb03-ed35-4a79-9116-c44c7bb0ec66'::uuid or is_active = false);
alter table catalog.categories add constraint phase13_category_must_stay_inactive
  check (id <> 'c4333e36-5ac9-446d-9394-eb043fc24d03'::uuid or is_active = false);
alter table catalog.products add constraint phase13_product_must_stay_inactive
  check (id <> '8d98c73d-43e9-484f-9dab-9a10d0513e70'::uuid or is_active = false);

commit;
