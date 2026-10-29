-- 212_hr_workforce.sql
--
-- HR and workforce management on top of the existing identity, branches, RBAC
-- and POS drawer.
--
-- WHAT THIS FILE OWNS
--   * hr.employment_records — the employment file of an identity.staff_members
--     row. It never grants access: identity.staff_members stays the only login
--     identity, and no column here is read by identity.has_permission.
--   * hr.work_schedules — when an employee is expected to work. Distinct from
--     payments.pos_shifts, which is the cash drawer's lifecycle.
--   * hr.attendance_sessions / hr.attendance_corrections — server-stamped
--     clock-in/out with an approval trail for manual fixes.
--   * hr.leave_types / hr.leave_balances / hr.leave_requests — a real approval
--     workflow with deterministic, single-count balance deductions.
--   * hr.compensations — effective-dated salary history, never overwritten.
--   * hr.payroll_runs / hr.payroll_statements / hr.payroll_line_items —
--     server-calculated payroll snapshots. Approved runs are immutable.
--   * hr.salary_advances — request, approval, disbursement, settlement.
--   * hr.adjustments — approved additions/deductions with a source reference.
--   * hr.cashier_discrepancies — a review record created from a closed POS
--     shift with a non-zero variance. A shortage never becomes a deduction by
--     itself.
--
-- MONEY
--   numeric(12,2) everywhere, rounded on the server. The client never sends a
--   net salary: admin_hr_generate_payroll derives it from the records below.
--
-- SECURITY
--   The hr schema is not exposed through PostgREST. Every table is revoked from
--   anon/authenticated and every read/write goes through a SECURITY DEFINER
--   function in public with search_path = ''. Branch scope reuses
--   identity.can_manage_branch / identity.has_permission; no parallel RBAC.
--
-- NOT APPLIED BY THIS SESSION. The owner applies it after reviewing the report.
--
-- HOW TO VERIFY
--   supabase/tests/hr_workforce_test.sql runs the matrix as real roles inside
--   one rolled-back transaction.

create schema if not exists hr;

comment on schema hr is
  'Human resources and workforce records. Reachable only through public RPCs.';

revoke all on schema hr from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 0. Branch-level HR settings (rates default to zero = no automatic deduction)
-- ---------------------------------------------------------------------------
create table if not exists hr.settings (
  id                          integer primary key default 1 check (id = 1),
  business_time_zone          text not null default 'Asia/Riyadh',
  late_grace_minutes          integer not null default 0
                                check (late_grace_minutes between 0 and 240),
  late_minute_rate            numeric(12,4) not null default 0
                                check (late_minute_rate >= 0),
  early_minute_rate           numeric(12,4) not null default 0
                                check (early_minute_rate >= 0),
  absence_day_rate            numeric(12,2) not null default 0
                                check (absence_day_rate >= 0),
  cashier_deduction_allowed   boolean not null default false,
  max_salary_deduction_percent numeric(5,2) not null default 0
                                check (max_salary_deduction_percent between 0 and 100),
  updated_at                  timestamptz not null default now(),
  updated_by                  uuid references identity.staff_members(id)
                                on delete set null
);

comment on table hr.settings is
  'Single HR policy row. Zero rates and a false cashier_deduction_allowed mean '
  'no automatic money movement until an owner configures the policy.';

insert into hr.settings (id) values (1) on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- 1. Employment file
-- ---------------------------------------------------------------------------
create table if not exists hr.employment_records (
  staff_id                uuid primary key
                            references identity.staff_members(id) on delete restrict,
  employee_number         text unique,
  department              text not null default '',
  job_title               text not null default '',
  employment_type         text not null default 'full_time'
                            check (employment_type in ('full_time','part_time','contract')),
  employment_status       text not null default 'active'
                            check (employment_status in
                              ('active','probation','on_leave','terminated')),
  hired_on                date,
  terminated_on           date,
  phone                   text not null default '',
  emergency_contact_name  text not null default '',
  emergency_contact_phone text not null default '',
  notes                   text not null default '',
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now(),
  constraint ck_employment_dates check (
    terminated_on is null or hired_on is null or terminated_on >= hired_on
  ),
  constraint ck_employment_terminated_date check (
    employment_status <> 'terminated' or terminated_on is not null
  )
);

comment on table hr.employment_records is
  'Employment file for a staff identity. Branch assignments stay in '
  'identity.staff_roles; this table never carries permissions.';

create index if not exists ix_employment_department
  on hr.employment_records (department);
create index if not exists ix_employment_status
  on hr.employment_records (employment_status);

-- ---------------------------------------------------------------------------
-- 2. Work schedules (expected work, not the POS cash drawer)
-- ---------------------------------------------------------------------------
create table if not exists hr.work_schedules (
  id              uuid primary key default extensions.gen_random_uuid(),
  staff_id        uuid not null references identity.staff_members(id) on delete restrict,
  branch_id       uuid not null references core.branches(id) on delete restrict,
  scheduled_start timestamptz not null,
  scheduled_end   timestamptz not null,
  break_minutes   integer not null default 0 check (break_minutes between 0 and 240),
  status          text not null default 'draft'
                    check (status in ('draft','published','cancelled')),
  note            text not null default '',
  created_by      uuid references identity.staff_members(id) on delete set null,
  updated_by      uuid references identity.staff_members(id) on delete set null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  constraint ck_schedule_window check (
    scheduled_end > scheduled_start
    and scheduled_end - scheduled_start <= interval '24 hours'
  ),
  constraint ck_schedule_break check (
    break_minutes * interval '1 minute' < scheduled_end - scheduled_start
  )
);

comment on table hr.work_schedules is
  'Published or draft expected working window. The POS drawer remains '
  'payments.pos_shifts and is never created or closed by this table.';

create index if not exists ix_work_schedules_staff_time
  on hr.work_schedules (staff_id, scheduled_start)
  where status <> 'cancelled';
create index if not exists ix_work_schedules_branch_time
  on hr.work_schedules (branch_id, scheduled_start)
  where status <> 'cancelled';

-- ---------------------------------------------------------------------------
-- 3. Attendance (server timestamps only)
-- ---------------------------------------------------------------------------
create table if not exists hr.attendance_sessions (
  id               uuid primary key default extensions.gen_random_uuid(),
  staff_id         uuid not null references identity.staff_members(id) on delete restrict,
  branch_id        uuid not null references core.branches(id) on delete restrict,
  clock_in         timestamptz not null default now(),
  clock_out        timestamptz,
  clock_out_note   text not null default '',
  break_started_at timestamptz,
  break_ended_at   timestamptz,
  note             text not null default '',
  created_by       uuid not null references identity.staff_members(id) on delete restrict,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  constraint ck_attendance_window check (clock_out is null or clock_out > clock_in),
  constraint ck_attendance_break_pair check (
    (break_started_at is null and break_ended_at is null)
    or (break_started_at is not null
        and (break_ended_at is null or break_ended_at > break_started_at))
  ),
  constraint ck_attendance_break_inside check (
    break_started_at is null
    or (break_started_at >= clock_in
        and (clock_out is null or break_started_at < clock_out))
  ),
  constraint ck_attendance_break_end_inside check (
    break_ended_at is null or clock_out is null or break_ended_at <= clock_out
  )
);

comment on table hr.attendance_sessions is
  'One clock-in … clock-out window stamped by now() on the server. A partial '
  'unique index allows at most one open session per staff.';

create unique index if not exists uq_attendance_open_staff
  on hr.attendance_sessions (staff_id)
  where clock_out is null;
create index if not exists ix_attendance_staff_time
  on hr.attendance_sessions (staff_id, clock_in desc);
create index if not exists ix_attendance_branch_time
  on hr.attendance_sessions (branch_id, clock_in desc);

create table if not exists hr.attendance_corrections (
  id              uuid primary key default extensions.gen_random_uuid(),
  staff_id        uuid not null references identity.staff_members(id) on delete restrict,
  branch_id       uuid not null references core.branches(id) on delete restrict,
  session_id      uuid references hr.attendance_sessions(id) on delete restrict,
  proposed_clock_in  timestamptz,
  proposed_clock_out timestamptz,
  reason          text not null check (btrim(reason) <> ''),
  status          text not null default 'pending'
                    check (status in ('pending','approved','rejected','cancelled')),
  requested_by    uuid not null references identity.staff_members(id) on delete restrict,
  reviewed_by     uuid references identity.staff_members(id) on delete set null,
  reviewed_at     timestamptz,
  review_note     text not null default '',
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  constraint ck_correction_has_change check (
    session_id is not null
    or proposed_clock_in is not null
    or proposed_clock_out is not null
  ),
  constraint ck_correction_window check (
    proposed_clock_out is null
    or proposed_clock_in is null
    or proposed_clock_out > proposed_clock_in
  ),
  constraint ck_correction_reviewed check (
    status <> 'approved' or (reviewed_by is not null and reviewed_at is not null)
  )
);

create index if not exists ix_attendance_corrections_status
  on hr.attendance_corrections (status, created_at desc);
create unique index if not exists uq_attendance_correction_pending
  on hr.attendance_corrections (session_id)
  where session_id is not null and status = 'pending';

-- ---------------------------------------------------------------------------
-- 4. Leave
-- ---------------------------------------------------------------------------
create table if not exists hr.leave_types (
  id                  uuid primary key default extensions.gen_random_uuid(),
  code                text not null unique check (code ~ '^[a-z_]+$'),
  name_ar             text not null,
  name_en             text not null,
  requires_document   boolean not null default false,
  is_paid             boolean not null default true,
  tracks_balance      boolean not null default false,
  default_annual_days numeric(6,2) check (default_annual_days is null or default_annual_days >= 0),
  is_active           boolean not null default true,
  created_at          timestamptz not null default now()
);

comment on table hr.leave_types is
  'Configurable leave types. No statutory entitlement is hard-coded: a type '
  'that tracks a balance starts at whatever the owner enters in hr.leave_balances.';

create table if not exists hr.leave_balances (
  staff_id      uuid not null references identity.staff_members(id) on delete restrict,
  leave_type_id uuid not null references hr.leave_types(id) on delete restrict,
  year          integer not null check (year between 2000 and 2100),
  entitled_days numeric(6,2) not null default 0 check (entitled_days >= 0),
  used_days     numeric(6,2) not null default 0 check (used_days >= 0),
  updated_at    timestamptz not null default now(),
  primary key (staff_id, leave_type_id, year),
  constraint ck_leave_balance_cap check (used_days <= entitled_days)
);

create table if not exists hr.leave_requests (
  id                  uuid primary key default extensions.gen_random_uuid(),
  staff_id            uuid not null references identity.staff_members(id) on delete restrict,
  leave_type_id       uuid not null references hr.leave_types(id) on delete restrict,
  starts_on           date not null,
  ends_on             date not null,
  reason              text not null default '',
  supporting_document text not null default '',
  status              text not null default 'pending'
                        check (status in ('pending','approved','rejected','cancelled')),
  requested_by        uuid not null references identity.staff_members(id) on delete restrict,
  reviewed_by         uuid references identity.staff_members(id) on delete set null,
  reviewed_at         timestamptz,
  review_note         text not null default '',
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  constraint ck_leave_dates check (ends_on >= starts_on),
  constraint ck_leave_span check (ends_on - starts_on <= 366),
  constraint ck_leave_reviewed check (
    status not in ('approved','rejected')
    or (reviewed_by is not null and reviewed_at is not null)
  )
);

create index if not exists ix_leave_requests_staff
  on hr.leave_requests (staff_id, starts_on desc);
create index if not exists ix_leave_requests_status
  on hr.leave_requests (status, created_at desc);

-- ---------------------------------------------------------------------------
-- 5. Compensation history
-- ---------------------------------------------------------------------------
create table if not exists hr.compensations (
  id                  uuid primary key default extensions.gen_random_uuid(),
  staff_id            uuid not null references identity.staff_members(id) on delete restrict,
  basic_salary        numeric(12,2) not null check (basic_salary >= 0),
  housing_allowance   numeric(12,2) not null default 0 check (housing_allowance >= 0),
  transport_allowance numeric(12,2) not null default 0 check (transport_allowance >= 0),
  other_allowance     numeric(12,2) not null default 0 check (other_allowance >= 0),
  currency_code       text not null default 'SAR' check (currency_code ~ '^[A-Z]{3}$'),
  effective_from      date not null,
  effective_to        date,
  note                text not null default '',
  created_by          uuid references identity.staff_members(id) on delete set null,
  created_at          timestamptz not null default now(),
  constraint ck_compensation_window check (
    effective_to is null or effective_to >= effective_from
  )
);

create index if not exists ix_compensations_staff_date
  on hr.compensations (staff_id, effective_from desc);

-- ---------------------------------------------------------------------------
-- 6. Payroll
-- ---------------------------------------------------------------------------
create table if not exists hr.payroll_runs (
  id                  uuid primary key default extensions.gen_random_uuid(),
  period_year         integer not null check (period_year between 2000 and 2100),
  period_month        integer not null check (period_month between 1 and 12),
  status              text not null default 'draft'
                        check (status in
                          ('draft','calculated','approved','paid','cancelled')),
  calculated_by       uuid references identity.staff_members(id) on delete set null,
  calculated_at       timestamptz,
  approved_by         uuid references identity.staff_members(id) on delete set null,
  approved_at         timestamptz,
  paid_by             uuid references identity.staff_members(id) on delete set null,
  paid_at             timestamptz,
  total_gross         numeric(14,2) not null default 0 check (total_gross >= 0),
  total_deductions    numeric(14,2) not null default 0 check (total_deductions >= 0),
  total_net           numeric(14,2) not null default 0 check (total_net >= 0),
  statement_count     integer not null default 0 check (statement_count >= 0),
  note                text not null default '',
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  unique (period_year, period_month),
  constraint ck_payroll_run_approved check (
    status <> 'approved' or (approved_by is not null and approved_at is not null)
  ),
  constraint ck_payroll_run_paid check (
    status <> 'paid'
    or (approved_by is not null and approved_at is not null
        and paid_by is not null and paid_at is not null)
  )
);

comment on table hr.payroll_runs is
  'One payroll period. Calculated, approved and paid are separate states and '
  'separate permissions. Paid is never inferred from a calculation.';

create table if not exists hr.payroll_statements (
  id                       uuid primary key default extensions.gen_random_uuid(),
  run_id                   uuid not null references hr.payroll_runs(id) on delete cascade,
  staff_id                 uuid not null references identity.staff_members(id) on delete restrict,
  basic_salary             numeric(12,2) not null check (basic_salary >= 0),
  allowances_total         numeric(12,2) not null default 0 check (allowances_total >= 0),
  additions_total          numeric(12,2) not null default 0 check (additions_total >= 0),
  attendance_deduction     numeric(12,2) not null default 0 check (attendance_deduction >= 0),
  advance_deduction        numeric(12,2) not null default 0 check (advance_deduction >= 0),
  other_deductions         numeric(12,2) not null default 0 check (other_deductions >= 0),
  deductions_total         numeric(12,2) not null default 0 check (deductions_total >= 0),
  absence_days             integer not null default 0 check (absence_days >= 0),
  late_minutes             integer not null default 0 check (late_minutes >= 0),
  early_minutes            integer not null default 0 check (early_minutes >= 0),
  gross                    numeric(12,2) not null check (gross >= 0),
  net                      numeric(12,2) not null check (net >= 0),
  currency_code            text not null default 'SAR' check (currency_code ~ '^[A-Z]{3}$'),
  calculation_version      text not null default 'hr-1',
  created_at               timestamptz not null default now(),
  unique (run_id, staff_id),
  constraint ck_statement_math check (
    gross = round(basic_salary + allowances_total + additions_total, 2)
    and deductions_total = round(
      attendance_deduction + advance_deduction + other_deductions, 2
    )
    and net = round(gross - deductions_total, 2)
  )
);

create table if not exists hr.payroll_line_items (
  id              uuid primary key default extensions.gen_random_uuid(),
  statement_id    uuid not null
                    references hr.payroll_statements(id) on delete cascade,
  payroll_run_id  uuid not null references hr.payroll_runs(id) on delete cascade,
  kind            text not null check (kind in ('addition','deduction')),
  category        text not null check (category in
                    ('basic','allowance','bonus','commission','overtime','advance',
                     'attendance','cashier_shortage','manual','correction')),
  source_type     text not null default 'manual' check (source_type in
                    ('compensation','adjustment','salary_advance','attendance_policy',
                     'manual','payroll_correction')),
  source_id       uuid,
  label           text not null default '',
  amount          numeric(12,2) not null check (amount > 0),
  created_at      timestamptz not null default now()
);

create index if not exists ix_payroll_statements_run
  on hr.payroll_statements (run_id);
create index if not exists ix_payroll_lines_statement
  on hr.payroll_line_items (statement_id);
create unique index if not exists uq_payroll_line_adjustment
  on hr.payroll_line_items (source_id)
  where source_type = 'adjustment' and source_id is not null;
create unique index if not exists uq_payroll_line_advance_run
  on hr.payroll_line_items (source_id, payroll_run_id)
  where source_type = 'salary_advance' and source_id is not null;

