-- 213-PROPOSED: cancelling a salary advance must respect the staff scope.
--
-- NOTHING HERE HAS BEEN EXECUTED. This file is a proposal kept in
-- supabase/proposals/. It is not applied to the live project and it is not part
-- of the migration chain until the owner copies it out with its own number and
-- repairs it into the ledger (`supabase migration repair`, never `db push`).
-- Applying it is an owner action in the SQL Editor.
--
-- ONE TOPIC, ONE DECISION
--   It replaces exactly one function: public.admin_hr_cancel_advance(uuid, text).
--   No table, no column, no constraint, no index, no RLS policy, no permission
--   code, no grant, no other RPC. Everything else in 212 stays byte-identical.
--
-- WHY A SEPARATE FILE AND NOT AN EDIT TO 212
--   212 is applied and behaviour-tested (see the STATUS header of
--   supabase/tests/hr_workforce_test.sql: it passed against the live project
--   inside one rolled-back transaction on 2026-10-29). Editing a migration that
--   is already recorded is exactly how the chain and the live database came to
--   diverge before; the chain keeps the history and this file keeps the delta.
--
-- WHY 213 IS A PROPOSAL NUMBER AND NOT A CLAIM
--   The local chain runs to 212, so 213 is the next free number locally. That is
--   the only thing assertable without touching the database. Verify live state
--   with `select pg_get_functiondef('public.admin_hr_cancel_advance(uuid, text)'::regprocedure);`
--   before deciding — if the live body already contains the guard, the live
--   database was patched out of band and the chain, not the database, needs the
--   repair.
--
-- THE DEFECT (read from the text of 212; no query was run to obtain it)
--   The three advance RPCs that change money are supposed to answer inside the
--   caller's staff scope, and two of them do:
--     * admin_hr_review_advance  asserts it at 212:4371
--     * admin_hr_disburse_advance asserts it at 212:4459
--     * admin_hr_cancel_advance  (212:4490-4547) does not.
--   What cancel does check is:
--     * hr.require_staff() — the caller is an active staff member (212:4504);
--     * identity.has_permission('hr.finance.adjust') — a boolean, not a scope;
--     * `v_adv.requested_by <> v_me and not v_can` → 42501 (212:4514);
--     * status and settled_amount guards (212:4517-4522);
--     * a disbursed advance needs finance (212:4523).
--   None of those compares the CALLER'S BRANCH with the BRANCH OF THE STAFF
--   MEMBER THE ADVANCE BELONGS TO. `identity.has_permission` answers "does this
--   person hold the code anywhere", and 212:5782 grants `hr.finance.adjust` to
--   `branch_manager`, whose authority is one branch (`identity.staff_roles.branch_id`).
--
--   The read side proves the intended contract. admin_hr_advances (212:4283-4292,
--   4327) refuses a filter outside the scope with hr.assert_staff_access and,
--   when unfiltered, keeps only rows whose staff pass hr.can_access_staff. So the
--   advances list of a branch manager never shows a colleague from another
--   branch — and the cancel RPC can still write that invisible row.
--
-- WHY THIS IS REACHABLE AND NOT MERELY THEORETICAL
--   All HR access goes through security definer RPCs: hr.salary_advances has RLS
--   enabled (212:550) and 212 creates NO policy on it (grep for `create policy`
--   in 212 returns zero hits). That is the documented design — "nothing in the
--   hr schema is reachable without an RPC" — which also means the definer body
--   bypasses RLS and the in-function checks are the only isolation there is. The
--   SELECT ... FOR UPDATE at 212:4507 reads any advance id in the table, so a
--   caller who learns an id from anywhere (a shared link, an audit export, a
--   guessed or leaked uuid, a support conversation) can cancel it.
--
-- THE FIX
--   `perform hr.assert_staff_access(v_adv.staff_id);` placed after the status and
--   settled_amount guards and before the UPDATE — the same helper, called the
--   same way, with the same errcode ('staff member out of scope', 42501) that the
--   two siblings already use. It is put last rather than first so the caller who
--   is out of scope AND holding a settled advance still learns the money reason
--   first, exactly as review and disburse order their refusals.
--   hr.assert_staff_access (212:954-970) is stable + security definer and is
--   already revoked from public/anon/authenticated (212:1003): it is an internal
--   helper reachable only from inside a definer body, so this adds no new
--   executable surface.
--
-- WHO IS AFFECTED
--   * owner: unchanged. hr.can_access_staff passes on identity.manages_all_branches().
--   * manager (global scope, 212:5770): unchanged — manages_all_branches() is true.
--   * branch_manager with hr.finance.adjust: keeps cancelling advances of staff
--     who share their branch, or their own; now refused on a foreign branch with
--     42501 'staff member out of scope'. This is the whole point.
--   * a self-requested advance: unchanged, because can_access_staff passes on
--     `me.id = p_staff_id` (212:936) before any branch comparison.
--   * cashier and customer: unchanged; hr.require_staff() already refuses them.
--
-- WHAT BREAKS IF THIS IS WRONG
--   Only one thing can regress: a legitimate cross-branch cancellation starts
--   raising 42501. The screen already renders that refusal in its own words —
--   lib/features/hr/domain/entities/hr_refusal.dart:70 maps the exact message
--   'staff member out of scope' to S.hrOutOfScope — so the admin sees a reason,
--   not a spinner, and the advance row is untouched: cancellation is a status
--   write and nothing in this path deducts money. Rolling back is re-running 212.
--
--   It cannot strand an advance: an out-of-scope branch manager was never the
--   intended actor for that row — the list RPC already hides it from them, so
--   the only caller reaching it today is one who obtained the id out of band.
--   The finance holder of the target's branch, a global manager, or the owner
--   can still cancel it.
--
-- PRESERVED VERBATIM FROM 212
--   The signature, security definer, `set search_path = ''`, hr.require_staff(),
--   the has_permission('hr.finance.adjust') boolean, the FOR UPDATE, the not
--   found / out of scope / status / settled_amount / disbursed guards and their
--   errcodes, the UPDATE, the identity.audit call, the return value, the comment
--   and the revoke/grant pair. One statement is added; nothing is removed.
--
-- COMPANIONS
--   supabase/tests/hr_advance_cancel_scope_test.sql — behaviour test, EXECUTED
--   AND PASSED on 2026-10-31 with this function in the same rolled-back
--   transaction; the live function is still 212's, so this file stays unapplied.
--   No Dart change: admin_hr_cancel_advance already throws through the HR mapper,
--   and 'staff member out of scope' has had its sentence since 212 shipped.
--   Note for the reviewer: admin_hr_advances still answers without a limit bound
--   of its own beyond 212:4330 and the directory RPCs have the same unbounded
--   question; that is the separate open item (#30), deliberately not bundled here.
--
-- ROLLBACK: `create or replace function` with the 212 body restores the previous
-- behaviour; 212 is untouched, so re-running it is byte-for-byte the old text.

-- -----------------------------------------------------------------------------
-- admin_hr_cancel_advance: the staff scope guard the two sibling money RPCs have.
-- -----------------------------------------------------------------------------
create or replace function public.admin_hr_cancel_advance(
  p_advance_id uuid,
  p_note       text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_me uuid;
  v_adv hr.salary_advances%rowtype;
  v_can boolean;
begin
  v_me := hr.require_staff();
  v_can := identity.has_permission('hr.finance.adjust');

  select * into v_adv
    from hr.salary_advances a
   where a.id = p_advance_id
   for update;
  if not found then
    raise exception 'advance not found' using errcode = 'P0002';
  end if;
  if v_adv.requested_by <> v_me and not v_can then
    raise exception 'advance out of scope' using errcode = '42501';
  end if;
  if v_adv.status in ('settled','cancelled','rejected') then
    raise exception 'this advance cannot be cancelled' using errcode = '23514';
  end if;
  if v_adv.settled_amount > 0 then
    raise exception 'part of this advance is already recovered' using errcode = '23514';
  end if;
  if v_adv.status = 'disbursed' and not v_can then
    raise exception 'a disbursed advance can only be cancelled by finance'
      using errcode = '42501';
  end if;
  -- The advance belongs to a staff member, and only their scope may cancel it:
  -- the same assertion admin_hr_review_advance and admin_hr_disburse_advance make.
  perform hr.assert_staff_access(v_adv.staff_id);

  update hr.salary_advances
     set status = 'cancelled',
         review_note = left(btrim(coalesce(p_note, review_note)), 500)
   where id = v_adv.id;

  perform identity.audit(
    'hr.advance.cancel', 'salary_advance', v_adv.id,
    jsonb_build_object('status', v_adv.status),
    jsonb_build_object('status', 'cancelled', 'note', p_note),
    null
  );

  return jsonb_build_object('id', v_adv.id, 'status', 'cancelled');
end;
$fn$;

revoke all on function public.admin_hr_cancel_advance(uuid, text)
  from public, anon;
grant execute on function public.admin_hr_cancel_advance(uuid, text)
  to authenticated;

-- -----------------------------------------------------------------------------
-- READ-ONLY PRE-FLIGHT, run this in the SQL Editor BEFORE pasting anything above
-- -----------------------------------------------------------------------------
-- Answers the two questions this file cannot answer from the text alone. Both
-- SELECTs write nothing, and the third statement is a rollback-only rehearsal.
--
-- 1) Does the live body already carry the guard?  If it prints
--    hr.assert_staff_access, the live database was patched out of band and the
--    chain needs the repair instead — do not apply this file.
-- select pg_get_functiondef('public.admin_hr_cancel_advance(uuid, text)'::regprocedure);
--
-- 2) How many advances exist whose staff member shares no branch with a caller
--    who holds hr.finance.adjust outside their own scope?  These are the rows
--    whose cancellation changes from "allowed" to "42501". Zero rows means the
--    guard is unreachable today and is being added as a fence, not a fix in
--    motion; report that honestly instead of calling it a repaired bug.
-- select a.id, a.status, a.amount,
--        a.staff_id, sm.full_name,
--        (select array_agg(distinct r.branch_id)
--           from identity.staff_roles r where r.staff_id = a.staff_id)      as staff_branches,
--        (select array_agg(distinct r.branch_id)
--           from identity.staff_roles r
--           join identity.role_permissions rp on rp.role_id = r.role_id
--           join identity.permissions p on p.id = rp.id
--          where p.code = 'hr.finance.adjust' and r.branch_id is not null)  as finance_branches
--   from hr.salary_advances a
--   join identity.staff_members sm on sm.id = a.staff_id
--  where a.status in ('pending','approved','disbursed')
--    and a.settled_amount = 0;
--
-- 3) Rehearsal in a transaction that can never commit (same discipline as
--    supabase/tests/hr_workforce_test.sql). Paste the SQL above between these two
--    lines, then run the file with `supabase db query --linked -f <file>`; ending
--    with ROLLBACK destroys every fixture, audit row and status change.
-- begin;
-- ...
-- rollback;
