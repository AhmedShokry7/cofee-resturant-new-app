-- 167_loyalty_reward_targets.sql
-- A loyalty reward can now target one of three catalogue items:
--   * a product      -> a free pickup order for that product;
--   * a bundle       -> a free pickup order with every bundle component;
--   * a subscription -> the reward activates one subscription cycle.
--
-- Free rewards are delivered as their own zero-total order instead of cart
-- lines. Cart lines are client-owned (replace_cart rewrites them) and are
-- always repriced from the catalogue, so a reward parked in the cart would be
-- charged at checkout. A reward order is created atomically with the points
-- deduction, deducts branch stock and stays visible to the branch and customer.
--
-- The admin catalogue, the customer catalogue and redemption all understand
-- the same three target types.

begin;

-- ---------------------------------------------------------------------------
-- 1. Reward targets.
-- ---------------------------------------------------------------------------
alter table loyalty.loyalty_rewards
  add column if not exists reward_type text not null default 'product';

alter table loyalty.loyalty_rewards
  add column if not exists bundle_id uuid
    references catalog.bundles(id) on delete restrict;

alter table loyalty.loyalty_rewards
  add column if not exists plan_id uuid
    references subscriptions.plans(id) on delete restrict;

alter table loyalty.loyalty_rewards
  alter column product_id drop not null;

alter table loyalty.loyalty_rewards
  drop constraint if exists loyalty_rewards_type_check;

alter table loyalty.loyalty_rewards
  add constraint loyalty_rewards_type_check
  check (reward_type in ('product', 'bundle', 'plan'));

alter table loyalty.loyalty_rewards
  drop constraint if exists loyalty_rewards_target_check;

alter table loyalty.loyalty_rewards
  add constraint loyalty_rewards_target_check check (
    (reward_type = 'product' and product_id is not null
      and bundle_id is null and plan_id is null)
    or (reward_type = 'bundle' and product_id is null
      and bundle_id is not null and plan_id is null)
    or (reward_type = 'plan' and product_id is null
      and bundle_id is null and plan_id is not null)
  );

create unique index if not exists uq_loyalty_rewards_bundle
  on loyalty.loyalty_rewards (bundle_id)
  where bundle_id is not null;

create unique index if not exists uq_loyalty_rewards_plan
  on loyalty.loyalty_rewards (plan_id)
  where plan_id is not null;

comment on column loyalty.loyalty_rewards.reward_type is
  'Which catalogue item the reward unlocks: product, bundle or plan.';
comment on column loyalty.loyalty_rewards.bundle_id is
  'The bundle a bundle reward unlocks. Set only when reward_type = bundle.';
comment on column loyalty.loyalty_rewards.plan_id is
  'The subscription plan a plan reward activates. Set only when reward_type = plan.';

comment on table loyalty.loyalty_rewards is
  'Redeemable rewards with their point cost. Each reward targets exactly one product, bundle or subscription plan.';

-- ---------------------------------------------------------------------------
-- 2. Public catalogue view.
--    The existing column list is preserved and the new columns are appended,
--    so current clients keep working while new clients can read the target.
-- ---------------------------------------------------------------------------
create or replace view public.loyalty_rewards with (security_invoker = true) as
  select r.id,
         r.product_id,
         r.points_cost,
         r.stock_available,
         r.is_active,
         t.slug,
         t.name_ar,
         t.name_en,
         t.image_url,
         r.reward_type,
         r.bundle_id,
         r.plan_id
    from loyalty.loyalty_rewards r
    join lateral (
      select p.slug, p.name_ar, p.name_en, p.image_url
        from catalog.products p
       where r.reward_type = 'product' and p.id = r.product_id
      union all
      select null::text, b.name_ar, b.name_en, b.image_url
        from catalog.bundles b
       where r.reward_type = 'bundle' and b.id = r.bundle_id
      union all
      select null::text, pl.name_ar, pl.name_en, pl.image_url
        from subscriptions.plans pl
       where r.reward_type = 'plan' and pl.id = r.plan_id
    ) t on true;

comment on view public.loyalty_rewards is
  'Public reward catalogue with the target name/image for products, bundles and subscription plans.';

