-- 206_hr_employee_foundation.sql
-- HR Module Phase 1: Employee Management Foundation
-- Entities: employment_records, departments, job_titles
-- Relations to identity.staff_members via staff_id (FK)

create schema if not exists hr;
alter schema hr owner to postgres;
comment on schema hr is 'HR module: employees, schedules, attendance, leave, payroll';

-- Departements table
create table hr.departments (
    id uuid primary key default gen_random_uuid(),
    code text not null,
    name_ar text not null,
    name_en text not null,
    branch_id uuid references core.branches(id) on delete cascade,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    
    constraint hr_departments_code_unique unique (code, branch_id),
    constraint hr_departments_branch_scope check (branch_id is not null)
);

-- Job titles table
create table hr.job_titles (
    id uuid primary key default gen_random_uuid(),
    code text not null,
    name_ar text not null,
    name_en text not null,
    department_id uuid references hr.departments(id) on delete set null,
    level integer,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    
    constraint hr_job_titles_code_unique unique (code, department_id),
    constraint hr_job_titles_level_check check (level is null or level > 0)
);

-- Employment records: connects staff_members to HR data
create table hr.employment_records (
    id uuid primary key default gen_random_uuid(),
    staff_id uuid not null references identity.staff_members(id) on delete cascade,
    employee_number text not null, -- Human-readable ID like EMP-001
    department_id uuid references hr.departments(id) on delete set null,
    job_title_id uuid references hr.job_titles(id) on delete set null,
    
    -- Employment details
    hire_date date not null,
    termination_date date,
    employment_status text not null default 'active' 
        check (employment_status in ('active', 'terminated', 'resigned', 'suspended', 'on_leave')),
    
    -- Compensation (base config, separate from payroll calculation)
    base_salary numeric(12,3) not null default 0,
    currency_code text not null default 'SAR' check (currency_code = 'SAR'),
    pay_period text not null default 'monthly' check (pay_period in ('monthly', 'weekly', 'daily')),
    
    -- Branch assignment (HR-level, different from POS shift assignments)
    main_branch_id uuid references core.branches(id) on delete set null,
    
    -- Metadata
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    created_by uuid references auth.users(id),
    
    constraint hr_employment_staff_unique unique (staff_id),
    constraint hr_employment_emp_num_unique unique (employee_number),
    constraint hr_employment_status_check check (employment_status is not null)
);

-- Indexes for performance
create index hr_employment_records_staff_idx on hr.employment_records(staff_id);
create index hr_employment_records_branch_idx on hr.employment_records(main_branch_id);
create index hr_employment_records_status_idx on hr.employment_records(employment_status);
create index hr_departments_branch_idx on hr.departments(branch_id);
create index hr_job_titles_dept_idx on hr.job_titles(department_id);

-- Row Level Security policies
alter table hr.departments enable row level security;
alter table hr.job_titles enable row level security;
alter table hr.employment_records enable row level security;

-- Departments: only managers can read
create policy hr_departments_read_manage_all
    on hr.departments for select
    using (
        cothere exists (
            select 1 from identity.staff_members sm
            join identity.role_permissions rp on rp.staff_member_id = sm.id
            join identity.permissions p on p.id = rp.permission_id
            where sm.user_id = auth.uid()
            and p.code in ('admin.branch.write', 'hr.employee.read')
        )
    );

-- Job titles: readable by anyone with hr.employee.read
create policy hr_job_titles_read
    on hr.job_titles for select
    using (
        cothere exists (
            select 1 from identity.staff_members sm
            join identity.role_permissions rp on rp.staff_member_id = sm.id
            join identity.permissions p on p.id = rp.permission_id
            where sm.user_id = auth.uid()
            and p.code in ('admin.branch.write', 'hr.employee.read')
        )
    );

