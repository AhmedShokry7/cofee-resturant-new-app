-- 240_hr_leave_attendance.sql
--
-- HR Phase 2 / decision D1: approved leave meets attendance and payroll.
--
-- 1  hr.settings gains unpaid_leave_day_rate (default 0 = no money moves
--    until the owner configures it, same philosophy as every other rate).
-- 2  hr.attendance_metrics_v2 keeps the seven published metrics and adds
--    paid_leave_days / unpaid_leave_days. A published shift whose start date
--    sits inside an APPROVED leave is no longer absence, lateness or early
--    exit - paid or unpaid. The schedule row itself is untouched.
-- 3  hr_my_attendance and admin_hr_generate_payroll read the v2 metrics.
--    Payroll splits the policy deduction into @unpaid_leave (own rate) and
--    @attendance (absence/late/early) lines; the combined value still lives
--    in payroll_statements.attendance_deduction, so the math constraint,
--    the snapshot and the Dart contract are unchanged.
-- 4  admin_hr_reference exposes the new rate to policy readers;
--    admin_hr_update_settings accepts it (new 8-arg signature; the old
--    7-arg binding is dropped to keep the PostgREST call unambiguous).
-- 5  admin_hr_attendance shows covered_by_leave and zeroes late minutes on
--    leave-covered days, so screens and payroll agree on one truth.
--
-- DOUBLE-COUNT GUARD: the leave day leaves absence_days entirely; the unpaid
-- money comes from unpaid_leave_days x its own rate, never from absence.
-- CROSS-YEAR LEAVE: coverage is by date overlap, not by the balance year.
-- HOLIDAYS / HALF-DAYS: no holiday calendar exists; until the owner supplies
-- one (policy decision), days outside approved leave follow the schedule.
--
-- ROLLBACK: re-running the 212 bodies of the touched functions, dropping
-- hr.attendance_metrics_v2 and hr.settings.unpaid_leave_day_rate restores
-- the previous behaviour. 212 is untouched.

alter table hr.settings
  add column if not exists unpaid_leave_day_rate numeric(12,2) not null default 0
    check (unpaid_leave_day_rate >= 0);

drop function if exists public.admin_hr_update_settings(
  text, integer, numeric, numeric, numeric, boolean, numeric);

