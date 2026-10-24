begin;

insert into core.branches
  (id, brand_id, code, name_ar, name_en, address, address_ar, address_en,
   latitude, longitude, phone, is_active, opens_at, closes_at, settings)
values
  ('d0000000-0000-4000-8000-000000000001',
   '00000000-0000-4000-8000-000000000001',
   'DEMO-01', 'فرع النرجس', 'Al Narjis Branch',
   'Riyadh - Al Narjis', 'الرياض - حي النرجس', 'Riyadh - Al Narjis',
   24.8236, 46.6406, '+966500000001', true, '07:00', '23:00',
   '{"demo": true}'::jsonb)
on conflict (id) do update set
  brand_id = excluded.brand_id,
  code = excluded.code,
  name_ar = excluded.name_ar,
  name_en = excluded.name_en,
  address = excluded.address,
  address_ar = excluded.address_ar,
  address_en = excluded.address_en,
  latitude = excluded.latitude,
  longitude = excluded.longitude,
  phone = excluded.phone,
  is_active = excluded.is_active,
  opens_at = excluded.opens_at,
  closes_at = excluded.closes_at,
  settings = excluded.settings;

insert into catalog.categories
  (id, parent_id, name_ar, name_en, description_ar, description_en,
   image_url, icon_key, sort_order, is_active, slug)
values
  ('d0000000-0000-4000-8000-000000000101', null,
   'قهوة ساخنة', 'Hot Coffee', 'قهوة طازجة ومشروبات ساخنة', 'Fresh coffee and hot drinks',
   'https://picsum.photos/seed/hot-coffee/600/600', 'hot_coffee', 1, true, 'hot-coffee'),
  ('d0000000-0000-4000-8000-000000000102', null,
   'قهوة مثلجة', 'Iced Coffee', 'مشروبات القهوة الباردة والمثلجة', 'Cold and iced coffee drinks',
   'https://picsum.photos/seed/iced-coffee/600/600', 'cold_coffee', 2, true, 'iced-coffee'),
  ('d0000000-0000-4000-8000-000000000103', null,
   'مخبوزات وحلويات', 'Bakery & Desserts', 'مخبوزات طازجة وحلويات مختارة', 'Fresh bakery and selected desserts',
   'https://picsum.photos/seed/bakery-desserts/600/600', 'bakery', 3, true, 'bakery-desserts')
on conflict (id) do update set
  parent_id = excluded.parent_id,
  name_ar = excluded.name_ar,
  name_en = excluded.name_en,
  description_ar = excluded.description_ar,
  description_en = excluded.description_en,
  image_url = excluded.image_url,
  icon_key = excluded.icon_key,
  sort_order = excluded.sort_order,
  is_active = excluded.is_active,
  slug = excluded.slug;

insert into catalog.products
  (id, category_id, sku, slug, name_ar, name_en, description_ar, description_en,
   base_price, compare_at_price, image_url, is_active, is_featured,
   prep_minutes, is_calorie_tracked, allergens, sort_order, calories,
   discount_percentage, discount_starts_at, discount_ends_at)
