-- 217-PROPOSED: a notification must never abort the order, the points or the
-- subscription it rides on — and "your payment landed" is the one automatic
-- event the customer app has been waiting for.
--
-- NOTHING HERE HAS BEEN EXECUTED AS A CHANGE. This file is a proposal kept in
-- supabase/proposals/. It is not applied to the live project and it is not part
-- of the migration chain until the owner copies it out with its own number and
-- repairs it into the ledger (`supabase migration repair`, never `db push`).
-- Applying it is an owner action in the SQL Editor. Its behaviour test
-- (supabase/tests/notification_paid_event_test.sql) is WRITTEN BUT NOT RUN: the
-- CLI and the direct query helper both answered `401 Invalid access token` on
-- 2026-10-31, so every claim below is read off the migration chain and the
-- Edge Function code, not off the live database. Nothing in this file may be
-- applied before that test has been run whole inside one rolled-back
-- transaction and its report row read.
--
-- ONE FILE, TWO DECISIONS
--   1. Three function bodies get an exception block around the notification
--      INSERT: engagement.notify_order_status (175), engagement.notify_loyalty
--      (030), engagement.notify_subscription_status (114). Same text, same
--      rows, same dedupe keys — only the failure behaviour changes.
--   2. One new automatic event: engagement.notify_order_paid(), an AFTER
--      trigger on orders.orders firing only when payment_status becomes
--      'paid'. No table, no column, no constraint, no index, no policy, no new
--      notification type.
--
-- WHY THE CURRENT STRUCTURE CANNOT DO EITHER WITHOUT THIS FILE
--   (1) is a defect, not a missing feature. All three functions are SECURITY
--   DEFINER triggers that run inside the business write: the order status
--   update, the loyalty ledger row, the subscription status change. If the
--   INSERT into engagement.notifications raises — and it can raise for reasons
--   that have nothing to do with the order — the whole statement rolls back.
--   Measured against the chain, these are the reachable raisers:
--     * the check constraint on engagement.notifications.type (016:39, rewritten
--       by 114:55-59 and again by 170:109-112) refuses a type outside
--       ('order_status','promo','system','loyalty','subscription');
--     * user_id / title / body are not null (016), so a NULL the trigger does
--       not pre-check aborts the caller's transaction;
--     * EXECUTE on the function, held through PUBLIC, can be taken away by a
--       grants sweep the way 081 was undone by 188 and 216 measures it — then
--       every order status write answers 42501;
--     * a lock or a timeout on the notifications table, or the table being
--       absent in a restored environment.
--   None of those is the kitchen's or the cashier's problem, and today each of
--   them cancels a real order or loses a real points entry. The same rule
--   already holds everywhere else in this system: send-push records a failed
--   device and keeps going, engagement.enqueue_push never raises into the
--   insert it follows. These three triggers are the last places where a
--   notification can still break a sale.
--   (2) needs no schema at all, which is why it is in this file rather than in
--   a bigger one. orders.orders already carries payment_status as text with
--   check (payment_status in ('unpaid','pending','paid','failed','refunded'))
--   (011:95, re-asserted by 159:18 and 211:139 — and never widened: 'authorized'
--   appears in one comparison at 107:96, but the constraint refuses a row from
--   ever holding it, so that arm is dead code);
--   engagement.notifications
--   already carries dedupe_key with the partial unique index
--   uq_notifications_dedupe on (user_id, dedupe_key) where dedupe_key is not
--   null (016:50,62-64); public.notifications exposes the row to the owner; and
--   engagement.enqueue_push() already serialises payload into the pg_net body
--   (170:380-400) that supabase/functions/send-push reads. The only missing
--   piece is the trigger that turns "the payment landed" into one row.
--
-- HOW THE EVENT AVOIDS EVERY DUPLICATE PATH INSPECTED
--   An event id, in the shape this chain already uses for the other three:
--     order:<id>:<status>          027/030/175  engagement.notify_order_status
--     loyalty:<user>:<txn>         027/030      engagement.notify_loyalty
--     subscription:<id>:<status>:<ends_at::date> 114:97  lifecycle
--     subscription:<id>:reminder_<1d|3d>:<ends_at::date> 114:147  reminders
--     campaign:<id>:<user>         170          admin campaigns
--   This file adds one key of the same family — payment:<id>:paid — and takes
--   its duplicate protection from three independent layers, so no single one
--   has to be right:
--     * the WHEN clause on the trigger: PostgreSQL re-evaluates it per row, and
--       `new.payment_status is distinct from old.payment_status` means a row
--       rewritten to the value it already holds never enters the function at
--       all;
--     * the function's own `if old.payment_status = 'paid' then return new`
--       guard for the paid → paid case that reaches it through an
--       `after update` without a column list, and for a future re-definition;
--     * the partial unique index: the ON CONFLICT DO NOTHING makes a repeat —
--       a replayed webhook, a re-run of the admin RPC, a manual patch — a
--       no-op rather than a second notification, exactly as it does for the
--       order-status event today.
--   tap-webhook (supabase/functions/tap-webhook/index.ts:148-157) is the only
--   writer of payment_status = 'paid' outside the admin panel, and it PATCHes
--   the row through PostgREST with the service role. Tap may deliver the same
--   charge notification more than once; the patch then writes the same value,
--   and the first two layers above stop it twice before the index stops it a
--   third time. The webhook itself is not changed by this file — its `.catch()`
--   already swallows the PATCH failure, and a notification that cannot be
--   written must not change what the webhook answers to Tap.
--
-- WHAT THIS IS NOT — STATED SO THE DECISION IS MADE ON THE RIGHT FACTS
--   * It is not the payment-failure event. 'failed' and 'refunded' get no
--     notification here; the spec's own rule is that an automatic event ships
--     only when the state is reached reliably, and a failure message has a
--     support path of its own to be designed with.
--   * It is not proof of delivery. Like every other row in this table it says
--     "an in-app notification was written" — engagement.push_deliveries says
--     what FCM accepted. Nothing here measures display or open.
--   * It is not scheduling, drafts, campaign status, per-device retry or
--     open tracking. Those need columns this file does not add, and they are
--     batch د٢ with their own proposal.
--   * It does not touch engagement.process_subscription_notifications (114:115
--     -152), the hourly cron job. Its loop could lose the whole run to one bad
--     row, but that batch writes no order and takes no payment, and wrapping it
--     would change what its returned count means. Separate decision, separate
--     file.
--   * It does not change any RLS policy, any grant that exists, or the
--     notifications type constraint — which is why the event reuses type
--     'order_status' (see the owner decisions below).
--
-- OWNER DECISIONS THIS FILE ASKS FOR
--   1. A separate message for payment, or none? The order already gets a
--      notification when its STATUS changes. A customer whose order is
--      accepted at the same moment it is paid sees two rows. The answer built
--      here is "yes, one row, because paying and cooking are different facts"
--      — but the owner may prefer the payment to stay silent.
--   2. Which type does the row carry? This file writes 'order_status' and
--      related_entity_type 'order', because both already exist in the
--      constraint (114/170) and in the customer app's routing
--      (lib/core/navigation/notification_routes.dart maps the 'order' entity to
--      the orders screen). Adding a real 'payment' type would mean ALTERing
--      notifications_type_check AND the customer app's type enum AND the admin
--      directory filter, for a message that opens the same screen. The
--      distinguishing data is in the payload ('event': 'payment') and in the
--      dedupe key.
--   3. Where does a swallowed failure go? This file uses `raise warning`, which
--      lands in the project's PostgreSQL logs with the order id, the SQLSTATE
--      and the message — never a device token, never a secret. A durable table
--      (engagement.notification_failures) would make failures countable in the
--      admin panel, which is what the spec asks for long-term; it is a new
--      table, so it is NOT added here and the owner can ask for it in the same
--      pass.
--   4. Should the walk-in and the counter-paid orders be excluded? They are:
--     the trigger is `after update of payment_status` only, so a POS order
--     inserted already paid fires nothing, and a row with no customer has
--     nobody to notify — orders.orders.user_id has been nullable since 181:50,
--     which is the same fact 175:74-77 rules on for status changes.
--
-- WHAT BREAKS IF THIS IS WRONG
--   (1) is a wrapper around a statement that either happens or does not: the
--   worst outcome is a notification silently missing while the order saved —
--   which is the outcome today when the notification writes fine and the
--   device is dead. The business write cannot get worse.
--   (2) can fail in one way that matters: if service_role loses the EXECUTE it
--   borrows from PUBLIC, the webhook's PATCH aborts with 42501 and payment
--   confirmation stops landing. That is why the grant line is explicit rather
--   than left to PUBLIC, and why the behaviour test drives the write through
--   the service role path and reads the row back, in one rolled-back
--   transaction. The trigger fires as the invoker (the function is SECURITY
--   DEFINER, so its INSERT runs as the owner, but EXECUTE is still checked
--   against the role that ran the statement).
--   Rollback for (1): re-run 175:57-102, 030:96-128 and 114:61-108 in order —
--   each body is `create or replace`, so the chain is idempotent.
--   Rollback for (2):
--     drop trigger if exists tr_order_paid_notification on orders.orders;
--     drop function if exists engagement.notify_order_paid();
--   and the rows it wrote are ordinary notifications the owner can delete:
--     delete from engagement.notifications where dedupe_key like 'payment:%';
--
-- COMPANIONS
--   supabase/tests/notification_paid_event_test.sql — the behaviour test, NOT
--   YET RUN (see the status note at the top).
--   No Dart change: the customer app already renders this table, already opens
--   an 'order' entity on the orders screen, and already ignores a payload it
--   cannot read; the admin directory already lists every type in the constraint.

