-- 042_marketing_banner_targets.sql
--
-- Gives the home page one working banner per target type: the seed only
-- shipped `category` banners, so product / bundle / url / none targets had
-- no real rows to exercise the navigation paths.
--
-- Every image_url below was verified with an HTTP 200 check before being
-- written here. Target ids resolve by stable slug / name, never by display
-- text, and each statement inserts only when its title_en is absent, so the
-- migration is safe to re-run.

-- ---------------------------------------------------------------------------
-- 1. Product banner -> Latte.
-- ---------------------------------------------------------------------------
insert into marketing.banners
  (title_ar, title_en, subtitle_ar, subtitle_en, description_ar,
   description_en, image_url, cta_label_ar, cta_label_en,
   target_type, target_id, target_url, sort_order, is_published)
select
  'جرّب اللاتيه', 'Try the Latte',
  'كريمي وناعم', 'Creamy and smooth',
  'اللاتيه الأكثر طلباً لدينا', 'Our most ordered latte',
  'https://images.unsplash.com/photo-1541167760496-1628856ab772?auto=format&fit=crop&w=800&q=80',
  'اطلب الآن', 'Order Now',
  'product', p.id, null, 6, true
from catalog.products p
where p.slug = 'latte'
  and not exists (
    select 1 from marketing.banners b where b.title_en = 'Try the Latte'
  )
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- 2. Bundle banner -> Morning Duo.
-- ---------------------------------------------------------------------------
insert into marketing.banners
  (title_ar, title_en, subtitle_ar, subtitle_en, description_ar,
   description_en, image_url, cta_label_ar, cta_label_en,
   target_type, target_id, target_url, sort_order, is_published)
select
  'ثنائية الصباح', 'Morning Duo Deal',
  'إسبريسو مع كرواسون', 'Espresso with a croissant',
  'وفّر مع باقة الصباح', 'Save with the morning bundle',
  'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?auto=format&fit=crop&w=800&q=80',
  'اكتشف الباقة', 'View Bundle',
  'bundle', bu.id, null, 7, true
from catalog.bundles bu
where bu.name_en = 'Morning Duo'
  and not exists (
    select 1 from marketing.banners b where b.title_en = 'Morning Duo Deal'
  )
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- 3. External-link banner.
-- ---------------------------------------------------------------------------
insert into marketing.banners
  (title_ar, title_en, subtitle_ar, subtitle_en, description_ar,
   description_en, image_url, cta_label_ar, cta_label_en,
   target_type, target_id, target_url, sort_order, is_published)
select
  'تابعنا', 'Follow Us',
  'جديدنا أول بأول', 'Fresh news first',
  'تابع آخر العروض والأخبار', 'Follow the latest offers and news',
  'https://images.unsplash.com/photo-1509042239860-f550ce710b93?auto=format&fit=crop&w=800&q=80',
  'زيارة الرابط', 'Visit Link',
  'url', null, 'https://flutter.dev', 8, true
where not exists (
  select 1 from marketing.banners b where b.title_en = 'Follow Us'
)
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- 4. Announcement banner (no target).
-- ---------------------------------------------------------------------------
insert into marketing.banners
  (title_ar, title_en, subtitle_ar, subtitle_en, description_ar,
   description_en, image_url, cta_label_ar, cta_label_en,
   target_type, target_id, target_url, sort_order, is_published)
select
  'قهوة طازجة يومياً', 'Fresh Daily',
  'تحميص يومي', 'Roasted daily',
  'بن طازج كل صباح', 'Fresh beans every morning',
  'https://images.unsplash.com/photo-1442512595331-e89e73853f31?auto=format&fit=crop&w=800&q=80',
  'اكتشف المزيد', 'Learn More',
  'none', null, null, 9, true
where not exists (
  select 1 from marketing.banners b where b.title_en = 'Fresh Daily'
)
on conflict do nothing;
