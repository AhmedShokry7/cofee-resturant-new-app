-- 105_grants_hardening.sql
--
-- Close the grants that let a caller read or write more than it should, and
-- restore the grants a later migration dropped by accident.
--
-- 1. marketing.coupon_eligible_lines and marketing.allocate_coupon_discount
--    are SECURITY DEFINER helpers that take a raw cart id.  Migration 093
--    created them without a REVOKE, and migration 081 - the blanket hardening
--    that revokes EXECUTE from PUBLIC on every function of the internal
--    schemas - runs BEFORE 093, so it never saw them.  The final state was
--    therefore `EXECUTE TO PUBLIC`, which means the `anon` role could call
--    them and read the lines of any cart whose id it knew: product, quantity
--    and line total of another customer's basket.
--    The two functions are also granted to `authenticated`, because
--    `public.coupon_line_breakdown` is SECURITY INVOKER and calls them.
--    The ownership check is added to the body as well, so a caller can only
--    ever price its own cart.
--
-- 2. `public.saved_cards` lost its grant.  Migration 063 granted SELECT to
--    `authenticated`; migration 073 dropped the view and re-created it
--    without granting anything again, and a new view has no privileges of its
--    own.  The saved-card list of a signed-in customer therefore failed with
--    "permission denied for table saved_cards".
--
-- 3. `public.push_deliveries` was granted SELECT only, but the send-push Edge
--    Function writes its delivery log through it.  The insert failed with
--    "permission denied for table push_deliveries", so every push attempt was
--    lost without a trace.
--
-- 4. `public.cart_items` and `public.order_items` were granted INSERT,
--    UPDATE and DELETE to `authenticated` although their base tables have no
--    write policy for customers.  The grants widen the surface for no reason.
--
-- 5. `public.validate_coupon_for_cart` and `public.coupon_line_breakdown`
--    were executable by `anon` (no REVOKE after the CREATE).  Both fail
--    closed today, but only because an inner function is not executable for
--    `anon`: that is one dropped grant away from an open door.
--
-- Everything here is a grant change: no table, column, function body or row
-- is touched, and no production data is read or written.

begin;

-- ---------------------------------------------------------------------------
-- 1. The coupon helpers
-- ---------------------------------------------------------------------------
create or replace function marketing.coupon_eligible_lines(
  p_coupon_id uuid, p_cart_id uuid
)
returns table (
  cart_item_id uuid,
  product_id uuid,
  line_total numeric
)
language sql
stable
security definer
set search_path = ''
as $fn$
  select ci.id, ci.product_id, ci.line_total
    from marketing.coupons c
    join orders.cart_items ci on ci.cart_id = p_cart_id
    join orders.carts ca on ca.id = ci.cart_id
   where c.id = p_coupon_id
     and ca.user_id = auth.uid()
     and (
       c.applies_to = 'all'
       or (c.applies_to = 'product' and exists (
             select 1 from marketing.coupons_products cp
              where cp.coupon_id = c.id and cp.product_id = ci.product_id
       ))
       or (c.applies_to = 'category' and exists (
             select 1 from marketing.coupons_categories cc
             join catalog.categories cat on cat.id = cc.category_id
             join catalog.products pr on pr.category_id = cat.id
              where cc.coupon_id = c.id and pr.id = ci.product_id
       ))
     )
   order by ci.id;
$fn$;

comment on function marketing.coupon_eligible_lines(uuid, uuid) is
  'The cart lines a coupon may discount, for the calling customer only.';

create or replace function marketing.allocate_coupon_discount(
  p_coupon_id uuid, p_cart_id uuid, p_amount numeric
)
returns table (
  cart_item_id uuid,
  discount numeric
)
language sql
stable
security definer
set search_path = ''
as $fn$
  with base as (
    select coalesce(sum(el.line_total), 0) as total
      from marketing.coupon_eligible_lines(p_coupon_id, p_cart_id) el
  ),
  running as (
    select el.cart_item_id,
           sum(el.line_total) over (order by el.cart_item_id) as cumulative
      from marketing.coupon_eligible_lines(p_coupon_id, p_cart_id) el
  ),
  marked as (
    select r.cart_item_id,
           round(p_amount * r.cumulative / b.total, 2) as target
      from running r
      cross join base b
     where b.total > 0
  )
  select m.cart_item_id,
         round(m.target - coalesce(
           lag(m.target) over (order by m.cart_item_id), 0
         ), 2) as discount
    from marked m
   order by m.cart_item_id;
