-- 032_public_bridge_views.sql
--
-- ROUTING LAYER.
--
-- Why this exists
--   On this project PostgREF never loads the configured db-schemas list. The
--   value is stored correctly and reads back correctly through the Management
--   API, but the running service keeps serving only "public". Verified with:
--     * NOTIFY pgrst 'reload config' / 'reload schema'  -> no effect
--     * restart of postgrest, then a full project restart -> still public only
--     * postgrest.pre_config() is never invoked          -> in-database config off
--   So PostgREST can only reach the "public" schema.
--
-- What this file does
--   Publishes thin views in public over the ten application schemas. The real
--   tables stay exactly where they are, in their own schemas, with their own
--   RLS. Nothing is copied and nothing is flattened.
--
-- Why this is safe
--   Every view is created WITH (security_invoker = true). That makes the view
--   execute with the privileges of the CALLING role rather than the view owner,
--   so the underlying row-level security policies run unchanged and still
--   decide the rows. This is the difference between a bridge and a back door:
--
--     client -> public.products -> catalog.products -> RLS -> allowed rows only
--
--   No policy is relaxed anywhere by this file. The grants that back the views
--   are the ones already written in 023_grants_01.sql.
--
-- Trade-off, stated plainly: DATABASE_SPEC.md decision D10 says public stays
-- empty. That decision is deliberately overridden here, because the platform
-- will not serve any other schema. Tables remain separated; only the door is
-- routed through public.
--
-- ai is NOT published. It stays reachable only through an Edge Function.

-- ---------------------------------------------------------------------------
-- catalog
-- ---------------------------------------------------------------------------
create or replace view public.categories with (security_invoker = true) as
  select * from catalog.categories;

create or replace view public.products with (security_invoker = true) as
  select p.id, p.category_id, p.sku, p.slug, p.name_ar, p.name_en,
         p.description_ar, p.description_en, p.base_price,
         p.compare_at_price, p.image_url, p.is_active, p.is_featured,
         p.prep_minutes, p.is_calorie_tracked, p.allergens, p.sort_order,
         c.slug  as category_slug,
         c.name_ar as category_name_ar,
         c.name_en as category_name_en
    from catalog.products p
    join catalog.categories c on c.id = p.category_id;

create or replace view public.product_images with (security_invoker = true) as
  select * from catalog.product_images;

create or replace view public.bundles with (security_invoker = true) as
  select * from catalog.bundles;

create or replace view public.bundle_items with (security_invoker = true) as
  select * from catalog.bundle_items;

create or replace view public.option_groups with (security_invoker = true) as
  select * from catalog.option_groups;

create or replace view public.option_values with (security_invoker = true) as
  select * from catalog.option_values;

create or replace view public.product_option_groups with (security_invoker = true) as
  select * from catalog.product_option_groups;

-- Branch pricing. Needed by the client so it can show the price for the branch
-- the customer picked, and so the server can refuse an unavailable item.
create or replace view public.branch_product_pricing with (security_invoker = true) as
  select * from catalog.branch_product_pricing;

-- ---------------------------------------------------------------------------
-- core
-- ---------------------------------------------------------------------------
create or replace view public.brand with (security_invoker = true) as
  select * from core.brands;

create or replace view public.branches with (security_invoker = true) as
  select id, code, name_ar, name_en, address, latitude, longitude, phone,
         is_active, opens_at, closes_at, created_at
    from core.branches;

create or replace view public.delivery_zones with (security_invoker = true) as
  select id, name_ar, name_en, delivery_fee, min_order_amount,
         estimated_minutes, is_active
    from core.delivery_zones;

create or replace view public.faq_items with (security_invoker = true) as
  select * from core.faq_items;

create or replace view public.legal_documents with (security_invoker = true) as
  select * from core.legal_documents;

create or replace view public.onboarding_slides with (security_invoker = true) as
  select * from core.onboarding_slides;

create or replace view public.app_settings with (security_invoker = true) as
  select * from core.app_settings;

-- ---------------------------------------------------------------------------
-- marketing
-- ---------------------------------------------------------------------------
create or replace view public.banners with (security_invoker = true) as
  select * from marketing.banners;

create or replace view public.coupons with (security_invoker = true) as
  select id, code, title_ar, title_en, description_ar, description_en,
         discount_type, discount_value, max_discount, min_order_amount,
         applies_to, starts_at, ends_at, is_active
    from marketing.coupons;

create or replace view public.coupon_redemptions with (security_invoker = true) as
  select * from marketing.coupon_redemptions;

