-- Rollback-only branch-scope and read/write separation checks for migration 271.
begin;

insert into core.branches (id, brand_id, code, name_ar, name_en, address, is_active, settings)
values
  ('97e10000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000001', 'AI-SCOPE-271-271-1', 'فرع مساعد 1', 'Assistant Branch 1', 'test', true, '{}'::jsonb),
  ('97e10000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000001', 'AI-SCOPE-271-2', 'فرع مساعد 2', 'Assistant Branch 2', 'test', true, '{}'::jsonb);

insert into auth.users (id, email) values
 ('97e20000-0000-4000-8000-000000000001', 'assistant-customer-271@test.local'),
 ('97e20000-0000-4000-8000-000000000002', 'assistant-branch-271@test.local'),
 ('97e20000-0000-4000-8000-000000000003', 'assistant-multi-271@test.local'),
 ('97e20000-0000-4000-8000-000000000004', 'assistant-reader-271@test.local'),
 ('97e20000-0000-4000-8000-000000000005', 'assistant-owner-271@test.local');

insert into identity.profiles (id, full_name, email, phone)
values ('97e20000-0000-4000-8000-000000000001', 'Assistant Scope Customer', 'assistant-customer-271@test.local', '0500000000')
on conflict (id) do update set full_name = excluded.full_name;

insert into identity.staff_members (id, user_id, status, full_name, email) values
 ('97e30000-0000-4000-8000-000000000001', '97e20000-0000-4000-8000-000000000002', 'active', 'Assistant Branch Staff', 'assistant-branch-271@test.local'),
 ('97e30000-0000-4000-8000-000000000002', '97e20000-0000-4000-8000-000000000003', 'active', 'Assistant Multi Staff', 'assistant-multi-271@test.local'),
 ('97e30000-0000-4000-8000-000000000003', '97e20000-0000-4000-8000-000000000004', 'active', 'Assistant Coupon Reader', 'assistant-reader-271@test.local'),
 ('97e30000-0000-4000-8000-000000000004', '97e20000-0000-4000-8000-000000000005', 'active', 'Assistant Owner', 'assistant-owner-271@test.local');

insert into identity.roles (code, name_ar, name_en, is_system)
values ('assistant_coupon_reader_test', 'قارئ كوبونات اختبار', 'Assistant Coupon Reader Test', false);

insert into identity.staff_roles (staff_id, role_id, branch_id)
select '97e30000-0000-4000-8000-000000000001', id, '97e10000-0000-4000-8000-000000000001' from identity.roles where code = 'branch_manager';
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '97e30000-0000-4000-8000-000000000002', id, null from identity.roles where code = 'owner';
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '97e30000-0000-4000-8000-000000000003', id, '97e10000-0000-4000-8000-000000000001' from identity.roles where code = 'assistant_coupon_reader_test';
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '97e30000-0000-4000-8000-000000000004', id, null from identity.roles where code = 'owner';

-- The migration creates a read permission but grants it to no role.
do $$ begin
  if exists (
    select 1 from identity.role_permissions rp
    join identity.permissions p on p.id = rp.permission_id
    where p.code = 'coupons.read'
  ) then raise exception 'FAIL: coupons.read was automatically granted'; end if;
end $$;

insert into identity.role_permissions (role_id, permission_id)
select r.id, p.id from identity.roles r, identity.permissions p
where (r.code = 'branch_manager' and p.code = 'customers.read')
   or (r.code = 'branch_manager' and p.code = 'orders.read')
   or (r.code = 'assistant_coupon_reader_test' and p.code in ('customers.read','coupons.read'))
on conflict do nothing;

insert into orders.orders (
  id, order_number, user_id, branch_id, fulfillment_type, status, payment_status,
  subtotal, discount_total, delivery_fee, tax_total, grand_total, currency_code,
  customer_note, placed_at, loyalty_points_earned, idempotency_key, order_source
) values
 ('97e40000-0000-4000-8000-000000000001', 'AI-SCOPE-271-ORDER-1', '97e20000-0000-4000-8000-000000000001', '97e10000-0000-4000-8000-000000000001', 'pickup', 'confirmed', 'unpaid', 10, 0, 0, 0, 10, 'SAR', '', now() - interval '1 day', 0, 'ai-scope-271-order-1', 'online'),
 ('97e40000-0000-4000-8000-000000000002', 'AI-SCOPE-271-ORDER-2', '97e20000-0000-4000-8000-000000000001', '97e10000-0000-4000-8000-000000000002', 'pickup', 'confirmed', 'unpaid', 90, 0, 0, 0, 90, 'SAR', '', now(), 0, 'ai-scope-271-order-2', 'online');

insert into marketing.coupons (id, code, title_ar, title_en, discount_type, discount_value)
values ('97e50000-0000-4000-8000-000000000001', 'AI-SCOPE-271-COUPON', 'كوبون اختبار نطاق', 'Scope Test Coupon', 'percentage', 10);
insert into marketing.coupon_redemptions (id, coupon_id, user_id, order_id, amount, created_at)
values
 ('97e60000-0000-4000-8000-000000000001', '97e50000-0000-4000-8000-000000000001', '97e20000-0000-4000-8000-000000000001', '97e40000-0000-4000-8000-000000000001', 1, now() - interval '1 day'),
 ('97e60000-0000-4000-8000-000000000002', '97e50000-0000-4000-8000-000000000001', '97e20000-0000-4000-8000-000000000001', '97e40000-0000-4000-8000-000000000002', 4, now());

