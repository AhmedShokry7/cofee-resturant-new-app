-- notification_paid_event_test.sql
-- Behaviour test for supabase/proposals/217_notification_write_immunity_and_paid_event.PROPOSED.sql.
--
-- STATUS: WRITTEN, NOT RUN.
--   The CLI (`supabase db query`) and the direct query helper both answered
--   `401 Invalid access token` against webzzasosevzymftgszn on 2026-10-31, so
--   nothing below has been executed against any database. It is written from the
--   migration chain (011, 014, 016, 027, 030, 114, 159, 170, 175, 211) and from
--   supabase/functions/tap-webhook/index.ts. Do NOT treat 217 as applicable
--   until this file has been run whole, exactly as written, inside one
--   transaction that ends in `rollback;` and its report row has been read.
--   Run it with psql against an isolated, non-production database:
--     psql "$DATABASE_URL" -f supabase/tests/notification_paid_event_test.sql
--
-- WHAT 217 CLAIMS, AND HOW EACH CLAIM IS CHECKED HERE
--   A  a notification that cannot be written does not roll back the business
--      write it rides on — for the order status, the points ledger, the
--      subscription status and the new payment event (sections 3-5, with the
--      blocker of section 2 in place).
--   B  the payment event writes exactly one row, to the order owner, when the
--      order arrives at 'paid' — and no second row on a replay, a repeat of the
--      same value, or a failed → paid round trip (sections 6-7).
--   C  it stays out of everything that is not a payment: an unrelated column
--      update, a walk-in order with no customer, 'pending' and 'failed'
--      (section 8).
--   D  the new trigger function is not callable by anon or PUBLIC, and the
--      roles that reach the write — the service role behind the webhook's PATCH,
--      and the owner behind the admin RPC — can fire it (section 9).
--   E  217 changes nothing else: no other notification type appears, no
--      constraint, policy or index moves (section 10).
--
-- THE FORCED FAILURE IN SECTION 2
--   Section A cannot be proved by reading the wrapper: the notification INSERT
--   succeeds in a healthy database, so the exception block never runs and the
--   test would pass with or without it. It is proved by making the INSERT raise
--   on purpose — one temporary BEFORE trigger on engagement.notifications that
--   refuses every row — and then attempting each business write. Without the
--   wrapper the statement dies with 217's own message and the order row keeps
--   its old status; with it, the row changes and no notification exists. The
--   blocker is dropped before section 6 so the payment event is measured on a
--   healthy table, and the whole file is rolled back regardless.
--
-- THE JOURNAL IS A GUC, NOT A TABLE
--   Same reason 216's test gives: the project runs an `ensure_rls` event trigger
--   on ddl_command_end that turns RLS on for tables a script creates, so a
--   journal table would need a grant and an un-turn. `set_config(..., true)` is
--   transaction-local, readable by every role in the file, and the rollback
--   takes it with everything else.

\set ON_ERROR_STOP on

begin;

-- ---------------------------------------------------------------------------
-- 0. Fixtures. One branch, one customer with a profile, one walk-in order, and
--    the three orders the sections below move independently.
-- ---------------------------------------------------------------------------
insert into core.branches (id, brand_id, code, name_ar, name_en, address, is_active, settings)
values ('9e7b0000-0000-4000-8000-000000000001',
        '00000000-0000-4000-8000-000000000001', 'NPE-B1', 'فرع الإشعار', 'Notify Branch 1',
        'addr', true, '{}'::jsonb)
on conflict (id) do nothing;

insert into auth.users (id, email)
values ('9e7c0000-0000-4000-8000-000000000001', 'npe-customer@test.local')
on conflict (id) do nothing;

insert into identity.profiles (id, full_name, email, phone)
values ('9e7c0000-0000-4000-8000-000000000001', 'NPE Customer',
        'npe-customer@test.local', '0590000901')
on conflict (id) do nothing;

