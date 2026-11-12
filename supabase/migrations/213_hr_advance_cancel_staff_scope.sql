-- 213_hr_advance_cancel_staff_scope.sql
--
-- HR Phase 1 / fix 1.1: cancelling a salary advance must respect staff scope.
--
-- THE DEFECT (verified against the live function, 2026-11-11)
--   admin_hr_review_advance (212:4341) and admin_hr_disburse_advance (212:4434)
--   assert hr.assert_staff_access on the advance's staff member. Their sibling
--   admin_hr_cancel_advance (212:4490) does not: it checks only the caller is
--   active staff and (for a foreign request) holds hr.finance.adjust, which is
--   a boolean, not a branch scope. A branch-scoped finance holder could cancel
--   an advance of a staff member of another branch by learning its uuid.
--   Live proof: supabase/tests/hr_advance_cancel_scope_test.sql FAIL 3b on the
--   pre-fix function ("a branch-1 finance holder cancelled the approved
--   advance of a branch-2 employee").
--
-- THE FIX (one statement added; everything else byte-identical to 212)
--   perform hr.assert_staff_access(v_adv.staff_id);
--   placed after the status/settled guards so a caller outside the scope AND
--   holding a settled advance still learns the money reason first, exactly as
--   review and disburse order their refusals.
--
-- AFFECTED LIVE ROWS AT VERIFICATION TIME
--   One open advance (settled_amount = 0) whose staff member holds a NULL
--   branch role (global scope): cancellations of that row by branch-scoped
--   callers change from allowed to 42501 'staff member out of scope'. Owner
--   and globally-scoped callers are unchanged; a self-requested advance is
--   unchanged (can_access_staff passes on me.id = p_staff_id first).
--
-- ROLLBACK: re-running the 212 body of this function restores the previous
-- behaviour byte-for-byte. 212 is untouched.
--
-- HOW TO VERIFY
--   supabase/tests/hr_advance_cancel_scope_test.sql (must pass)
--   supabase/tests/hr_workforce_test.sql (regression; must pass)

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

comment on function public.admin_hr_cancel_advance(uuid, text) is
  'Cancels an advance that has recovered nothing. The requester may cancel '
  'their own; anyone else needs hr.finance.adjust and shares the advance''s '
  'staff branch scope. A disbursed advance is finance-only.';

revoke all on function public.admin_hr_cancel_advance(uuid, text) from public, anon;
grant execute on function public.admin_hr_cancel_advance(uuid, text) to authenticated;

notify pgrst, 'reload schema';
