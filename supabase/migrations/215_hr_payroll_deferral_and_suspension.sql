-- 215_hr_payroll_deferral_and_suspension.sql
--
-- HR Phase 1 / fixes 1.4 + 1.6, implementing decisions D2 and D3.
--
-- D2 DEFERRAL: an approved, unclaimed adjustment is claimed by the first OPEN
--   payroll run whose month has started (effective_date <= period end), not
--   only by the run of its own month. The original due date is kept on the
--   row; the payslip line names the deferral ('— ترحيل من YYYY-MM'); the
--   claiming run itself is the recorded claim cycle (payroll_run_id).
-- D3 SUSPENSION: an approved deduction claims only what still fits under the
--   employee's net room. A deduction that no longer fits stays approved and
--   unclaimed (audited as hr.payroll.claim_suspended) instead of failing the
--   whole brand-level run. Nothing is dropped and nothing carries forward
--   silently: the suspended row appears in the finance exceptions report
--   (migration 217) and the owner decides its fate.
--
-- Double-claim protection is unchanged: payroll_run_id, the partial unique
-- indexes uq_payroll_line_adjustment / uq_payroll_line_advance_run and the
-- FOR UPDATE on the run row serialise concurrent generations.
-- Immutable approved/paid runs are untouched (tr_payroll_statement_immutable).
--
-- ROLLBACK: re-running the 212 body of this function restores the previous
-- behaviour byte-for-byte.

