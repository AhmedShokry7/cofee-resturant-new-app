-- 199_loyalty_plan_reward_entry_point.sql
--
-- Closes decision D4 of supabase/proposals/196_body_drift_owner_decisions.PROPOSED.sql,
-- with the opposite choice from the one recommended there, because that
-- recommendation rested on a false premise.
--
-- D4 says subscriptions.subscribe, subscriptions.renew, public.subscribe_to_plan
-- and public.renew_subscription are in the chain but missing from the live
-- project, and recommends replaying 074 so a rebuilt database matches. It does
-- not need to: 075_subscriptions_order_payment_hardening.sql ends with
--
--     -- Remove the previous unsafe direct-activation entry points.
--     drop function if exists public.subscribe_to_plan(uuid, text, text);
--     drop function if exists public.renew_subscription(uuid, text, text);
--     drop function if exists subscriptions.subscribe(uuid, text, text);
--     drop function if exists subscriptions.renew(uuid, text, text);
--
-- so the chain's LAST word on all four is "they do not exist". Live and chain
-- agree, the ledger is right, and there is no drift to record. Replaying 074
-- would reopen the exact hole 075 closed: a customer-facing RPC that activates a
-- paid subscription cycle from a free-text payment reference, with no verified
-- payments.payment_transactions row behind it. 075's replacement path,
-- activate_subscription, requires provider_reference plus verified_by_server and
-- a captured or authorized status, and refuses anything not pending_payment.
--
-- What IS broken, found by reading the caller instead of the drop list:
-- loyalty.redeem_loyalty_reward (167) still performs subscriptions.subscribe for
-- a reward whose reward_type = 'plan'. Verified on webzzasosevzymftgszn on
-- 2026-10-27: pg_get_functiondef of the deployed function still contains that
-- reference, and pg_proc holds no subscriptions.subscribe. Redeeming a plan
-- reward therefore aborts the whole transaction with
--
--     42883  function subscriptions.subscribe(uuid, text, text) does not exist
--
-- — the customer keeps their points (the deduction rolls back with the grant)
-- and can never redeem that reward. It stayed invisible because the live
-- catalogue holds no active plan reward:
--
--     select count(*) from loyalty.loyalty_rewards
--      where reward_type = 'plan' and is_active        -- 0
--
-- The fix is not to reopen the entry point but to give the reward path the
-- server-side grant it was reaching for. A reward is not a purchase, so there is
-- no payment to verify; that is precisely why the new helper is not client
-- callable at all. It is revoked from anon and authenticated, and the only
-- caller is loyalty.redeem_loyalty_reward, which is SECURITY DEFINER and has
-- already checked that the caller owns the points it is spending.
--
-- grant_plan_cycle follows 075's activation semantics, not 074's: the plan must
-- be active and for sale, the grant is idempotent by key, carryover subtracts
-- cups_reserved (a column 074 predates), and the row is written as the same
-- 'activated' event the paid path writes, with its source recorded.

