-- Store product nutrition as calories (kcal) per serving. Nullable values keep
-- products without verified nutrition data from displaying an invented value.
alter table catalog.products
  add column if not exists calories integer;

alter table catalog.products
  drop constraint if exists products_calories_nonnegative;

alter table catalog.products
  add constraint products_calories_nonnegative
  check (calories is null or calories >= 0);

-- Keep the public PostgREST bridge in sync. Append the new field so existing
-- view column order remains stable for dependent clients.
create or replace view public.products with (security_invoker = true) as
  select p.id, p.category_id, p.sku, p.slug, p.name_ar, p.name_en,
         p.description_ar, p.description_en, p.base_price,
         p.compare_at_price, p.image_url, p.is_active, p.is_featured,
         p.prep_minutes, p.is_calorie_tracked, p.allergens, p.sort_order,
         c.slug as category_slug,
         c.name_ar as category_name_ar,
         c.name_en as category_name_en,
         p.related_product_ids,
         p.calories
    from catalog.products p
    join catalog.categories c on c.id = p.category_id;