-- ---------------------------------------------------------------------------
-- 7. Salary advances
-- ---------------------------------------------------------------------------
create table if not exists hr.salary_advances (
  id                 uuid primary key default extensions.gen_random_uuid(),
  staff_id           uuid not null references identity.staff_members(id) on delete restrict,
  amount             numeric(12,2) not null check (amount > 0),
  installment_amount numeric(12,2) check (installment_amount is null or installment_amount > 0),
  settled_amount     numeric(12,2) not null default 0 check (settled_amount >= 0),
  currency_code      text not null default 'SAR' check (currency_code ~ '^[A-Z]{3}$'),
  reason             text not null check (btrim(reason) <> ''),
  status             text not null default 'pending'
                       check (status in
                         ('pending','approved','rejected','disbursed','settled','cancelled')),
  requested_by       uuid not null references identity.staff_members(id) on delete restrict,
  reviewed_by        uuid references identity.staff_members(id) on delete set null,
  reviewed_at        timestamptz,
  review_note        text not null default '',
  disbursed_by       uuid references identity.staff_members(id) on delete set null,
  disbursed_at       timestamptz,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  constraint ck_advance_settled check (settled_amount <= amount),
  constraint ck_advance_installment check (
    installment_amount is null or installment_amount <= amount
  ),
  constraint ck_advance_approved check (
    status not in ('approved','disbursed','settled')
    or (reviewed_by is not null and reviewed_at is not null)
  ),
  constraint ck_advance_disbursed check (
    status not in ('disbursed','settled') or disbursed_at is not null
  )
);

create index if not exists ix_advances_staff
  on hr.salary_advances (staff_id, created_at desc);
create index if not exists ix_advances_status
  on hr.salary_advances (status, created_at desc);

-- ---------------------------------------------------------------------------
-- 8. Adjustments (approved additions and deductions)
-- ---------------------------------------------------------------------------
create table if not exists hr.adjustments (
  id              uuid primary key default extensions.gen_random_uuid(),
  staff_id        uuid not null references identity.staff_members(id) on delete restrict,
  kind            text not null check (kind in
                    ('allowance','bonus','commission','overtime','deduction')),
  amount          numeric(12,2) not null check (amount > 0),
  quantity        numeric(10,2) check (quantity is null or quantity > 0),
  effective_date  date not null default current_date,
  reason          text not null check (btrim(reason) <> ''),
  status          text not null default 'pending'
                    check (status in
                      ('pending','approved','rejected','reversed','cancelled')),
  source_type     text not null default 'manual' check (source_type in
                    ('manual','cashier_discrepancy','payroll_correction','adjustment_reversal')),
  source_id       uuid,
  payroll_run_id  uuid references hr.payroll_runs(id) on delete set null,
  requested_by    uuid references identity.staff_members(id) on delete set null,
  reviewed_by     uuid references identity.staff_members(id) on delete set null,
  reviewed_at     timestamptz,
  review_note     text not null default '',
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  constraint ck_adjustment_reviewed check (
    status <> 'approved' or (reviewed_by is not null and reviewed_at is not null)
  ),
  constraint ck_adjustment_source check (
    (source_type = 'manual' and source_id is null)
    or (source_type <> 'manual' and source_id is not null)
  )
);

create index if not exists ix_adjustments_staff
  on hr.adjustments (staff_id, effective_date desc);
create index if not exists ix_adjustments_status
  on hr.adjustments (status, effective_date);
create unique index if not exists uq_adjustment_source
  on hr.adjustments (source_type, source_id)
  where source_id is not null and source_type <> 'manual';

-- ---------------------------------------------------------------------------
-- 9. Cashier discrepancies (POS drawer ↔ HR review)
-- ---------------------------------------------------------------------------
create table if not exists hr.cashier_discrepancies (
  id                  uuid primary key default extensions.gen_random_uuid(),
  shift_id            uuid not null unique
                        references payments.pos_shifts(id) on delete restrict,
  branch_id           uuid not null references core.branches(id) on delete restrict,
  drawer_cashier_id   uuid references identity.staff_members(id) on delete set null,
  attributed_staff_id uuid references identity.staff_members(id) on delete set null,
  signed_variance     numeric(12,2) not null,
  amount              numeric(12,2) not null check (amount > 0),
  currency_code       text not null default 'SAR' check (currency_code ~ '^[A-Z]{3}$'),
  status              text not null default 'pending_review'
                        check (status in
                          ('pending_review','explained','reconciliation_required',
                           'confirmed','rejected','deduction_approved','closed')),
  review_note         text not null default '',
  evidence            text not null default '',
  reviewed_by         uuid references identity.staff_members(id) on delete set null,
  reviewed_at         timestamptz,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  constraint ck_discrepancy_amount check (amount = abs(signed_variance))
);

comment on table hr.cashier_discrepancies is
  'A review record, never a deduction. The original POS shift and its numbers '
  'are preserved; the drawer_cashier_id is who held the drawer, and '
  'attributed_staff_id stays null until a reviewer names a person on evidence.';

create index if not exists ix_discrepancies_status
  on hr.cashier_discrepancies (status, created_at desc);
create index if not exists ix_discrepancies_staff
  on hr.cashier_discrepancies (attributed_staff_id)
  where attributed_staff_id is not null;
create unique index if not exists uq_discrepancy_deduction
  on hr.adjustments (source_id)
  where source_type = 'cashier_discrepancy' and source_id is not null;

-- ---------------------------------------------------------------------------
-- 10. RLS and grants: nothing in hr is directly reachable
-- ---------------------------------------------------------------------------
alter table hr.settings enable row level security;
alter table hr.employment_records enable row level security;
alter table hr.work_schedules enable row level security;
alter table hr.attendance_sessions enable row level security;
alter table hr.attendance_corrections enable row level security;
alter table hr.leave_types enable row level security;
alter table hr.leave_balances enable row level security;
alter table hr.leave_requests enable row level security;
alter table hr.compensations enable row level security;
alter table hr.payroll_runs enable row level security;
alter table hr.payroll_statements enable row level security;
alter table hr.payroll_line_items enable row level security;
alter table hr.salary_advances enable row level security;
alter table hr.adjustments enable row level security;
alter table hr.cashier_discrepancies enable row level security;

revoke all on all tables in schema hr from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 11. Triggers
-- ---------------------------------------------------------------------------
drop trigger if exists tr_hr_settings_updated_at on hr.settings;
create trigger tr_hr_settings_updated_at
  before update on hr.settings
  for each row execute function core.set_updated_at();

drop trigger if exists tr_employment_updated_at on hr.employment_records;
create trigger tr_employment_updated_at
  before update on hr.employment_records
  for each row execute function core.set_updated_at();

drop trigger if exists tr_work_schedules_updated_at on hr.work_schedules;
create trigger tr_work_schedules_updated_at
  before update on hr.work_schedules
  for each row execute function core.set_updated_at();

drop trigger if exists tr_attendance_updated_at on hr.attendance_sessions;
create trigger tr_attendance_updated_at
  before update on hr.attendance_sessions
  for each row execute function core.set_updated_at();

drop trigger if exists tr_corrections_updated_at on hr.attendance_corrections;
create trigger tr_corrections_updated_at
  before update on hr.attendance_corrections
  for each row execute function core.set_updated_at();

drop trigger if exists tr_leave_requests_updated_at on hr.leave_requests;
create trigger tr_leave_requests_updated_at
  before update on hr.leave_requests
  for each row execute function core.set_updated_at();

drop trigger if exists tr_payroll_runs_updated_at on hr.payroll_runs;
create trigger tr_payroll_runs_updated_at
  before update on hr.payroll_runs
  for each row execute function core.set_updated_at();

drop trigger if exists tr_advances_updated_at on hr.salary_advances;
create trigger tr_advances_updated_at
  before update on hr.salary_advances
  for each row execute function core.set_updated_at();

drop trigger if exists tr_adjustments_updated_at on hr.adjustments;
create trigger tr_adjustments_updated_at
  before update on hr.adjustments
  for each row execute function core.set_updated_at();

drop trigger if exists tr_discrepancies_updated_at on hr.cashier_discrepancies;
create trigger tr_discrepancies_updated_at
  before update on hr.cashier_discrepancies
  for each row execute function core.set_updated_at();

-- Every staff identity gets an employment file; the branch stays in staff_roles.
create or replace function hr.ensure_employment_record()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  insert into hr.employment_records (staff_id)
  values (new.id)
  on conflict (staff_id) do nothing;
  return new;
end;
$fn$;

revoke all on function hr.ensure_employment_record() from public, anon, authenticated;

drop trigger if exists tr_staff_employment_record on identity.staff_members;
create trigger tr_staff_employment_record
  after insert on identity.staff_members
  for each row execute function hr.ensure_employment_record();

-- Backfill existing staff without fabricating dates or departments.
insert into hr.employment_records (staff_id)
select sm.id from identity.staff_members sm
on conflict (staff_id) do nothing;

-- Overlapping schedules are refused for the same person, whatever writes them.
create or replace function hr.check_schedule_overlap()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if new.status = 'cancelled' then
    return new;
  end if;
  perform pg_advisory_xact_lock(hashtext('hr.schedule:' || new.staff_id::text));
  if exists (
    select 1
      from hr.work_schedules s
     where s.staff_id = new.staff_id
       and s.id <> new.id
       and s.status <> 'cancelled'
       and s.scheduled_start < new.scheduled_end
       and s.scheduled_end > new.scheduled_start
  ) then
    raise exception 'overlapping work schedule' using errcode = '23505';
  end if;
  return new;
end;
$fn$;

revoke all on function hr.check_schedule_overlap() from public, anon, authenticated;

drop trigger if exists tr_schedule_overlap on hr.work_schedules;
create trigger tr_schedule_overlap
  before insert or update of staff_id, scheduled_start, scheduled_end, status
  on hr.work_schedules
  for each row execute function hr.check_schedule_overlap();

-- Compensation ranges may not overlap, so a period has exactly one salary.
create or replace function hr.check_compensation_overlap()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  perform pg_advisory_xact_lock(hashtext('hr.compensation:' || new.staff_id::text));
  if exists (
    select 1
      from hr.compensations c
     where c.staff_id = new.staff_id
       and c.id <> new.id
       and daterange(c.effective_from, coalesce(c.effective_to, 'infinity'::date), '[]')
           && daterange(new.effective_from, coalesce(new.effective_to, 'infinity'::date), '[]')
  ) then
    raise exception 'overlapping compensation period' using errcode = '23505';
  end if;
  return new;
end;
$fn$;

revoke all on function hr.check_compensation_overlap() from public, anon, authenticated;

drop trigger if exists tr_compensation_overlap on hr.compensations;
create trigger tr_compensation_overlap
  before insert or update of staff_id, effective_from, effective_to
  on hr.compensations
  for each row execute function hr.check_compensation_overlap();

-- Two pending/approved leave requests for the same person cannot overlap.
create or replace function hr.check_leave_overlap()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if new.status not in ('pending','approved') then
    return new;
  end if;
  perform pg_advisory_xact_lock(hashtext('hr.leave:' || new.staff_id::text));
  if exists (
    select 1
      from hr.leave_requests r
     where r.staff_id = new.staff_id
       and r.id <> new.id
       and r.status in ('pending','approved')
       and daterange(r.starts_on, r.ends_on, '[]')
           && daterange(new.starts_on, new.ends_on, '[]')
  ) then
    raise exception 'overlapping leave request' using errcode = '23505';
  end if;
  return new;
end;
$fn$;

revoke all on function hr.check_leave_overlap() from public, anon, authenticated;

drop trigger if exists tr_leave_overlap on hr.leave_requests;
create trigger tr_leave_overlap
  before insert or update of staff_id, starts_on, ends_on, status
  on hr.leave_requests
  for each row execute function hr.check_leave_overlap();

-- Closing a drawer with a non-zero variance opens a review record. It never
-- creates a deduction and never edits the shift.
create or replace function hr.capture_pos_discrepancy()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_currency text;
begin
  if new.status <> 'closed' or old.status = 'closed' then
    return new;
  end if;
  if new.variance is null or new.variance = 0 then
    return new;
  end if;

  select b.currency_code
    into v_currency
    from core.branches br
    join core.brands b on b.id = br.brand_id
   where br.id = new.branch_id;

  insert into hr.cashier_discrepancies (
    shift_id, branch_id, drawer_cashier_id, signed_variance, amount, currency_code
  ) values (
    new.id, new.branch_id, new.opened_by, round(new.variance, 2),
    abs(round(new.variance, 2)), coalesce(v_currency, 'SAR')
  )
  on conflict (shift_id) do nothing;

  return new;
end;
$fn$;

revoke all on function hr.capture_pos_discrepancy() from public, anon, authenticated;

drop trigger if exists tr_pos_shift_discrepancy on payments.pos_shifts;
create trigger tr_pos_shift_discrepancy
  after update of status on payments.pos_shifts
  for each row execute function hr.capture_pos_discrepancy();

-- Approved payroll statements are snapshots; a correction is a new adjustment.
create or replace function hr.protect_payroll_statement()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_status text;
begin
  select r.status into v_status
    from hr.payroll_runs r
   where r.id = coalesce(new.run_id, old.run_id);

  if v_status in ('approved','paid') then
    if tg_op = 'DELETE' then
      raise exception 'an approved payroll statement cannot be deleted'
        using errcode = '23514';
    end if;
    if row(new.*) is distinct from row(old.*) then
      raise exception 'an approved payroll statement is immutable'
        using errcode = '23514';
    end if;
  end if;
  return coalesce(new, old);
end;
$fn$;

revoke all on function hr.protect_payroll_statement() from public, anon, authenticated;

drop trigger if exists tr_payroll_statement_immutable on hr.payroll_statements;
create trigger tr_payroll_statement_immutable
  before update or delete on hr.payroll_statements
  for each row execute function hr.protect_payroll_statement();

-- The workflow only moves forward; a cancelled run may be regenerated.
create or replace function hr.guard_payroll_run_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if new.status = old.status then
    return new;
  end if;
  if not (
    (old.status = 'draft' and new.status in ('calculated','cancelled'))
    or (old.status = 'calculated' and new.status in ('draft','approved','cancelled'))
    or (old.status = 'approved' and new.status = 'paid')
    or (old.status = 'cancelled' and new.status = 'draft')
  ) then
    raise exception 'invalid payroll run transition % -> %', old.status, new.status
      using errcode = '23514';
  end if;
  return new;
end;
$fn$;

revoke all on function hr.guard_payroll_run_status() from public, anon, authenticated;

drop trigger if exists tr_payroll_run_status on hr.payroll_runs;
create trigger tr_payroll_run_status
  before update of status on hr.payroll_runs
  for each row execute function hr.guard_payroll_run_status();

-- ---------------------------------------------------------------------------
-- 12. Shared guards
-- ---------------------------------------------------------------------------
create or replace function hr.my_staff_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $fn$
  select sm.id
    from identity.staff_members sm
   where sm.user_id = auth.uid()
     and sm.status = 'active';
$fn$;

comment on function hr.my_staff_id() is
  'The active staff_members id of the caller, or null.';

create or replace function hr.is_owner()
returns boolean
language sql
stable
security definer
set search_path = ''
as $fn$
  select exists (
    select 1
      from identity.staff_members sm
      join identity.staff_roles sr on sr.staff_id = sm.id
      join identity.roles r on r.id = sr.role_id
     where sm.user_id = auth.uid()
       and sm.status = 'active'
       and r.code = 'owner'
  );
$fn$;

create or replace function hr.require_staff()
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_staff uuid;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  v_staff := hr.my_staff_id();
  if v_staff is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  return v_staff;
end;
$fn$;

create or replace function hr.require_permission(p_code text)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_staff uuid;
begin
  v_staff := hr.require_staff();
  if not identity.has_permission(p_code) then
    raise exception 'missing permission: %', p_code using errcode = '42501';
  end if;
  return v_staff;
end;
$fn$;

-- A branch manager sees the staff who share a branch; a global scope sees all.
create or replace function hr.can_access_staff(p_staff_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $fn$
  select exists (
    select 1
      from identity.staff_members me
     where me.user_id = auth.uid()
       and me.status = 'active'
       and (
         me.id = p_staff_id
         or identity.manages_all_branches()
         or exists (
           select 1
             from identity.staff_roles target
             join identity.staff_roles mine on mine.staff_id = me.id
            where target.staff_id = p_staff_id
              and mine.branch_id is not null
              and mine.branch_id = target.branch_id
         )
       )
  );
$fn$;

comment on function hr.can_access_staff(uuid) is
  'True when the caller is the employee, manages every branch, or shares a '
  'branch-scoped role with the target. Mirrors the staff_roles scope of RLS.';

create or replace function hr.assert_staff_access(p_staff_id uuid)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_staff uuid;
begin
  v_staff := hr.require_staff();
  if not hr.can_access_staff(p_staff_id) then
    raise exception 'staff member out of scope' using errcode = '42501';
  end if;
  return v_staff;
end;
$fn$;

create or replace function hr.business_time_zone()
returns text
language sql
stable
security definer
set search_path = ''
as $fn$
  select coalesce(
    (select s.business_time_zone from hr.settings s where s.id = 1),
    'Asia/Riyadh'
  );
$fn$;

create or replace function hr.fmt_ts(p_ts timestamptz)
returns text
language sql
stable
security definer
set search_path = ''
as $fn$
  select case
    when p_ts is null then null
    else to_char(p_ts at time zone hr.business_time_zone(), 'YYYY-MM-DD HH24:MI')
  end;
$fn$;

revoke all on function hr.my_staff_id() from public, anon, authenticated;
revoke all on function hr.is_owner() from public, anon, authenticated;
revoke all on function hr.require_staff() from public, anon, authenticated;
revoke all on function hr.require_permission(text) from public, anon, authenticated;
revoke all on function hr.can_access_staff(uuid) from public, anon, authenticated;
revoke all on function hr.assert_staff_access(uuid) from public, anon, authenticated;
revoke all on function hr.business_time_zone() from public, anon, authenticated;
revoke all on function hr.fmt_ts(timestamptz) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 13. Reference data for the HR screens
-- ---------------------------------------------------------------------------
create or replace function public.admin_hr_reference()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
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
      'absence_day_rate', case when v_show_policy then s.absence_day_rate else null end
    ),
    'my_staff_id', v_staff
  )
  from (select * from hr.settings where id = 1) s;
