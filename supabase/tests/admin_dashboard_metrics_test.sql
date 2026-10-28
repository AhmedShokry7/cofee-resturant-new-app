-- admin_dashboard_metrics_test.sql
-- Behaviour test for migrations 202 and 203: public.admin_dashboard_metrics()
-- reports the numbers the dashboard tiles render, for the branches the caller
-- manages, with cancelled and out-of-window orders kept out of the money; 203
-- adds the thirty-day series, the channel split, recent orders and the editable
-- monthly target, each with its own case below.
--
-- STATUS: EXECUTED, ALL NINE CASES PASSED, EVERY FIXTURE ROLLED BACK.
--
-- Plain SQL for the Supabase SQL Editor or psql, like the other tests here: one
-- transaction, every fixture rolled back at the end, and the read executed as a
-- real authenticated role with real JWT claims, so the permission and scope arms
-- of the function are tested rather than asserted about.
--
-- WHY THIS NEEDS A TEST AT ALL. The dashboard replaces a "قريبًا" placeholder, so
-- nothing else in the app has ever compared these numbers with the rows. Three
-- of its rules are invisible in a UI rehearsal: a branch manager must not see
-- the brand's total, a cancelled order must not inflate today's revenue, and an
-- order from last week must not stay in the seven-day breakdown. Each one is
-- fixed by a fixture that would pass if the rule were dropped.
--
-- WHAT THE FIXTURES SET UP
--   A    the branch the manager of a single branch manages.
--   B    another branch with one order today, so a missing scope predicate is
--        visible as a wrong number instead of passing silently.
--   A1 completed today 100.00, lines Latte x4 and Mocha x2
--   A2 CANCELLED today 50.00, line Cold Brew x9   (must move no number except
--        the all-time count, and must not reach top_products)
--   A3 preparing today 30.00, line Tea x3
--   A4 completed just before this Riyadh midnight, 40.00, line Water x20
--        (yesterday, and inside the seven-day window)
--   A5 completed eight days ago, 10.00, line Old Item x50 (outside the window;
--      its quantity is the largest in the fixture, so a loose window filter
--      would put it first in top_products)
--   B1 completed today 70.00, at branch B
--   MGR  a manager whose role row has NO branch, so it manages everything.
--   BM   a branch_manager whose role row is bound to A.
--   NOROLE an active staff member with no role row at all - the refusal.
--
-- PREREQUISITES: 004/005/007/011/012/013 (identity, RBAC matrix, branches,
-- orders), 137, 141, 202, 203.

begin;

-- ---------------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------------
insert into core.branches (id, brand_id, code, name_ar, name_en, address, is_active, settings)
values
  ('ad000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000001',
   'ADDBA', 'فرع اختبار اللوحة أ', 'ADB Test A', 'addr1', true, '{}'::jsonb),
  ('ad000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000001',
   'ADDBB', 'فرع اختبار اللوحة ب', 'ADB Test B', 'addr2', true, '{}'::jsonb);

insert into auth.users (id, email)
values
  ('ad100000-0000-4000-8000-000000000001', 'adb-manager@test.local'),
  ('ad100000-0000-4000-8000-000000000002', 'adb-branch-manager@test.local'),
  ('ad100000-0000-4000-8000-000000000003', 'adb-no-role@test.local'),
  ('ad100000-0000-4000-8000-000000000004', 'adb-customer@test.local');

insert into identity.staff_members (id, user_id, status, full_name, email)
values
  ('ad200000-0000-4000-8000-000000000001', 'ad100000-0000-4000-8000-000000000001', 'active', 'ADB Manager', 'adb-manager@test.local'),
  ('ad200000-0000-4000-8000-000000000002', 'ad100000-0000-4000-8000-000000000002', 'active', 'ADB Branch Manager', 'adb-branch-manager@test.local'),
  ('ad200000-0000-4000-8000-000000000003', 'ad100000-0000-4000-8000-000000000003', 'active', 'ADB Unroled Staff', 'adb-no-role@test.local');