create or replace function hr.attendance_metrics_v2(
  p_staff_id uuid,
  p_start    date,
  p_end      date
)
returns table (
  scheduled_shifts   integer,
  scheduled_minutes  integer,
  absence_days       integer,
  late_minutes       integer,
  early_minutes      integer,
  worked_minutes     integer,
  present_shifts     integer,
  paid_leave_days    integer,
  unpaid_leave_days  integer
)
language sql
stable
security definer
set search_path = ''
as $fn$
  with cfg as (
    select hr.business_time_zone() as tz,
           coalesce((select late_grace_minutes from hr.settings where id = 1), 0)
             as grace
  ),
  approved_leaves as (
    select lr.starts_on, lr.ends_on, lt.is_paid
      from hr.leave_requests lr
      join hr.leave_types lt on lt.id = lr.leave_type_id
     where lr.staff_id = p_staff_id
       and lr.status = 'approved'
  ),
  schedules as (
    select ws.*,
           (select bool_or(true)
              from approved_leaves al
             where ws.scheduled_start::date >= al.starts_on
               and ws.scheduled_start::date <= al.ends_on
           ) as leave_covered,
           (select bool_or(true)
              from approved_leaves al
             where al.is_paid
               and ws.scheduled_start::date >= al.starts_on
               and ws.scheduled_start::date <= al.ends_on
           ) as paid_covered
      from hr.work_schedules ws, cfg
     where ws.staff_id = p_staff_id
       and ws.status = 'published'
       and (ws.scheduled_start at time zone cfg.tz)::date between p_start and p_end
  ),
  matched as (
    select sch.id,
           sch.scheduled_start,
           sch.scheduled_end,
           sch.break_minutes,
           sch.leave_covered,
           sch.paid_covered,
           a.clock_in,
           a.clock_out
      from schedules sch
      left join lateral (
        select s.clock_in, s.clock_out
          from hr.attendance_sessions s
         where s.staff_id = p_staff_id
           and s.clock_in <= sch.scheduled_end
           and coalesce(s.clock_out, s.clock_in) >= sch.scheduled_start
         order by s.clock_in
         limit 1
      ) a on true
  ),
  worked as (
    select
      coalesce(sum(
        greatest(
          0,
          floor(extract(epoch from (coalesce(s.clock_out, now()) - s.clock_in)) / 60)::int
          - coalesce(
              floor(extract(epoch from (s.break_ended_at - s.break_started_at)) / 60)::int,
              0
            )
        )
      ), 0)::integer as minutes
      from hr.attendance_sessions s, cfg
     where s.staff_id = p_staff_id
       and (s.clock_in at time zone cfg.tz)::date between p_start and p_end
  )
  select
    coalesce(count(m.id), 0)::integer,
    coalesce(sum(
      floor(extract(epoch from (m.scheduled_end - m.scheduled_start)) / 60)::int
      - m.break_minutes
    ), 0)::integer,
    coalesce(count(*) filter (
      where m.clock_in is null and m.scheduled_end < now()
        and not coalesce(m.leave_covered, false)
    ), 0)::integer,
    coalesce(sum(greatest(
      0,
      floor(extract(epoch from (m.clock_in - m.scheduled_start)) / 60)::int
      - (select grace from cfg)
    )) filter (where m.clock_in is not null
               and not coalesce(m.leave_covered, false)), 0)::integer,
    coalesce(sum(greatest(
      0,
      floor(extract(epoch from (m.scheduled_end - m.clock_out)) / 60)::int
    )) filter (where m.clock_out is not null and m.scheduled_end < now()
               and not coalesce(m.leave_covered, false)), 0)::integer,
    (select minutes from worked),
    coalesce(count(*) filter (where m.clock_in is not null), 0)::integer,
    coalesce(count(*) filter (
      where coalesce(m.leave_covered, false)
        and coalesce(m.paid_covered, false)
    ), 0)::integer,
    coalesce(count(*) filter (
      where coalesce(m.leave_covered, false)
        and not coalesce(m.paid_covered, false)
    ), 0)::integer
  from matched m;
$fn$;

revoke all on function hr.attendance_metrics_v2(uuid, date, date)
  from public, anon, authenticated;