end;
$fn$;

comment on function public.admin_hr_reference() is
  'Branches in scope, active leave types and the HR policy row for the screens.';

revoke all on function public.admin_hr_reference() from public, anon;
grant execute on function public.admin_hr_reference() to authenticated;

-- ---------------------------------------------------------------------------
-- 14. Employee directory and file
-- ---------------------------------------------------------------------------
create or replace function public.admin_hr_employees(
  p_search     text default null,
  p_branch_id  uuid default null,
  p_status     text default null,
  p_department text default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_term text := nullif(btrim(left(coalesce(p_search, ''), 120)), '');
  v_status text := nullif(btrim(coalesce(p_status, '')), '');
  v_department text := nullif(btrim(coalesce(p_department, '')), '');
begin
  perform hr.require_permission('hr.employee.read');

  if p_branch_id is not null and not identity.can_manage_branch(p_branch_id) then
    raise exception 'branch out of scope' using errcode = '42501';
  end if;
  if v_status is not null and v_status not in
     ('active','probation','on_leave','terminated') then
    raise exception 'invalid employment status' using errcode = '22023';
  end if;

  return coalesce((
    select jsonb_agg(row_json order by sort_name, staff_id)
    from (
      select
        sm.id as staff_id,
        sm.full_name as sort_name,
        jsonb_build_object(
          'staff_id', sm.id,
          'user_id', sm.user_id,
          'full_name', sm.full_name,
          'email', sm.email,
          'avatar_url', sm.avatar_url,
          'account_status', sm.status,
          'employee_number', e.employee_number,
          'department', coalesce(e.department, ''),
          'job_title', coalesce(e.job_title, ''),
          'employment_type', coalesce(e.employment_type, 'full_time'),
          'employment_status', coalesce(e.employment_status, 'active'),
          'hired_on', e.hired_on,
          'terminated_on', e.terminated_on,
          'phone', coalesce(e.phone, ''),
          'branches', coalesce((
            select jsonb_agg(jsonb_build_object(
              'id', b.id,
              'name_ar', b.name_ar,
              'name_en', b.name_en
            ) order by b.name_ar)
            from identity.staff_roles sr
            join core.branches b on b.id = sr.branch_id
            where sr.staff_id = sm.id
          ), '[]'::jsonb),
          'roles', coalesce((
            select jsonb_agg(jsonb_build_object(
              'code', r.code,
              'name_ar', r.name_ar,
              'name_en', r.name_en,
              'branch_id', sr.branch_id
            ) order by r.code)
            from identity.staff_roles sr
            join identity.roles r on r.id = sr.role_id
            where sr.staff_id = sm.id
          ), '[]'::jsonb)
        ) as row_json
        from identity.staff_members sm
        left join hr.employment_records e on e.staff_id = sm.id
       where hr.can_access_staff(sm.id)
         and (v_status is null
              or coalesce(e.employment_status, 'active') = v_status)
         and (v_department is null
              or btrim(coalesce(e.department, '')) = v_department)
         and (p_branch_id is null
              or exists (
                select 1 from identity.staff_roles sr
                 where sr.staff_id = sm.id and sr.branch_id = p_branch_id
              ))
         and (
           v_term is null
           or core.normalize_ar(coalesce(sm.full_name, ''))
                like '%' || core.normalize_ar(v_term) || '%'
           or lower(coalesce(sm.email, '')) like '%' || lower(v_term) || '%'
           or lower(coalesce(e.employee_number, '')) like '%' || lower(v_term) || '%'
           or core.normalize_ar(coalesce(e.job_title, ''))
                like '%' || core.normalize_ar(v_term) || '%'
         )
    ) rows
  ), '[]'::jsonb);
end;
$fn$;

comment on function public.admin_hr_employees(text, uuid, text, text) is
  'Employee directory of the branches the caller manages, with employment file, '
  'branches and roles. Compensation is never part of this payload.';

revoke all on function public.admin_hr_employees(text, uuid, text, text)
  from public, anon;
grant execute on function public.admin_hr_employees(text, uuid, text, text)
  to authenticated;

create or replace function public.admin_hr_employee(p_staff_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_me uuid;
  v_self boolean;
  v_can_hr boolean;
  v_can_attendance boolean;
  v_can_payroll boolean;
  v_can_compensation boolean;
  v_can_finance boolean;
  v_payload jsonb;
begin
  v_me := hr.require_staff();
  v_self := v_me = p_staff_id;
  v_can_hr := identity.has_permission('hr.employee.read');
  if not v_self and not v_can_hr then
    raise exception 'missing permission: hr.employee.read' using errcode = '42501';
  end if;
  if not v_self then
    perform hr.assert_staff_access(p_staff_id);
  end if;
  if not exists (
    select 1 from identity.staff_members sm where sm.id = p_staff_id
  ) then
    raise exception 'employee not found' using errcode = 'P0002';
  end if;

  v_can_attendance := identity.has_permission('hr.attendance.read')
    or identity.has_permission('hr.attendance.manage');
  v_can_payroll := identity.has_permission('hr.payroll.read');
  v_can_compensation := identity.has_permission('hr.compensation.manage');
  v_can_finance := identity.has_permission('hr.finance.adjust');

  select jsonb_build_object(
    'staff_id', sm.id,
    'user_id', sm.user_id,
    'full_name', sm.full_name,
    'email', sm.email,
    'avatar_url', sm.avatar_url,
    'account_status', sm.status,
    'accepted_at', sm.accepted_at,
    'employment', case when e.staff_id is null then null else jsonb_build_object(
      'employee_number', e.employee_number,
      'department', e.department,
      'job_title', e.job_title,
      'employment_type', e.employment_type,
      'employment_status', e.employment_status,
      'hired_on', e.hired_on,
      'terminated_on', e.terminated_on,
      'phone', e.phone,
      'emergency_contact_name', e.emergency_contact_name,
      'emergency_contact_phone', e.emergency_contact_phone,
      'notes', e.notes
    ) end,
    'roles', coalesce((
      select jsonb_agg(jsonb_build_object(
        'code', r.code,
        'name_ar', r.name_ar,
        'name_en', r.name_en,
        'branch_id', sr.branch_id
      ) order by r.code)
      from identity.staff_roles sr
      join identity.roles r on r.id = sr.role_id
      where sr.staff_id = sm.id
    ), '[]'::jsonb),
    'branches', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', b.id,
        'name_ar', b.name_ar,
        'name_en', b.name_en
      ) order by b.name_ar)
      from identity.staff_roles sr
      join core.branches b on b.id = sr.branch_id
      where sr.staff_id = sm.id
    ), '[]'::jsonb),
    'attendance', case
      when not (v_self or v_can_attendance) then null
      else coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', a.id,
          'branch_id', a.branch_id,
          'branch_name_ar', br.name_ar,
          'branch_name_en', br.name_en,
          'clock_in', a.clock_in,
          'clock_out', a.clock_out,
          'clock_in_local', hr.fmt_ts(a.clock_in),
          'clock_out_local', hr.fmt_ts(a.clock_out),
          'is_open', a.clock_out is null
        ) order by a.clock_in desc)
        from (
          select * from hr.attendance_sessions s
           where s.staff_id = p_staff_id
           order by s.clock_in desc
           limit 30
        ) a
        left join core.branches br on br.id = a.branch_id
      ), '[]'::jsonb)
    end,
    'leave', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', l.id,
        'leave_type_id', l.leave_type_id,
        'type_name_ar', t.name_ar,
        'type_name_en', t.name_en,
        'starts_on', l.starts_on,
        'ends_on', l.ends_on,
        'days', (l.ends_on - l.starts_on + 1),
        'status', l.status,
        'reason', l.reason,
        'review_note', l.review_note
      ) order by l.starts_on desc)
      from (
        select * from hr.leave_requests r
         where r.staff_id = p_staff_id
         order by r.starts_on desc
         limit 20
      ) l
      join hr.leave_types t on t.id = l.leave_type_id
    ), '[]'::jsonb),
    'compensation', case
      when not (v_self or v_can_payroll or v_can_compensation) then null
      else jsonb_build_object(
        'current', (
          select jsonb_build_object(
            'id', c.id,
            'basic_salary', c.basic_salary,
            'housing_allowance', c.housing_allowance,
            'transport_allowance', c.transport_allowance,
            'other_allowance', c.other_allowance,
            'currency_code', c.currency_code,
            'effective_from', c.effective_from,
            'effective_to', c.effective_to
          )
          from hr.compensations c
          where c.staff_id = p_staff_id
            and c.effective_from <= current_date
            and (c.effective_to is null or c.effective_to >= current_date)
          order by c.effective_from desc
          limit 1
        ),
        'history', coalesce((
          select jsonb_agg(jsonb_build_object(
            'id', c.id,
            'basic_salary', c.basic_salary,
            'allowances', round(
              c.housing_allowance + c.transport_allowance + c.other_allowance, 2
            ),
            'currency_code', c.currency_code,
            'effective_from', c.effective_from,
            'effective_to', c.effective_to,
            'note', c.note
          ) order by c.effective_from desc)
          from (
            select * from hr.compensations c
             where c.staff_id = p_staff_id
             order by c.effective_from desc
             limit 12
          ) c
        ), '[]'::jsonb)
      )
    end,
    'payslips', case
      when not (v_self or v_can_payroll) then null
      else coalesce((
        select jsonb_agg(jsonb_build_object(
          'statement_id', p.id,
          'run_id', p.run_id,
          'period_year', r.period_year,
          'period_month', r.period_month,
          'run_status', r.status,
          'gross', p.gross,
          'deductions_total', p.deductions_total,
          'net', p.net,
          'currency_code', p.currency_code
        ) order by r.period_year desc, r.period_month desc)
        from (
          select st.* from hr.payroll_statements st
           join hr.payroll_runs rr on rr.id = st.run_id
           where st.staff_id = p_staff_id
             and rr.status in ('approved','paid')
           order by rr.period_year desc, rr.period_month desc
           limit 12
        ) p
        join hr.payroll_runs r on r.id = p.run_id
      ), '[]'::jsonb)
    end,
    'advances', case
      when not (v_self or v_can_finance) then null
      else coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', a.id,
          'amount', a.amount,
          'settled_amount', a.settled_amount,
          'outstanding', round(a.amount - a.settled_amount, 2),
          'status', a.status,
          'created_at', a.created_at,
          'reason', a.reason
        ) order by a.created_at desc)
        from (
          select * from hr.salary_advances a
           where a.staff_id = p_staff_id
           order by a.created_at desc
           limit 12
        ) a
      ), '[]'::jsonb)
    end,
    'adjustments', case
      when not (v_can_payroll or v_can_finance) then null
      else coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', a.id,
          'kind', a.kind,
          'amount', a.amount,
          'reason', a.reason,
          'status', a.status,
          'source_type', a.source_type,
          'effective_date', a.effective_date,
          'payroll_run_id', a.payroll_run_id
        ) order by a.effective_date desc, a.created_at desc)
        from (
          select * from hr.adjustments a
           where a.staff_id = p_staff_id
           order by a.effective_date desc, a.created_at desc
           limit 20
        ) a
      ), '[]'::jsonb)
    end,
    'cashier_shifts', case
      when not (v_self or v_can_hr) then null
      else coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', s.id,
          'status', s.status,
          'opened_at', s.opened_at,
          'closed_at', s.closed_at,
          'opened_at_local', hr.fmt_ts(s.opened_at),
          'closed_at_local', hr.fmt_ts(s.closed_at),
          'variance', s.variance,
          'currency_code', coalesce(b.currency_code, 'SAR')
        ) order by s.opened_at desc)
        from (
          select * from payments.pos_shifts ps
           where ps.opened_by = p_staff_id
           order by ps.opened_at desc
           limit 10
        ) s
        left join core.branches br on br.id = s.branch_id
        left join core.brands b on b.id = br.brand_id
      ), '[]'::jsonb)
    end
  )
  into v_payload
  from identity.staff_members sm
  left join hr.employment_records e on e.staff_id = sm.id
  where sm.id = p_staff_id;

  return v_payload;
end;
$fn$;

comment on function public.admin_hr_employee(uuid) is
  'One employee file. Self always reads their own; HR readers need '
  'hr.employee.read. Salary and payroll blocks are null without permission.';

revoke all on function public.admin_hr_employee(uuid) from public, anon;
grant execute on function public.admin_hr_employee(uuid) to authenticated;

