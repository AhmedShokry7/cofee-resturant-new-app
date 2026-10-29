-- Migration 206: the drawer can be opened in the name of a named cashier.
--
-- THE PROBLEM
--   payments.pos_shifts.opened_by was always the person tapping the button:
--   182_admin_pos_cashier_shifts.sql:412-416 reads `identity.staff_members`
--   for `sm.user_id = auth.uid()` and 182:436-440 inserts that id. A manager
--   or an owner who starts the day's drawer for the cashier on the counter
--   cannot do it — the shift reports the manager as the cashier and every Z
--   figure in the history is attributed to the wrong person.
--
-- WHAT CHANGES
--   1. `payments.pos_shift_cashier_candidates(uuid)` is the one definition of
--      "who may hold the drawer of this branch": an active staff member whose
--      role is scoped to that branch (or to no branch) and whose role carries
--      `pos.manage`, with the `owner` role short-circuited exactly the way
--      `identity.has_permission` does (123_unify_admin_identity.sql:68-77).
--      It lives in one function so the picker and the writer cannot drift.
--   2. `public.admin_pos_cashiers(uuid)` returns that list to the panel. The
--      gate is the same one the drawer already needs (`pos.manage` plus
--      branch scope), which discloses nothing new: `admin_pos_shift` and
--      `admin_pos_shifts` already hand `opened_by_name` of that branch's
--      shifts to any `pos.manage` holder (182:322, 182:340-358).
--   3. `public.admin_pos_open_shift` takes an optional `p_cashier_id`. The old
--      three-parameter signature is dropped rather than left beside the new
--      one, because two live overloads make the PostgREST call ambiguous.
--
-- WHAT DOES NOT CHANGE
--   Opening without `p_cashier_id` behaves exactly as before: the shift is the
--   caller's own. Self-open never consults the candidate list, so a caller who
--   reaches the branch through a second role cannot be locked out of their own
--   drawer by a scope the eligibility rule did not expect.
--   A second open attempt is still idempotent: when the branch already has an
--   open shift the function returns THAT shift with `already_open` and does not
--   reassign it to the newly chosen cashier. Moving a live drawer to another
--   person is a cash-accounting decision, not a form edit, and stays the
--   owner's to make.
--   Movements and closes still record the staff member who actually performed
--   them (`created_by`, `closed_by`), not the assigned cashier, so the audit
--   trail keeps the operator and the drawer keeps its owner.
--
-- BEHAVIOUR A OWNER MUST ACCEPT
--   A `pos.manage` holder may now put a shift on another named employee of the
--   same branch, which moves the accountability of that day's cash.
--
-- CHECKLIST
--   [x] eligibility rule in one function, reused by the reader and the writer
--   [x] old signature dropped, new signature granted to `authenticated` only
--   [x] `set search_path = ''`, every relation schema-qualified
--   [x] audit row records both the operator and the assigned cashier
--
-- HOW TO VERIFY
--   supabase/tests/pos_shift_cashier_assignment_test.sql runs the whole matrix
--   as the real roles inside one rolled-back transaction.

-- ---------------------------------------------------------------------------
-- 1. The one rule of who may hold a branch drawer
-- ---------------------------------------------------------------------------
create or replace function payments.pos_shift_cashier_candidates(p_branch_id uuid)
returns table (cashier_id uuid, cashier_name text, is_self boolean)
language sql
stable
security definer
set search_path = ''
as $fn$
  select sm.id, sm.full_name, (sm.user_id = auth.uid())
    from identity.staff_members sm
   where sm.status = 'active'
     and exists (
       select 1
       from identity.staff_roles sr
       join identity.roles r on r.id = sr.role_id
      where sr.staff_id = sm.id
        and (sr.branch_id is null or sr.branch_id = p_branch_id)
        and (
          r.code = 'owner'
          or exists (
            select 1
            from identity.role_permissions rp
            join identity.permissions p on p.id = rp.permission_id
           where rp.role_id = r.id
             and p.code = 'pos.manage'
          )
        )
     );
$fn$;

comment on function payments.pos_shift_cashier_candidates(uuid) is
  'Active staff members whose branch-scoped role carries pos.manage, plus the '
  'owner role that holds every permission. The single source of truth behind '
  'the shift cashier picker and admin_pos_open_shift.';

