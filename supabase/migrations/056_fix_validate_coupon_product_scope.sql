-- 056_fix_validate_coupon_product_scope.sql
--
-- Fix (F3): marketing.coupons.applies_to allows 'category' and 'product', but
-- marketing.validate_coupon only ever handled 'category'. A 'product' coupon
-- was therefore never checked against the cart and its discount was applied to
-- the WHOLE subtotal, so any product-scoped code behaved like an 'all' coupon.
--
-- There was also no linkage table for product scope (only
-- marketing.coupons_categories existed), so 'product' was impossible to define.
--
-- Fix:
--   1. Add marketing.coupons_products, mirroring marketing.coupons_categories.
--   2. In validate_coupon, require the cart to contain an eligible product for
--      'product' coupons, and compute the discount on the eligible products'
--      subtotal only.
--
-- Scope note: 'all' and 'category' coupons keep their existing behaviour
-- (discount on the full subtotal). Only the previously-broken 'product' scope
-- is changed, as requested. Category-scope discounting is left to a separate
-- business decision.

-- ---------------------------------------------------------------------------
-- 1. Product scope linkage table, mirroring marketing.coupons_categories.
-- ---------------------------------------------------------------------------
create table if not exists marketing.coupons_products (
  coupon_id  uuid not null references marketing.coupons(id) on delete cascade,
  product_id uuid not null references catalog.products(id) on delete cascade,
  primary key (coupon_id, product_id)
);

comment on table marketing.coupons_products is
  'Restricts a product-scoped coupon to specific products.';

alter table marketing.coupons_products enable row level security;

-- Same policy shape as marketing.coupons_categories (022/030): public read,
-- settings.write-gated writes.
drop policy if exists coupons_products_public_read on marketing.coupons_products;
create policy coupons_products_public_read on marketing.coupons_products
  for select to anon, authenticated
  using (true);

drop policy if exists coupons_products_admin_write on marketing.coupons_products;
create policy coupons_products_admin_write on marketing.coupons_products
  for all to authenticated
  using (identity.has_permission('settings.write'))
  with check (identity.has_permission('settings.write'));

-- Least-privilege grants: everyone may read the mapping, only staff may write
-- it (RLS still gates the rows). validate_coupon is SECURITY DEFINER so it does
-- not depend on these grants.
grant select on marketing.coupons_products to anon, authenticated;
grant insert, update, delete on marketing.coupons_products to authenticated;

-- ---------------------------------------------------------------------------
-- 2. Product-aware validate_coupon. Signature and result columns unchanged.
-- ---------------------------------------------------------------------------
create or replace function marketing.validate_coupon(
  p_code       text,
  p_subtotal   numeric,
  p_branch_id  uuid default null
)
returns table (
  coupon_id    uuid,
  code         text,
  discount     numeric,
  message      text
)
language plpgsql
stable
security definer
set search_path = ''
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
    return query select null::uuid, upper(coalesce(p_code,'')), 0::numeric, 'code not valid';
    return;
  end if;

  if (v_c.starts_at is not null and v_c.starts_at > now())
     or (v_c.ends_at is not null and v_c.ends_at < now()) then
    return query select v_c.id, v_c.code, 0::numeric, 'code expired';
    return;
  end if;

  if p_subtotal < v_c.min_order_amount then
    return query select v_c.id, v_c.code, 0::numeric, 'minimum order not reached';
    return;
  end if;

  if v_c.usage_limit is not null then
    select count(*) into v_count from marketing.coupon_redemptions r where r.coupon_id = v_c.id;
    if v_count >= v_c.usage_limit then
      return query select v_c.id, v_c.code, 0::numeric, 'code fully used';
      return;
    end if;
  end if;

  if auth.uid() is not null then
    select count(*) into v_count
      from marketing.coupon_redemptions r
     where r.coupon_id = v_c.id and r.user_id = auth.uid();
    if v_count >= v_c.per_user_limit then
      return query select v_c.id, v_c.code, 0::numeric, 'you already used this code';
      return;
    end if;
  end if;

  if v_c.applies_to = 'category' then
    if not exists (
      select 1 from marketing.coupons_categories cc
       where cc.coupon_id = v_c.id
         and exists (
           select 1 from catalog.categories cat
           join catalog.products pr on pr.category_id = cat.id
           join orders.cart_items ci on ci.product_id = pr.id
           join orders.carts ca on ca.id = ci.cart_id
           where ca.user_id = auth.uid()
             and ca.status = 'active'
             and ca.branch_id = p_branch_id
             and cat.id = cc.category_id
         )
    ) then
      return query select v_c.id, v_c.code, 0::numeric, 'code does not apply to your items';
      return;
    end if;
  end if;

  -- F3: product scope. Require an eligible product in the cart and base the
  -- discount on that product's lines only.
  if v_c.applies_to = 'product' then
    select coalesce(sum(ci.line_total), 0)
      into v_eligible
      from orders.cart_items ci
      join orders.carts ca on ca.id = ci.cart_id
     where ca.user_id = auth.uid()
       and ca.status = 'active'
       and (p_branch_id is null or ca.branch_id = p_branch_id)
       and exists (
         select 1 from marketing.coupons_products cp
          where cp.coupon_id = v_c.id
            and cp.product_id = ci.product_id
       );
    if v_eligible <= 0 then
      return query select v_c.id, v_c.code, 0::numeric, 'code does not apply to your items';
      return;
    end if;
  end if;

  v_base := case when v_c.applies_to = 'product' then v_eligible else p_subtotal end;

  if v_c.discount_type = 'percentage' then
    v_amount := round(v_base * v_c.discount_value / 100, 2);
    if v_c.max_discount is not null then
      v_amount := least(v_amount, v_c.max_discount);
    end if;
  else
    v_amount := least(v_c.discount_value, v_base);
  end if;

  return query select v_c.id, v_c.code, v_amount, 'applied';
end;
$fn$;

comment on function marketing.validate_coupon is
  'Server-side coupon check: window, minimum spend, global limit, per-user limit, scope. For product-scoped coupons the discount is computed on the eligible products'' subtotal. Returns 0 if unusable.';

notify pgrst, 'reload schema';