create or replace function public.admin_hr_save_employment(
  p_staff_id                uuid,
  p_employee_number         text default null,
  p_department              text default null,
  p_job_title               text default null,
  p_employment_type         text default null,
  p_employment_status       text default null,
  p_hired_on                date default null,
  p_terminated_on           date default null,
  p_phone                   text default null,
  p_emergency_contact_name  text default null,
  p_emergency_contact_phone text default null,
  p_notes                   text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_me uuid;
  v_old hr.employment_records%rowtype;
  v_number text := nullif(btrim(coalesce(p_employee_number, '')), '');
  v_type text := coalesce(nullif(btrim(coalesce(p_employment_type, '')), ''), 'full_time');
  v_status text := coalesce(nullif(btrim(coalesce(p_employment_status, '')), ''), 'active');
begin
  v_me := hr.require_permission('hr.employee.write');
  perform hr.assert_staff_access(p_staff_id);

  if not exists (select 1 from identity.staff_members sm where sm.id = p_staff_id) then
    raise exception 'employee not found' using errcode = 'P0002';
  end if;
  if v_type not in ('full_time','part_time','contract') then
    raise exception 'invalid employment type' using errcode = '22023';
  end if;
  if v_status not in ('active','probation','on_leave','terminated') then
    raise exception 'invalid employment status' using errcode = '22023';
  end if;
  if v_status = 'terminated' and p_terminated_on is null then
    raise exception 'a terminated employment needs a termination date'
      using errcode = '22023';
  end if;
  if p_terminated_on is not null and p_hired_on is not null
     and p_terminated_on < p_hired_on then
    raise exception 'termination date precedes hire date' using errcode = '22023';
  end if;

  select * into v_old
    from hr.employment_records e
   where e.staff_id = p_staff_id
   for update;

  insert into hr.employment_records (
    staff_id, employee_number, department, job_title, employment_type,
    employment_status, hired_on, terminated_on, phone,
    emergency_contact_name, emergency_contact_phone, notes
  ) values (
    p_staff_id,
    v_number,
    left(btrim(coalesce(p_department, '')), 80),
    left(btrim(coalesce(p_job_title, '')), 80),
    v_type,
    v_status,
    p_hired_on,
    p_terminated_on,
    left(btrim(coalesce(p_phone, '')), 40),
    left(btrim(coalesce(p_emergency_contact_name, '')), 80),
    left(btrim(coalesce(p_emergency_contact_phone, '')), 40),
    left(btrim(coalesce(p_notes, '')), 1000)
  )
  on conflict (staff_id) do update set
    employee_number = excluded.employee_number,
    department = excluded.department,
    job_title = excluded.job_title,
    employment_type = excluded.employment_type,
    employment_status = excluded.employment_status,
    hired_on = excluded.hired_on,
    terminated_on = excluded.terminated_on,
    phone = excluded.phone,
    emergency_contact_name = excluded.emergency_contact_name,
    emergency_contact_phone = excluded.emergency_contact_phone,
    notes = excluded.notes;

  perform identity.audit(
    'hr.employment.save',
    'staff_employee',
    p_staff_id,
    case when v_old.staff_id is null then null else to_jsonb(v_old) end,
    jsonb_build_object(
      'employee_number', v_number,
      'department', left(btrim(coalesce(p_department, '')), 80),
      'job_title', left(btrim(coalesce(p_job_title, '')), 80),
      'employment_type', v_type,
      'employment_status', v_status,
      'hired_on', p_hired_on,
      'terminated_on', p_terminated_on
    ),
    null
  );

  return (
    select jsonb_build_object(
      'staff_id', e.staff_id,
      'employee_number', e.employee_number,
      'department', e.department,
      'job_title', e.job_title,
      'employment_type', e.employment_type,
      'employment_status', e.employment_status,
      'hired_on', e.hired_on,
      'terminated_on', e.terminated_on,
      'phone', e.phone,
      'emergency_contact_name', e.emergency_contact_name,
      'emergency_contact_phone', e.emergency_contact_phone,
      'notes', e.notes
    )
    from hr.employment_records e
    where e.staff_id = p_staff_id
  );
end;
$fn$;

comment on function public.admin_hr_save_employment(
  uuid, text, text, text, text, text, date, date, text, text, text, text
) is
  'Creates or edits the employment file. Cannot grant account access or roles.';

revoke all on function public.admin_hr_save_employment(
  uuid, text, text, text, text, text, date, date, text, text, text, text
) from public, anon;
grant execute on function public.admin_hr_save_employment(
  uuid, text, text, text, text, text, date, date, text, text, text, text
) to authenticated;

-- ---------------------------------------------------------------------------
-- 15. Attendance
-- ---------------------------------------------------------------------------
create or replace function hr.attendance_json(p_session_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $fn$
  select jsonb_build_object(
    'id', a.id,
    'staff_id', a.staff_id,
    'branch_id', a.branch_id,
    'branch_name_ar', b.name_ar,
    'branch_name_en', b.name_en,
    'clock_in', a.clock_in,
    'clock_out', a.clock_out,
    'clock_in_local', hr.fmt_ts(a.clock_in),
    'clock_out_local', hr.fmt_ts(a.clock_out),
    'break_started_at', a.break_started_at,
    'break_ended_at', a.break_ended_at,
    'is_open', a.clock_out is null,
    'is_on_break', a.break_started_at is not null and a.break_ended_at is null,
    'note', a.note,
    'clock_out_note', a.clock_out_note,
    'worked_minutes', greatest(
      0,
      floor(extract(epoch from (coalesce(a.clock_out, now()) - a.clock_in)) / 60)::int
      - coalesce(
          floor(extract(epoch from (a.break_ended_at - a.break_started_at)) / 60)::int,
          0
        )
    )
  )
  from hr.attendance_sessions a
  left join core.branches b on b.id = a.branch_id
  where a.id = p_session_id;
$fn$;

revoke all on function hr.attendance_json(uuid) from public, anon, authenticated;

create or replace function public.hr_clock_in(
  p_branch_id uuid,
  p_note      text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_me uuid;
  v_id uuid;
begin
  v_me := hr.require_staff();

  if not exists (
    select 1 from core.branches b where b.id = p_branch_id and b.is_active
  ) then
    raise exception 'branch not found or inactive' using errcode = 'P0002';
  end if;
  if not identity.can_manage_branch(p_branch_id) then
    raise exception 'branch out of scope' using errcode = '42501';
  end if;

  begin
    insert into hr.attendance_sessions (
      staff_id, branch_id, clock_in, note, created_by
    ) values (
      v_me, p_branch_id, now(), left(btrim(coalesce(p_note, '')), 240), v_me
    )
    returning id into v_id;
  exception
    when unique_violation then
      raise exception 'already clocked in' using errcode = '23505';
  end;

  perform identity.audit(
    'hr.attendance.clock_in',
    'attendance_session',
    v_id,
    null,
    jsonb_build_object('branch_id', p_branch_id),
    p_branch_id
  );

  return hr.attendance_json(v_id);
end;
$fn$;

comment on function public.hr_clock_in(uuid, text) is
  'Starts the caller''s attendance session with the server clock. A second '
  'clock-in while one is open is refused by a unique index.';

revoke all on function public.hr_clock_in(uuid, text) from public, anon;
grant execute on function public.hr_clock_in(uuid, text) to authenticated;

create or replace function public.hr_clock_out(p_note text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_me uuid;
  v_session hr.attendance_sessions%rowtype;
begin
  v_me := hr.require_staff();

  select *
    into v_session
    from hr.attendance_sessions s
   where s.staff_id = v_me
     and s.clock_out is null
   for update;
  if not found then
    raise exception 'no open attendance session' using errcode = '23514';
  end if;

  update hr.attendance_sessions
     set clock_out = now(),
         break_ended_at = case
           when break_started_at is not null and break_ended_at is null then now()
           else break_ended_at
         end,
         clock_out_note = left(btrim(coalesce(p_note, '')), 240)
   where id = v_session.id;

  perform identity.audit(
    'hr.attendance.clock_out',
    'attendance_session',
    v_session.id,
    jsonb_build_object('clock_out', null),
    jsonb_build_object('clock_out', now()),
    v_session.branch_id
  );

  return hr.attendance_json(v_session.id);
end;
$fn$;

comment on function public.hr_clock_out(text) is
  'Closes the caller''s open session with the server clock and ends an open '
  'break. An overnight session is closed on the day it ends, not rewritten.';

revoke all on function public.hr_clock_out(text) from public, anon;
grant execute on function public.hr_clock_out(text) to authenticated;

create or replace function public.hr_break_start()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_me uuid;
  v_session hr.attendance_sessions%rowtype;
begin
  v_me := hr.require_staff();
  select * into v_session
    from hr.attendance_sessions s
   where s.staff_id = v_me and s.clock_out is null
   for update;
  if not found then
    raise exception 'no open attendance session' using errcode = '23514';
  end if;
  if v_session.break_started_at is not null and v_session.break_ended_at is null then
    raise exception 'a break is already open' using errcode = '23514';
  end if;
  if v_session.break_started_at is not null then
    raise exception 'this session already used its break' using errcode = '23514';
  end if;

  update hr.attendance_sessions
     set break_started_at = now(), break_ended_at = null
   where id = v_session.id;

  perform identity.audit(
    'hr.attendance.break_start',
    'attendance_session',
    v_session.id,
    null,
    jsonb_build_object('break_started_at', now()),
    v_session.branch_id
  );

  return hr.attendance_json(v_session.id);
end;
$fn$;

revoke all on function public.hr_break_start() from public, anon;
grant execute on function public.hr_break_start() to authenticated;

create or replace function public.hr_break_end()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_me uuid;
  v_session hr.attendance_sessions%rowtype;
begin
  v_me := hr.require_staff();
  select * into v_session
    from hr.attendance_sessions s
   where s.staff_id = v_me and s.clock_out is null
   for update;
  if not found then
    raise exception 'no open attendance session' using errcode = '23514';
  end if;
  if v_session.break_started_at is null or v_session.break_ended_at is not null then
    raise exception 'no open break' using errcode = '23514';
  end if;

  update hr.attendance_sessions
     set break_ended_at = now()
   where id = v_session.id;

  perform identity.audit(
    'hr.attendance.break_end',
    'attendance_session',
    v_session.id,
    null,
    jsonb_build_object('break_ended_at', now()),
    v_session.branch_id
  );

  return hr.attendance_json(v_session.id);
end;
$fn$;

revoke all on function public.hr_break_end() from public, anon;
grant execute on function public.hr_break_end() to authenticated;

create or replace function public.hr_my_attendance(
  p_from date default null,
  p_to   date default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
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
      from hr.attendance_metrics(v_me, v_from, v_to) m
    )
  );
end;
$fn$;

revoke all on function public.hr_my_attendance(date, date) from public, anon;
grant execute on function public.hr_my_attendance(date, date) to authenticated;

create or replace function hr.attendance_metrics(
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
  present_shifts     integer
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
  schedules as (
    select ws.*
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
    ), 0)::integer,
    coalesce(sum(greatest(
      0,
      floor(extract(epoch from (m.clock_in - m.scheduled_start)) / 60)::int
      - (select grace from cfg)
    )) filter (where m.clock_in is not null), 0)::integer,
    coalesce(sum(greatest(
      0,
      floor(extract(epoch from (m.scheduled_end - m.clock_out)) / 60)::int
    )) filter (where m.clock_out is not null and m.scheduled_end < now()), 0)::integer,
    (select minutes from worked),
    coalesce(count(*) filter (where m.clock_in is not null), 0)::integer
  from matched m;
$fn$;

revoke all on function hr.attendance_metrics(uuid, date, date)
  from public, anon, authenticated;

create or replace function public.admin_hr_attendance(
  p_from      date default null,
  p_to        date default null,
  p_branch_id uuid default null,
  p_staff_id  uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
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
      'late_minutes', case
        when sch.id is null or a.clock_in is null then 0
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

comment on function public.admin_hr_attendance(date, date, uuid, uuid) is
  'Attendance sessions of accessible staff in a date range, with late and '
  'early minutes measured against the published schedule.';

revoke all on function public.admin_hr_attendance(date, date, uuid, uuid)
  from public, anon;
grant execute on function public.admin_hr_attendance(date, date, uuid, uuid)
  to authenticated;

create or replace function public.admin_hr_request_attendance_correction(
  p_staff_id   uuid,
  p_session_id uuid default null,
  p_clock_in   timestamptz default null,
  p_clock_out  timestamptz default null,
  p_reason     text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_me uuid;
  v_branch uuid;
  v_id uuid;
  v_reason text := left(btrim(coalesce(p_reason, '')), 500);
begin
  v_me := hr.require_staff();
  if v_me <> p_staff_id then
    perform hr.require_permission('hr.attendance.manage');
  end if;
  perform hr.assert_staff_access(p_staff_id);

  if v_reason = '' then
    raise exception 'an attendance correction needs a reason' using errcode = '22023';
  end if;
  if p_session_id is null and p_clock_in is null and p_clock_out is null then
    raise exception 'no change proposed' using errcode = '22023';
  end if;
  if p_clock_in is not null and p_clock_out is not null
     and p_clock_out <= p_clock_in then
    raise exception 'clock out must follow clock in' using errcode = '22023';
  end if;

  if p_session_id is not null then
    select s.branch_id into v_branch
      from hr.attendance_sessions s
     where s.id = p_session_id
       and s.staff_id = p_staff_id;
    if v_branch is null then
      raise exception 'attendance session not found' using errcode = 'P0002';
    end if;
  else
    select sr.branch_id into v_branch
      from identity.staff_roles sr
     where sr.staff_id = p_staff_id
       and sr.branch_id is not null
     order by sr.created_at
     limit 1;
    if v_branch is null then
      raise exception 'the employee has no branch to record attendance in'
        using errcode = '22023';
    end if;
    if p_clock_in is null then
      raise exception 'a new attendance record needs a clock-in time'
        using errcode = '22023';
    end if;
  end if;

  insert into hr.attendance_corrections (
    staff_id, branch_id, session_id, proposed_clock_in, proposed_clock_out,
    reason, requested_by
  ) values (
    p_staff_id, v_branch, p_session_id, p_clock_in, p_clock_out,
    v_reason, v_me
  )
  returning id into v_id;

  perform identity.audit(
    'hr.attendance.correction.request',
    'attendance_correction',
    v_id,
    null,
    jsonb_build_object(
      'staff_id', p_staff_id,
      'session_id', p_session_id,
      'proposed_clock_in', p_clock_in,
      'proposed_clock_out', p_clock_out
    ),
    v_branch
  );

  return jsonb_build_object(
    'id', v_id,
    'status', 'pending',
    'staff_id', p_staff_id,
    'session_id', p_session_id
  );
end;
$fn$;

comment on function public.admin_hr_request_attendance_correction(
  uuid, uuid, timestamptz, timestamptz, text
) is
  'Opens a pending correction. An employee may dispute their own record; an '
  'attendance manager may correct anyone in scope. Nothing changes before review.';

revoke all on function public.admin_hr_request_attendance_correction(
  uuid, uuid, timestamptz, timestamptz, text
) from public, anon;
grant execute on function public.admin_hr_request_attendance_correction(
  uuid, uuid, timestamptz, timestamptz, text
) to authenticated;

create or replace function public.admin_hr_attendance_corrections(
  p_status text default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_status text := nullif(btrim(coalesce(p_status, '')), '');
begin
  perform hr.require_permission('hr.attendance.manage');
  if v_status is not null and v_status not in
     ('pending','approved','rejected','cancelled') then
    raise exception 'invalid correction status' using errcode = '22023';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', c.id,
      'staff_id', c.staff_id,
      'staff_name', sm.full_name,
      'branch_id', c.branch_id,
      'branch_name_ar', b.name_ar,
      'branch_name_en', b.name_en,
      'session_id', c.session_id,
      'current_clock_in', s.clock_in,
      'current_clock_out', s.clock_out,
      'current_clock_in_local', hr.fmt_ts(s.clock_in),
      'current_clock_out_local', hr.fmt_ts(s.clock_out),
      'proposed_clock_in', c.proposed_clock_in,
      'proposed_clock_out', c.proposed_clock_out,
      'proposed_clock_in_local', hr.fmt_ts(c.proposed_clock_in),
      'proposed_clock_out_local', hr.fmt_ts(c.proposed_clock_out),
      'reason', c.reason,
      'status', c.status,
      'requested_by_name', rb.full_name,
      'reviewed_by_name', rv.full_name,
      'reviewed_at', c.reviewed_at,
      'review_note', c.review_note,
      'created_at', c.created_at,
      'created_at_local', hr.fmt_ts(c.created_at)
    ) order by c.created_at desc)
    from hr.attendance_corrections c
    join identity.staff_members sm on sm.id = c.staff_id
    left join core.branches b on b.id = c.branch_id
    left join hr.attendance_sessions s on s.id = c.session_id
    left join identity.staff_members rb on rb.id = c.requested_by
    left join identity.staff_members rv on rv.id = c.reviewed_by
    where (v_status is null or c.status = v_status)
      and hr.can_access_staff(c.staff_id)
  ), '[]'::jsonb);
end;
$fn$;

revoke all on function public.admin_hr_attendance_corrections(text)
  from public, anon;
grant execute on function public.admin_hr_attendance_corrections(text)
  to authenticated;

create or replace function public.admin_hr_review_attendance_correction(
  p_correction_id uuid,
  p_approve       boolean,
  p_note          text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_me uuid;
  v_c hr.attendance_corrections%rowtype;
  v_session hr.attendance_sessions%rowtype;
  v_in timestamptz;
  v_out timestamptz;
  v_note text := left(btrim(coalesce(p_note, '')), 500);
  v_session_id uuid;
begin
  v_me := hr.require_permission('hr.attendance.manage');

  select * into v_c
    from hr.attendance_corrections c
   where c.id = p_correction_id
   for update;
  if not found then
    raise exception 'attendance correction not found' using errcode = 'P0002';
  end if;
  if v_c.status <> 'pending' then
    raise exception 'attendance correction is already reviewed'
      using errcode = '23514';
  end if;
  perform hr.assert_staff_access(v_c.staff_id);
  if v_c.staff_id = v_me and not hr.is_owner() then
    raise exception 'you cannot approve your own attendance correction'
      using errcode = '42501';
  end if;

  if not p_approve then
    update hr.attendance_corrections
       set status = 'rejected', reviewed_by = v_me, reviewed_at = now(),
           review_note = v_note
     where id = v_c.id;
    perform identity.audit(
      'hr.attendance.correction.reject',
      'attendance_correction', v_c.id,
      jsonb_build_object('status', 'pending'),
      jsonb_build_object('status', 'rejected', 'note', v_note),
      v_c.branch_id
    );
    return jsonb_build_object('id', v_c.id, 'status', 'rejected');
  end if;

  if v_c.session_id is null then
    v_in := v_c.proposed_clock_in;
    v_out := v_c.proposed_clock_out;
    if v_in is null then
      raise exception 'a new attendance record needs a clock-in time'
        using errcode = '22023';
    end if;
    if exists (
      select 1 from hr.attendance_sessions s
       where s.staff_id = v_c.staff_id
         and s.clock_in < coalesce(v_out, 'infinity'::timestamptz)
         and coalesce(s.clock_out, 'infinity'::timestamptz) > v_in
    ) then
      raise exception 'the corrected session overlaps another session'
        using errcode = '23505';
    end if;
    insert into hr.attendance_sessions (
      staff_id, branch_id, clock_in, clock_out, note, created_by
    ) values (
      v_c.staff_id, v_c.branch_id, v_in, v_out,
      left('correction ' || v_c.id::text, 240), v_me
    )
    returning id into v_session_id;
  else
    select * into v_session
      from hr.attendance_sessions s
     where s.id = v_c.session_id
       and s.staff_id = v_c.staff_id
     for update;
    if not found then
      raise exception 'attendance session not found' using errcode = 'P0002';
    end if;
    v_in := coalesce(v_c.proposed_clock_in, v_session.clock_in);
    v_out := coalesce(v_c.proposed_clock_out, v_session.clock_out);
    if v_out is not null and v_out <= v_in then
      raise exception 'clock out must follow clock in' using errcode = '22023';
    end if;
    if exists (
      select 1 from hr.attendance_sessions s
       where s.staff_id = v_c.staff_id
         and s.id <> v_session.id
         and s.clock_in < coalesce(v_out, 'infinity'::timestamptz)
         and coalesce(s.clock_out, 'infinity'::timestamptz) > v_in
    ) then
      raise exception 'the corrected session overlaps another session'
        using errcode = '23505';
    end if;
    update hr.attendance_sessions
       set clock_in = v_in,
           clock_out = v_out,
           break_started_at = case
             when break_started_at is not null and break_started_at < v_in then v_in
             else break_started_at
           end,
           break_ended_at = case
             when break_ended_at is not null and v_out is not null
                  and break_ended_at > v_out then v_out
             else break_ended_at
           end
     where id = v_session.id;
    update hr.attendance_sessions
       set break_started_at = null, break_ended_at = null
     where id = v_session.id
       and break_started_at is not null
       and break_ended_at is not null
       and break_ended_at <= break_started_at;
    v_session_id := v_session.id;
  end if;

  update hr.attendance_corrections
     set status = 'approved', reviewed_by = v_me, reviewed_at = now(),
         review_note = v_note
   where id = v_c.id;

  perform identity.audit(
    'hr.attendance.correction.approve',
    'attendance_correction', v_c.id,
    jsonb_build_object('status', 'pending', 'session_id', v_c.session_id),
    jsonb_build_object(
      'status', 'approved',
      'session_id', v_session_id,
      'clock_in', v_in,
      'clock_out', v_out,
      'note', v_note
    ),
    v_c.branch_id
  );

  return jsonb_build_object(
    'id', v_c.id,
    'status', 'approved',
    'session', hr.attendance_json(v_session_id)
  );
end;
$fn$;

revoke all on function public.admin_hr_review_attendance_correction(
  uuid, boolean, text
) from public, anon;
grant execute on function public.admin_hr_review_attendance_correction(
  uuid, boolean, text
) to authenticated;

-- ---------------------------------------------------------------------------
-- 16. Schedules
-- ---------------------------------------------------------------------------
create or replace function public.admin_hr_schedules(
  p_from      date,
  p_to        date,
  p_branch_id uuid default null,
  p_staff_id  uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_me uuid;
  v_self boolean;
begin
  v_me := hr.require_staff();
  v_self := p_staff_id = v_me;
  if not v_self and not (
    identity.has_permission('hr.schedule.read')
    or identity.has_permission('hr.schedule.manage')
  ) then
    raise exception 'missing permission: hr.schedule.read' using errcode = '42501';
  end if;
  if p_to < p_from then
    raise exception 'invalid schedule date range' using errcode = '22023';
  end if;
  if p_to - p_from > 62 then
    raise exception 'schedule range is limited to 62 days' using errcode = '22023';
  end if;
  if p_staff_id is not null then
    perform hr.assert_staff_access(p_staff_id);
  end if;
  if p_branch_id is not null and not identity.can_manage_branch(p_branch_id) then
    raise exception 'branch out of scope' using errcode = '42501';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', s.id,
      'staff_id', s.staff_id,
      'staff_name', sm.full_name,
      'branch_id', s.branch_id,
      'branch_name_ar', b.name_ar,
      'branch_name_en', b.name_en,
      'date_local', to_char(
        s.scheduled_start at time zone hr.business_time_zone(), 'YYYY-MM-DD'
      ),
      'scheduled_start', s.scheduled_start,
      'scheduled_end', s.scheduled_end,
      'start_local', hr.fmt_ts(s.scheduled_start),
      'end_local', hr.fmt_ts(s.scheduled_end),
      'break_minutes', s.break_minutes,
      'hours', round(
        (extract(epoch from (s.scheduled_end - s.scheduled_start)) / 3600
         - s.break_minutes::numeric / 60)::numeric, 2
      ),
      'status', s.status,
      'note', s.note,
      'created_by_name', cb.full_name,
      'updated_by_name', ub.full_name,
      'created_at', s.created_at,
      'updated_at', s.updated_at
    ) order by s.scheduled_start)
    from hr.work_schedules s
    join identity.staff_members sm on sm.id = s.staff_id
    left join core.branches b on b.id = s.branch_id
    left join identity.staff_members cb on cb.id = s.created_by
    left join identity.staff_members ub on ub.id = s.updated_by
    where (s.scheduled_start at time zone hr.business_time_zone())::date
            between p_from and p_to
      and (p_branch_id is null or s.branch_id = p_branch_id)
      and (p_staff_id is null or s.staff_id = p_staff_id)
      and (p_staff_id is not null or hr.can_access_staff(s.staff_id))
      and (v_self or s.status <> 'cancelled')
  ), '[]'::jsonb);