-- Three orders for one customer: the status path, the payment path, the replay
-- path. All start unpaid and in the kitchen's 'pending'. All 'pickup' — a
-- 'delivery' row owes a delivery_zone_id (ck_orders_delivery_needs_zone), and
-- this file is about notifications, not zones.
insert into orders.orders (
  id, order_number, user_id, branch_id, fulfillment_type, status, payment_status,
  subtotal, discount_total, delivery_fee, tax_total, grand_total, currency_code,
  customer_note, loyalty_points_earned, idempotency_key
)
values
  ('9e7d0000-0000-4000-8000-000000000001', 'TEST-NPE-STATUS',
   '9e7c0000-0000-4000-8000-000000000001', '9e7b0000-0000-4000-8000-000000000001',
   'pickup', 'pending', 'unpaid', 10.00, 0.00, 0.00, 0.00, 10.00, 'SAR', 't', 0, 'npe-status-1'),
  ('9e7d0000-0000-4000-8000-000000000002', 'TEST-NPE-PAID',
   '9e7c0000-0000-4000-8000-000000000001', '9e7b0000-0000-4000-8000-000000000001',
   'pickup', 'pending', 'unpaid', 12.50, 0.00, 0.00, 0.00, 12.50, 'SAR', 't', 0, 'npe-paid-1'),
  ('9e7d0000-0000-4000-8000-000000000003', 'TEST-NPE-REPLAY',
   '9e7c0000-0000-4000-8000-000000000001', '9e7b0000-0000-4000-8000-000000000001',
   'pickup', 'preparing', 'unpaid', 20.00, 0.00, 0.00, 0.00, 20.00, 'SAR', 't', 0, 'npe-replay-1');

-- A walk-in order: no user — orders.orders.user_id lost its NOT NULL at 181:50 —
-- which is the case 175 already refuses for status changes.
insert into orders.orders (
  id, order_number, user_id, branch_id, fulfillment_type, status, payment_status,
  subtotal, discount_total, delivery_fee, tax_total, grand_total, currency_code,
  customer_note, loyalty_points_earned, idempotency_key
)
values ('9e7d0000-0000-4000-8000-000000000004', 'TEST-NPE-WALKIN',
        null, '9e7b0000-0000-4000-8000-000000000001',
        'dine_in', 'completed', 'unpaid', 8.00, 0.00, 0.00, 0.00, 8.00, 'SAR', '', 0,
        'npe-walkin-1');

-- ---------------------------------------------------------------------------
-- 1. 217's own body, verbatim: the three wrapped functions, the new event, the
--    trigger, the grants. Copy it from
--    supabase/proposals/217_notification_write_immunity_and_paid_event.PROPOSED.sql
--    between the two banner lines, or run this test through a wrapper that
--    includes the proposal file. Nothing in section 1 is repeated here so the
--    rehearsal cannot drift from the artifact it is rehearsing.
-- ---------------------------------------------------------------------------
do $$
begin
  perform set_config('test.npe_proposal_loaded',
    case when exists (
      select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
       where n.nspname = 'engagement' and p.proname = 'notify_order_paid'
    ) then 'notify_order_paid exists — proposal body was applied in this transaction'
      else 'ABORT THIS RUN: engagement.notify_order_paid() is missing, so 217 was not loaded before the assertions'
    end, true);
end $$;

-- ---------------------------------------------------------------------------
-- 2. The blocker: the notification table refuses every row it is handed.
--    Only sections 3-5 run under it; it is dropped before section 6.
-- ---------------------------------------------------------------------------
create or replace function public.npe_block_notifications()
returns trigger language plpgsql as $blk$
begin
  raise exception 'npe forced notification failure' using errcode = 'P0001';
end;
$blk$;

create trigger zz_npe_block_notifications
  before insert on engagement.notifications
  for each row execute function public.npe_block_notifications();

-- ---------------------------------------------------------------------------
-- 3. A-1: the order status survives a notification that cannot be written.
-- ---------------------------------------------------------------------------
do $$
declare
  v_status text;
  v_rows integer;
begin
  update orders.orders set status = 'preparing'
   where id = '9e7d0000-0000-4000-8000-000000000001';

  select status into v_status from orders.orders
   where id = '9e7d0000-0000-4000-8000-000000000001';
  select count(*) into v_rows from engagement.notifications
   where dedupe_key = 'order:9e7d0000-0000-4000-8000-000000000001:preparing';

  perform set_config('test.npe_status_under_blocker',
    'status=' || v_status || ' notification_rows=' || v_rows, true);

  if v_status <> 'preparing' then
    raise exception 'FAIL A-1: the order kept its old status — the notification aborted the kitchen write';
  end if;
  if v_rows <> 0 then
    raise exception 'FAIL A-1: a blocked notification was written anyway';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 4. A-2: the points ledger survives the same block.
-- ---------------------------------------------------------------------------
do $$
declare
  v_rows integer;
