-- 242_hr_payroll_workflow.sql
--
-- HR Phase 4: the professional payroll workflow on top of the existing engine.
--
--   2-5  admin_hr_preview_payroll (new, read-only): validates the inputs,
--        lists missing data, mirrors the calculation per employee (metrics v2,
--        D2 deferral, D3 suspension, D4 cap, advance recovery) and compares
--        with the previous paid month. Writes nothing.
--   6    every generation stamps a real version: hr.payroll_runs.calc_seq
--        increments per generation and its statements carry 'hr-' || calc_seq
--        (existing approved/paid snapshots keep their stored version).
--   7-9  approve refuses an EMPTY run (a miscalculation, not an approvable);
--        the SoD, all-branch scope and advance-attachment checks are unchanged.
--   10   payslips stay visible to their employee only once approved/paid —
--        already true (212), documented here as the publishing gate.
--   11   admin_hr_close_payroll_period (new): seals a PAID period; a closed
--        period keeps its payslips readable but refuses further corrections.
--
-- ROLLBACK: drop admin_hr_preview_payroll / admin_hr_close_payroll_period and
-- the calc_seq/closed columns, then re-run the 212 bodies of the touched
-- functions. 212 is untouched.

alter table hr.payroll_runs
  add column if not exists calc_seq integer not null default 0,
  add column if not exists closed_by uuid references identity.staff_members(id) on delete set null,
  add column if not exists closed_at timestamptz;

