-- 057_fix_rebuild_search_security_definer.sql
--
-- Fix (F5): catalog.rebuild_product_search() and catalog.rebuild_category_search()
-- were LANGUAGE sql functions running as the CALLER. Migration 023/030 granted
-- only SELECT on catalog.product_search / catalog.category_search to
-- authenticated (023:67), so when staff edited a product the AFTER trigger
-- called rebuild_*(), which tried to INSERT into the search table as the staff
-- member and died with:
--     42501 permission denied for table product_search
--
-- The tempting fix -- GRANT INSERT/UPDATE on the search tables to authenticated
-- -- would hand every signed-in user general write access to the projections.
-- Instead, run the two rebuild functions as their owner (SECURITY DEFINER) so
-- the caller needs no write privilege on the projection tables. Bodies are
-- unchanged and already fully schema-qualified, so search_path is pinned to ''.
--
-- Grant intent is untouched: the search tables stay read-only for clients.

create or replace function catalog.rebuild_product_search(p_product uuid)
returns void
language sql
security definer
set search_path = ''
as $fn$
  insert into catalog.product_search (product_id, body_norm, keywords_norm, updated_at)
  select
    p.id,
    core.normalize_ar(
      coalesce(p.name_ar,'') || ' ' || coalesce(p.name_en,'') || ' ' ||
      coalesce(p.description_ar,'') || ' ' || coalesce(p.description_en,'') || ' ' ||
      coalesce(p.sku,'') || ' ' ||
      coalesce(c.name_ar,'') || ' ' || coalesce(c.name_en,'') || ' ' ||
      coalesce((select string_agg(a.alias, ' ')
                from catalog.product_aliases a where a.product_id = p.id), '')
    ),
    array_remove(array[
      core.normalize_ar(p.name_ar),
      core.normalize_ar(p.name_en),
      core.normalize_ar(c.name_ar),
      core.normalize_ar(c.name_en)
    ]::text[], ''),
    now()
  from catalog.products p
  join catalog.categories c on c.id = p.category_id
  where p.id = p_product
  on conflict (product_id) do update
    set body_norm = excluded.body_norm,
        keywords_norm = excluded.keywords_norm,
        updated_at = now();
$fn$;

create or replace function catalog.rebuild_category_search(p_category uuid)
returns void
language sql
security definer
set search_path = ''
as $fn$
  insert into catalog.category_search (category_id, body_norm, updated_at)
  select
    c.id,
    core.normalize_ar(
      coalesce(c.name_ar,'') || ' ' || coalesce(c.name_en,'') || ' ' ||
      coalesce(c.description_ar,'') || ' ' || coalesce(c.description_en,'') || ' ' ||
      coalesce((select string_agg(a.alias, ' ')
                from catalog.category_aliases a where a.category_id = c.id), '')
    ),
    now()
  from catalog.categories c
  where c.id = p_category
  on conflict (category_id) do update
    set body_norm = excluded.body_norm,
        updated_at = now();
$fn$;

comment on function catalog.rebuild_product_search(uuid) is
  'Rebuild one product search document. SECURITY DEFINER so catalogue writers do not need direct INSERT on product_search. Called by triggers and after seed.';

comment on function catalog.rebuild_category_search(uuid) is
  'Rebuild one category search document. SECURITY DEFINER so catalogue writers do not need direct INSERT on category_search. Called by triggers and after seed.';

notify pgrst, 'reload schema';