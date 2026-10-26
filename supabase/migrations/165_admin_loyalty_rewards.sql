-- 165_admin_loyalty_rewards.sql
-- Turn the loyalty page into a real rewards catalogue:
--   * an admin picks one catalog product and sets its points cost;
--   * optional stock and an active flag control what customers can redeem;
--   * members and the points ledger are readable from the same page.
--
-- Also links a redemption to its reward in the ledger, and stops an
-- out-of-stock reward from being redeemed.

-- ---------------------------------------------------------------------------
-- 1. Let a ledger row point at a reward as well as an order.
-- ---------------------------------------------------------------------------
alter table loyalty.loyalty_transactions
  drop constraint if exists loyalty_transactions_reference_type_check;

alter table loyalty.loyalty_transactions
  add constraint loyalty_transactions_reference_type_check
  check (reference_type in ('order', 'reward'));

-- ---------------------------------------------------------------------------
-- 2. Redeem a reward: same signature, now with a stock guard and a ledger
--    reference to the reward so the admin history can name it.
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
  v_uid      uuid := auth.uid();
  v_reward   loyalty.loyalty_rewards%rowtype;
  v_balance  integer;
  v_remain   integer;
  v_note     text;
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

  select coalesce(nullif(btrim(p.name_ar), ''), nullif(btrim(p.name_en), ''), p_product_id::text)
    into v_note
    from catalog.products p
   where p.id = p_product_id;

  perform loyalty.apply_points(
    v_uid,
    -v_reward.points_cost,
    'redeem_reward',
    'reward',
    v_reward.id,
    v_note
  );

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
  'Spend points on a reward and add it to the cart in one atomic step. Refuses an out-of-stock reward.';

-- ---------------------------------------------------------------------------
-- 3. Admin reads.
-- ---------------------------------------------------------------------------
create or replace function public.admin_loyalty_overview()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_rule    jsonb;
  v_metrics jsonb;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('loyalty.read') then
    raise exception 'missing permission: loyalty.read' using errcode = '42501';
  end if;

  select jsonb_build_object(
    'id', r.id,
    'code', r.code,
    'name_ar', r.name_ar,
    'name_en', r.name_en,
    'points_per_currency_unit', r.points_per_currency_unit,
    'point_value', r.point_value,
    'is_active', r.is_active,
    'is_current', r.is_active
      and r.valid_from <= now()
      and (r.valid_to is null or r.valid_to > now()),
    'valid_from', r.valid_from,
    'valid_to', r.valid_to
  )
    into v_rule
    from loyalty.loyalty_rules r
   order by r.is_active desc, r.valid_from desc
   limit 1;

  select jsonb_build_object(
    'members', (select count(*) from loyalty.loyalty_accounts),
    'members_with_points', (
      select count(*) from loyalty.loyalty_accounts where points_balance > 0
    ),
    'points_outstanding', (
      select coalesce(sum(points_balance), 0) from loyalty.loyalty_accounts
    ),
    'points_earned', (
      select coalesce(sum(lifetime_points), 0) from loyalty.loyalty_accounts
    ),
    'points_redeemed', (
      select coalesce(sum(-points), 0)
        from loyalty.loyalty_transactions
       where reason = 'redeem_reward'
    ),
    'redemptions', (
      select count(*)
        from loyalty.loyalty_transactions
       where reason = 'redeem_reward'
    ),
    'active_rewards', (
      select count(*) from loyalty.loyalty_rewards where is_active
    ),
    'total_rewards', (select count(*) from loyalty.loyalty_rewards),
    'out_of_stock_rewards', (
      select count(*)
        from loyalty.loyalty_rewards
       where is_active and stock_available = 0
    ),
    'transactions', (select count(*) from loyalty.loyalty_transactions)
  ) into v_metrics;

  return jsonb_build_object('rule', v_rule, 'metrics', v_metrics);
end;
$fn$;

comment on function public.admin_loyalty_overview is
  'Program rule and loyalty metrics for the admin page.';

revoke all on function public.admin_loyalty_overview() from public, anon;
grant execute on function public.admin_loyalty_overview() to authenticated;

