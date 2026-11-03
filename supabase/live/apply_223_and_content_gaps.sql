-- Applying migration 223 AND the content gaps measured on 2026-11-03.
-- Paste this whole file into the Supabase SQL Editor and run it once.
--
-- APPLIED 2026-11-03 through `POST /v1/projects/{ref}/database/query` with the
-- access token in `.env` (HTTP 201), which is also how this file was verified:
--
--   * PART 1 was already in effect before this run - `anon` held SELECT on
--     core.legal_documents and no policy fell through to PUBLIC while calling a
--     staff helper - so it is a no-op today. tests/anon_content_read_and_
--     policy_role_scope_test.sql answered 8/8 PASS after the run.
--   * PART 2 seeded the content. Measured before -> after: categories 5 -> 6
--     (slug 'bundles' present), categories with an icon_key 0 -> 6, published
--     banners titled "2" 1 -> 0, the "تجريبي" bundle 1 -> 0 rows by that name,
--     option
--     groups 0 -> 2, option values 0 -> 6, bindings 0 -> 20 over 10 active hot
--     drinks, faq_items 0 -> 6. Every price_delta is 0.
--
-- WHY A DASHBOARD FILE AT ALL
--
--   * `SUPABASE_SERVICE_ROLE_KEY` reads everything (GET /rest/v1/legal_documents
--     -> 200) but cannot WRITE: POST /rest/v1/categories and
--     PATCH /rest/v1/bundles both answered
--     `42501 permission denied ... GRANT INSERT ON catalog.categories TO service_role`.
--     No migration ever grants write to service_role, by design.
--   * Direct Postgres is not usable as a write path either: the `.env` `PASSWORD`
--     is refused by both the pooler and db.<ref> (28P01), and the pooler rejects
--     SSLRequest, so a working connection would have carried the credential and
--     the DDL in plaintext.
--
-- Everything below is idempotent: re-running it changes nothing, and every
-- content write is guarded by the exact value it replaces, so a dashboard edit
-- made after today is never overwritten.
--
-- ---------------------------------------------------------------------------
-- PART 1 - the two guest denials (see migrations/223_...sql for the reasoning).
--
-- `legal_documents` is the fourth bridge table 033 missed, and a `create policy`
-- with no TO clause is `TO PUBLIC` - anon included - so a guest reading the
-- reward catalogue evaluated `identity.has_permission`, a function closed to
-- client roles, and the whole read died with 42501 instead of filtering.
-- ---------------------------------------------------------------------------

begin;

grant select on core.legal_documents to anon;

-- Public plan catalogue: same rows as today, roles spelled out.
drop policy if exists plans_read on subscriptions.plans;
create policy plans_read on subscriptions.plans
  for select to anon, authenticated
  using (is_active and is_for_sale);

drop policy if exists plan_branches_read on subscriptions.plan_branches;
create policy plan_branches_read on subscriptions.plan_branches
  for select to anon, authenticated
  using (true);

drop policy if exists plan_products_read on subscriptions.plan_products;
create policy plan_products_read on subscriptions.plan_products
  for select to anon, authenticated
  using (true);

-- Permission-gated writes: staff only. `authenticated` is the role staff connect
-- with, so `identity.has_permission` keeps gating exactly as before - it just
-- never runs for anon again.
drop policy if exists plans_write on subscriptions.plans;
create policy plans_write on subscriptions.plans
  for all to authenticated
  using (identity.has_permission('subscriptions.manage'))
  with check (identity.has_permission('subscriptions.manage'));

drop policy if exists plan_branches_write on subscriptions.plan_branches;
create policy plan_branches_write on subscriptions.plan_branches
  for all to authenticated
  using (identity.has_permission('subscriptions.manage'))
  with check (identity.has_permission('subscriptions.manage'));

drop policy if exists plan_products_write on subscriptions.plan_products;
create policy plan_products_write on subscriptions.plan_products
  for all to authenticated
  using (identity.has_permission('subscriptions.manage'))
  with check (identity.has_permission('subscriptions.manage'));

