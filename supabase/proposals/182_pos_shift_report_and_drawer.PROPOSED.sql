-- 182-REVIEW: the two shift-report questions the 2026-10-27 audit left open.
--
-- NOTHING IN THIS FILE HAS BEEN APPLIED OR EXECUTED. Migration 182 itself is
-- untouched — this is the diff the owner must approve or reject before 182 is
-- ever run. Both hunks are separate decisions and can be taken separately.
--
-- THE AUDIT FACTS THESE HUNKS REST ON (all verified read-only against the live
-- project, not inferred from the local chain):
--   * orders.orders.status is CHECKed to
--     (pending, confirmed, preparing, ready, out_for_delivery, completed,
--     cancelled) and payment_transactions.status to
--     (pending, authorized, captured, failed, refunded, voided).
--   * A counter sale is created as status='confirmed', payment_status='paid'
--     with one 'captured' / provider='pos_counter' tender, in the same
--     transaction.
--   * orders.cancel_order (107) refuses a paid order — "this order was paid: it
--     has to be refunded before it can be cancelled" — and the deployed
--     public.admin_update_order_status delegates cancellation to it. No
--     migration anywhere ever sets a tender to 'refunded' or 'voided'.
--   * orders.orders has only two RLS policies, both SELECT. Nothing writes an
--     order row outside a security-definer RPC.
--   => A shift-linked order can therefore NOT be in 'cancelled' today, and no
--      captured tender can leave 'captured'. The Z report is internally
--      consistent right now; hunk 1 is a guard for the future, not a bug fix.
--   * payments.pos_shift_totals has no drawer check anywhere in the paid-out
--     path: admin_pos_record_cash_movement validates amount in (0, 1000000]
--     only. expected_cash = opening_float + cash_sales + cash_in − cash_out,
--     and the table CHECKs expected_cash >= 0 and counted_cash >= 0.
--   => a paid-out larger than the drawer makes the shift impossible to close:
--      the close recomputes the same negative expected cash, the CHECK rejects
--      the row, and the only way out is to book a fictitious paid-in or to edit
--      payments.pos_shifts by hand. Dart shows that as "قيمة غير صالحة"
--      (PosShiftFailure.invalid), because 23514 maps to invalid unless the
--      message contains "closed". That is hunk 2.

-- ---------------------------------------------------------------------------
-- HUNK 1 — OPTIONAL: keep cancelled orders out of the sales block.
-- Only meaningful once a refund/reversal path exists. It is a no-op today.
-- pos_shift_totals is private and recomputed live; a CLOSED shift keeps its
-- snapshotted Z columns, so this never rewrites history.
-- ---------------------------------------------------------------------------
-- create or replace function payments.pos_shift_totals(p_shift_id uuid)
-- returns table (
--   cash_sales     numeric,
--   card_sales     numeric,
--   sales_total    numeric,
--   order_count    integer,
--   cash_in_total  numeric,
--   cash_out_total numeric
-- )
-- language sql
-- stable
-- security definer
-- set search_path = ''
-- as $fn$
--   select
--     coalesce((
--       select sum(t.amount)
--         from orders.orders o
--         join payments.payment_transactions t
--           on t.order_id = o.id
--          and t.provider = 'pos_counter'
--          and t.status = 'captured'
--         join payments.payment_methods m
--           on m.id = coalesce(t.method_id, o.payment_method_id)
--        where o.pos_shift_id = p_shift_id
--          and m.code = 'cash'
--     ), 0)::numeric,
--     coalesce((
--       select sum(t.amount)
--         from orders.orders o
--         join payments.payment_transactions t
--           on t.order_id = o.id
--          and t.provider = 'pos_counter'
--          and t.status = 'captured'
--         join payments.payment_methods m
--           on m.id = coalesce(t.method_id, o.payment_method_id)
--        where o.pos_shift_id = p_shift_id
--          and m.code = 'card'
--     ), 0)::numeric,
--     coalesce((
--       select sum(o.grand_total)
--         from orders.orders o
--        where o.pos_shift_id = p_shift_id
--          and o.status <> 'cancelled'        -- ADDED
--     ), 0)::numeric,
--     coalesce((
--       select count(*)::integer
--         from orders.orders o
--        where o.pos_shift_id = p_shift_id
--          and o.status <> 'cancelled'        -- ADDED
--     ), 0),
--     coalesce((
--       select sum(mv.amount)
--         from payments.pos_shift_movements mv
--        where mv.shift_id = p_shift_id
--          and mv.kind = 'cash_in'
--     ), 0)::numeric,
--     coalesce((
--       select sum(mv.amount)
--         from payments.pos_shift_movements mv
--        where mv.shift_id = p_shift_id
--          and mv.kind = 'cash_out'
--     ), 0)::numeric;
-- $fn$;
--
-- Deliberately NOT done here: no refund RPC, no 'refunded'/'voided' writer, no
-- reversal tender. If the product wants counter refunds they need their own
-- migration (the money has to leave the drawer through cash_out for a cash
-- refund, or be recorded as a negative tender — those are different models) and
-- the drawer arithmetic has to be re-audited against that choice.