-- ---------------------------------------------------------------------------
-- 1. The server-side cycle grant.
-- ---------------------------------------------------------------------------
create or replace function subscriptions.grant_plan_cycle(
  p_user_id uuid,
  p_plan_id uuid,
  p_source_reference text,
  p_idempotency_key text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_plan     subscriptions.plans%rowtype;
  v_prev     subscriptions.subscriptions%rowtype;
  v_existing uuid;
  v_unused   integer;
  v_carry    integer := 0;
  v_start    timestamptz := now();
  v_end      timestamptz;
  v_new      uuid;
begin
  if p_user_id is null then
    raise exception 'a user is required' using errcode = '23514';
  end if;
  if coalesce(btrim(p_idempotency_key), '') = '' then
    raise exception 'idempotency key required' using errcode = '23514';
  end if;

  -- A retry of the same grant returns the cycle it already created.
  select id into v_existing
    from subscriptions.subscriptions
   where idempotency_key = p_idempotency_key;
  if found then
    return v_existing;
  end if;

  select * into v_plan
    from subscriptions.plans
   where id = p_plan_id and is_active and is_for_sale
   for update;
  if not found then
    raise exception 'plan not available' using errcode = 'P0002';
  end if;

  -- Carryover, measured the way activate_subscription measures it: cups already
  -- reserved by open orders are not spare cups, and only a cycle that has not
  -- given its balance back yet may give it here.
  select * into v_prev
    from subscriptions.subscriptions
   where user_id = p_user_id
     and rollover_applied = false
     and status in ('active', 'expired')
   order by ends_at desc nulls last
   limit 1
   for update;
  if found then
    v_unused := greatest(v_prev.cups_entitled + v_prev.cups_carried_over
                           - v_prev.cups_used - v_prev.cups_reserved, 0);
    v_carry := least(v_unused, v_plan.rollover_cap_cups);
    update subscriptions.subscriptions
       set status = 'expired', rollover_applied = true
     where id = v_prev.id;
  end if;

  v_end := v_start + (v_plan.duration_days || ' days')::interval;

  insert into subscriptions.subscriptions
    (user_id, plan_id, status, starts_at, ends_at, cups_entitled, cups_used,
     cups_carried_over, cups_reserved, bonus_balance, bonus_expires_at,
     auto_renew, payment_reference, idempotency_key, rollover_applied)
  values
    (p_user_id, v_plan.id, 'active', v_start, v_end, v_plan.cups_per_cycle, 0,
     v_carry, 0,
     case when v_plan.bonus_type = 'none' then 0 else v_plan.bonus_value end,
     case when v_plan.bonus_expires_with_cycle then v_end else null end,
     v_plan.renewal_policy = 'auto' and v_plan.auto_renew_supported,
     p_source_reference, p_idempotency_key, true)
  returning id into v_new;

  insert into subscriptions.subscription_events
    (subscription_id, user_id, event_type, payload)
  values
    (v_new, p_user_id, 'activated',
     jsonb_build_object('plan', v_plan.id, 'carry', v_carry,
                        'source', p_source_reference));

  return v_new;
end;
$fn$;

comment on function subscriptions.grant_plan_cycle(uuid, uuid, text, text) is
  'Server-side grant of one subscription cycle for something the customer has '
  'already paid for in another currency, such as a loyalty reward. Not callable '
  'by a client: there is no payment transaction to verify, so only definer code '
  'that has checked its own entitlement may reach it.';

revoke all on function subscriptions.grant_plan_cycle(uuid, uuid, text, text)
  from public, anon, authenticated;
grant execute on function subscriptions.grant_plan_cycle(uuid, uuid, text, text)
  to service_role;


-- ---------------------------------------------------------------------------
-- 2. Redemption, unchanged from 167 except the plan branch, which now calls the
--    grant above instead of the entry point 075 removed.
-- ---------------------------------------------------------------------------
create or replace function loyalty.redeem_loyalty_reward(
  p_reward_id uuid,
  p_branch_id uuid
)
returns integer
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_uid       uuid := auth.uid();
  v_reward    loyalty.loyalty_rewards%rowtype;
  v_balance   integer;
  v_remain    integer;
  v_note      text;
  v_currency  text;
  v_order_id  uuid;
  v_number    text;
  v_line      record;
  v_stock     integer;
  v_allow_neg boolean;
begin
  if v_uid is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  select * into v_reward
    from loyalty.loyalty_rewards r
   where r.id = p_reward_id and r.is_active
   for update;

  if not found then
    raise exception 'no active reward' using errcode = 'P0002';
  end if;

  if v_reward.stock_available is not null and v_reward.stock_available <= 0 then
    raise exception 'reward is out of stock' using errcode = '23514';
  end if;

  select coalesce(points_balance, 0) into v_balance
    from loyalty.loyalty_accounts where user_id = v_uid;
  v_balance := coalesce(v_balance, 0);

  if v_balance < v_reward.points_cost then
    raise exception 'not enough points: have %, need %', v_balance, v_reward.points_cost
      using errcode = '23514';
  end if;

  if v_reward.reward_type in ('product', 'bundle') then
    if p_branch_id is null or not exists (
      select 1 from core.branches b
       where b.id = p_branch_id and b.is_active
    ) then
      raise exception 'an active branch is required for this reward'
        using errcode = '23514';
    end if;
  end if;

  if v_reward.reward_type = 'product' then
    select coalesce(nullif(btrim(p.name_ar), ''), nullif(btrim(p.name_en), ''), p.id::text)
      into v_note
      from catalog.products p
     where p.id = v_reward.product_id
       and p.is_active
       and p.archived_at is null;

    if not found then
      raise exception 'reward product is not available' using errcode = 'P0002';
    end if;

    if not exists (
      select 1
        from catalog.resolve_effective_price(
               p_branch_id, v_reward.product_id, '{}'::uuid[]) r
       where r.is_available
    ) then
      raise exception 'reward product is not available at this branch'
        using errcode = 'P0002';
    end if;
  elsif v_reward.reward_type = 'bundle' then
    select coalesce(nullif(btrim(b.name_ar), ''), nullif(btrim(b.name_en), ''), b.id::text)
      into v_note
      from catalog.bundles b
     where b.id = v_reward.bundle_id
       and b.is_active
       and (b.starts_at is null or now() >= b.starts_at)
       and (b.ends_at is null or now() < b.ends_at)
       and b.bundle_price is not null
       and b.bundle_price > 0;

    if not found or not exists (
      select 1 from catalog.bundle_items bi where bi.bundle_id = v_reward.bundle_id
    ) then
      raise exception 'reward bundle is not available' using errcode = 'P0002';
    end if;

    if exists (
      select 1
        from catalog.bundle_items bi
       where bi.bundle_id = v_reward.bundle_id
         and not exists (
           select 1
             from catalog.resolve_effective_price(
                    p_branch_id, bi.product_id, '{}'::uuid[]) r
            where r.is_available
         )
    ) then
      raise exception 'a reward bundle component is not available at this branch'
        using errcode = 'P0002';
    end if;
  else
    select coalesce(nullif(btrim(pl.name_ar), ''), nullif(btrim(pl.name_en), ''), pl.id::text)
      into v_note
      from subscriptions.plans pl
     where pl.id = v_reward.plan_id
       and pl.is_active
       and pl.is_for_sale;

    if not found then
      raise exception 'reward plan is not available' using errcode = 'P0002';
    end if;
  end if;

  perform loyalty.apply_points(
    v_uid,
    -v_reward.points_cost,
    'redeem_reward',
    'reward',
    v_reward.id,
    v_note
  );

  if v_reward.reward_type = 'plan' then
    -- 167 wrote subscriptions.subscribe here. 075 removed that entry point, so
    -- the call has failed with 42883 ever since; the reward is a grant, not a
    -- self-service activation, so it goes to the definer-only helper instead.
    perform subscriptions.grant_plan_cycle(
      v_uid,
      v_reward.plan_id,
      'loyalty_reward:' || v_reward.id::text,
      'loyalty_reward:' || v_reward.id::text || ':'
        || extensions.gen_random_uuid()::text
    );
  else
    select b.currency_code into v_currency
      from core.brands b
     limit 1;
    v_currency := coalesce(v_currency, 'SAR');

    v_number := 'RWD-' || to_char(now(), 'YYYY') || '-'
      || lpad(nextval('orders.order_number_seq')::text, 6, '0');

    insert into orders.orders (
      order_number, user_id, branch_id, fulfillment_type,
      status, payment_status, subtotal, discount_total, delivery_fee,
      tax_total, grand_total, currency_code, customer_note,
      loyalty_points_earned, loyalty_points_redeemed, idempotency_key
    ) values (
      v_number, v_uid, p_branch_id, 'pickup',
      'pending', 'paid', 0, 0, 0,
      0, 0, v_currency, 'Loyalty reward',
      0, v_reward.points_cost,
      'loyalty_reward:' || v_reward.id::text || ':'
        || extensions.gen_random_uuid()::text
    ) returning id into v_order_id;

    if v_reward.reward_type = 'product' then
      insert into orders.order_items (
        order_id, product_id, product_name_ar, product_name_en,
        sku_snapshot, image_snapshot, unit_price, quantity, line_total, note
      )
      select v_order_id, p.id, p.name_ar, p.name_en,
             p.sku, p.image_url, 0, 1, 0, 'Loyalty reward: ' || v_note
        from catalog.products p
       where p.id = v_reward.product_id;
    else
      insert into orders.order_items (
        order_id, product_id, product_name_ar, product_name_en,
        sku_snapshot, image_snapshot, unit_price, quantity, line_total, note
      )
      select v_order_id, p.id, p.name_ar, p.name_en,
             p.sku, p.image_url, 0, bi.quantity, 0,
             'Loyalty reward: ' || v_note
        from catalog.bundle_items bi
        join catalog.products p on p.id = bi.product_id
       where bi.bundle_id = v_reward.bundle_id
       order by bi.sort_order, bi.product_id;
    end if;

    for v_line in
      select oi.product_id, oi.quantity
        from orders.order_items oi
       where oi.order_id = v_order_id
    loop
      select bs.quantity_on_hand, bs.allow_negative
        into v_stock, v_allow_neg
        from inventory.branch_stock bs
       where bs.branch_id = p_branch_id
         and bs.product_id = v_line.product_id
         and bs.variant_key = '00000000-0000-0000-0000-000000000000'::uuid
         for update;

      if found and not coalesce(v_allow_neg, false)
         and coalesce(v_stock, 0) < v_line.quantity then
        raise exception 'insufficient stock for product %', v_line.product_id
          using errcode = '23514';
      end if;

      if found then
        update inventory.branch_stock
           set quantity_on_hand = quantity_on_hand - v_line.quantity,
               updated_at = now()
         where branch_id = p_branch_id
           and product_id = v_line.product_id
           and variant_key = '00000000-0000-0000-0000-000000000000'::uuid;

        insert into inventory.stock_movements (
          branch_id, product_id, variant_key, quantity_delta, reason,
          reference_type, reference_id, actor_user_id, note
        ) values (
          p_branch_id, v_line.product_id,
          '00000000-0000-0000-0000-000000000000'::uuid,
          -v_line.quantity, 'sale', 'order', v_order_id, v_uid,
          'loyalty reward'
        );
      end if;
    end loop;

    insert into orders.order_status_history
      (order_id, from_status, to_status, changed_by, note)
    values
      (v_order_id, null, 'pending', v_uid, 'loyalty reward redeemed');

    insert into orders.order_events (order_id, event_type, payload)
    values (v_order_id, 'loyalty.reward_redeemed', jsonb_build_object(
      'reward_id', v_reward.id,
      'reward_type', v_reward.reward_type,
      'points', v_reward.points_cost,
      'branch', p_branch_id
    ));
  end if;

  if v_reward.stock_available is not null then
    v_remain := v_reward.stock_available - 1;
    update loyalty.loyalty_rewards
       set stock_available = v_remain
     where id = v_reward.id;
  end if;

  return v_balance - v_reward.points_cost;
end;
$fn$;

comment on function loyalty.redeem_loyalty_reward is
  'Spend points on a reward and deliver it atomically: a free pickup order for products and bundles, or a new subscription cycle for plans.';

revoke all on function loyalty.redeem_loyalty_reward(uuid, uuid) from public, anon;
grant execute on function loyalty.redeem_loyalty_reward(uuid, uuid) to authenticated;

notify pgrst, 'reload schema';