create or replace function public.admin_hr_generate_payroll(
  p_period_year  integer,
  p_period_month integer,
  p_note         text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_me               uuid;
  v_run              hr.payroll_runs%rowtype;
  v_settings         hr.settings%rowtype;
  v_start            date;
  v_period_end       date;
  v_staff            record;
  v_comp             hr.compensations%rowtype;
  v_metrics          record;
  v_adj              hr.adjustments%rowtype;
  v_adv              hr.salary_advances%rowtype;
  v_claimed          uuid[] := '{}';
  v_advance_ids      uuid[] := '{}';
  v_advance_amounts  numeric[] := '{}';
  v_allowances       numeric(12,2);
  v_gross            numeric(12,2);
  v_attendance       numeric(12,2);
  v_additions        numeric(12,2);
  v_other_deductions numeric(12,2);
  v_advance_total    numeric(12,2);
  v_cap              numeric(12,2);
  v_planned          numeric(12,2);
  v_advance_amount   numeric(12,2);
  v_remaining        numeric(12,2);
  v_statement_id     uuid;
  v_count            integer := 0;
  v_total_gross      numeric(14,2) := 0;
  v_total_deductions numeric(14,2) := 0;
  v_total_net        numeric(14,2) := 0;
  v_previous_status  text;
  i                  integer;
begin
  v_me := hr.require_permission('hr.payroll.manage');
  if not identity.manages_all_branches() then
    raise exception 'payroll runs answer for the whole brand and need all-branch scope'
      using errcode = '42501';
  end if;
  if p_period_year is null or p_period_year < 2000 or p_period_year > 2100 then
    raise exception 'invalid payroll year' using errcode = '22023';
  end if;
  if p_period_month is null or p_period_month not between 1 and 12 then
    raise exception 'invalid payroll month' using errcode = '22023';
  end if;

  v_start := make_date(p_period_year, p_period_month, 1);
  v_period_end := (v_start + interval '1 month')::date - 1;
  if v_start > current_date then
    raise exception 'this payroll period has not started yet' using errcode = '22023';
  end if;

  select * into v_settings from hr.settings where id = 1;

  select * into v_run
    from hr.payroll_runs r
   where r.period_year = p_period_year
     and r.period_month = p_period_month
   for update;

  if found then
    if v_run.status in ('approved','paid') then
      raise exception 'this payroll period is already approved; use a correction'
        using errcode = '23514';
    end if;
    v_previous_status := v_run.status;
    if v_run.status = 'cancelled' then
      update hr.payroll_runs set status = 'draft' where id = v_run.id;
    end if;
    -- Recalculation starts from a clean slate; claims are released first so a
    -- regenerated run can pick the same adjustments again.
    delete from hr.payroll_statements where run_id = v_run.id;
    update hr.adjustments set payroll_run_id = null where payroll_run_id = v_run.id;
  else
    insert into hr.payroll_runs (period_year, period_month, note)
    values (p_period_year, p_period_month, left(btrim(coalesce(p_note, '')), 500))
    returning * into v_run;
    v_previous_status := 'draft';
  end if;

  for v_staff in
    select sm.id as staff_id, sm.full_name
      from identity.staff_members sm
      join hr.employment_records e on e.staff_id = sm.id
     where sm.status = 'active'
       and coalesce(e.employment_status, 'active') <> 'terminated'
       and exists (
         select 1
           from hr.compensations c
          where c.staff_id = sm.id
            and c.effective_from <= v_period_end
            and (c.effective_to is null or c.effective_to >= v_start)
       )
     order by sm.full_name, sm.id
  loop
    select * into v_comp
      from hr.compensations c
     where c.staff_id = v_staff.staff_id
       and c.effective_from <= v_period_end
     order by c.effective_from desc
     limit 1;

    select * into v_metrics
      from hr.attendance_metrics(v_staff.staff_id, v_start, v_period_end);

    v_allowances := round(
      v_comp.housing_allowance + v_comp.transport_allowance
      + v_comp.other_allowance, 2
    );
    v_gross := round(v_comp.basic_salary + v_allowances, 2);
    v_attendance := round(
        v_metrics.absence_days * v_settings.absence_day_rate
      + v_metrics.late_minutes * v_settings.late_minute_rate
      + v_metrics.early_minutes * v_settings.early_minute_rate, 2);
    -- A policy deduction can never turn a salary negative; the excess is not
    -- carried anywhere, which is why the rates start at zero and stay visible.
    if v_attendance > v_gross then
      v_attendance := v_gross;
    end if;

    v_additions := 0;
    v_other_deductions := 0;
    v_claimed := '{}';
    v_cap := round(v_gross * v_settings.max_salary_deduction_percent / 100.0, 2);

    for v_adj in
      select a.*
        from hr.adjustments a
       where a.staff_id = v_staff.staff_id
         and a.status = 'approved'
         and a.payroll_run_id is null
         and a.effective_date <= v_period_end
       order by a.effective_date, a.created_at, a.id
    loop
      if v_adj.kind = 'deduction' then
        if v_adj.source_type = 'cashier_discrepancy' then
          if not v_settings.cashier_deduction_allowed
             or v_adj.amount > v_cap then
            continue;
          end if;
          v_cap := v_cap - v_adj.amount;
        end if;
        v_other_deductions := v_other_deductions + v_adj.amount;
      else
        v_additions := v_additions + v_adj.amount;
      end if;
      -- D3: an approved deduction claims only what still fits under the net
      -- room of this employee's gross. A deduction that no longer fits stays
      -- approved and unclaimed (its own suspension is audited below) instead
      -- of failing the whole brand-level run.
      if v_adj.kind = 'deduction'
         and round(v_other_deductions + v_adj.amount, 2)
             > round(v_gross - v_attendance, 2) then
        perform identity.audit(
          'hr.payroll.claim_suspended',
          'adjustment', v_adj.id,
          null,
          jsonb_build_object(
            'reason', 'deduction exceeds remaining net room',
            'period', p_period_year || '-' || lpad(p_period_month::text, 2, '0'),
            'amount', v_adj.amount
          ),
          null
        );
        continue;
      end if;
      v_claimed := v_claimed || v_adj.id;
    end loop;

    v_remaining := round(v_gross - v_attendance - v_other_deductions, 2);
    -- D3: a negative room is impossible now that every deduction claims only
    -- what fits; the excess stays approved and unclaimed for the owner to
    -- resolve (see the finance exceptions report). Advance recovery below
    -- claims only the remaining room, exactly as before.

    v_advance_total := 0;
    v_advance_ids := '{}';
    v_advance_amounts := '{}';

    for v_adv in
      select a.*
        from hr.salary_advances a
       where a.staff_id = v_staff.staff_id
         and a.status = 'disbursed'
         and a.settled_amount < a.amount
       order by a.created_at, a.id
    loop
      v_planned := least(
        coalesce(v_adv.installment_amount, v_adv.amount - v_adv.settled_amount),
        v_adv.amount - v_adv.settled_amount
      );
      v_advance_amount := round(least(v_planned, v_remaining), 2);
      if v_advance_amount <= 0 then
        continue;
      end if;
      v_advance_ids := v_advance_ids || v_adv.id;
      v_advance_amounts := v_advance_amounts || v_advance_amount;
      v_advance_total := v_advance_total + v_advance_amount;
      v_remaining := round(v_remaining - v_advance_amount, 2);
    end loop;

    v_advance_total := round(v_advance_total, 2);

    insert into hr.payroll_statements (
      run_id, staff_id, basic_salary, allowances_total, additions_total,
      attendance_deduction, advance_deduction, other_deductions,
      deductions_total, absence_days, late_minutes, early_minutes,
      gross, net, currency_code
    ) values (
      v_run.id, v_staff.staff_id, round(v_comp.basic_salary, 2), v_allowances,
      round(v_additions, 2), v_attendance, v_advance_total,
      round(v_other_deductions, 2),
      round(v_attendance + v_advance_total + v_other_deductions, 2),
      v_metrics.absence_days, v_metrics.late_minutes, v_metrics.early_minutes,
      v_gross, round(v_remaining, 2), v_comp.currency_code
    )
    returning id into v_statement_id;

    insert into hr.payroll_line_items (
      statement_id, payroll_run_id, kind, category, source_type,
      source_id, label, amount
    ) values (
      v_statement_id, v_run.id, 'addition', 'basic', 'compensation',
      v_comp.id, '@basic', round(v_comp.basic_salary, 2)
    );

    if v_comp.housing_allowance > 0 then
      insert into hr.payroll_line_items (
        statement_id, payroll_run_id, kind, category, source_type,
        source_id, label, amount
      ) values (
        v_statement_id, v_run.id, 'addition', 'allowance', 'compensation',
        v_comp.id, '@housing_allowance', v_comp.housing_allowance
      );
    end if;

    if v_comp.transport_allowance > 0 then
      insert into hr.payroll_line_items (
        statement_id, payroll_run_id, kind, category, source_type,
        source_id, label, amount
      ) values (
        v_statement_id, v_run.id, 'addition', 'allowance', 'compensation',
        v_comp.id, '@transport_allowance', v_comp.transport_allowance
      );
    end if;

    if v_comp.other_allowance > 0 then
      insert into hr.payroll_line_items (
        statement_id, payroll_run_id, kind, category, source_type,
        source_id, label, amount
      ) values (
        v_statement_id, v_run.id, 'addition', 'allowance', 'compensation',
        v_comp.id, '@other_allowance', v_comp.other_allowance
      );
    end if;

    if v_attendance > 0 then
      insert into hr.payroll_line_items (
        statement_id, payroll_run_id, kind, category, source_type,
        source_id, label, amount
      ) values (
        v_statement_id, v_run.id, 'deduction', 'attendance', 'attendance_policy',
        null, '@attendance', v_attendance
      );
    end if;

    for i in 1 .. coalesce(array_length(v_claimed, 1), 0) loop
      select * into v_adj from hr.adjustments where id = v_claimed[i];
      insert into hr.payroll_line_items (
        statement_id, payroll_run_id, kind, category, source_type,
        source_id, label, amount
      ) values (
        v_statement_id, v_run.id,
        case when v_adj.kind = 'deduction' then 'deduction' else 'addition' end,
        case
          when v_adj.kind <> 'deduction' then v_adj.kind
          when v_adj.source_type = 'cashier_discrepancy' then 'cashier_shortage'
          when v_adj.source_type = 'payroll_correction' then 'correction'
          else 'manual'
        end,
        'adjustment', v_adj.id,
        case when v_adj.effective_date < v_start then
          left(v_adj.reason, 100) || ' — ترحيل من '
            || to_char(v_adj.effective_date, 'YYYY-MM')
        else left(v_adj.reason, 120) end, v_adj.amount
      );
      update hr.adjustments
         set payroll_run_id = v_run.id
       where id = v_adj.id;
    end loop;

    for i in 1 .. coalesce(array_length(v_advance_ids, 1), 0) loop
      insert into hr.payroll_line_items (
        statement_id, payroll_run_id, kind, category, source_type,
        source_id, label, amount
      ) values (
        v_statement_id, v_run.id, 'deduction', 'advance', 'salary_advance',
        v_advance_ids[i], '@advance', v_advance_amounts[i]
      );
    end loop;

    v_count := v_count + 1;
    v_total_gross := v_total_gross + round(v_comp.basic_salary + v_allowances + v_additions, 2);
    v_total_deductions := v_total_deductions
      + round(v_attendance + v_advance_total + v_other_deductions, 2);
    v_total_net := v_total_net + round(v_remaining, 2);
  end loop;

  update hr.payroll_runs
     set status = 'calculated',
         calculated_by = v_me,
         calculated_at = now(),
         total_gross = v_total_gross,
         total_deductions = v_total_deductions,
         total_net = v_total_net,
         statement_count = v_count,
         note = case
                  when nullif(btrim(coalesce(p_note, '')), '') is null then note
                  else left(btrim(p_note), 500)
                end
   where id = v_run.id
   returning * into v_run;

  perform identity.audit(
    'hr.payroll.calculate',
    'payroll_run', v_run.id,
    jsonb_build_object('status', v_previous_status),
    jsonb_build_object(
      'period_year', p_period_year,
      'period_month', p_period_month,
      'status', 'calculated',
      'statement_count', v_count,
      'total_net', v_total_net
    ),
    null
  );

  return jsonb_build_object(
    'run_id', v_run.id,
    'period_year', p_period_year,
    'period_month', p_period_month,
    'status', 'calculated',
    'statement_count', v_count,
    'total_gross', v_total_gross,
    'total_deductions', v_total_deductions,
    'total_net', v_total_net
  );
end;
$fn$;


comment on function public.admin_hr_generate_payroll(integer, integer, text) is
  'Calculates one brand-level payroll period from compensating records, '
  'attendance, approved adjustments and disbursed advances. Recalculating a '
  'draft or calculated run replaces its statements and releases their claims.';

revoke all on function public.admin_hr_generate_payroll(integer, integer, text)
  from public, anon;
grant execute on function public.admin_hr_generate_payroll(integer, integer, text)
  to authenticated;

notify pgrst, 'reload schema';