revoke all on function payments.pos_shift_cashier_candidates(uuid)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. The picker feed
-- ---------------------------------------------------------------------------
create or replace function public.admin_pos_cashiers(p_branch_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_cashiers jsonb;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('pos.manage') then
    raise exception 'missing permission: pos.manage' using errcode = '42501';
  end if;
  if not identity.can_manage_branch(p_branch_id) then
    raise exception 'branch out of scope' using errcode = '42501';
  end if;

  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'id', c.cashier_id,
               'full_name', c.cashier_name,
               'is_self', c.is_self
             ) order by c.cashier_name, c.cashier_id
           ),
           '[]'::jsonb
         )
    into v_cashiers
    from payments.pos_shift_cashier_candidates(p_branch_id) c;

  return v_cashiers;
end;
$fn$;

comment on function public.admin_pos_cashiers(uuid) is
  'The staff members that a shift of this branch can be opened for.';

revoke all on function public.admin_pos_cashiers(uuid) from public, anon;
grant execute on function public.admin_pos_cashiers(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Opening the drawer for a chosen cashier
-- ---------------------------------------------------------------------------
drop function if exists public.admin_pos_open_shift(uuid, numeric, text);

create or replace function public.admin_pos_open_shift(
  p_branch_id     uuid,
  p_opening_float numeric,
  p_note          text default null,
  p_cashier_id    uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_staff_id    uuid;
  v_cashier_id  uuid;
  v_cashier     text;
  v_shift_id    uuid;
  v_existing    uuid;
  v_note        text;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('pos.manage') then
    raise exception 'missing permission: pos.manage' using errcode = '42501';
  end if;
  if not identity.can_manage_branch(p_branch_id) then
    raise exception 'branch out of scope' using errcode = '42501';
  end if;
  if not exists (
    select 1 from core.branches b where b.id = p_branch_id and b.is_active
  ) then
    raise exception 'branch not found or inactive' using errcode = 'P0002';
  end if;
  if p_opening_float is null
     or p_opening_float < 0
     or p_opening_float > 1000000 then
    raise exception 'invalid opening float' using errcode = '22023';
  end if;

  select sm.id
    into v_staff_id
    from identity.staff_members sm
   where sm.user_id = auth.uid()
     and sm.status = 'active';
  if v_staff_id is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  v_cashier_id := v_staff_id;
  if p_cashier_id is not null and p_cashier_id is distinct from v_staff_id then
    if not exists (
      select 1
      from payments.pos_shift_cashier_candidates(p_branch_id) c
      where c.cashier_id = p_cashier_id
    ) then
      raise exception 'cashier not eligible for this branch'
        using errcode = '22023';
    end if;
    v_cashier_id := p_cashier_id;
  end if;

  select sm.full_name
    into v_cashier
    from identity.staff_members sm
   where sm.id = v_cashier_id;

  v_note := left(btrim(coalesce(p_note, '')), 240);

  -- Opening twice is harmless: the first open shift is returned instead of
  -- creating a second drawer for the same branch.
  select s.id
    into v_existing
    from payments.pos_shifts s
   where s.branch_id = p_branch_id
     and s.status = 'open';
  if v_existing is not null then
    return payments.pos_shift_json(v_existing, true)
      || jsonb_build_object('already_open', true);
  end if;

  begin
    insert into payments.pos_shifts (
      branch_id, status, opening_float, opened_by, note
    ) values (
      p_branch_id, 'open', round(p_opening_float, 2), v_cashier_id, v_note
    )
    returning id into v_shift_id;
  exception
    when unique_violation then
      select s.id
        into v_shift_id
        from payments.pos_shifts s
       where s.branch_id = p_branch_id
         and s.status = 'open';
      if v_shift_id is null then
        raise;
      end if;
      return payments.pos_shift_json(v_shift_id, true)
        || jsonb_build_object('already_open', true);
  end;

  perform identity.audit(
    'pos.shift.open',
    'pos_shift',
    v_shift_id,
    null,
    jsonb_build_object(
      'branch_id', p_branch_id,
      'opening_float', round(p_opening_float, 2),
      'cashier_id', v_cashier_id,
      'cashier_name', coalesce(v_cashier, ''),
      'assigned_by_operator', v_cashier_id is distinct from v_staff_id,
      'operator_staff_id', v_staff_id
    ),
    p_branch_id
  );

  return payments.pos_shift_json(v_shift_id, true)
    || jsonb_build_object('already_open', false);
end;
$fn$;

comment on function public.admin_pos_open_shift(uuid, numeric, text, uuid) is
  'Opens the branch drawer with an opening float, in the name of p_cashier_id '
  'when one is given and eligible, and in the name of the caller otherwise. '
  'Idempotent while a shift is already open.';

revoke all on function public.admin_pos_open_shift(uuid, numeric, text, uuid)
  from public, anon;
grant execute on function public.admin_pos_open_shift(uuid, numeric, text, uuid)
  to authenticated;

notify pgrst, 'reload schema';