-- The manager answers for the whole brand: no branch on the role row.
insert into identity.staff_roles (staff_id, role_id, branch_id)
select 'ad200000-0000-4000-8000-000000000001', r.id, null
from identity.roles r where r.code = 'manager';

insert into identity.staff_roles (staff_id, role_id, branch_id)
select 'ad200000-0000-4000-8000-000000000002', r.id, 'ad000000-0000-4000-8000-000000000001'::uuid
from identity.roles r where r.code = 'branch_manager';

-- Day boundaries written exactly as the function writes them, so the fixtures
-- land in the same buckets whichever hour the test is run at.
insert into orders.orders (
  id, order_number, branch_id, fulfillment_type, status, payment_status,
  subtotal, discount_total, delivery_fee, tax_total, grand_total, currency_code,
  loyalty_points_earned, idempotency_key, placed_at
) values
  ('ad300000-0000-4000-8000-000000000001', 'TEST-ADB-1',
   'ad000000-0000-4000-8000-000000000001', 'pickup', 'completed', 'paid',
   100.00, 0.00, 0.00, 0.00, 100.00, 'SAR', 0, 'adb-test-key-1', now()),
  ('ad300000-0000-4000-8000-000000000002', 'TEST-ADB-2',
   'ad000000-0000-4000-8000-000000000001', 'pickup', 'cancelled', 'failed',
   50.00, 0.00, 0.00, 0.00, 50.00, 'SAR', 0, 'adb-test-key-2', now()),
  ('ad300000-0000-4000-8000-000000000003', 'TEST-ADB-3',
   'ad000000-0000-4000-8000-000000000001', 'dine_in', 'preparing', 'paid',
   30.00, 0.00, 0.00, 0.00, 30.00, 'SAR', 0, 'adb-test-key-3', now()),
  ('ad300000-0000-4000-8000-000000000004', 'TEST-ADB-4',
   'ad000000-0000-4000-8000-000000000001', 'pickup', 'completed', 'paid',
   40.00, 0.00, 0.00, 0.00, 40.00, 'SAR', 0, 'adb-test-key-4',
   (date_trunc('day', now() at time zone 'Asia/Riyadh') at time zone 'Asia/Riyadh') - interval '1 hour'),
  ('ad300000-0000-4000-8000-000000000005', 'TEST-ADB-5',
   'ad000000-0000-4000-8000-000000000001', 'pickup', 'completed', 'paid',
   10.00, 0.00, 0.00, 0.00, 10.00, 'SAR', 0, 'adb-test-key-5',
   (date_trunc('day', now() at time zone 'Asia/Riyadh') at time zone 'Asia/Riyadh') - interval '8 days'),
  ('ad300000-0000-4000-8000-000000000006', 'TEST-ADB-6',
   'ad000000-0000-4000-8000-000000000002', 'pickup', 'completed', 'paid',
   70.00, 0.00, 0.00, 0.00, 70.00, 'SAR', 0, 'adb-test-key-6', now());

insert into orders.order_items (
  id, order_id, product_id, option_group_name_ar, option_group_name_en,
  product_name_ar, product_name_en, sku_snapshot, unit_price, quantity,
  line_total, note, created_at, options_key, discount_total,
  bundle_name_ar, bundle_name_en, product_discount_total
) values
  ('ad400000-0000-4000-8000-000000000001', 'ad300000-0000-4000-8000-000000000001', null,
   '', '', 'لاتيه', 'Latte', 'ADB-LATTE', 10.00, 4, 40.00, '', now(), '', 0.00, '', '', 0.00),
  ('ad400000-0000-4000-8000-000000000002', 'ad300000-0000-4000-8000-000000000001', null,
   '', '', 'موكا', 'Mocha', 'ADB-MOCHA', 15.00, 2, 30.00, '', now(), '', 0.00, '', '', 0.00),
  ('ad400000-0000-4000-8000-000000000003', 'ad300000-0000-4000-8000-000000000002', null,
   '', '', 'كولد برو', 'Cold Brew', 'ADB-COLD', 20.00, 9, 180.00, '', now(), '', 0.00, '', '', 0.00),
  ('ad400000-0000-4000-8000-000000000004', 'ad300000-0000-4000-8000-000000000003', null,
   '', '', 'شاي', 'Tea', 'ADB-TEA', 10.00, 3, 30.00, '', now(), '', 0.00, '', '', 0.00),
  ('ad400000-0000-4000-8000-000000000005', 'ad300000-0000-4000-8000-000000000004', null,
   '', '', 'ماء', 'Water', 'ADB-WATER', 5.00, 20, 100.00, '', now(), '', 0.00, '', '', 0.00),
  ('ad400000-0000-4000-8000-000000000006', 'ad300000-0000-4000-8000-000000000005', null,
   '', '', 'قديم', 'Old Item', 'ADB-OLD', 10.00, 50, 500.00, '', now(), '', 0.00, '', '', 0.00);

