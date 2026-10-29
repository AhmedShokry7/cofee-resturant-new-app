-- 209_staff_profile_edit_and_avatar.sql
--
-- Gives the dashboard a way to edit a staff account — name, email, status,
-- picture — that the database actually allows it to use.
--
-- WHAT WAS MISSING
--   * `identity.staff_members` has no picture column at all: the staff page
--     renders `StaffAvatar` with no URL, so every row is initials forever.
--   * No RPC writes `full_name`, `email` or `status`. The staff feature has
--     three repository methods — load, load permissions, toggle a permission —
--     and `grep` for a staff write in `lib/` returns nothing. The owner of the
--     account is created by hand in the Supabase dashboard (see the wipe notes),
--     which is what this replaces.
--   * `admin_staff()` (142) returns every row to anyone with `admin.staff.read`
--     but no client can change any of it.
--   * `084_customer_profile_avatars.sql` scoped the whole `avatars` bucket to
--     `<auth.uid()>/…` folders, so a path under `staff/` could be neither read
--     nor written by the dashboard, and 208 only widened the customer case.
--
-- THE RULES THIS MIGRATION ENFORCES
--   * One guard function decides who may touch a staff row —
--     `identity.can_edit_staff(uuid)` — and both write RPCs consult it, so the
--     scope of an edit cannot drift apart from the scope of a picture.
--     An owner edits anyone; anyone else edits only staff who hold a role in a
--     branch they manage, never a staff account with a branch-less role, and
--     never an owner unless they are one. This mirrors the escalation and
--     branch checks of `identity.provision_staff` (080, 123).
--   * `status` is checked against the table's own constraint (004: invited /
--     active / suspended), and an admin may not change their own status. That
--     is not a permission judgement, it is the lockout guard: the only account
--     a manager can suspend with this RPC is the one they are signed in as.
--   * `avatar_url` stores a PATH, never a signed URL and never a public URL —
--     the same rule 084 set for customers, because a signed URL persisted would
--     be a dead link an hour later. The column is constrained to
--     `staff/<staff id>/<file>` so a row cannot point outside the folder of the
--     account it belongs to, and `admin_set_staff_image` re-checks the same
--     shape before writing.
--   * The picture is written by a definer RPC like 205 did for categories, not
--     by an `update identity.staff_members` from the client: 019 gave that table
--     a select policy for staff and 080 an insert policy, so a client-side write
--     would depend on table policies nobody has tested for updates.
--
-- NOT CHANGED
--   `identity.provision_staff`, the RBAC tables, `admin_set_staff_permission`
--   (143) — which still edits the shared role, so reassigning one staff member's
--   role to another is still not implemented here — the customer folder
--   policies of `avatars`, the delete policy of 084, and every grant 092 made.

-- ---------------------------------------------------------------------------
-- 1. The column, and the shape it accepts.
-- ---------------------------------------------------------------------------
alter table identity.staff_members
  add column if not exists avatar_url text;

comment on column identity.staff_members.avatar_url is
  'Path of the staff picture inside the private avatars bucket, always '
  'staff/<staff id>/<file>. Never a signed or public URL: see 084 and 208.';

