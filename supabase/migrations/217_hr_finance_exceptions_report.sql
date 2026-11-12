-- 217_hr_finance_exceptions_report.sql
--
-- HR Phase 1 / fix 1.7: the finance exceptions report (read-only).
--
-- One RPC answers "what money is waiting, stuck or stranded" for the branches
-- the caller manages:
--   deferred_adjustments   approved, unclaimed adjustments whose due date has
--                          already passed; these are what D2 deferral claims
--                          into the next open run, and what D3 suspension
--                          parks when the net room is gone.
--   upcoming_adjustments   approved, unclaimed adjustments dated this month or
--                          later (not yet due).
--   open_shortages         cashier discrepancies not closed or rejected, with
--                          their review state; a deduction_approved row whose
--                          adjustment is still unclaimed is a cap-blocked
--                          shortage the owner must resolve.
--   outstanding_advances   disbursed advances with money still to recover.
--   stale_requests         pending/approved advances older than 30 days.
--   terminated_open        liabilities of terminated employees: outstanding
--                          advances, unclaimed adjustments, future approved
--                          leave.
--
-- Every section is null for a caller without hr.finance.adjust; branch scope
-- filters discrepancies through identity.can_manage_branch and people rows
-- through hr.can_access_staff, exactly like the rest of HR.
--
-- ROLLBACK: drop the function and its grant.

create or replace function public.admin_hr_finance_exceptions()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
begin
  perform hr.require_permission('hr.finance.adjust');

  return jsonb_build_object(
    'generated_at', now(),
    'deferred_adjustments', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', a.id,
        'staff_id', a.staff_id,
        'staff_name', sm.full_name,
        'kind', a.kind,
        'amount', a.amount,
        'due_date', a.effective_date,
        'reason', a.reason,
        'source_type', a.source_type,
        'created_at', a.created_at
      ) order by a.effective_date)
      from hr.adjustments a
      join identity.staff_members sm on sm.id = a.staff_id
     where a.status = 'approved'
       and a.payroll_run_id is null
       and a.effective_date < date_trunc('month', current_date)
       and hr.can_access_staff(a.staff_id)
    ), '[]'::jsonb),
    'upcoming_adjustments', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', a.id,
        'staff_id', a.staff_id,
        'staff_name', sm.full_name,
        'kind', a.kind,
        'amount', a.amount,
        'due_date', a.effective_date,
        'reason', a.reason,
        'source_type', a.source_type
      ) order by a.effective_date)
      from hr.adjustments a
      join identity.staff_members sm on sm.id = a.staff_id
     where a.status = 'approved'
       and a.payroll_run_id is null
       and a.effective_date >= date_trunc('month', current_date)
       and hr.can_access_staff(a.staff_id)
    ), '[]'::jsonb),
    'open_shortages', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', d.id,
        'shift_id', d.shift_id,
        'branch_id', d.branch_id,
        'amount', d.amount,
        'signed_variance', d.signed_variance,
        'status', d.status,
        'attributed_staff_id', d.attributed_staff_id,
        'attributed_staff_name', sm.full_name,
        'deduction_claimed', exists (
          select 1 from hr.adjustments a
           where a.source_type = 'cashier_discrepancy'
             and a.source_id = d.id
             and a.payroll_run_id is not null
        ),
        'created_at', d.created_at
      ) order by d.created_at desc)
      from hr.cashier_discrepancies d
      left join identity.staff_members sm on sm.id = d.attributed_staff_id
     where d.status not in ('closed', 'rejected')
       and identity.can_manage_branch(d.branch_id)
    ), '[]'::jsonb),
    'outstanding_advances', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', a.id,
        'staff_id', a.staff_id,
        'staff_name', sm.full_name,
        'amount', a.amount,
        'settled_amount', a.settled_amount,
        'outstanding', round(a.amount - a.settled_amount, 2),
        'disbursed_at', a.disbursed_at
      ) order by a.disbursed_at)
      from hr.salary_advances a
      join identity.staff_members sm on sm.id = a.staff_id
     where a.status = 'disbursed'
       and a.settled_amount < a.amount
       and hr.can_access_staff(a.staff_id)
    ), '[]'::jsonb),
    'stale_requests', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', a.id,
        'staff_id', a.staff_id,
        'staff_name', sm.full_name,
        'status', a.status,
        'amount', a.amount,
        'created_at', a.created_at
      ) order by a.created_at)
      from hr.salary_advances a
      join identity.staff_members sm on sm.id = a.staff_id
     where a.status in ('pending', 'approved')
       and a.created_at < now() - interval '30 days'
       and hr.can_access_staff(a.staff_id)
    ), '[]'::jsonb),
    'terminated_open', coalesce((
      select jsonb_agg(jsonb_build_object(
        'staff_id', e.staff_id,
        'staff_name', sm.full_name,
        'terminated_on', e.terminated_on,
        'advance_outstanding', (
          select coalesce(sum(x.amount - x.settled_amount), 0)
            from hr.salary_advances x
           where x.staff_id = e.staff_id
             and x.status = 'disbursed'
        ),
        'unclaimed_adjustments', (
          select coalesce(sum(x.amount), 0)
            from hr.adjustments x
           where x.staff_id = e.staff_id
             and x.status = 'approved'
             and x.payroll_run_id is null
        ),
        'future_approved_leave', (
          select count(*) from hr.leave_requests x
           where x.staff_id = e.staff_id
             and x.status = 'approved'
             and x.ends_on >= current_date
        )
      ) order by sm.full_name)
      from hr.employment_records e
      join identity.staff_members sm on sm.id = e.staff_id
     where e.employment_status = 'terminated'
       and hr.can_access_staff(e.staff_id)
       and (
         exists (
           select 1 from hr.salary_advances x
            where x.staff_id = e.staff_id
              and x.status = 'disbursed'
              and x.settled_amount < x.amount
         )
         or exists (
           select 1 from hr.adjustments x
            where x.staff_id = e.staff_id
              and x.status = 'approved'
              and x.payroll_run_id is null
         )
         or exists (
           select 1 from hr.leave_requests x
            where x.staff_id = e.staff_id
              and x.status = 'approved'
              and x.ends_on >= current_date
         )
       )
    ), '[]'::jsonb)
  );
end;
$fn$;

comment on function public.admin_hr_finance_exceptions() is
  'Read-only finance exceptions for the caller''s scope: deferred and upcoming '
  'unclaimed adjustments, open cashier shortages and their claim state, '
  'outstanding advances, stale advance requests and terminated employees with '
  'open liabilities. Money sections are null without hr.finance.adjust.';

revoke all on function public.admin_hr_finance_exceptions() from public, anon;
grant execute on function public.admin_hr_finance_exceptions() to authenticated;

notify pgrst, 'reload schema';