values
  ('d0000000-0000-4000-8000-000000000201',
   'd0000000-0000-4000-8000-000000000101', 'DEMO-ESP-001', 'espresso',
   'إسبريسو', 'Espresso', 'جرعة إسبريسو مركزة من حبوب مختارة', 'A concentrated shot from selected beans',
   12.00, null, 'https://picsum.photos/seed/espresso/800/800', true, false,
   2, true, array[]::text[], 1, 5, null, null, null),
  ('d0000000-0000-4000-8000-000000000202',
   'd0000000-0000-4000-8000-000000000101', 'DEMO-AME-002', 'americano',
   'أمريكانو', 'Americano', 'إسبريسو مع ماء ساخن', 'Espresso with hot water',
   14.00, null, 'https://picsum.photos/seed/americano/800/800', true, true,
   3, true, array[]::text[], 2, 10, null, null, null),
  ('d0000000-0000-4000-8000-000000000203',
   'd0000000-0000-4000-8000-000000000101', 'DEMO-LAT-003', 'latte',
   'لاتيه', 'Latte', 'إسبريسو مع حليب مبخر', 'Espresso with steamed milk',
   18.00, null, 'https://picsum.photos/seed/latte/800/800', true, true,
   4, true, array['milk'], 3, 190, null, null, null),
  ('d0000000-0000-4000-8000-000000000204',
   'd0000000-0000-4000-8000-000000000101', 'DEMO-CAP-004', 'cappuccino',
   'كابتشينو', 'Cappuccino', 'إسبريسو مع رغوة حليب كثيفة', 'Espresso with thick milk foam',
   18.00, null, 'https://picsum.photos/seed/cappuccino/800/800', true, false,
   4, true, array['milk'], 4, 150, null, null, null),
  ('d0000000-0000-4000-8000-000000000205',
   'd0000000-0000-4000-8000-000000000102', 'DEMO-ICL-005', 'iced-latte',
   'آيس لاتيه', 'Iced Latte', 'إسبريسو مع حليب بارد وثلج', 'Espresso with cold milk and ice',
   20.00, null, 'https://picsum.photos/seed/iced-latte/800/800', true, true,
   4, true, array['milk'], 5, 130, null, null, null),
  ('d0000000-0000-4000-8000-000000000206',
   'd0000000-0000-4000-8000-000000000102', 'DEMO-ISL-006', 'iced-spanish-latte',
   'آيس سبانيش لاتيه', 'Iced Spanish Latte', 'لاتيه مثلج بحليب مكثف', 'Iced latte with condensed milk',
   22.00, 24.00, 'https://picsum.photos/seed/iced-spanish-latte/800/800', true, true,
   4, true, array['milk'], 6, 210, 10.0, now() - interval '1 day', now() + interval '30 days'),
  ('d0000000-0000-4000-8000-000000000207',
   'd0000000-0000-4000-8000-000000000102', 'DEMO-MOF-007', 'mocha-frappe',
   'موكا فرابيه', 'Mocha Frappe', 'قهوة مثلجة بالشوكولاتة والكريمة', 'Iced coffee with chocolate and cream',
   24.00, null, 'https://picsum.photos/seed/mocha-frappe/800/800', true, false,
   5, true, array['milk'], 7, 320, null, null, null),
  ('d0000000-0000-4000-8000-000000000208',
   'd0000000-0000-4000-8000-000000000103', 'DEMO-CRO-008', 'butter-croissant',
   'كرواسون بالزبدة', 'Butter Croissant', 'كرواسون طازج بالزبدة', 'Fresh buttery croissant',
   12.00, null, 'https://picsum.photos/seed/butter-croissant/800/800', true, false,
   1, true, array['gluten','milk'], 8, 280, null, null, null),
  ('d0000000-0000-4000-8000-000000000209',
   'd0000000-0000-4000-8000-000000000103', 'DEMO-CHE-009', 'cheesecake',
   'تشيز كيك', 'Cheesecake', 'قطعة تشيز كيك كريمية', 'Creamy cheesecake slice',
   22.00, null, 'https://picsum.photos/seed/cheesecake/800/800', true, false,
   1, true, array['gluten','milk','egg'], 9, 410, null, null, null)
on conflict (id) do update set
  category_id = excluded.category_id,
  sku = excluded.sku,
  slug = excluded.slug,
  name_ar = excluded.name_ar,
  name_en = excluded.name_en,
  description_ar = excluded.description_ar,
  description_en = excluded.description_en,
  base_price = excluded.base_price,
  compare_at_price = excluded.compare_at_price,
  image_url = excluded.image_url,
  is_active = excluded.is_active,
  is_featured = excluded.is_featured,
  prep_minutes = excluded.prep_minutes,
  is_calorie_tracked = excluded.is_calorie_tracked,
  allergens = excluded.allergens,
  sort_order = excluded.sort_order,
  calories = excluded.calories,
  discount_percentage = excluded.discount_percentage,
  discount_starts_at = excluded.discount_starts_at,
  discount_ends_at = excluded.discount_ends_at;

insert into catalog.product_images
  (id, product_id, image_url, alt_ar, alt_en, sort_order, is_primary, fit, alignment)
