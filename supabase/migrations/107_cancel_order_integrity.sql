-- 107_cancel_order_integrity.sql
--
-- The cancellation of an order could end in a state that never existed.
--
-- What was wrong
-- --------------
-- `orders.cancel_order` (migration 025) did three things that the rest of the
-- database does not allow:
--
-- 1. It cancelled an order from any status.  `orders.status_transitions`
--    allows a cancellation only from `pending`, `confirmed` and `preparing`.
--    A customer could therefore cancel an order in `ready` or
--    `out_for_delivery` - after the drink was made or sent - and still get the
--    stock back and the loyalty points reversed.
--
-- 2. It gave the stock back for every product of the order, guarded by "a
--    stock row exists now".  The deduction at order time only happened "if a
--    stock row was found then", so a product that had no stock row when the
--    order was placed and got one before the cancellation was credited stock
--    that was never taken.
--
-- 3. It cancelled a paid order.  The money of a paid order is captured, and
--    the refund is a staff action (`tap-refund`); cancelling the order behind
--    the back of the refund left a captured payment on a cancelled order with
--    no trace of the money.
--
-- What this migration does
-- ------------------------
-- `orders.cancel_order` is re-created with three guards:
--
--   * the status has to be one the transition table allows to be cancelled;
--   * a paid or authorized order is refused, with a message that names the
--     refund as the next step;
--   * the stock is restored from the movement ledger, which is the record of
--     what was really deducted for this order, and only for the products that
--     were deducted.
--
-- The stock movement of the cancellation is written for the same products, so
-- the ledger tells the whole story: a `sale` movement when the order was
-- placed and a `cancellation` movement when it was cancelled.
--
-- The behaviour of a cancellation that was already correct does not change:
-- the order is cancelled, the stock comes back, the loyalty points are
-- reversed, a status history row is written, and a second cancellation is
-- still refused.

begin;

create or replace function orders.cancel_order(
  p_order_id uuid,
  p_reason text default null
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_order    orders.orders%rowtype;
  v_uid      uuid := auth.uid();
  v_line     record;
  v_quantity integer;
begin
  select * into v_order
    from orders.orders
   where id = p_order_id
   for update;
  if not found then
    raise exception 'order % not found', p_order_id using errcode = 'P0002';
  end if;

  -- the owner may cancel while it is not yet completed
  if v_order.user_id <> v_uid and not identity.has_permission('orders.cancel') then
    raise exception 'not permitted to cancel this order' using errcode = '42501';
  end if;
  if v_order.status in ('completed','cancelled') then
    raise exception 'order is already %', v_order.status using errcode = '23514';
  end if;

  -- Only the statuses the transition table allows may be cancelled.  An order
  -- that is already `ready` or `out_for_delivery` has left the kitchen, and
  -- the branch has to deal with it.
  if not exists (
    select 1
      from orders.status_transitions t
     where t.from_status = v_order.status
       and t.to_status = 'cancelled'
       and t.is_allowed
  ) then
    raise exception 'an order in status % can no longer be cancelled', v_order.status
      using errcode = '23514';
  end if;

  -- A paid order is not cancelled behind the back of the refund: the money
  -- was taken, so it has to be given back first.
  if v_order.payment_status in ('paid','authorized') then
    raise exception
      'this order was paid: it has to be refunded before it can be cancelled'
      using errcode = '23514';
  end if;

  update orders.orders
     set status = 'cancelled', cancelled_at = now(), cancel_reason = p_reason
   where id = p_order_id;

  -- The stock comes back for the products that were really deducted for this
  -- order.  The movement ledger is that record; the order lines are not,
  -- because a line that was never deducted (no stock row at order time) must
  -- not be credited later.
  for v_line in
    select sm.product_id, sum(sm.quantity_delta)::integer as quantity
      from inventory.stock_movements sm
     where sm.reference_type = 'order'
       and sm.reference_id = p_order_id
       and sm.reason = 'sale'
       and sm.quantity_delta < 0
     group by sm.product_id
  loop
    v_quantity := -v_line.quantity;

    update inventory.branch_stock
       set quantity_on_hand = quantity_on_hand + v_quantity,
           updated_at = now()
     where branch_id = v_order.branch_id
       and product_id = v_line.product_id
       and variant_key = '00000000-0000-0000-0000-000000000000'::uuid;
    if not found then
      -- The stock row is gone.  The movement stays the record of the sale;
      -- there is nothing to give back.
      continue;
    end if;

    insert into inventory.stock_movements (
      branch_id, product_id, variant_key, quantity_delta, reason,
      reference_type, reference_id, actor_user_id, note
    )
    values (
      v_order.branch_id, v_line.product_id,
      '00000000-0000-0000-0000-000000000000'::uuid,
      v_quantity, 'cancellation', 'order', p_order_id, v_uid, p_reason
    )
    on conflict do nothing;
  end loop;

  -- claw back earned points
  if v_order.loyalty_points_earned > 0 then
    perform loyalty.apply_points(v_order.user_id, -v_order.loyalty_points_earned,
      'refund', 'order', p_order_id, 'points reversed on cancellation');
  end if;

  insert into orders.order_status_history (order_id, from_status, to_status, changed_by, note)
  values (p_order_id, v_order.status, 'cancelled', v_uid, p_reason);

  return true;
end;
$fn$;

comment on function orders.cancel_order(uuid, text) is
  'Cancels an order. Only from a status the transition table allows, never '
  'from a paid order, and the stock comes back for the products that were '
  'really deducted for it.';

notify pgrst, 'reload schema';

commit;

-- Verification
-- ------------
-- 1) The function carries the three guards:
--      select prosrc from pg_proc
--       where oid = to_regprocedure('orders.cancel_order(uuid,text)');
--    Expected: it mentions `status_transitions`, `paid` and `stock_movements`.
--
-- 2) The behaviour is covered by `supabase/tests/cancel_order_test.sql`,
--    which runs against an isolated database.
--
-- Rollback
-- --------
-- The previous definition is in `supabase/migrations/025_functions_03_orders.sql`.
-- ---------------------------------------------------------------------------
