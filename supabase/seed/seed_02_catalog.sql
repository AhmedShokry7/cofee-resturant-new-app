-- seed_02_catalog.sql
--
-- The catalogue currently hard-coded in Dart, moved into data.
--   menu_list.dart       (16 products)      -> catalog.products
--   categories_list.dart (10 categories)    -> catalog.categories
--   product_variants.dart (sizes/sugar/extras) -> option groups + values
--   bundles_list.dart   (4 bundles)        -> catalog.bundles + bundle_items
--   banners_list.dart   (5 banners)        -> marketing.banners
--   coupons_list.dart   (4 coupons)        -> marketing.coupons
--   loyalty_rules.dart  (6 reward costs)   -> loyalty.loyalty_rewards
--   product_knowledge.dart (16 ingredient sets) -> ai.product_knowledge
--   productSynonyms (~50 Arabic aliases)     -> catalog.product_aliases
--
-- Arabic names are added because D4 requires bilingual data and the Dart
-- models had none.
--
-- Idempotent: every insert keys on a natural unique value.

-- ---------------------------------------------------------------------------
-- Categories (10, matching getCategoriesList())
-- ---------------------------------------------------------------------------
insert into catalog.categories (slug, name_ar, name_en, description_ar, description_en, sort_order) values
  ('hot-coffee',    'قهوة ساخنة',   'Hot Coffee',   'قهوة ساخنة بمشروبات وأحماض',        'Hot coffee, espresso based',        1),
  ('cold-coffee',   'قهوة باردة',   'Cold Coffee',  'مشروبات باردة ومثلجة',              'Iced and cold brew drinks',         2),
  ('tea',           'شاي',          'Tea',          'شاي بأنواعه',                        'All teas',                          3),
  ('desserts',      'حلويات',       'Desserts',     'حلويات طازجة',                      'Fresh desserts',                   4),
  ('snacks',        'وجبات خفيفة',  'Snacks',       'وجبات خفيفة سريعة',                 'Quick bites',                      5),
  ('milkshakes',  'ميلك شيك',   'Milkshakes',   'عصائر بالحليب',                     'Milk shakes',                      6),
  ('soft-drinks',   'مشروبات غازية', 'Soft Drinks',  'مشروبات غازية',                      'Soft drinks',                      7),
  ('bakery',        'مخبوزات',      'Bakery',       'مخبوزات طازجة',                     'Fresh bakery',                     8),
  ('donuts',        'دوناتس',       'Donuts',       'دوناتس',                             'Donuts',                           9),
  ('bundles',       'باقات',        'Bundles',      'باقات وعروض مجمعة',                 'Bundles and combos',               10)
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- Option groups (replaces DrinkSize + SugarLevel + ProductExtra enums)
-- ---------------------------------------------------------------------------
insert into catalog.option_groups
  (code, name_ar, name_en, selection_type, min_select, max_select, is_required, sort_order)
values
  ('size',    'الحجم',  'Size',         'single',   0, 1, false, 1),
  ('sugar',   'السكر',  'Sugar Level',  'single',   0, 1, false, 2),
  ('extras',  'الإضافات','Extras',      'multiple', 0, 6, false, 3)
on conflict (code) do nothing;

insert into catalog.option_values
  (group_id, code, name_ar, name_en, short_label, price_delta, sort_order, is_default)
select g.id, v.code, v.name_ar, v.name_en, v.short_label, v.price_delta, v.sort_order, v.is_default
  from (values
    ('size',    'small',  'صغير',  'Small',      'S',  0.00, 1, true),
    ('size',    'medium', 'وسط',   'Medium',     'M',  5.00, 2, false),
    ('size',    'large',  'كبير',  'Large',      'L', 10.00, 3, false),
    ('sugar',   'none',   'بدون سكر', 'No Sugar',  null, 0.00, 1, true),
    ('sugar',   'less',   'سكر قليل', 'Less Sugar', null, 0.00, 2, false),
    ('sugar',   'normal', 'سكر عادي', 'Regular',  null, 0.00, 3, false),
    ('sugar',   'extra',  'سكر كثير', 'Extra Sugar', null, 0.00, 4, false),
    ('extras',  'shot',   'جرعة إسبريسو إضافية', 'Extra Espresso Shot', null,  8.00, 1, false),
    ('extras',  'cream',  'كريمة مخفوقة',        'Whipped Cream',        null,  5.00, 2, false),
    ('extras',  'vanilla','شراب الفانيلا',       'Vanilla Syrup',        null,  5.00, 3, false),
    ('extras',  'caramel','شراب الكراميل',       'Caramel Syrup',        null,  5.00, 4, false),
    ('extras',  'mint',   'نعناع طازج',           'Fresh Mint',           null,  3.00, 5, false),
    ('extras',  'honey',  'عسل',                  'Honey',                null,  5.00, 6, false),
    ('extras',  'scoop',  'كرة آيس كريم إضافية', 'Extra Ice Cream Scoop', null, 10.00, 7, false)
  ) as v(group_code, code, name_ar, name_en, short_label, price_delta, sort_order, is_default)
  join catalog.option_groups g on g.code = v.group_code
