-- 208_hr_leave_cashier_discrepancies.sql
-- HR Module Phase 3: Leave Management & Cashier Accountability
-- Entities: leave_types, leave_requests, cashier_discrepancies, financial_adjustments

-- Leave types (configurable)
create type hr.leave_type_kind as enum (
    'annual', 'sick', 'personal', 'unpaid', 'maternity', 
    'paternity', 'emergency', 'compensatory', 'floating'
);

create table hr.leave_types (
    id uuid primary key default gen_random_uuid(),
    code text not null unique,
    name_ar text not null,
    name_en text not null,
    kind hr.leave_type_kind not null default 'annual',
    
    -- Entitlement (optional - can be per-employee)
    annual_days integer,
    requires_document boolean not null default false,
    max_consecutive_days integer,
    accrual_rate numeric(5,2), -- Days accrued per month
    
    is_active boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    created_by uuid references auth.users(id),
    
    constraint hr_leave_type_code_unique unique (code)
);

-- Leave requests
create table hr.leave_requests (
    id uuid primary key default gen_random_uuid(),
    staff_id uuid not null references identity.staff_members(id) on delete cascade,
    leave_type_id uuid not null references hr.leave_types(id) on delete restrict,
    branch_id uuid not null references core.branches(id) on delete cascade,
    
    -- Request period
    start_date date not null,
    end_date date not null,
    total_days numeric(4,2) not null,
    
    // Reason (optional but recommended)
    reason text,
    supporting_document_url text,
    
    // Balance tracking
    deducted_balance boolean not null default false,
    days_deducted numeric(4,2),
    
    // Approval workflow
    requested_by uuid not null references auth.users(id),
    request_date timestamptz not null default now(),
    
    reviewed_by uuid references auth.users(id),
    review_date timestamptz,
    approval_status text not null default 'pending'
        check (approval_status in ('pending', 'approved', 'rejected', 'cancelled')),
    rejection_reason text,
    
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    
    constraint hr_leave_request_dates_check check (end_date >= start_date),
    constraint hr_leave_request_single_pending check (
        approval_status != 'pending' or reviewed_by is not null
    ),
    constraint hr_leave_request_days_positive check (total_days > 0)
);

// Create index for pending reviews
create index hr_leave_requests_pending_idx on hr.leave_requests(approval_status) 
    where approval_status = 'pending';

// Cashier discrepancies: linked to POS shifts
create table hr.cashier_discrepancies (
    id uuid primary key default gen_random_uuid(),
    shift_id uuid not null references pos.shifts(id) on delete cascade,
    staff_id uuid not null references identity.staff_members(id) on delete cascade,
    branch_id uuid not null references core.branches(id) on delete cascade,
    
    // Discrepancy calculation (from authoritative source: POS shift variance)
    variance_amount numeric(12,3) not null,
    expected_cash numeric(12,3) not null,
    counted_cash numeric(12,3) not null,
    
    // Investigation status
    investigation_status text not null default 'pending_review'
        check (investigation_status in (
            'pending_review', 'explained', 'reconciliation_required',
            'confirmed_discrepancy', 'rejected_allegation', 'approved_adjustment'
        )),
    
    // Investigation notes
    investigator_notes text,
    investigator_id uuid references auth.users(id),
    investigation_date timestamptz,
    
    // Resolution outcome
    resolution_outcome text,
    resolved_by uuid references auth.users(id),
    resolution_date timestamptz,
    
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    
    constraint hr_discrepancy_variance_calculation check (
        variance_amount = counted_cash - expected_cash
    ),
    constraint hr_discrepancy_branch_scope check (branch_id is not null)
);

// Financial adjustments: approved deductions/additions linked to payroll
create type hr.financial_adjustment_kind as enum (
    'shortage_deduction', 'overage_credit', 'salary_advance',
    'bonus', 'allowance', 'other_deduction', 'other_addition'
);

create type hr.financial_adjustment_status as enum (
    'pending_approval', 'approved', 'rejected', 'applied_to_payroll', 'reversed'
);

