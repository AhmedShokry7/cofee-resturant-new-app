-- 207_hr_attendance_schedules.sql
-- HR Module Phase 2: Attendance and Work Schedules
-- Entities: attendance_sessions, attendance_corrections, work_schedules, schedule_assignments

-- Attendance sessions: clock-in/clock-out records
create table hr.attendance_sessions (
    id uuid primary key default gen_random_uuid(),
    staff_id uuid not null references identity.staff_members(id) on delete cascade,
    branch_id uuid not null references core.branches(id) on delete cascade,
    
    -- Session timestamps (server-authoritative)
    clock_in_at timestamptz not null,
    clock_out_at timestamptz,
    break_start_at timestamptz,
    break_end_at timestamptz,
    
    -- Status tracking
    status text not null default 'open' 
        check (status in ('open', 'broken', 'closed', 'manual_closed')),
    
    -- Manual corrections metadata
    is_manual_correction boolean not null default false,
    correction_reason text,
    corrected_by uuid references auth.users(id),
    
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    
    constraint hr_attendance_session_single_open check (
        status != 'open' or clock_out_at is null
    ),
    constraint hr_attendance_branch_scope check (branch_id is not null)
);

-- Attendance corrections log (separate from session for audit)
create table hr.attendance_corrections (
    id uuid primary key default gen_random_uuid(),
    session_id uuid references hr.attendance_sessions(id) on delete set null,
    staff_id uuid not null references identity.staff_members(id) on delete cascade,
    branch_id uuid not null references core.branches(id) on delete cascade,
    
    -- Correction details
    original_date date not null,
    corrected_date date not null,
    original_clock_in_at timestamptz,
    corrected_clock_in_at timestamptz,
    original_clock_out_at timestamptz,
    corrected_clock_out_at timestamptz,
    
    // Type of correction
    correction_type text not null
        check (correction_type in ('late_arrival', 'early_departure', 'missed_clock_in', 
                                   'missed_clock_out', 'full_day_absence', 'schedule_change')),
    
    reason text not null,
    approved_by uuid references auth.users(id),
    approval_status text not null default 'pending'
        check (approval_status in ('pending', 'approved', 'rejected')),
    
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    
    constraint hr_attendance_corr_session_unique unique (session_id),
    constraint hr_attendance_corr_date_unique unique (staff_id, original_date)
);

-- Work schedules (template definitions)
create table hr.work_schedules (
    id uuid primary key default gen_random_uuid(),
    name_ar text not null,
    name_en text not null,
    branch_id uuid not null references core.branches(id) on delete cascade,
    
    // Weekly pattern
    monday_start time,
    monday_end time,
    tuesday_start time,
    tuesday_end time,
    wednesday_start time,
    wednesday_end time,
    thursday_start time,
    thursday_end time,
    friday_start time,
    friday_end time,
    saturday_start time,
    saturday_end time,
    sunday_start time,
    sunday_end time,
    
    // Break times
    daily_break_duration_min integer,
    
    is_active boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    created_by uuid references auth.users(id),
    
    constraint hr_work_schedule_name_unique check (
        coalesce(name_ar, '') != '' or coalesce(name_en, '') != ''
    )
);

// Schedule assignments (link employees to schedules with effective dates)
create table hr.schedule_assignments (
    id uuid primary key default gen_random_uuid(),
    schedule_id uuid not null references hr.work_schedules(id) on delete cascade,
    staff_id uuid not null references identity.staff_members(id) on delete cascade,
    branch_id uuid not null references core.branches(id) on delete cascade,
    
    // Assignment period
    effective_from date not null,
    effective_to date,
    
    // Override specific days (optional)
    override_monday_start time,
    override_monday_end time,
    override_tuesday_start time,
    override_tuesday_end time,
    override_wednesday_start time,
    override_wednesday_end time,
    override_thursday_start time,
    override_thursday_end time,
    override_friday_start time,
    override_friday_end time,
    override_saturday_start time,
    override_saturday_end time,
    override_sunday_start time,
    override_sunday_end time,
    
    is_active boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    created_by uuid references auth.users(id),
    
    constraint hr_assignment_period_check check (effective_to is null or effective_to >= effective_from),
    constraint hr_assignment_active_dates overlap check (
        effective_to is null or effective_to >= now()::date
    )
);

// Indexes
create index hr_attendance_sessions_staff_date_idx on hr.attendance_sessions(staff_id, clock_in_at);
create index hr_attendance_sessions_branch_date_idx on hr.attendance_sessions(branch_id, clock_in_at);
create index hr_attendance_sessions_status_idx on hr.attendance_sessions(status);
create index hr_attendance_corrections_staff_idx on hr.attendance_corrections(staff_id);
create index hr_attendance_corrections_status_idx on hr.attendance_corrections(approval_status);
create index hr_work_schedules_branch_idx on hr.work_schedules(branch_id);
create index hr_schedule_assignments_staff_idx on hr.schedule_assignments(staff_id);
create index hr_schedule_assignments_schedule_idx on hr.schedule_assignments(schedule_id);

// RLS policies
alter table hr.attendance_sessions enable row level security;
alter table hr.attendance_corrections enable row level security;
alter table hr.work_schedules enable row level security;
alter table hr.schedule_assignments enable row level security;