$fn$;

comment on function marketing.allocate_coupon_discount(uuid, uuid, numeric) is
  'Splits an approved discount across the eligible cart lines of the caller.';

revoke all on function marketing.coupon_eligible_lines(uuid, uuid)
  from public, anon;
revoke all on function marketing.allocate_coupon_discount(uuid, uuid, numeric)
  from public, anon;

grant execute on function marketing.coupon_eligible_lines(uuid, uuid)
  to authenticated, service_role;
grant execute on function marketing.allocate_coupon_discount(uuid, uuid, numeric)
  to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 2. The saved cards the customer may read
-- ---------------------------------------------------------------------------
grant select on public.saved_cards to authenticated;
revoke all on public.saved_cards from anon;

-- ---------------------------------------------------------------------------
-- 3. The delivery log the Edge Function writes
-- ---------------------------------------------------------------------------
do $$
begin
  if to_regclass('public.push_deliveries') is not null then
    grant select, insert, update, delete on public.push_deliveries to service_role;
    revoke all on public.push_deliveries from anon, authenticated;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 4. The cart and order bridges are read-only for customers
-- ---------------------------------------------------------------------------
revoke insert, update, delete on public.cart_items from authenticated;
revoke insert, update, delete on public.order_items from authenticated;

-- ---------------------------------------------------------------------------
-- 5. The coupon bridges are for signed-in customers only
-- ---------------------------------------------------------------------------
revoke all on function public.validate_coupon_for_cart(uuid, text, jsonb)
  from public, anon;
grant execute on function public.validate_coupon_for_cart(uuid, text, jsonb)
  to authenticated, service_role;

revoke execute on function public.coupon_line_breakdown(uuid, text, jsonb)
  from anon;

notify pgrst, 'reload schema';

commit;

-- Verification
-- ------------
-- 1) The coupon helpers are not executable by anon:
--      select case when has_function_privilege(
--                 'anon', 'marketing.coupon_eligible_lines(uuid,uuid)', 'EXECUTE')
--             then 'FAIL' else 'PASS' end;
--    Expected: PASS.
-- 2) The helpers are executable for a signed-in customer:
--      select case when has_function_privilege(
--                 'authenticated', 'marketing.allocate_coupon_discount(uuid,uuid,numeric)', 'EXECUTE')
--             then 'PASS' else 'FAIL' end;
--    Expected: PASS.
-- 3) The saved cards are readable by a customer and not by anon:
--      select case when has_table_privilege('authenticated','public.saved_cards','SELECT')
--             then 'PASS' else 'FAIL' end,
--             case when has_table_privilege('anon','public.saved_cards','SELECT')
--             then 'FAIL' else 'PASS' end;
--    Expected: PASS, PASS.
-- 4) The delivery log is writable by the service role:
--      select case when has_table_privilege('service_role','public.push_deliveries','INSERT')
--             then 'PASS' else 'FAIL' end;
--    Expected: PASS.
-- 5) The cart bridge is read-only for customers:
--      select case when has_table_privilege('authenticated','public.cart_items','INSERT')
--             then 'FAIL' else 'PASS' end;
--    Expected: PASS.
-- 6) The coupon bridges are not executable by anon:
--      select case when has_function_privilege(
--                 'anon', 'public.validate_coupon_for_cart(uuid,text,jsonb)', 'EXECUTE')
--             then 'FAIL' else 'PASS' end;
--    Expected: PASS.
--
-- Rollback
-- --------
-- begin;
-- grant select on public.saved_cards to anon;             -- not wanted
-- revoke all on function marketing.coupon_eligible_lines(uuid, uuid) from authenticated, service_role;
-- revoke all on function marketing.allocate_coupon_discount(uuid, uuid, numeric) from authenticated, service_role;
-- grant execute on function public.validate_coupon_for_cart(uuid, text, jsonb) to anon;
-- grant execute on function public.coupon_line_breakdown(uuid, text, jsonb) to anon;
-- grant insert, update, delete on public.push_deliveries to service_role;
-- commit;
-- ---------------------------------------------------------------------------