begin
  insert into loyalty.loyalty_transactions (id, user_id, points, balance_after, reason)
  values ('9e7e0000-0000-4000-8000-000000000001',
          '9e7c0000-0000-4000-8000-000000000001', 25, 25, 'earn_order');

  select count(*) into v_rows from loyalty.loyalty_transactions
   where id = '9e7e0000-0000-4000-8000-000000000001';

  perform set_config('test.npe_loyalty_under_blocker', 'ledger_rows=' || v_rows, true);

  if v_rows <> 1 then
    raise exception 'FAIL A-2: the ledger row rolled back with its notification';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 5. A-3: the payment itself survives the same block — the one that matters
--    most, because it is the money.
-- ---------------------------------------------------------------------------
do $$
declare
  v_payment text;
begin
  update orders.orders set payment_status = 'paid'
   where id = '9e7d0000-0000-4000-8000-000000000003';

  select payment_status into v_payment from orders.orders
   where id = '9e7d0000-0000-4000-8000-000000000003';

  perform set_config('test.npe_payment_under_blocker', 'payment=' || v_payment, true);

  if v_payment <> 'paid' then
    raise exception 'FAIL A-3: a notification refused the payment confirmation';
  end if;
end $$;

drop trigger zz_npe_block_notifications on engagement.notifications;
drop function public.npe_block_notifications();

-- ---------------------------------------------------------------------------
-- 6. B: the paid event writes exactly one row, to the owner, on a healthy table.
-- ---------------------------------------------------------------------------
do $$
declare
  v_row engagement.notifications%rowtype;
  v_rows integer;
begin
  update orders.orders set payment_status = 'paid'
   where id = '9e7d0000-0000-4000-8000-000000000002';

  select count(*) into v_rows from engagement.notifications
   where dedupe_key = 'payment:9e7d0000-0000-4000-8000-000000000002:paid';
  if v_rows <> 1 then
    raise exception 'FAIL B: expected one payment notification, found %', v_rows;
  end if;

  select * into v_row from engagement.notifications
   where dedupe_key = 'payment:9e7d0000-0000-4000-8000-000000000002:paid';

  perform set_config('test.npe_paid_row',
    'user=' || v_row.user_id ||
    ' type=' || v_row.type ||
    ' entity=' || coalesce(v_row.related_entity_type, 'null') ||
    ' id=' || coalesce(v_row.related_entity_id::text, 'null') ||
    ' event=' || coalesce(v_row.payload->>'event', 'null') ||
    ' number=' || coalesce(v_row.payload->>'order_number', 'null') ||
    ' total=' || coalesce(v_row.payload->>'total', 'null') ||
    ' title_ar=' || v_row.title_ar ||
    ' title_en=' || v_row.title_en, true);

  if v_row.user_id <> '9e7c0000-0000-4000-8000-000000000001' then
    raise exception 'FAIL B: the payment message went to someone other than the order owner';
  end if;
  if v_row.type <> 'order_status' or v_row.related_entity_type <> 'order' then
    raise exception 'FAIL B: the row carries a type or entity the constraints and the client do not know';
  end if;
  if v_row.payload->>'event' <> 'payment' then
    raise exception 'FAIL B: the payload lost the field that tells a payment apart from a status change';
  end if;
  -- Every field engagement.enqueue_push() (170:380-394) serialises into the
  -- pg_net body that supabase/functions/send-push reads has to be there, or the
  -- row is an inbox entry the phone never learns about.
  if not (v_row.payload ? 'order_id')
     or not (v_row.payload ? 'order_number')
     or not (v_row.payload ? 'payment_status')
     or not (v_row.payload ? 'total') then
    raise exception 'FAIL B: the payload lost a field the push body carries';
  end if;
  if btrim(v_row.title_ar) = '' or btrim(v_row.title_en) = ''
     or btrim(v_row.body_ar) = '' or btrim(v_row.body_en) = '' then
    raise exception 'FAIL B: a bilingual row is missing one of its four texts';
  end if;
  -- WHAT THIS SECTION CANNOT PROVE: engagement.push_deliveries is written by the
  -- Edge Function after pg_net fires, outside this transaction, so no push count
  -- is asserted here. Calling engagement.enqueue_push() directly would post to
  -- the live webhook and push a real device — that is deliberately not done.
  -- The device side of this event is verified on a real phone, not in this file.
end $$;

-- ---------------------------------------------------------------------------
-- 7. B-2: no second message for the same payment, by any of the three repeat
--    shapes the system can actually produce.
-- ---------------------------------------------------------------------------
do $$
declare
  v_key constant text := 'payment:9e7d0000-0000-4000-8000-000000000002:paid';
  v_rows integer;