values
  ('d0000000-0000-4000-8000-000000000301', 'd0000000-0000-4000-8000-000000000201',
   'https://picsum.photos/seed/espresso/800/800', 'إسبريسو', 'Espresso', 0, true, 'cover', 'center'),
  ('d0000000-0000-4000-8000-000000000302', 'd0000000-0000-4000-8000-000000000202',
   'https://picsum.photos/seed/americano/800/800', 'أمريكانو', 'Americano', 0, true, 'cover', 'center'),
  ('d0000000-0000-4000-8000-000000000303', 'd0000000-0000-4000-8000-000000000203',
   'https://picsum.photos/seed/latte/800/800', 'لاتيه', 'Latte', 0, true, 'cover', 'center'),
  ('d0000000-0000-4000-8000-000000000313', 'd0000000-0000-4000-8000-000000000203',
   'https://picsum.photos/seed/latte-art/800/800', 'لاتيه مع رسمة', 'Latte art', 1, false, 'contain', 'topCenter'),
  ('d0000000-0000-4000-8000-000000000304', 'd0000000-0000-4000-8000-000000000204',
   'https://picsum.photos/seed/cappuccino/800/800', 'كابتشينو', 'Cappuccino', 0, true, 'cover', 'center'),
  ('d0000000-0000-4000-8000-000000000305', 'd0000000-0000-4000-8000-000000000205',
   'https://picsum.photos/seed/iced-latte/800/800', 'آيس لاتيه', 'Iced Latte', 0, true, 'cover', 'center'),
  ('d0000000-0000-4000-8000-000000000306', 'd0000000-0000-4000-8000-000000000206',
   'https://picsum.photos/seed/iced-spanish-latte/800/800', 'آيس سبانيش لاتيه', 'Iced Spanish Latte', 0, true, 'cover', 'center'),
  ('d0000000-0000-4000-8000-000000000316', 'd0000000-0000-4000-8000-000000000206',
   'https://picsum.photos/seed/iced-spanish-latte-close/800/800', 'آيس سبانيش لاتيه عن قرب', 'Iced Spanish Latte close-up', 1, false, 'contain', 'center'),
  ('d0000000-0000-4000-8000-000000000307', 'd0000000-0000-4000-8000-000000000207',
   'https://picsum.photos/seed/mocha-frappe/800/800', 'موكا فرابيه', 'Mocha Frappe', 0, true, 'cover', 'center'),
  ('d0000000-0000-4000-8000-000000000308', 'd0000000-0000-4000-8000-000000000208',
   'https://picsum.photos/seed/butter-croissant/800/800', 'كرواسون بالزبدة', 'Butter Croissant', 0, true, 'cover', 'center'),
  ('d0000000-0000-4000-8000-000000000309', 'd0000000-0000-4000-8000-000000000209',
   'https://picsum.photos/seed/cheesecake/800/800', 'تشيز كيك', 'Cheesecake', 0, true, 'cover', 'center')
on conflict (id) do update set
  product_id = excluded.product_id,
  image_url = excluded.image_url,
  alt_ar = excluded.alt_ar,
  alt_en = excluded.alt_en,
  sort_order = excluded.sort_order,
  is_primary = excluded.is_primary,
  fit = excluded.fit,
  alignment = excluded.alignment;

insert into catalog.option_groups
  (id, code, name_ar, name_en, selection_type, min_select, max_select,
   is_required, sort_order, is_active)
values
  ('d0000000-0000-4000-8000-000000000401', 'size', 'الحجم', 'Size',
   'single', 0, 1, false, 1, true),
  ('d0000000-0000-4000-8000-000000000402', 'milk', 'الحليب', 'Milk',
   'single', 0, 1, false, 2, true)
on conflict (id) do update set
  code = excluded.code,
  name_ar = excluded.name_ar,
  name_en = excluded.name_en,
  selection_type = excluded.selection_type,
  min_select = excluded.min_select,
  max_select = excluded.max_select,
  is_required = excluded.is_required,
  sort_order = excluded.sort_order,
  is_active = excluded.is_active;

insert into catalog.option_values
  (id, group_id, code, name_ar, name_en, price_delta, short_label,
   sort_order, is_active, is_default)