create table hr.financial_adjustments (
    id uuid primary key default gen_random_uuid(),
    staff_id uuid not null references identity.staff_members(id) on delete cascade,
    branch_id uuid not null references core.branches(id) on delete cascade,
    
    // Source reference
    adjustment_kind hr.financial_adjustment_kind not null,
    source_type text, -- 'cashier_discrepancy', 'manual', etc.
    source_id uuid, -- Reference to relevant record (discrepancy.id, advance.id, etc.)
    
    // Amount details
    amount numeric(12,3) not null,
    currency_code text not null default 'SAR' check (currency_code = 'SAR'),
    description text not null,
    
    // Approval workflow
    requested_by uuid not null references auth.users(id),
    request_date timestamptz not null default now(),
    
    approved_by uuid references auth.users(id),
    approval_date timestamptz,
    approval_status hr.financial_adjustment_status not null default 'pending_approval',
    
    // Payroll linkage
    applied_payroll_period text, -- Format: YYYY-MM
    applied_payroll_id uuid,
    
    // Reversal tracking
    reversed_by uuid references auth.users(id),
    reversal_date timestamptz,
    reversal_reason text,
    
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    
    constraint hr_financial_adjustment_amount_positive check (amount > 0),
    constraint hr_financial_adjustment_source_unique unique (source_type, source_id),
    constraint hr_financial_adjustment_payroll_ref unique (applied_payroll_period, staff_id)
);

-- Indexes
create index hr_leave_requests_staff_idx on hr.leave_requests(staff_id);
create index hr_leave_requests_branch_idx on hr.leave_requests(branch_id);
create index hr_leave_requests_status_idx on hr.leave_requests(approval_status);
create index hr_cashier_discrepancies_shift_idx on hr.cashier_discrepancies(shift_id);
create index hr_cashier_discrepancies_staff_idx on hr.cashier_discrepancies(staff_id);
create index hr_cashier_discrepancies_status_idx on hr.cashier_discrepancies(investigation_status);
create index hr_financial_adjustments_staff_idx on hr.financial_adjustments(staff_id);
create index hr_financial_adjustments_status_idx on hr.financial_adjustments(approval_status);
create index hr_financial_adjustments_payroll_idx on hr.financial_adjustments(applied_payroll_period, staff_id);

-- RLS policies
alter table hr.leave_types enable row level security;
alter table hr.leave_requests enable row level security;
alter table hr.cashier_discrepancies enable row level security;
alter table hr.financial_adjustments enable row level security;

-- Leave types: readable by HR
create policy hr_leave_types_read
    on hr.leave_types for select
    using (
        exists (
            select 1 from identity.staff_members sm
            join identity.role_permissions rp on rp.staff_member_id = sm.id
            join identity.permissions p on p.id = rp.permission_id
            where sm.user_id = auth.uid()
            and p.code in ('admin.branch.write', 'hr.leave.review', 'hr.employee.read')
        )
    );

// Leave requests: self + HR + manager scope
create policy hr_leave_requests_read
    on hr.leave_requests for select
    using (
        staff_id = (select id from identity.staff_members where user_id = auth.uid())
        or exists (
            select 1 from identity.staff_members sm
            join identity.role_permissions rp on rp.staff_member_id = sm.id
            join identity.permissions p on p.id = rp.permission_id
            where sm.user_id = auth.uid()
            and p.code in ('admin.branch.write', 'hr.leave.review', 'hr.employee.read')
        )
        or exists (
            select 1 from identity.staff_roles sr
            where sr.staff_member_id = (select id from identity.staff_members where user_id = auth.uid())
            and sr.branch_id = branch_id
        )
    );

// Only HR + managers can approve/reject
create policy hr_leave_requests_write
    on hr.leave_requests for update
    using (
        exists (
            select 1 from identity.staff_members sm
            join identity.role_permissions rp on rp.staff_member_id = sm.id
            join identity.permissions p on p.id = rp.permission_id
            where sm.user_id = auth.uid()
            and p.code in ('admin.branch.write', 'hr.leave.review')
        )
    );

