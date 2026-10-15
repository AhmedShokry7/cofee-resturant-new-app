-- 041_catalog_product_images.sql
-- Adds real internet product images for the 16 seeded catalogue products.
--
-- Populates catalog.product_images (one primary row per product) and back-fills
-- catalog.products.image_url so the client has a usable image immediately.
-- Idempotent: deletes existing rows first so re-running is safe.

-- ---------------------------------------------------------------------------
-- 1. Product gallery rows (catalog.product_images).
-- ---------------------------------------------------------------------------
delete from catalog.product_images;

insert into catalog.product_images (
  product_id,
  image_url,
  alt_ar,
  alt_en,
  sort_order,
  is_primary
)
select
  p.id,
  img.image_url,
  img.alt_ar,
  img.alt_en,
  1,
  true
from (
  values
    ('espresso',    'https://images.unsplash.com/photo-1510557880183-7d7a3c955c22?auto=format&fit=crop&w=800&q=80',  'صورة إسبريسو',                'Espresso shot'),
    ('cappuccino',  'https://images.unsplash.com/photo-1534736821046-89351f80488e?auto=format&fit=crop&w=800&q=80',  'صورة كابتشينو',              'Cappuccino'),
    ('latte',       'https://images.unsplash.com/photo-1572442388716-1d36d662b2c9?auto=format&fit=crop&w=800&q=80',  'صورة لاتيه',                 'Latte'),
    ('mocha',       'https://images.unsplash.com/photo-1610879668279-b80619a6d5b3?auto=format&fit=crop&w=800&q=80',  'صورة موكا',                   'Mocha'),
    ('americano',   'https://images.unsplash.com/photo-1559056199-641a0a8b7519?auto=format&fit=crop&w=800&q=80',    'صورة أمريكانو',               'Americano'),
    ('iced-latte',  'https://images.unsplash.com/photo-1461023058943-07fcbe16d735?auto=format&fit=crop&w=800&q=80',  'صورة لاتيه مثلج',            'Iced Latte'),
    ('green-tea',   'https://images.unsplash.com/photo-1558962353-227922e15e61?auto=format&fit=crop&w=800&q=80',     'صورة شاي أخضر',               'Green Tea'),
    ('masala-tea',  'https://images.unsplash.com/photo-1603894632481-51a90639504b?auto=format&fit=crop&w=800&q=80',  'صورة شاي بالهيل',             'Masala Tea'),
    ('cheesecake',  'https://images.unsplash.com/photo-1533134254217-42cf33e9e41d?auto=format&fit=crop&w=800&q=80',  'صورة تشيز كيك',              'Cheesecake'),
    ('chocolate-brownie', 'https://images.unsplash.com/photo-1606313564200-e75d5e30476c?auto=format&fit=crop&w=800&q=80', 'صورة براوني شوكولاتة',   'Chocolate Brownie'),
    ('chocolate-chip-cookie', 'https://images.unsplash.com/photo-1499636136214-6f4fcf59f882?auto=format&fit=crop&w=800&q=80', 'صورة كوكيز شوكولاتة', 'Chocolate Chip Cookie'),
    ('butter-croissant', 'https://images.unsplash.com/photo-1555507036-ab1f4038808a?auto=format&fit=crop&w=800&q=80',  'صورة كرواسون بالزبدة',      'Butter Croissant'),
    ('chocolate-milkshake', 'https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=800&q=80', 'صورة ميلك شيك شوكولاتة', 'Chocolate Milkshake'),
    ('cola',        'https://images.unsplash.com/photo-1622068809117-7bb86a83be7e?auto=format&fit=crop&w=800&q=80',   'صورة كولا',                   'Cola'),
    ('butter-bread', 'https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=800&q=80',  'صورة خبز بالزبدة',           'Butter Bread'),
    ('glazed-donut', 'https://images.unsplash.com/photo-1602532007839-2a9028392c86?auto=format&fit=crop&w=800&q=80',  'صورة دونات بالشوكولاتة',    'Glazed Donut')
) as img(slug, image_url, alt_ar, alt_en)
join catalog.products p on p.slug = img.slug;

-- ---------------------------------------------------------------------------
-- 2. Back-fill products.image_url so single-column readers (legacy code and
--    offline mocks) still get an image even without joining product_images.
-- ---------------------------------------------------------------------------
update catalog.products p
set image_url = img.image_url
from (
  values
    ('espresso',    'https://images.unsplash.com/photo-1510557880183-7d7a3c955c22?auto=format&fit=crop&w=800&q=80'),
    ('cappuccino',  'https://images.unsplash.com/photo-1534736821046-89351f80488e?auto=format&fit=crop&w=800&q=80'),
    ('latte',       'https://images.unsplash.com/photo-1572442388716-1d36d662b2c9?auto=format&fit=crop&w=800&q=80'),
    ('mocha',       'https://images.unsplash.com/photo-1610879668279-b80619a6d5b3?auto=format&fit=crop&w=800&q=80'),
    ('americano',   'https://images.unsplash.com/photo-1559056199-641a0a8b7519?auto=format&fit=crop&w=800&q=80'),
    ('iced-latte',  'https://images.unsplash.com/photo-1461023058943-07fcbe16d735?auto=format&fit=crop&w=800&q=80'),
    ('green-tea',   'https://images.unsplash.com/photo-1558962353-227922e15e61?auto=format&fit=crop&w=800&q=80'),
    ('masala-tea',  'https://images.unsplash.com/photo-1603894632481-51a90639504b?auto=format&fit=crop&w=800&q=80'),
    ('cheesecake',  'https://images.unsplash.com/photo-1533134254217-42cf33e9e41d?auto=format&fit=crop&w=800&q=80'),
    ('chocolate-brownie', 'https://images.unsplash.com/photo-1606313564200-e75d5e30476c?auto=format&fit=crop&w=800&q=80'),
    ('chocolate-chip-cookie', 'https://images.unsplash.com/photo-1499636136214-6f4fcf59f882?auto=format&fit=crop&w=800&q=80'),
    ('butter-croissant', 'https://images.unsplash.com/photo-1555507036-ab1f4038808a?auto=format&fit=crop&w=800&q=80'),
    ('chocolate-milkshake', 'https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=800&q=80'),
    ('cola',        'https://images.unsplash.com/photo-1622068809117-7bb86a83be7e?auto=format&fit=crop&w=800&q=80'),
    ('butter-bread', 'https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=800&q=80'),
    ('glazed-donut', 'https://images.unsplash.com/photo-1602532007839-2a9028392c86?auto=format&fit=crop&w=800&q=80')
) as img(slug, image_url)
where p.slug = img.slug;