set local role authenticated;

-- Branch 1 sees only its own order and redemption even when the same customer
-- also ordered at branch 2. The supplied user cannot choose a branch_id.
select set_config('request.jwt.claims', '{"sub":"97e20000-0000-4000-8000-000000000002","role":"authenticated","aud":"authenticated"}', true);
do $$ declare d jsonb; o jsonb; begin
  d := public.admin_assistant_customer_directory('Assistant Scope Customer');
  if jsonb_array_length(d->'rows') <> 1
     or (d->'rows'->0->>'orders_count')::int <> 1
     or (d->'rows'->0->>'total_spent')::numeric <> 10 then
    raise exception 'FAIL: branch-only customer aggregates escaped scope: %', d;
  end if;
  if (d->'rows'->0) ? 'email' or (d->'rows'->0) ? 'phone' then
    raise exception 'FAIL: assistant directory returned customer contact data: %', d;
  end if;
  if jsonb_array_length(public.admin_assistant_customer_directory('%%')->'rows') <> 0 then
    raise exception 'FAIL: SQL wildcard characters broadened customer search';
  end if;
  d := public.admin_assistant_order_search('AI-SCOPE-271-ORDER-1');
  if jsonb_array_length(d->'rows') <> 1
     or d->'rows'->0->>'order_number' <> 'AI-SCOPE-271-ORDER-1'
     or d->'rows'->0->>'customer_name' <> 'Assistant Scope Customer'
     or (d->'rows'->0) ? 'phone' then
    raise exception 'FAIL: branch-only order search is not safely scoped: %', d;
  end if;
  o := public.admin_assistant_customer_orders('97e20000-0000-4000-8000-000000000001');
  if jsonb_array_length(o) <> 1 or o->0->>'branch_id' <> '97e10000-0000-4000-8000-000000000001' then
    raise exception 'FAIL: branch-only order detail escaped scope: %', o;
  end if;
  begin
    perform public.admin_assistant_coupon_report();
    raise exception 'FAIL: user without coupons.read read coupon report';
  exception when others then
    if sqlstate <> '42501' then raise; end if;
  end;
end $$;

-- A separately assigned read-only coupon permission reads scoped redemptions,
-- while the existing settings.write mutation remains denied.
select set_config('request.jwt.claims', '{"sub":"97e20000-0000-4000-8000-000000000004","role":"authenticated","aud":"authenticated"}', true);
do $$ declare c jsonb; begin
  c := public.admin_assistant_coupon_report();
  if (c->>'redemptions')::int <> 1 or (c->>'discount_given')::numeric <> 1 then
    raise exception 'FAIL: coupon report escaped branch scope: %', c;
  end if;
  begin
    perform public.admin_set_coupon_active('97e50000-0000-4000-8000-000000000001', false);
    raise exception 'FAIL: coupon-read permission allowed coupon mutation';
  exception when others then
    if sqlstate <> '42501' then raise; end if;
  end;
  begin
    perform public.admin_assistant_pos_order_create(
      null,
      '[]'::jsonb,
      null,
      'assistant-order-no-pos-permission',
      null,
      null,
      0
    );
    raise exception 'FAIL: read-only assistant permission created a POS order';
  exception when others then
    if sqlstate <> '42501' then raise; end if;
  end;
end $$;

-- An owner with its supported all-branch assignment sees both branches.
select set_config('request.jwt.claims', '{"sub":"97e20000-0000-4000-8000-000000000003","role":"authenticated","aud":"authenticated"}', true);
do $$ declare d jsonb; c jsonb; begin
  d := public.admin_assistant_customer_directory('Assistant Scope Customer');
  c := public.admin_assistant_coupon_report();
  if (d->'rows'->0->>'orders_count')::int <> 2
     or (d->'rows'->0->>'total_spent')::numeric <> 100
     or (c->>'redemptions')::int <> 2
     or (c->>'discount_given')::numeric <> 5 then
    raise exception 'FAIL: multi-branch scope was not combined correctly: %, %', d, c;
  end if;
end $$;

-- Owner scope sees the same complete fixture.
select set_config('request.jwt.claims', '{"sub":"97e20000-0000-4000-8000-000000000005","role":"authenticated","aud":"authenticated"}', true);
do $$ declare d jsonb; begin
  d := public.admin_assistant_customer_directory('Assistant Scope Customer');
  if (d->'rows'->0->>'orders_count')::int <> 2 then
    raise exception 'FAIL: all-branch owner scope was not honored: %', d;
  end if;
  d := public.admin_assistant_order_search('Assistant Scope Customer');
  if jsonb_array_length(d->'rows') <> 2 then
    raise exception 'FAIL: scoped order name search was not complete: %', d;
  end if;
end $$;

rollback;