// Cashier discrepancies: stricter access
create policy hr_discrepancies_read
    on hr.cashier_discrepancies for select
    using (
        exists (
            select 1 from identity.staff_members sm
            join identity.role_permissions rp on rp.staff_member_id = sm.id
            join identity.permissions p on p.id = rp.permission_id
            where sm.user_id = auth.uid()
            and p.code in ('admin.branch.write', 'hr.payroll.approve', 'hr.financial.adjust')
        )
    );

create policy hr_discrepancies_write
    on hr.cashier_discrepancies for update
    using (
        exists (
            select 1 from identity.staff_members sm
            join identity.role_permissions rp on rp.staff_member_id = sm.id
            join identity.permissions p on p.id = rp.permission_id
            where sm.user_id = auth.uid()
            and p.code in ('admin.branch.write', 'hr.financial.adjust')
        )
    );

// Financial adjustments: very strict - only authorized approvers
create policy hr_financial_adjustments_read
    on hr.financial_adjustments for select
    using (
        exists (
            select 1 from identity.staff_members sm
            join identity.role_permissions rp on rp.staff_member_id = sm.id
            join identity.permissions p on p.id = rp.permission_id
            where sm.user_id = auth.uid()
            and p.code in ('admin.branch.write', 'hr.payroll.approve', 'hr.financial.adjust', 'hr.payroll.read')
        )
    );

create policy hr_financial_adjustments_write
    on hr.financial_adjustments for insert
    with check (
        exists (
            select 1 from identity.staff_members sm
            join identity.role_permissions rp on rp.staff_member_id = sm.id
            join identity.permissions p on p.id = rp.permission_id
            where sm.user_id = auth.uid()
            and p.code in ('admin.branch.write', 'hr.financial.adjust')
        )
    );

create policy hr_financial_adjustments_update
    on hr.financial_adjustments for update
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
grant select, insert, update, delete on hr.leave_types to authenticated;
grant select, insert, update, delete on hr.leave_requests to authenticated;
grant select, update on hr.cashier_discrepancies to authenticated;
grant select, insert, update, delete on hr.financial_adjustments to authenticated;

-- Trigger to enforce no self-approval on leave
create or replace function hr.enforce_leave_no_self_approval()
returns trigger
language plpgsql
security definer
as $$
begin
    if new.reviewed_by = new.requested_by then
        raise exception 'Staff cannot approve their own leave requests';
    end if;
    
    return new;
end$$;

create trigger hr_leave_requests_no_self_approval
    before update on hr.leave_requests
    for each row when (new.reviewed_by is distinct from old.reviewed_by)
    execute function hr.enforce_leave_no_self_approval();

-- Helper to prevent duplicate deduction from same discrepancy
create or replace function hr.prevent_duplicate_deduction()
returns trigger
language plpgsql
security definer
as $$
declare
    v_existing_record uuid;
begin
    -- Check if this discrepancy already has an approved deduction
    select fa.id into v_existing_record
    from hr.financial_adjustments fa
    where fa.source_type = 'cashier_discrepancy'
    and fa.source_id = new.source_id
    and fa.approval_status in ('approved', 'applied_to_payroll');
    
    if v_existing_record is not null then
        raise exception 'Financial adjustment already exists for this discrepancy (ID: %)', v_existing_record;
    end if;
    
    return new;
end$$;

create trigger hr_financial_adjustment_unique_source
    before insert on hr.financial_adjustments
    for each row
    when (new.adjustment_kind = 'shortage_deduction' and new.source_type = 'cashier_discrepancy')
    execute function hr.prevent_duplicate_deduction();

comment on table hr.leave_types is 'Configurable leave categories with entitlement rules';
comment on table hr.leave_requests is 'Employee leave applications with approval workflow';
comment on table hr.cashier_discrepancies is 'Investigation records for POS shift variances';
comment on table hr.financial_adjustments is 'Approved salary deductions/additions linked to payroll';
comment on function hr.enforce_leave_no_self_approval is 'Prevents employees from approving their own leave';
comment on function hr.prevent_duplicate_deduction is 'Ensures single deduction per discrepancy event';