-- ---------------------------------------------------------------------------
-- loyalty
-- ---------------------------------------------------------------------------
create or replace view public.loyalty_rules with (security_invoker = true) as
  select * from loyalty.loyalty_rules;

create or replace view public.loyalty_rewards with (security_invoker = true) as
  select r.id, r.product_id, r.points_cost, r.stock_available, r.is_active,
         p.slug, p.name_ar, p.name_en, p.image_url
    from loyalty.loyalty_rewards r
    join catalog.products p on p.id = r.product_id;

create or replace view public.loyalty_accounts with (security_invoker = true) as
  select * from loyalty.loyalty_accounts;

create or replace view public.loyalty_transactions with (security_invoker = true) as
  select * from loyalty.loyalty_transactions;

-- D9 read path: profile and balance in one query, balance never duplicated.
create or replace view public.user_points with (security_invoker = true) as
  select * from identity.user_points;

-- ---------------------------------------------------------------------------
-- identity (customer-owned only; staff and audit stay unreachable)
-- ---------------------------------------------------------------------------
create or replace view public.profiles with (security_invoker = true) as
  select * from identity.profiles;

create or replace view public.customer_addresses with (security_invoker = true) as
  select * from identity.customer_addresses;

-- ---------------------------------------------------------------------------
-- orders (read only; every write goes through a SECURITY DEFINER function)
-- ---------------------------------------------------------------------------
create or replace view public.carts with (security_invoker = true) as
  select * from orders.carts;

create or replace view public.cart_items with (security_invoker = true) as
  select * from orders.cart_items;

create or replace view public.cart_item_options with (security_invoker = true) as
  select * from orders.cart_item_options;

create or replace view public.orders with (security_invoker = true) as
  select * from orders.orders;

create or replace view public.order_items with (security_invoker = true) as
  select * from orders.order_items;

create or replace view public.order_item_options with (security_invoker = true) as
  select * from orders.order_item_options;

create or replace view public.order_status_history with (security_invoker = true) as
  select * from orders.order_status_history;

-- ---------------------------------------------------------------------------
-- engagement
-- ---------------------------------------------------------------------------
create or replace view public.product_reviews with (security_invoker = true) as
  select * from engagement.product_reviews;

create or replace view public.notifications with (security_invoker = true) as
  select * from engagement.notifications;

create or replace view public.notification_preferences with (security_invoker = true) as
  select * from engagement.notification_preferences;

create or replace view public.device_tokens with (security_invoker = true) as
  select * from engagement.device_tokens;

-- ---------------------------------------------------------------------------
-- payments: methods are public, transactions are not published at all.
-- ---------------------------------------------------------------------------
create or replace view public.payment_methods with (security_invoker = true) as
  select * from payments.payment_methods;

-- ---------------------------------------------------------------------------
-- Grants.
--
-- The views inherit their rows from the underlying RLS. These grants only
-- decide whether a role may read the view at all.
-- ---------------------------------------------------------------------------
grant usage on schema public to anon, authenticated;

-- Public catalogue, readable before anyone signs in.
grant select on
  public.categories, public.products, public.product_images,
  public.bundles, public.bundle_items,
  public.option_groups, public.option_values, public.product_option_groups,
  public.branch_product_pricing,
  public.brand, public.branches, public.delivery_zones,
  public.faq_items, public.legal_documents, public.onboarding_slides,
  public.app_settings,
  public.banners, public.coupons,
  public.loyalty_rules, public.loyalty_rewards,
  public.payment_methods
  to anon;

-- Everything else needs a session.
grant select on
  public.loyalty_accounts, public.loyalty_transactions, public.user_points,
  public.profiles, public.customer_addresses,
  public.carts, public.cart_items, public.cart_item_options,
  public.orders, public.order_items, public.order_item_options,
  public.order_status_history, public.coupon_redemptions,
  public.product_reviews, public.notifications,
  public.notification_preferences, public.device_tokens
  to authenticated;

-- anon must never see a single one of those.
revoke all on
  public.loyalty_accounts, public.loyalty_transactions, public.user_points,
  public.profiles, public.customer_addresses,
  public.carts, public.cart_items, public.cart_item_options,
  public.orders, public.order_items, public.order_item_options,
  public.order_status_history, public.coupon_redemptions,
  public.product_reviews, public.notifications,
  public.notification_preferences, public.device_tokens
  from anon;

comment on view public.products is
  'Routing view over catalog.products with security_invoker, so catalog RLS decides the rows.';
comment on view public.user_points is
  'Routing view over identity.user_points. Loyalty balance single source of truth (D9).';