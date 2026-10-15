-- 004d_catalog_05_categories_slug.sql
--
-- Gap found while seeding: catalog.categories had no slug. Products and
-- branches both had one, and the app resolves a category by name string
-- (CategoryModel.label), which is exactly the fragility this schema is meant
-- to remove. A stable slug is also needed for deep links and admin URLs.
--
-- Backfilled from the existing English name so existing rows are never null.

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