-- 026_functions_04_marketing_loyalty_inventory.sql
-- Coupon validation, loyalty redemption and manual stock adjustment.

-- ---------------------------------------------------------------------------
-- Validate a coupon and return the discount it grants.
-- Returns 0 rather than raising when a coupon is simply unusable, so the
-- caller can show a message. Raises only on a programming error.
--
-- Replaces CheckoutCubit.couponPercent() (checkout_cubit.dart:66-71), which
-- scraped the percentage out of display text with a regex.
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
  v_c      marketing.coupons%rowtype;
  v_count  integer;
  v_amount numeric;
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

  if v_c.discount_type = 'percentage' then
    v_amount := round(p_subtotal * v_c.discount_value / 100, 2);
    if v_c.max_discount is not null then
      v_amount := least(v_amount, v_c.max_discount);
    end if;
  else
    v_amount := least(v_c.discount_value, p_subtotal);
  end if;

  return query select v_c.id, v_c.code, v_amount, 'applied';
end;
$fn$;

comment on function marketing.validate_coupon is
  'Server-side coupon check: window, minimum spend, global limit, per-user limit, scope. Returns 0 if unusable.';

-- ---------------------------------------------------------------------------
-- Redeem a reward: deduct points through the ledger and add to the cart.
-- Atomic, so a failure part-way cannot leave points spent with nothing added.
-- ---------------------------------------------------------------------------
create or replace function loyalty.redeem_reward(
  p_product_id uuid,
  p_branch_id  uuid
)
returns integer
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_uid     uuid := auth.uid();
  v_reward  loyalty.loyalty_rewards%rowtype;
  v_balance integer;
  v_remain  integer;
begin
  if v_uid is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  select * into v_reward
    from loyalty.loyalty_rewards r
   where r.product_id = p_product_id and r.is_active
   for update;

  if not found then
    raise exception 'no active reward for this product' using errcode = 'P0002';
  end if;

  select coalesce(points_balance, 0) into v_balance
    from loyalty.loyalty_accounts where user_id = v_uid;
  v_balance := coalesce(v_balance, 0);

  if v_balance < v_reward.points_cost then
    raise exception 'not enough points: have %, need %', v_balance, v_reward.points_cost
      using errcode = '23514';
  end if;

  perform loyalty.apply_points(v_uid, -v_reward.points_cost, 'redeem_reward', null, null,
    'redeemed ' || p_product_id::text);

  if v_reward.stock_available is not null then
    v_remain := v_reward.stock_available - 1;
    update loyalty.loyalty_rewards
       set stock_available = v_remain
     where id = v_reward.id;
  end if;

  perform orders.upsert_cart_item(p_branch_id, p_product_id, 1, 'Loyalty reward', '{}');

  return v_balance - v_reward.points_cost;
end;
$fn$;

comment on function loyalty.redeem_reward is
  'Spend points on a reward and add it to the cart in one atomic step.';

-- ---------------------------------------------------------------------------
-- Manual stock adjustment. Always writes a movement row.
-- ---------------------------------------------------------------------------
create or replace function inventory.adjust_stock(
  p_branch_id  uuid,
  p_product_id uuid,
  p_delta      integer,
  p_reason     text,
  p_note       text default null,
  p_variant_key uuid default '00000000-0000-0000-0000-000000000000'::uuid
)
returns integer
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_result integer;
begin
  if not identity.has_permission('inventory.adjust') then
    raise exception 'inventory.adjust permission required' using errcode = '42501';
  end if;
  if not identity.can_manage_branch(p_branch_id) then
    raise exception 'you do not manage this branch' using errcode = '42501';
  end if;
  if p_delta = 0 then
    raise exception 'delta must not be zero' using errcode = '23514';
  end if;
  if p_reason not in ('restock','adjustment','waste','return') then
    raise exception 'reason % cannot be applied manually', p_reason using errcode = '23514';
  end if;

  insert into inventory.branch_stock
    (branch_id, product_id, variant_key, quantity_on_hand, allow_negative)
  values (p_branch_id, p_product_id, p_variant_key, greatest(p_delta, 0), p_delta < 0)
  on conflict (branch_id, product_id, variant_key) do update
    set quantity_on_hand = inventory.branch_stock.quantity_on_hand + excluded.quantity_on_hand,
        updated_at = now();

  insert into inventory.stock_movements
    (branch_id, product_id, variant_key, quantity_delta, reason,
     reference_type, actor_user_id, note)
  values (p_branch_id, p_product_id, p_variant_key, p_delta, p_reason, 'manual', auth.uid(), p_note);

  select quantity_on_hand into v_result
    from inventory.branch_stock
   where branch_id = p_branch_id and product_id = p_product_id and variant_key = p_variant_key;

  perform identity.audit('stock.adjust', 'stock', p_product_id, null,
    jsonb_build_object('branch', p_branch_id, 'delta', p_delta, 'reason', p_reason, 'result', v_result),
    p_branch_id);

  return v_result;
end;
$fn$;

comment on function inventory.adjust_stock is
  'Manual stock change with permission + branch-scope checks, and a mandatory movement row.';

-- ---------------------------------------------------------------------------
-- Customer-facing branches list (D1: the customer picks a branch).
-- ---------------------------------------------------------------------------
create or replace function core.active_branches()
returns table (
  id uuid, code text, name_ar text, name_en text,
  address text, latitude numeric, longitude numeric, phone text
)
language sql
stable
security definer
set search_path = ''
as $fn$
  select b.id, b.code, b.name_ar, b.name_en, b.address, b.latitude, b.longitude, b.phone
    from core.branches b
   where b.is_active
   order by b.name_en;
$fn$;

-- ---------------------------------------------------------------------------
-- Mark notifications read (the app had no per-notification read state).
-- ---------------------------------------------------------------------------
create or replace function engagement.mark_notifications_read(p_ids uuid[])
returns integer
language plpgsql
security definer
set search_path = ''
as $fn$
declare v_n integer;
begin
  update engagement.notifications
     set is_read = true, read_at = now()
   where id = any(p_ids)
     and user_id = auth.uid()
     and not is_read;
  get diagnostics v_n = row_count;
  return v_n;
end;
$fn$;