begin
  -- (i) the webhook replay: Tap posts the same charge again and the PATCH
  --     writes the value the row already holds.
  update orders.orders set payment_status = 'paid'
   where id = '9e7d0000-0000-4000-8000-000000000002';
  select count(*) into v_rows from engagement.notifications where dedupe_key = v_key;
  if v_rows <> 1 then
    raise exception 'FAIL B-2(i): a paid → paid rewrite produced % rows', v_rows;
  end if;

  -- (ii) a correction round trip: failed, then paid again. The transition is
  --      real, so the WHEN clause lets the function in — and the dedupe key is
  --      what stops the second message.
  update orders.orders set payment_status = 'failed'
   where id = '9e7d0000-0000-4000-8000-000000000002';
  update orders.orders set payment_status = 'paid'
   where id = '9e7d0000-0000-4000-8000-000000000002';
  select count(*) into v_rows from engagement.notifications where dedupe_key = v_key;
  if v_rows <> 1 then
    raise exception 'FAIL B-2(ii): a failed → paid round trip produced % rows', v_rows;
  end if;

  -- (iii) a different column on the same row, which must not reach the trigger
  --       at all.
  update orders.orders set customer_note = 'edited after paying'
   where id = '9e7d0000-0000-4000-8000-000000000002';
  select count(*) into v_rows from engagement.notifications where dedupe_key = v_key;
  if v_rows <> 1 then
    raise exception 'FAIL B-2(iii): an unrelated column update produced % rows', v_rows;
  end if;

  perform set_config('test.npe_replay_rows', v_rows::text, true);
end $$;

-- ---------------------------------------------------------------------------
-- 8. C: who does NOT get a payment message.
-- ---------------------------------------------------------------------------
do $$
declare
  v_rows integer;
begin
  -- The walk-in: nobody to tell.
  update orders.orders set payment_status = 'paid'
   where id = '9e7d0000-0000-4000-8000-000000000004';
  select count(*) into v_rows from engagement.notifications
   where dedupe_key = 'payment:9e7d0000-0000-4000-8000-000000000004:paid';
  if v_rows <> 0 then
    raise exception 'FAIL C: a walk-in order produced a notification for a NULL user';
  end if;

  -- 'pending' and 'failed' say nothing the customer asked to be told.
  update orders.orders set payment_status = 'pending'
   where id = '9e7d0000-0000-4000-8000-000000000001';
  update orders.orders set payment_status = 'failed'
   where id = '9e7d0000-0000-4000-8000-000000000001';
  select count(*) into v_rows from engagement.notifications
   where dedupe_key like 'payment:%';
  perform set_config('test.npe_payment_rows_total', v_rows::text, true);
  if v_rows <> 1 then
    raise exception 'FAIL C: % payment rows exist, expected exactly the one real payment', v_rows;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 9. D: who may fire and call the new function.
-- ---------------------------------------------------------------------------
do $$
begin
  perform set_config('test.npe_grants',
    'anon=' || has_function_privilege('anon', 'engagement.notify_order_paid()', 'execute') ||
    ' authenticated=' || has_function_privilege('authenticated', 'engagement.notify_order_paid()', 'execute') ||
    ' service_role=' || has_function_privilege('service_role', 'engagement.notify_order_paid()', 'execute') ||
    ' owner=' || has_function_privilege('postgres', 'engagement.notify_order_paid()', 'execute'), true);

  if has_function_privilege('anon', 'engagement.notify_order_paid()', 'execute') then
    raise exception 'FAIL D: anon still executes the trigger function through PUBLIC';
  end if;
  -- The webhook PATCH arrives as the service role. Losing this is not a
  -- notification problem, it is a payment problem — see the proposal's
  -- "WHAT BREAKS IF THIS IS WRONG".
  if not has_function_privilege('service_role', 'engagement.notify_order_paid()', 'execute') then
    raise exception 'FAIL D: service_role cannot fire the trigger, so tap-webhook would lose the payment confirmation';
  end if;
end $$;

-- The write path the webhook actually uses, replayed as that role.
set local role service_role;
update orders.orders set payment_status = 'paid'
 where id = '9e7d0000-0000-4000-8000-000000000001';
reset role;

do $$
declare
  v_rows integer;
  v_payment text;
begin
  select count(*) into v_rows from engagement.notifications
   where dedupe_key = 'payment:9e7d0000-0000-4000-8000-000000000001:paid';
  select payment_status into v_payment from orders.orders
   where id = '9e7d0000-0000-4000-8000-000000000001';
  perform set_config('test.npe_service_role_path',
    'payment=' || v_payment || ' notification_rows=' || v_rows, true);
  if v_payment <> 'paid' then
    raise exception 'FAIL D: the service-role write did not land';
  end if;
  if v_rows <> 1 then
    raise exception 'FAIL D: the service-role path produced % rows, expected 1', v_rows;
  end if;