CREATE OR REPLACE FUNCTION public.admin_hr_generate_payroll(p_period_year integer, p_period_month integer, p_note text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
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
  v_unpaid           numeric(12,2);
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

CREATE OR REPLACE FUNCTION public.admin_hr_update_settings(p_business_time_zone text DEFAULT NULL::text, p_late_grace_minutes integer DEFAULT NULL::integer, p_late_minute_rate numeric DEFAULT NULL::numeric, p_early_minute_rate numeric DEFAULT NULL::numeric, p_absence_day_rate numeric DEFAULT NULL::numeric, p_cashier_deduction_allowed boolean DEFAULT NULL::boolean, p_max_salary_deduction_percent numeric DEFAULT NULL::numeric,
 p_unpaid_leave_day_rate numeric DEFAULT NULL::numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
as $fn$
declare
  v_me uuid;
  v_old hr.settings%rowtype;
  v_tz text;
  v_grace integer;
  v_late numeric(12,4);
  v_early numeric(12,4);
  v_absence numeric(12,2);
  v_allowed boolean;
  v_percent numeric(5,2);
  v_unpaid_rate numeric(12,2);
begin
  v_me := hr.require_permission('hr.settings.manage');

  select * into v_old from hr.settings where id = 1 for update;
  v_tz := coalesce(nullif(btrim(coalesce(p_business_time_zone, '')), ''), v_old.business_time_zone);
  v_grace := coalesce(p_late_grace_minutes, v_old.late_grace_minutes);
  v_late := round(coalesce(p_late_minute_rate, v_old.late_minute_rate), 4);
  v_early := round(coalesce(p_early_minute_rate, v_old.early_minute_rate), 4);
  v_absence := round(coalesce(p_absence_day_rate, v_old.absence_day_rate), 2);
  v_allowed := coalesce(p_cashier_deduction_allowed, v_old.cashier_deduction_allowed);
  v_percent := round(coalesce(p_max_salary_deduction_percent, v_old.max_salary_deduction_percent), 2);
  v_unpaid_rate := round(coalesce(p_unpaid_leave_day_rate, v_old.unpaid_leave_day_rate), 2);

  if not exists (select 1 from pg_catalog.pg_timezone_names tz where tz.name = v_tz) then
    raise exception 'unknown time zone: %', v_tz using errcode = '22023';
  end if;
  if v_grace < 0 or v_grace > 240 then
    raise exception 'late grace must be between 0 and 240 minutes' using errcode = '22023';
  end if;
  if v_late < 0 or v_late > 10000 or v_early < 0 or v_early > 10000 then
    raise exception 'minute rates must be between 0 and 10000' using errcode = '22023';
  end if;
  if v_absence < 0 or v_absence > 100000 then
    raise exception 'absence day rate is out of range' using errcode = '22023';
  end if;
  if v_percent < 0 or v_percent > 100 then
    raise exception 'the deduction cap must be between 0 and 100 percent'
      using errcode = '22023';
  end if;
  if v_allowed and v_percent = 0 then
    raise exception 'cashier deductions need a positive cap'
      using errcode = '22023';
  end if;
  if v_unpaid_rate < 0 or v_unpaid_rate > 100000 then
    raise exception 'unpaid leave day rate is out of range' using errcode = '22023';
  end if;

  update hr.settings
     set business_time_zone = v_tz,
         unpaid_leave_day_rate = v_unpaid_rate,
         late_grace_minutes = v_grace,
         late_minute_rate = v_late,
         early_minute_rate = v_early,
         absence_day_rate = v_absence,
         cashier_deduction_allowed = v_allowed,
         max_salary_deduction_percent = v_percent,
         updated_by = v_me
   where id = 1;

  perform identity.audit(
    'hr.settings.update',
    'hr_settings', null,
    jsonb_build_object(
      'business_time_zone', v_old.business_time_zone,
      'late_grace_minutes', v_old.late_grace_minutes,
      'late_minute_rate', v_old.late_minute_rate,
      'early_minute_rate', v_old.early_minute_rate,
      'absence_day_rate', v_old.absence_day_rate,
      'cashier_deduction_allowed', v_old.cashier_deduction_allowed,
      'max_salary_deduction_percent', v_old.max_salary_deduction_percent,
      'unpaid_leave_day_rate', v_old.unpaid_leave_day_rate
    ),
    jsonb_build_object(
      'business_time_zone', v_tz,
      'late_grace_minutes', v_grace,
      'late_minute_rate', v_late,
      'early_minute_rate', v_early,
      'absence_day_rate', v_absence,
      'cashier_deduction_allowed', v_allowed,
      'max_salary_deduction_percent', v_percent,
      'unpaid_leave_day_rate', v_unpaid_rate
    ),
    null
  );

  return jsonb_build_object(
    'business_time_zone', v_tz,
    'late_grace_minutes', v_grace,
    'late_minute_rate', v_late,
    'early_minute_rate', v_early,
    'absence_day_rate', v_absence,
    'cashier_deduction_allowed', v_allowed,
    'max_salary_deduction_percent', v_percent,
      'unpaid_leave_day_rate', v_unpaid_rate
  );
end;
$fn$;

revoke all on function public.admin_hr_update_settings(
  text, integer, numeric, numeric, numeric, boolean, numeric, numeric
) from public, anon;
grant execute on function public.admin_hr_update_settings(
  text, integer, numeric, numeric, numeric, boolean, numeric, numeric
) to authenticated;
revoke all on function public.admin_hr_generate_payroll(integer, integer, text)
  from public, anon;
grant execute on function public.admin_hr_generate_payroll(integer, integer, text)
  to authenticated;

CREATE OR REPLACE FUNCTION public.admin_hr_reference()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
as $fn$
declare
  v_staff uuid;
  v_show_policy boolean;
begin
  v_staff := hr.require_staff();
  v_show_policy := identity.has_permission('hr.payroll.read')
    or identity.has_permission('hr.compensation.manage')
    or identity.has_permission('hr.finance.adjust');

  return jsonb_build_object(
    'branches', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', b.id,
        'name_ar', b.name_ar,
        'name_en', b.name_en
      ) order by b.name_ar)
      from core.branches b
      where b.is_active
        and identity.can_manage_branch(b.id)
    ), '[]'::jsonb),
    'leave_types', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', t.id,
        'code', t.code,
        'name_ar', t.name_ar,
        'name_en', t.name_en,
        'requires_document', t.requires_document,
        'is_paid', t.is_paid,
        'tracks_balance', t.tracks_balance
      ) order by t.name_ar)
      from hr.leave_types t
      where t.is_active
    ), '[]'::jsonb),
    'departments', coalesce((
      select jsonb_agg(department order by department)
      from (
        select distinct btrim(e.department) as department
          from hr.employment_records e
         where btrim(e.department) <> ''
      ) d
    ), '[]'::jsonb),
    'settings', jsonb_build_object(
      'business_time_zone', hr.business_time_zone(),
      'late_grace_minutes', coalesce(s.late_grace_minutes, 0),
      'cashier_deduction_allowed', coalesce(s.cashier_deduction_allowed, false),
      'max_salary_deduction_percent', coalesce(s.max_salary_deduction_percent, 0),
      'late_minute_rate', case when v_show_policy then s.late_minute_rate else null end,
      'early_minute_rate', case when v_show_policy then s.early_minute_rate else null end,
      'absence_day_rate', case when v_show_policy then s.absence_day_rate else null end,
      'unpaid_leave_day_rate', case when v_show_policy then s.unpaid_leave_day_rate else null end
    ),
    'my_staff_id', v_staff
  )
  from (select * from hr.settings where id = 1) s;
