-- 209_hr_payroll_and_advances.sql
-- HR Module Phase 4: Payroll Calculation & Salary Advances
-- Entities: compensation_history, payroll_runs, payroll_lines, salary_advances

-- Compensation history (audit trail for base salary changes)
create table hr.compensation_history (
    id uuid primary key default gen_random_uuid(),
    staff_id uuid not null references identity.staff_members(id) on delete cascade,
    
    // Effective period
    effective_from date not null,
    effective_to date,
    
    // Compensation details
    base_salary numeric(12,3) not null,
    currency_code text not null default 'SAR' check (currency_code = 'SAR'),
    pay_period text not null default 'monthly' 
        check (pay_period in ('monthly', 'weekly', 'daily')),
    
    allowances numeric(12,3) not null default 0,
    other_additions numeric(12,3) not null default 0,
    
    metadata jsonb not null default '{}'::jsonb,
    
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    created_by uuid references auth.users(id),
    
    constraint hr_comp_period_check check (effective_to is null or effective_to >= effective_from),
    constraint hr_comp_active_dates overlap check (
        effective_to is null or effective_to >= now()::date
    ),
    constraint hr_comp_salary_positive check (base_salary >= 0),
    constraint hr_comp_allowance_positive check (allowances >= 0)
);

// Create unique constraint for active compensation record
create unique index hr_compensation_active_idx on hr.compensation_history (staff_id, effective_from)
    where effective_to is null;

// Payroll runs (header for each pay period)
create type hr.payroll_status as enum (
    'draft', 'pending_approval', 'approved', 'cancelled', 'paid'
);

create table hr.payroll_runs (
    id uuid primary key default gen_random_uuid(),
    branch_id uuid not null references core.branches(id) on delete cascade,
    
    // Period details
    payroll_period text not null, -- Format: YYYY-MM
    period_start date not null,
    period_end date not null,
    
    // Status tracking
    status hr.payroll_status not null default 'draft',
    
    // Calculation snapshot
    calculated_by uuid references auth.users(id),
    calculation_date timestamptz not null default now(),
    
    // Approval workflow
    approved_by uuid references auth.users(id),
    approval_date timestamptz,
    
    // Total amounts (summary for reference)
    total_gross_amount numeric(15,3),
    total_deductions numeric(15,3),
    total_net_amount numeric(15,3),
    
    // Payment status
    payment_status text not null default 'not_paid'
        check (payment_status in ('not_paid', 'scheduled', 'paid', 'failed')),
    payment_date timestamptz,
    
    version text not null default '1.0',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    
    constraint hr_payroll_period_format check (payroll_period ~ '^\d{4}-\d{2}$'),
    constraint hr_payroll_dates_check check (period_end >= period_start),
    constraint hr_payroll_unique_period_branch unique (branch_id, payroll_period),
    constraint hr_payroll_totals_nonnegative check (
        total_net_amount >= 0 and total_gross_amount >= 0 and total_deductions >= 0
    )
);

// Indexes for payroll performance
create index hr_payroll_runs_period_idx on hr.payroll_runs(branch_id, payroll_period);
create index hr_payroll_runs_status_idx on hr.payroll_runs(status);

// Payroll lines (individual employee payroll entries)
create table hr.payroll_lines (
    id uuid primary key default gen_random_uuid(),
    payroll_run_id uuid not null references hr.payroll_runs(id) on delete cascade,
    staff_id uuid not null references identity.staff_members(id) on delete cascade,
    
    // Snapshot of employment data at calculation time
    base_salary numeric(12,3) not null,
    currency_code text not null default 'SAR',
    
    // Calculated components
    gross_amount numeric(15,3) not null,
    
    // Additions
    attendance_adjustment numeric(15,3) not null default 0,
    overtime_amount numeric(15,3) not null default 0,
    bonus_amount numeric(15,3) not null default 0,
    allowance_amount numeric(15,3) not null default 0,
    other_additions numeric(15,3) not null default 0,
    
    // Deductions
    advance_repayment numeric(15,3) not null default 0,
    shortage_deduction numeric(15,3) not null default 0,
    tax_amount numeric(15,3) not null default 0,
    other_deductions numeric(15,3) not null default 0,
    total_deductions numeric(15,3) not null default 0,
    
    // Final net amount
    net_payable numeric(15,3) not null,
    
    // Source references (for audit)
    source_documents jsonb not null default '{}'::jsonb,
    
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    
    constraint hr_payroll_line_positive check (gross_amount >= 0 and net_payable >= 0),
    constraint hr_payroll_line_deduction_limit check (total_deductions >= 0)
);

