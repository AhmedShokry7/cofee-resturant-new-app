-- Include the signed-storage input path for the authenticated employee so the
-- admin assistant can identify the employee's own messages in the conversation.
-- The function still returns only the active staff row for auth.uid().
create or replace function public.admin_get_my_staff_record()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_uid uuid := auth.uid();
  v_staff_id uuid;
  v_full_name text;
  v_email text;
  v_status text;
  v_avatar_url text;
  v_accepted_at timestamptz;
  v_roles jsonb;
  v_permissions jsonb;
  v_can_manage_all boolean;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  if not identity.is_staff() then
    raise exception 'not an active staff member' using errcode = '42501';
  end if;

  select sm.id, sm.full_name, sm.email, sm.status, sm.avatar_url, sm.accepted_at
    into v_staff_id, v_full_name, v_email, v_status, v_avatar_url, v_accepted_at
    from identity.staff_members sm
   where sm.user_id = v_uid and sm.status = 'active';

  if v_staff_id is null then
    raise exception 'staff record not found' using errcode = 'P0002';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
           'role_id', r.id,
           'role_code', r.code,
           'branch_id', sr.branch_id
         ) order by r.code, sr.branch_id), '[]'::jsonb)
    into v_roles
    from identity.staff_roles sr
    join identity.roles r on r.id = sr.role_id
   where sr.staff_id = v_staff_id;

  select coalesce(jsonb_agg(jsonb_build_object(
           'branch_id', sr.branch_id,
           'permissions', coalesce(
             (select jsonb_agg(p.code order by p.code)
              from identity.role_permissions rp
              join identity.permissions p on p.id = rp.permission_id
              where rp.role_id = sr.role_id),
             '[]'::jsonb
           )
         ) order by sr.branch_id), '[]'::jsonb)
    into v_permissions
    from identity.staff_roles sr
   where sr.staff_id = v_staff_id;

  select exists (
    select 1
      from identity.staff_roles sr
     where sr.staff_id = v_staff_id
       and sr.branch_id is null
  ) into v_can_manage_all;

  return jsonb_build_object(
    'staff_id', v_staff_id,
    'full_name', v_full_name,
    'email', v_email,
    'status', v_status,
    'avatar_url', v_avatar_url,
    'accepted_at', v_accepted_at,
    'roles', v_roles,
    'permissions', v_permissions,
    'can_manage_all_branches', v_can_manage_all
  );
end;
$fn$;

revoke all on function public.admin_get_my_staff_record() from public;
revoke execute on function public.admin_get_my_staff_record() from anon;
grant execute on function public.admin_get_my_staff_record() to authenticated;