on conflict (group_id, code) do nothing;

-- ---------------------------------------------------------------------------
-- Products (16, matching getMenuList())
-- ---------------------------------------------------------------------------
insert into catalog.products
  (category_id, sku, slug, name_ar, name_en, description_ar, description_en,
   base_price, compare_at_price, sort_order, is_featured)
select c.id, p.sku, p.slug, p.name_ar, p.name_en, p.description_ar, p.description_en,
       p.base_price, p.compare_at_price, p.sort_order, p.is_featured
  from (values
    ('hot-coffee',  'CF-001', 'espresso',             'إسبريسو',                'Espresso',               'جرعة إسبريسو مركزة',                  'A single concentrated espresso shot',            25.00, null::numeric,  1, true),
    ('hot-coffee',  'CF-002', 'cappuccino',           'كابتشينو',               'Cappuccino',             'إسبريسو مع حليب رغوي',                'Espresso with steamed milk and foam',             40.00, 50.00,  2, true),
    ('hot-coffee',  'CF-003', 'latte',                'لاتيه',                  'Latte',                  'إسبريسو مع حليب',                     'Espresso with steamed milk',                     35.00, null::numeric,  3, true),
    ('hot-coffee',  'CF-004', 'mocha',                'موكا',                   'Mocha',                  'شوكولاتة مع إسبريسو',                 'Chocolate and espresso',                          45.00, 55.00,  4, false),
    ('hot-coffee',  'CF-005', 'americano',            'أمريكانو',               'Americano',              'إسبريسو مع الماء',                     'Espresso with water',                             30.00, null::numeric,  5, false),
    ('cold-coffee', 'CF-006', 'iced-latte',           'لاتيه مثلج',             'Iced Latte',             'لاتيه مع الثلج',                       'Iced latte',                                    42.00, 50.00,  6, true),
    ('tea',         'CF-007', 'green-tea',            'شاي أخضر',               'Green Tea',              'شاي أخضر طبيعي',                       'Natural green tea',                              20.00, null::numeric,  7, true),
    ('tea',         'CF-008', 'masala-tea',           'شاي بالهيل',        'Masala Tea',             'شاي بالهيل والزنجبيل',                'Tea with cardamom and ginger',                   25.00, null::numeric,  8, false),
    ('desserts',    'CF-009', 'cheesecake',           'تشيز كيك',               'Cheesecake',             'تشيز كيك كلاسيكي',                     'Classic cheesecake',                             55.00, 65.00,  9, true),
    ('desserts',    'CF-010', 'chocolate-brownie',    'براوني شوكولاتة',       'Chocolate Brownie',      'براوني غني بالشوكولاتة',              'Rich chocolate brownie',                        48.00, null::numeric, 10, false),
    ('snacks',      'CF-011', 'chocolate-chip-cookie','كوكيز شوكولاتة',         'Chocolate Chip Cookie',  'كوكيز بالشوكولاتة',                   'Chocolate chip cookie',                          18.00, null::numeric, 11, false),
    ('snacks',      'CF-012', 'butter-croissant',     'كرواسون بالزبدة',        'Butter Croissant',       'كرواسون مقرمش',                       'Flaky butter croissant',                         30.00, null::numeric, 12, false),
    ('milkshakes',  'CF-013', 'chocolate-milkshake',  'ميلك شيك شوكولاتة',      'Chocolate Milkshake',    'عصير شوكولاتة مثلج',                  'Frozen chocolate shake',                         45.00, 55.00, 13, false),
    ('soft-drinks', 'CF-014', 'cola',                 'كولا',                   'Cola',                   'مشروب غازي',                          'Soft drink',                                     15.00, null::numeric, 14, false),
    ('bakery',      'CF-015', 'butter-bread',         'خبز بالزبدة',            'Butter Bread',           'خبز طازج بالزبدة',                    'Fresh buttered bread',                           28.00, null::numeric, 15, false),
    ('donuts',      'CF-016', 'glazed-donut',         'دونات بالشوكولاتة',    'Glazed Donut',           'دونات بالشوكولاتة',                    'Glazed chocolate donut',                         22.00, null::numeric, 16, false)
  ) as p(cat_slug, sku, slug, name_ar, name_en, description_ar, description_en, base_price, compare_at_price, sort_order, is_featured)
  join catalog.categories c on c.slug = p.cat_slug
on conflict (sku) do nothing;