-- -----------------------------------------------------------------------------
-- 1. The notification cannot outvote the business write.
--    Each body below is the body already in the chain, byte for byte in its
--    logic, with the single INSERT wrapped in its own exception block. The
--    guard covers exactly one statement, so nothing the caller did can be
--    swallowed with it: the order row, the ledger row and the subscription row
--    are already written by the time the trigger runs.
--    `raise warning` keeps the failure visible in the project logs — SQLSTATE,
--    message, and the id of the row that was not notified. No token, no
--    payload, no secret.
-- -----------------------------------------------------------------------------

-- 175:57-102 with the guard added.
create or replace function engagement.notify_order_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_user uuid;
  v_dedupe text;
begin
  if tg_op = 'UPDATE' and new.status is not distinct from old.status then
    return new;
  end if;

  select user_id into v_user from orders.orders where id = new.id;

  -- Walk-in orders have nobody to notify, and the kitchen must still be able
  -- to move them forward.
  if v_user is null then
    return new;
  end if;

  v_dedupe := 'order:' || new.id::text || ':' || new.status;

  begin
    insert into engagement.notifications
      (user_id, type, title_ar, title_en, body_ar, body_en,
       payload, related_entity_type, related_entity_id, dedupe_key)
    values (
      v_user,
      'order_status',
      'تحديث حالة الطلب ' || new.order_number,
      'Order ' || new.order_number || ' updated',
      'حالة طلبك الآن: ' || new.status,
      'Your order status is now: ' || new.status,
      jsonb_build_object('order_id', new.id, 'order_number', new.order_number,
                         'status', new.status, 'total', new.grand_total,
                         'branch_id', new.branch_id),
      'order',
      new.id,
      v_dedupe
    )
    on conflict (user_id, dedupe_key) where dedupe_key is not null do nothing;
  exception when others then
    raise warning
      'engagement.notify_order_status: order % kept its status change and lost '
      'its notification (%: %)', new.id, sqlstate, sqlerrm;
  end;

  return new;