-- ---------------------------------------------------------------------------
-- The branch manager's answer, parked before the role changes back: only the
-- last row-returning statement of the run comes back through the CLI.
-- ---------------------------------------------------------------------------
set local role authenticated;

select set_config('request.jwt.claims',
  '{"sub":"ad100000-0000-4000-8000-000000000002","role":"authenticated","aud":"authenticated"}', true);

select set_config('test.adb_branch',
  public.admin_dashboard_metrics()::text, true);

reset role;

-- ---------------------------------------------------------------------------
-- 1. For the branch manager every money number is branch A only, and the
--    cancelled order moves nothing but the all-time count.
-- ---------------------------------------------------------------------------
do $$
declare
  payload jsonb := current_setting('test.adb_branch')::jsonb;
  day_start timestamptz := (
    date_trunc('day', now() at time zone 'Asia/Riyadh') at time zone 'Asia/Riyadh'
  );
begin
  if (payload ->> 'today_orders')::int <> 2 then
    raise exception 'FAIL 1: today counts % orders, the branch holds 2 uncancelled ones',
      payload ->> 'today_orders';
  end if;
  if (payload ->> 'today_revenue')::numeric <> 130.00 then
    raise exception 'FAIL 1: today revenue is %, the uncancelled orders of the day total 130.00',
      payload ->> 'today_revenue';
  end if;
  if (payload ->> 'average_order_value')::numeric <> 65.00 then
    raise exception 'FAIL 1: the average is %, 130.00 over 2 orders is 65.00',
      payload ->> 'average_order_value';
  end if;
  if (payload ->> 'yesterday_orders')::int <> 1
     or (payload ->> 'yesterday_revenue')::numeric <> 40.00 then
    raise exception 'FAIL 1: yesterday reads % orders / % riyals, the fixture holds 1 / 40.00',
      payload ->> 'yesterday_orders', payload ->> 'yesterday_revenue';
  end if;
  if (payload ->> 'active_orders')::int <> 1 then
    raise exception 'FAIL 1: % orders are reported as still open, only the preparing one is',
      payload ->> 'active_orders';
  end if;
  if (payload ->> 'total_orders')::int <> 5 then
    raise exception 'FAIL 1: the all-time count is %, branch A holds 5 orders including the cancelled and the week-old one',
      payload ->> 'total_orders';
  end if;

  -- The same numbers, recomputed from the rows with the rule written out.
  if (payload ->> 'today_revenue')::numeric <> (
    select coalesce(sum(o.grand_total), 0) from orders.orders o
     where o.branch_id = 'ad000000-0000-4000-8000-000000000001'
       and o.placed_at >= day_start
       and o.status <> 'cancelled'
  ) then
    raise exception 'FAIL 1: today revenue disagrees with the rows';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 2. The seven-day breakdown ignores the eight-day-old order and lists the
--    states in the flow's own order, not by volume.
-- ---------------------------------------------------------------------------
do $$
declare
  breakdown jsonb := current_setting('test.adb_branch')::jsonb -> 'status_breakdown';
  reported text;
