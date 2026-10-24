-- 142_admin_staff.sql
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