end;
$fn$;

revoke all on function public.admin_hr_schedules(date, date, uuid, uuid)
  from public, anon;
grant execute on function public.admin_hr_schedules(date, date, uuid, uuid)
  to authenticated;

create or replace function public.admin_hr_save_schedule(
  p_staff_id      uuid,
  p_branch_id     uuid,
  p_start         timestamptz,
  p_end           timestamptz,
  p_break_minutes integer default 0,
  p_status        text default 'draft',
  p_note          text default null,
  p_id            uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_me uuid;
  v_status text := coalesce(nullif(btrim(coalesce(p_status, '')), ''), 'draft');
  v_id uuid;
begin
  v_me := hr.require_permission('hr.schedule.manage');
  perform hr.assert_staff_access(p_staff_id);
  if not identity.can_manage_branch(p_branch_id) then
    raise exception 'branch out of scope' using errcode = '42501';
  end if;
  if not exists (
    select 1 from core.branches b where b.id = p_branch_id and b.is_active
  ) then
    raise exception 'branch not found or inactive' using errcode = 'P0002';
  end if;
  if p_start is null or p_end is null or p_end <= p_start then
    raise exception 'invalid schedule window' using errcode = '22023';
  end if;
  if p_end - p_start > interval '24 hours' then
    raise exception 'a shift cannot exceed 24 hours' using errcode = '22023';
  end if;
  if coalesce(p_break_minutes, 0) < 0 or coalesce(p_break_minutes, 0) > 240 then
    raise exception 'invalid break length' using errcode = '22023';
  end if;
  if v_status not in ('draft','published') then
    raise exception 'invalid schedule status' using errcode = '22023';
  end if;

  if p_id is null then
    insert into hr.work_schedules (
      staff_id, branch_id, scheduled_start, scheduled_end, break_minutes,
      status, note, created_by, updated_by
    ) values (
      p_staff_id, p_branch_id, p_start, p_end, coalesce(p_break_minutes, 0),
      v_status, left(btrim(coalesce(p_note, '')), 500), v_me, v_me
    )
    returning id into v_id;

    perform identity.audit(
      'hr.schedule.create',
      'work_schedule', v_id,
      null,
      jsonb_build_object(
        'staff_id', p_staff_id,
        'branch_id', p_branch_id,
        'start', p_start,
        'end', p_end,
        'status', v_status
      ),
      p_branch_id
    );
  else
    update hr.work_schedules
       set staff_id = p_staff_id,
           branch_id = p_branch_id,
           scheduled_start = p_start,
           scheduled_end = p_end,
           break_minutes = coalesce(p_break_minutes, 0),
           status = v_status,
           note = left(btrim(coalesce(p_note, '')), 500),
           updated_by = v_me
     where id = p_id
       and hr.can_access_staff(staff_id)
    returning id into v_id;
    if v_id is null then
      raise exception 'work schedule not found' using errcode = 'P0002';
    end if;

    perform identity.audit(
      'hr.schedule.update',
      'work_schedule', v_id,
      null,
      jsonb_build_object(
        'staff_id', p_staff_id,
        'branch_id', p_branch_id,
        'start', p_start,
        'end', p_end,
        'status', v_status
      ),
      p_branch_id
    );
  end if;

  return (
    select jsonb_build_object(
      'id', s.id,
      'staff_id', s.staff_id,
      'branch_id', s.branch_id,
      'scheduled_start', s.scheduled_start,
      'scheduled_end', s.scheduled_end,
      'start_local', hr.fmt_ts(s.scheduled_start),
      'end_local', hr.fmt_ts(s.scheduled_end),
      'break_minutes', s.break_minutes,
      'status', s.status,
      'note', s.note
    )
    from hr.work_schedules s
    where s.id = v_id
  );
end;
$fn$;

comment on function public.admin_hr_save_schedule(
  uuid, uuid, timestamptz, timestamptz, integer, text, text, uuid
) is
  'Creates or edits a work schedule. The overlap trigger refuses two live '
  'schedules for the same person and records who changed it.';

revoke all on function public.admin_hr_save_schedule(
  uuid, uuid, timestamptz, timestamptz, integer, text, text, uuid
) from public, anon;
grant execute on function public.admin_hr_save_schedule(
  uuid, uuid, timestamptz, timestamptz, integer, text, text, uuid
) to authenticated;

create or replace function public.admin_hr_set_schedule_status(
  p_id     uuid,
  p_status text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_me uuid;
  v_old text;
  v_branch uuid;
begin
  v_me := hr.require_permission('hr.schedule.manage');
  if p_status not in ('draft','published','cancelled') then
    raise exception 'invalid schedule status' using errcode = '22023';
  end if;

  select s.status, s.branch_id into v_old, v_branch
    from hr.work_schedules s
   where s.id = p_id
   for update;
  if v_old is null then
    raise exception 'work schedule not found' using errcode = 'P0002';
  end if;
  if not identity.can_manage_branch(v_branch) then
    raise exception 'branch out of scope' using errcode = '42501';
  end if;

  update hr.work_schedules
     set status = p_status, updated_by = v_me
   where id = p_id;

  perform identity.audit(
    'hr.schedule.status',
    'work_schedule', p_id,
    jsonb_build_object('status', v_old),
    jsonb_build_object('status', p_status),
    v_branch
  );

  return jsonb_build_object('id', p_id, 'status', p_status);
end;
$fn$;

revoke all on function public.admin_hr_set_schedule_status(uuid, text)
  from public, anon;
grant execute on function public.admin_hr_set_schedule_status(uuid, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 17. Leave
-- ---------------------------------------------------------------------------
create or replace function public.hr_request_leave(
  p_leave_type_id       uuid,
  p_starts_on           date,
  p_ends_on             date,
  p_reason              text default null,
  p_supporting_document text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_me uuid;
  v_type hr.leave_types%rowtype;
  v_days integer;
  v_year integer;
  v_balance hr.leave_balances%rowtype;
  v_id uuid;
begin
  v_me := hr.require_staff();
  if p_starts_on is null or p_ends_on is null or p_ends_on < p_starts_on then
    raise exception 'invalid leave dates' using errcode = '22023';
  end if;
  if p_ends_on - p_starts_on > 366 then
    raise exception 'leave request is too long' using errcode = '22023';
  end if;

  select * into v_type
    from hr.leave_types t
   where t.id = p_leave_type_id and t.is_active;
  if not found then
    raise exception 'leave type not found' using errcode = 'P0002';
  end if;
  if v_type.requires_document
     and nullif(btrim(coalesce(p_supporting_document, '')), '') is null then
    raise exception 'this leave type requires a supporting document'
      using errcode = '22023';
  end if;

  v_days := (p_ends_on - p_starts_on) + 1;
  v_year := extract(year from p_starts_on)::integer;

  if v_type.tracks_balance then
    select * into v_balance
      from hr.leave_balances b
     where b.staff_id = v_me
       and b.leave_type_id = p_leave_type_id
       and b.year = v_year
       for update;
    if not found then
      raise exception 'leave balance is not configured for this year'
        using errcode = '22023';
    end if;
    if v_balance.used_days + v_days > v_balance.entitled_days then
      raise exception 'insufficient leave balance' using errcode = '22023';
    end if;
  end if;

  insert into hr.leave_requests (
    staff_id, leave_type_id, starts_on, ends_on, reason,
    supporting_document, requested_by
  ) values (
    v_me, p_leave_type_id, p_starts_on, p_ends_on,
    left(btrim(coalesce(p_reason, '')), 1000),
    left(btrim(coalesce(p_supporting_document, '')), 500),
    v_me
  )
  returning id into v_id;

  perform identity.audit(
    'hr.leave.request',
    'leave_request', v_id,
    null,
    jsonb_build_object(
      'leave_type_id', p_leave_type_id,
      'starts_on', p_starts_on,
      'ends_on', p_ends_on,
      'days', v_days
    ),
    null
  );

  return jsonb_build_object(
    'id', v_id,
    'status', 'pending',
    'days', v_days,
    'leave_type_id', p_leave_type_id
  );
end;
$fn$;

revoke all on function public.hr_request_leave(uuid, date, date, text, text)
  from public, anon;
grant execute on function public.hr_request_leave(uuid, date, date, text, text)
  to authenticated;

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

revoke all on function public.hr_cancel_leave_request(uuid, text)
  from public, anon;
grant execute on function public.hr_cancel_leave_request(uuid, text)
  to authenticated;

create or replace function public.admin_hr_leave_requests(
  p_status   text default null,
  p_staff_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_me uuid;
  v_self boolean;
  v_status text := nullif(btrim(coalesce(p_status, '')), '');
begin
  v_me := hr.require_staff();
  v_self := p_staff_id = v_me;
  if not v_self and not (
    identity.has_permission('hr.leave.review')
    or identity.has_permission('hr.employee.read')
  ) then
    raise exception 'missing permission: hr.leave.review' using errcode = '42501';
  end if;
  if p_staff_id is not null then
    perform hr.assert_staff_access(p_staff_id);
  end if;
  if v_status is not null and v_status not in
     ('pending','approved','rejected','cancelled') then
    raise exception 'invalid leave status' using errcode = '22023';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', l.id,
      'staff_id', l.staff_id,
      'staff_name', sm.full_name,
      'leave_type_id', l.leave_type_id,
      'type_name_ar', t.name_ar,
      'type_name_en', t.name_en,
      'is_paid', t.is_paid,
      'tracks_balance', t.tracks_balance,
      'starts_on', l.starts_on,
      'ends_on', l.ends_on,
      'days', (l.ends_on - l.starts_on + 1),
      'reason', l.reason,
      'supporting_document', l.supporting_document,
      'status', l.status,
      'requested_by_name', rb.full_name,
      'reviewed_by_name', rv.full_name,
      'reviewed_at', l.reviewed_at,
      'reviewed_at_local', hr.fmt_ts(l.reviewed_at),
      'review_note', l.review_note,
      'created_at', l.created_at,
      'created_at_local', hr.fmt_ts(l.created_at),
      'balance', case when t.tracks_balance then (
        select jsonb_build_object(
          'year', b.year,
          'entitled_days', b.entitled_days,
          'used_days', b.used_days,
          'remaining_days', b.entitled_days - b.used_days
        )
        from hr.leave_balances b
        where b.staff_id = l.staff_id
          and b.leave_type_id = l.leave_type_id
          and b.year = extract(year from l.starts_on)::integer
      ) else null end
    ) order by l.created_at desc)
    from hr.leave_requests l
    join identity.staff_members sm on sm.id = l.staff_id
    join hr.leave_types t on t.id = l.leave_type_id
    left join identity.staff_members rb on rb.id = l.requested_by
    left join identity.staff_members rv on rv.id = l.reviewed_by
    where (v_status is null or l.status = v_status)
      and (p_staff_id is null or l.staff_id = p_staff_id)
      and (p_staff_id is not null or hr.can_access_staff(l.staff_id))
  ), '[]'::jsonb);
end;
$fn$;

revoke all on function public.admin_hr_leave_requests(text, uuid)
  from public, anon;
grant execute on function public.admin_hr_leave_requests(text, uuid)
  to authenticated;

create or replace function public.admin_hr_review_leave(
  p_request_id uuid,
  p_approve    boolean,
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
  v_type hr.leave_types%rowtype;
  v_balance hr.leave_balances%rowtype;
  v_days integer;
  v_note text := left(btrim(coalesce(p_note, '')), 500);
begin
  v_me := hr.require_permission('hr.leave.review');
  select * into v_req
    from hr.leave_requests r
   where r.id = p_request_id
   for update;
  if not found then
    raise exception 'leave request not found' using errcode = 'P0002';
  end if;
  if v_req.status <> 'pending' then
    raise exception 'leave request is already reviewed' using errcode = '23514';
  end if;
  perform hr.assert_staff_access(v_req.staff_id);
  if v_req.requested_by = v_me or v_req.staff_id = v_me then
    raise exception 'you cannot approve your own leave request'
      using errcode = '42501';
  end if;

  select * into v_type from hr.leave_types t where t.id = v_req.leave_type_id;
  v_days := (v_req.ends_on - v_req.starts_on) + 1;

  if not p_approve then
    update hr.leave_requests
       set status = 'rejected', reviewed_by = v_me, reviewed_at = now(),
           review_note = v_note
     where id = v_req.id;
    perform identity.audit(
      'hr.leave.reject', 'leave_request', v_req.id,
      jsonb_build_object('status', 'pending'),
      jsonb_build_object('status', 'rejected', 'note', v_note),
      null
    );
    return jsonb_build_object('id', v_req.id, 'status', 'rejected');
  end if;

  if v_type.tracks_balance then
    select * into v_balance
      from hr.leave_balances b
     where b.staff_id = v_req.staff_id
       and b.leave_type_id = v_req.leave_type_id
       and b.year = extract(year from v_req.starts_on)::integer
       for update;
    if not found then
      raise exception 'leave balance is not configured for this year'
        using errcode = '22023';
    end if;
    if v_balance.used_days + v_days > v_balance.entitled_days then
      raise exception 'insufficient leave balance' using errcode = '22023';
    end if;
    update hr.leave_balances
       set used_days = used_days + v_days
     where staff_id = v_req.staff_id
       and leave_type_id = v_req.leave_type_id
       and year = v_balance.year;
  end if;

  update hr.leave_requests
     set status = 'approved', reviewed_by = v_me, reviewed_at = now(),
         review_note = v_note
   where id = v_req.id;

  perform identity.audit(
    'hr.leave.approve', 'leave_request', v_req.id,
    jsonb_build_object('status', 'pending'),
    jsonb_build_object(
      'status', 'approved',
      'days', v_days,
      'tracked_balance', v_type.tracks_balance,
      'note', v_note
    ),
    null
  );

  return jsonb_build_object(
    'id', v_req.id,
    'status', 'approved',
    'days', v_days
  );
end;
$fn$;

revoke all on function public.admin_hr_review_leave(uuid, boolean, text)
  from public, anon;
grant execute on function public.admin_hr_review_leave(uuid, boolean, text)
  to authenticated;

create or replace function public.admin_hr_set_leave_balance(
  p_staff_id      uuid,
  p_leave_type_id uuid,
  p_year          integer,
  p_entitled_days numeric
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_me uuid;
  v_old hr.leave_balances%rowtype;
  v_entitled numeric(6,2) := round(coalesce(p_entitled_days, 0), 2);
begin
  v_me := hr.require_permission('hr.leave.review');
  perform hr.assert_staff_access(p_staff_id);
  if p_year is null or p_year < 2000 or p_year > 2100 then
    raise exception 'invalid leave year' using errcode = '22023';
  end if;
  if v_entitled < 0 then
    raise exception 'entitled days cannot be negative' using errcode = '22023';
  end if;
  if not exists (
    select 1 from hr.leave_types t where t.id = p_leave_type_id and t.tracks_balance
  ) then
    raise exception 'this leave type does not track a balance' using errcode = '22023';
  end if;

  select * into v_old
    from hr.leave_balances b
   where b.staff_id = p_staff_id
     and b.leave_type_id = p_leave_type_id
     and b.year = p_year
   for update;

  if v_old.staff_id is not null and v_entitled < v_old.used_days then
    raise exception 'entitlement cannot be below the days already used'
      using errcode = '22023';
  end if;

  insert into hr.leave_balances (staff_id, leave_type_id, year, entitled_days)
  values (p_staff_id, p_leave_type_id, p_year, v_entitled)
  on conflict (staff_id, leave_type_id, year) do update
    set entitled_days = excluded.entitled_days;

  perform identity.audit(
    'hr.leave.balance.set',
    'leave_balance',
    p_staff_id,
    case when v_old.staff_id is null then null
         else jsonb_build_object('entitled_days', v_old.entitled_days) end,
    jsonb_build_object(
      'leave_type_id', p_leave_type_id,
      'year', p_year,
      'entitled_days', v_entitled
    ),
    null
  );

  return jsonb_build_object(
    'staff_id', p_staff_id,
    'leave_type_id', p_leave_type_id,
    'year', p_year,
    'entitled_days', v_entitled,
    'used_days', coalesce(v_old.used_days, 0),
    'remaining_days', v_entitled - coalesce(v_old.used_days, 0)
  );
end;
$fn$;

revoke all on function public.admin_hr_set_leave_balance(uuid, uuid, integer, numeric)
  from public, anon;
grant execute on function public.admin_hr_set_leave_balance(uuid, uuid, integer, numeric)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 18. Compensation history
-- ---------------------------------------------------------------------------
create or replace function public.admin_hr_set_compensation(
  p_staff_id            uuid,
  p_basic_salary        numeric,
  p_housing_allowance   numeric default 0,
  p_transport_allowance numeric default 0,
  p_other_allowance     numeric default 0,
  p_effective_from      date default null,
  p_note                text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_me uuid;
  v_from date := coalesce(p_effective_from, current_date);
  v_previous hr.compensations%rowtype;
  v_id uuid;
begin
  v_me := hr.require_permission('hr.compensation.manage');
  perform hr.assert_staff_access(p_staff_id);

  if p_basic_salary is null or p_basic_salary < 0 then
    raise exception 'invalid basic salary' using errcode = '22023';
  end if;
  if coalesce(p_housing_allowance, 0) < 0
     or coalesce(p_transport_allowance, 0) < 0
     or coalesce(p_other_allowance, 0) < 0 then
    raise exception 'allowances cannot be negative' using errcode = '22023';
  end if;

  perform pg_advisory_xact_lock(hashtext('hr.compensation:' || p_staff_id::text));

  if exists (
    select 1 from hr.compensations c
     where c.staff_id = p_staff_id
       and c.effective_from = v_from
  ) then
    raise exception 'a compensation record already starts on this date'
      using errcode = '23505';
  end if;
  if exists (
    select 1 from hr.compensations c
     where c.staff_id = p_staff_id
       and c.effective_from > v_from
  ) then
    raise exception 'cannot backdate before a later compensation record'
      using errcode = '22023';
  end if;

  select * into v_previous
    from hr.compensations c
   where c.staff_id = p_staff_id
     and c.effective_from < v_from
     and (c.effective_to is null or c.effective_to >= v_from)
   order by c.effective_from desc
   limit 1
   for update;

  if v_previous.id is not null then
    update hr.compensations
       set effective_to = v_from - 1
     where id = v_previous.id
       and effective_to is null;
  end if;

  insert into hr.compensations (
    staff_id, basic_salary, housing_allowance, transport_allowance,
    other_allowance, effective_from, note, created_by
  ) values (
    p_staff_id,
    round(p_basic_salary, 2),
    round(coalesce(p_housing_allowance, 0), 2),
    round(coalesce(p_transport_allowance, 0), 2),
    round(coalesce(p_other_allowance, 0), 2),
    v_from,
    left(btrim(coalesce(p_note, '')), 500),
    v_me
  )
  returning id into v_id;

  perform identity.audit(
    'hr.compensation.save',
    'compensation', v_id,
    case when v_previous.id is null then null else jsonb_build_object(
      'basic_salary', v_previous.basic_salary,
      'allowances', round(
        v_previous.housing_allowance + v_previous.transport_allowance
        + v_previous.other_allowance, 2
      ),
      'effective_from', v_previous.effective_from
    ) end,
    jsonb_build_object(
      'staff_id', p_staff_id,
      'basic_salary', round(p_basic_salary, 2),
      'effective_from', v_from
    ),
    null
  );

  return jsonb_build_object(
    'id', v_id,
    'staff_id', p_staff_id,
    'basic_salary', round(p_basic_salary, 2),
    'effective_from', v_from
  );
end;
$fn$;

comment on function public.admin_hr_set_compensation(
  uuid, numeric, numeric, numeric, numeric, date, text
) is
  'Adds an effective-dated salary row and closes the previous open range. '
  'History is preserved; no row is overwritten.';

revoke all on function public.admin_hr_set_compensation(
  uuid, numeric, numeric, numeric, numeric, date, text
) from public, anon;
grant execute on function public.admin_hr_set_compensation(
  uuid, numeric, numeric, numeric, numeric, date, text
) to authenticated;

-- ---------------------------------------------------------------------------
-- 19. Payroll: calculated, approved and paid are three separate acts
-- ---------------------------------------------------------------------------
-- A run is brand-level on purpose: one (year, month) exists once and its
-- totals answer for the whole brand. A branch-scoped reader receives only the
-- statements of the staff they may access, recomputed from those rows.
--
-- Nothing in this section deducts from a salary on its own:
--   * attendance deductions come from rates the owner typed in hr.settings,
--     and default to zero;
--   * a cashier shortage enters as an approved adjustment only after an
--     explicit review that names the person and the amount, and it is only
--     claimed when cashier_deduction_allowed is true and the deduction fits
--     under max_salary_deduction_percent of gross;
--   * a cashier adjustment that does not fit stays approved and unclaimed for
--     a later period instead of being silently reduced.
-- Payroll line labels that start with '@' are stable codes the client
-- localizes; any other label is the reviewer's own wording.

create or replace function hr.statement_json(p_statement_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $fn$
  select jsonb_build_object(
    'statement_id', st.id,
    'run_id', st.run_id,
    'staff_id', st.staff_id,
    'staff_name', sm.full_name,
    'employee_number', e.employee_number,
    'period_year', r.period_year,
    'period_month', r.period_month,
    'run_status', r.status,
    'basic_salary', st.basic_salary,
    'allowances_total', st.allowances_total,
    'additions_total', st.additions_total,
    'attendance_deduction', st.attendance_deduction,
    'advance_deduction', st.advance_deduction,
    'other_deductions', st.other_deductions,
    'deductions_total', st.deductions_total,
    'absence_days', st.absence_days,
    'late_minutes', st.late_minutes,
    'early_minutes', st.early_minutes,
    'gross', st.gross,
    'net', st.net,
    'currency_code', st.currency_code,
    'calculation_version', st.calculation_version,
    'lines', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', l.id,
        'kind', l.kind,
        'category', l.category,
        'source_type', l.source_type,
        'source_id', l.source_id,
        'label', l.label,
        'amount', l.amount
      ) order by l.kind desc, l.created_at, l.id)
      from hr.payroll_line_items l
      where l.statement_id = st.id
    ), '[]'::jsonb)
  )
  from hr.payroll_statements st
  join hr.payroll_runs r on r.id = st.run_id
  join identity.staff_members sm on sm.id = st.staff_id
  left join hr.employment_records e on e.staff_id = st.staff_id
  where st.id = p_statement_id;
$fn$;

revoke all on function hr.statement_json(uuid)
  from public, anon, authenticated;

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
         and a.effective_date between v_start and v_period_end
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
      v_claimed := v_claimed || v_adj.id;
    end loop;

    v_remaining := round(v_gross - v_attendance - v_other_deductions, 2);
    if v_remaining < 0 then
      raise exception
        'attendance and approved deductions exceed the gross pay of %; review the policy or the adjustments',
        v_staff.full_name
        using errcode = '23514';
    end if;

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
        'adjustment', v_adj.id, left(v_adj.reason, 120), v_adj.amount
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

create or replace function public.admin_hr_payroll_runs(p_limit integer default 24)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
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

revoke all on function public.admin_hr_payroll_runs(integer)
  from public, anon;
grant execute on function public.admin_hr_payroll_runs(integer)
  to authenticated;

create or replace function public.admin_hr_payroll_run(p_run_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
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

revoke all on function public.admin_hr_payroll_run(uuid)
  from public, anon;
grant execute on function public.admin_hr_payroll_run(uuid)
  to authenticated;

create or replace function public.admin_hr_statement(p_statement_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_me uuid;
  v_staff_id uuid;
  v_run_status text;
begin
  v_me := hr.require_staff();

  select st.staff_id, r.status
    into v_staff_id, v_run_status
    from hr.payroll_statements st
    join hr.payroll_runs r on r.id = st.run_id
   where st.id = p_statement_id;

  if v_staff_id is null then
    raise exception 'payslip not found' using errcode = 'P0002';
  end if;

  if v_staff_id = v_me then
    if v_run_status not in ('approved','paid') then
      raise exception 'this payslip is not final yet' using errcode = '42501';
    end if;
  else
    perform hr.require_permission('hr.payroll.read');
    perform hr.assert_staff_access(v_staff_id);
  end if;

  return hr.statement_json(p_statement_id);
end;
$fn$;

comment on function public.admin_hr_statement(uuid) is
  'One payslip with its line items. Self reads only approved or paid runs; '
  'HR readers need hr.payroll.read and share a branch with the employee.';

revoke all on function public.admin_hr_statement(uuid)
  from public, anon;
grant execute on function public.admin_hr_statement(uuid)
  to authenticated;

create or replace function public.hr_my_payslips()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_me uuid;
begin
  v_me := hr.require_staff();
  return coalesce((
    select jsonb_agg(hr.statement_json(st.id) order by r.period_year desc, r.period_month desc)
      from hr.payroll_statements st
      join hr.payroll_runs r on r.id = st.run_id
     where st.staff_id = v_me
       and r.status in ('approved','paid')
  ), '[]'::jsonb);
end;
$fn$;

revoke all on function public.hr_my_payslips()
  from public, anon;
grant execute on function public.hr_my_payslips()
  to authenticated;

create or replace function public.admin_hr_approve_payroll(
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

revoke all on function public.admin_hr_approve_payroll(uuid, text)
  from public, anon;
grant execute on function public.admin_hr_approve_payroll(uuid, text)
  to authenticated;

create or replace function public.admin_hr_pay_payroll(
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
    raise exception 'recording payroll payment needs all-branch scope'
      using errcode = '42501';
  end if;

  select * into v_run
    from hr.payroll_runs r
   where r.id = p_run_id
   for update;
  if not found then
    raise exception 'payroll run not found' using errcode = 'P0002';
  end if;
  if v_run.status <> 'approved' then
    raise exception 'only an approved run can be marked paid' using errcode = '23514';
  end if;

  update hr.payroll_runs
     set status = 'paid',
         paid_by = v_me,
         paid_at = now(),
         note = case when nullif(btrim(coalesce(p_note, '')), '') is null then note
                     else left(btrim(p_note), 500) end
   where id = v_run.id
   returning * into v_run;

  perform identity.audit(
    'hr.payroll.pay',
    'payroll_run', v_run.id,
    jsonb_build_object('status', 'approved'),
    jsonb_build_object(
      'status', 'paid',
      'period_year', v_run.period_year,
      'period_month', v_run.period_month,
      'total_net', v_run.total_net
    ),
    null
  );

  return jsonb_build_object(
    'run_id', v_run.id,
    'status', 'paid',
    'paid_at', v_run.paid_at
  );
end;
$fn$;

comment on function public.admin_hr_pay_payroll(uuid, text) is
  'Records that an approved payroll was paid. It moves no money itself; the '
  'payment happens outside the app and this row is the audited receipt.';

revoke all on function public.admin_hr_pay_payroll(uuid, text)
  from public, anon;
grant execute on function public.admin_hr_pay_payroll(uuid, text)
  to authenticated;

create or replace function public.admin_hr_cancel_payroll_run(
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
  v_prev text;
begin
  v_me := hr.require_permission('hr.payroll.manage');
  if not identity.manages_all_branches() then
    raise exception 'cancelling a payroll run needs all-branch scope'
      using errcode = '42501';
  end if;

  select * into v_run
    from hr.payroll_runs r
   where r.id = p_run_id
   for update;
  if not found then
    raise exception 'payroll run not found' using errcode = 'P0002';
  end if;
  if v_run.status not in ('draft','calculated') then
    raise exception 'only a draft or calculated run can be cancelled'
      using errcode = '23514';
  end if;
  v_prev := v_run.status;

  update hr.payroll_runs
     set status = 'cancelled',
         note = case when nullif(btrim(coalesce(p_note, '')), '') is null then note
                     else left(btrim(p_note), 500) end
   where id = v_run.id
   returning * into v_run;

  update hr.adjustments
     set payroll_run_id = null
   where payroll_run_id = v_run.id;

  perform identity.audit(
    'hr.payroll.cancel',
    'payroll_run', v_run.id,
    jsonb_build_object('status', v_prev),
    jsonb_build_object('status', 'cancelled', 'note', p_note),
    null
  );

  return jsonb_build_object('run_id', v_run.id, 'status', 'cancelled');
end;
$fn$;

revoke all on function public.admin_hr_cancel_payroll_run(uuid, text)
  from public, anon;
grant execute on function public.admin_hr_cancel_payroll_run(uuid, text)
  to authenticated;

create or replace function public.admin_hr_payroll_correction(
  p_statement_id   uuid,
  p_kind           text,
  p_amount         numeric,
  p_reason         text,
  p_effective_date date default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_me uuid;
  v_staff_id uuid;
  v_run_status text;
  v_period_year integer;
  v_period_month integer;
  v_kind text := btrim(coalesce(p_kind, ''));
  v_amount numeric(12,2) := round(coalesce(p_amount, 0), 2);
  v_effective date := coalesce(
    p_effective_date,
    (date_trunc('month', current_date) + interval '1 month')::date
  );
  v_id uuid;
begin
  v_me := hr.require_permission('hr.payroll.manage');

  select st.staff_id, r.status, r.period_year, r.period_month
    into v_staff_id, v_run_status, v_period_year, v_period_month
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

comment on function public.admin_hr_payroll_correction(uuid, text, numeric, text, date) is
  'An approved payslip is a snapshot. A correction is a pending adjustment for '
  'a later period, reviewed like any other adjustment.';

revoke all on function public.admin_hr_payroll_correction(uuid, text, numeric, text, date)
  from public, anon;
grant execute on function public.admin_hr_payroll_correction(uuid, text, numeric, text, date)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 20. Salary advances
-- ---------------------------------------------------------------------------
create or replace function public.hr_request_advance(
  p_amount      numeric,
  p_installment numeric default null,
  p_reason      text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_me uuid;
  v_amount numeric(12,2) := round(coalesce(p_amount, 0), 2);
  v_installment numeric(12,2);
  v_id uuid;
begin
  v_me := hr.require_staff();
  if v_amount <= 0 then
    raise exception 'advance amount must be positive' using errcode = '22023';
  end if;
  if nullif(btrim(coalesce(p_reason, '')), '') is null then
    raise exception 'an advance request needs a reason' using errcode = '22023';
  end if;
  if p_installment is not null then
    v_installment := round(p_installment, 2);
    if v_installment <= 0 or v_installment > v_amount then
      raise exception 'installment must be positive and no larger than the advance'
        using errcode = '22023';
    end if;
  end if;
  if exists (
    select 1 from hr.salary_advances a
     where a.staff_id = v_me
       and a.status in ('pending','approved')
  ) then
    raise exception 'an advance request is already open' using errcode = '23505';
  end if;

  insert into hr.salary_advances (
    staff_id, amount, installment_amount, reason, requested_by
  ) values (
    v_me, v_amount, v_installment, left(btrim(p_reason), 500), v_me
  )
  returning id into v_id;

  perform identity.audit(
    'hr.advance.request', 'salary_advance', v_id,
    null,
    jsonb_build_object('amount', v_amount, 'installment', v_installment),
    null
  );

  return jsonb_build_object(
    'id', v_id,
    'amount', v_amount,
    'installment_amount', v_installment,
    'status', 'pending'
  );
end;
$fn$;

revoke all on function public.hr_request_advance(numeric, numeric, text)
  from public, anon;
grant execute on function public.hr_request_advance(numeric, numeric, text)
  to authenticated;

create or replace function public.admin_hr_advances(
  p_status   text default null,
  p_staff_id uuid default null,
  p_limit    integer default 50
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_me uuid;
  v_can boolean;
  v_status text := nullif(btrim(coalesce(p_status, '')), '');
  v_filter uuid := p_staff_id;
begin
  v_me := hr.require_staff();
  v_can := identity.has_permission('hr.finance.adjust');

  if v_filter is not null then
    if v_filter <> v_me then
      if not v_can then
        raise exception 'missing permission: hr.finance.adjust' using errcode = '42501';
      end if;
      perform hr.assert_staff_access(v_filter);
    end if;
  elsif not v_can then
    v_filter := v_me;
  end if;

  if v_status is not null and v_status not in
     ('pending','approved','rejected','disbursed','settled','cancelled') then
    raise exception 'invalid advance status' using errcode = '22023';
  end if;

  return coalesce((
    select jsonb_agg(row_json order by created_at desc)
    from (
      select
        a.created_at,
        jsonb_build_object(
          'id', a.id,
          'staff_id', a.staff_id,
          'staff_name', sm.full_name,
          'amount', a.amount,
          'installment_amount', a.installment_amount,
          'settled_amount', a.settled_amount,
          'outstanding', round(a.amount - a.settled_amount, 2),
          'currency_code', a.currency_code,
          'reason', a.reason,
          'status', a.status,
          'requested_by', a.requested_by,
          'reviewed_by', a.reviewed_by,
          'reviewed_at', a.reviewed_at,
          'review_note', a.review_note,
          'disbursed_at', a.disbursed_at,
          'created_at', a.created_at
        ) as row_json
      from hr.salary_advances a
      join identity.staff_members sm on sm.id = a.staff_id
      where (v_status is null or a.status = v_status)
        and (
          (v_filter is not null and a.staff_id = v_filter)
          or (v_filter is null and hr.can_access_staff(a.staff_id))
        )
      order by a.created_at desc
      limit greatest(1, least(coalesce(p_limit, 50), 200))
    ) rows
  ), '[]'::jsonb);
end;
$fn$;

revoke all on function public.admin_hr_advances(text, uuid, integer)
  from public, anon;
grant execute on function public.admin_hr_advances(text, uuid, integer)
  to authenticated;

create or replace function public.admin_hr_review_advance(
  p_advance_id  uuid,
  p_approve     boolean,
  p_installment numeric default null,
  p_note        text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_me uuid;
  v_adv hr.salary_advances%rowtype;
  v_outstanding numeric(12,2);
  v_installment numeric(12,2);
  v_note text := left(btrim(coalesce(p_note, '')), 500);
begin
  v_me := hr.require_permission('hr.finance.adjust');

  select * into v_adv
    from hr.salary_advances a
   where a.id = p_advance_id
   for update;
  if not found then
    raise exception 'advance not found' using errcode = 'P0002';
  end if;
  if v_adv.status <> 'pending' then
    raise exception 'this advance is already reviewed' using errcode = '23514';
  end if;
  perform hr.assert_staff_access(v_adv.staff_id);
  if v_adv.requested_by = v_me and not hr.is_owner() then
    raise exception 'you cannot review your own advance request' using errcode = '42501';
  end if;

  v_outstanding := round(v_adv.amount - v_adv.settled_amount, 2);

  if not p_approve then
    update hr.salary_advances
       set status = 'rejected',
           reviewed_by = v_me,
           reviewed_at = now(),
           review_note = v_note
     where id = v_adv.id;

    perform identity.audit(
      'hr.advance.reject', 'salary_advance', v_adv.id,
      jsonb_build_object('status', 'pending'),
      jsonb_build_object('status', 'rejected', 'note', v_note),
      null
    );

    return jsonb_build_object('id', v_adv.id, 'status', 'rejected');
  end if;

  v_installment := round(coalesce(p_installment, v_outstanding), 2);
  if v_installment <= 0 or v_installment > v_outstanding then
    raise exception 'installment must be positive and no larger than the outstanding amount'
      using errcode = '22023';
  end if;

  update hr.salary_advances
     set status = 'approved',
         installment_amount = v_installment,
         reviewed_by = v_me,
         reviewed_at = now(),
         review_note = v_note
   where id = v_adv.id;

  perform identity.audit(
    'hr.advance.approve', 'salary_advance', v_adv.id,
    jsonb_build_object('status', 'pending'),
    jsonb_build_object(
      'status', 'approved',
      'installment_amount', v_installment,
      'note', v_note
    ),
    null
  );

  return jsonb_build_object(
    'id', v_adv.id,
    'status', 'approved',
    'installment_amount', v_installment
  );
end;
$fn$;

revoke all on function public.admin_hr_review_advance(uuid, boolean, numeric, text)
  from public, anon;
grant execute on function public.admin_hr_review_advance(uuid, boolean, numeric, text)
  to authenticated;

create or replace function public.admin_hr_disburse_advance(
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
begin
  v_me := hr.require_permission('hr.finance.adjust');

  select * into v_adv
    from hr.salary_advances a
   where a.id = p_advance_id
   for update;
  if not found then
    raise exception 'advance not found' using errcode = 'P0002';
  end if;
  if v_adv.status <> 'approved' then
    raise exception 'only an approved advance can be disbursed' using errcode = '23514';
  end if;
  perform hr.assert_staff_access(v_adv.staff_id);

  update hr.salary_advances
     set status = 'disbursed',
         disbursed_by = v_me,
         disbursed_at = now(),
         review_note = case when nullif(btrim(coalesce(p_note, '')), '') is null
                            then review_note
                            else left(btrim(p_note), 500) end
   where id = v_adv.id;

  perform identity.audit(
    'hr.advance.disburse', 'salary_advance', v_adv.id,
    jsonb_build_object('status', 'approved'),
    jsonb_build_object('status', 'disbursed', 'amount', v_adv.amount),
    null
  );

  return jsonb_build_object('id', v_adv.id, 'status', 'disbursed');
end;
$fn$;

comment on function public.admin_hr_disburse_advance(uuid, text) is
  'Records that the advance was handed over. Approval alone never settles a '
  'salary: only a disbursed advance is recovered by payroll.';

revoke all on function public.admin_hr_disburse_advance(uuid, text)
  from public, anon;
grant execute on function public.admin_hr_disburse_advance(uuid, text)
  to authenticated;

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

-- ---------------------------------------------------------------------------
-- 21. Adjustments
-- ---------------------------------------------------------------------------
create or replace function public.admin_hr_adjustments(
  p_status      text default null,
  p_staff_id    uuid default null,
  p_source_type text default null,
  p_limit       integer default 60
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_me uuid;
  v_can boolean;
  v_status text := nullif(btrim(coalesce(p_status, '')), '');
  v_source text := nullif(btrim(coalesce(p_source_type, '')), '');
  v_filter uuid := p_staff_id;
begin
  v_me := hr.require_staff();
  v_can := identity.has_permission('hr.finance.adjust')
    or identity.has_permission('hr.payroll.read');

  if v_filter is not null then
    perform hr.assert_staff_access(v_filter);
    if v_filter <> v_me and not v_can then
      raise exception 'missing permission: hr.payroll.read' using errcode = '42501';
    end if;
  elsif not v_can then
    raise exception 'missing permission: hr.payroll.read' using errcode = '42501';
  end if;

  if v_status is not null and v_status not in
     ('pending','approved','rejected','reversed','cancelled') then
    raise exception 'invalid adjustment status' using errcode = '22023';
  end if;
  if v_source is not null and v_source not in
     ('manual','cashier_discrepancy','payroll_correction','adjustment_reversal') then
    raise exception 'invalid adjustment source' using errcode = '22023';
  end if;

  return coalesce((
    select jsonb_agg(row_json order by effective_date desc, created_at desc)
    from (
      select
        a.effective_date,
        a.created_at,
        jsonb_build_object(
          'id', a.id,
          'staff_id', a.staff_id,
          'staff_name', sm.full_name,
          'kind', a.kind,
          'amount', a.amount,
          'quantity', a.quantity,
          'effective_date', a.effective_date,
          'reason', a.reason,
          'status', a.status,
          'source_type', a.source_type,
          'source_id', a.source_id,
          'payroll_run_id', a.payroll_run_id,
          'claimed', a.payroll_run_id is not null,
          'requested_by', a.requested_by,
          'reviewed_by', a.reviewed_by,
          'reviewed_at', a.reviewed_at,
          'review_note', a.review_note,
          'created_at', a.created_at
        ) as row_json
      from hr.adjustments a
      join identity.staff_members sm on sm.id = a.staff_id
      where (v_status is null or a.status = v_status)
        and (v_source is null or a.source_type = v_source)
        and (
          (v_filter is not null and a.staff_id = v_filter)
          or (v_filter is null and hr.can_access_staff(a.staff_id))
        )
      order by a.effective_date desc, a.created_at desc
      limit greatest(1, least(coalesce(p_limit, 60), 200))
    ) rows
  ), '[]'::jsonb);
end;
$fn$;

revoke all on function public.admin_hr_adjustments(text, uuid, text, integer)
  from public, anon;
grant execute on function public.admin_hr_adjustments(text, uuid, text, integer)
  to authenticated;

create or replace function public.admin_hr_create_adjustment(
  p_staff_id       uuid,
  p_kind           text,
  p_amount         numeric,
  p_reason         text,
  p_effective_date date default null,
  p_quantity       numeric default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_me uuid;
  v_kind text := btrim(coalesce(p_kind, ''));
  v_amount numeric(12,2) := round(coalesce(p_amount, 0), 2);
  v_effective date := coalesce(p_effective_date, current_date);
  v_id uuid;
begin
  v_me := hr.require_permission('hr.finance.adjust');
  if p_staff_id is null then
    raise exception 'staff member is required' using errcode = '22023';
  end if;
  perform hr.assert_staff_access(p_staff_id);

  if v_kind not in ('allowance','bonus','commission','overtime','deduction') then
    raise exception 'invalid adjustment kind' using errcode = '22023';
  end if;
  if v_amount <= 0 then
    raise exception 'adjustment amount must be positive' using errcode = '22023';
  end if;
  if nullif(btrim(coalesce(p_reason, '')), '') is null then
    raise exception 'an adjustment needs a reason' using errcode = '22023';
  end if;
  if p_quantity is not null and p_quantity <= 0 then
    raise exception 'quantity must be positive when given' using errcode = '22023';
  end if;

  insert into hr.adjustments (
    staff_id, kind, amount, quantity, effective_date, reason,
    status, source_type, requested_by
  ) values (
    p_staff_id, v_kind, v_amount, p_quantity, v_effective,
    left(btrim(p_reason), 500), 'pending', 'manual', v_me
  )
  returning id into v_id;

  perform identity.audit(
    'hr.adjustment.create', 'adjustment', v_id,
    null,
    jsonb_build_object(
      'staff_id', p_staff_id,
      'kind', v_kind,
      'amount', v_amount,
      'effective_date', v_effective
    ),
    null
  );

  return jsonb_build_object(
    'id', v_id,
    'staff_id', p_staff_id,
    'kind', v_kind,
    'amount', v_amount,
    'status', 'pending',
    'effective_date', v_effective
  );
end;
$fn$;

revoke all on function public.admin_hr_create_adjustment(uuid, text, numeric, text, date, numeric)
  from public, anon;
grant execute on function public.admin_hr_create_adjustment(uuid, text, numeric, text, date, numeric)
  to authenticated;

create or replace function public.admin_hr_review_adjustment(
  p_adjustment_id uuid,
  p_approve       boolean,
  p_note          text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_me uuid;
  v_adj hr.adjustments%rowtype;
  v_note text := left(btrim(coalesce(p_note, '')), 500);
begin
  v_me := hr.require_permission('hr.finance.adjust');

  select * into v_adj
    from hr.adjustments a
   where a.id = p_adjustment_id
   for update;
  if not found then
    raise exception 'adjustment not found' using errcode = 'P0002';
  end if;
  if v_adj.status <> 'pending' then
    raise exception 'this adjustment is already reviewed' using errcode = '23514';
  end if;
  perform hr.assert_staff_access(v_adj.staff_id);
  if v_adj.requested_by = v_me and not hr.is_owner() then
    raise exception 'you cannot approve your own adjustment' using errcode = '42501';
  end if;

  if not p_approve then
    update hr.adjustments
       set status = 'rejected',
           reviewed_by = v_me,
           reviewed_at = now(),
           review_note = v_note
     where id = v_adj.id;

    perform identity.audit(
      'hr.adjustment.reject', 'adjustment', v_adj.id,
      jsonb_build_object('status', 'pending'),
      jsonb_build_object('status', 'rejected', 'note', v_note),
      null
    );

    return jsonb_build_object('id', v_adj.id, 'status', 'rejected');
  end if;

  if v_adj.payroll_run_id is not null then
    raise exception 'this adjustment is already part of a payroll run'
      using errcode = '23514';
  end if;

  update hr.adjustments
     set status = 'approved',
         reviewed_by = v_me,
         reviewed_at = now(),
         review_note = v_note
   where id = v_adj.id;

  perform identity.audit(
    'hr.adjustment.approve', 'adjustment', v_adj.id,
    jsonb_build_object('status', 'pending'),
    jsonb_build_object(
      'status', 'approved',
      'kind', v_adj.kind,
      'amount', v_adj.amount,
      'note', v_note
    ),
    null
  );

  return jsonb_build_object('id', v_adj.id, 'status', 'approved');
end;
$fn$;

revoke all on function public.admin_hr_review_adjustment(uuid, boolean, text)
  from public, anon;
grant execute on function public.admin_hr_review_adjustment(uuid, boolean, text)
  to authenticated;

create or replace function public.admin_hr_reverse_adjustment(
  p_adjustment_id uuid,
  p_reason        text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_me uuid;
  v_adj hr.adjustments%rowtype;
  v_reason text := left(btrim(coalesce(p_reason, '')), 500);
begin
  v_me := hr.require_permission('hr.finance.adjust');
  if v_reason = '' then
    raise exception 'a reversal needs a reason' using errcode = '22023';
  end if;

  select * into v_adj
    from hr.adjustments a
   where a.id = p_adjustment_id
   for update;
  if not found then
    raise exception 'adjustment not found' using errcode = 'P0002';
  end if;
  if v_adj.status <> 'approved' then
    raise exception 'only an approved adjustment can be reversed' using errcode = '23514';
  end if;
  if v_adj.payroll_run_id is not null then
    raise exception 'this adjustment is already in a payroll snapshot; create a correction'
      using errcode = '23514';
  end if;
  perform hr.assert_staff_access(v_adj.staff_id);

  update hr.adjustments
     set status = 'reversed',
         review_note = v_reason
   where id = v_adj.id;

  perform identity.audit(
    'hr.adjustment.reverse', 'adjustment', v_adj.id,
    jsonb_build_object('status', 'approved'),
    jsonb_build_object('status', 'reversed', 'reason', v_reason),
    null
  );

  return jsonb_build_object('id', v_adj.id, 'status', 'reversed');
end;
$fn$;

revoke all on function public.admin_hr_reverse_adjustment(uuid, text)
  from public, anon;
grant execute on function public.admin_hr_reverse_adjustment(uuid, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 22. Cashier discrepancies: review first, deduction only on evidence
-- ---------------------------------------------------------------------------
create or replace function hr.discrepancy_json(p_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $fn$
  select jsonb_build_object(
    'id', d.id,
    'shift_id', d.shift_id,
    'branch_id', d.branch_id,
    'branch_name_ar', b.name_ar,
    'branch_name_en', b.name_en,
    'drawer_cashier_id', d.drawer_cashier_id,
    'drawer_cashier_name', drawer.full_name,
    'attributed_staff_id', d.attributed_staff_id,
    'attributed_staff_name', attributed.full_name,
    'signed_variance', d.signed_variance,
    'amount', d.amount,
    'currency_code', d.currency_code,
    'status', d.status,
    'review_note', d.review_note,
    'evidence', d.evidence,
    'reviewed_by', d.reviewed_by,
    'reviewer_name', reviewer.full_name,
    'reviewed_at', d.reviewed_at,
    'created_at', d.created_at,
    'shift', jsonb_build_object(
      'opened_at', s.opened_at,
      'closed_at', s.closed_at,
      'opened_at_local', hr.fmt_ts(s.opened_at),
      'closed_at_local', hr.fmt_ts(s.closed_at),
      'expected_cash', s.expected_cash,
      'counted_cash', s.counted_cash
    ),
    'deduction_adjustment_id', (
      select a.id
        from hr.adjustments a
       where a.source_type = 'cashier_discrepancy'
         and a.source_id = d.id
       limit 1
    )
  )
  from hr.cashier_discrepancies d
  left join core.branches b on b.id = d.branch_id
  left join identity.staff_members drawer on drawer.id = d.drawer_cashier_id
  left join identity.staff_members attributed on attributed.id = d.attributed_staff_id
  left join identity.staff_members reviewer on reviewer.id = d.reviewed_by
  left join payments.pos_shifts s on s.id = d.shift_id
  where d.id = p_id;
$fn$;

revoke all on function hr.discrepancy_json(uuid)
  from public, anon, authenticated;

create or replace function public.admin_hr_discrepancies(
  p_status    text default null,
  p_branch_id uuid default null,
  p_limit     integer default 60
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_status text := nullif(btrim(coalesce(p_status, '')), '');
begin
  perform hr.require_permission('hr.finance.adjust');

  if p_branch_id is not null and not identity.can_manage_branch(p_branch_id) then
    raise exception 'branch out of scope' using errcode = '42501';
  end if;
  if v_status is not null and v_status not in
     ('pending_review','explained','reconciliation_required','confirmed',
      'rejected','deduction_approved','closed') then
    raise exception 'invalid discrepancy status' using errcode = '22023';
  end if;

  return coalesce((
    select jsonb_agg(hr.discrepancy_json(d.id) order by d.created_at desc)
    from (
      select d.id, d.created_at
        from hr.cashier_discrepancies d
       where (v_status is null or d.status = v_status)
         and identity.can_manage_branch(d.branch_id)
         and (p_branch_id is null or d.branch_id = p_branch_id)
       order by d.created_at desc
       limit greatest(1, least(coalesce(p_limit, 60), 200))
    ) d
  ), '[]'::jsonb);
end;
$fn$;

revoke all on function public.admin_hr_discrepancies(text, uuid, integer)
  from public, anon;
grant execute on function public.admin_hr_discrepancies(text, uuid, integer)
  to authenticated;

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

-- ---------------------------------------------------------------------------
-- 23. HR dashboard
-- ---------------------------------------------------------------------------
create or replace function hr.scoped_staff(p_branch_id uuid)
returns table (staff_id uuid)
language sql
stable
security definer
set search_path = ''
as $fn$
  select sm.id
    from identity.staff_members sm
   where sm.status = 'active'
     and hr.can_access_staff(sm.id)
     and (
       p_branch_id is null
       or exists (
         select 1
           from identity.staff_roles sr
          where sr.staff_id = sm.id
            and sr.branch_id = p_branch_id
       )
     );
$fn$;

revoke all on function hr.scoped_staff(uuid)
  from public, anon, authenticated;

create or replace function public.admin_hr_dashboard(p_branch_id uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_me uuid;
  v_tz text;
  v_today date;
  v_can_hr boolean;
  v_can_attendance boolean;
  v_can_schedule boolean;
  v_can_leave boolean;
  v_can_finance boolean;
  v_can_payroll boolean;
  v_can_compensation boolean;
  v_grace integer;
begin
  v_me := hr.require_staff();
  v_tz := hr.business_time_zone();
  v_today := (now() at time zone v_tz)::date;

  if p_branch_id is not null and not identity.can_manage_branch(p_branch_id) then
    raise exception 'branch out of scope' using errcode = '42501';
  end if;

  v_can_hr := identity.has_permission('hr.employee.read')
    or identity.has_permission('hr.employee.write');
  v_can_attendance := identity.has_permission('hr.attendance.read')
    or identity.has_permission('hr.attendance.manage');
  v_can_schedule := identity.has_permission('hr.schedule.read')
    or identity.has_permission('hr.schedule.manage');
  v_can_leave := identity.has_permission('hr.leave.review');
  v_can_finance := identity.has_permission('hr.finance.adjust');
  v_can_payroll := identity.has_permission('hr.payroll.read');
  v_can_compensation := identity.has_permission('hr.compensation.manage');
  v_grace := coalesce((select s.late_grace_minutes from hr.settings s where s.id = 1), 0);

  return jsonb_build_object(
    'today', to_char(v_today, 'YYYY-MM-DD'),
    'time_zone', v_tz,
    'permissions', jsonb_build_object(
      'hr', v_can_hr,
      'attendance', v_can_attendance,
      'schedule', v_can_schedule,
      'leave_review', v_can_leave,
      'finance', v_can_finance,
      'payroll', v_can_payroll,
      'compensation', v_can_compensation
    ),
    'headcount', jsonb_build_object(
      'total', (
        select count(*) from hr.scoped_staff(p_branch_id) s
      ),
      'active', (
        select count(*)
          from hr.scoped_staff(p_branch_id) s
          join hr.employment_records e on e.staff_id = s.staff_id
         where coalesce(e.employment_status, 'active') = 'active'
      ),
      'probation', (
        select count(*)
          from hr.scoped_staff(p_branch_id) s
          join hr.employment_records e on e.staff_id = s.staff_id
         where e.employment_status = 'probation'
      ),
      'on_leave', (
        select count(*)
          from hr.scoped_staff(p_branch_id) s
          join hr.employment_records e on e.staff_id = s.staff_id
         where e.employment_status = 'on_leave'
      ),
      'terminated', (
        select count(*)
          from hr.scoped_staff(p_branch_id) s
          join hr.employment_records e on e.staff_id = s.staff_id
         where e.employment_status = 'terminated'
      )
    ),
    'today_attendance', case when not v_can_attendance then null
      else jsonb_build_object(
        'scheduled', (
          select count(*)
            from hr.work_schedules ws
           where ws.status = 'published'
             and ws.staff_id in (select staff_id from hr.scoped_staff(p_branch_id))
             and (ws.scheduled_start at time zone v_tz)::date = v_today
        ),
        'present', (
          select count(distinct a.staff_id)
            from hr.attendance_sessions a
           where a.staff_id in (select staff_id from hr.scoped_staff(p_branch_id))
             and (a.clock_in at time zone v_tz)::date = v_today
        ),
        'open', (
          select count(*)
            from hr.attendance_sessions a
           where a.clock_out is null
             and a.staff_id in (select staff_id from hr.scoped_staff(p_branch_id))
        ),
        'late', (
          select count(distinct a.staff_id)
            from hr.attendance_sessions a
            join hr.work_schedules ws
              on ws.staff_id = a.staff_id
             and ws.status = 'published'
             and (ws.scheduled_start at time zone v_tz)::date = v_today
           where a.staff_id in (select staff_id from hr.scoped_staff(p_branch_id))
             and (a.clock_in at time zone v_tz)::date = v_today
             and a.clock_in > ws.scheduled_start + make_interval(mins => v_grace)
        ),
        'on_leave', (
          select count(distinct l.staff_id)
            from hr.leave_requests l
           where l.status = 'approved'
             and v_today between l.starts_on and l.ends_on
             and l.staff_id in (select staff_id from hr.scoped_staff(p_branch_id))
        )
      )
    end,
    'pending', jsonb_build_object(
      'leave_requests', case when v_can_leave then (
        select count(*) from hr.leave_requests l
         where l.status = 'pending'
           and l.staff_id in (select staff_id from hr.scoped_staff(p_branch_id))
      ) else null end,
      'attendance_corrections', case when v_can_attendance then (
        select count(*) from hr.attendance_corrections c
         where c.status = 'pending'
           and c.staff_id in (select staff_id from hr.scoped_staff(p_branch_id))
      ) else null end,
      'advances', case when v_can_finance then (
        select count(*) from hr.salary_advances a
         where a.status = 'pending'
           and a.staff_id in (select staff_id from hr.scoped_staff(p_branch_id))
      ) else null end,
      'adjustments', case when v_can_finance then (
        select count(*) from hr.adjustments a
         where a.status = 'pending'
           and a.staff_id in (select staff_id from hr.scoped_staff(p_branch_id))
      ) else null end,
      'discrepancies', case when v_can_finance then (
        select count(*) from hr.cashier_discrepancies d
         where d.status = 'pending_review'
           and identity.can_manage_branch(d.branch_id)
      ) else null end
    ),
    'finance', case when not (v_can_finance or v_can_payroll) then null
      else jsonb_build_object(
        'open_discrepancies', case when v_can_finance then (
          select count(*) from hr.cashier_discrepancies d
           where d.status not in ('closed','rejected')
             and identity.can_manage_branch(d.branch_id)
        ) else null end,
        'open_discrepancy_amount', case when v_can_finance then (
          select coalesce(sum(d.amount), 0) from hr.cashier_discrepancies d
           where d.status not in ('closed','rejected')
             and identity.can_manage_branch(d.branch_id)
        ) else null end,
        'advances_outstanding', case when v_can_finance then (
          select coalesce(sum(a.amount - a.settled_amount), 0)
            from hr.salary_advances a
           where a.status = 'disbursed'
             and a.staff_id in (select staff_id from hr.scoped_staff(p_branch_id))
        ) else null end
      )
    end,
    'payroll', case when not v_can_payroll then null
      else jsonb_build_object(
        'period_year', extract(year from current_date)::integer,
        'period_month', extract(month from current_date)::integer,
        'run', (
          select jsonb_build_object(
            'run_id', r.id,
            'status', r.status,
            'total_net', r.total_net,
            'statement_count', r.statement_count
          )
          from hr.payroll_runs r
          where r.period_year = extract(year from current_date)::integer
            and r.period_month = extract(month from current_date)::integer
        )
      )
    end,
    'me', jsonb_build_object(
      'staff_id', v_me,
      'open_session', (
        select jsonb_build_object(
          'id', a.id,
          'branch_id', a.branch_id,
          'clock_in', a.clock_in,
          'clock_in_local', hr.fmt_ts(a.clock_in),
          'on_break', a.break_started_at is not null and a.break_ended_at is null
        )
        from hr.attendance_sessions a
        where a.staff_id = v_me
          and a.clock_out is null
        order by a.clock_in desc
        limit 1
      ),
      'worked_minutes_today', coalesce((
        select sum(
          greatest(
            0,
            floor(extract(epoch from (coalesce(a.clock_out, now()) - a.clock_in)) / 60)::integer
            - coalesce(
                floor(extract(epoch from (a.break_ended_at - a.break_started_at)) / 60)::integer,
                0
              )
          )
        )
        from hr.attendance_sessions a
        where a.staff_id = v_me
          and (a.clock_in at time zone v_tz)::date = v_today
      ), 0),
      'pending_leave', (
        select count(*) from hr.leave_requests l
         where l.staff_id = v_me and l.status = 'pending'
      ),
      'open_advance', (
        select count(*) from hr.salary_advances a
         where a.staff_id = v_me and a.status in ('pending','approved')
      ),
      'latest_payslip', (
        select jsonb_build_object(
          'statement_id', st.id,
          'period_year', r.period_year,
          'period_month', r.period_month,
          'net', st.net,
          'currency_code', st.currency_code
        )
        from hr.payroll_statements st
        join hr.payroll_runs r on r.id = st.run_id
        where st.staff_id = v_me
          and r.status in ('approved','paid')
        order by r.period_year desc, r.period_month desc
        limit 1
      )
    )
  );
end;
$fn$;

comment on function public.admin_hr_dashboard(uuid) is
  'Counts and today figures for the branches the caller may access. Money '
  'fields are null without finance or payroll permission.';

revoke all on function public.admin_hr_dashboard(uuid)
  from public, anon;
grant execute on function public.admin_hr_dashboard(uuid)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 24. HR policy and leave types
-- ---------------------------------------------------------------------------
create or replace function public.admin_hr_update_settings(
  p_business_time_zone          text default null,
  p_late_grace_minutes          integer default null,
  p_late_minute_rate            numeric default null,
  p_early_minute_rate           numeric default null,
  p_absence_day_rate            numeric default null,
  p_cashier_deduction_allowed   boolean default null,
  p_max_salary_deduction_percent numeric default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
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

  update hr.settings
     set business_time_zone = v_tz,
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
      'max_salary_deduction_percent', v_old.max_salary_deduction_percent
    ),
    jsonb_build_object(
      'business_time_zone', v_tz,
      'late_grace_minutes', v_grace,
      'late_minute_rate', v_late,
      'early_minute_rate', v_early,
      'absence_day_rate', v_absence,
      'cashier_deduction_allowed', v_allowed,
      'max_salary_deduction_percent', v_percent
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
    'max_salary_deduction_percent', v_percent
  );
end;
$fn$;

revoke all on function public.admin_hr_update_settings(
  text, integer, numeric, numeric, numeric, boolean, numeric
) from public, anon;
grant execute on function public.admin_hr_update_settings(
  text, integer, numeric, numeric, numeric, boolean, numeric
) to authenticated;

-- Standard types, no entitlement baked in: a balance-tracking type starts at
-- whatever the owner enters per employee and year.
insert into hr.leave_types (
  code, name_ar, name_en, requires_document, is_paid, tracks_balance
) values
  ('annual',  'إجازة سنوية',      'Annual leave',  false, true,  true),
  ('sick',    'إجازة مرضية',      'Sick leave',    true,  true,  false),
  ('unpaid',  'إجازة بدون راتب',  'Unpaid leave',  false, false, false)
on conflict (code) do nothing;

create or replace function public.admin_hr_save_leave_type(
  p_id                  uuid default null,
  p_code                text default null,
  p_name_ar             text default null,
  p_name_en             text default null,
  p_requires_document   boolean default false,
  p_is_paid             boolean default true,
  p_tracks_balance      boolean default false,
  p_default_annual_days numeric default null,
  p_is_active           boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_me uuid;
  v_code text := lower(btrim(coalesce(p_code, '')));
  v_name_ar text := left(btrim(coalesce(p_name_ar, '')), 120);
  v_name_en text := left(btrim(coalesce(p_name_en, '')), 120);
  v_id uuid;
  v_old hr.leave_types%rowtype;
begin
  v_me := hr.require_permission('hr.settings.manage');
  if p_default_annual_days is not null and p_default_annual_days < 0 then
    raise exception 'default annual days cannot be negative' using errcode = '22023';
  end if;

  if p_id is null then
    if v_code !~ '^[a-z_]+$' then
      raise exception 'leave type code must be lowercase letters and underscores'
        using errcode = '22023';
    end if;
    if v_name_ar = '' or v_name_en = '' then
      raise exception 'both names are required' using errcode = '22023';
    end if;

    insert into hr.leave_types (
      code, name_ar, name_en, requires_document, is_paid,
      tracks_balance, default_annual_days, is_active
    ) values (
      v_code, v_name_ar, v_name_en, coalesce(p_requires_document, false),
      coalesce(p_is_paid, true), coalesce(p_tracks_balance, false),
      p_default_annual_days, coalesce(p_is_active, true)
    )
    returning id into v_id;
  else
    select * into v_old from hr.leave_types t where t.id = p_id for update;
    if not found then
      raise exception 'leave type not found' using errcode = 'P0002';
    end if;
    if v_name_ar = '' or v_name_en = '' then
      raise exception 'both names are required' using errcode = '22023';
    end if;

    update hr.leave_types
       set name_ar = v_name_ar,
           name_en = v_name_en,
           requires_document = coalesce(p_requires_document, requires_document),
           is_paid = coalesce(p_is_paid, is_paid),
           tracks_balance = coalesce(p_tracks_balance, tracks_balance),
           default_annual_days = p_default_annual_days,
           is_active = coalesce(p_is_active, is_active)
     where id = p_id
     returning id into v_id;
  end if;

  perform identity.audit(
    'hr.leave_type.save',
    'leave_type', v_id,
    case when v_old.id is null then null else jsonb_build_object(
      'name_ar', v_old.name_ar,
      'name_en', v_old.name_en,
      'is_active', v_old.is_active
    ) end,
    jsonb_build_object(
      'name_ar', v_name_ar,
      'name_en', v_name_en,
      'is_active', coalesce(p_is_active, true)
    ),
    null
  );

  return jsonb_build_object('id', v_id, 'code', coalesce(nullif(v_code, ''), v_old.code));
end;
$fn$;

revoke all on function public.admin_hr_save_leave_type(
  uuid, text, text, text, boolean, boolean, boolean, numeric, boolean
) from public, anon;
grant execute on function public.admin_hr_save_leave_type(
  uuid, text, text, text, boolean, boolean, boolean, numeric, boolean
) to authenticated;

-- ---------------------------------------------------------------------------
-- 25. HR permissions
-- ---------------------------------------------------------------------------
insert into identity.permissions (code, name_ar, name_en, description) values
  ('hr.employee.read',
   'عرض ملفات الموظفين',
   'View employee files',
   'Open the employee directory and read employment files in scope.'),
  ('hr.employee.write',
   'تعديل ملفات الموظفين',
   'Edit employee files',
   'Maintain employment details, department, job title and status.'),
  ('hr.attendance.read',
   'عرض الحضور',
   'View attendance',
   'See clock-in, clock-out and daily attendance for staff in scope.'),
  ('hr.attendance.manage',
   'إدارة الحضور',
   'Manage attendance',
   'Review and approve attendance corrections for staff in scope.'),
  ('hr.attendance.correction',
   'طلب تصحيح حضور',
   'Request attendance correction',
   'Submit an attendance correction on behalf of another employee.'),
  ('hr.schedule.read',
   'عرض الجدول',
   'View schedules',
   'See draft and published work schedules in scope.'),
  ('hr.schedule.manage',
   'إدارة الجدول',
   'Manage schedules',
   'Create, publish and cancel work schedules.'),
  ('hr.leave.review',
   'مراجعة الإجازات',
   'Review leave',
   'Approve or reject leave requests and set yearly entitlements.'),
  ('hr.compensation.manage',
   'إدارة الرواتب الأساسية',
   'Manage compensation',
   'Add effective-dated salary records for staff in scope.'),
  ('hr.payroll.read',
   'عرض الرواتب',
   'View payroll',
   'Read payroll runs and payslips for staff in scope.'),
  ('hr.payroll.manage',
   'احتساب الرواتب',
   'Calculate payroll',
   'Generate, recalculate and cancel payroll runs.'),
  ('hr.payroll.approve',
   'اعتماد الرواتب',
   'Approve payroll',
   'Approve a calculated payroll run.'),
  ('hr.payroll.pay',
   'تسجيل صرف الرواتب',
   'Record payroll payment',
   'Mark an approved payroll run as paid.'),
  ('hr.finance.adjust',
   'التسويات المالية للموظفين',
   'Employee finance adjustments',
   'Review advances, adjustments and cashier discrepancies.'),
  ('hr.settings.manage',
   'إعدادات الموارد البشرية',
   'Manage HR settings',
   'Edit HR policy rates, leave types and the business time zone.')
on conflict (code) do update
  set name_ar = excluded.name_ar,
      name_en = excluded.name_en,
      description = excluded.description;

insert into identity.role_permissions (role_id, permission_id)
select r.id, p.id
  from identity.roles r
  join identity.permissions p on p.code in (
    'hr.employee.read', 'hr.employee.write',
    'hr.attendance.read', 'hr.attendance.manage', 'hr.attendance.correction',
    'hr.schedule.read', 'hr.schedule.manage', 'hr.leave.review',
    'hr.compensation.manage', 'hr.payroll.read', 'hr.payroll.manage',
    'hr.finance.adjust', 'hr.settings.manage'
  )
 where r.code = 'manager'
on conflict do nothing;

insert into identity.role_permissions (role_id, permission_id)
select r.id, p.id
  from identity.roles r
  join identity.permissions p on p.code in (
    'hr.employee.read', 'hr.employee.write',
    'hr.attendance.read', 'hr.attendance.manage', 'hr.attendance.correction',
    'hr.schedule.read', 'hr.schedule.manage', 'hr.leave.review',
    'hr.finance.adjust'
  )
 where r.code = 'branch_manager'
on conflict do nothing;

-- Payroll approval and payment stay with the owner (owner short-circuits
-- identity.has_permission) until a role is explicitly given those codes.

-- ---------------------------------------------------------------------------
-- 26. Audit visibility
-- ---------------------------------------------------------------------------
-- Payroll, salary, advance, adjustment and discrepancy actions join the
-- critical list so the audit screen marks them without a client change.
create or replace function identity.audit_is_critical(p_action text)
returns boolean
language sql
immutable
set search_path = ''
as $fn$
  select p_action like '%.delete'
      or split_part(p_action, '.', 1) in ('permission', 'role')
      or p_action in (
        'staff.provision',
        'stock.adjust',
        'core.branch.deactivate'
      )
      or p_action like 'hr.payroll.%'
      or p_action like 'hr.compensation.%'
      or p_action like 'hr.advance.%'
      or p_action like 'hr.adjustment.%'
      or p_action like 'hr.discrepancy.%'
      or p_action like 'hr.leave.balance.%';
$fn$;

comment on function identity.audit_is_critical(text) is
  'True for destructive, access-related, stock-changing and HR money actions.';

revoke all on function identity.audit_is_critical(text) from public;

notify pgrst, 'reload schema';