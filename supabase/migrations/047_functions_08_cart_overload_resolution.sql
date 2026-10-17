-- 047_functions_08_cart_overload_resolution.sql
--
-- Resolves the `upsert_cart_item` overload ambiguity.
--
-- Evidence (reproduced on Postgres 17 with migrations 001..046 applied):
--   * `orders.upsert_cart_item` and `public.upsert_cart_item` each exist twice:
--     a 5-argument version (029 / 035) and a 6-argument version whose
--     `p_bundle_id` has a DEFAULT (039 / 045).
--   * Because the 6-argument version is callable with five arguments (its last
--     parameter is defaulted), PostgreSQL cannot choose between the two
--     candidates. A five-argument call fails with:
--         ERROR 42725: function orders.upsert_cart_item(uuid, uuid, integer, text, uuid[]) is not unique
--     even when every argument is explicitly typed.
--   * PostgREST resolves RPCs by parameter names before reaching PostgreSQL, so
--     a normal five-key cart request has the same two matching candidates and
--     is equally unusable (PGRST203).
--
-- The 5-argument overload therefore carries no usable behaviour to preserve:
-- it can never be selected. The 6-argument version with `p_bundle_id default
-- null` is a strict functional superset (it is the one the app already reaches
-- when it sends a bundle id), so it becomes the single cart-add entry point.
--
-- This migration only removes the ambiguous signatures. The surviving
-- 6-argument function is the validated one created by
-- 046_functions_07_option_validation.sql, so every reachable path now runs the
-- same central verifier (`catalog.validate_product_option_selection`).

drop function if exists public.upsert_cart_item(
  uuid, uuid, integer, text, uuid[]);

drop function if exists orders.upsert_cart_item(
  uuid, uuid, integer, text, uuid[]);

-- Re-assert the grants on the surviving 6-argument functions. Dropping the
-- 5-argument bridges cannot leave an unauthenticated entry point, but state it
-- explicitly so the security posture is inspectable in this file.
revoke all on function
  orders.upsert_cart_item(uuid, uuid, integer, text, uuid[], uuid),
  public.upsert_cart_item(uuid, uuid, integer, text, uuid[], uuid)
  from public;

revoke execute on function
  public.upsert_cart_item(uuid, uuid, integer, text, uuid[], uuid)
  from anon;

grant execute on function
  orders.upsert_cart_item(uuid, uuid, integer, text, uuid[], uuid),
  public.upsert_cart_item(uuid, uuid, integer, text, uuid[], uuid)
  to authenticated;

notify pgrst, 'reload config';
notify pgrst, 'reload schema';
