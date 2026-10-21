-- 093_restore_dropped_coupon_helpers.sql
--
-- Fixes a production-breaking defect introduced by 072.
--
-- Verified defect:
--   072_coupon_discount_breakdown.sql creates three helper functions
--     marketing.coupon_eligible_lines(uuid, uuid)
--     marketing.allocate_coupon_discount(uuid, uuid, numeric)
--     public.coupon_line_breakdown(uuid, text, jsonb)
--   and then DROPS all three on line 233 (together with
--   orders.place_order_impl) so that the new place_order_impl could be
--   recreated with a changed return type. The three helpers are never
--   recreated afterwards in that file.
--
--   The result on the live database:
--     * marketing.coupon_eligible_lines      MISSING
--     * marketing.allocate_coupon_discount   MISSING
--     * public.coupon_line_breakdown         MISSING
--     * orders.place_order_impl              PRESENT and calls
--       marketing.allocate_coupon_discount(...)
--
--   Every customer order therefore failed with:
--     ERROR: function marketing.allocate_coupon_discount(uuid, uuid, numeric)
--            does not exist
--   raised while writing orders.order_items, i.e. the checkout flow was
--   completely broken for all customers.
--
-- This migration recreates the three helpers verbatim from 072, after
-- place_order_impl, so the dependency resolves. The definitions are
-- unchanged on purpose: the business rules they encode (which lines a
-- scoped coupon may discount, and how the approved amount is split across
-- those lines) are the ones 071/072 were written to enforce.
--
-- order matters: public.coupon_line_breakdown is a SQL function, so its body
-- is parsed at creation time and needs the two marketing helpers to exist
-- first. orders.place_order_impl is PL/pgSQL, so it resolves
-- marketing.allocate_coupon_discount at run time and is not affected by
-- the order.

-- ---------------------------------------------------------------------------
-- Which lines a coupon can discount
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
set search_path to ''
as $fn$
  select ci.id, ci.product_id, ci.line_total
    from marketing.coupons c
    join orders.cart_items ci on ci.cart_id = p_cart_id
   where c.id = p_coupon_id
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
  'The cart lines a coupon may discount. One definition, used by the '
  'allocator, the client-facing breakdown and place_order.';

-- ---------------------------------------------------------------------------
-- Allocation
-- ---------------------------------------------------------------------------
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
set search_path to ''
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
  'Splits an approved discount across the eligible cart lines. Cumulative '
  'rounding, so the parts sum to exactly p_amount and no share is negative. '
  'Returns no rows when the amount is zero or nothing is eligible.';

-- ---------------------------------------------------------------------------
-- Client-facing breakdown
-- ---------------------------------------------------------------------------
create or replace function public.coupon_line_breakdown(
  p_branch_id uuid,
  p_code text,
  p_lines jsonb
)
returns table (
  cart_item_id   uuid,
  product_id     uuid,
  product_name_ar text,
  product_name_en text,
  line_total     numeric,
  eligible       boolean,
  discount       numeric
)
language sql
stable
set search_path to ''
as $fn$
  with cart as (
    select orders.replace_customer_cart(p_branch_id, p_lines) as cart_id
  ),
  resolved as (
    select c.cart_id, v.coupon_id, v.discount
      from cart c
      cross join lateral marketing.validate_coupon(
        p_code,
        (select coalesce(round(sum(ci.line_total), 2), 0)
           from orders.cart_items ci where ci.cart_id = c.cart_id),
        p_branch_id
      ) v
  ),
  eligible as (
    select el.cart_item_id, el.product_id, el.line_total
      from resolved r
      cross join lateral marketing.coupon_eligible_lines(r.coupon_id, r.cart_id) el
  ),
  shares as (
    select a.cart_item_id, a.discount
      from resolved r
      cross join lateral marketing.allocate_coupon_discount(
        r.coupon_id, r.cart_id, r.discount
      ) a
  )
  select ci.id, ci.product_id, p.name_ar, p.name_en, ci.line_total,
         e.cart_item_id is not null,
         coalesce(s.discount, 0)
    from cart c
    join orders.cart_items ci on ci.cart_id = c.cart_id
    left join catalog.products p on p.id = ci.product_id
    left join eligible e on e.cart_item_id = ci.id
    left join shares s on s.cart_item_id = ci.id
   order by ci.id;
$fn$;

comment on function public.coupon_line_breakdown(uuid, text, jsonb) is
  'Per-line attribution of a coupon discount for the cart screen. Every line is '
  'returned; eligible marks the ones a scoped coupon actually covers.';

revoke all on function public.coupon_line_breakdown(uuid, text, jsonb) from public;
grant execute on function public.coupon_line_breakdown(uuid, text, jsonb)
  to anon, authenticated, service_role;

notify pgrst, 'reload schema';
