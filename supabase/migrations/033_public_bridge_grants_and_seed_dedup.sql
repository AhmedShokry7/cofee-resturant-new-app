-- 033_public_bridge_grants_and_seed_dedup.sql
--
-- Fixes found by probing the bridge through PostgREST as a real anon client.

-- ---------------------------------------------------------------------------
-- PART 1 -- grants that security_invoker views need.
--
-- A view created WITH (security_invoker = true) executes with the privileges of
-- the CALLING role, not the view owner. So anon needs SELECT on the BASE table,
-- not only on the view. Three base tables were missed by 023_grants_01.sql,
-- which is why faq_items, onboarding_slides and app_settings answered 42501.
-- ---------------------------------------------------------------------------
grant select on
  core.faq_items,
  core.onboarding_slides,
  core.app_settings
  to anon;

-- product_images is also read through a view, so keep it symmetrical.
grant select on catalog.product_images, catalog.categories, catalog.products
  to anon;

-- ---------------------------------------------------------------------------
-- PART 2 -- the seed was not idempotent for tables with no natural key.
--
-- Running seed_03 twice produced 8 bundles instead of 4, 16 bundle_items
-- instead of 8, and 10 banners instead of 5. The inserts carried
-- `on conflict do nothing`, but there was no unique key for the conflict to
-- match on, so every run added fresh rows.
--
-- Order matters: the duplicates must be removed BEFORE the unique key is
-- added, otherwise the key cannot be created.
-- ---------------------------------------------------------------------------
-- Keep one row per natural key.
-- Postgres has no min(uuid), and the three tables do not share a timestamp
-- column (marketing.banners has none), so rank on the id text. Which duplicate
-- survives does not matter; only that exactly one does.
delete from catalog.bundles b
 where b.id in (
   select id from (
     select id, row_number() over (
       partition by name_en order by id::text) rn
     from catalog.bundles
   ) t where rn > 1
 );

-- bundle_items reference bundles by id, so drop the ones orphaned by the delete
-- above, then collapse the ones a second seed run duplicated.
delete from catalog.bundle_items bi
 where not exists (select 1 from catalog.bundles b where b.id = bi.bundle_id);

delete from catalog.bundle_items bi
 where bi.id in (
   select id from (
     select id, row_number() over (
       partition by bundle_id, product_id order by id::text) rn
     from catalog.bundle_items
   ) t where rn > 1
 );

delete from marketing.banners b
 where b.id in (
   select id from (
     select id, row_number() over (
       partition by title_en order by id::text) rn
     from marketing.banners
   ) t where rn > 1
 );

-- Now the natural keys can exist.
do $$
begin
  if not exists (select 1 from pg_constraint
                 where conname = 'bundles_name_en_key' and conrelid = 'catalog.bundles'::regclass) then
    alter table catalog.bundles add constraint bundles_name_en_key unique (name_en);
  end if;
  if not exists (select 1 from pg_constraint
                 where conname = 'banners_title_en_key' and conrelid = 'marketing.banners'::regclass) then
    alter table marketing.banners add constraint banners_title_en_key unique (title_en);
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- PART 3 -- reload the schema cache so PostgREST sees the new constraints.
-- The views themselves are unchanged, but a fresh reload keeps the cache honest.
-- ---------------------------------------------------------------------------
notify pgrst, 'reload config';
notify pgrst, 'reload schema';