-- ---------------------------------------------------------------------------
-- 3. Admin reads.
-- ---------------------------------------------------------------------------
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
      'reward_type', r.reward_type,
      'product_id', r.product_id,
      'bundle_id', r.bundle_id,
      'plan_id', r.plan_id,
      'target_id', coalesce(r.product_id, r.bundle_id, r.plan_id),
      'points_cost', r.points_cost,
      'stock_available', r.stock_available,
      'is_active', r.is_active,
      'target_name_ar', coalesce(p.name_ar, b.name_ar, pl.name_ar),
      'target_name_en', coalesce(p.name_en, b.name_en, pl.name_en),
      'target_code', coalesce(p.sku, pl.code),
      'target_image_url', coalesce(p.image_url, b.image_url, pl.image_url),
      'target_price', coalesce(p.base_price, b.bundle_price, pl.price, 0),
      'target_is_active', case r.reward_type
        when 'product' then coalesce(p.is_active, false)
        when 'bundle' then coalesce(
          b.is_active
          and (b.starts_at is null or now() >= b.starts_at)
          and (b.ends_at is null or now() < b.ends_at),
          false
        )
        when 'plan' then coalesce(pl.is_active and pl.is_for_sale, false)
        else false
      end,
      'target_is_available', case r.reward_type
        when 'product' then coalesce(
          p.is_active and p.archived_at is null, false
        )
        when 'bundle' then coalesce(
          b.is_active
          and (b.starts_at is null or now() >= b.starts_at)
          and (b.ends_at is null or now() < b.ends_at)
          and b.bundle_price is not null
          and b.bundle_price > 0
          and exists (
            select 1 from catalog.bundle_items bi where bi.bundle_id = b.id
          ),
          false
        )
        when 'plan' then coalesce(pl.is_active and pl.is_for_sale, false)
        else false
      end,
      'category_name_ar', c.name_ar,
      'category_name_en', c.name_en,
      'bundle_items_count', (
        select count(*)::integer
          from catalog.bundle_items bi
         where r.reward_type = 'bundle' and bi.bundle_id = r.bundle_id
      ),
      'plan_duration_days', case
        when r.reward_type = 'plan' then pl.duration_days
      end,
      'plan_cups_per_cycle', case
        when r.reward_type = 'plan' then pl.cups_per_cycle
      end,
      'redemptions_count', coalesce(stats.redemptions_count, 0),
      'last_redeemed_at', stats.last_redeemed_at,
      'created_at', r.created_at,
      'updated_at', r.updated_at
    ) order by r.is_active desc, r.points_cost, r.created_at)
    from loyalty.loyalty_rewards r
    left join catalog.products p
      on r.reward_type = 'product' and p.id = r.product_id
    left join catalog.categories c on c.id = p.category_id
    left join catalog.bundles b
      on r.reward_type = 'bundle' and b.id = r.bundle_id
    left join subscriptions.plans pl
      on r.reward_type = 'plan' and pl.id = r.plan_id
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
  'Reward catalogue with the target details and redemption counts for products, bundles and plans.';

revoke all on function public.admin_loyalty_rewards() from public, anon;
grant execute on function public.admin_loyalty_rewards() to authenticated;