// Salary advances
create type hr.advance_status as enum (
    'pending', 'approved', 'rejected', 'disbursed', 'partially_repaid', 'fully_repaid', 'written_off'
);

create table hr.salary_advances (
    id uuid primary key default gen_random_uuid(),
    staff_id uuid not null references identity.staff_members(id) on delete cascade,
    branch_id uuid not null references core.branches(id) on delete cascade,
    
    // Request details
    amount numeric(12,3) not null,
    currency_code text not null default 'SAR' check (currency_code = 'SAR'),
    purpose text not null,
    
    // Disbursement
    disbursed boolean not null default false,
    disbursement_date timestamptz,
    disbursed_by uuid references auth.users(id),
    
    // Repayment tracking
    repaid_amount numeric(12,3) not null default 0,
    remaining_balance numeric(12,3) not null default 0,
    repayment_schedule jsonb, -- Array of {due_date, amount, paid} objects
    
    requested_by uuid not null references auth.users(id),
    request_date timestamptz not null default now(),
    
    reviewed_by uuid references auth.users(id),
    review_date timestamptz,
    status hr.advance_status not null default 'pending',
    rejection_reason text,
    
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    
    constraint hr_advance_amount_positive check (amount > 0),
    constraint hr_advance_repayment_limit check (repaid_amount <= amount),
    constraint hr_advance_balance_nonnegative check (remaining_balance >= 0)
);

// Indexes
create index hr_compensation_staff_idx on hr.compensation_history(staff_id);
create index hr_payroll_lines_payroll_idx on hr.payroll_lines(payroll_run_id);
create index hr_payroll_lines_staff_idx on hr.payroll_lines(staff_id);
create index hr_salary_advances_staff_idx on hr.salary_advances(staff_id);
create index hr_salary_advances_status_idx on hr.salary_advances(status);
create index hr_salary_advances_outstanding_idx on hr.salary_advances(remaining_balance)
    where remaining_balance > 0;

// RLS policies
alter table hr.compensation_history enable row level security;
alter table hr.payroll_runs enable row level security;
alter table hr.payroll_lines enable row level security;
alter table hr.salary_advances enable row level security;

// Compensation history: readable by HR + staff own
create policy hr_comp_read
    on hr.compensation_history for select
    using (
        staff_id = (select id from identity.staff_members where user_id = auth.uid())
        or exists (
            select 1 from identity.staff_members sm
            join identity.role_permissions rp on rp.staff_member_id = sm.id
            join identity.permissions p on p.id = rp.permission_id
            where sm.user_id = auth.uid()
            and p.code in ('admin.branch.write', 'hr.payroll.read', 'hr.compensation.manage')
        )
    );

create policy hr_comp_write
    on hr.compensation_history for insert
    with check (
        exists (
            select 1 from identity.staff_members sm
            join identity.role_permissions rp on rp.staff_member_id = sm.id
            join identity.permissions p on p.id = rp.permission_id
            where sm.user_id = auth.uid()
            and p.code in ('admin.branch.write', 'hr.compensation.manage')
        )
    );

// Payroll runs: only payroll approvers can see
create policy hr_payroll_run_read
    on hr.payroll_runs for select
    using (
        exists (
            select 1 from identity.staff_members sm
            join identity.role_permissions rp on rp.staff_member_id = sm.id
            join identity.permissions p on p.id = rp.permission_id
            where sm.user_id = auth.uid()
            and p.code in ('admin.branch.write', 'hr.payroll.approve', 'hr.payroll.read')
        )
    );

create policy hr_payroll_run_write
    on hr.payroll_runs for insert
    with check (
        exists (
            select 1 from identity.staff_members sm
            join identity.role_permissions rp on rp.staff_member_id = sm.id
            join identity.permissions p on p.id = rp.permission_id
            where sm.user_id = auth.uid()
            and p.code in ('admin.branch.write', 'hr.payroll.calculate')
        )
    );