values
  ('d0000000-0000-4000-8000-000000000411', 'd0000000-0000-4000-8000-000000000401',
   'small', 'صغير', 'Small', 0, 'S', 1, true, true),
  ('d0000000-0000-4000-8000-000000000412', 'd0000000-0000-4000-8000-000000000401',
   'medium', 'وسط', 'Medium', 3, 'M', 2, true, false),
  ('d0000000-0000-4000-8000-000000000413', 'd0000000-0000-4000-8000-000000000401',
   'large', 'كبير', 'Large', 5, 'L', 3, true, false),
  ('d0000000-0000-4000-8000-000000000421', 'd0000000-0000-4000-8000-000000000402',
   'regular', 'حليب عادي', 'Regular milk', 0, 'Regular', 1, true, true),
  ('d0000000-0000-4000-8000-000000000422', 'd0000000-0000-4000-8000-000000000402',
   'oat', 'حليب الشوفان', 'Oat milk', 4, 'Oat', 2, true, false),
  ('d0000000-0000-4000-8000-000000000423', 'd0000000-0000-4000-8000-000000000402',
   'almond', 'حليب اللوز', 'Almond milk', 4, 'Almond', 3, true, false)
on conflict (id) do update set
  group_id = excluded.group_id,
  code = excluded.code,
  name_ar = excluded.name_ar,
  name_en = excluded.name_en,
  price_delta = excluded.price_delta,
  short_label = excluded.short_label,
  sort_order = excluded.sort_order,
  is_active = excluded.is_active,
  is_default = excluded.is_default;

insert into catalog.product_option_groups
  (product_id, group_id, sort_order, is_required)
values
  ('d0000000-0000-4000-8000-000000000201', 'd0000000-0000-4000-8000-000000000401', 1, false),
  ('d0000000-0000-4000-8000-000000000202', 'd0000000-0000-4000-8000-000000000401', 1, false),
  ('d0000000-0000-4000-8000-000000000203', 'd0000000-0000-4000-8000-000000000401', 1, false),
  ('d0000000-0000-4000-8000-000000000204', 'd0000000-0000-4000-8000-000000000401', 1, false),
  ('d0000000-0000-4000-8000-000000000205', 'd0000000-0000-4000-8000-000000000401', 1, false),
  ('d0000000-0000-4000-8000-000000000206', 'd0000000-0000-4000-8000-000000000401', 1, false),
  ('d0000000-0000-4000-8000-000000000207', 'd0000000-0000-4000-8000-000000000401', 1, false),
  ('d0000000-0000-4000-8000-000000000203', 'd0000000-0000-4000-8000-000000000402', 2, false),
  ('d0000000-0000-4000-8000-000000000204', 'd0000000-0000-4000-8000-000000000402', 2, false),
  ('d0000000-0000-4000-8000-000000000205', 'd0000000-0000-4000-8000-000000000402', 2, false),
  ('d0000000-0000-4000-8000-000000000206', 'd0000000-0000-4000-8000-000000000402', 2, false),
  ('d0000000-0000-4000-8000-000000000207', 'd0000000-0000-4000-8000-000000000402', 2, false)
on conflict (product_id, group_id) do update set
  sort_order = excluded.sort_order,
  is_required = excluded.is_required;

insert into catalog.branch_product_pricing
  (branch_id, product_id, price_override, is_available, is_featured,
   unavailable_reason, discount_percentage, discount_starts_at,
   discount_ends_at, use_general_discount)
values
  ('d0000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8000-000000000201', null, true, false, null, null, null, null, true),
  ('d0000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8000-000000000202', null, true, true, null, null, null, null, true),
  ('d0000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8000-000000000203', null, true, true, null, null, null, null, true),
  ('d0000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8000-000000000204', null, true, false, null, null, null, null, true),
  ('d0000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8000-000000000205', null, true, true, null, null, null, null, true),
  ('d0000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8000-000000000206', null, true, true, null, null, null, null, true),
  ('d0000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8000-000000000207', null, true, false, null, 15.0, now() - interval '1 day', now() + interval '30 days', false),
  ('d0000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8000-000000000208', null, true, false, null, null, null, null, true),
  ('d0000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8000-000000000209', null, true, false, null, null, null, null, true)
