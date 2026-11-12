-- 241_hr_offboarding.sql
--
-- HR Phase 3 / decision D6: an independent employee offboarding cycle.
--
-- DESIGN
--   hr.offboarding_cases  — one case per employee (a cancelled case frees the
--     slot for a restart). The case holds the planned last working day; the
--     termination decision is executed through finalize, separated from every
--     settlement step.
--   hr.offboarding_steps  — a fixed checklist, one row per code per case, each
--     with an owner, a due date, a note and the actor who closed it:
--       manager_review, hr_review, finance_review, obligations,
--       final_settlement, access_suspension.
--   No EOS-money formula is invented: final_settlement is a documented human
--   sign-off (amounts live inside its note). Legal EOS computation stays an
--   owner policy decision.
--   Access suspension is its own deliberate, audited act executed AFTER the
--   case is closed — never automatic.
--
-- LIFECYCLE: invited/onboarding stay in staff_members.status (unchanged);
--   active/probation/on_leave/terminated stay in hr.employment_records;
--   offboarding lives here; archiving is NOT introduced — history stays put.
--
-- ROLLBACK: drop the two tables and the functions.

create table if not exists hr.offboarding_cases (
  id              uuid primary key default extensions.gen_random_uuid(),
  staff_id        uuid not null references identity.staff_members(id) on delete restrict,
  status          text not null default 'open'
                    check (status in ('open', 'closed', 'cancelled')),
  last_working_on date,
  settlement_note text not null default '',
  requested_by    uuid not null references identity.staff_members(id) on delete restrict,
  finalized_by    uuid references identity.staff_members(id) on delete set null,
  finalized_at    timestamptz,
  cancelled_note  text not null default '',
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

comment on table hr.offboarding_cases is
  'One offboarding case per employee. Closing the case executes the '
  'termination decision; suspending access is a later, separate, audited act.';

create unique index if not exists uq_offboarding_case_staff
  on hr.offboarding_cases (staff_id)
  where status <> 'cancelled';

create table if not exists hr.offboarding_steps (
  id             uuid primary key default extensions.gen_random_uuid(),
  case_id        uuid not null references hr.offboarding_cases(id) on delete restrict,
  code           text not null
                   check (code in ('manager_review', 'hr_review', 'finance_review',
                                   'obligations', 'final_settlement', 'access_suspension')),
  status         text not null default 'pending'
                   check (status in ('pending', 'done', 'skipped')),
  owner_staff_id uuid references identity.staff_members(id) on delete set null,
  due_on         date,
  note           text not null default '',
  done_by        uuid references identity.staff_members(id) on delete set null,
  done_at        timestamptz,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  constraint ck_offboarding_step_done check (
    status <> 'done' or (done_by is not null and done_at is not null)
  ),
  unique (case_id, code)
);

comment on table hr.offboarding_steps is
  'The offboarding checklist. final_settlement is a documented human sign-off; '
  'access_suspension is executed after the case is closed, by an explicit act.';

alter table hr.offboarding_cases enable row level security;
alter table hr.offboarding_steps enable row level security;
revoke all on hr.offboarding_cases from public, anon, authenticated;
revoke all on hr.offboarding_steps from public, anon, authenticated;

create trigger tr_offboarding_cases_updated_at
  before update on hr.offboarding_cases
  for each row execute function core.set_updated_at();

create trigger tr_offboarding_steps_updated_at
  before update on hr.offboarding_steps
  for each row execute function core.set_updated_at();

create or replace function hr.offboarding_case_json(p_case_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $fn$
  select jsonb_build_object(
    'case_id', c.id,
    'staff_id', c.staff_id,
    'staff_name', sm.full_name,
    'employment_status', coalesce(e.employment_status, 'active'),
    'status', c.status,
    'last_working_on', c.last_working_on,
    'settlement_note', c.settlement_note,
    'requested_by_name', rb.full_name,
    'finalized_by_name', fb.full_name,
    'finalized_at', c.finalized_at,
    'cancelled_note', c.cancelled_note,
    'created_at', c.created_at,
    'steps', coalesce((
      select jsonb_agg(jsonb_build_object(
        'code', s.code,
        'status', s.status,
        'owner_staff_id', s.owner_staff_id,
        'owner_name', ow.full_name,
        'due_on', s.due_on,
        'note', s.note,
        'done_by_name', db.full_name,
        'done_at', s.done_at
      ) order by case s.code
        when 'manager_review' then 1
        when 'hr_review' then 2
        when 'finance_review' then 3
        when 'obligations' then 4
        when 'final_settlement' then 5
        else 6 end)
      from hr.offboarding_steps s
      left join identity.staff_members ow on ow.id = s.owner_staff_id
      left join identity.staff_members db on db.id = s.done_by
      where s.case_id = c.id
    ), '[]'::jsonb)
  )
  from hr.offboarding_cases c
  join identity.staff_members sm on sm.id = c.staff_id
  left join hr.employment_records e on e.staff_id = c.staff_id
  left join identity.staff_members rb on rb.id = c.requested_by
  left join identity.staff_members fb on fb.id = c.finalized_by
  where c.id = p_case_id;
$fn$;

revoke all on function hr.offboarding_case_json(uuid) from public, anon, authenticated;

create or replace function public.admin_hr_start_offboarding(
  p_staff_id        uuid,
  p_last_working_on date default null,
  p_note            text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_me uuid;
  v_case uuid;
begin
  v_me := hr.require_permission('hr.employee.write');
  perform hr.assert_staff_access(p_staff_id);

  if not exists (
    select 1 from identity.staff_members sm where sm.id = p_staff_id
  ) then
    raise exception 'employee not found' using errcode = 'P0002';
  end if;
  if exists (
    select 1 from hr.offboarding_cases oc
     where oc.staff_id = p_staff_id and oc.status = 'open'
  ) then
    raise exception 'an offboarding case is already open for this employee'
      using errcode = '23505';
  end if;

  insert into hr.offboarding_cases (
    staff_id, last_working_on, settlement_note, requested_by
  ) values (
    p_staff_id, p_last_working_on,
    left(btrim(coalesce(p_note, '')), 500), v_me
  )
  returning id into v_case;

  insert into hr.offboarding_steps (case_id, code) values
    (v_case, 'manager_review'),
    (v_case, 'hr_review'),
    (v_case, 'finance_review'),
    (v_case, 'obligations'),
    (v_case, 'final_settlement'),
    (v_case, 'access_suspension');

  perform identity.audit(
    'hr.offboarding.start',
    'offboarding_case', v_case,
    null,
    jsonb_build_object('staff_id', p_staff_id, 'last_working_on', p_last_working_on),
    null
  );

  return hr.offboarding_case_json(v_case);
end;
$fn$;

comment on function public.admin_hr_start_offboarding(uuid, date, text) is
  'Opens the offboarding case with its fixed checklist. The termination '
  'decision itself stays unexecuted until the case is finalized.';

create or replace function public.admin_hr_assign_offboarding_step(
  p_case_id     uuid,
  p_code        text,
  p_owner_staff uuid default null,
  p_due_on      date default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  perform hr.require_permission('hr.employee.write');

  if p_code not in ('manager_review', 'hr_review', 'finance_review',
                    'obligations', 'final_settlement', 'access_suspension') then
    raise exception 'unknown offboarding step: %', p_code using errcode = '22023';
  end if;

  if not exists (
    select 1 from hr.offboarding_cases c
     where c.id = p_case_id
       and c.status = 'open'
       and hr.assert_staff_access(c.staff_id) is not null
  ) then
    raise exception 'offboarding case not found or not open' using errcode = 'P0002';
  end if;

  update hr.offboarding_steps s
     set owner_staff_id = p_owner_staff,
         due_on = p_due_on
   where s.case_id = p_case_id
     and s.code = p_code;

  perform identity.audit(
    'hr.offboarding.step.assign',
    'offboarding_case', p_case_id,
    null,
    jsonb_build_object('code', p_code, 'owner_staff_id', p_owner_staff, 'due_on', p_due_on),
    null
  );

  return hr.offboarding_case_json(p_case_id);
end;
$fn$;

create or replace function public.admin_hr_set_offboarding_step(
  p_case_id uuid,
  p_code    text,
  p_status  text,
  p_note    text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_me uuid;
begin
  v_me := hr.require_permission('hr.employee.write');

  if p_code not in ('manager_review', 'hr_review', 'finance_review',
                    'obligations', 'final_settlement', 'access_suspension') then
    raise exception 'unknown offboarding step: %', p_code using errcode = '22023';
  end if;
  if p_status not in ('pending', 'done', 'skipped') then
    raise exception 'invalid offboarding step status' using errcode = '22023';
  end if;
  if p_status = 'done' and nullif(btrim(coalesce(p_note, '')), '') is null then
    raise exception 'closing an offboarding step needs a note' using errcode = '22023';
  end if;

  if not exists (
    select 1 from hr.offboarding_cases c
     where c.id = p_case_id
       and c.status = 'open'
       and hr.assert_staff_access(c.staff_id) is not null
  ) then
    raise exception 'offboarding case not found or not open' using errcode = 'P0002';
  end if;

  update hr.offboarding_steps s
     set status = p_status,
         note = case when nullif(btrim(coalesce(p_note, '')), '') is null
                     then s.note else left(btrim(p_note), 1000) end,
         done_by = case when p_status = 'done' then v_me else s.done_by end,
         done_at = case when p_status = 'done' then now() else s.done_at end
   where s.case_id = p_case_id
     and s.code = p_code;

  perform identity.audit(
    'hr.offboarding.step.' || p_status,
    'offboarding_case', p_case_id,
    null,
    jsonb_build_object('code', p_code, 'status', p_status, 'note', p_note),
    null
  );

  return hr.offboarding_case_json(p_case_id);
end;
$fn$;

create or replace function public.admin_hr_cancel_offboarding(
  p_case_id uuid,
  p_note    text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  perform hr.require_permission('hr.employee.write');

  if not exists (
    select 1 from hr.offboarding_cases c
     where c.id = p_case_id
       and c.status = 'open'
       and hr.assert_staff_access(c.staff_id) is not null
  ) then
    raise exception 'offboarding case not found or not open' using errcode = 'P0002';
  end if;

  update hr.offboarding_cases
     set status = 'cancelled',
         cancelled_note = left(btrim(coalesce(p_note, '')), 500)
   where id = p_case_id;

  perform identity.audit(
    'hr.offboarding.cancel',
    'offboarding_case', p_case_id,
    jsonb_build_object('status', 'open'),
    jsonb_build_object('status', 'cancelled', 'note', p_note),
    null
  );

  return hr.offboarding_case_json(p_case_id);
end;
$fn$;

create or replace function public.admin_hr_finalize_offboarding(
  p_case_id       uuid,
  p_terminated_on date default null,
  p_note          text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_me uuid;
  v_case hr.offboarding_cases%rowtype;
  v_terminated_on date := coalesce(p_terminated_on, current_date);
begin
  v_me := hr.require_permission('hr.employee.write');

  select * into v_case
    from hr.offboarding_cases c
   where c.id = p_case_id
   for update;
  if not found then
    raise exception 'offboarding case not found' using errcode = 'P0002';
  end if;
  perform hr.assert_staff_access(v_case.staff_id);
  if v_case.staff_id = v_me and not hr.is_owner() then
    raise exception 'you cannot finalize your own offboarding' using errcode = '42501';
  end if;
  if v_case.status <> 'open' then
    raise exception 'only an open offboarding case can be finalized' using errcode = '23514';
  end if;

  if exists (
    select 1 from hr.offboarding_steps s
     where s.case_id = p_case_id
       and s.code in ('manager_review', 'hr_review', 'finance_review',
                      'obligations', 'final_settlement')
       and s.status = 'pending'
  ) then
    raise exception 'the offboarding checklist still has pending steps'
      using errcode = '23514';
  end if;

  declare
    v_hired date;
  begin
    select hired_on into v_hired from hr.employment_records
     where staff_id = v_case.staff_id;
    if v_hired is not null and v_terminated_on < v_hired then
      raise exception 'termination date precedes hire date' using errcode = '22023';
    end if;
  end;

  update hr.employment_records
     set employment_status = 'terminated',
         terminated_on = v_terminated_on
   where staff_id = v_case.staff_id;

  update hr.offboarding_cases
     set status = 'closed',
         finalized_by = v_me,
         finalized_at = now(),
         settlement_note = case
             when nullif(btrim(coalesce(p_note, '')), '') is null then settlement_note
             else left(btrim(p_note), 1000)
           end
   where id = p_case_id;

  perform identity.audit(
    'hr.offboarding.finalize',
    'offboarding_case', p_case_id,
    jsonb_build_object('status', 'open'),
    jsonb_build_object(
      'status', 'closed',
      'staff_id', v_case.staff_id,
      'terminated_on', v_terminated_on,
      'note', p_note
    ),
    null
  );

  return hr.offboarding_case_json(p_case_id);
end;
$fn$;

create or replace function public.admin_hr_suspend_offboarding_access(
  p_case_id uuid,
  p_note    text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_me uuid;
begin
  v_me := hr.require_permission('hr.employee.write');

  if not exists (
    select 1 from hr.offboarding_cases c
     where c.id = p_case_id
       and c.status = 'closed'
       and hr.assert_staff_access(c.staff_id) is not null
  ) then
    raise exception 'offboarding case not found or not closed' using errcode = 'P0002';
  end if;

  if exists (
    select 1 from hr.offboarding_steps s
     where s.case_id = p_case_id
       and s.code = 'access_suspension'
       and s.status = 'done'
  ) then
    raise exception 'access suspension is already executed for this case'
      using errcode = '23514';
  end if;

  update identity.staff_members sm
     set status = 'suspended',
         suspended_at = now()
   where sm.id = (
     select c.staff_id from hr.offboarding_cases c where c.id = p_case_id
   );

  update hr.offboarding_steps s
     set status = 'done',
         done_by = v_me,
         note = left(btrim(coalesce(p_note, 'login suspended')), 1000),
         done_at = now()
   where s.case_id = p_case_id
     and s.code = 'access_suspension';

  perform identity.audit(
    'hr.offboarding.access_suspended',
    'offboarding_case', p_case_id,
    null,
    jsonb_build_object('note', p_note),
    null
  );

  return hr.offboarding_case_json(p_case_id);
end;
$fn$;

create or replace function public.admin_hr_offboarding_cases(
  p_staff_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
begin
  perform hr.require_permission('hr.employee.read');

  if p_staff_id is not null then
    perform hr.assert_staff_access(p_staff_id);
  end if;

  return coalesce((
    select jsonb_agg(hr.offboarding_case_json(c.id) order by c.created_at desc)
    from hr.offboarding_cases c
    where (p_staff_id is null or c.staff_id = p_staff_id)
      and hr.can_access_staff(c.staff_id)
  ), '[]'::jsonb);
end;
$fn$;

comment on function public.admin_hr_offboarding_cases(uuid) is
  'The offboarding cases of the caller scope, with their step checklists.';

revoke all on function public.admin_hr_start_offboarding(uuid, date, text)
  from public, anon;
revoke all on function public.admin_hr_assign_offboarding_step(uuid, text, uuid, date)
  from public, anon;
revoke all on function public.admin_hr_set_offboarding_step(uuid, text, text, text)
  from public, anon;
revoke all on function public.admin_hr_cancel_offboarding(uuid, text)
  from public, anon;
revoke all on function public.admin_hr_finalize_offboarding(uuid, date, text)
  from public, anon;
revoke all on function public.admin_hr_suspend_offboarding_access(uuid, text)
  from public, anon;
revoke all on function public.admin_hr_offboarding_cases(uuid)
  from public, anon;

grant execute on function public.admin_hr_start_offboarding(uuid, date, text)
  to authenticated;
grant execute on function public.admin_hr_assign_offboarding_step(uuid, text, uuid, date)
  to authenticated;
grant execute on function public.admin_hr_set_offboarding_step(uuid, text, text, text)
  to authenticated;
grant execute on function public.admin_hr_cancel_offboarding(uuid, text)
  to authenticated;
grant execute on function public.admin_hr_finalize_offboarding(uuid, date, text)
  to authenticated;
grant execute on function public.admin_hr_suspend_offboarding_access(uuid, text)
  to authenticated;
grant execute on function public.admin_hr_offboarding_cases(uuid)
  to authenticated;

notify pgrst, 'reload schema';