create policy hr_payroll_run_update
    on hr.payroll_runs for update
    using (
        exists (
            select 1 from identity.staff_members sm
            join identity.role_permissions rp on rp.staff_member_id = sm.id
            join identity.permissions p on p.id = rp.permission_id
            where sm.user_id = auth.uid()
            and p.code in ('admin.branch.write', 'hr.payroll.approve', 'hr.payroll.calculate')
        )
    );

// Payroll lines: same access as payroll runs
create policy hr_payroll_line_read
    on hr.payroll_lines for select
    using (
        exists (
            select 1 from identity.staff_members sm
            join identity.role_permissions rp on rp.staff_member_id = sm.id
            join identity.permissions p on p.id = rp.permission_id
            where sm.user_id = auth.uid()
            and p.code in ('admin.branch.write', 'hr.payroll.approve', 'hr.payroll.read')
        )
    );

create policy hr_payroll_line_write
    on hr.payroll_lines for insert
    with check (
        exists (
            select 1 from identity.staff_members sm
            join identity.role_permissions rp on rp.staff_member_id = sm.id
            join identity.permissions p on p.id = rp.permission_id
            where sm.user_id = auth.uid()
            and p.code in ('admin.branch.write', 'hr.payroll.calculate')
        )
    );

// Salary advances: self + HR
create policy hr_advance_read
    on hr.salary_advances for select
    using (
        staff_id = (select id from identity.staff_members where user_id = auth.uid())
        or exists (
            select 1 from identity.staff_members sm
            join identity.role_permissions rp on rp.staff_member_id = sm.id
            join identity.permissions p on p.id = rp.permission_id
            where sm.user_id = auth.uid()
            and p.code in ('admin.branch.write', 'hr.payroll.read', 'hr.financial.adjust')
        )
    );

create policy hr_advance_write
    on hr.salary_advances for insert
    with check (
        exists (
            select 1 from identity.staff_members sm
            join identity.role_permissions rp on rp.staff_member_id = sm.id
            join identity.permissions p on p.id = rp.permission_id
            where sm.user_id = auth.uid()
            and p.code in ('admin.branch.write', 'hr.financial.adjust')
        )
    );

create policy hr_advance_update
    on hr.salary_advances for update
    using (
        exists (
            select 1 from identity.staff_members sm
            join identity.role_permissions rp on rp.staff_member_id = sm.id
            join identity.permissions p on p.id = rp.permission_id
            where sm.user_id = auth.uid()
            and p.code in ('admin.branch.write', 'hr.financial.adjust', 'hr.payroll.approve')
        )
    );

// Grants
grant usage on schema hr to authenticated;
grant select, insert, update, delete on hr.compensation_history to authenticated;
grant select, insert, update, delete on hr.payroll_runs to authenticated;
grant select, insert, update, delete on hr.payroll_lines to authenticated;
grant select, insert, update, delete on hr.salary_advances to authenticated;

// Helper functions
create or replace function hr.get_current_compensation(p_staff_id uuid)
returns table (
    base_salary numeric(12,3),
    currency_code text,
    pay_period text,
    allowances numeric(12,3),
    effective_from date
)
language sql
stable
as $$
    select ch.base_salary, ch.currency_code, ch.pay_period, ch.allowances, ch.effective_from
    from hr.compensation_history ch
    where ch.staff_id = p_staff_id
    and (ch.effective_to is null or ch.effective_to >= now()::date)
    order by ch.effective_from desc
    limit 1;
$$;

create or replace function hr.prevent_duplicate_payroll()
returns trigger
language plpgsql
security definer
as $$
declare
    v_existing int;
begin
    -- Check if payroll already exists for this employee and period
    select count(*) into v_existing
    from hr.payroll_lines pl
    join hr.payroll_runs pr on pr.id = pl.payroll_run_id
    where pl.staff_id = new.staff_id
    and pr.branch_id = new.branch_id
    and pr.payroll_period = new.payroll_period
    and pr.status != 'cancelled';
    
    if v_existing > 0 then
        raise exception 'Payroll line already exists for this employee and period';
    end if;
    
    return new;
end$$;

comment on table hr.compensation_history is 'Audit trail for base salary and compensation changes';
comment on table hr.payroll_runs is 'Payroll batch headers for each pay period';
comment on table hr.payroll_lines is 'Individual employee payroll calculations within a run';
comment on table hr.salary_advances is 'Employee loan records with repayment tracking';
comment on function hr.get_current_compensation is 'Returns active compensation for an employee';
