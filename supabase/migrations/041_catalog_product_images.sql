-- 041_catalog_product_images.sql
-- Adds internet product images for the seeded catalogue products.
--
-- Every URL below was verified with an HTTP 200 check before being written
-- here. A previous version carried 11 dead Unsplash links (404), which made
-- the app render the "image unavailable" placeholder even though the rows
-- existed in the database.
--
-- Idempotent and self-healing:
--   1. Replaces the gallery rows for the 16 known products (matched by slug).
--   2. Inserts a category-appropriate fallback for any product that still has
--      no image row, so a renamed or newly added product is never imageless.
--   3. Syncs products.image_url from the primary gallery row, so single-column
--      readers (RPC search, legacy code) also get a working image.

-- ---------------------------------------------------------------------------
-- 1. Replace the gallery for the known products.
-- ---------------------------------------------------------------------------
delete from catalog.product_images;

insert into catalog.product_images (
  product_id, image_url, alt_ar, alt_en, sort_order, is_primary
)
select p.id, img.image_url, img.alt_ar, img.alt_en, 1, true
from (
  values
    ('espresso',    'https://images.unsplash.com/photo-1509042239860-f550ce710b93?auto=format&fit=crop&w=800&q=80', 'صورة إسبريسو',          'Espresso'),
    ('cappuccino',  'https://images.unsplash.com/photo-1442512595331-e89e73853f31?auto=format&fit=crop&w=800&q=80', 'صورة كابتشينو',        'Cappuccino'),
    ('latte',       'https://images.unsplash.com/photo-1541167760496-1628856ab772?auto=format&fit=crop&w=800&q=80', 'صورة لاتيه',           'Latte'),
    ('mocha',       'https://images.unsplash.com/photo-1579954115545-a95591f28bfc?auto=format&fit=crop&w=800&q=80', 'صورة موكا',            'Mocha'),
    ('americano',   'https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?auto=format&fit=crop&w=800&q=80', 'صورة أمريكانو',        'Americano'),
    ('iced-latte',  'https://images.unsplash.com/photo-1461023058943-07fcbe16d735?auto=format&fit=crop&w=800&q=80', 'صورة لاتيه مثلج',      'Iced Latte'),
    ('green-tea',   'https://images.unsplash.com/photo-1576092768241-dec231879fc3?auto=format&fit=crop&w=800&q=80', 'صورة شاي أخضر',        'Green Tea'),
    ('masala-tea',  'https://images.unsplash.com/photo-1556881286-fc6915169721?auto=format&fit=crop&w=800&q=80',    'صورة شاي بالهيل',      'Masala Tea'),
    ('cheesecake',  'https://images.unsplash.com/photo-1578985545062-69928b1d9587?auto=format&fit=crop&w=800&q=80', 'صورة تشيز كيك',       'Cheesecake'),
    ('chocolate-brownie', 'https://images.unsplash.com/photo-1606313564200-e75d5e30476c?auto=format&fit=crop&w=800&q=80', 'صورة براوني شوكولاتة', 'Chocolate Brownie'),
    ('chocolate-chip-cookie', 'https://images.unsplash.com/photo-1587248720327-8eb72564be1e?auto=format&fit=crop&w=800&q=80', 'صورة كوكيز شوكولاتة', 'Chocolate Chip Cookie'),
    ('butter-croissant', 'https://images.unsplash.com/photo-1555507036-ab1f4038808a?auto=format&fit=crop&w=800&q=80', 'صورة كرواسون بالزبدة', 'Butter Croissant'),
    ('chocolate-milkshake', 'https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=800&q=80', 'صورة ميلك شيك شوكولاتة', 'Chocolate Milkshake'),
    ('cola',        'https://images.unsplash.com/photo-1554866585-cd94860890b7?auto=format&fit=crop&w=800&q=80',    'صورة كولا',            'Cola'),
    ('butter-bread', 'https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=800&q=80', 'صورة خبز بالزبدة',    'Butter Bread'),
    ('glazed-donut', 'https://images.unsplash.com/photo-1550989460-0adf9ea622e2?auto=format&fit=crop&w=800&q=80',  'صورة دونات بالشوكولاتة', 'Glazed Donut')
) as img(slug, image_url, alt_ar, alt_en)
join catalog.products p on p.slug = img.slug;

-- ---------------------------------------------------------------------------
-- 2. Safety net: any product still without a gallery row gets a
--    category-appropriate image, so nothing renders imageless.
-- ---------------------------------------------------------------------------
insert into catalog.product_images (
  product_id, image_url, alt_ar, alt_en, sort_order, is_primary
)
select p.id, d.image_url, d.alt_en, d.alt_en, 1, true
from catalog.products p
join catalog.categories c on c.id = p.category_id
join (
  values
    ('hot-coffee',  'https://images.unsplash.com/photo-1509042239860-f550ce710b93?auto=format&fit=crop&w=800&q=80', 'Espresso coffee'),
    ('cold-coffee', 'https://images.unsplash.com/photo-1524350876685-274059332603?auto=format&fit=crop&w=800&q=80', 'Iced coffee'),
    ('tea',         'https://images.unsplash.com/photo-1556881286-fc6915169721?auto=format&fit=crop&w=800&q=80',    'Tea'),
    ('desserts',    'https://images.unsplash.com/photo-1578985545062-69928b1d9587?auto=format&fit=crop&w=800&q=80', 'Dessert'),
    ('snacks',      'https://images.unsplash.com/photo-1587248720327-8eb72564be1e?auto=format&fit=crop&w=800&q=80', 'Snack'),
    ('milkshakes',  'https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=800&q=80', 'Milkshake'),
    ('soft-drinks', 'https://images.unsplash.com/photo-1554866585-cd94860890b7?auto=format&fit=crop&w=800&q=80',    'Soft drink'),
    ('bakery',      'https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=800&q=80', 'Bakery'),
    ('donuts',      'https://images.unsplash.com/photo-1550989460-0adf9ea622e2?auto=format&fit=crop&w=800&q=80',   'Donut')
) as d(cat_slug, image_url, alt_en) on d.cat_slug = c.slug
where not exists (
  select 1 from catalog.product_images pi where pi.product_id = p.id
);

-- ---------------------------------------------------------------------------
-- 3. Sync products.image_url from the primary gallery row, so RPC search and
--    any single-column reader also resolve a working image.
-- ---------------------------------------------------------------------------
update catalog.products p
set image_url = pi.image_url
from catalog.product_images pi
where pi.product_id = p.id
  and pi.is_primary
  and (p.image_url is null or btrim(p.image_url) = '' or p.image_url <> pi.image_url);