on conflict (branch_id, product_id) do update set
  price_override = excluded.price_override,
  is_available = excluded.is_available,
  is_featured = excluded.is_featured,
  unavailable_reason = excluded.unavailable_reason,
  discount_percentage = excluded.discount_percentage,
  discount_starts_at = excluded.discount_starts_at,
  discount_ends_at = excluded.discount_ends_at,
  use_general_discount = excluded.use_general_discount;

insert into inventory.branch_stock
  (branch_id, product_id, variant_key, quantity_on_hand, quantity_reserved,
   reorder_level, allow_negative)
values
  ('d0000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8000-000000000201', '00000000-0000-0000-0000-000000000000'::uuid, 80, 0, 10, false),
  ('d0000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8000-000000000202', '00000000-0000-0000-0000-000000000000'::uuid, 80, 0, 10, false),
  ('d0000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8000-000000000203', '00000000-0000-0000-0000-000000000000'::uuid, 80, 0, 10, false),
  ('d0000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8000-000000000204', '00000000-0000-0000-0000-000000000000'::uuid, 80, 0, 10, false),
  ('d0000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8000-000000000205', '00000000-0000-0000-0000-000000000000'::uuid, 80, 0, 10, false),
  ('d0000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8000-000000000206', '00000000-0000-0000-0000-000000000000'::uuid, 80, 0, 10, false),
  ('d0000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8000-000000000207', '00000000-0000-0000-0000-000000000000'::uuid, 80, 0, 10, false),
  ('d0000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8000-000000000208', '00000000-0000-0000-0000-000000000000'::uuid, 80, 0, 10, false),
  ('d0000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8000-000000000209', '00000000-0000-0000-0000-000000000000'::uuid, 80, 0, 10, false)
on conflict (branch_id, product_id, variant_key) do update set
  quantity_on_hand = excluded.quantity_on_hand,
  quantity_reserved = excluded.quantity_reserved,
  reorder_level = excluded.reorder_level,
  allow_negative = excluded.allow_negative;

insert into catalog.bundles
  (id, name_ar, name_en, description_ar, description_en, image_url,
   bundle_price, sort_order, is_active, starts_at, ends_at)
values
  ('d0000000-0000-4000-8000-000000000501', 'كومبو الصباح', 'Morning Combo',
   'لاتيه مع كرواسون بالزبدة', 'Latte with a butter croissant',
   'https://picsum.photos/seed/morning-combo/900/600', 30.00, 1, true, null, null),
  ('d0000000-0000-4000-8000-000000000502', 'ثنائي القهوة المثلجة', 'Iced Coffee Duo',
   'آيس لاتيه مع آيس سبانيش لاتيه', 'Iced Latte with an Iced Spanish Latte',
   'https://picsum.photos/seed/iced-coffee-duo/900/600', 42.00, 2, true, null, null)
on conflict (id) do update set
  name_ar = excluded.name_ar,
  name_en = excluded.name_en,
  description_ar = excluded.description_ar,
  description_en = excluded.description_en,
  image_url = excluded.image_url,
  bundle_price = excluded.bundle_price,
  sort_order = excluded.sort_order,
  is_active = excluded.is_active,
  starts_at = excluded.starts_at,
  ends_at = excluded.ends_at;

insert into catalog.bundle_items
  (id, bundle_id, product_id, quantity, allow_options, sort_order)
values
  ('d0000000-0000-4000-8000-000000000511', 'd0000000-0000-4000-8000-000000000501', 'd0000000-0000-4000-8000-000000000203', 1, true, 1),
  ('d0000000-0000-4000-8000-000000000512', 'd0000000-0000-4000-8000-000000000501', 'd0000000-0000-4000-8000-000000000208', 1, false, 2),
  ('d0000000-0000-4000-8000-000000000513', 'd0000000-0000-4000-8000-000000000502', 'd0000000-0000-4000-8000-000000000205', 1, true, 1),
  ('d0000000-0000-4000-8000-000000000514', 'd0000000-0000-4000-8000-000000000502', 'd0000000-0000-4000-8000-000000000206', 1, true, 2)
