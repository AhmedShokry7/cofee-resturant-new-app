-- 187-PROPOSED: an over-withdrawal must not be able to brick a cashier shift.
--
-- NOTHING HERE HAS BEEN EXECUTED. This is the owner-approved safeguard from the
-- 2026-10-27 audit of 182, delivered as a follow-up because migration 182 itself
-- stays byte-identical. It replaces exactly one function and changes nothing
-- else: no table, no constraint, no index, no RLS, no grant, no other RPC.
--
-- WHY A SEPARATE FILE AND NOT AN EDIT TO 182
--   182 is committed and unchanged (md5 b3a0f6c864735f90418ad451bae8b9ba). The
--   approved decision list keeps its sales-total, tender and ownership behaviour
--   and rejects the optional cancelled-order filter, so the drawer guard is the
--   only delta.
--
-- WHY 187 IS A PROPOSAL NUMBER AND NOT A CLAIM
--   The local chain runs to 186, so 187 is the next free number locally. That is
--   the only thing that can be asserted without touching the database. The live
--   ledger (supabase_migrations.schema_migrations) tops out at 160 while objects
--   from 161-181 and 183-185 are already deployed out of band, and two remote
--   rows carry timestamp names (20261025121013, 20261025121027) with no local
--   file. So no number in this folder can be called safe, and this file must NOT
--   be renamed into supabase/migrations/ and treated as applied until the owner
--   has decided how 182-186 get tracked.
--
-- HARD DEPENDENCY
--   payments.pos_shifts, payments.pos_shift_movements, payments.pos_shift_totals
--   and public.admin_pos_record_cash_movement all come from 182, which is not
--   applied in the live project. This file therefore only ever runs AFTER 182,
--   in the same session or a later one. Running it against a database without
--   182 fails with 42P01/42883, which is why it lives here and not in the chain.
--
-- THE DEFECT (verified read-only against the live project, then from the text)
--   admin_pos_record_cash_movement validates only 0 < amount <= 1000000
--   (182:527) and never compares the withdrawal with the drawer.
--   admin_pos_close_shift recomputes
--     expected = opening_float + cash_sales + cash_in - cash_out   (182:619-625)
--   and writes it into a column CHECKed expected_cash >= 0 (182:51), with
--   counted_cash >= 0 as well.
--   So one paid-out larger than float + cash sales + paid-in makes the shift
--   permanently unclosable: every close recomputes the same negative number and
--   the UPDATE is rejected by the table. There is no RPC that repairs it, so the
--   only exits are booking a fictitious paid-in (which corrupts the Z report) or
--   editing payments.pos_shifts by hand. The Flutter layer cannot even explain
--   it: 23514 without the word "closed" maps to PosShiftFailure.invalid, whose
--   Arabic copy is the generic "تحقق من بيانات الوردية وحاول مرة أخرى."
--
-- THE GUARD
--   It sits after the FOR UPDATE on the shift row, so:
--     * a concurrent checkout cannot sneak a sale in. The checkout takes the
--       same shift row in SHARE mode (182:842) and SHARE conflicts with UPDATE,
--       so this statement has already waited for every in-flight sale to commit
--       and blocks the next one until it finishes. The totals it reads are the
--       same totals admin_pos_close_shift will read.
--     * two simultaneous paid-outs are serialised by the same lock, so neither
--       can pass on a balance the other has just spent.
--   The balance comes from payments.pos_shift_totals, the very function the
--   report and the close use, so cash/card/snapshot semantics cannot drift.
--   The rejection is errcode 22023 — the same sqlstate as the existing amount
--   and reason validations — with a distinct message, because this project maps
--   RPC failures by sqlstate plus message keyword (see "closed" in
--   admin_pos_repository.dart:_shiftFailure). No new sqlstate is invented.
--   Zero is allowed: a withdrawal that empties the drawer exactly is legal
--   while expected_cash >= 0 holds equality.
--
-- PRESERVED VERBATIM FROM 182
--   Both permission gates, the active-staff lookup, the FOR UPDATE, the not
--   found and branch scope and closed checks, the kind/amount/reason
--   validations, the insert, the identity.audit call, the return value, the
--   comment wording about movements, and the revoke/grant pair. Cash-in is
--   untouched: no correctness problem in it was found (a paid-in only ever
--   raises expected cash, so it cannot reach the negative state).
--
-- COMPANIONS
--   supabase/tests/pos_shift_cash_out_guard_test.sql — behaviour test, authored
--   and NOT executed (no database was touched).
--   app/admin_app: PosShiftFailure.insufficientDrawerCash, its mapping and the
--   two localized strings. The Dart arm is inert until this SQL is applied, and
--   a Dart-only deployment keeps the old generic message, so the two halves are
--   safe in either order.
--
-- ROLLBACK: re-running 182 restores this function byte-for-byte.

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

  -- ADDED: a paid-out may not empty the drawer below zero. Same arithmetic as
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