begin
  if (select string_agg(e ->> 'status', ',' order by ord)
        from jsonb_array_elements(breakdown) with ordinality as se(e, ord))
     <> 'preparing,completed,cancelled' then
    raise exception 'FAIL 2: the breakdown reads %, expected the flow order preparing,completed,cancelled',
      (select string_agg(e ->> 'status', ',' order by ord)
         from jsonb_array_elements(breakdown) with ordinality as se(e, ord));
  end if;

  if breakdown @> '[{"status":"completed","orders":2,"revenue":140.00}]'::jsonb then
    null;
  else
    raise exception 'FAIL 2: completed is not 2 orders / 140.00 inside the week: %', breakdown;
  end if;

  if exists (select 1 from jsonb_array_elements(breakdown) e
              where (e ->> 'orders')::int = 0)
     or (select count(*) from jsonb_array_elements(breakdown)) <> 3 then
    raise exception 'FAIL 2: the breakdown carries an empty state or a state from outside the week: %', breakdown;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 3. top_products keeps the cancelled line and the week-old line out, and caps
--    at five. The week-old item has the largest quantity in the fixture, so a
--    loose window would put it first instead of leaving.
-- ---------------------------------------------------------------------------
do $$
declare
  payload jsonb := current_setting('test.adb_branch')::jsonb;
  top jsonb := payload -> 'top_products';
  names text;
begin
  select string_agg(e ->> 'product_name_en', ',' order by ord)
    into names
    from jsonb_array_elements(top) with ordinality as te(e, ord);

  if names <> 'Water,Latte,Tea,Mocha' then
    raise exception 'FAIL 3: the best sellers read %, expected Water,Latte,Tea,Mocha', names;
  end if;

  if jsonb_array_length(top) > 5 then
    raise exception 'FAIL 3: the panel lists % products, it must stop at five',
      jsonb_array_length(top);
  end if;

  if exists (select 1 from jsonb_array_elements(top) e
              where e ->> 'product_name_en' in ('Cold Brew', 'Old Item')) then
    raise exception 'FAIL 3: a cancelled or week-old line reached the best sellers';
  end if;

  if ((top -> 0) ->> 'quantity')::int <> 20
     or ((top -> 0) ->> 'revenue')::numeric <> 100.00 then
    raise exception 'FAIL 3: the leading product reads % units / % riyals, the rows hold 20 / 100.00',
      (top -> 0) ->> 'quantity', (top -> 0) ->> 'revenue';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 4. The brand manager answers for every branch, so the brand must be wider
--    than the single branch and equal to the whole table. The live project
--    holds real orders beyond these fixtures, so the expectation is recomputed
--    from the rows instead of counted from the fixture list.
-- ---------------------------------------------------------------------------
set local role authenticated;

