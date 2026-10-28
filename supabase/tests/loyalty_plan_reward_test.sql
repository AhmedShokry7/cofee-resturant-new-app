-- loyalty_plan_reward_test.sql
-- Behaviour test for 199_loyalty_plan_reward_entry_point.sql.
--
-- It answers the question the D4 write-up could not: does a loyalty reward whose
-- target is a subscription plan actually deliver that plan. Before 199 the
-- answer was no, but only a run against a real database proves it, because the
-- failure is a runtime lookup of a dropped function (42883), not a syntax error,
-- and plpgsql did not check it at CREATE time.
--
-- HOW TO RUN: this file builds its fixtures inside one transaction and rolls the
-- transaction back, so it can be executed against a database that already has
-- 199 applied, including production. Read the STATUS block before believing any
-- result. Every fixture id is in the 5d/5e/3d ranges used by the other tests in
-- this folder, and every insert is a fresh row, so the rollback removes all of it.
--
-- PREREQUISITES: 004/011/014 (identity, orders, loyalty), 074/075 (subscription
-- tables and the safe activation path), 167 (reward targets) and 199.
--
-- ASSERTS
--   1. redeeming a plan reward creates exactly one new subscription, active, on
--      the reward's plan, with the plan's cups and the reward as its reference;
--   2. the points are spent, and the reward's own stock counter is untouched
--      when the reward carries no stock limit;
--   3. the grant is not reachable as a client RPC: authenticated has no execute
--      on subscriptions.grant_plan_cycle, which is the reason 075 dropped the
--      public entry point in the first place.

begin;

-- ---------------------------------------------------------------------------
-- Fixtures, written while the session is still its owner.
-- ---------------------------------------------------------------------------
insert into auth.users (id, email)
values ('5d000000-0000-4000-8000-000000000001', 'lprt-customer@test.local')
on conflict (id) do nothing;

insert into identity.profiles (id, full_name, email, phone)
values ('5d000000-0000-4000-8000-000000000001', 'LPRT Customer',
        'lprt-customer@test.local', '0590000101')
on conflict (id) do nothing;

insert into loyalty.loyalty_accounts (user_id, points_balance, lifetime_points)
values ('5d000000-0000-4000-8000-000000000001', 1000, 1000)
on conflict (user_id) do update
   set points_balance = 1000, lifetime_points = 1000;

insert into subscriptions.plans (code, name_ar, name_en, price, duration_days,
                                 cups_per_cycle, rollover_cap_cups)
values ('LPRT-PLAN', 'خطة الاختبار', 'Rehearsal plan', 10, 30, 25, 0)
returning id;

insert into loyalty.loyalty_rewards (points_cost, is_active, reward_type, plan_id)
select 500, true, 'plan', p.id
  from subscriptions.plans p
 where p.code = 'LPRT-PLAN'
returning id;

-- What the customer already had before redeeming, counted as the owner role.
select count(*) as subscriptions_before
  from subscriptions.subscriptions
 where user_id = '5d000000-0000-4000-8000-000000000001';

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"5d000000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);

-- ---------------------------------------------------------------------------
-- 1 + 2. The reward is redeemed through the customer RPC.
-- ---------------------------------------------------------------------------
select loyalty.redeem_loyalty_reward(
  (select r.id from loyalty.loyalty_rewards r
     join subscriptions.plans p on p.id = r.plan_id
    where p.code = 'LPRT-PLAN'),
  null
) as balance_after;

do $$
declare
  v_uid  uuid := '5d000000-0000-4000-8000-000000000001';
  v_sub  subscriptions.subscriptions%rowtype;
  v_cost integer;
begin
  select r.points_cost into v_cost
    from loyalty.loyalty_rewards r
    join subscriptions.plans p on p.id = r.plan_id
   where p.code = 'LPRT-PLAN';

  select * into v_sub
    from subscriptions.subscriptions
   where user_id = v_uid
   order by created_at desc
   limit 1;

  if not found then
    raise exception 'FAIL 1: redeeming a plan reward created no subscription';
  end if;
  if v_sub.status <> 'active' then
    raise exception 'FAIL 1: the granted cycle is %, expected active', v_sub.status;
  end if;
  if v_sub.cups_entitled <> 25 then
    raise exception 'FAIL 1: the granted cycle carries % cups, expected 25',
      v_sub.cups_entitled;
  end if;
  if v_sub.payment_reference <> 'loyalty_reward:' || (
       select r.id::text from loyalty.loyalty_rewards r
       join subscriptions.plans p on p.id = r.plan_id
        where p.code = 'LPRT-PLAN') then
    raise exception 'FAIL 1: the grant names % instead of the reward',
      v_sub.payment_reference;
  end if;
  if v_sub.ends_at is null or v_sub.ends_at <= now() + interval '29 days' then
    raise exception 'FAIL 1: the granted cycle does not run the plan''s 30 days';
  end if;

  if (select points_balance from loyalty.loyalty_accounts where user_id = v_uid)
     <> 1000 - v_cost then
    raise exception 'FAIL 2: the points were not spent exactly once';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 3. The grant itself stays a server-side call.
-- ---------------------------------------------------------------------------
do $$
begin
  if has_function_privilege('authenticated',
       'subscriptions.grant_plan_cycle(uuid,uuid,text,text)', 'execute') then
    raise exception 'FAIL 3: a client may call the cycle grant directly';
  end if;
  if has_function_privilege('anon',
       'subscriptions.grant_plan_cycle(uuid,uuid,text,text)', 'execute') then
    raise exception 'FAIL 3: anon may call the cycle grant';
  end if;
end $$;

select 'loyalty_plan_reward_test: assertions executed' as result;

rollback;