create or replace function public.admin_loyalty_rewards()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('loyalty.read') then
    raise exception 'missing permission: loyalty.read' using errcode = '42501';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', r.id,
      'product_id', r.product_id,
      'points_cost', r.points_cost,
      'stock_available', r.stock_available,
      'is_active', r.is_active,
      'product_name_ar', p.name_ar,
      'product_name_en', p.name_en,
      'sku', p.sku,
      'image_url', p.image_url,
      'base_price', p.base_price,
      'is_product_active', p.is_active,
      'is_product_archived', p.archived_at is not null,
      'category_name_ar', c.name_ar,
      'category_name_en', c.name_en,
      'redemptions_count', coalesce(stats.redemptions_count, 0),
      'last_redeemed_at', stats.last_redeemed_at,
      'created_at', r.created_at,
      'updated_at', r.updated_at
    ) order by r.is_active desc, r.points_cost, p.sort_order)
    from loyalty.loyalty_rewards r
    join catalog.products p on p.id = r.product_id
    left join catalog.categories c on c.id = p.category_id
    left join lateral (
      select count(*)::integer as redemptions_count,
             max(t.created_at) as last_redeemed_at
        from loyalty.loyalty_transactions t
       where t.reference_type = 'reward'
         and t.reference_id = r.id
    ) stats on true
  ), '[]'::jsonb);
end;
$fn$;

comment on function public.admin_loyalty_rewards is
  'Reward catalogue with product details and redemption counts.';

revoke all on function public.admin_loyalty_rewards() from public, anon;
grant execute on function public.admin_loyalty_rewards() to authenticated;

create or replace function public.admin_loyalty_product_options()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('loyalty.read') then
    raise exception 'missing permission: loyalty.read' using errcode = '42501';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', p.id,
      'name_ar', p.name_ar,
      'name_en', p.name_en,
      'sku', p.sku,
      'image_url', p.image_url,
      'base_price', p.base_price,
      'is_active', p.is_active,
      'category_name_ar', c.name_ar,
      'category_name_en', c.name_en,
      'reward_id', r.id,
      'reward_points_cost', r.points_cost,
      'reward_is_active', r.is_active
    ) order by p.is_active desc, p.sort_order, p.name_ar)
    from catalog.products p
    left join catalog.categories c on c.id = p.category_id
    left join loyalty.loyalty_rewards r on r.product_id = p.id
    where p.archived_at is null
  ), '[]'::jsonb);
end;
$fn$;

comment on function public.admin_loyalty_product_options is
  'Products the admin can turn into a reward, including their current reward if any.';

revoke all on function public.admin_loyalty_product_options() from public, anon;
grant execute on function public.admin_loyalty_product_options() to authenticated;

create or replace function public.admin_loyalty_members()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('loyalty.read') then
    raise exception 'missing permission: loyalty.read' using errcode = '42501';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'user_id', a.user_id,
      'full_name', p.full_name,
      'email', p.email,
      'phone', p.phone,
      'avatar_url', p.avatar_url,
      'points_balance', a.points_balance,
      'lifetime_points', a.lifetime_points,
      'tier', a.tier,
      'redemptions_count', coalesce(redemptions.redemptions_count, 0),
      'last_activity_at', greatest(
        a.updated_at,
        coalesce(activity.last_activity_at, a.updated_at)
      ),
      'updated_at', a.updated_at
    ) order by a.points_balance desc, a.lifetime_points desc, a.updated_at desc)
    from loyalty.loyalty_accounts a
    join identity.profiles p on p.id = a.user_id
    left join lateral (
      select count(*)::integer as redemptions_count
        from loyalty.loyalty_transactions t
       where t.user_id = a.user_id
         and t.reason = 'redeem_reward'
    ) redemptions on true
    left join lateral (
      select max(t.created_at) as last_activity_at
        from loyalty.loyalty_transactions t
       where t.user_id = a.user_id
    ) activity on true
  ), '[]'::jsonb);
end;
$fn$;

comment on function public.admin_loyalty_members is
  'Loyalty members with their balance, lifetime points, tier and activity.';

