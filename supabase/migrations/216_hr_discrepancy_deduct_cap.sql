-- 216_hr_discrepancy_deduct_cap.sql
--
-- HR Phase 1 / fix 1.5, implementing decision D4.
--
-- The salary deduction cap is now enforced at the moment the deduction is
-- approved (deduct), not only later at claim time. The reserved room is every
-- approved cashier-sourced deduction of the attributed employee — claimed by
-- an earlier run or still waiting — so a decision can no longer approve a
-- shortfall a payslip could never carry. The refusal names the remaining cap.
-- The claim-time filter in admin_hr_generate_payroll stays as a second fence.
--
-- ROLLBACK: re-running the 212 body of this function restores the previous
-- behaviour byte-for-byte.

create or replace function public.admin_hr_review_discrepancy(
  p_discrepancy_id   uuid,
  p_action           text,
  p_note             text default null,
  p_evidence         text default null,
  p_attributed_staff uuid default null,
  p_deduction_amount numeric default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_me uuid;
  v_d hr.cashier_discrepancies%rowtype;
  v_action text := lower(btrim(coalesce(p_action, '')));
  v_note text := left(btrim(coalesce(p_note, '')), 1000);
  v_evidence text := left(btrim(coalesce(p_evidence, '')), 1000);
  v_amount numeric(12,2) := round(coalesce(p_deduction_amount, 0), 2);
  v_adjustment uuid;
  v_settings hr.settings%rowtype;
  v_gross numeric(12,2);
  v_committed numeric(12,2);
  v_room numeric(12,2);
begin
  v_me := hr.require_permission('hr.finance.adjust');

  select * into v_d
    from hr.cashier_discrepancies d
   where d.id = p_discrepancy_id
   for update;
  if not found then
    raise exception 'discrepancy not found' using errcode = 'P0002';
  end if;
  if not identity.can_manage_branch(v_d.branch_id) then
    raise exception 'branch out of scope' using errcode = '42501';
  end if;

  if v_action = 'explain' then
    if v_d.status not in ('pending_review','confirmed','reconciliation_required') then
      raise exception 'this discrepancy cannot be explained in its current state'
        using errcode = '23514';
    end if;
    if v_note = '' then
      raise exception 'an explanation needs a note' using errcode = '22023';
    end if;

    update hr.cashier_discrepancies
       set status = 'explained',
           review_note = v_note,
           reviewed_by = v_me,
           reviewed_at = now(),
           evidence = case when v_evidence = '' then evidence
                           when evidence = '' then v_evidence
                           else left(evidence || E'\n' || v_evidence, 2000) end
     where id = v_d.id;

  elsif v_action = 'reconcile' then
    if v_d.status not in ('pending_review','explained') then
      raise exception 'this discrepancy cannot be moved to reconciliation in its current state'
        using errcode = '23514';
    end if;

    update hr.cashier_discrepancies
       set status = 'reconciliation_required',
           review_note = case when v_note = '' then review_note else v_note end,
           reviewed_by = v_me,
           reviewed_at = now(),
           evidence = case when v_evidence = '' then evidence
                           when evidence = '' then v_evidence
                           else left(evidence || E'\n' || v_evidence, 2000) end
     where id = v_d.id;

  elsif v_action = 'confirm' then
    if v_d.status not in ('pending_review','explained','reconciliation_required') then
      raise exception 'this discrepancy cannot be confirmed in its current state'
        using errcode = '23514';
    end if;
    if p_attributed_staff is null then
      raise exception 'confirming a discrepancy requires naming the responsible employee'
        using errcode = '22023';
    end if;
    if not exists (
      select 1 from identity.staff_members sm
       where sm.id = p_attributed_staff and sm.status = 'active'
    ) then
      raise exception 'attributed employee not found or inactive' using errcode = 'P0002';
    end if;
    if p_attributed_staff is distinct from v_d.drawer_cashier_id
       and not exists (
         select 1 from identity.staff_roles sr
          where sr.staff_id = p_attributed_staff
            and sr.branch_id = v_d.branch_id
       ) then
      raise exception 'the attributed employee does not work in this branch'
        using errcode = '22023';
    end if;
    if p_attributed_staff = v_me and not hr.is_owner() then
      raise exception 'a reviewer cannot attribute a shortage to themselves'
        using errcode = '42501';
    end if;

    update hr.cashier_discrepancies
       set status = 'confirmed',
           attributed_staff_id = p_attributed_staff,
           review_note = case when v_note = '' then review_note else v_note end,
           reviewed_by = v_me,
           reviewed_at = now(),
           evidence = case when v_evidence = '' then evidence
                           when evidence = '' then v_evidence
                           else left(evidence || E'\n' || v_evidence, 2000) end
     where id = v_d.id;

  elsif v_action = 'reject' then
    if v_d.status in ('closed','deduction_approved') then
      raise exception 'this discrepancy cannot be rejected in its current state'
        using errcode = '23514';
    end if;
    if v_note = '' then
      raise exception 'rejecting a discrepancy needs a note' using errcode = '22023';
    end if;

    update hr.cashier_discrepancies
       set status = 'rejected',
           review_note = v_note,
           reviewed_by = v_me,
           reviewed_at = now(),
           evidence = case when v_evidence = '' then evidence
                           when evidence = '' then v_evidence
                           else left(evidence || E'\n' || v_evidence, 2000) end
     where id = v_d.id;

  elsif v_action = 'deduct' then
    select * into v_settings from hr.settings where id = 1;
    if v_d.status <> 'confirmed' then
      raise exception 'confirm the discrepancy before approving a deduction'
        using errcode = '23514';
    end if;
    if v_d.attributed_staff_id is null then
      raise exception 'no employee is attributed to this discrepancy' using errcode = '23514';
    end if;
    if v_d.attributed_staff_id = v_me then
      raise exception 'a reviewer cannot deduct from themselves' using errcode = '42501';
    end if;
    if not coalesce(v_settings.cashier_deduction_allowed, false) then
      raise exception 'cashier deductions are disabled in the HR settings'
        using errcode = '23514';
    end if;
    if v_amount <= 0 or v_amount > v_d.amount then
      raise exception 'the deduction must be positive and no larger than the discrepancy'
        using errcode = '22023';
    end if;

    if exists (
      select 1 from hr.adjustments a
       where a.source_type = 'cashier_discrepancy'
         and a.source_id = v_d.id
    ) then
      raise exception 'a deduction already exists for this discrepancy'
        using errcode = '23505';
    end if;
    if v_note = '' then
      raise exception 'approving a deduction needs a note explaining the decision'
        using errcode = '22023';
    end if;

    -- D4: the cap is checked at the moment of the decision, not silently later
    -- at claim time. The reserved room is every approved cashier-sourced
    -- deduction of the same employee — claimed by an earlier run or still
    -- waiting — so one decision cannot over-commit what a payslip can carry.
    select coalesce(
             round(
               c.basic_salary + c.housing_allowance
               + c.transport_allowance + c.other_allowance, 2
             ), 0
           )
      into v_gross
      from hr.compensations c
     where c.staff_id = v_d.attributed_staff_id
       and c.effective_from <= current_date
     order by c.effective_from desc
     limit 1;
    if v_gross is null or v_gross = 0 then
      raise exception 'the attributed employee has no salary record to deduct from'
        using errcode = '22023';
    end if;
    select coalesce(sum(a.amount), 0)
      into v_committed
      from hr.adjustments a
     where a.staff_id = v_d.attributed_staff_id
       and a.kind = 'deduction'
       and a.source_type = 'cashier_discrepancy'
       and a.status = 'approved';
    v_room := round(v_gross * v_settings.max_salary_deduction_percent / 100.0, 2)
              - v_committed;
    if v_amount > v_room then
      raise exception
        'the deduction exceeds the remaining salary deduction cap of %', round(v_room, 2)
        using errcode = '22023';
    end if;

    insert into hr.adjustments (
      staff_id, kind, amount, effective_date, reason, status,
      source_type, source_id, requested_by, reviewed_by, reviewed_at, review_note
    ) values (
      v_d.attributed_staff_id, 'deduction', v_amount, current_date,
      'تسوية عجز صندوق', 'approved',
      'cashier_discrepancy', v_d.id, v_me, v_me, now(),
      left(v_note, 500)
    )
    returning id into v_adjustment;

    update hr.cashier_discrepancies
       set status = 'deduction_approved',
           review_note = v_note,
           reviewed_by = v_me,
           reviewed_at = now(),
           evidence = case when v_evidence = '' then evidence
                           when evidence = '' then v_evidence
                           else left(evidence || E'\n' || v_evidence, 2000) end
     where id = v_d.id;

  elsif v_action = 'close' then
    if v_d.status not in
       ('explained','reconciliation_required','confirmed','rejected','deduction_approved') then
      raise exception 'this discrepancy cannot be closed in its current state'
        using errcode = '23514';
    end if;

    update hr.cashier_discrepancies
       set status = 'closed',
           review_note = case when v_note = '' then review_note else v_note end,
           reviewed_by = v_me,
           reviewed_at = now()
     where id = v_d.id;

  else
    raise exception 'unknown discrepancy action: %', coalesce(p_action, '')
      using errcode = '22023';
  end if;

  perform identity.audit(
    'hr.discrepancy.' || v_action,
    'cashier_discrepancy', v_d.id,
    jsonb_build_object('status', v_d.status),
    jsonb_build_object(
      'status', (select d.status from hr.cashier_discrepancies d where d.id = v_d.id),
      'attributed_staff_id', (select d.attributed_staff_id from hr.cashier_discrepancies d where d.id = v_d.id),
      'deduction_amount', case when v_action = 'deduct' then v_amount else null end,
      'note', v_note
    ),
    v_d.branch_id
  );

  return hr.discrepancy_json(v_d.id);
end;
$fn$;

comment on function public.admin_hr_review_discrepancy(
  uuid, text, text, text, uuid, numeric
) is
  'Records the review of a POS drawer variance. "deduct" is the only action '
  'that can create a salary deduction, it needs a confirmed discrepancy, an '
  'attributed employee, a positive amount within the variance, a note, and '
  'cashier deductions enabled in the HR settings.';

revoke all on function public.admin_hr_review_discrepancy(
  uuid, text, text, text, uuid, numeric
) from public, anon;
grant execute on function public.admin_hr_review_discrepancy(
  uuid, text, text, text, uuid, numeric
) to authenticated;

notify pgrst, 'reload schema';