-- ---------------------------------------------------------------------------
-- 4. Targets the admin can turn into a reward.
--    One list with a type discriminator; the editor filters by type.
-- ---------------------------------------------------------------------------
create or replace function public.admin_loyalty_reward_targets()
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
    select jsonb_agg(entry order by sort_order, is_active desc, name_en)
      from (
        select
          jsonb_build_object(
            'type', 'product',
            'id', p.id,
            'name_ar', p.name_ar,
            'name_en', p.name_en,
            'code', p.sku,
            'image_url', p.image_url,
            'price', p.base_price,
            'is_active', p.is_active,
            'category_name_ar', c.name_ar,
            'category_name_en', c.name_en,
            'bundle_items_count', null,
            'plan_duration_days', null,
            'plan_cups_per_cycle', null,
            'reward_id', rp.id,
            'reward_points_cost', rp.points_cost,
            'reward_is_active', rp.is_active
          ) as entry,
          0 as sort_order,
          p.is_active as is_active,
          coalesce(p.name_en, p.name_ar) as name_en
        from catalog.products p
        left join catalog.categories c on c.id = p.category_id
        left join loyalty.loyalty_rewards rp on rp.product_id = p.id
        where p.archived_at is null

        union all

        select
          jsonb_build_object(
            'type', 'bundle',
            'id', b.id,
            'name_ar', b.name_ar,
            'name_en', b.name_en,
            'code', null,
            'image_url', b.image_url,
            'price', b.bundle_price,
            'is_active', coalesce(
              b.is_active
              and (b.starts_at is null or now() >= b.starts_at)
              and (b.ends_at is null or now() < b.ends_at)
              and b.bundle_price is not null
              and b.bundle_price > 0
              and exists (
                select 1 from catalog.bundle_items bi where bi.bundle_id = b.id
              ),
              false
            ),
            'category_name_ar', null,
            'category_name_en', null,
            'bundle_items_count', (
              select count(*)::integer
                from catalog.bundle_items bi
               where bi.bundle_id = b.id
            ),
            'plan_duration_days', null,
            'plan_cups_per_cycle', null,
            'reward_id', rb.id,
            'reward_points_cost', rb.points_cost,
            'reward_is_active', rb.is_active
          ) as entry,
          1 as sort_order,
          coalesce(
            b.is_active
            and (b.starts_at is null or now() >= b.starts_at)
            and (b.ends_at is null or now() < b.ends_at)
            and b.bundle_price is not null
            and b.bundle_price > 0
            and exists (
              select 1 from catalog.bundle_items bi where bi.bundle_id = b.id
            ),
            false
          ) as is_active,
          coalesce(b.name_en, b.name_ar) as name_en
        from catalog.bundles b
        left join loyalty.loyalty_rewards rb on rb.bundle_id = b.id

        union all

        select
          jsonb_build_object(
            'type', 'plan',
            'id', pl.id,
            'name_ar', pl.name_ar,
            'name_en', pl.name_en,
            'code', pl.code,
            'image_url', pl.image_url,
            'price', pl.price,
            'is_active', coalesce(pl.is_active and pl.is_for_sale, false),
            'category_name_ar', null,
            'category_name_en', null,
            'bundle_items_count', null,
            'plan_duration_days', pl.duration_days,
            'plan_cups_per_cycle', pl.cups_per_cycle,
            'reward_id', rpl.id,
            'reward_points_cost', rpl.points_cost,
            'reward_is_active', rpl.is_active
          ) as entry,
          2 as sort_order,
          coalesce(pl.is_active and pl.is_for_sale, false) as is_active,
          coalesce(pl.name_en, pl.name_ar) as name_en
        from subscriptions.plans pl
        left join loyalty.loyalty_rewards rpl on rpl.plan_id = pl.id
      ) rows
  ), '[]'::jsonb);
end;
$fn$;

comment on function public.admin_loyalty_reward_targets is
  'Products, bundles and subscription plans the admin can turn into a loyalty reward.';

revoke all on function public.admin_loyalty_reward_targets() from public, anon;
grant execute on function public.admin_loyalty_reward_targets() to authenticated;

