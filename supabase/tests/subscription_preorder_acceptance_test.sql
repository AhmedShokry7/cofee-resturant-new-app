-- Subscription preorder acceptance test (proposal; NOT RUNNABLE yet).
--
-- BLOCKED: this earlier v1 fixture assumes an order grand_total of zero and
-- does not model subscription funding provenance, retail value, partial/mixed
-- coverage, VAT policy, or accounting events. Do not run it or treat its
-- assertions as approved. The updated financial and technical matrix is in
-- ../proposals/subscription_preorder_financial_model.PROPOSED.md. Replace this
-- fixture with policy-specific assertions after the data model and final RPC
-- contract are approved. No database test has been run.
--
-- The remaining SQL below is retained as review history only. It must not be
-- executed until replaced with tests for the approved schema.
-- All fixtures are in one transaction and rolled back.
\set ON_ERROR_STOP on
begin;

create temporary table _preorder_fixture as
select
  'c0ffee00-0000-4000-8000-000000000101'::uuid as user_id,
  'c0ffee00-0000-4000-8000-000000000102'::uuid as other_user_id,
  'c0ffee00-0000-4000-8000-000000000111'::uuid as plan_id,
  'c0ffee00-0000-4000-8000-000000000121'::uuid as subscription_id,
  'c0ffee00-0000-4000-8000-000000000122'::uuid as other_subscription_id,
  'c0ffee00-0000-4000-8000-000000000131'::uuid as branch_id,
  'c0ffee00-0000-4000-8000-000000000132'::uuid as other_branch_id,
  'c0ffee00-0000-4000-8000-000000000141'::uuid as product_id,
  'c0ffee00-0000-4000-8000-000000000142'::uuid as excluded_product_id,
  (select (now() at time zone coalesce(b.time_zone,'Asia/Riyadh'))::date + 1
     from core.branches b where b.is_active order by b.id limit 1) as service_date;

insert into core.branches (id, brand_id, code, name_ar, name_en, is_active, settings, time_zone)
select f.branch_id, b.brand_id, 'PREORDER-TEST', 'فرع الاختبار', 'Preorder Test', true, '{}'::jsonb, 'Asia/Riyadh'
from _preorder_fixture f cross join (select brand_id from core.branches limit 1) b;
insert into core.branches (id, brand_id, code, name_ar, name_en, is_active, settings, time_zone)
select f.other_branch_id, b.brand_id, 'PREORDER-OTHER', 'فرع آخر', 'Other Branch', true, '{}'::jsonb, 'Asia/Riyadh'
from _preorder_fixture f cross join (select brand_id from core.branches where id <> f.branch_id limit 1) b;

insert into auth.users (id, email) values
 ('c0ffee00-0000-4000-8000-000000000101','preorder-a@test.local'),
 ('c0ffee00-0000-4000-8000-000000000102','preorder-b@test.local');
insert into identity.profiles (id, full_name, email) values
 ('c0ffee00-0000-4000-8000-000000000101','Preorder A','preorder-a@test.local'),
 ('c0ffee00-0000-4000-8000-000000000102','Preorder B','preorder-b@test.local')
on conflict (id) do nothing;

insert into catalog.products (id, category_id, sku, slug, name_ar, name_en, description_ar, description_en, base_price, is_active)
select f.product_id, c.id, 'PREORDER-TEST-1', 'preorder-test-1', 'منتج الاختبار','Preorder Test Product','وصف','Description', 12, true
from _preorder_fixture f cross join (select id from catalog.categories order by id limit 1) c;
insert into catalog.products (id, category_id, sku, slug, name_ar, name_en, base_price, is_active)
select f.excluded_product_id, c.id, 'PREORDER-TEST-2', 'preorder-test-2', 'منتج غير مشمول','Excluded Test Product',12,true
from _preorder_fixture f cross join (select id from catalog.categories order by id limit 1) c;

insert into subscriptions.plans (
 id, code, name_ar, name_en, price, duration_days, cups_per_cycle,
 all_branches, product_scope, is_active, is_for_sale
) values (
 'c0ffee00-0000-4000-8000-000000000111','PREORDER-TEST','باقة اختبار','Test plan',0,30,3,
 false,'selected',true,true
);
insert into subscriptions.plan_branches (plan_id, branch_id)
select plan_id, branch_id from _preorder_fixture;
insert into subscriptions.plan_products (plan_id, product_id)
select plan_id, product_id from _preorder_fixture;
insert into subscriptions.subscriptions (
 id,user_id,plan_id,status,starts_at,ends_at,cups_entitled,cups_used,cups_carried_over,
 bonus_balance,auto_renew,idempotency_key
) select subscription_id,user_id,plan_id,'active',now()-interval '1 day',now()+interval '20 days',3,0,0,0,false,'preorder-test-sub-a'
  from _preorder_fixture;
