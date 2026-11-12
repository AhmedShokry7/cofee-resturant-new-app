-- 214_hr_leave_cancel_reviewer_scope.sql
--
-- HR Phase 1 / fix 1.2: a leave reviewer may cancel only inside their scope.
--
-- THE DEFECT (read from the live text of 212 hr_cancel_leave_request)
--   hr_cancel_leave_request accepts the requester (self) or any holder of
--   hr.leave.review. The review arm has no hr.assert_staff_access, so a
--   branch-scoped leave reviewer could cancel the leave request of an
--   employee of another branch by knowing its uuid — a row their list RPC
--   (admin_hr_leave_requests) never shows them.
--   admin_hr_review_leave (212:2946) already asserts the scope; the cancel arm
--   is the gap. Same class of defect as 213 (advance cancel), same fix shape.
--
-- THE FIX (one statement added; everything else byte-identical to 212)
--   perform hr.assert_staff_access(v_req.staff_id);
--   placed after the existing guards (money/state reasons first, scope last —
--   the ordering convention 213 established and review/disburse already use).
--   The self path is untouched: hr.assert_staff_access passes on
--   me.id = p_staff_id before any branch comparison.
--
-- ROLLBACK: re-running the 212 body of this function restores the previous
-- behaviour byte-for-byte. 212 is untouched.
--
-- HOW TO VERIFY
--   supabase/tests/hr_leave_cancel_scope_test.sql (new companion test)
--   supabase/tests/hr_workforce_test.sql (regression)

create or replace function public.hr_cancel_leave_request(
  p_request_id uuid,
  p_note       text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_me uuid;
  v_req hr.leave_requests%rowtype;
  v_days integer;
  v_tracks boolean;
begin
  v_me := hr.require_staff();
  select * into v_req
    from hr.leave_requests r
   where r.id = p_request_id
   for update;
  if not found then
    raise exception 'leave request not found' using errcode = 'P0002';
  end if;
  if v_req.requested_by <> v_me
     and not identity.has_permission('hr.leave.review') then
    raise exception 'leave request out of scope' using errcode = '42501';
  end if;
  if v_req.status not in ('pending','approved') then
    raise exception 'leave request cannot be cancelled in its current state'
      using errcode = '23514';
  end if;
  -- A reviewer may cancel only inside the staff branch scope of the request:
  -- the same assertion admin_hr_review_leave makes, and the same convention
  -- 213 applied to advances. The self path passes before any branch check.
  perform hr.assert_staff_access(v_req.staff_id);

  v_days := (v_req.ends_on - v_req.starts_on) + 1;
  select t.tracks_balance into v_tracks
    from hr.leave_types t where t.id = v_req.leave_type_id;

  if v_req.status = 'approved' and v_tracks then
    update hr.leave_balances
       set used_days = greatest(0, used_days - v_days)
     where staff_id = v_req.staff_id
       and leave_type_id = v_req.leave_type_id
       and year = extract(year from v_req.starts_on)::integer;
  end if;

  update hr.leave_requests
     set status = 'cancelled',
         review_note = left(btrim(coalesce(p_note, review_note)), 500)
   where id = v_req.id;

  perform identity.audit(
    'hr.leave.cancel',
    'leave_request', v_req.id,
    jsonb_build_object('status', v_req.status),
    jsonb_build_object('status', 'cancelled', 'note', p_note),
    null
  );

  return jsonb_build_object('id', v_req.id, 'status', 'cancelled');
end;
$fn$;

comment on function public.hr_cancel_leave_request(uuid, text) is
  'The requester cancels their own pending or approved leave; a holder of '
  'hr.leave.review may cancel within the requester''s staff branch scope. '
  'Cancelling an approved balance-tracked leave returns its days.';

revoke all on function public.hr_cancel_leave_request(uuid, text) from public, anon;
grant execute on function public.hr_cancel_leave_request(uuid, text) to authenticated;

notify pgrst, 'reload schema';