do $$
begin
  if not exists (
    select 1
      from pg_constraint
     where conrelid = 'identity.staff_members'::regclass
       and conname = 'staff_members_avatar_path'
  ) then
    alter table identity.staff_members
      add constraint staff_members_avatar_path
      check (
        avatar_url is null
        or avatar_url ~ '^staff/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[^/]+$'
      );
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 2. Who may edit a staff account.
--
--    SECURITY DEFINER for the same reason as the helpers it calls: it reads
--    identity.staff_roles, and 080's policies are about writes. The caller's
--    own active membership is re-derived from auth.uid() here, never taken from
--    an argument.
-- ---------------------------------------------------------------------------
create or replace function identity.can_edit_staff(p_staff_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_uid uuid := auth.uid();
  v_caller_is_owner boolean;
  v_target_is_owner boolean;
begin
  if v_uid is null then
    return false;
  end if;

  if not exists (select 1 from identity.staff_members sm where sm.id = p_staff_id) then
    return false;
  end if;

  if not identity.has_permission('admin.staff.write') then
    return false;
  end if;

  select exists (
    select 1
      from identity.staff_members sm
      join identity.staff_roles sr on sr.staff_id = sm.id
      join identity.roles r on r.id = sr.role_id
     where sm.user_id = v_uid
       and sm.status = 'active'
       and r.code = 'owner'
  ) into v_caller_is_owner;

  if v_caller_is_owner then
    return true;
  end if;

  -- Below owner level, an owner account is out of reach in both directions:
  -- it cannot be edited, and its branch-less role cannot be used to prove scope.
  select exists (
    select 1
      from identity.staff_roles sr
      join identity.roles r on r.id = sr.role_id
     where sr.staff_id = p_staff_id
       and r.code = 'owner'
  ) into v_target_is_owner;

  if v_target_is_owner then
    return false;
  end if;

  if identity.manages_all_branches() then
    return true;
  end if;

  return exists (
    select 1
      from identity.staff_roles sr
     where sr.staff_id = p_staff_id
       and sr.branch_id is not null
       and identity.can_manage_branch(sr.branch_id)
  );
end;
$fn$;

comment on function identity.can_edit_staff(uuid) is
  'Whether the signed-in staff account may change the given staff account: '
  'admin.staff.write plus an owner/branch scope that matches provisioning. '
  'Never a global role for a branch-only caller, never an owner for a non-owner.';

revoke all on function identity.can_edit_staff(uuid) from public, anon;
grant execute on function identity.can_edit_staff(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 2b. The same scope on the table itself.
--
--     `019_rls_01_identity.sql:40` let anyone with `admin.staff.write` update
--     ANY staff row — including an owner's, and including their own status.
--     Measured against the live database, that policy was never reachable by the
--     dashboard: `authenticated` holds no SELECT on identity.staff_members, and
--     an UPDATE has to read the row, so a direct write is refused with 42501 one
--     layer before any policy is consulted (staff_profile_edit_and_avatar_test
--     section 7 asserts that). The replacement is defence in depth — the shape
--     the table would enforce if that grant ever returns is the shape the RPCs
--     already use, so the two cannot drift apart.
--     It also means no client of this migration can update the table directly:
--     every edit goes through admin_update_staff / admin_set_staff_image.
-- ---------------------------------------------------------------------------
drop policy if exists staff_update_permitted on identity.staff_members;
create policy staff_update_permitted
  on identity.staff_members
  for update
  to authenticated
  using (identity.can_edit_staff(id))
  with check (identity.can_edit_staff(id));

-- ---------------------------------------------------------------------------
-- 3. Editing the account itself.
--
--    A null argument means "leave that field alone", so one dialog can send
--    everything it holds without turning a blank box into a change.
-- ---------------------------------------------------------------------------
create or replace function public.admin_update_staff(
  p_staff_id uuid,
  p_full_name text,
  p_email text,
  p_status text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_uid uuid := auth.uid();
  v_self uuid;
  v_name text := nullif(btrim(coalesce(p_full_name, '')), '');
  v_email text := lower(nullif(btrim(coalesce(p_email, '')), ''));
  v_status text := nullif(btrim(coalesce(p_status, '')), '');
  v_old record;
  v_other_id uuid;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  if not identity.can_edit_staff(p_staff_id) then
    raise exception 'missing permission: admin.staff.write' using errcode = '42501';
  end if;

  select sm.full_name, sm.email, sm.status into v_old
    from identity.staff_members sm
   where sm.id = p_staff_id;

  -- A manager suspending or re-inviting the account they are signed in as would
  -- end their own session with no way back; the dashboard itself is the fix.
  select sm.id into v_self from identity.staff_members sm where sm.user_id = v_uid;
  if v_status is not null and p_staff_id = v_self then
    return jsonb_build_object('ok', false, 'reason', 'self_status');
  end if;

  if p_full_name is not null and (v_name is null or char_length(v_name) < 2) then
    return jsonb_build_object('ok', false, 'reason', 'invalid_name');
  end if;

  if p_email is not null and (
    v_email is null or v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'
  ) then
    return jsonb_build_object('ok', false, 'reason', 'invalid_email');
  end if;

  if p_status is not null and p_status not in ('invited', 'active', 'suspended') then
    return jsonb_build_object('ok', false, 'reason', 'invalid_status');
  end if;

  if v_email is not null then
    select sm.id into v_other_id
      from identity.staff_members sm
     where sm.email = v_email
       and sm.id <> p_staff_id;
    if v_other_id is not null then
      return jsonb_build_object('ok', false, 'reason', 'duplicate_email');
    end if;
  end if;

  update identity.staff_members
     set full_name = coalesce(v_name, full_name),
         email = coalesce(v_email, email),
         status = coalesce(v_status, status),
         suspended_at = case
           when v_status is null then suspended_at
           when v_status = 'suspended' then now()
           else null
         end
   where id = p_staff_id;

  perform identity.audit(
    'staff.update',
    'staff_member',
    p_staff_id,
    jsonb_build_object(
      'full_name', v_old.full_name,
      'email', v_old.email,
      'status', v_old.status
    ),
    jsonb_build_object(
      'full_name', coalesce(v_name, v_old.full_name),
      'email', coalesce(v_email, v_old.email),
      'status', coalesce(v_status, v_old.status)
    )
  );

  return jsonb_build_object('ok', true);
end;
$fn$;

comment on function public.admin_update_staff(uuid, text, text, text) is
  'Change the name, email or status of a staff account the caller manages. '
  'Null arguments are left untouched. Audits old and new values.';

revoke all on function public.admin_update_staff(uuid, text, text, text)
  from public, anon;
grant execute on function public.admin_update_staff(uuid, text, text, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 4. The picture row.
--
--    The bytes go to the bucket through the storage API under the new policies
--    in section 5; this writes only the path, and refuses a path that is not
--    inside the folder of this staff account.
-- ---------------------------------------------------------------------------
create or replace function public.admin_set_staff_image(
  p_staff_id uuid,
  p_avatar_url text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_path text := nullif(btrim(coalesce(p_avatar_url, '')), '');
  v_folder text := 'staff/' || p_staff_id::text || '/';
  v_file text;
  v_old text;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  if not identity.can_edit_staff(p_staff_id) then
    raise exception 'missing permission: admin.staff.write' using errcode = '42501';
  end if;

  select avatar_url into v_old
    from identity.staff_members
   where id = p_staff_id;

  -- Compared by prefix and length rather than by rebuilding the path from its
  -- segments: a value with fewer segments would make the rebuilt string null,
  -- and a null condition would have let the write through to the column
  -- constraint, which answers an operator with 23514 instead of a reason.
  if v_path is not null then
    if left(v_path, length(v_folder)) <> v_folder then
      return jsonb_build_object('ok', false, 'reason', 'invalid_path');
    end if;
    v_file := substr(v_path, length(v_folder) + 1);
    if v_file = '' or position('/' in v_file) > 0 then
      return jsonb_build_object('ok', false, 'reason', 'invalid_path');
    end if;
  end if;

  update identity.staff_members
     set avatar_url = v_path
   where id = p_staff_id;

  perform identity.audit(
    'staff.image',
    'staff_member',
    p_staff_id,
    jsonb_build_object('avatar_url', v_old),
    jsonb_build_object('avatar_url', v_path)
  );

  return jsonb_build_object('ok', true);
end;
$fn$;

comment on function public.admin_set_staff_image(uuid, text) is
  'Record or clear the avatars-bucket path of a staff picture. The path must be '
  'inside staff/<staff id>/. Audits the replaced path.';

revoke all on function public.admin_set_staff_image(uuid, text) from public, anon;
grant execute on function public.admin_set_staff_image(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 5. Storage policies for the staff folders of the private avatars bucket.
--
--    208 widened reading for customer photos; a staff photo lives one folder up
--    (`staff/<staff id>/…`), so its first segment is the literal 'staff' and no
--    owner check of 084 can ever match it. These policies are the staff side of
--    the same decision: the bucket stays private, the dashboard signs links.
--
--    Read is scoped to `admin.staff.read` — the permission `admin_staff()`
--    already requires, so a page can only display pictures it could list.
--    Write is scoped to `admin.staff.write`, the same one the edit RPCs check,
--    so no one can put bytes somewhere they cannot then name in the row.
-- ---------------------------------------------------------------------------
drop policy if exists "avatars_select_staff_folder" on storage.objects;
create policy "avatars_select_staff_folder"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = 'staff'
    and identity.has_permission('admin.staff.read')
  );

drop policy if exists "avatars_insert_staff_folder" on storage.objects;
create policy "avatars_insert_staff_folder"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = 'staff'
    and identity.has_permission('admin.staff.write')
  );

drop policy if exists "avatars_update_staff_folder" on storage.objects;
create policy "avatars_update_staff_folder"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = 'staff'
    and identity.has_permission('admin.staff.write')
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = 'staff'
    and identity.has_permission('admin.staff.write')
  );

drop policy if exists "avatars_delete_staff_folder" on storage.objects;
create policy "avatars_delete_staff_folder"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = 'staff'
    and identity.has_permission('admin.staff.write')
  );

-- ---------------------------------------------------------------------------
-- 6. The directory now carries the picture path.
--
--    Same body as 142 with one key added, so nothing that reads the JSON loses
--    a field. The value stays a path: `AdminAvatarLinks` turns it into a
--    short-lived signed URL on the way to the widget (208).
-- ---------------------------------------------------------------------------
create or replace function public.admin_staff()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('admin.staff.read') then
    raise exception 'missing permission: admin.staff.read' using errcode = '42501';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', sm.id,
      'user_id', sm.user_id,
      'full_name', sm.full_name,
      'email', sm.email,
      'status', sm.status,
      'avatar_url', sm.avatar_url,
      'created_at', sm.created_at,
      'accepted_at', sm.accepted_at,
      'roles', coalesce((
        select jsonb_agg(jsonb_build_object(
          'role_id', sr.role_id,
          'role_code', r.code,
          'branch_id', sr.branch_id
        ) order by r.code)
        from identity.staff_roles sr
        join identity.roles r on r.id = sr.role_id
        where sr.staff_id = sm.id
      ), '[]'::jsonb),
      'permissions', coalesce((
        select jsonb_agg(distinct p.code order by p.code)
        from identity.staff_roles sr
        join identity.role_permissions rp on rp.role_id = sr.role_id
        join identity.permissions p on p.id = rp.permission_id
        where sr.staff_id = sm.id
      ), '[]'::jsonb)
    ) order by sm.created_at)
    from identity.staff_members sm
  ), '[]'::jsonb);
end;
$fn$;

revoke all on function public.admin_staff() from public, anon;
grant execute on function public.admin_staff() to authenticated;

notify pgrst, 'reload schema';