end;
$fn$;

comment on function engagement.notify_order_status() is
  'After an order status change: create one in-app notification. Walk-in orders '
  'are skipped. A notification that cannot be written is logged and skipped — '
  'it never rolls back the status change (217).';

-- 030:96-128 with the guard added. The ledger row is the customer's points;
-- the message about it is not allowed to decide whether they keep them.
create or replace function engagement.notify_loyalty()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_dedupe text;
begin
  v_dedupe := 'loyalty:' || new.user_id::text || ':' || new.id::text;

  begin
    insert into engagement.notifications
      (user_id, type, title_ar, title_en, body_ar, body_en,
       payload, related_entity_type, related_entity_id, dedupe_key)
    values (
      new.user_id,
      'loyalty',
      case when new.points > 0 then 'ربحت نقاط' else 'استخدمت نقاط' end,
      case when new.points > 0 then 'Points earned' else 'Points redeemed' end,
      case when new.points > 0
        then 'ربحت ' || new.points || ' نقطة. رصيدك ' || new.balance_after
        else 'استخدمت ' || abs(new.points) || ' نقطة. رصيدك ' || new.balance_after end,
      case when new.points > 0
        then 'You earned ' || new.points || ' points. Balance: ' || new.balance_after
        else 'You used ' || abs(new.points) || ' points. Balance: ' || new.balance_after end,
      jsonb_build_object('points', new.points, 'balance_after', new.balance_after, 'reason', new.reason),
      'loyalty', new.id, v_dedupe
    )
    on conflict (user_id, dedupe_key) where dedupe_key is not null do nothing;
  exception when others then
    raise warning
      'engagement.notify_loyalty: ledger row % kept its points and lost its '
      'notification (%: %)', new.id, sqlstate, sqlerrm;
  end;

  return new;
end;
$fn$;