-- ---------------------------------------------------------------------------
-- HUNK 2 — RECOMMENDED: stop a paid-out that would empty the drawer below zero.
-- SUPERSEDED: keep [`187_pos_shift_cash_out_guard.PROPOSED.sql`] as the text to
-- apply. This hunk is the earlier draft (it names the variable v_remaining and
-- reads the totals into a local) and is kept only as the review trail.
-- Whole function is shown because the signature, guards, ordering, audit call
-- and return value must stay byte-identical apart from the new block and the
-- one new declare variable.
-- ---------------------------------------------------------------------------
create or replace function public.admin_pos_record_cash_movement(
  p_shift_id uuid,
  p_kind     text,
  p_amount   numeric,
  p_reason   text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_staff_id  uuid;
  v_shift     payments.pos_shifts%rowtype;
  v_reason    text;
  v_amount    numeric;
  v_remaining numeric;   -- ADDED
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('pos.manage') then
    raise exception 'missing permission: pos.manage' using errcode = '42501';
  end if;

  select sm.id
    into v_staff_id
    from identity.staff_members sm
   where sm.user_id = auth.uid()
     and sm.status = 'active';
  if v_staff_id is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  select *
    into v_shift
    from payments.pos_shifts s
   where s.id = p_shift_id
   for update;
  if not found then
    raise exception 'cashier shift not found' using errcode = 'P0002';
  end if;
  if not identity.can_manage_branch(v_shift.branch_id) then
    raise exception 'branch out of scope' using errcode = '42501';
  end if;
  if v_shift.status <> 'open' then
    raise exception 'cashier shift is closed' using errcode = '23514';
  end if;
  if p_kind is null or p_kind not in ('cash_in', 'cash_out') then
    raise exception 'invalid cash movement kind' using errcode = '22023';
  end if;
  if p_amount is null or p_amount <= 0 or p_amount > 1000000 then
    raise exception 'invalid cash movement amount' using errcode = '22023';
  end if;

  v_amount := round(p_amount, 2);
  v_reason := left(btrim(coalesce(p_reason, '')), 240);
  if v_reason = '' then
    raise exception 'a cash movement needs a reason' using errcode = '22023';
  end if;

  -- ADDED: the shift row is already locked FOR UPDATE, and a concurrent
  -- checkout holds it in SHARE mode, so this reading of the live totals is
  -- stable for the whole transaction. A drawer that cannot pay itself out is
  -- recorded, not silently allowed: the alternative is a shift that can never
  -- be closed.
  if p_kind = 'cash_out' then
    select round(
             v_shift.opening_float
             + coalesce(t.cash_sales, 0)
             + coalesce(t.cash_in_total, 0)
             - coalesce(t.cash_out_total, 0)
             - v_amount,
             2
           )
      into v_remaining
      from payments.pos_shift_totals(p_shift_id) t;
    if v_remaining < 0 then
      raise exception 'cash out exceeds the drawer'
        using errcode = '22023';
    end if;
  end if;

  insert into payments.pos_shift_movements (
    shift_id, kind, amount, reason, created_by
  ) values (
    p_shift_id, p_kind, v_amount, v_reason, v_staff_id
  );

  perform identity.audit(
    'pos.shift.' || p_kind,
    'pos_shift',
    p_shift_id,
    null,
    jsonb_build_object('amount', v_amount, 'reason', v_reason),
    v_shift.branch_id
  );

  return payments.pos_shift_json(p_shift_id, true);
end;
$fn$;

comment on function public.admin_pos_record_cash_movement(uuid, text, numeric, text) is
  'Records cash paid into or taken out of the open drawer, with a reason. A '
  'paid-out may not push the expected cash below zero.';

-- PAIR OF THIS HUNK (Dart, NOT written here): _shiftFailure in
-- app/admin_app/lib/features/pos/data/repositories/admin_pos_repository.dart
-- maps 22023 to PosShiftFailure.invalid, so the new reason needs its own arm,
-- a PosShiftFailure value and an Arabic/English string, otherwise the cashier
-- sees the same generic message as today.
--
-- NOT TOUCHED: the expected_cash >= 0 and counted_cash >= 0 CHECKs stay as the
-- backstop; admin_pos_close_shift keeps recomputing expected cash itself; no
-- negative-balance mode; no ownership (opened_by) predicate anywhere.