revoke all on function public.admin_loyalty_members() from public, anon;
grant execute on function public.admin_loyalty_members() to authenticated;

create or replace function public.admin_loyalty_transactions(p_limit integer default 300)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_limit integer := least(greatest(coalesce(p_limit, 300), 1), 1000);
  v_rows  jsonb;
  v_total bigint;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('loyalty.read') then
    raise exception 'missing permission: loyalty.read' using errcode = '42501';
  end if;

  select coalesce(jsonb_agg(entry), '[]'::jsonb)
    into v_rows
    from (
      select jsonb_build_object(
        'id', t.id,
        'user_id', t.user_id,
        'customer_name', p.full_name,
        'customer_email', p.email,
        'points', t.points,
        'balance_after', t.balance_after,
        'reason', t.reason,
        'reference_type', t.reference_type,
        'reference_id', t.reference_id,
        'order_number', o.order_number,
        'reward_product_name_ar', rp.name_ar,
        'reward_product_name_en', rp.name_en,
        'note', t.note,
        'created_at', t.created_at
      ) as entry
        from loyalty.loyalty_transactions t
        join identity.profiles p on p.id = t.user_id
        left join orders.orders o
          on t.reference_type = 'order' and o.id = t.reference_id
        left join loyalty.loyalty_rewards r
          on t.reference_type = 'reward' and r.id = t.reference_id
        left join catalog.products rp on rp.id = r.product_id
       order by t.created_at desc
       limit v_limit
    ) rows;

  select count(*) into v_total from loyalty.loyalty_transactions;

  return jsonb_build_object('rows', v_rows, 'total', v_total);
end;
$fn$;

comment on function public.admin_loyalty_transactions is
  'Newest points-ledger entries, with the order or reward each one refers to.';

revoke all on function public.admin_loyalty_transactions(integer) from public, anon;
grant execute on function public.admin_loyalty_transactions(integer) to authenticated;