comment on function engagement.notify_loyalty() is
  'After a loyalty ledger row: create one in-app notification. A notification '
  'that cannot be written is logged and skipped — it never rolls back the '
  'points movement (217).';

-- 114:61-108 with the guard added. The status change is the subscription
-- truth; the inbox row about it is a courtesy.
create or replace function engagement.notify_subscription_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_title_ar text;
  v_title_en text;
  v_body_ar text;
  v_body_en text;
  v_key text;
begin
  if tg_op = 'UPDATE' and old.status is not distinct from new.status then
    return new;
  end if;
  if new.status not in ('active','expired','cancelled') then
    return new;
  end if;

  if new.status = 'active' then
    v_title_ar := 'تم تفعيل اشتراكك';
    v_title_en := 'Your subscription is active';
    v_body_ar := 'يمكنك الآن استخدام أكواب اشتراكك حتى تاريخ الانتهاء.';
    v_body_en := 'You can now use your subscription cups until the end date.';
  elsif new.status = 'expired' then
    v_title_ar := 'انتهى اشتراكك';
    v_title_en := 'Your subscription has expired';
    v_body_ar := 'انتهت صلاحية اشتراكك. تصفح الباقات لتجديده.';
    v_body_en := 'Your subscription has ended. Browse plans to renew it.';
  else
    v_title_ar := 'تم إلغاء اشتراكك';
    v_title_en := 'Your subscription was cancelled';
    v_body_ar := 'تم إلغاء اشتراكك بنجاح.';
    v_body_en := 'Your subscription was cancelled successfully.';
  end if;
  v_key := 'subscription:' || new.id::text || ':' || new.status || ':' || new.ends_at::date::text;

  begin
    insert into engagement.notifications
      (user_id, type, title_ar, title_en, body_ar, body_en,
       related_entity_type, related_entity_id, dedupe_key)
    values
      (new.user_id, 'subscription', v_title_ar, v_title_en, v_body_ar, v_body_en,
       'subscription', new.id, v_key)
    on conflict (user_id, dedupe_key) where dedupe_key is not null do nothing;
  exception when others then
    raise warning
      'engagement.notify_subscription_status: subscription % kept its status '
      'and lost its notification (%: %)', new.id, sqlstate, sqlerrm;
  end;

  return new;
end;
$fn$;

comment on function engagement.notify_subscription_status() is
  'After a subscription status change: create one in-app notification for '
  'active/expired/cancelled. A notification that cannot be written is logged '
  'and skipped — it never rolls back the status (217).';

-- -----------------------------------------------------------------------------
-- 2. The one new automatic event: the payment landed.
--
--    'paid' is reached from two places and no third:
--      * supabase/functions/tap-webhook/index.ts:148-157, which PATCHes
--        payment_status only after it has re-read the local transaction and
--        matched the amount and the currency against it and against the order
--        (index.ts:97-146). An order row whose charge failed the check is
--        never marked paid, so the webhook's own verdict is the reliable
--        result the spec asks for — creating a charge, or receiving a
--        callback, is not.
--      * public.admin_update_order_payment_status (159, rewritten by 211:123
--        -154) for a refund or a correction recorded in the admin panel.
--
--    `after update of payment_status` keeps the trigger out of every unrelated
--    write to the order row — a kitchen note, a delivery status, a totals
--    recompute (191, 200) — and the WHEN clause keeps out every rewrite that
--    leaves the value alone, which is what a replayed webhook does.
-- -----------------------------------------------------------------------------
create or replace function engagement.notify_order_paid()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_dedupe text;
begin
  -- Second gate for the paid → paid rewrite: an `after update` without a
  -- column list, or a future re-definition of the trigger, still writes one
  -- message per order.
  if tg_op = 'UPDATE' and old.payment_status is not distinct from new.payment_status then
    return new;
  end if;

  -- Only the arrival at 'paid' is an event. 'pending', 'failed' and 'refunded'
  -- say nothing this customer asked to be told.
  if new.payment_status <> 'paid' then
    return new;
  end if;

  -- A walk-in or counter order has nobody to notify, exactly as 175 rules for
  -- a status change.
  if new.user_id is null then
    return new;
  end if;

  v_dedupe := 'payment:' || new.id::text || ':paid';

  begin
    insert into engagement.notifications
      (user_id, type, title_ar, title_en, body_ar, body_en,
       payload, related_entity_type, related_entity_id, dedupe_key)
    values (
      new.user_id,
      'order_status',
      'تم الدفع بنجاح',
      'Payment received',
      'وصل دفعك لطلبك ' || new.order_number || '. شكرًا لك.',
      'Your payment for order ' || new.order_number || ' is confirmed. Thank you.',
      jsonb_build_object(
        'event', 'payment',
        'order_id', new.id,
        'order_number', new.order_number,
        'payment_status', new.payment_status,
        'total', new.grand_total,
        'currency', new.currency_code,
        'branch_id', new.branch_id),
      'order',
      new.id,
      v_dedupe
    )
    -- The same ON CONFLICT inference against the partial unique index that
    -- 030:17-20 documents and guards; `where dedupe_key is not null` is the
    -- form 175 and 114 settled on.
    on conflict (user_id, dedupe_key) where dedupe_key is not null do nothing;
  exception when others then
    raise warning
      'engagement.notify_order_paid: order % kept its payment and lost its '
      'notification (%: %)', new.id, sqlstate, sqlerrm;
  end;

  return new;
