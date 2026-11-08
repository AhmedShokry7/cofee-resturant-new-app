-- 1) Defense in depth: RLS on ai.learned_answers (no policies = service_role/owner only)
ALTER TABLE ai.learned_answers ENABLE ROW LEVEL SECURITY;

-- 2) Trigger / event-trigger functions must never be callable as RPC
REVOKE EXECUTE ON FUNCTION catalog.sync_product_image_url()            FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION engagement.notify_subscription_status()     FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION orders.fill_order_item_product_discount()   FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION orders.refresh_order_product_discount()     FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.rls_auto_enable()                    FROM PUBLIC, anon, authenticated;

-- 3) Internal / cron / maintenance functions: server-side only (pg_cron runs as postgres)
REVOKE EXECUTE ON FUNCTION engagement.process_subscription_notifications() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION catalog.rebuild_category_search(uuid)           FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION catalog.rebuild_product_search(uuid)            FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION subscriptions.activate_subscription(uuid, text) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION engagement.process_subscription_notifications() TO service_role;
GRANT  EXECUTE ON FUNCTION catalog.rebuild_category_search(uuid)           TO service_role;
GRANT  EXECUTE ON FUNCTION catalog.rebuild_product_search(uuid)            TO service_role;
GRANT  EXECUTE ON FUNCTION subscriptions.activate_subscription(uuid, text) TO service_role;

-- 4) Coupon scope lookups require a signed-in user (anon could probe coupon codes)
REVOKE EXECUTE ON FUNCTION public.coupon_scope(text)     FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.coupon_scopes(text[])  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.coupon_scope(text)     TO authenticated, service_role;
GRANT  EXECUTE ON FUNCTION public.coupon_scopes(text[])  TO authenticated, service_role;

-- 5) Pin search_path on the flagged functions (keeps the old effective path, removes the mutable-path risk)
ALTER FUNCTION catalog.sync_alias_normalized()         SET search_path = pg_catalog, public, extensions;
ALTER FUNCTION payments.guard_payment_status()         SET search_path = pg_catalog, public, extensions;
ALTER FUNCTION inventory.validate_movement_variant()   SET search_path = pg_catalog, public, extensions;
ALTER FUNCTION core.set_updated_at()                   SET search_path = pg_catalog, public, extensions;
ALTER FUNCTION catalog.trg_product_search()            SET search_path = pg_catalog, public, extensions;
ALTER FUNCTION catalog.trg_category_search()           SET search_path = pg_catalog, public, extensions;
ALTER FUNCTION core.slugify(text)                      SET search_path = pg_catalog, public, extensions;
ALTER FUNCTION inventory.validate_stock_variant()      SET search_path = pg_catalog, public, extensions;
ALTER FUNCTION core.normalize_ar(text)                 SET search_path = pg_catalog, public, extensions;