// Attendance sessions: readable by HR + own data + branch scope
create policy hr_attendance_read
    on hr.attendance_sessions for select
    using (
        exists (
            select 1 from identity.staff_members sm
            join identity.role_permissions rp on rp.staff_member_id = sm.id
            join identity.permissions p on p.id = rp.permission_id
            where sm.user_id = auth.uid()
            and p.code in ('admin.branch.write', 'hr.attendance.manage', 'hr.employee.read')
        )
        or staff_id = (select id from identity.staff_members where user_id = auth.uid())
        or exists (
            select 1 from identity.staff_roles sr
            where sr.staff_member_id = (select id from identity.staff_members where user_id = auth.uid())
            and sr.branch_id = branch_id
        )
    );

// Allow write only for those with HR permission
create policy hr_attendance_write
    on hr.attendance_sessions for insert
    with check (
        exists (
            select 1 from identity.staff_members sm
            join identity.role_permissions rp on rp.staff_member_id = sm.id
            join identity.permissions p on p.id = rp.permission_id
            where sm.user_id = auth.uid()
            and p.code in ('admin.branch.write', 'hr.attendance.manage')
        )
    );

create policy hr_attendance_update
    on hr.attendance_sessions for update
    using (
        exists (
            select 1 from identity.staff_members sm
            join identity.role_permissions rp on rp.staff_member_id = sm.id
            join identity.permissions p on p.id = rp.permission_id
            where sm.user_id = auth.uid()
            and p.code in ('admin.branch.write', 'hr.attendance.manage')
        )
    );

// Attendance corrections: stricter controls
create policy hr_attendance_corr_read
    on hr.attendance_corrections for select
    using (
        exists (
            select 1 from identity.staff_members sm
            join identity.role_permissions rp on rp.staff_member_id = sm.id
            join identity.permissions p on p.id = rp.permission_id
            where sm.user_id = auth.uid()
            and p.code in ('admin.branch.write', 'hr.attendance.manage', 'hr.employee.read')
        )
    );

create policy hr_attendance_corr_write
    on hr.attendance_corrections for insert
    with check (
        exists (
            select 1 from identity.staff_members sm
            join identity.role_permissions rp on rp.staff_member_id = sm.id
            join identity.permissions p on p.id = rp.permission_id
            where sm.user_id = auth.uid()
            and p.code in ('admin.branch.write', 'hr.attendance.manage')
        )
    );

// Work schedules and assignments
create policy hr_schedule_read
    on hr.work_schedules for select
    using (
        exists (
            select 1 from identity.staff_members sm
            join identity.role_permissions rp on rp.staff_member_id = sm.id
            join identity.permissions p on p.id = rp.permission_id
            where sm.user_id = auth.uid()
            and p.code in ('admin.branch.write', 'hr.schedule.manage', 'hr.employee.read')
        )
    );

create policy hr_schedule_assignment_read
    on hr.schedule_assignments for select
    using (
        exists (
            select 1 from identity.staff_members sm
            join identity.role_permissions rp on rp.staff_member_id = sm.id
            join identity.permissions p on p.id = rp.permission_id
            where sm.user_id = auth.uid()
            and p.code in ('admin.branch.write', 'hr.schedule.manage', 'hr.employee.read')
        )
    );

-- Grants
grant usage on schema hr to authenticated;
grant select, insert, update, delete on hr.attendance_sessions to authenticated;
grant select, insert, update, delete on hr.attendance_corrections to authenticated;
grant select, insert, update, delete on hr.work_schedules to authenticated;
grant select, insert, update, delete on hr.schedule_assignments to authenticated;

-- Helper functions
create or replace function hr.check_open_session_for_staff(staff_param uuid, branch_param uuid)
returns table (session_id uuid)
language plpgsql
stable
as $$
begin
    return query
    select id from hr.attendance_sessions
    where staff_id = staff_param
    and branch_id = branch_param
    and status = 'open';
end$$;

create or replace function hr.record_clock_in()
returns trigger
language plpgsql
security definer
as $$
declare
    v_staff_id uuid;
    v_current_branch uuid;
    v_open_count int;
begin
    -- Get current staff's branch (use first if multiple)
    select into v_current_branch sr.branch_id
    from identity.staff_roles sr
    where sr.staff_member_id = new.staff_id
    and sr.branch_id = new.branch_id
    limit 1;
    
    if v_current_branch is null then
        raise exception 'Staff does not have access to this branch';
    end if;
    
    -- Check for existing open session
    select count(*) into v_open_count
    from hr.attendance_sessions
    where staff_id = new.staff_id
    and branch_id = new.branch_id
    and status = 'open';
    
    if v_open_count > 0 then
        raise exception 'Staff already has an open attendance session';
    end if;
    
    new.created_at := now();
    new.updated_at := now();
    
    return new;
end$$;

create trigger hr_attendance_session_before_insert
    before insert on hr.attendance_sessions
    for each row execute function hr.check_open_session_for_staff(new.staff_id, new.branch_id);

comment on table hr.attendance_sessions is 'Employee clock-in/clock-out sessions with server-authoritative timestamps';
comment on table hr.attendance_corrections is 'Audit trail for manual attendance corrections requiring approval';
comment on table hr.work_schedules is 'Weekly schedule templates with time patterns';
comment on table hr.schedule_assignments is 'Assign employees to schedules with optional overrides';
comment on function hr.record_clock_in is 'Pre-insert trigger to prevent duplicate open sessions';
