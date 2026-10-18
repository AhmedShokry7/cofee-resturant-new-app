-- 070_coupon_rejection_reasons.sql
--
-- A category-scoped and a product-scoped coupon both answered the identical
-- string 'code does not apply to your items'. A customer whose cart held no
-- espresso and a customer whose cart held no cold drinks were told the same
-- sentence, which explains nothing and, in an Arabic UI, arrived as raw
-- English because there was no way to say more.
--
-- The return table had no reason column, so the client could not tell the cases
-- apart even if it wanted to. It also never learned what the coupon was scoped
-- to: `public.coupons` exposes `applies_to` but nothing joined
-- coupons_categories / coupons_products, so the app could not have named the
-- qualifying items even with the reason in hand.
--
-- Three changes:
--
--   1. validate_coupon gains a `reason_code` column carrying a stable machine
--      token alongside the legacy human-readable `message`. Existing callers
--      that read `message` are unaffected; `select *` callers now see one more
--      column, which is why every call site in this repo names its columns.
--
--   2. The two scope rejections stop sharing a message and each get their own
--      code, plus codes for the branch case that previously fell through as
--      "does not apply".
--
--   3. A new read-only RPC resolves a coupon's scope to names, so the app can
--      both label the coupon on the list and name the qualifying items when it
--      refuses to apply.
--
-- The category block's branch filter also changes. It used
-- `ca.branch_id = p_branch_id`, and with a null branch id that comparison is
-- null, so the `exists` was never satisfied and a category coupon was
-- unconditionally rejected for every anonymous or branch-less caller. The
-- product block already used the null-tolerant form; the category block now
-- matches it.

-- ---------------------------------------------------------------------------
-- 1 + 2. Structured reasons
-- ---------------------------------------------------------------------------

drop function if exists marketing.validate_coupon(text, numeric, uuid);drop function if exists public.validate_coupon(text, numeric, uuid);drop function if exists public.validate_coupon_for_cart(uuid, text, jsonb);drop function if exists public.resolve_customer_cart_subtotal(uuid, jsonb);drop function if exists public.coupon_scope(text);

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
             and (p_branch_id is null or ca.branch_id = p_branch_id)
             and cat.id = cc.category_id
         )
    ) then
      return query
        select v_c.id, v_c.code, 0::numeric,
               'code does not apply to your items', 'scope_category_no_match';
      return;
    end if;
  end if;

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
      return query
        select v_c.id, v_c.code, 0::numeric,
               'code does not apply to your items', 'scope_product_no_match';
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

  return query
    select v_c.id, v_c.code, v_amount, 'applied', 'applied';
end;
$fn$;

comment on function marketing.validate_coupon(text, numeric, uuid) is
  'Validates a coupon. reason_code is a stable machine token (not_found, '
  'expired, min_order_not_met, fully_used, user_limit_reached, '
  'scope_category_no_match, scope_product_no_match, applied); message stays a '
  'human-readable legacy string. Read reason_code, never message.';

-- The cart subtotal the old wrapper computed inline, factored out so
-- validate_coupon_for_cart stays a single select and both agree.
--
-- Declared before the wrapper that calls it: Postgres validates function bodies
-- at CREATE time unless check_function_bodies is off, so a `language sql`
-- wrapper referencing a function that does not exist yet would fail here.
create or replace function public.resolve_customer_cart_subtotal(
  p_branch_id uuid,
  p_lines jsonb
)
returns table (cart_id uuid, subtotal numeric)
language plpgsql
volatile
set search_path to ''
as $fn$
declare
  v_cart_id uuid;
  v_subtotal numeric;
begin
  v_cart_id := orders.replace_customer_cart(p_branch_id, p_lines);
  select coalesce(round(sum(ci.line_total), 2), 0)
    into v_subtotal
    from orders.cart_items ci
   where ci.cart_id = v_cart_id;
  return query select v_cart_id, v_subtotal;
end;
$fn$;

revoke all on function public.resolve_customer_cart_subtotal(uuid, jsonb)
  from public, anon;
grant execute on function public.resolve_customer_cart_subtotal(uuid, jsonb)
  to authenticated, service_role;

-- The public wrapper must name the new column so it can pass it through.
create or replace function public.validate_coupon_for_cart(
  p_branch_id uuid,
  p_code text,
  p_lines jsonb
)
returns table (
  coupon_id uuid,
  code text,
  discount numeric,
  message text,
  cart_subtotal numeric,
  reason_code text
)
language sql
stable
set search_path to ''
as $fn$
  select v.coupon_id, v.code, v.discount, v.message, c.subtotal, v.reason_code
    from public.resolve_customer_cart_subtotal(p_branch_id, p_lines) c
    cross join lateral marketing.validate_coupon(p_code, c.subtotal, p_branch_id) v;
$fn$;

comment on function public.validate_coupon_for_cart(uuid, text, jsonb) is
  'Syncs the cart snapshot, prices it server-side, then validates the coupon '
  'against that exact subtotal. Returns reason_code for a precise rejection.';

-- The legacy subtotal-only bridge, kept for callers that still pass one.
create or replace function public.validate_coupon(
  p_code text,
  p_subtotal numeric,
  p_branch_id uuid default null
)
returns table (
  coupon_id uuid, code text, discount numeric, message text, reason_code text
)
language sql
stable
security invoker
set search_path to ''
as $fn$
  select * from marketing.validate_coupon(p_code, p_subtotal, p_branch_id);
$fn$;

revoke all on function public.validate_coupon(text, numeric, uuid) from public;
grant execute on function public.validate_coupon(text, numeric, uuid)
  to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 3. What is this coupon scoped to?
-- ---------------------------------------------------------------------------

-- One row per qualifying category or product, in both languages.
--
-- Returns no rows for an 'all' coupon, which the app reads as "no scope".
create or replace function public.coupon_scope(p_code text)
returns table (
  coupon_id  uuid,
  applies_to text,
  scope_kind text,
  scope_id   uuid,
  name_ar    text,
  name_en    text
)
language sql
stable
security definer
set search_path to ''
as $fn$
  with target as (
    select c.id, c.applies_to
      from marketing.coupons c
     where c.code = upper(btrim(coalesce(p_code, '')))
     limit 1
  )
  select t.id, t.applies_to, 'category'::text, cat.id, cat.name_ar, cat.name_en
    from target t
    join marketing.coupons_categories cc on cc.coupon_id = t.id
    join catalog.categories cat on cat.id = cc.category_id
  union all
  select t.id, t.applies_to, 'product'::text, pr.id, pr.name_ar, pr.name_en
    from target t
    join marketing.coupons_products cp on cp.coupon_id = t.id
    join catalog.products pr on pr.id = cp.product_id
   order by 4;
$fn$;

comment on function public.coupon_scope(text) is
  'The categories or products a coupon is limited to, for display and for '
  'explaining a rejection. Empty result means the coupon has no scope (applies '
  'to everything) or does not exist.';

revoke all on function public.coupon_scope(text) from public;
grant execute on function public.coupon_scope(text)
  to anon, authenticated, service_role;

notify pgrst, 'reload schema';