CREATE OR REPLACE FUNCTION public.admin_hr_generate_payroll(p_period_year integer, p_period_month integer, p_note text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
as $fn$declare
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
  v_unpaid           numeric(12,2);
  v_calc_seq         integer;
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

  -- Workflow step 6: every generation stamps a real calculation version so a
  -- regenerated run is distinguishable from its predecessor.
  update hr.payroll_runs
     set calc_seq = calc_seq + 1
   where id = v_run.id
   returning calc_seq into v_calc_seq;

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
      from hr.attendance_metrics_v2(v_staff.staff_id, v_start, v_period_end);

    v_allowances := round(
      v_comp.housing_allowance + v_comp.transport_allowance
      + v_comp.other_allowance, 2
    );
    v_gross := round(v_comp.basic_salary + v_allowances, 2);
    -- D1: unpaid leave days leave the absence column of the metrics and take
    -- their money from their own rate; the two never overlap.
    v_unpaid := round(
      v_metrics.unpaid_leave_days * v_settings.unpaid_leave_day_rate, 2);
    if v_unpaid > v_gross then
      v_unpaid := v_gross;
    end if;
    v_attendance := least(
      round(
        v_metrics.absence_days * v_settings.absence_day_rate
        + v_metrics.late_minutes * v_settings.late_minute_rate
        + v_metrics.early_minutes * v_settings.early_minute_rate, 2
      ),
      v_gross - v_unpaid
    );
    v_attendance := round(v_attendance + v_unpaid, 2);

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
      gross, net, currency_code, calculation_version
    ) values (
      v_run.id, v_staff.staff_id, round(v_comp.basic_salary, 2), v_allowances,
      round(v_additions, 2), v_attendance, v_advance_total,
      round(v_other_deductions, 2),
      round(v_attendance + v_advance_total + v_other_deductions, 2),
      v_metrics.absence_days, v_metrics.late_minutes, v_metrics.early_minutes,
      v_gross, round(v_remaining, 2), v_comp.currency_code,
      'hr-' || v_calc_seq
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

    if v_unpaid > 0 then
      insert into hr.payroll_line_items (
        statement_id, payroll_run_id, kind, category, source_type,
        source_id, label, amount
      ) values (
        v_statement_id, v_run.id, 'deduction', 'attendance', 'attendance_policy',
        null, '@unpaid_leave', v_unpaid
      );
    end if;
    if round(v_attendance - v_unpaid, 2) > 0 then
      insert into hr.payroll_line_items (
        statement_id, payroll_run_id, kind, category, source_type,
        source_id, label, amount
      ) values (
        v_statement_id, v_run.id, 'deduction', 'attendance', 'attendance_policy',
        null, '@attendance', round(v_attendance - v_unpaid, 2)
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

CREATE OR REPLACE FUNCTION public.admin_hr_approve_payroll(p_run_id uuid, p_note text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
as $fn$declare
  v_me uuid;
  v_run hr.payroll_runs%rowtype;
  v_note text := left(btrim(coalesce(p_note, '')), 500);
begin
  v_me := hr.require_permission('hr.payroll.approve');
  if not identity.manages_all_branches() then
    raise exception 'approving a payroll run needs all-branch scope'
      using errcode = '42501';
  end if;

  select * into v_run
    from hr.payroll_runs r
   where r.id = p_run_id
   for update;
  if not found then
    raise exception 'payroll run not found' using errcode = 'P0002';
  end if;
  if v_run.status <> 'calculated' then
    raise exception 'only a calculated run can be approved' using errcode = '23514';
  end if;
  -- Workflow step 8: an empty run is a miscalculation, not an approvable one.
  if v_run.statement_count = 0 then
    raise exception 'this run has no statements; nothing to approve'
      using errcode = '23514';
  end if;
  if v_run.calculated_by = v_me and not hr.is_owner() then
    raise exception 'the person who calculated this run cannot approve it'
      using errcode = '42501';
  end if;

  -- Advances are settled from the snapshot's own line items, and only when
  -- the remaining balance still covers the installment.
  if exists (
    select 1
      from hr.payroll_line_items l
      join hr.salary_advances a on a.id = l.source_id
     where l.payroll_run_id = v_run.id
       and l.source_type = 'salary_advance'
       and (
         a.status <> 'disbursed'
         or a.settled_amount + l.amount > a.amount
       )
  ) then
    raise exception 'an advance in this run changed after calculation; regenerate the run'
      using errcode = '23514';
  end if;

  update hr.payroll_runs
     set status = 'approved',
         approved_by = v_me,
         approved_at = now(),
         note = case when v_note = '' then note else v_note end
   where id = v_run.id
   returning * into v_run;

  update hr.salary_advances a
     set settled_amount = a.settled_amount + l.amount,
         status = case
                    when a.settled_amount + l.amount >= a.amount then 'settled'
                    else 'disbursed'
                  end
    from (
      select source_id, amount
        from hr.payroll_line_items
       where payroll_run_id = v_run.id
         and source_type = 'salary_advance'
         and source_id is not null
    ) l
   where a.id = l.source_id;

  perform identity.audit(
    'hr.payroll.approve',
    'payroll_run', v_run.id,
    jsonb_build_object('status', 'calculated'),
    jsonb_build_object(
      'status', 'approved',
      'period_year', v_run.period_year,
      'period_month', v_run.period_month,
      'total_net', v_run.total_net,
      'note', v_note
    ),
    null
  );

  return jsonb_build_object(
    'run_id', v_run.id,
    'status', 'approved',
    'approved_at', v_run.approved_at
  );
end;
$fn$;

CREATE OR REPLACE FUNCTION public.admin_hr_payroll_correction(p_statement_id uuid, p_kind text, p_amount numeric, p_reason text, p_effective_date date DEFAULT NULL::date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
as $fn$declare
  v_me uuid;
  v_staff_id uuid;
  v_run_status text;
  v_period_year integer;
  v_period_month integer;
  v_closed_at timestamptz;
  v_kind text := btrim(coalesce(p_kind, ''));
  v_amount numeric(12,2) := round(coalesce(p_amount, 0), 2);
  v_effective date := coalesce(
    p_effective_date,
    (date_trunc('month', current_date) + interval '1 month')::date
  );
  v_id uuid;
begin
  v_me := hr.require_permission('hr.payroll.manage');

  select st.staff_id, r.status, r.period_year, r.period_month, r.closed_at
    into v_staff_id, v_run_status, v_period_year, v_period_month, v_closed_at
    from hr.payroll_statements st
    join hr.payroll_runs r on r.id = st.run_id
   where st.id = p_statement_id;

  if v_staff_id is null then
    raise exception 'payslip not found' using errcode = 'P0002';
  end if;
  if v_run_status not in ('approved','paid') then
    raise exception 'a correction applies to an approved or paid payslip'
      using errcode = '23514';
  end if;
  -- Workflow step 11: a closed period seals its payslips for good.
  if v_closed_at is not null then
    raise exception 'the payroll period is already closed' using errcode = '23514';
  end if;
  perform hr.assert_staff_access(v_staff_id);
  if v_kind not in ('allowance','bonus','commission','overtime','deduction') then
    raise exception 'invalid correction kind' using errcode = '22023';
  end if;
  if v_amount <= 0 then
    raise exception 'correction amount must be positive' using errcode = '22023';
  end if;
  if nullif(btrim(coalesce(p_reason, '')), '') is null then
    raise exception 'a correction needs a reason' using errcode = '22023';
  end if;
  if v_effective <= make_date(v_period_year, v_period_month, 1) then
    raise exception 'a correction starts after the corrected period'
      using errcode = '22023';
  end if;

  insert into hr.adjustments (
    staff_id, kind, amount, effective_date, reason, status,
    source_type, source_id, requested_by
  ) values (
    v_staff_id, v_kind, v_amount, v_effective,
    left(btrim(p_reason), 500), 'pending',
    'payroll_correction', p_statement_id, v_me
  )
  returning id into v_id;

  perform identity.audit(
    'hr.payroll.correction',
    'adjustment', v_id,
    null,
    jsonb_build_object(
      'statement_id', p_statement_id,
      'kind', v_kind,
      'amount', v_amount,
      'effective_date', v_effective
    ),
    null
  );

  return jsonb_build_object(
    'id', v_id,
    'staff_id', v_staff_id,
    'kind', v_kind,
    'amount', v_amount,
    'status', 'pending',
    'effective_date', v_effective
  );
end;
$fn$;

CREATE OR REPLACE FUNCTION public.admin_hr_payroll_runs(p_limit integer DEFAULT 24)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
as $fn$declare
  v_scope_all boolean;
begin
  perform hr.require_permission('hr.payroll.read');
  v_scope_all := identity.manages_all_branches();

  return coalesce((
    select jsonb_agg(row_json order by period_year desc, period_month desc)
    from (
      select
        r.period_year,
        r.period_month,
        jsonb_build_object(
          'run_id', r.id,
          'period_year', r.period_year,
          'period_month', r.period_month,
          'status', r.status,
          'statement_count', s.statement_count,
          'total_gross', s.total_gross,
          'total_deductions', s.total_deductions,
          'total_net', s.total_net,
          'calculated_at', r.calculated_at,
          'approved_at', r.approved_at,
          'paid_at', r.paid_at,
          'note', r.note,
          'calc_seq', r.calc_seq,
          'closed_at', r.closed_at,
          'scope', case when v_scope_all then 'brand' else 'branches' end
        ) as row_json
      from hr.payroll_runs r
      cross join lateral (
        select count(*)::integer as statement_count,
               coalesce(sum(st.gross), 0) as total_gross,
               coalesce(sum(st.deductions_total), 0) as total_deductions,
               coalesce(sum(st.net), 0) as total_net
          from hr.payroll_statements st
         where st.run_id = r.id
           and hr.can_access_staff(st.staff_id)
      ) s
      order by r.period_year desc, r.period_month desc
      limit greatest(1, least(coalesce(p_limit, 24), 120))
    ) rows
  ), '[]'::jsonb);
end;
$fn$;

CREATE OR REPLACE FUNCTION public.admin_hr_payroll_run(p_run_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
as $fn$declare
  v_payload jsonb;
begin
  perform hr.require_permission('hr.payroll.read');

  select jsonb_build_object(
    'run_id', r.id,
    'period_year', r.period_year,
    'period_month', r.period_month,
    'status', r.status,
    'note', r.note,
    'calculated_at', r.calculated_at,
    'approved_at', r.approved_at,
    'paid_at', r.paid_at,
    'calc_seq', r.calc_seq,
    'closed_at', r.closed_at,
    'scope', case when identity.manages_all_branches() then 'brand' else 'branches' end,
    'statement_count', jsonb_array_length(coalesce((
      select jsonb_agg(st.id)
        from hr.payroll_statements st
       where st.run_id = r.id
         and hr.can_access_staff(st.staff_id)
    ), '[]'::jsonb)),
    'total_gross', coalesce((
      select sum(st.gross) from hr.payroll_statements st
       where st.run_id = r.id and hr.can_access_staff(st.staff_id)
    ), 0),
    'total_deductions', coalesce((
      select sum(st.deductions_total) from hr.payroll_statements st
       where st.run_id = r.id and hr.can_access_staff(st.staff_id)
    ), 0),
    'total_net', coalesce((
      select sum(st.net) from hr.payroll_statements st
       where st.run_id = r.id and hr.can_access_staff(st.staff_id)
    ), 0),
    'statements', coalesce((
      select jsonb_agg(hr.statement_json(st.id) order by sm.full_name)
        from hr.payroll_statements st
        join identity.staff_members sm on sm.id = st.staff_id
       where st.run_id = r.id
         and hr.can_access_staff(st.staff_id)
    ), '[]'::jsonb)
  )
  into v_payload
  from hr.payroll_runs r
  where r.id = p_run_id;

  if v_payload is null then
    raise exception 'payroll run not found' using errcode = 'P0002';
  end if;
  return v_payload;
end;
$fn$;

create or replace function public.admin_hr_close_payroll_period(
  p_run_id uuid,
  p_note   text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_me uuid;
  v_run hr.payroll_runs%rowtype;
begin
  v_me := hr.require_permission('hr.payroll.pay');
  if not identity.manages_all_branches() then
    raise exception 'closing a payroll period needs all-branch scope'
      using errcode = '42501';
  end if;

  select * into v_run
    from hr.payroll_runs r
   where r.id = p_run_id
   for update;
  if not found then
    raise exception 'payroll run not found' using errcode = 'P0002';
  end if;
  if v_run.status <> 'paid' then
    raise exception 'only a paid run can be closed' using errcode = '23514';
  end if;
  if v_run.closed_at is not null then
    raise exception 'the payroll period is already closed' using errcode = '23514';
  end if;

  update hr.payroll_runs
     set closed_by = v_me,
         closed_at = now(),
         note = case when nullif(btrim(coalesce(p_note, '')), '') is null then note
                     else left(btrim(p_note), 500) end
   where id = p_run_id
   returning * into v_run;

  perform identity.audit(
    'hr.payroll.close',
    'payroll_run', v_run.id,
    jsonb_build_object('closed_at', null),
    jsonb_build_object('closed_at', v_run.closed_at, 'note', p_note),
    null
  );

  return jsonb_build_object(
    'run_id', v_run.id,
    'status', v_run.status,
    'closed_at', v_run.closed_at
  );
end;
$fn$;

comment on function public.admin_hr_close_payroll_period(uuid, text) is
  'Workflow step 11: seals a paid period. A closed period keeps its payslips '
  'readable but refuses further corrections.';

revoke all on function public.admin_hr_close_payroll_period(uuid, text)
  from public, anon;
grant execute on function public.admin_hr_close_payroll_period(uuid, text)
  to authenticated;

notify pgrst, 'reload schema';

create or replace function public.admin_hr_preview_payroll(
  p_period_year  integer,
  p_period_month integer
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_settings      hr.settings%rowtype;
  v_start         date;
  v_period_end    date;
  v_run           hr.payroll_runs%rowtype;
  v_prev_run      hr.payroll_runs%rowtype;
  v_staff         record;
  v_comp          hr.compensations%rowtype;
  v_metrics       record;
  v_adj_row       hr.adjustments%rowtype;
  v_adv           hr.salary_advances%rowtype;
  v_allowances    numeric(12,2);
  v_gross         numeric(12,2);
  v_unpaid        numeric(12,2);
  v_att_base      numeric(12,2);
  v_attendance    numeric(12,2);
  v_additions     numeric(12,2);
  v_other_ded     numeric(12,2);
  v_cap           numeric(12,2);
  v_remaining     numeric(12,2);
  v_planned       numeric(12,2);
  v_advance_amt   numeric(12,2);
  v_advance_total numeric(12,2);
  v_lines         jsonb := '[]'::jsonb;
  v_prev_net      numeric(12,2);
  v_employees     jsonb := '[]'::jsonb;
  v_missing       jsonb := '[]'::jsonb;
  v_adj_due       jsonb;
begin
  perform hr.require_permission('hr.payroll.manage');
  if not identity.manages_all_branches() then
    raise exception 'the payroll preview needs all-branch scope'
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
  select * into v_run from hr.payroll_runs r
   where r.period_year = p_period_year and r.period_month = p_period_month;
  select * into v_prev_run from hr.payroll_runs r
   where r.period_year = p_period_year - case when p_period_month = 1 then 1 else 0 end
     and r.period_month = case when p_period_month = 1 then 12 else p_period_month - 1 end;

  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'id', a.id,
               'staff_id', a.staff_id,
               'staff_name', sm.full_name,
               'kind', a.kind,
               'amount', a.amount,
               'due_date', a.effective_date,
               'reason', a.reason,
               'source_type', a.source_type,
               'deferred', a.effective_date < v_start
             ) order by a.effective_date, a.created_at, a.id
           ),
           '[]'::jsonb
         )
    into v_adj_due
    from hr.adjustments a
    join identity.staff_members sm on sm.id = a.staff_id
   where a.status = 'approved'
     and a.payroll_run_id is null
     and a.effective_date <= v_period_end;

  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'staff_id', sm.id,
               'staff_name', sm.full_name,
               'reason', 'no compensation covering the period'
             ) order by sm.full_name
           ),
           '[]'::jsonb
         )
    into v_missing
    from identity.staff_members sm
    join hr.employment_records e on e.staff_id = sm.id
   where sm.status = 'active'
     and coalesce(e.employment_status, 'active') <> 'terminated'
     and not exists (
       select 1 from hr.compensations c
        where c.staff_id = sm.id
          and c.effective_from <= v_period_end
          and (c.effective_to is null or c.effective_to >= v_start)
     );

  for v_staff in
    select sm.id as staff_id, sm.full_name
      from identity.staff_members sm
      join hr.employment_records e on e.staff_id = sm.id
     where sm.status = 'active'
       and coalesce(e.employment_status, 'active') <> 'terminated'
       and exists (
         select 1 from hr.compensations c
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
      from hr.attendance_metrics_v2(v_staff.staff_id, v_start, v_period_end);

    v_lines := '[]'::jsonb;
    v_allowances := round(
      v_comp.housing_allowance + v_comp.transport_allowance
      + v_comp.other_allowance, 2);
    v_gross := round(v_comp.basic_salary + v_allowances, 2);
    v_unpaid := round(
      v_metrics.unpaid_leave_days * v_settings.unpaid_leave_day_rate, 2);
    if v_unpaid > v_gross then
      v_unpaid := v_gross;
    end if;
    v_att_base := least(
      round(
        v_metrics.absence_days * v_settings.absence_day_rate
        + v_metrics.late_minutes * v_settings.late_minute_rate
        + v_metrics.early_minutes * v_settings.early_minute_rate, 2
      ),
      v_gross - v_unpaid
    );
    v_attendance := round(v_att_base + v_unpaid, 2);
    v_additions := 0;
    v_other_ded := 0;
    v_cap := round(v_gross * v_settings.max_salary_deduction_percent / 100.0, 2);

    for v_adj_row in
      select a.*
        from hr.adjustments a
       where a.staff_id = v_staff.staff_id
         and a.status = 'approved'
         and a.payroll_run_id is null
         and a.effective_date <= v_period_end
       order by a.effective_date, a.created_at, a.id
    loop
      if v_adj_row.kind = 'deduction' then
        if v_adj_row.source_type = 'cashier_discrepancy' then
          if not v_settings.cashier_deduction_allowed
             or v_adj_row.amount > v_cap then
            v_lines := v_lines || jsonb_build_object(
              'kind', 'deduction', 'state', 'cap_blocked',
              'label', left(v_adj_row.reason, 120), 'amount', v_adj_row.amount);
            continue;
          end if;
          v_cap := v_cap - v_adj_row.amount;
        end if;
        if round(v_other_ded + v_adj_row.amount, 2)
           > round(v_gross - v_attendance, 2) then
          v_lines := v_lines || jsonb_build_object(
            'kind', 'deduction', 'state', 'suspended',
            'label', left(v_adj_row.reason, 120), 'amount', v_adj_row.amount);
          continue;
        end if;
        v_other_ded := v_other_ded + v_adj_row.amount;
      else
        v_additions := v_additions + v_adj_row.amount;
      end if;
      v_lines := v_lines || jsonb_build_object(
        'kind', case when v_adj_row.kind = 'deduction' then 'deduction' else 'addition' end,
        'state', case when v_adj_row.effective_date < v_start then 'deferred' else 'due' end,
        'label', left(v_adj_row.reason, 120),
        'amount', v_adj_row.amount);
    end loop;

    v_remaining := round(v_gross - v_attendance - v_other_ded, 2);
    v_advance_total := 0;
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
        v_adv.amount - v_adv.settled_amount);
      v_advance_amt := round(least(v_planned, v_remaining), 2);
      if v_advance_amt <= 0 then
        continue;
      end if;
      v_lines := v_lines || jsonb_build_object(
        'kind', 'deduction', 'state', 'advance',
        'label', '@advance', 'amount', v_advance_amt);
      v_advance_total := v_advance_total + v_advance_amt;
      v_remaining := round(v_remaining - v_advance_amt, 2);
    end loop;

    v_prev_net := null;
    if v_prev_run.id is not null and v_prev_run.status in ('approved', 'paid') then
      select st.net into v_prev_net
        from hr.payroll_statements st
       where st.run_id = v_prev_run.id
         and st.staff_id = v_staff.staff_id;
    end if;

    v_employees := v_employees || jsonb_build_object(
      'staff_id', v_staff.staff_id,
      'staff_name', v_staff.full_name,
      'compensation_id', v_comp.id,
      'compensation_from', v_comp.effective_from,
      'basic_salary', round(v_comp.basic_salary, 2),
      'allowances_total', v_allowances,
      'gross', v_gross,
      'absence_days', v_metrics.absence_days,
      'late_minutes', v_metrics.late_minutes,
      'early_minutes', v_metrics.early_minutes,
      'paid_leave_days', v_metrics.paid_leave_days,
      'unpaid_leave_days', v_metrics.unpaid_leave_days,
      'attendance_deduction', v_attendance,
      'attendance_deduction_base', v_att_base,
      'unpaid_leave_deduction', v_unpaid,
      'additions_total', round(v_additions, 2),
      'other_deductions', round(v_other_ded, 2),
      'advance_planned', v_advance_total,
      'net_preview', v_remaining,
      'previous_net', v_prev_net,
      'lines', v_lines);
  end loop;

  return jsonb_build_object(
    'period_year', p_period_year,
    'period_month', p_period_month,
    'run', case
      when v_run.id is null then null
      else jsonb_build_object(
        'run_id', v_run.id,
        'status', v_run.status,
        'calc_seq', v_run.calc_seq,
        'statement_count', v_run.statement_count,
        'total_gross', v_run.total_gross,
        'total_deductions', v_run.total_deductions,
        'total_net', v_run.total_net,
        'closed_at', v_run.closed_at)
    end,
    'policy', jsonb_build_object(
      'absence_day_rate', v_settings.absence_day_rate,
      'late_minute_rate', v_settings.late_minute_rate,
      'early_minute_rate', v_settings.early_minute_rate,
      'unpaid_leave_day_rate', v_settings.unpaid_leave_day_rate,
      'max_salary_deduction_percent', v_settings.max_salary_deduction_percent,
      'cashier_deduction_allowed', v_settings.cashier_deduction_allowed),
    'previous_month', case
      when v_prev_run.id is null
        or v_prev_run.status not in ('approved', 'paid') then null
      else jsonb_build_object(
        'period_year', v_prev_run.period_year,
        'period_month', v_prev_run.period_month,
        'status', v_prev_run.status,
        'statement_count', v_prev_run.statement_count,
        'total_gross', v_prev_run.total_gross,
        'total_deductions', v_prev_run.total_deductions,
        'total_net', v_prev_run.total_net)
    end,
    'employees', v_employees,
    'adjustments_due', v_adj_due,
    'missing_data', v_missing
  );
end;
$fn$;

comment on function public.admin_hr_preview_payroll(integer, integer) is
  'Workflow steps 2-5, read-only: validates the period inputs, lists missing '
  'data, mirrors the calculation for every employee (attendance metrics v2, '
  'the D2 deferral window, the D3 suspension and D4 cap rules, advance '
  'recovery) and compares against the previous paid month. Writes nothing.';

revoke all on function public.admin_hr_preview_payroll(integer, integer)
  from public, anon;
grant execute on function public.admin_hr_preview_payroll(integer, integer)
  to authenticated;

revoke all on function public.admin_hr_generate_payroll(integer, integer, text)
  from public, anon;
grant execute on function public.admin_hr_generate_payroll(integer, integer, text)
  to authenticated;

revoke all on function public.admin_hr_approve_payroll(uuid, text)
  from public, anon;
grant execute on function public.admin_hr_approve_payroll(uuid, text)
  to authenticated;

revoke all on function public.admin_hr_payroll_correction(uuid, text, numeric, text, date)
  from public, anon;
grant execute on function public.admin_hr_payroll_correction(uuid, text, numeric, text, date)
  to authenticated;

revoke all on function public.admin_hr_payroll_runs(integer)
  from public, anon;
grant execute on function public.admin_hr_payroll_runs(integer)
  to authenticated;

revoke all on function public.admin_hr_payroll_run(uuid)
  from public, anon;
grant execute on function public.admin_hr_payroll_run(uuid)
  to authenticated;

notify pgrst, 'reload schema';
