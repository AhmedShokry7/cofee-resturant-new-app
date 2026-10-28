-- 187: an over-withdrawal must not be able to brick a cashier shift.
--
-- Follow-up to 182, which stays byte-identical. This replaces exactly one
-- function and changes nothing else: no table, no constraint, no index, no RLS
-- policy, no grant beyond the pair it re-declares for the function itself.
--
-- THE DEFECT
--   admin_pos_record_cash_movement validated only 0 < amount <= 1000000
--   (182:527) and never compared a paid-out with the drawer.
--   admin_pos_close_shift recomputes
--     expected = opening_float + cash_sales + cash_in - cash_out   (182:619-625)
--   and writes it into a column CHECKed expected_cash >= 0 (182:51), while
--   counted_cash is CHECKed >= 0 too. One paid-out larger than the drawer
--   therefore made the shift permanently unclosable, with no RPC that repairs
--   it: the only exits were booking a fictitious paid-in, which corrupts the Z
--   report, or editing payments.pos_shifts by hand.
--
-- THE GUARD
--   It sits after the FOR UPDATE this function already takes on the shift row,
--   so a concurrent checkout cannot slip a sale in — the checkout holds the
--   same row in SHARE mode (182:842), which conflicts with UPDATE — and two
--   simultaneous paid-outs serialise on that same lock. The balance comes from
--   payments.pos_shift_totals, the very function the live report and the close
--   use, so the arithmetic cannot drift from the Z maths.
--   The rejection is errcode 22023, the sqlstate the existing amount and reason
--   validations already use, with its own message, because this project maps RPC
--   failures by sqlstate plus message keyword (see _shiftFailure in
--   admin_pos_repository.dart). Zero stays allowed: emptying the drawer exactly
--   is legal while expected_cash >= 0 holds as equality.
--   Cash-in is untouched — a paid-in only ever raises expected cash.
--
-- APP SIDE
--   PosShiftFailure.insufficientDrawerCash and S.posShiftInsufficientDrawerCash
--   read this message. The Dart arm is inert until this file is applied, and the
--   old generic message still applies without it, so the two halves are safe in
--   either order.
--
-- Companion test: supabase/tests/pos_shift_cash_out_guard_test.sql
-- Rollback: re-running 182 restores this function byte-for-byte.

-- ---------------------------------------------------------------------------
-- The one function: the 182 body plus the drawer check and v_expected.
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
  v_staff_id uuid;
  v_shift    payments.pos_shifts%rowtype;
  v_reason   text;
  v_amount   numeric;
  v_expected numeric;
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

  -- A paid-out may not empty the drawer below zero. Same arithmetic as
  -- admin_pos_close_shift, read under the row lock this function already holds.
  if p_kind = 'cash_out' then
    select round(
             v_shift.opening_float
             + coalesce(t.cash_sales, 0)
             + coalesce(t.cash_in_total, 0)
             - coalesce(t.cash_out_total, 0)
             - v_amount,
             2
           )
      into v_expected
      from payments.pos_shift_totals(p_shift_id) t;
    if v_expected is null or v_expected < 0 then
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

revoke all on function public.admin_pos_record_cash_movement(
  uuid, text, numeric, text
) from public, anon;
grant execute on function public.admin_pos_record_cash_movement(
  uuid, text, numeric, text
) to authenticated;

notify pgrst, 'reload schema';