end;
$fn$;

comment on function engagement.notify_order_paid() is
  'After orders.orders.payment_status becomes paid: one in-app notification for '
  'the order owner, keyed payment:<order>:paid so a replayed webhook cannot '
  'send a second one. Walk-in orders are skipped and a notification that cannot '
  'be written never rolls back the payment (217).';

drop trigger if exists tr_order_paid_notification on orders.orders;
create trigger tr_order_paid_notification
  after update of payment_status on orders.orders
  for each row
  when (new.payment_status = 'paid'
        and old.payment_status is distinct from new.payment_status)
  execute function engagement.notify_order_paid();

-- The trigger fires as whoever wrote the row. Today that is the service role
-- (tap-webhook's PATCH) and, through the SECURITY DEFINER admin RPC, postgres.
-- A new function arrives with EXECUTE held by PUBLIC, which is the artifact 081
-- was written against and 216 measures in 188's pair; it is named instead.
-- service_role is granted explicitly because the webhook is the path that
-- reaches 'paid' — taking it away through PUBLIC would fail the payment
-- confirmation, not the notification.
grant execute on function engagement.notify_order_paid() to authenticated, service_role;
revoke execute on function engagement.notify_order_paid() from public, anon;

notify pgrst, 'reload schema';

-- -----------------------------------------------------------------------------
-- READ-ONLY PRE-FLIGHT, run this in the SQL Editor BEFORE pasting anything above
-- -----------------------------------------------------------------------------
-- 1) The three bodies being wrapped, as they are live. Each must still carry
--    its own dedupe key text, and none must already hold an exception block.
-- select p.proname,
--        position('exception when others' in pg_get_functiondef(p.oid)) > 0 as already_guarded,
--        length(pg_get_functiondef(p.oid)) as definition_chars
--   from pg_proc p
--   join pg_namespace n on n.oid = p.pronamespace
--  where n.nspname = 'engagement'
--    and p.proname in ('notify_order_status','notify_loyalty','notify_subscription_status')
--  order by p.proname;
--
-- 2) The event must be free of a name clash: the triggers that live on the
--    order row today. No tr_order_paid_notification among them means the event
--    does not exist yet and this file is not a second copy of it.
-- select trigger_name, event_manipulation, action_timing
--   from information_schema.triggers
--  where event_object_schema = 'orders' and event_object_table = 'orders'
--  order by trigger_name;
--
-- 3) The three claims about the shape this file relies on: the payment_status
--    values, the dedupe index, and the type constraint.
-- select conname, pg_get_constraintdef(oid)
--   from pg_constraint
--  where conrelid in ('orders.orders'::regclass, 'engagement.notifications'::regclass)
--    and (pg_get_constraintdef(oid) ilike '%payment_status%'
--         or conname = 'notifications_type_check')
--  order by conname;
-- select indexdef from pg_indexes
--  where schemaname = 'engagement' and indexname = 'uq_notifications_dedupe';
--
-- 4) Who can write payment_status today — the roles the trigger will fire as.
-- select grantee, privilege_type
--   from information_schema.role_table_grants
--  where table_schema = 'orders' and table_name = 'orders'
--    and privilege_type = 'UPDATE'
--  order by grantee;
--
-- 5) Is there a paid order already, and has its owner already been told? A
--    live count of the key this file introduces, so the owner sees the size of
--    the backlog the trigger will NOT fill retroactively (it only fires on the
--    transition).
-- select count(*) as paid_orders,
--        (select count(*) from engagement.notifications
--          where dedupe_key like 'payment:%') as payment_notifications
--   from orders.orders where payment_status = 'paid';
--
-- 6) Rehearsal: run supabase/tests/notification_paid_event_test.sql whole,
--    inside one transaction that ends in `rollback;`, and read its report row
--    before applying anything above.