end $$;

-- A direct call by anon is refused — and the answer it gets is recorded, the way
-- 216's run recorded the difference between 42501 and 0A000.
set local role anon;
do $$
begin
  perform engagement.notify_order_paid();
  raise exception 'FAIL D: anon called the trigger function directly';
exception when others then
  perform set_config('test.npe_anon_direct_call', sqlstate, true);
end $$;
reset role;

-- ---------------------------------------------------------------------------
-- 10. E: nothing else moved. 217 adds one dedupe family and wraps three
--     bodies; it must not have created a second notification shape anywhere.
-- ---------------------------------------------------------------------------
do $$
declare
  v_families text;
begin
  select string_agg(family, ', ' order by family) into v_families from (
    select split_part(dedupe_key, ':', 1) as family
      from engagement.notifications
     where user_id = '9e7c0000-0000-4000-8000-000000000001'
       and dedupe_key is not null
     group by 1
  ) f;
  -- Scoped to the fixture customer, so a shared rehearsal database with other
  -- rows cannot fail this on data this file never wrote. Every order-status and
  -- loyalty row this file attempted was written under section 2's blocker and
  -- therefore does not exist, so the only family left is the new one.
  perform set_config('test.npe_fixture_dedupe_families', coalesce(v_families, 'none'), true);

  if v_families <> 'payment' then
    raise exception 'FAIL E: the fixture customer''s dedupe families are %, expected payment only', v_families;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Report row.
-- ---------------------------------------------------------------------------
do $$
declare
  r record;
begin
  raise notice '================================================================';
  raise notice '217 notification immunity + paid event — behaviour test report';
  raise notice '----------------------------------------------------------------';
  select
    current_setting('test.npe_proposal_loaded', true)        as proposal_loaded,
    current_setting('test.npe_status_under_blocker', true)   as order_status_under_blocker,
    current_setting('test.npe_loyalty_under_blocker', true)  as loyalty_under_blocker,
    current_setting('test.npe_payment_under_blocker', true)  as payment_under_blocker,
    current_setting('test.npe_paid_row', true)               as paid_notification_row,
    current_setting('test.npe_replay_rows', true)            as rows_after_three_repeats,
    current_setting('test.npe_payment_rows_total', true)     as payment_rows_after_negatives,
    current_setting('test.npe_grants', true)                 as grants,
    current_setting('test.npe_service_role_path', true)      as service_role_write_path,
    current_setting('test.npe_anon_direct_call', true)       as anon_direct_call_sqlstate,
    current_setting('test.npe_fixture_dedupe_families', true) as fixture_dedupe_families
    into r;
  raise notice 'proposal_loaded              = %', r.proposal_loaded;
  raise notice 'order_status_under_blocker   = %', r.order_status_under_blocker;
  raise notice 'loyalty_under_blocker        = %', r.loyalty_under_blocker;
  raise notice 'payment_under_blocker        = %', r.payment_under_blocker;
  raise notice 'paid_notification_row        = %', r.paid_notification_row;
  raise notice 'rows_after_three_repeats     = %', r.rows_after_three_repeats;
  raise notice 'payment_rows_after_negatives = %', r.payment_rows_after_negatives;
  raise notice 'grants                       = %', r.grants;
  raise notice 'service_role_write_path      = %', r.service_role_write_path;
  raise notice 'anon_direct_call_sqlstate    = %', r.anon_direct_call_sqlstate;
  raise notice 'fixture_dedupe_families      = %', r.fixture_dedupe_families;
  raise notice '----------------------------------------------------------------';
  raise notice 'verdict = reached the end: no assertion failed';
  raise notice '================================================================';
end $$;

rollback;

-- AFTER THE RUN, in a fresh session, the database must read as it did before:
--   select count(*) from engagement.notifications where dedupe_key like 'payment:%';  -- 0
--   select count(*) from orders.orders where order_number like 'TEST-NPE%';            -- 0
--   select tgname from pg_trigger t join pg_class c on c.oid = t.tgrelid
--     where c.relname = 'orders' and t.tgname = 'tr_order_paid_notification';          -- 0 rows
--   select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
--     where n.nspname = 'engagement' and p.proname = 'notify_order_paid';               -- 0
--   select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
--     where n.nspname = 'public' and p.proname = 'npe_block_notifications';             -- 0
-- If any of those is not empty, the rollback did not take and the rehearsal left
-- state behind — clean it by hand before saying anything about 217.
