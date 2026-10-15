-- seed_03_marketing_bundles_loyalty.sql
-- Bundles, banners, coupons, loyalty rewards, assistant knowledge, content.

-- ---------------------------------------------------------------------------
-- Bundles (4). bundle_items.quantity is new -- BundleModel had none.
-- ---------------------------------------------------------------------------
insert into catalog.bundles (name_ar, name_en, description_ar, description_en, bundle_price, sort_order)
select b.name_ar, b.name_en, b.description_ar, b.description_en, b.bundle_price, b.sort_order
  from (values
    ('صباح مزدوج',   'Morning Duo',   'إسبريسو مع كرواسون',       'Espresso with a croissant',        48.00, 1),
    ('استراحة حلوة', 'Sweet Break',   'لاتيه مع تشيز كيك',       'Latte with cheesecake',            79.00, 2),
    ('انتعاش بارد',  'Iced Refresh',  'لاتيه مثلج مع دونات',      'Iced latte with a donut',          56.00, 3),
    ('وقت الشاي',    'Tea Time',      'شاي أخضر مع خبز',          'Green tea with buttered bread',    42.00, 4)
  ) as b(name_ar, name_en, description_ar, description_en, bundle_price, sort_order)
on conflict do nothing;

insert into catalog.bundle_items (bundle_id, product_id, quantity, sort_order)
select bu.id, p.id, bi.qty, bi.sort_order
  from (values
    ('Morning Duo',  'espresso',      1, 1),
    ('Morning Duo',  'butter-croissant', 1, 2),
    ('Sweet Break',  'latte',         1, 1),
    ('Sweet Break',  'cheesecake',    1, 2),
    ('Iced Refresh', 'iced-latte',    1, 1),
    ('Iced Refresh', 'glazed-donut',  1, 2),
    ('Tea Time',     'green-tea',     1, 1),
    ('Tea Time',     'butter-bread',  1, 2)
  ) as bi(bundle_name, product_slug, qty, sort_order)
  join catalog.bundles bu on bu.name_en = bi.bundle_name
  join catalog.products p on p.slug = bi.product_slug
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- Banners (5). target_type replaces the raw targetCategory string.
-- ---------------------------------------------------------------------------
insert into marketing.banners
  (title_ar, title_en, subtitle_ar, subtitle_en, description_ar, description_en,
   image_url, cta_label_ar, cta_label_en, target_type, target_id, sort_order, is_published)
select b.ta, b.te, b.sa, b.se, b.da, b.de, b.img, b.ca, b.ce, 'category', c.id, b.sort_order, true
  from (values
    ('صباح نشط',   'Morning Boost', 'ابدأ يومك بشكل صحيح', 'Start your day right',   'عرض الصباح',   'Morning offer',   'assets/images/banar.png', 'تسوق الآن',   'Shop Now',  'hot-coffee',   1),
    ('بارد وطازج', 'Iced & Fresh',  'مثلجات منعشة',        'Refreshing iced',        'عروض المثلجات','Iced drinks',     'assets/images/banar.png', 'تسوق الآن',   'Shop Now',  'cold-coffee',  2),
    ('وقت الشاي',  'Tea Time',      'دفئ مع الشاي',         'Warm up with tea',       'عروض الشاي',   'Tea selection',   'assets/images/banar.png', 'تسوق الآن',   'Shop Now',  'tea',          3),
    ('مذاق حلو',   'Sweet Treats',  'حلويات طازجة',         'Fresh desserts',         'عروض الحلويات','Dessert selection','assets/images/banar.png','تسوق الآن',   'Shop Now',  'desserts',     4),
    ('وجبة خفيفة', 'Snack Corner',  'وجبات خفيفة',          'Quick bites',            'عروض السناكس', 'Snack selection', 'assets/images/banar.png', 'تسوق الآن',   'Shop Now',  'snacks',       5)
  ) as b(ta, te, sa, se, da, de, img, ca, ce, cat_slug, sort_order)
  join catalog.categories c on c.slug = b.cat_slug
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- Coupons (4). discount_value is numeric now, not scraped from text.
-- ---------------------------------------------------------------------------
insert into marketing.coupons
  (code, title_ar, title_en, description_ar, description_en,
   discount_type, discount_value, max_discount, min_order_amount,
   per_user_limit, is_active)