-- ---------------------------------------------------------------------------
-- Bind option groups to products.
-- Sizes: hot coffee, cold coffee, tea, milkshakes, soft drinks
-- (replaces sizedCategories string matching in product_variants.dart)
-- ---------------------------------------------------------------------------
insert into catalog.product_option_groups (product_id, group_id)
select p.id, g.id
  from catalog.products p
  join catalog.categories c on c.id = p.category_id
  join catalog.option_groups g on g.code = 'size'
 where c.slug in ('hot-coffee','cold-coffee','tea','milkshakes','soft-drinks')
on conflict do nothing;

insert into catalog.product_option_groups (product_id, group_id)
select p.id, g.id
  from catalog.products p
  join catalog.categories c on c.id = p.category_id
  join catalog.option_groups g on g.code = 'sugar'
 where c.slug in ('hot-coffee','cold-coffee','tea','milkshakes','soft-drinks')
on conflict do nothing;

-- Extras: hot coffee + cold coffee (4 each), tea (2), milkshakes (2)
insert into catalog.product_option_groups (product_id, group_id)
select p.id, g.id
  from catalog.products p
  join catalog.categories c on c.id = p.category_id
  join catalog.option_groups g on g.code = 'extras'
 where c.slug in ('hot-coffee','cold-coffee','tea','milkshakes')
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- Arabic search aliases (from AssistantPhrases.productSynonyms).
-- This is what lets "لاتيه" find Latte without SearchCubit borrowing the
-- assistant's word list.
-- ---------------------------------------------------------------------------
insert into catalog.product_aliases (product_id, alias, locale)
select p.id, a.alias, 'ar'
  from (values
    ('espresso',             'إسبريسو'), ('espresso', 'اسبرسو'), ('espresso', 'بن'),
    ('cappuccino',           'كابتشينو'), ('cappuccino', 'كابتشنينو'), ('cappuccino', 'كابتشينو'),
    ('latte',                'لاتيه'),    ('latte', 'لاتتي'), ('latte', 'قهوة بالحليب'),
    ('mocha',                'موكا'),     ('mocha', 'موكا شوكولاتة'),
    ('americano',            'أمريكانو'), ('americano', 'امريكانو'),
    ('iced-latte',           'لاتيه مثلج'), ('iced-latte', 'ايسد لاتيه'), ('iced-latte', 'قهوة مثلجة'),
    ('green-tea',            'شاي أخضر'), ('green-tea', 'شاي اخضر'), ('green-tea', 'شاي'),
    ('masala-tea',           'شاي بالهيل'), ('masala-tea', 'شاي بالهيل والزنجبيل'),
    ('cheesecake',           'تشيز كيك'), ('cheesecake', 'تشيزكيك'), ('cheesecake', 'كيك'),
    ('chocolate-brownie',    'براوني'),   ('chocolate-brownie', 'براوني شوكولاتة'),
    ('chocolate-chip-cookie','كوكيز'),    ('chocolate-chip-cookie', 'كوكيز شوكولاتة'),
    ('butter-croissant',     'كرواسون'),  ('butter-croissant', 'كروسان'),
    ('chocolate-milkshake',  'ميلك شيك'), ('chocolate-milkshake', 'ملكشك'), ('chocolate-milkshake', 'عصير شوكولاتة'),
    ('cola',                 'كولا'),     ('cola', 'مشروب غازي'),
    ('butter-bread',         'خبز'),      ('butter-bread', 'توست'),
    ('glazed-donut',         'دونات'),    ('glazed-donut', 'دوناتس'), ('glazed-donut', 'كرواسون حلو')
  ) as a(slug, alias)
  join catalog.products p on p.slug = a.slug
on conflict do nothing;

-- Category aliases, from categoryBoosts.
insert into catalog.category_aliases (category_id, alias, locale)
select c.id, a.alias, 'ar'
  from (values
    ('desserts', 'حلويات'), ('desserts', 'حلو'), ('desserts', 'كيك'),
    ('snacks',   'وجبات خفيفة'), ('snacks', 'سناكس'), ('snacks', 'وجبة'),
    ('bakery',   'مخبوزات'), ('bakery', 'خبز'), ('bakery', 'معجنات'),
    ('donuts',   'دوناتس'), ('donuts', 'دونات'), ('donuts', 'مقبلات حلوة'),
    ('hot-coffee', 'قهوة ساخنة'), ('hot-coffee', 'قهوة'),
    ('cold-coffee','قهوة باردة'), ('cold-coffee', 'ايسد'), ('cold-coffee', 'مثلج'),
    ('tea',      'شاي'), ('milkshakes', 'ميلك شيك'), ('soft-drinks', 'مشروبات')
  ) as a(cat_slug, alias)
  join catalog.categories c on c.slug = a.cat_slug
on conflict do nothing;