on conflict (id) do update set
  bundle_id = excluded.bundle_id,
  product_id = excluded.product_id,
  quantity = excluded.quantity,
  allow_options = excluded.allow_options,
  sort_order = excluded.sort_order;

insert into marketing.banners
  (id, title_ar, title_en, subtitle_ar, subtitle_en, description_ar,
   description_en, image_url, cta_label_ar, cta_label_en, target_type,
   target_id, target_url, sort_order, starts_at, ends_at, is_published)
values
  ('d0000000-0000-4000-8000-000000000601', 'قهوة الصباح', 'Morning Coffee',
   'ابدأ يومك بكوب منعش', 'Start your day with a fresh cup',
   'اختيارات ساخنة من حبوبنا المختارة', 'Hot picks from our selected beans',
   'https://picsum.photos/seed/morning-coffee-banner/1200/600',
   'اطلب الآن', 'Order now', 'category',
   'd0000000-0000-4000-8000-000000000101', null, 1,
   now() - interval '1 day', now() + interval '1 year', true),
  ('d0000000-0000-4000-8000-000000000602', 'قهوة مثلجة', 'Iced Coffee',
   'انتعش بأفضل المشروبات الباردة', 'Cool down with our best cold drinks',
   'آيس لاتيه وسبانيش لاتيه بانتظارك', 'Iced Latte and Spanish Latte await',
   'https://picsum.photos/seed/iced-coffee-banner/1200/600',
   'اكتشف المزيد', 'Discover more', 'category',
   'd0000000-0000-4000-8000-000000000102', null, 2,
   now() - interval '1 day', now() + interval '1 year', true),
  ('d0000000-0000-4000-8000-000000000603', 'كومبو الصباح', 'Morning Combo',
   'لاتيه وكرواسون بسعر مميز', 'Latte and croissant at a special price',
   'وفّر عند طلب الكومبو', 'Save when you order the combo',
   'https://picsum.photos/seed/breakfast-combo-banner/1200/600',
   'اطلب الكومبو', 'Order the combo', 'bundle',
   'd0000000-0000-4000-8000-000000000501', null, 3,
   now() - interval '1 day', now() + interval '1 year', true)
on conflict (id) do update set
  title_ar = excluded.title_ar,
  title_en = excluded.title_en,
  subtitle_ar = excluded.subtitle_ar,
  subtitle_en = excluded.subtitle_en,
  description_ar = excluded.description_ar,
  description_en = excluded.description_en,
  image_url = excluded.image_url,
  cta_label_ar = excluded.cta_label_ar,
  cta_label_en = excluded.cta_label_en,
  target_type = excluded.target_type,
  target_id = excluded.target_id,
  target_url = excluded.target_url,
  sort_order = excluded.sort_order,
  starts_at = excluded.starts_at,
  ends_at = excluded.ends_at,
  is_published = excluded.is_published;

insert into marketing.coupons
  (id, code, title_ar, title_en, description_ar, description_en,
   discount_type, discount_value, max_discount, min_order_amount,
   applies_to, usage_limit, per_user_limit, starts_at, ends_at, is_active)
values
  ('d0000000-0000-4000-8000-000000000701', 'DEMO10', 'خصم ترحيبي', 'Welcome Discount',
   'خصم 10% على أول طلب', '10% off your first order',
   'percentage', 10, 25, 30, 'all', 1000, 5,
   now() - interval '1 day', now() + interval '1 year', true)
on conflict (code) do update set
  title_ar = excluded.title_ar,
  title_en = excluded.title_en,
  description_ar = excluded.description_ar,
  description_en = excluded.description_en,
  discount_type = excluded.discount_type,
  discount_value = excluded.discount_value,
  max_discount = excluded.max_discount,
  min_order_amount = excluded.min_order_amount,
  applies_to = excluded.applies_to,
  usage_limit = excluded.usage_limit,
  per_user_limit = excluded.per_user_limit,
  starts_at = excluded.starts_at,
  ends_at = excluded.ends_at,
  is_active = excluded.is_active;

notify pgrst, 'reload schema';

commit;