values
  ('WELCOME200', 'خصم ترحيبي', 'Welcome discount', 'خصم 50% على أول طلب', '50% off your first order', 'percentage', 50.00, 40.00, 30.00, 1, true),
  ('COFFEE20',   'خصم القهوة', 'Coffee discount',  'خصم 20% على القهوة',   '20% off coffee',            'percentage', 20.00, null,  0.00,  3, true),
  ('COLD50',     'خصم المشروبات الباردة', 'Cold drinks discount', 'خصم 50% على المشروبات الباردة', '50% off cold drinks', 'percentage', 50.00, null, 0.00, 2, true),
  ('LOYAL10',    'خصم الولاء', 'Loyalty discount', 'خصم 10% للعملاء المميزين', '10% off for loyal customers', 'percentage', 10.00, null, 0.00, 5, true)
on conflict (code) do nothing;

-- ---------------------------------------------------------------------------
-- Loyalty rewards. Replaces the frozen Map in loyalty_rules.dart:19-26
--   '14':150 (Cola), '11':180 (Cookie), '7':200 (Green Tea),
--   '1':250 (Espresso), '12':300 (Croissant), '2':400 (Cappuccino)
-- ---------------------------------------------------------------------------
insert into loyalty.loyalty_rewards (product_id, points_cost, stock_available)
select p.id, r.points, r.stock
  from (values
    ('cola', 150, 100), ('chocolate-chip-cookie', 180, 100),
    ('green-tea', 200, 100), ('espresso', 250, 100),
    ('butter-croissant', 300, 100), ('cappuccino', 400, 50)
  ) as r(product_slug, points, stock)
  join catalog.products p on p.slug = r.product_slug
on conflict (product_id) do nothing;

-- ---------------------------------------------------------------------------
-- Assistant product knowledge (from product_knowledge.dart:67-84)
-- ---------------------------------------------------------------------------
insert into ai.product_knowledge (product_id, ingredients, tags)
select p.id, k.ingredients::text[], k.tags::text[]
  from (values
    ('espresso',              '{espresso}',                      '{strong,black}'),
    ('cappuccino',            '{espresso,milk,foam}',            '{milky,classic}'),
    ('latte',                 '{espresso,milk}',                 '{milky,smooth}'),
    ('mocha',                 '{espresso,milk,chocolate,cream}', '{milky,sweet}'),
    ('americano',             '{espresso,water}',                '{black,light}'),
    ('iced-latte',            '{espresso,milk,ice}',             '{cold,milky,sweet}'),
    ('green-tea',             '{tea,water}',                     '{herbal,light}'),
    ('masala-tea',            '{tea,milk,spices,ginger,cardamom,cinnamon}', '{spiced,warm}'),
    ('cheesecake',            '{cheese,cream,biscuit,sugar,egg}','{sweet,dessert}'),
    ('chocolate-brownie',     '{chocolate,cocoa,butter,egg,flour}','{sweet,dessert}'),
    ('chocolate-chip-cookie', '{chocolate,butter,flour,sugar,egg}','{sweet,snack}'),
    ('butter-croissant',      '{butter,flour,milk}',             '{bakery,savory}'),
    ('chocolate-milkshake',   '{milk,ice_cream,chocolate,cream}', '{cold,sweet,thick}'),
    ('cola',                  '{soda,ice,sugar}',                '{cold,sweet}'),
    ('butter-bread',          '{flour,butter,milk,egg}',         '{bakery,savory}'),
    ('glazed-donut',          '{flour,sugar,glaze,egg}',        '{sweet,snack}')
  ) as k(product_slug, ingredients, tags)
  join catalog.products p on p.slug = k.product_slug
on conflict (product_id) do nothing;

