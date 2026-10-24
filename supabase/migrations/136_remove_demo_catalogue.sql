-- 136_remove_demo_catalogue.sql
--
-- The database carried a complete demo catalogue: sixteen coffee products,
-- ten categories, four bundles, three option groups, nine banners, four
-- coupons, six loyalty rewards, the search aliases, the demo branches and the
-- records of the test sessions. It was content, not structure, and it made the
-- real catalogue impossible to see.
--
-- This migration removes the content and keeps the structure:
--
--   removed  the catalogue, the marketing content, the options, the aliases,
--            the stock, the demo branches and zones, the plans, the AI
--            knowledge, the FAQ and the legal pages, and every record of the
--            test sessions
--   kept    the accounts and the access control (the roles, the permissions
--            and the staff records), the brand, the payment methods, the
--            loyalty rule, the order status machine, the storage buckets and
--            the runtime settings
--
-- The deletions are plain deletes of whole tables, so a fresh database that
-- never saw the demo data is left exactly as it is.

-- ---------------------------------------------------------------------------
-- Marketing: banners, coupons and their redemptions.
-- ---------------------------------------------------------------------------
delete from marketing.coupon_redemptions;
delete from marketing.coupons_categories;
delete from marketing.coupons_products;
delete from marketing.coupons;
delete from marketing.banners;

-- ---------------------------------------------------------------------------
-- The assistant knowledge: it describes the demo products.
-- ---------------------------------------------------------------------------
delete from ai.learned_answers;
delete from ai.product_knowledge;
delete from ai.knowledge_articles;

-- ---------------------------------------------------------------------------
-- Loyalty: the balances, the transactions and the rewards of the demo
-- products. The earning rule itself stays.
-- ---------------------------------------------------------------------------
delete from loyalty.loyalty_transactions;
delete from loyalty.loyalty_accounts;
delete from loyalty.loyalty_rewards;

-- ---------------------------------------------------------------------------
-- Payments: the attempts, the transactions and the saved cards.
-- ---------------------------------------------------------------------------
delete from payments.payment_events;
delete from payments.payment_attempts;
delete from payments.payment_transactions;
delete from payments.tap_customers;
delete from payments.saved_cards;

-- ---------------------------------------------------------------------------
-- Subscriptions: the plans and the subscriptions of the test sessions.
-- ---------------------------------------------------------------------------
delete from subscriptions.subscription_consumptions;
delete from subscriptions.subscription_events;
delete from subscriptions.subscription_usage;
delete from subscriptions.subscriptions;
delete from subscriptions.plan_products;
delete from subscriptions.plan_branches;
delete from subscriptions.qr_tokens;
delete from subscriptions.plans;

-- ---------------------------------------------------------------------------
-- Engagement: the notifications, the device tokens and the reviews.
-- ---------------------------------------------------------------------------
delete from engagement.push_deliveries;
delete from engagement.notifications;
delete from engagement.device_tokens;
delete from engagement.notification_preferences;
delete from engagement.customer_favorites;
delete from engagement.customer_websites;
delete from engagement.product_reviews;

-- ---------------------------------------------------------------------------
-- Orders and carts: the records of the test sessions.
-- ---------------------------------------------------------------------------
delete from orders.order_item_options;
delete from orders.order_items;
delete from orders.order_status_history;
delete from orders.order_events;
delete from orders.cart_item_options;
delete from orders.cart_items;
delete from orders.carts;
delete from orders.orders;

-- ---------------------------------------------------------------------------
-- Stock.
-- ---------------------------------------------------------------------------
delete from inventory.stock_movements;
delete from inventory.branch_stock;

-- ---------------------------------------------------------------------------
-- The catalogue itself.
-- ---------------------------------------------------------------------------
delete from catalog.product_images;
delete from catalog.bundle_items;
delete from catalog.bundles;
delete from catalog.product_aliases;
delete from catalog.category_aliases;
delete from catalog.product_option_groups;
delete from catalog.products;
delete from catalog.categories;
delete from catalog.option_values;
delete from catalog.option_groups;
delete from catalog.branch_product_pricing;
delete from catalog.product_search;
delete from catalog.category_search;

-- ---------------------------------------------------------------------------
-- The content pages of the app and the demo locations.
-- ---------------------------------------------------------------------------
delete from core.faq_items;
delete from core.legal_documents;
delete from core.onboarding_slides;
delete from core.delivery_zone_branches;
delete from core.delivery_zones;
delete from core.branches;

-- ---------------------------------------------------------------------------
-- The customer addresses of the test sessions.
-- ---------------------------------------------------------------------------
delete from identity.customer_addresses;

-- ---------------------------------------------------------------------------
-- The settings that carried a placeholder value. The runtime settings
-- (push_function_url) stay: they are configuration, not content.
-- ---------------------------------------------------------------------------
delete from core.app_settings
 where key in (
   'delivery_fee_default',
   'cart_max_items',
   'tax_enabled',
   'app_version_min',
   'support_whatsapp',
   'loyalty_enabled',
   'order_tracking_enabled'
 );

-- ---------------------------------------------------------------------------
-- The rate limit counters are runtime state.
-- ---------------------------------------------------------------------------
delete from public.rate_limit_counters;
delete from public.assistant_rate_limit_counters;

notify pgrst, 'reload schema';