insert into subscriptions.subscriptions (
 id,user_id,plan_id,status,starts_at,ends_at,cups_entitled,cups_used,cups_carried_over,
 bonus_balance,auto_renew,idempotency_key
) select other_subscription_id,other_user_id,plan_id,'active',now()-interval '1 day',now()+interval '20 days',3,0,0,0,false,'preorder-test-sub-b'
  from _preorder_fixture;

-- Configure one open pickup window for tomorrow; slot availability/capacity is
-- still validated by the same production RPC/trigger path used by checkout.
insert into core.branch_pickup_exceptions(branch_id,exception_date,closed,opens_at,closes_at,slot_minutes,capacity)
select branch_id,service_date,false,'08:00','22:00',15,4 from _preorder_fixture;
insert into inventory.branch_stock(branch_id,product_id,variant_key,quantity_on_hand,allow_negative)
select f.branch_id,f.product_id,'00000000-0000-0000-0000-000000000000'::uuid,4,false from _preorder_fixture;

set local role authenticated;
select set_config('request.jwt.claim.sub','c0ffee00-0000-4000-8000-000000000101',true);
create temporary table _preorder_results (order_id uuid not null);

do $$
declare
  f record;
  v_slot timestamptz;
  v_order record;
  v_retry record;
  v_failed boolean := false;
begin
  select * into f from _preorder_fixture;
  if (select count(*) from public.list_my_subscription_preorder_branches(f.subscription_id)) <> 1 then
    raise exception 'FAIL: owner branch list did not scope to the plan';
  end if;
  if (select count(*) from public.list_my_subscription_preorder_products(f.subscription_id,f.branch_id)) <> 1 then
    raise exception 'FAIL: product list did not scope to active included branch products';
  end if;
  select s.slot_start into v_slot
    from public.available_pickup_slots(f.branch_id,f.service_date) s
   order by s.slot_start limit 1;
  if v_slot is null then raise exception 'FAIL: fixture has no available pickup slot'; end if;

  -- Successful order: 2 covered products, zero due, quota reserved, no usage yet.
  select * into v_order from public.place_subscription_preorder(
    f.subscription_id,f.branch_id,
    jsonb_build_array(jsonb_build_object('product_id',f.product_id,'quantity',2)),
    'preorder-test-key-1',v_slot
  );
  if v_order.order_id is null or v_order.status <> 'pending' then
    raise exception 'FAIL: preorder was not created pending';
  end if;
  insert into _preorder_results values (v_order.order_id);
  if (select grand_total from orders.orders where id=v_order.order_id) <> 0 then
    raise exception 'FAIL: included products were charged';
  end if;
  if (select cups_reserved from subscriptions.subscriptions where id=f.subscription_id) <> 2
     or (select cups_used from subscriptions.subscriptions where id=f.subscription_id) <> 0 then
    raise exception 'FAIL: reservation did not remain separate from consumption';
  end if;
  if exists(select 1 from subscriptions.subscription_usage where order_id=v_order.order_id) then
    raise exception 'FAIL: usage recorded before pickup';
  end if;
  if not exists(select 1 from kitchen.tickets where order_id=v_order.order_id) then
    raise exception 'FAIL: preorder did not enter the existing kitchen queue';
  end if;
  if not exists(
    select 1 from engagement.notifications n
     where n.user_id=f.user_id
       and n.dedupe_key='order:'||v_order.order_id::text||':pending'
       and n.payload->>'order_number'=v_order.order_number
       and n.payload ? 'scheduled_pickup_at'
       and n.payload ? 'branch_name'
  ) then raise exception 'FAIL: preorder confirmation notification is incomplete'; end if;

  -- Retry returns the same order; a different body with the same key is refused.
  select * into v_retry from public.place_subscription_preorder(
    f.subscription_id,f.branch_id,
    jsonb_build_array(jsonb_build_object('product_id',f.product_id,'quantity',2)),
    'preorder-test-key-1',v_slot
  );
  if v_retry.order_id <> v_order.order_id or not v_retry.reused_existing_order then
    raise exception 'FAIL: retry was not idempotent';
  end if;
  begin
    perform * from public.place_subscription_preorder(
      f.subscription_id,f.branch_id,
      jsonb_build_array(jsonb_build_object('product_id',f.product_id,'quantity',1)),
      'preorder-test-key-1',v_slot
    );
  exception when others then v_failed := true;
  end;
  if not v_failed then raise exception 'FAIL: changed payload reused an idempotency key'; end if;

  -- Reject excluded products, another customer's subscription, ineligible branch,
  -- and a quantity above the remaining quota. Each failed statement is atomic.
  v_failed := false;
  begin
    perform * from public.place_subscription_preorder(
      f.subscription_id,f.branch_id,
      jsonb_build_array(jsonb_build_object('product_id',f.excluded_product_id,'quantity',1)),
      'preorder-test-key-excluded',v_slot
    );
  exception when others then v_failed := true;
  end;
  if not v_failed then raise exception 'FAIL: excluded product was accepted'; end if;

  v_failed := false;
  begin
    perform * from public.place_subscription_preorder(
      f.other_subscription_id,f.branch_id,
      jsonb_build_array(jsonb_build_object('product_id',f.product_id,'quantity',1)),
      'preorder-test-key-owner',v_slot
    );
  exception when others then v_failed := true;
  end;
  if not v_failed then raise exception 'FAIL: another customer subscription was accepted'; end if;

  v_failed := false;
  begin
    perform * from public.place_subscription_preorder(
      f.subscription_id,f.other_branch_id,
      jsonb_build_array(jsonb_build_object('product_id',f.product_id,'quantity',1)),
      'preorder-test-key-branch',v_slot
    );
  exception when others then v_failed := true;
  end;
  if not v_failed then raise exception 'FAIL: ineligible branch was accepted'; end if;

  v_failed := false;
  begin
    perform * from public.place_subscription_preorder(
      f.subscription_id,f.branch_id,
      jsonb_build_array(jsonb_build_object('product_id',f.product_id,'quantity',2)),
      'preorder-test-key-quota',v_slot
    );
  exception when others then v_failed := true;
  end;
  if not v_failed then raise exception 'FAIL: over-quota order was accepted'; end if;
  if (select count(*) from orders.orders where idempotency_key like 'preorder-test-key-%') <> 1 then
    raise exception 'FAIL: failed requests left partial orders';
  end if;
  if has_function_privilege('authenticated','subscriptions.reserve_for_order(uuid,uuid,uuid,jsonb,text)','EXECUTE')
     or has_function_privilege('authenticated','public.reserve_subscription_for_order(uuid,uuid,uuid,jsonb,text)','EXECUTE') then
    raise exception 'FAIL: standalone client reservation remains executable';
  end if;
