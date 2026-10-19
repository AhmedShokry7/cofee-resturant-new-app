-- 081_harden_function_and_view_grants.sql
--
-- Least-privilege cleanup. Public/anon lose execution on internal helpers.
-- Authenticated keeps execution on functions that back public RPC wrappers, while
-- a small set of internal-only helpers is revoked from authenticated too.

-- ---------------------------------------------------------------------------
-- 1. Anonymous/default-PUBLIC execution on internal schemas is removed. Keeping
--    authenticated execution preserves public (SECURITY INVOKER) RPC wrappers.
-- ---------------------------------------------------------------------------
revoke execute on all functions in schema orders, catalog, core, inventory, marketing, loyalty, engagement, payments, subscriptions from public;
revoke execute on all functions in schema orders, catalog, core, inventory, marketing, loyalty, engagement, payments, subscriptions from anon;

revoke execute on all functions in schema identity from public;
revoke execute on all functions in schema identity from anon;

-- ---------------------------------------------------------------------------
-- 2. Internal-only helpers that are never invoked through public wrappers and
--    have no client-facing authorization of their own.
-- ---------------------------------------------------------------------------
revoke execute on function loyalty.apply_points(uuid, integer, text, text, uuid, text) from public;
revoke execute on function loyalty.apply_points(uuid, integer, text, text, uuid, text) from anon;
revoke execute on function loyalty.apply_points(uuid, integer, text, text, uuid, text) from authenticated;

revoke execute on function identity.audit(text, text, uuid, jsonb, jsonb, uuid) from public;
revoke execute on function identity.audit(text, text, uuid, jsonb, jsonb, uuid) from anon;
revoke execute on function identity.audit(text, text, uuid, jsonb, jsonb, uuid) from authenticated;

revoke execute on function catalog.rebuild_category_search(uuid) from public;
revoke execute on function catalog.rebuild_category_search(uuid) from anon;
revoke execute on function catalog.rebuild_category_search(uuid) from authenticated;

revoke execute on function catalog.rebuild_product_search(uuid) from public;
revoke execute on function catalog.rebuild_product_search(uuid) from anon;
revoke execute on function catalog.rebuild_product_search(uuid) from authenticated;

revoke execute on function core.delivery_zone_fee(uuid, uuid, numeric, numeric, numeric) from public;
revoke execute on function core.delivery_zone_fee(uuid, uuid, numeric, numeric, numeric) from anon;
revoke execute on function core.delivery_zone_fee(uuid, uuid, numeric, numeric, numeric) from authenticated;

revoke execute on function core.zone_covers_point(uuid, numeric, numeric) from public;
revoke execute on function core.zone_covers_point(uuid, numeric, numeric) from anon;
revoke execute on function core.zone_covers_point(uuid, numeric, numeric) from authenticated;

revoke execute on function orders.place_order_impl(uuid, text, text, uuid, text, text, uuid) from public;
revoke execute on function orders.place_order_impl(uuid, text, text, uuid, text, text, uuid) from anon;
revoke execute on function orders.place_order_impl(uuid, text, text, uuid, text, text, uuid) from authenticated;

revoke execute on function subscriptions.finalize_order_consumption(uuid) from public;
revoke execute on function subscriptions.finalize_order_consumption(uuid) from anon;
revoke execute on function subscriptions.finalize_order_consumption(uuid) from authenticated;

revoke execute on function subscriptions.release_order_consumption(uuid) from public;
revoke execute on function subscriptions.release_order_consumption(uuid) from anon;
revoke execute on function subscriptions.release_order_consumption(uuid) from authenticated;

revoke execute on function subscriptions.handle_order_status_change() from public;
revoke execute on function subscriptions.handle_order_status_change() from anon;
revoke execute on function subscriptions.handle_order_status_change() from authenticated;

-- ---------------------------------------------------------------------------
-- 3. Anonymous write access to public bridge tables/views is removed.
-- ---------------------------------------------------------------------------
revoke insert, update, delete, truncate, references, trigger on all tables in schema public from anon;

-- Authenticated users do not need TRUNCATE/REFERENCES/TRIGGER on exposed objects;
-- DML remains controlled by RLS.
revoke truncate, references, trigger on all tables in schema public from authenticated;

-- ---------------------------------------------------------------------------
-- 4. Reload PostgREST metadata.
-- ---------------------------------------------------------------------------
notify pgrst, 'reload schema';