end;
$fn$;

CREATE OR REPLACE FUNCTION public.hr_my_attendance(p_from date DEFAULT NULL::date, p_to date DEFAULT NULL::date)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
as $fn$
declare
  v_me uuid;
  v_from date;
  v_to date;
begin
  v_me := hr.require_staff();
  v_to := coalesce(p_to, (now() at time zone hr.business_time_zone())::date);
  v_from := coalesce(p_from, v_to - 30);
  if v_to < v_from then
    raise exception 'invalid attendance date range' using errcode = '22023';
  end if;
  if v_to - v_from > 92 then
    raise exception 'attendance range is limited to 92 days' using errcode = '22023';
  end if;

  return jsonb_build_object(
    'staff_id', v_me,
    'open_session', (
      select hr.attendance_json(s.id)
        from hr.attendance_sessions s
       where s.staff_id = v_me and s.clock_out is null
       limit 1
    ),
    'sessions', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', a.id,
        'branch_id', a.branch_id,
        'branch_name_ar', b.name_ar,
        'branch_name_en', b.name_en,
        'clock_in', a.clock_in,
        'clock_out', a.clock_out,
        'clock_in_local', hr.fmt_ts(a.clock_in),
        'clock_out_local', hr.fmt_ts(a.clock_out),
        'is_open', a.clock_out is null,
        'worked_minutes', greatest(
          0,
          floor(extract(epoch from (coalesce(a.clock_out, now()) - a.clock_in)) / 60)::int
          - coalesce(
              floor(extract(epoch from (a.break_ended_at - a.break_started_at)) / 60)::int,
              0
            )
        )
      ) order by a.clock_in desc)
      from hr.attendance_sessions a
      left join core.branches b on b.id = a.branch_id
      where a.staff_id = v_me
        and (a.clock_in at time zone hr.business_time_zone())::date
            between v_from and v_to
    ), '[]'::jsonb),
    'metrics', (
      select to_jsonb(m)
      from hr.attendance_metrics_v2(v_me, v_from, v_to) m
    )
  );
end;
$fn$;

