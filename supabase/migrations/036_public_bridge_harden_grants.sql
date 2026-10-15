-- 036_public_bridge_harden_grants.sql
--
-- Security fix found by probing the bridge with an anon key.
--
-- PostgreSQL grants EXECUTE on a newly created function to PUBLIC by default.
-- Migration 035 then did:
--     grant execute on function ... to anon, authenticated;
--     revoke execute on function ... from anon;
-- but revoking from the role "anon" does not remove the grant that came from
-- PUBLIC. The result was that anon held EXECUTE on all fifteen wrappers,
-- including public.place_order.
--
-- Nothing was actually exploitable, and that was luck rather than design:
--   * the wrappers are SECURITY INVOKER, so calling one as anon executes as
--     anon, and the wrapped orders.place_order requires an EXECUTE grant that
--     anon never received, so the call died with 42501 inside.
--   * public.mark_notifications_read did answer 200 with zero rows, because an
--     empty uuid[] matches nothing and auth.uid() is NULL without a session.
--
-- A wrapper that is only stopped by the function behind it is one dropped
-- grant away from being exposed. Fix it properly: remove the PUBLIC grant,
-- then hand privileges back explicitly.
--
-- Reads stay open to anon so the menu renders before sign-in. Everything that
-- touches a cart, an order, a balance or a notification list does not.

-- 1. Remove the default PUBLIC grant from every wrapper.
revoke all on function
  public.active_branches(),
  public.search_products(text, uuid, uuid, numeric, numeric, text, integer, integer),
  public.get_best_sellers(uuid, interval, integer),
  public.get_featured(uuid, integer),
  public.resolve_effective_price(uuid, uuid, uuid[]),
  public.get_or_create_cart(uuid),
  public.upsert_cart_item(uuid, uuid, integer, text, uuid[]),
  public.remove_cart_item(uuid),
  public.get_cart_summary(uuid),
  public.place_order(uuid, text, text, uuid, text, text),
  public.cancel_order(uuid, text),
  public.update_order_status(uuid, text, text),
  public.validate_coupon(text, numeric, uuid),
  public.redeem_reward(uuid, uuid),
  public.mark_notifications_read(uuid[])
  from public;

-- 2. Public catalogue: anon and signed-in users both.
grant execute on function
  public.active_branches(),
  public.search_products(text, uuid, uuid, numeric, numeric, text, integer, integer),
  public.get_best_sellers(uuid, interval, integer),
  public.get_featured(uuid, integer),
  public.resolve_effective_price(uuid, uuid, uuid[])
  to anon, authenticated;

-- 3. Signed-in only.
grant execute on function
  public.get_or_create_cart(uuid),
  public.upsert_cart_item(uuid, uuid, integer, text, uuid[]),
  public.remove_cart_item(uuid),
  public.get_cart_summary(uuid),
  public.place_order(uuid, text, text, uuid, text, text),
  public.cancel_order(uuid, text),
  public.update_order_status(uuid, text, text),
  public.validate_coupon(text, numeric, uuid),
  public.redeem_reward(uuid, uuid),
  public.mark_notifications_read(uuid[])
  to authenticated;

-- 4. Belt and braces: name anon explicitly as well.
revoke execute on function
  public.get_or_create_cart(uuid),
  public.upsert_cart_item(uuid, uuid, integer, text, uuid[]),
  public.remove_cart_item(uuid),
  public.get_cart_summary(uuid),
  public.place_order(uuid, text, text, uuid, text, text),
  public.cancel_order(uuid, text),
  public.update_order_status(uuid, text, text),
  public.validate_coupon(text, numeric, uuid),
  public.redeem_reward(uuid, uuid),
  public.mark_notifications_read(uuid[])
  from anon;

notify pgrst, 'reload config';
notify pgrst, 'reload schema';