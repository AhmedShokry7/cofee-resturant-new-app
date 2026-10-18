-- 071_category_coupon_discounts_eligible_lines_only.sql
--
-- A category-scoped coupon passed an existence check and then discounted the
-- WHOLE cart. A coupon limited to Cold drinks, applied to a cart of 12 SAR of
-- cold drinks plus 40 SAR of everything else, took 20% off all 52 SAR instead
-- of the 12 it was scoped to. The customer paid for a discount they were never
-- offered, and the shortfall was invisible: one number, no per-line breakdown.
--
-- Migration 056 fixed exactly this for the 'product' scope and deliberately
-- left category alone as "a separate business decision". This is that decision.
--
-- The change is to price scoped coupons the same way, on the eligible lines
-- only:
--
--   * v_eligible is now computed for the category scope too, not just product.
--     The category branch previously only ran an `exists`, so there was no sum
--     to use even if the base had wanted one.
--   * the two scope branches collapse into one query, because "a line is
--     eligible" is the same question with a different answer, and keeping them
--     separate is how they drifted apart in the first place.
--   * v_base becomes v_eligible for both scopes, and stays p_subtotal for 'all'.
--
-- Unchanged on purpose: min_order_amount is still measured against the whole
-- cart. "Spend 50 to use this coupon" conventionally refers to the order, not
-- to the discounted slice, and measuring it against the eligible slice would
-- reject carts that plainly meet the stated condition.
--
-- fixed_amount coupons were already capped correctly via `least(v_c.discount_value,
-- v_base)`; with v_base now smaller for a category coupon, that cap tightens on
-- its own and a fixed discount can no longer exceed the scoped items' value.

create or replace function marketing.validate_coupon(
  p_code       text,
  p_subtotal   numeric,
  p_branch_id  uuid default null
)
returns table (
  coupon_id    uuid,
  code         text,
  discount     numeric,
  message      text,
  reason_code  text
)
language plpgsql
stable
security definer
set search_path to ''
as $fn$
declare
  v_c        marketing.coupons%rowtype;
  v_count    integer;
  v_eligible numeric := 0;
  v_base     numeric;
  v_amount   numeric;
begin
  select * into v_c
    from marketing.coupons c
   where c.code = upper(btrim(coalesce(p_code, '')))
     and c.is_active
   limit 1;

  if not found then
    return query
      select null::uuid, upper(coalesce(p_code,'')), 0::numeric,
             'code not valid', 'not_found';
    return;
  end if;

  if (v_c.starts_at is not null and v_c.starts_at > now())
     or (v_c.ends_at is not null and v_c.ends_at < now()) then
    return query
      select v_c.id, v_c.code, 0::numeric, 'code expired', 'expired';
    return;
  end if;

  if p_subtotal < v_c.min_order_amount then
    return query
      select v_c.id, v_c.code, 0::numeric,
             'minimum order not reached', 'min_order_not_met';
    return;
  end if;

  if v_c.usage_limit is not null then
    select count(*) into v_count from marketing.coupon_redemptions r where r.coupon_id = v_c.id;
    if v_count >= v_c.usage_limit then
      return query
        select v_c.id, v_c.code, 0::numeric, 'code fully used', 'fully_used';
      return;
    end if;
  end if;

  if auth.uid() is not null then
    select count(*) into v_count
      from marketing.coupon_redemptions r
     where r.coupon_id = v_c.id and r.user_id = auth.uid();
    if v_count >= v_c.per_user_limit then
      return query
        select v_c.id, v_c.code, 0::numeric,
               'you already used this code', 'user_limit_reached';
      return;
    end if;
  end if;

  -- A scoped coupon is priced on the eligible lines only, and is refused when
  -- the cart holds none of them. One query answers "is this line eligible" for
  -- both scopes: matching against the coupon's own linkage table, which is the
  -- only place the scope is recorded.
  if v_c.applies_to in ('category', 'product') then
    select coalesce(sum(ci.line_total), 0)
      into v_eligible
      from orders.cart_items ci
      join orders.carts ca on ca.id = ci.cart_id
     where ca.user_id = auth.uid()
       and ca.status = 'active'
       and (p_branch_id is null or ca.branch_id = p_branch_id)
       and (
         (v_c.applies_to = 'product' and exists (
            select 1 from marketing.coupons_products cp
             where cp.coupon_id = v_c.id
               and cp.product_id = ci.product_id
         ))
         or
         (v_c.applies_to = 'category' and exists (
            select 1 from marketing.coupons_categories cc
            join catalog.categories cat on cat.id = cc.category_id
            join catalog.products pr on pr.category_id = cat.id
             where cc.coupon_id = v_c.id
               and pr.id = ci.product_id
         ))
       );
    if v_eligible <= 0 then
      return query
        select v_c.id, v_c.code, 0::numeric,
               'code does not apply to your items',
               case when v_c.applies_to = 'category'
                    then 'scope_category_no_match'
                    else 'scope_product_no_match' end;
      return;
    end if;
  end if;

  v_base := case when v_c.applies_to in ('category', 'product')
                 then v_eligible
                 else p_subtotal end;

  if v_c.discount_type = 'percentage' then
    v_amount := round(v_base * v_c.discount_value / 100, 2);
    if v_c.max_discount is not null then
      v_amount := least(v_amount, v_c.max_discount);
    end if;
  else
    -- Caps the flat discount at the eligible value, so a 20 SAR coupon scoped
    -- to cold drinks cannot discount 20 SAR out of an 8 SAR basket.
    v_amount := least(v_c.discount_value, v_base);
  end if;

  return query
    select v_c.id, v_c.code, v_amount, 'applied', 'applied';
end;
$fn$;

comment on function marketing.validate_coupon(text, numeric, uuid) is
  'Validates a coupon. A coupon scoped to categories or products discounts only '
  'the eligible cart lines, never the whole cart; min_order_amount still '
  'applies to the whole cart. reason_code is a stable machine token; message '
  'stays a human-readable legacy string. Read reason_code, never message.';

notify pgrst, 'reload schema';