CREATE OR REPLACE FUNCTION public.admin_hr_attendance(p_from date DEFAULT NULL::date, p_to date DEFAULT NULL::date, p_branch_id uuid DEFAULT NULL::uuid, p_staff_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
as $fn$
declare
  v_me uuid;
  v_from date;
  v_to date;
  v_self boolean;
begin
  v_me := hr.require_staff();
  v_self := p_staff_id = v_me;
  if not v_self and not (
    identity.has_permission('hr.attendance.read')
    or identity.has_permission('hr.attendance.manage')
  ) then
    raise exception 'missing permission: hr.attendance.read' using errcode = '42501';
  end if;
  if p_staff_id is not null then
    perform hr.assert_staff_access(p_staff_id);
  end if;
  if p_branch_id is not null and not identity.can_manage_branch(p_branch_id) then
    raise exception 'branch out of scope' using errcode = '42501';
  end if;

  v_to := coalesce(p_to, (now() at time zone hr.business_time_zone())::date);
  v_from := coalesce(p_from, v_to);
  if v_to < v_from then
    raise exception 'invalid attendance date range' using errcode = '22023';
  end if;
  if v_to - v_from > 92 then
    raise exception 'attendance range is limited to 92 days' using errcode = '22023';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', a.id,
      'staff_id', a.staff_id,
      'staff_name', sm.full_name,
      'branch_id', a.branch_id,
      'branch_name_ar', b.name_ar,
      'branch_name_en', b.name_en,
      'date_local', to_char(
        a.clock_in at time zone hr.business_time_zone(), 'YYYY-MM-DD'
      ),
      'clock_in', a.clock_in,
      'clock_out', a.clock_out,
      'clock_in_local', hr.fmt_ts(a.clock_in),
      'clock_out_local', hr.fmt_ts(a.clock_out),
      'is_open', a.clock_out is null,
      'is_missing_clock_out', a.clock_out is null
        and a.clock_in < now() - interval '16 hours',
      'worked_minutes', greatest(
        0,
        floor(extract(epoch from (coalesce(a.clock_out, now()) - a.clock_in)) / 60)::int
        - coalesce(
            floor(extract(epoch from (a.break_ended_at - a.break_started_at)) / 60)::int,
            0
          )
      ),
      'scheduled_start', sch.scheduled_start,
      'scheduled_end', sch.scheduled_end,
      'covered_by_leave', exists (
        select 1 from hr.leave_requests lr
         where lr.staff_id = a.staff_id
           and lr.status = 'approved'
           and lr.starts_on <= (a.clock_in at time zone hr.business_time_zone())::date
           and lr.ends_on >= (a.clock_in at time zone hr.business_time_zone())::date
      ),
      'late_minutes', case
        when sch.id is null or a.clock_in is null then 0
        when exists (
          select 1 from hr.leave_requests lr
           where lr.staff_id = a.staff_id
             and lr.status = 'approved'
             and lr.starts_on <= (a.clock_in at time zone hr.business_time_zone())::date
             and lr.ends_on >= (a.clock_in at time zone hr.business_time_zone())::date
        ) then 0
        else greatest(
          0,
          floor(extract(epoch from (a.clock_in - sch.scheduled_start)) / 60)::int
          - coalesce((select late_grace_minutes from hr.settings where id = 1), 0)
        )
      end,
      'early_minutes', case
        when sch.id is null or a.clock_out is null or sch.scheduled_end >= now() then 0
        else greatest(
          0,
          floor(extract(epoch from (sch.scheduled_end - a.clock_out)) / 60)::int
        )
      end
    ) order by a.clock_in desc)
    from hr.attendance_sessions a
    join identity.staff_members sm on sm.id = a.staff_id
    left join core.branches b on b.id = a.branch_id
    left join lateral (
      select ws.id, ws.scheduled_start, ws.scheduled_end
        from hr.work_schedules ws
       where ws.staff_id = a.staff_id
         and ws.status = 'published'
         and ws.scheduled_start <= coalesce(a.clock_out, a.clock_in)
         and ws.scheduled_end >= a.clock_in
       order by ws.scheduled_start
       limit 1
    ) sch on true
    where (a.clock_in at time zone hr.business_time_zone())::date
            between v_from and v_to
      and (p_branch_id is null or a.branch_id = p_branch_id)
      and (p_staff_id is null or a.staff_id = p_staff_id)
      and (p_staff_id is not null or hr.can_access_staff(a.staff_id))
  ), '[]'::jsonb);
end;
$fn$;

comment on function hr.attendance_metrics_v2(uuid, date, date) is
  'Published-schedule attendance metrics of one staff member in a range, with
  approved leave excluded: paid_leave_days and unpaid_leave_days name the
  covered shifts. Server-side truth for payroll.';

notify pgrst, 'reload schema';