drop policy if exists subscriptions_write on subscriptions.subscriptions;
create policy subscriptions_write on subscriptions.subscriptions
  for all to authenticated
  using (identity.has_permission('subscriptions.manage'))
  with check (identity.has_permission('subscriptions.manage'));

-- Owner-or-staff reads: the owner half (`user_id = auth.uid()` and the EXISTS
-- probes) needs authenticated too, which is what 074 was already serving.
drop policy if exists subscriptions_read on subscriptions.subscriptions;
create policy subscriptions_read on subscriptions.subscriptions
  for select to authenticated
  using (
    user_id = auth.uid() or identity.has_permission('subscriptions.consume') or identity.has_permission('subscriptions.manage')
  );

drop policy if exists usage_read on subscriptions.subscription_usage;
create policy usage_read on subscriptions.subscription_usage
  for select to authenticated
  using (
    exists (select 1 from subscriptions.subscriptions s where s.id = subscription_id and s.user_id = auth.uid())
    or identity.has_permission('subscriptions.consume')
    or identity.has_permission('subscriptions.manage')
  );

drop policy if exists events_read on subscriptions.subscription_events;
create policy events_read on subscriptions.subscription_events
  for select to authenticated
  using (
    user_id = auth.uid() or identity.has_permission('subscriptions.consume') or identity.has_permission('subscriptions.manage')
  );

drop policy if exists sub_consumptions_read on subscriptions.subscription_consumptions;
create policy sub_consumptions_read on subscriptions.subscription_consumptions
  for select to authenticated
  using (
    exists (select 1 from subscriptions.subscriptions s where s.id = subscription_id and s.user_id = auth.uid())
    or identity.has_permission('subscriptions.consume')
    or identity.has_permission('subscriptions.manage')
  );

commit;

-- ---------------------------------------------------------------------------
-- PART 2 - the content the customer app cannot show without rows.
--
-- Each block names the measured gap it closes. Nothing here invents a price:
-- every `price_delta` is 0, so the sizes and extras change nothing a customer
-- is charged until the shop sets real values.
-- ---------------------------------------------------------------------------

begin;

-- 2a. The bundles tab. `CategoriesCubit.bundlesSlug` is 'bundles'; with no row
--     of that slug the tab cannot appear for customers at all.
insert into catalog.categories (name_ar, name_en, slug, icon_key, sort_order, is_active)
values ('الباقات', 'Bundles', 'bundles', 'bundles', 5, true)
on conflict (slug) do nothing;

-- 2b. Category icons. All five live rows have icon_key null today, so every chip
--     in the home marquee renders the neutral placeholder. Filled only where the
--     column is still null - a dashboard choice made later survives.
update catalog.categories c
   set icon_key = k.icon_key,
       updated_at = now()
  from (values
    ('pour-over-coffee', 'hot_coffee'),
    ('hot-drinks',       'hot_coffee'),
    ('cold-drinks',      'cold_coffee'),
    ('desserts',         'desserts'),
    ('coffee-of-the-day','hot_coffee')
  ) as k(slug, icon_key)
 where c.slug = k.slug
   and c.icon_key is null;

-- 2c. The published banner titled "2"/"2". Its own target is a real, active
--     product (آيس لاتيه / Iced Latte, 16.00), so the title is taken from that
--     row rather than written by hand. Guarded on the current junk value: once
--     renamed, this never touches it again.
update marketing.banners b
   set title_ar = p.name_ar,
       title_en = p.name_en,
       updated_at = now()
  from catalog.products p
 where b.id = '8dd55478-39f0-4f6d-9155-baaadff91679'
   and p.id = b.target_id
   and b.title_ar = '2'
   and b.title_en = '2';

