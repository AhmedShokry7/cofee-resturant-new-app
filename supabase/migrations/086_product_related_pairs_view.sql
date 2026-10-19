create or replace view public.products with (security_invoker = true) as
  select p.id, p.category_id, p.sku, p.slug, p.name_ar, p.name_en,
         p.description_ar, p.description_en, p.base_price,
         p.compare_at_price, p.image_url, p.is_active, p.is_featured,
         p.prep_minutes, p.is_calorie_tracked, p.allergens, p.sort_order,
         p.related_product_ids,
         c.slug  as category_slug,
         c.name_ar as category_name_ar,
         c.name_en as category_name_en
    from catalog.products p
    join catalog.categories c on c.id = p.category_id;