-- Employment records: readable by HR + branch scope
create policy hr_employment_read
    on hr.employment_records for select
    using (
        cothere exists (
            select 1 from identity.staff_members sm
            join identity.role_permissions rp on rp.staff_member_id = sm.id
            join identity.permissions p on p.id = rp.permission_id
            where sm.user_id = auth.uid()
            and p.code in ('admin.branch.write', 'hr.employee.read')
        )
        and (
            main_branch_id is null
            or exists (
                select 1 from identity.staff_roles sr
                where sr.branch_id = main_branch_id
                and sr.staff_member_id = (
                    select id from identity.staff_members where user_id = auth.uid()
                )
            )
        )
    );

-- Insert HR-specific permissions into identity.permissions (will fail safely if exist)
insert into identity.permissions (id, code, name_ar, name_en, description_ar, description_en)
values
    (gen_random_uuid(), 'hr.employee.read', 'قراءة سجلات الموظفين', 'Read Employee Records', 'إمكانية قراءة بيانات الموظفين الأساسية', 'Ability to read basic employee information'),
    (gen_random_uuid(), 'hr.employee.write', 'كتابة سجلات الموظفين', 'Write Employee Records', 'إمكانية تعديل بيانات الموظفين', 'Ability to modify employee data'),
    (gen_random_uuid(), 'hr.attendance.manage', 'إدارة الحضور', 'Manage Attendance', 'إدارة تسجيل الحضور والغياب', 'Manage clock-in/clock-out records'),
    (gen_random_uuid(), 'hr.schedule.manage', 'إدارة الجداول', 'Manage Schedules', 'إدارة جداول العمل', 'Manage work schedules'),
    (gen_random_uuid(), 'hr.leave.review', 'مراجعة الإجازات', 'Review Leave Requests', 'موافقة/رفض طلبات الإجازات', 'Approve/reject leave requests'),
    (gen_random_uuid(), 'hr.payroll.read', 'قراءة الرواتب', 'Read Payroll', 'رؤية معلومات الرواتب والأجور', 'View salary and payroll information'),
    (gen_random_uuid(), 'hr.payroll.calculate', 'حساب الرواتب', 'Calculate Payroll', 'حساب وتنفيذ الرواتب', 'Calculate and process payroll'),
    (gen_random_uuid(), 'hr.payroll.approve', 'اعتماد الرواتب', 'Approve Payroll', 'الموافقة على الدفع', 'Approve payment processing'),
    (gen_random_uuid(), 'hr.compensation.manage', 'إدارة التعويضات', 'Manage Compensation', 'تعديل مبالغ الرواتب الأساسية', 'Modify base salary amounts'),
    (gen_random_uuid(), 'hr.financial.adjust', 'الإجراءات المالية', 'Financial Adjustments', 'إجراء خصومات أو إضافات مالية', 'Make financial deductions/additions')
on conflict (code) do nothing;

-- Grant access to authenticated staff
do $$
begin
    -- Grant schema access
    grant usage on schema hr to authenticated;
    
    -- Grant table access with SELECT for HR readers
    grant select on hr.departments to authenticated;
    grant select on hr.job_titles to authenticated;
    grant select on hr.employment_records to authenticated;
    
    -- Grant INSERT/UPDATE for those with write permissions (handled by RLS)
    grant insert, update, delete on hr.departments to authenticated;
    grant insert, update, delete on hr.job_titles to authenticated;
    grant insert, update, delete on hr.employment_records to authenticated;
end$$;

-- Helper function to get current staff's branches
create or replace function hr.get_current_staff_branches()
returns setof uuid
language sql
stable
as $$
    select sr.branch_id
    from identity.staff_members sm
    join identity.staff_roles sr on sr.staff_member_id = sm.id
    where sm.user_id = auth.uid()
    and sr.branch_id is not null;
$$;

comment on table hr.departments is 'Organizational departments within branches';
comment on table hr.job_titles is 'Job positions/titles, optionally grouped by department';
comment on table hr.employment_records is 'Main employment record linking staff_members to HR data';
comment on column hr.employment_records.employee_number is 'Human-readable employee ID';
comment on column hr.employment_records.base_salary is 'Base compensation amount before additions/deductions';
comment on column hr.employment_records.pay_period is 'Salary payment frequency';