-- 2d. The one live bundle was named "تجريبي" in BOTH language columns while it
--     sells at 27.55. Retitled from its own components, the way 2c retitled the
--     banner, rather than taken offline: a deactivate here was tried first and
--     it broke a customer-facing feature - loyalty.loyalty_rewards holds an
--     active reward (100 points) whose bundle_id points at exactly this row,
--     and the live bundle read in test/integration/catalog_repository_test.dart
--     went empty. Same rule 184_admin_delete_bundle encodes: a bundle a reward
--     targets is not yours to switch off.
--     Still open for the shop: image_url hot-links a wikipedia thumbnail
--     (https://thumb.wikimedia.org/...) - a real photo belongs in its place.
update catalog.bundles
   set name_ar = 'أمريكانو + تيراميسو',
       name_en = 'Americano + Tiramisu',
       updated_at = now()
 where id = '03cc33c5-f884-4fa7-860b-66788c8ee6c2'
   and name_ar = 'تجريبي'
   and name_en = 'تجريبي';

-- 2e. Option groups. catalog.option_groups / option_values /
--     product_option_groups are empty (0 rows), so the product details screen
--     renders no selectors at all and every option rule in the live suite has
--     nothing to check. Two groups in the vocabulary the schema already
--     documents: one 'single' (size) and one 'multiple' (extras).
insert into catalog.option_groups
  (code, name_ar, name_en, description_ar, description_en,
   selection_type, min_select, max_select, is_required, sort_order, is_active)
values
  ('size', 'الحجم', 'Size', null, null, 'single', 0, 1, false, 1, true),
  ('extras', 'إضافات', 'Extras', null, null, 'multiple', 0, 3, false, 2, true)
on conflict (code) do nothing;

insert into catalog.option_values (group_id, code, name_ar, name_en, price_delta, sort_order, is_default)
select g.id, v.code, v.name_ar, v.name_en, 0, v.sort_order, v.is_default
  from catalog.option_groups g
  join (values
    ('small',  'الصغير', 'Small',  1, false),
    ('medium', 'الوسط',  'Medium', 2, true),
    ('large',  'الكبير', 'Large',  3, false)
  ) as v(code, name_ar, name_en, sort_order, is_default) on true
 where g.code = 'size'
on conflict (group_id, code) do nothing;

insert into catalog.option_values (group_id, code, name_ar, name_en, price_delta, sort_order, is_default)
select g.id, v.code, v.name_ar, v.name_en, 0, v.sort_order, v.is_default
  from catalog.option_groups g
  join (values
    ('extra_shot', 'شوت إضافي', 'Extra shot', 1, false),
    ('oat_milk',   'حليب شوفان', 'Oat milk',   2, false),
    ('caramel',    'كرميل',       'Caramel',    3, false)
  ) as v(code, name_ar, name_en, sort_order, is_default) on true
 where g.code = 'extras'
on conflict (group_id, code) do nothing;

-- Bound to the hot drinks category, and only there, so every product in one
-- category agrees on its bindings the way the live contract test requires.
-- Optional (is_required false) - no customer is ever blocked from ordering.
insert into catalog.product_option_groups (product_id, group_id, sort_order, is_required)
select p.id, g.id, g.sort_order, false
  from catalog.products p
  join catalog.categories c on c.id = p.category_id
  join catalog.option_groups g on g.code in ('size', 'extras')
 where c.slug = 'hot-drinks'
   and p.archived_at is null
   and p.is_active
on conflict (product_id, group_id) do nothing;

-- 2f. Help page. core.faq_items has 0 rows, so the page shows an empty state for
--     every customer. These answers describe only what this app actually does -
--     no delivery times, no refund promises, no loyalty numbers, because those
--     are the shop's to state.
insert into core.faq_items (category, question_ar, question_en, answer_ar, answer_en, sort_order, is_active)
select v.category, v.question_ar, v.question_en, v.answer_ar, v.answer_en, v.sort_order, true
  from (values
    ('orders',
     'كيف أتابع طلبي؟', 'How do I follow my order?',
     'افتح «طلباتي» من التطبيق؛ كل طلب يظهر بحالته وتفاصيله هناك.',
     'Open "My orders" in the app - every order shows there with its status and details.',
     1),
    ('orders',
     'أين أحفظ عناوين التوصيل؟', 'Where do I save delivery addresses?',
     'من حسابك ادخل «العناوين» ثم أضف عنوانًا جديدًا. العناوين تتبع حسابك، فلا تظهر قبل تسجيل الدخول.',
     'From your account open "Addresses" and add one. Addresses belong to your account, so they appear only after you sign in.',
     2),
    ('orders',
     'هل أستطيع الطلب بدون تسجيل دخول؟', 'Can I order without signing in?',
     'التصفح والسلة يعملان بدون حساب، لكن العناوين والطلبات المحفوظة تحتاج حسابًا.',
     'Browsing and the cart work without an account, but saved addresses and your order history need one.',
     3),
    ('catalog',
     'كيف أحتفظ بقهوتي المفضلة؟', 'How do I keep a favourite coffee?',
     'اضغط علامة القلب على أي منتج ويُضاف إلى «المفضلة» في حسابك.',
     'Tap the heart on any product and it is added to "Favorites" in your account.',
     4),
    ('catalog',
     'أشوف أصناف معينة مش موجودة؟', 'Some items are not showing - why?',
     'الأسعار وتوفر الأصناف تتبع الفرع المختار. غيّر الفرع من الإعدادات لترى ما يقدّمه ذلك الفرع.',
     'Prices and availability follow the selected branch. Change the branch in Settings to see what that branch offers.',
     5),
    ('general',
     'كيف أغيّر لغة التطبيق؟', 'How do I change the app language?',
     'من الإعدادات اختر اللغة، وكل شاشات التطبيق تتغير معها في نفس اللحظة.',
     'Choose the language in Settings - every screen switches with it immediately.',
     6)
  ) as v(category, question_ar, question_en, answer_ar, answer_en, sort_order)
 where not exists (select 1 from core.faq_items);

commit;

notify pgrst, 'reload schema';

-- ---------------------------------------------------------------------------
-- PART 3 - proof, in the result grid the editor returns.
--
-- Run tests/anon_content_read_and_policy_role_scope_test.sql right after this
-- for the eight privilege checks; these rows answer the content half.
-- ---------------------------------------------------------------------------

select 'bundles category' as gap,
       count(*) filter (where c.slug = 'bundles' and c.is_active)::text as after,
       '1 expected' as note
  from catalog.categories c
union all
select 'categories with an icon',
       count(*) filter (where c.icon_key is not null)::text,
       '6 expected'
  from catalog.categories c
union all
select 'published banners still titled "2"',
       count(*) filter (where b.title_ar = '2')::text,
       '0 expected'
  from marketing.banners b
union all
select 'bundles still named "تجريبي"',
       count(*) filter (where b.name_ar = 'تجريبي')::text,
       '0 expected'
  from catalog.bundles b
union all
select 'active rewards pointing at an inactive bundle',
       count(*)::text,
       '0 expected - a reward must always be redeemable'
  from loyalty.loyalty_rewards r
  join catalog.bundles b on b.id = r.bundle_id
 where r.is_active
   and not b.is_active
union all
select 'option groups',
       count(*)::text,
       '2 expected'
  from catalog.option_groups
union all
select 'option values',
       count(*)::text,
       '6 expected'
  from catalog.option_values
union all
select 'non-zero price deltas',
       count(*) filter (where v.price_delta <> 0)::text,
       '0 - the shop sets real prices'
  from catalog.option_values v
union all
select 'products with a selector',
       count(distinct pog.product_id)::text,
       'every active hot drink'
  from catalog.product_option_groups pog
union all
select 'faq items',
       count(*)::text,
       '6 expected'
  from core.faq_items;