select set_config('request.jwt.claims',
  '{"sub":"ad100000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);

select set_config('test.adb_brand',
  public.admin_dashboard_metrics()::text, true);

reset role;

do $$
declare
  payload jsonb := current_setting('test.adb_brand')::jsonb;
  branch jsonb := current_setting('test.adb_branch')::jsonb;
  day_start timestamptz := (
    date_trunc('day', now() at time zone 'Asia/Riyadh') at time zone 'Asia/Riyadh'
  );
begin
  if (payload ->> 'total_orders')::int
     <> (select count(*) from orders.orders where placed_at is not null) then
    raise exception 'FAIL 4: the brand reports % orders while the table holds %',
      payload ->> 'total_orders',
      (select count(*) from orders.orders where placed_at is not null);
  end if;

  if (payload ->> 'today_revenue')::numeric <> (
    select coalesce(sum(o.grand_total), 0) from orders.orders o
     where o.placed_at >= day_start and o.status <> 'cancelled'
  ) then
    raise exception 'FAIL 4: the brand reports % for today, the rows total %',
      payload ->> 'today_revenue',
      (select coalesce(sum(o.grand_total), 0) from orders.orders o
        where o.placed_at >= day_start and o.status <> 'cancelled');
  end if;

  -- The fixture branch is new, so nothing but these rows sit in it: its own
  -- numbers stay exactly as case 1 read them, and they must not be the brand's.
  if (branch ->> 'today_revenue')::numeric <> 130.00 then
    raise exception 'FAIL 4: the single branch stopped reporting its own 130.00';
  end if;
  if (payload ->> 'today_revenue')::numeric = (branch ->> 'today_revenue')::numeric then
    raise exception 'FAIL 4: the brand and the single branch report the same money, so one of them ignores can_manage_branch';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 5. The guards: a staff member with no role row, a customer, and the anon role
--    are all refused with 42501.
-- ---------------------------------------------------------------------------
set local role authenticated;

select set_config('request.jwt.claims',
  '{"sub":"ad100000-0000-4000-8000-000000000003","role":"authenticated","aud":"authenticated"}', true);

do $$
begin
  begin
    perform public.admin_dashboard_metrics();
    raise exception 'FAIL 5a: a staff member with no role read the dashboard metrics';
  exception when others then
    if sqlstate <> '42501' then raise; end if;
  end;
end $$;

select set_config('request.jwt.claims',
  '{"sub":"ad100000-0000-4000-8000-000000000004","role":"authenticated","aud":"authenticated"}', true);

do $$
begin
  begin
    perform public.admin_dashboard_metrics();
    raise exception 'FAIL 5b: a customer read the dashboard metrics';
  exception when others then
    if sqlstate <> '42501' then raise; end if;
  end;
end $$;

reset role;

set local role anon;

select set_config('request.jwt.claims', '{}', true);

do $$
begin
  begin
    perform public.admin_dashboard_metrics();
    raise exception 'FAIL 5c: the anon role read the dashboard metrics';
  exception when others then
    if sqlstate <> '42501' then raise; end if;
  end;
end $$;

reset role;

-- ---------------------------------------------------------------------------
-- 6. The thirty-day series is dense: one bucket per day, oldest first, today
--    last, and the days with no order read zero instead of disappearing. A5
--    (eight days ago) and A4 (yesterday) must land in their own buckets, and
--    the cancelled A2 must leave the series untouched.
-- ---------------------------------------------------------------------------
do $$
declare
  payload jsonb := current_setting('test.adb_branch')::jsonb;
  series jsonb := payload -> 'sales_series';
  day_start timestamptz := (
    date_trunc('day', now() at time zone 'Asia/Riyadh') at time zone 'Asia/Riyadh'
  );
  series_total numeric;
  row_total numeric;
begin
  if jsonb_array_length(series) <> 30 then
    raise exception 'FAIL 6: the series holds % buckets, thirty days were asked for',
      jsonb_array_length(series);
  end if;

  if (series -> 29) ->> 'date'
     <> to_char(day_start at time zone 'Asia/Riyadh', 'YYYY-MM-DD') then
    raise exception 'FAIL 6: the last bucket is %, today should be last',
      (series -> 29) ->> 'date';
  end if;

  if (series -> 29) ->> 'revenue' <> '130.00'
     or ((series -> 29) ->> 'orders')::int <> 2 then
    raise exception 'FAIL 6: today reads % / %, the uncancelled rows total 130.00 / 2',
      (series -> 29) ->> 'revenue', (series -> 29) ->> 'orders';
  end if;

  if (series -> 28) ->> 'revenue' <> '40.00' then
    raise exception 'FAIL 6: yesterday reads %, the fixture holds 40.00',
      (series -> 28) ->> 'revenue';
  end if;

  if (series -> 21) ->> 'date'
       <> to_char((day_start - interval '8 days') at time zone 'Asia/Riyadh', 'YYYY-MM-DD')
     or (series -> 21) ->> 'revenue' <> '10.00' then
    raise exception 'FAIL 6: the eight-day-old order is not in its own bucket: %',
      series -> 21;
  end if;

  if exists (
    select 1 from jsonb_array_elements(series) e
     where (e ->> 'orders')::int < 0
        or (e ->> 'revenue')::numeric < 0
  ) then
    raise exception 'FAIL 6: a bucket carries a negative value';
  end if;

  select coalesce(sum((e ->> 'revenue')::numeric), 0)
    into series_total
    from jsonb_array_elements(series) e;

  select coalesce(sum(o.grand_total), 0)
    into row_total
    from orders.orders o
   where o.branch_id = 'ad000000-0000-4000-8000-000000000001'
     and o.placed_at >= day_start - interval '29 days'
     and o.status <> 'cancelled';

  if series_total <> row_total then
    raise exception 'FAIL 6: the series adds up to %, the rows hold %', series_total, row_total;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 7. The channel split covers thirty days, drops the cancelled order, and sorts
--    by volume. Branch A holds three pickup orders (100 + 40 + 10) and one
--    dine_in (30); the cancelled pickup would have made it four.
-- ---------------------------------------------------------------------------
do $$
declare
  channels jsonb := current_setting('test.adb_branch')::jsonb -> 'channels';
begin
  if (select string_agg(e ->> 'channel', ',' order by ord)
        from jsonb_array_elements(channels) with ordinality as ce(e, ord))
     <> 'pickup,dine_in' then
    raise exception 'FAIL 7: the channels read %, expected pickup,dine_in',
      (select string_agg(e ->> 'channel', ',' order by ord)
         from jsonb_array_elements(channels) with ordinality as ce(e, ord));
  end if;

  if (channels -> 0) ->> 'orders' <> '3' or (channels -> 0) ->> 'revenue' <> '150.00' then
    raise exception 'FAIL 7: pickup reads % / %, the rows hold 3 / 150.00',
      (channels -> 0) ->> 'orders', (channels -> 0) ->> 'revenue';
  end if;

  if (channels -> 1) ->> 'orders' <> '1' or (channels -> 1) ->> 'revenue' <> '30.00' then
    raise exception 'FAIL 7: dine_in reads % / %, the rows hold 1 / 30.00',
      (channels -> 1) ->> 'orders', (channels -> 1) ->> 'revenue';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 8. Recent orders: newest first, the cancelled one stays (it happened), the
--    oldest two sit at the end in placed_at order, and each row carries the
--    line count the table prints next to the order number.
-- ---------------------------------------------------------------------------
do $$
declare
  payload jsonb := current_setting('test.adb_branch')::jsonb;
  recent jsonb := payload -> 'recent_orders';
begin
  if jsonb_array_length(recent) <> 5 then
    raise exception 'FAIL 8: the recent list holds % of the branch''s 5 orders',
      jsonb_array_length(recent);
  end if;

  if (recent -> 0) ->> 'placed_at' < (recent -> 1) ->> 'placed_at'
     or (recent -> 1) ->> 'placed_at' < (recent -> 2) ->> 'placed_at' then
    raise exception 'FAIL 8: the recent list is not sorted newest first';
  end if;

  if (recent -> 3) ->> 'order_number' <> 'TEST-ADB-4'
     or (recent -> 4) ->> 'order_number' <> 'TEST-ADB-5' then
    raise exception 'FAIL 8: the oldest rows read % and %, expected TEST-ADB-4 then TEST-ADB-5',
      (recent -> 3) ->> 'order_number', (recent -> 4) ->> 'order_number';
  end if;

  if not exists (
    select 1 from jsonb_array_elements(recent) e
     where e ->> 'order_number' = 'TEST-ADB-2' and e ->> 'status' = 'cancelled'
  ) then
    raise exception 'FAIL 8: the cancelled order is missing from the recent list';
  end if;

  if not exists (
    select 1 from jsonb_array_elements(recent) e
     where e ->> 'order_number' = 'TEST-ADB-1' and (e ->> 'items_count')::int = 2
  ) then
    raise exception 'FAIL 8: TEST-ADB-1 does not report its two lines: %', recent;
  end if;

  if (recent -> 0) ->> 'customer_name' is not null then
    raise exception 'FAIL 8: an order with no customer invented the name %',
      (recent -> 0) ->> 'customer_name';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 9. Week windows. Today and yesterday are this week (130 + 40); the
--    eight-day-old order is the only row in the previous seven-day window and
--    must be counted there, once, not in both.
-- ---------------------------------------------------------------------------
do $$
declare
  payload jsonb := current_setting('test.adb_branch')::jsonb;
begin
  if (payload ->> 'week_orders')::int <> 3
     or (payload ->> 'week_revenue')::numeric <> 170.00 then
    raise exception 'FAIL 9: this week reads % / %, the rows hold 3 / 170.00',
      payload ->> 'week_orders', payload ->> 'week_revenue';
  end if;

  if (payload ->> 'prev_week_orders')::int <> 1
     or (payload ->> 'prev_week_revenue')::numeric <> 10.00 then
    raise exception 'FAIL 9: last week reads % / %, the eight-day-old row holds 1 / 10.00',
      payload ->> 'prev_week_orders', payload ->> 'prev_week_revenue';
  end if;

  if payload ->> 'monthly_revenue_target' is not null then
    raise exception 'FAIL 9: the branch manager reads a company target: %',
      payload ->> 'monthly_revenue_target';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 10. The monthly target: the brand manager writes it, reads it back, and the
--     write is audited; an unset target reads null instead of a made-up number;
--     a branch manager cannot write it even when handed settings.write, because
--     the target is company-wide.
-- ---------------------------------------------------------------------------
set local role authenticated;

select set_config('request.jwt.claims',
  '{"sub":"ad100000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);

do $$
declare
  before_row jsonb;
  written jsonb;
begin
  select s.value into before_row
    from core.app_settings s where s.key = 'monthly_revenue_target';
  perform set_config('test.adb_old_target', coalesce(before_row::text, ''), true);

  written := public.admin_set_revenue_target(33500);

  if written ->> 'monthly_revenue_target' <> '33500.00' then
    raise exception 'FAIL 10: the write returned %, expected 33500.00',
      written ->> 'monthly_revenue_target';
  end if;

  if (select s.value #>> '{}' from core.app_settings s
       where s.key = 'monthly_revenue_target') <> '33500.00' then
    raise exception 'FAIL 10: the target did not reach core.app_settings';
  end if;

  if public.admin_dashboard_metrics() ->> 'monthly_revenue_target' <> '33500.00' then
    raise exception 'FAIL 10: the dashboard does not read the target it stores';
  end if;

  written := public.admin_set_revenue_target(null);

  if written ->> 'monthly_revenue_target' is not null
     or exists (select 1 from core.app_settings where key = 'monthly_revenue_target') then
    raise exception 'FAIL 10: clearing the target left %', written;
  end if;

  if public.admin_dashboard_metrics() ->> 'monthly_revenue_target' is not null then
    raise exception 'FAIL 10: a cleared target still shows on the dashboard';
  end if;

  begin
    perform public.admin_set_revenue_target(-1);
    raise exception 'FAIL 10: a negative target was accepted';
  exception when sqlstate '22003' then
    null;
  end;
end $$;

reset role;

-- The audit row is read here, not above: reading identity.audit_log needs
-- audit.read, which the manager role does not hold.
do $$
declare
  old_target text := current_setting('test.adb_old_target');
begin
  if not exists (
    select 1 from identity.audit_log a
     where a.action = 'core.revenue_target.update'
       and a.new_values = '33500.00'::jsonb
       and coalesce(a.old_values::text, '') = old_target
  ) then
    raise exception 'FAIL 10: the target write left no audit row';
  end if;

  if (select count(*) from identity.audit_log
       where action = 'core.revenue_target.update'
         and new_values is null) <> 1 then
    raise exception 'FAIL 10: clearing the target left no audit row';
  end if;
end $$;

reset role;

-- A branch manager is given settings.write on purpose: the refusal under test
-- is the scope check, not the permission check.
insert into identity.role_permissions (role_id, permission_id)
select r.id, p.id
  from identity.roles r
  join identity.permissions p on p.code = 'settings.write'
 where r.code = 'branch_manager'
on conflict do nothing;

set local role authenticated;

select set_config('request.jwt.claims',
  '{"sub":"ad100000-0000-4000-8000-000000000002","role":"authenticated","aud":"authenticated"}', true);

do $$
begin
  begin
    perform public.admin_set_revenue_target(1000);
    raise exception 'FAIL 10: a branch manager set a company-wide target';
  exception when others then
    if sqlstate <> '42501' or sqlerrm not like '%company-wide%' then raise; end if;
  end;
end $$;

reset role;

-- Everything above is a fixture inside this transaction.
rollback;