-- ---------------------------------------------------------------------------
-- 5. Ledger read: name the reward for every target type.
-- ---------------------------------------------------------------------------
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
        'reward_type', r.reward_type,
        'reward_product_name_ar', coalesce(rp.name_ar, rb.name_ar, rpl.name_ar),
        'reward_product_name_en', coalesce(rp.name_en, rb.name_en, rpl.name_en),
        'note', t.note,
        'created_at', t.created_at
      ) as entry
        from loyalty.loyalty_transactions t
        join identity.profiles p on p.id = t.user_id
        left join orders.orders o
          on t.reference_type = 'order' and o.id = t.reference_id
        left join loyalty.loyalty_rewards r
          on t.reference_type = 'reward' and r.id = t.reference_id
        left join catalog.products rp
          on r.reward_type = 'product' and rp.id = r.product_id
        left join catalog.bundles rb
          on r.reward_type = 'bundle' and rb.id = r.bundle_id
        left join subscriptions.plans rpl
          on r.reward_type = 'plan' and rpl.id = r.plan_id
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
-- 6. Admin writes.
-- ---------------------------------------------------------------------------
create or replace function public.admin_save_loyalty_reward(p_reward jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_id           uuid;
  v_type         text;
  v_target_id    uuid;
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
    v_type := coalesce(nullif(btrim(p_reward ->> 'reward_type'), ''), 'product');
    v_target_id := coalesce(
      nullif(btrim(p_reward ->> 'target_id'), ''),
      nullif(btrim(p_reward ->> 'product_id'), ''),
      nullif(btrim(p_reward ->> 'bundle_id'), ''),
      nullif(btrim(p_reward ->> 'plan_id'), '')
    )::uuid;
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

  if v_type not in ('product', 'bundle', 'plan') then
    return jsonb_build_object('ok', false, 'reason', 'invalid_type');
  end if;

  if v_points_cost is null or v_points_cost <= 0 or v_points_cost > 1000000 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_points');
  end if;
  if v_stock is not null and (v_stock < 0 or v_stock > 1000000) then
    return jsonb_build_object('ok', false, 'reason', 'invalid_stock');
  end if;

  if v_target_id is null then
    return jsonb_build_object('ok', false, 'reason', 'invalid_target');
  end if;

  if v_type = 'product' then
    if not exists (
      select 1 from catalog.products p
       where p.id = v_target_id and p.archived_at is null
    ) then
      return jsonb_build_object('ok', false, 'reason', 'invalid_target');
    end if;
    if v_active and not exists (
      select 1 from catalog.products p
       where p.id = v_target_id and p.is_active
    ) then
      return jsonb_build_object('ok', false, 'reason', 'target_unavailable');
    end if;
  elsif v_type = 'bundle' then
    if not exists (
      select 1 from catalog.bundles b where b.id = v_target_id
    ) then
      return jsonb_build_object('ok', false, 'reason', 'invalid_target');
    end if;
    if v_active and not exists (
      select 1
        from catalog.bundles b
       where b.id = v_target_id
         and b.is_active
         and (b.starts_at is null or now() >= b.starts_at)
         and (b.ends_at is null or now() < b.ends_at)
         and b.bundle_price is not null
         and b.bundle_price > 0
         and exists (
           select 1 from catalog.bundle_items bi where bi.bundle_id = b.id
         )
    ) then
      return jsonb_build_object('ok', false, 'reason', 'target_unavailable');
    end if;
  else
    if not exists (
      select 1 from subscriptions.plans p where p.id = v_target_id
    ) then
      return jsonb_build_object('ok', false, 'reason', 'invalid_target');
    end if;
    if v_active and not exists (
      select 1
        from subscriptions.plans p
       where p.id = v_target_id
         and p.is_active
         and p.is_for_sale
    ) then
      return jsonb_build_object('ok', false, 'reason', 'target_unavailable');
    end if;
  end if;

  if exists (
    select 1
      from loyalty.loyalty_rewards r
     where (v_id is null or r.id <> v_id)
       and case v_type
         when 'product' then r.product_id = v_target_id
         when 'bundle' then r.bundle_id = v_target_id
         else r.plan_id = v_target_id
       end
  ) then
    return jsonb_build_object('ok', false, 'reason', 'duplicate_target');
  end if;

  if v_id is null then
    insert into loyalty.loyalty_rewards
      (reward_type, product_id, bundle_id, plan_id,
       points_cost, stock_available, is_active)
    values
      (v_type,
       case when v_type = 'product' then v_target_id end,
       case when v_type = 'bundle' then v_target_id end,
       case when v_type = 'plan' then v_target_id end,
       v_points_cost, v_stock, v_active)
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
       set reward_type = v_type,
           product_id = case when v_type = 'product' then v_target_id end,
           bundle_id = case when v_type = 'bundle' then v_target_id end,
           plan_id = case when v_type = 'plan' then v_target_id end,
           points_cost = v_points_cost,
           stock_available = v_stock,
           is_active = v_active,
           updated_at = now()
     where id = v_id;
  end if;

  perform identity.audit(
    case when v_created then 'loyalty.reward.create' else 'loyalty.reward.update' end,
    'loyalty_reward',
    v_id,
    v_old,
    jsonb_build_object(
      'reward_type', v_type,
      'target_id', v_target_id,
      'points_cost', v_points_cost,
      'stock_available', v_stock,
      'is_active', v_active
    )
  );

  return jsonb_build_object(
    'ok', true,
    'id', v_id,
    'created', v_created,
    'reward_type', v_type
  );
exception
  when unique_violation then
    return jsonb_build_object('ok', false, 'reason', 'duplicate_target');
  when foreign_key_violation then
    return jsonb_build_object('ok', false, 'reason', 'invalid_target');
end;
$fn$;

comment on function public.admin_save_loyalty_reward is
  'Create or update a reward for one product, bundle or subscription plan with a positive points cost and optional stock.';

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
  v_reward loyalty.loyalty_rewards%rowtype;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('loyalty.write') then
    raise exception 'missing permission: loyalty.write' using errcode = '42501';
  end if;

  select * into v_reward
    from loyalty.loyalty_rewards r
   where r.id = p_reward_id;

  if not found then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;

  if p_active then
    if v_reward.reward_type = 'product' then
      if not exists (
        select 1 from catalog.products p
         where p.id = v_reward.product_id
           and p.is_active
           and p.archived_at is null
      ) then
        return jsonb_build_object('ok', false, 'reason', 'target_unavailable');
      end if;
    elsif v_reward.reward_type = 'bundle' then
      if not exists (
        select 1
          from catalog.bundles b
         where b.id = v_reward.bundle_id
           and b.is_active
           and (b.starts_at is null or now() >= b.starts_at)
           and (b.ends_at is null or now() < b.ends_at)
           and b.bundle_price is not null
           and b.bundle_price > 0
           and exists (
             select 1 from catalog.bundle_items bi where bi.bundle_id = b.id
           )
      ) then
        return jsonb_build_object('ok', false, 'reason', 'target_unavailable');
      end if;
    else
      if not exists (
        select 1
          from subscriptions.plans p
         where p.id = v_reward.plan_id
           and p.is_active
           and p.is_for_sale
      ) then
        return jsonb_build_object('ok', false, 'reason', 'target_unavailable');
      end if;
    end if;
  end if;

  update loyalty.loyalty_rewards
     set is_active = p_active
   where id = p_reward_id;

  perform identity.audit(
    case when p_active then 'loyalty.reward.activate' else 'loyalty.reward.pause' end,
    'loyalty_reward',
    p_reward_id,
    to_jsonb(v_reward),
    jsonb_build_object('is_active', p_active)
  );

  return jsonb_build_object('ok', true);
end;
$fn$;

comment on function public.admin_set_loyalty_reward_active is
  'Show or hide a reward from customers without deleting its history.';

revoke all on function public.admin_set_loyalty_reward_active(uuid, boolean) from public, anon;
grant execute on function public.admin_set_loyalty_reward_active(uuid, boolean) to authenticated;

-- ---------------------------------------------------------------------------
-- 7. Redemption for every target type.
--    A product or bundle becomes a zero-total pickup order at the chosen
--    branch, so the reward is never charged and cannot be lost by a cart
--    rewrite. A plan starts a new subscription cycle. Points, stock, the order
--    and the target are all changed in one transaction, so a failure cannot
--    spend points without delivering.
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
    perform subscriptions.subscribe(
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

create or replace function public.redeem_loyalty_reward(
  p_reward_id uuid,
  p_branch_id uuid
)
returns integer
language sql
security invoker
set search_path = ''
as $fn$
  select loyalty.redeem_loyalty_reward(p_reward_id, p_branch_id);
$fn$;

comment on function public.redeem_loyalty_reward is
  'Public bridge for redeeming any reward type.';

revoke all on function public.redeem_loyalty_reward(uuid, uuid) from public, anon;
grant execute on function public.redeem_loyalty_reward(uuid, uuid) to authenticated;

notify pgrst, 'reload schema';

commit;