end $$;

-- Simulate the existing admin/kitchen status updates as the database owner,
-- after exercising the public customer RPC as `authenticated` above.
reset role;
do $$
declare f record; v_order_id uuid;
begin
  select * into f from _preorder_fixture;
  select order_id into v_order_id from _preorder_results limit 1;
  update orders.orders set status='cancelled',cancelled_at=now(),cancel_reason='test cancellation'
   where id=v_order_id;
  if (select cups_reserved from subscriptions.subscriptions where id=f.subscription_id) <> 0
     or (select cups_used from subscriptions.subscriptions where id=f.subscription_id) <> 0 then
    raise exception 'FAIL: cancellation did not release only the reservation';
  end if;
  if exists(select 1 from subscriptions.subscription_usage where order_id=v_order_id) then
    raise exception 'FAIL: cancellation created a usage row';
  end if;
end $$;

set local role authenticated;
select set_config('request.jwt.claim.sub','c0ffee00-0000-4000-8000-000000000101',true);
do $$
declare f record; v_slot timestamptz; v_order record;
begin
  select * into f from _preorder_fixture;
  select s.slot_start into v_slot from public.available_pickup_slots(f.branch_id,f.service_date) s order by s.slot_start limit 1;
  select * into v_order from public.place_subscription_preorder(
    f.subscription_id,f.branch_id,
    jsonb_build_array(jsonb_build_object('product_id',f.product_id,'quantity',1)),
    'preorder-test-key-2',v_slot
  );
end $$;
reset role;
do $$
declare f record; v_order_id uuid;
begin
  select * into f from _preorder_fixture;
  select order_id into v_order_id
    from subscriptions.subscription_consumptions
   where reservation_key='preorder-test-key-2'
   limit 1;
  update orders.orders set status='completed',completed_at=now() where id=v_order_id;
  update orders.orders set status='completed',completed_at=now() where id=v_order_id;
  if (select cups_reserved from subscriptions.subscriptions where id=f.subscription_id) <> 0
     or (select cups_used from subscriptions.subscriptions where id=f.subscription_id) <> 1 then
    raise exception 'FAIL: completion did not consume exactly once';
  end if;
  if (select count(*) from subscriptions.subscription_usage where order_id=v_order_id and method='app_order') <> 1 then
    raise exception 'FAIL: app_order usage history is missing or duplicated';
  end if;
end $$;

rollback;
