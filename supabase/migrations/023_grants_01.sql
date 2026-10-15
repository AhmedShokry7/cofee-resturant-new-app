-- 023_grants_01.sql
--
-- Explicit, minimal grants. Nothing broad for anon or authenticated
-- (spec section 9.10).
--
-- Pattern:
--   anon        -> SELECT on public catalogue only, so the menu renders
--                  before anyone signs in.
--   authenticated -> same catalogue, PLUS owner-scoped access to their own
--                  rows (enforced by the RLS policies already in place).
--   ai.*        -> nobody. Edge Function only.

grant usage on schema core, catalog, orders, inventory, payments,
                 loyalty, marketing, engagement, identity
  to anon, authenticated;

-- ---------------------------------------------------------------------------
-- anon: public catalogue reads only
-- ---------------------------------------------------------------------------
grant select on
  core.brands, core.branches, core.delivery_zones, core.delivery_zone_branches,
  catalog.categories, catalog.products, catalog.product_images,
  catalog.option_groups, catalog.option_values, catalog.product_option_groups,
  catalog.product_aliases, catalog.category_aliases,
  catalog.bundles, catalog.bundle_items, catalog.branch_product_pricing,
  marketing.banners, marketing.coupons, loyalty.loyalty_rules, loyalty.loyalty_rewards,
  payments.payment_methods
  to anon;

-- ---------------------------------------------------------------------------
-- authenticated: public catalogue + customer-owned tables.
-- RLS decides which rows are actually visible.
-- ---------------------------------------------------------------------------
grant select on
  core.brands, core.branches, core.delivery_zones, core.delivery_zone_branches,
  core.legal_documents, core.faq_items, core.onboarding_slides, core.app_settings,
  catalog.categories, catalog.products, catalog.product_images,
  catalog.option_groups, catalog.option_values, catalog.product_option_groups,
  catalog.product_aliases, catalog.category_aliases,
  catalog.bundles, catalog.bundle_items, catalog.branch_product_pricing,
  marketing.banners, marketing.coupons,
  loyalty.loyalty_rules, loyalty.loyalty_rewards,
  payments.payment_methods
  to authenticated;

-- Tables a signed-in customer must be able to read and/or write directly.
grant select on
  identity.profiles, identity.customer_addresses,
  loyalty.loyalty_accounts, loyalty.loyalty_transactions,
  engagement.product_reviews, engagement.notifications,
  engagement.notification_preferences, engagement.device_tokens,
  marketing.coupon_redemptions,
  orders.carts, orders.cart_items, orders.cart_item_options,
  orders.orders, orders.order_items, orders.order_item_options,
  orders.order_status_history
  to authenticated;

grant insert, update on
  identity.profiles, identity.customer_addresses,
  engagement.notification_preferences, engagement.device_tokens,
  engagement.product_reviews
  to authenticated;

grant update on engagement.notifications to authenticated;

-- Search projections are read-only for everyone.
grant select on catalog.product_search, catalog.category_search to anon, authenticated;

-- Read-only reference for the admin UI.
grant select on identity.roles, identity.permissions, identity.role_permissions
  to authenticated;
grant select on orders.status_transitions to authenticated;

-- ---------------------------------------------------------------------------
-- No authenticated access to: identity.staff_members, identity.staff_roles,
-- identity.audit_log, inventory.*, payments.payment_attempts,
-- payments.payment_transactions, ai.*
-- ---------------------------------------------------------------------------
revoke all on identity.staff_members, identity.staff_roles, identity.audit_log
  from anon, authenticated;
revoke all on inventory.branch_stock, inventory.stock_movements
  from anon, authenticated;
revoke all on payments.payment_attempts, payments.payment_transactions
  from anon, authenticated;
revoke all on orders.order_events from anon, authenticated;

-- Explicit confirmation that ai is closed to client roles.
revoke all on schema ai from anon, authenticated;

-- ---------------------------------------------------------------------------
-- sequences: staff_members uses uuid PKs, audit_log uses bigserial and is
-- service_role-only. order_events is bigserial too.
-- ---------------------------------------------------------------------------
grant usage, select on all sequences in schema identity to authenticated;
revoke all on all sequences in schema identity from anon;

-- ---------------------------------------------------------------------------
-- View (D9): identity.user_points gives the app the profile plus the
-- loyalty balance in one read, without duplicating the number.
-- ---------------------------------------------------------------------------
grant select on identity.user_points to authenticated;