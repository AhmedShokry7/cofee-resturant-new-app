-- 083_restore_client_function_execute_grants.sql
--
-- Repairs the privilege regression introduced by 081_harden_function_and_view_grants.sql.
--
-- Root cause
-- ----------
-- 081 line 11-12 ran:
--     revoke execute on all functions in schema orders, catalog, core, inventory,
--       marketing, loyalty, engagement, payments, subscriptions from public;
--     revoke execute on all functions in schema ... from anon;
-- and line 14-15 did the same for schema identity.
--
-- In PostgreSQL "PUBLIC" is a pseudo-role that every role inherits from. Revoking
-- from PUBLIC therefore removed EXECUTE from `authenticated`, `service_role` and
-- `supabase_auth_admin` too -- not just from `anon`. Nothing in this repository ever
-- granted EXECUTE on these internal functions to a specific role (every
-- `grant execute` targets a `public.*` bridge), so those roles lost access outright.
-- The comment at 081 lines 8-10 ("Keeping authenticated execution preserves public
-- SECURITY INVOKER RPC wrappers") states the opposite of what the statement does.
--
-- Why it takes down every page
-- ----------------------------
--   * The `public.*` bridges are SECURITY INVOKER (035, 045, 058, 066, 070, 074-078).
--     The caller must be able to execute the wrapped internal function, otherwise the
--     call dies with 42501 inside the bridge.
--   * The `public.*` bridge views are `WITH (security_invoker = true)` (032), so RLS
--     is evaluated as `authenticated`.
--   * RLS policy qualifiers call identity.has_permission()/is_staff()/can_manage_branch()/
--     manages_all_branches(). A policy expression that raises aborts the whole query,
--     so every catalogue read failed with "permission denied for function has_permission".
--   * Trigger functions are SECURITY INVOKER and require EXECUTE from the role that
--     performs the DML, so customer profile/address writes and the auth.users
--     signup trigger failed too.
--
-- Scope of this repair
-- --------------------
--   * Grants only, never to PUBLIC.
--   * No function body, signature, SECURITY attribute, RLS policy, table, or data
--     is changed.
--   * Every grant below is justified by an actual dependency discovered in the live
--     catalog: an RLS policy expression, a SECURITY INVOKER public bridge used by the
--     app, or a trigger that fires on a table the role writes directly.
--
-- Deliberately NOT granted (still private, per the 081 section 2 intent, which is
-- correct for these because every remaining caller is SECURITY DEFINER and therefore
-- executes as the owner):
--     loyalty.apply_points, identity.audit, orders.place_order_impl,
--     subscriptions.finalize_order_consumption, subscriptions.release_order_consumption,
--     subscriptions.handle_order_status_change, core.geo_point_in_polygon,
--     core.geo_point_in_ring, engagement.notify_order_status, engagement.notify_loyalty,
--     inventory.validate_stock_variant, inventory.validate_movement_variant,
--     core.slugify (no caller in the catalog)
--
-- Idempotent: re-running changes nothing.

-- ===========================================================================
-- 1. RLS policy helpers -> authenticated
--
--    61 policies call identity.has_permission(), 11 call identity.can_manage_branch(),
--    and one each call identity.is_staff() / identity.manages_all_branches(). All four
--    are SECURITY DEFINER boolean predicates over identity.staff_members/staff_roles.
--    A policy expression cannot be evaluated without EXECUTE on the function it calls,
--    regardless of the function's SECURITY attribute. 61 policies cover
--    catalog.*, core.*, marketing.*, loyalty.*, orders.*, payments.*, inventory.*,
--    identity.* and engagement.*, i.e. the whole customer and staff read surface.
-- ===========================================================================
grant execute on function identity.has_permission(text) to authenticated;
grant execute on function identity.can_manage_branch(uuid) to authenticated;
grant execute on function identity.is_staff() to authenticated;
grant execute on function identity.manages_all_branches() to authenticated;

-- ===========================================================================
-- 2. Guest and customer catalogue RPCs -> authenticated, anon
--
--    036_public_bridge_harden_grants.sql section 2 deliberately granted these five
--    public bridges to `anon` so the menu renders before sign-in, and section 3
--    granted them to `authenticated`. Each bridge is SECURITY INVOKER over the
--    function below, so the calling role needs EXECUTE on the wrapped function.
--    All five are read-only and expose no customer data. spec 9.1 marks the
--    catalogue and active branches as anon-readable; spec section 8 lists
--    search_products / get_best_sellers / get_featured / resolve_effective_price
--    as the sanctioned catalogue RPCs.
-- ===========================================================================
grant execute on function catalog.get_featured(uuid, integer) to authenticated, anon;
grant execute on function catalog.search_products(text, uuid, uuid, numeric, numeric, text, integer, integer) to authenticated, anon;
grant execute on function catalog.get_best_sellers(uuid, interval, integer) to authenticated, anon;
grant execute on function catalog.resolve_effective_price(uuid, uuid, uuid[]) to authenticated, anon;
grant execute on function core.active_branches() to authenticated, anon;

-- ===========================================================================
-- 3. Delivery-zone resolution -> authenticated
--
--    public.resolve_delivery_zone is SECURITY INVOKER and calls all three directly,
--    so the signed-in caller needs EXECUTE on each.
--
--    `anon` is deliberately NOT granted. Resolving a zone and its fee is a checkout
--    step, not a guest flow; guests read the active zones through the
--    public.delivery_zones_for_branch bridge and the core.delivery_zones table,
--    both of which still work for anon.
--
--    core.geo_point_in_polygon / core.geo_point_in_ring are not granted: they are
--    only reached through core.zone_covers_point, which is SECURITY DEFINER.
-- ===========================================================================
grant execute on function core.delivery_zone_fee(uuid, uuid, numeric, numeric, numeric) to authenticated;
grant execute on function core.geo_distance_km(numeric, numeric, numeric, numeric) to authenticated;
grant execute on function core.zone_covers_point(uuid, numeric, numeric) to authenticated;

-- ===========================================================================
-- 4. Coupons -> authenticated
--
--    public.validate_coupon(text,numeric,uuid) and
--    public.validate_coupon_for_cart(uuid,text,jsonb) are both SECURITY INVOKER over
--    marketing.validate_coupon. 036 section 3 granted the bridges to `authenticated`
--    only, so only `authenticated` is granted here.
-- ===========================================================================
grant execute on function marketing.validate_coupon(text, numeric, uuid) to authenticated;

-- ===========================================================================
-- 5. Subscriptions -> authenticated
--
--    Every public subscription bridge in 074/075/077/078 is SECURITY INVOKER over the
--    matching subscriptions.* function, and 074 sections "Grants" granted those
--    bridges to `authenticated`. These are the customer-facing subscription flows
--    (my_subscription, list plans, subscribe, renew, auto-renew, cancel, QR issue and
--    redemption, usage history).
--
--    `anon` is not granted: 074 granted the mutating bridges to `authenticated`, and
--    the wrapped functions resolve auth.uid() internally, so they cannot serve a guest.
--
--    subscriptions.finalize_order_consumption / release_order_consumption /
--    handle_order_status_change stay revoked: their only callers are SECURITY DEFINER
--    (orders.place_order_impl and the orders.orders trigger), which run as the owner.
-- ===========================================================================
grant execute on function subscriptions.my_subscription() to authenticated;
grant execute on function subscriptions.list_plans(uuid) to authenticated;
grant execute on function subscriptions.plan_products_list(uuid) to authenticated;
grant execute on function subscriptions.create_pending_subscription(uuid, text) to authenticated;
grant execute on function subscriptions.reserve_for_order(uuid, uuid, uuid, jsonb, text) to authenticated;
grant execute on function subscriptions.set_auto_renew(uuid, boolean) to authenticated;
grant execute on function subscriptions.cancel_subscription(uuid) to authenticated;
grant execute on function subscriptions.activate_subscription(uuid, text) to authenticated;
grant execute on function subscriptions.usage_history(uuid) to authenticated;
grant execute on function subscriptions.generate_qr_token(uuid) to authenticated;
grant execute on function subscriptions.consume_qr(text, uuid, uuid, integer, text) to authenticated;

-- ===========================================================================
-- 6. Trigger functions on tables `authenticated` writes directly -> authenticated
--
--    Trigger functions are SECURITY INVOKER and PostgreSQL checks EXECUTE against the
--    role performing the DML, so the caller needs the grant even though the function
--    body is trivial.
--
--    core.set_updated_at fires on identity.profiles, identity.customer_addresses,
--    engagement.customer_websites, engagement.notification_preferences and
--    engagement.product_reviews -- all customer-writable.
--
--    catalog.sync_alias_normalized / catalog.trg_product_search /
--    catalog.trg_category_search fire on staff catalogue writes. 081 section 2 also
--    revoked catalog.rebuild_product_search and catalog.rebuild_category_search,
--    described as "never invoked through public wrappers". That rationale does not
--    hold: both are invoked by the SECURITY INVOKER triggers above, so staff
--    catalogue editing needs them. Both are SECURITY DEFINER and only refresh the
--    catalog.product_search / catalog.category_search projections.
--
--    core.normalize_ar is required transitively: catalog.sync_alias_normalized is
--    SECURITY INVOKER and calls it. 057 made the rebuild functions SECURITY DEFINER
--    precisely so catalogue writers never need direct INSERT on the search tables;
--    granting EXECUTE does not undo that.
-- ===========================================================================
grant execute on function core.set_updated_at() to authenticated;
grant execute on function core.normalize_ar(text) to authenticated;
grant execute on function catalog.sync_alias_normalized() to authenticated;
grant execute on function catalog.trg_product_search() to authenticated;
grant execute on function catalog.trg_category_search() to authenticated;
grant execute on function catalog.rebuild_product_search(uuid) to authenticated;
grant execute on function catalog.rebuild_category_search(uuid) to authenticated;

-- ===========================================================================
-- 7. Payment guard trigger -> service_role
--
--    payments.guard_payment_status fires BEFORE UPDATE on payments.payment_transactions
--    and is SECURITY INVOKER. The Tap webhook (supabase/functions/tap-webhook) PATCHes
--    that table through PostgREST as service_role, and it swallowed the failure with
--    `.catch(() => undefined)`, so confirmations were silently dropped. Restores the
--    pre-081 privilege for the role that owns this path.
-- ===========================================================================
grant execute on function payments.guard_payment_status() to service_role;

-- ===========================================================================
-- 8. Signup trigger -> supabase_auth_admin
--
--    auth.users has `on_auth_user_created AFTER INSERT ... EXECUTE FUNCTION
--    identity.handle_new_user()`, and GoTrue inserts as supabase_auth_admin
--    (confirmed: it holds INSERT and SELECT on auth.users). With EXECUTE revoked by
--    081, every new signup aborted, including the Google Sign-In flow added in
--    commit d68d16a.
-- ===========================================================================
grant execute on function identity.handle_new_user() to supabase_auth_admin;