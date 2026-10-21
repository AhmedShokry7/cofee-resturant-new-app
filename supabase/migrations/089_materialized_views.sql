-- 089_materialized_views.sql
--
-- عروض مادية للبيانات التي تُقرأ بكثافة وتتغير rarement (المنتجات الشائعة،
-- الفئات، البانرات، الكوبونات النشطة). تُحدث دورياً أو عند تعديل البيانات
-- لتقليل حمل الاستعلامات المباشرة على جداول الكتالوج الكبيرة.

-- --- المخزون الشائع للبيوت ---
create materialized view if not exists catalog.popular_products_cache as
select
  p.id,
  p.category_id,
  p.sku,
  p.slug,
  p.name_ar,
  p.name_en,
  p.base_price,
  p.compare_at_price,
  p.image_url,
  p.prep_minutes,
  c.slug as category_slug,
  c.name_ar as category_name_ar,
  c.name_en as category_name_en
from catalog.products p
join catalog.categories c on c.id = p.category_id
where p.is_active = true
  and p.archived_at is null
  and c.is_active = true
order by p.sort_order
with no data;

create unique index if not exists ix_popular_products_cache_id
  on catalog.popular_products_cache (id);

-- --- الفئات النشطة للأقسام السريعة ---
create materialized view if not exists catalog.active_categories_cache as
select
  id,
  parent_id,
  name_ar,
  name_en,
  description_ar,
  description_en,
  image_url,
  icon_key,
  sort_order
from catalog.categories
where is_active = true
order by sort_order
with no data;

create unique index if not exists ix_active_categories_cache_id
  on catalog.active_categories_cache (id);

-- --- البانرات المنشورة ---
create materialized view if not exists marketing.published_banners_cache as
select
  id,
  title_ar,
  title_en,
  subtitle_ar,
  subtitle_en,
  description_ar,
  description_en,
  image_url,
  cta_label_ar,
  cta_label_en,
  target_type,
  target_id,
  target_url,
  sort_order
from marketing.banners
where is_published = true
  and (starts_at is null or starts_at <= now())
  and (ends_at is null or ends_at > now())
order by sort_order
with no data;

create unique index if not exists ix_published_banners_cache_id
  on marketing.published_banners_cache (id);

-- --- الكوبونات النشطة ---
create materialized view if not exists marketing.active_coupons_cache as
select
  id,
  code,
  title_ar,
  title_en,
  description_ar,
  description_en,
  discount_type,
  discount_value,
  max_discount,
  min_order_amount,
  applies_to,
  usage_limit,
  per_user_limit,
  starts_at,
  ends_at
from marketing.coupons
where is_active = true
  and (starts_at is null or starts_at <= now())
  and (ends_at is null or ends_at > now())
  and (usage_limit is null or usage_limit > 0)
order by code
with no data;

create unique index if not exists ix_active_coupons_cache_code
  on marketing.active_coupons_cache (code);

-- --- دالة تحديث جميع العروض المادية ---
create or replace function public.refresh_materialized_caches()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  refresh materialized view concurrently catalog.popular_products_cache;
  refresh materialized view concurrently catalog.active_categories_cache;
  refresh materialized view concurrently marketing.published_banners_cache;
  refresh materialized view concurrently marketing.active_coupons_cache;
end;
$$;

revoke all on function public.refresh_materialized_caches() from public, anon;
grant execute on function public.refresh_materialized_caches() to authenticated, service_role;

notify pgrst, 'reload schema';
