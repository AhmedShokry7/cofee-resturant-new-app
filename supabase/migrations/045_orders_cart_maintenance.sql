-- 045_orders_cart_maintenance.sql
--
-- Repairs the client-reachable cart surface:
--   1. `orders.remove_all_cart_items()` never existed, so the app's clear-cart
--      call had no function to reach. It deletes only the caller's own active
--      cart lines (ownership proved through `orders.carts.user_id`).
--   2. `public.upsert_cart_item()` only exposed the 5-parameter overload, so
--      bundle components could never reach the bundle-aware 6-parameter
--      implementation. The 6-parameter bridge is added alongside it.
--   3. New function signatures carry PostgreSQL's default PUBLIC execute
--      grant (see 036 for why that is dangerous). It is revoked here and the
--      wrappers are handed to `authenticated` only, mirroring the existing
--      cart RPC grants.

-- ---------------------------------------------------------------------------
-- 1. Clear one customer's active cart lines.
-- ---------------------------------------------------------------------------
create or replace function orders.remove_all_cart_items(p_cart_id uuid)
returns integer
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_count integer;
begin
  if auth.uid() is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  delete from orders.cart_items ci
   using orders.carts c
   where ci.cart_id = p_cart_id
     and c.id = ci.cart_id
     and c.user_id = auth.uid()
     and c.status = 'active';

  get diagnostics v_count = row_count;
  return v_count;
end;
$fn$;

comment on function orders.remove_all_cart_items(uuid) is
  'Empties the caller''s own active cart. Ownership is proved through the cart row; a foreign cart id deletes nothing.';

-- ---------------------------------------------------------------------------
-- 2. Public bridges (PostgREST serves only `public` on this project).
-- ---------------------------------------------------------------------------
create or replace function public.remove_all_cart_items(p_cart_id uuid)
returns integer
language sql
security invoker
set search_path = ''
as $fn$
  select orders.remove_all_cart_items(p_cart_id);
$fn$;

create or replace function public.upsert_cart_item(
  p_branch_id        uuid,
  p_product_id       uuid,
  p_quantity         integer default 1,
  p_note             text default '',
  p_option_value_ids uuid[] default '{}',
  p_bundle_id        uuid default null
)
returns table (cart_item_id uuid, unit_price numeric, line_total numeric, item_count integer)
language sql
security invoker
set search_path = ''
as $fn$
  select * from orders.upsert_cart_item(
    p_branch_id, p_product_id, p_quantity, p_note, p_option_value_ids,
    p_bundle_id);
$fn$;

-- ---------------------------------------------------------------------------
-- 3. Grants: authenticated only, never anon, never PUBLIC.
-- ---------------------------------------------------------------------------
revoke all on function
  orders.remove_all_cart_items(uuid),
  orders.upsert_cart_item(uuid, uuid, integer, text, uuid[], uuid),
  public.remove_all_cart_items(uuid),
  public.upsert_cart_item(uuid, uuid, integer, text, uuid[], uuid)
  from public;
grant execute on function
  orders.remove_all_cart_items(uuid),
  orders.upsert_cart_item(uuid, uuid, integer, text, uuid[], uuid),
  public.remove_all_cart_items(uuid),
  public.upsert_cart_item(uuid, uuid, integer, text, uuid[], uuid)
  to authenticated;
revoke execute on function
  public.remove_all_cart_items(uuid),
  public.upsert_cart_item(uuid, uuid, integer, text, uuid[], uuid)
  from anon;

notify pgrst, 'reload config';
notify pgrst, 'reload schema';