-- ---------------------------------------------------------------------------
-- 4. Admin writes.
-- ---------------------------------------------------------------------------
create or replace function public.admin_save_loyalty_reward(p_reward jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_id           uuid;
  v_product_id   uuid;
  v_points_cost  integer;
  v_stock        integer;
  v_active       boolean;
  v_created      boolean := false;
  v_old          jsonb;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('loyalty.write') then
    raise exception 'missing permission: loyalty.write' using errcode = '42501';
  end if;
  if p_reward is null or jsonb_typeof(p_reward) <> 'object' then
    return jsonb_build_object('ok', false, 'reason', 'invalid_payload');
  end if;

  begin
    if coalesce(btrim(p_reward ->> 'id'), '') <> '' then
      v_id := btrim(p_reward ->> 'id')::uuid;
    end if;
    v_product_id := btrim(coalesce(p_reward ->> 'product_id', ''))::uuid;
    v_points_cost := (p_reward ->> 'points_cost')::integer;
    if p_reward ? 'stock_available' and p_reward ->> 'stock_available' is not null then
      v_stock := (p_reward ->> 'stock_available')::integer;
    end if;
    v_active := coalesce((p_reward ->> 'is_active')::boolean, true);
  exception
    when invalid_text_representation
      or numeric_value_out_of_range
      or null_value_not_allowed then
      return jsonb_build_object('ok', false, 'reason', 'invalid_payload');
  end;

  if v_points_cost is null or v_points_cost <= 0 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_points');
  end if;
  if v_points_cost > 1000000 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_points');
  end if;
  if v_stock is not null and (v_stock < 0 or v_stock > 1000000) then
    return jsonb_build_object('ok', false, 'reason', 'invalid_stock');
  end if;

  if not exists (
    select 1 from catalog.products p
     where p.id = v_product_id and p.archived_at is null
  ) then
    return jsonb_build_object('ok', false, 'reason', 'invalid_product');
  end if;

  if exists (
    select 1 from loyalty.loyalty_rewards r
     where r.product_id = v_product_id
       and (v_id is null or r.id <> v_id)
  ) then
    return jsonb_build_object('ok', false, 'reason', 'duplicate_product');
  end if;

  if v_id is null then
    insert into loyalty.loyalty_rewards
      (product_id, points_cost, stock_available, is_active)
    values
      (v_product_id, v_points_cost, v_stock, v_active)
    returning id into v_id;
    v_created := true;
  else
    select to_jsonb(r) into v_old
      from loyalty.loyalty_rewards r
     where r.id = v_id;

    if v_old is null then
      return jsonb_build_object('ok', false, 'reason', 'not_found');
    end if;

    update loyalty.loyalty_rewards
       set product_id = v_product_id,
           points_cost = v_points_cost,
           stock_available = v_stock,
           is_active = v_active
     where id = v_id;
  end if;

  perform identity.audit(
    case when v_created then 'loyalty.reward.create' else 'loyalty.reward.update' end,
    'loyalty_reward',
    v_id,
    v_old,
    jsonb_build_object(
      'product_id', v_product_id,
      'points_cost', v_points_cost,
      'stock_available', v_stock,
      'is_active', v_active
    )
  );

  return jsonb_build_object('ok', true, 'id', v_id, 'created', v_created);
exception
  when unique_violation then
    return jsonb_build_object('ok', false, 'reason', 'duplicate_product');
  when foreign_key_violation then
    return jsonb_build_object('ok', false, 'reason', 'invalid_product');
end;
$fn$;

comment on function public.admin_save_loyalty_reward is
  'Create or update a reward: one product, a positive points cost, optional stock.';

revoke all on function public.admin_save_loyalty_reward(jsonb) from public, anon;
grant execute on function public.admin_save_loyalty_reward(jsonb) to authenticated;

create or replace function public.admin_set_loyalty_reward_active(
  p_reward_id uuid,
  p_active boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_old jsonb;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('loyalty.write') then
    raise exception 'missing permission: loyalty.write' using errcode = '42501';
  end if;

  select to_jsonb(r) into v_old
    from loyalty.loyalty_rewards r
   where r.id = p_reward_id;

  if v_old is null then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;

  if p_active and exists (
    select 1
      from loyalty.loyalty_rewards r
      join catalog.products p on p.id = r.product_id
     where r.id = p_reward_id
       and p.archived_at is not null
  ) then
    return jsonb_build_object('ok', false, 'reason', 'product_archived');
  end if;

  update loyalty.loyalty_rewards
     set is_active = p_active
   where id = p_reward_id;

  perform identity.audit(
    case when p_active then 'loyalty.reward.activate' else 'loyalty.reward.pause' end,
    'loyalty_reward',
    p_reward_id,
    v_old,
    jsonb_build_object('is_active', p_active)
  );

  return jsonb_build_object('ok', true);
end;
$fn$;

comment on function public.admin_set_loyalty_reward_active is
  'Show or hide a reward from customers without deleting its history.';

revoke all on function public.admin_set_loyalty_reward_active(uuid, boolean) from public, anon;
grant execute on function public.admin_set_loyalty_reward_active(uuid, boolean) to authenticated;

create or replace function public.admin_delete_loyalty_reward(p_reward_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_old jsonb;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('loyalty.write') then
    raise exception 'missing permission: loyalty.write' using errcode = '42501';
  end if;

  select to_jsonb(r) into v_old
    from loyalty.loyalty_rewards r
   where r.id = p_reward_id;

  if v_old is null then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;

  if exists (
    select 1 from loyalty.loyalty_transactions t
     where t.reference_type = 'reward'
       and t.reference_id = p_reward_id
  ) then
    return jsonb_build_object('ok', false, 'reason', 'has_redemptions');
  end if;

  delete from loyalty.loyalty_rewards where id = p_reward_id;

  perform identity.audit(
    'loyalty.reward.delete',
    'loyalty_reward',
    p_reward_id,
    v_old,
    null
  );

  return jsonb_build_object('ok', true);
end;
$fn$;

comment on function public.admin_delete_loyalty_reward is
  'Delete a reward that was never redeemed; redeemed rewards can only be paused.';

revoke all on function public.admin_delete_loyalty_reward(uuid) from public, anon;
grant execute on function public.admin_delete_loyalty_reward(uuid) to authenticated;