-- ---------------------------------------------------------------------------
-- FAQ (from faqs_list.dart, 5 entries)
-- ---------------------------------------------------------------------------
insert into core.faq_items (category, question_ar, question_en, answer_ar, answer_en, sort_order) values
  ('general', 'كيف أطلب؟', 'How do I order?', 'اختر الفرع ثم أضف المنتجات إلى السلة وأكمل الدفع.', 'Pick a branch, add items to the cart, then check out.', 1),
  ('general', 'هل يوجد توصيل؟', 'Do you deliver?', 'نعم، نوصّل ضمن مناطق التوصيل المحددة.', 'Yes, within our defined delivery zones.', 2),
  ('payment', 'ما طرق الدفع المتاحة؟', 'Which payment methods are available?', 'الدفع عند الاستلام والبطاقات الإلكترونية.', 'Cash on delivery and electronic cards.', 3),
  ('menu',    'هل يوجد خيارات إضافية؟', 'Do you offer add-ons?', 'نعم، يمكنك إضافة الإضافات مثل الكريمة والنكهات.', 'Yes, you can add extras such as cream and syrups.', 4),
  ('loyalty', 'كيف أحصل على النقاط؟', 'How do I earn points?', 'تحصل على نقطة عن كل وحدة عملة على كل طلب.', 'You earn one point per currency unit on every order.', 5)
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- Onboarding slides (3)
-- ---------------------------------------------------------------------------
insert into core.onboarding_slides (image_url, title_ar, title_en, body_ar, body_en, sort_order) values
  ('assets/images/logo.png', 'اختر فرعك',   'Choose your branch',  'ابدأ بتحديد الفرع الأقرب لك',  'Start by picking your nearest branch',  1),
  ('assets/images/logo.png', 'اختر ما يحلو', 'Pick what you like',  'تصفح المنتجات والحجميات والإضافات', 'Browse products, sizes and add-ons',     2),
  ('assets/images/logo.png', 'اطلب بسهولة', 'Order in seconds',    'أضف إلى السلة وأكمل الطلب',   'Add to cart and check out',             3)
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- Legal documents (privacy_policy_text.dart lived as a Dart constant)
-- ---------------------------------------------------------------------------
insert into core.legal_documents (slug, title_ar, title_en, content_ar, content_en, version, is_published, published_at) values
  ('privacy', 'سياسة الخصوصية', 'Privacy Policy',
   'نجمع البيانات الضرورية لتقديم الخدمة فقط، ولا نشارك بياناتك مع أطراف أخرى دون موافقتك.',
   'We collect only the data needed to provide the service and never share it with third parties without your consent.',
   '1.0', true, now()),
  ('terms', 'الشروط والأحكام', 'Terms of Service',
   'باستخدام التطبيق فإنك توافق على شروط الاستخدام المعلنة.',
   'By using the app you agree to the published terms of use.',
   '1.0', true, now())
on conflict (slug) do nothing;

-- ---------------------------------------------------------------------------
-- Knowledge articles for the local assistant (from coffee_knowledge.dart)
-- ---------------------------------------------------------------------------
insert into ai.knowledge_articles (slug, category, title_ar, title_en, body_ar, body_en, keywords, sort_order) values
  ('what_is_latte', 'coffee', 'ما هو اللاتيه؟', 'What is a latte?',
   'اللاتيه هو إسبريسو مع حليب مبخر.', 'A latte is espresso with steamed milk.',
   '{latte,لاتيه,حليب,milk}', 1),
  ('what_is_cappuccino', 'coffee', 'ما هو الكابتشينو؟', 'What is a cappuccino?',
   'الكابتشينو يحتوي على إسبريسو وحليب ورغوة.', 'A cappuccino is espresso, milk and foam.',
   '{cappuccino,كابتشينو,foam,رغوة}', 2),
  ('sizes', 'menu', 'أحجام المشروبات', 'Drink sizes',
   'نوفر-small، medium، large مع فرق سعر.', 'We offer small, medium and large sizes.',
   '{size,حجم,صغير,وسط,كبير}', 3),
  ('extras', 'menu', 'الإضافات', 'Extras',
   'يمكن إضافة الكريمة والنكهات وبنّة إضافية.', 'You can add cream, syrups and an extra shot.',
   '{extras,اضافات,كريمة,cream}', 4),
  ('orders', 'order', 'تتبع طلبك', 'Track your order',
   'يمكنك متابعة حالة طلبك من صفحة الطلبات.', 'You can follow your order status from the orders page.',
   '{order,طلب,تتبع,track}', 5)
on conflict (slug) do nothing;

-- ---------------------------------------------------------------------------
-- Rebuild every search document now that aliases exist.
-- ---------------------------------------------------------------------------
select catalog.rebuild_product_search(id) from catalog.products;
select catalog.rebuild_category_search(id) from catalog.categories;

-- ---------------------------------------------------------------------------
-- Per-branch availability. Everything is available at both branches for now,
-- but Cola is deliberately unavailable at the main branch so branch scoping
-- has a real negative case to test against.
-- ---------------------------------------------------------------------------
-- The per-branch flag is seeded from the product-level one rather than hardcoded.
-- get_featured() only returns a product when bpp.is_featured is true, so pinning
-- 'false' here made the home "Popular" section permanently empty while
-- catalog.products.is_featured was set correctly.
insert into catalog.branch_product_pricing (branch_id, product_id, is_available, is_featured)
select b.id, p.id, true, p.is_featured
  from core.branches b cross join catalog.products p
on conflict do nothing;

update catalog.branch_product_pricing bpp
   set is_available = false,
       unavailable_reason = 'branch does not stock cola'
  from core.branches b, catalog.products p
 where bpp.branch_id = b.id
   and bpp.product_id = p.id
   and b.code = 'MAIN'
   and p.slug = 'cola';

-- Stock: tracked at the main branch only, to exercise tracked vs untracked.
insert into inventory.branch_stock (branch_id, product_id, quantity_on_hand, reorder_level)
select '00000000-0000-4000-8000-000000000101', p.id, 100, 5
  from catalog.products p
on conflict do nothing;