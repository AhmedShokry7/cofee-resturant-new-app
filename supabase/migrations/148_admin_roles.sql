-- 148_admin_roles.sql
insert into identity.role_permissions (role_id, permission_id)
select r.id, p.id
  from identity.roles r
  cross join identity.permissions p
 where r.code = 'manager'
   and p.code = 'admin.role.write'
on conflict do nothing;

create or replace function public.admin_roles()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('admin.role.read') then
    raise exception 'missing permission: admin.role.read' using errcode = '42501';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', r.id,
      'code', r.code,
      'name_ar', r.name_ar,
      'name_en', r.name_en,
      'is_system', r.is_system,
      'permissions', coalesce((
        select jsonb_agg(p.code order by p.code)
        from identity.role_permissions rp
        join identity.permissions p on p.id = rp.permission_id
        where rp.role_id = r.id
      ), '[]'::jsonb)
    ) order by r.code)
    from identity.roles r
  ), '[]'::jsonb);
end;
$fn$;

create or replace function public.admin_set_role_permission(
  p_role_id uuid,
  p_permission_code text,
  p_granted boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_perm_id uuid;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('admin.role.write') then
    raise exception 'missing permission: admin.role.write' using errcode = '42501';
  end if;

  select id into v_perm_id from identity.permissions where code = p_permission_code;
  if v_perm_id is null then
    raise exception 'unknown permission %', p_permission_code using errcode = '22023';
  end if;

  if p_granted then
    insert into identity.role_permissions (role_id, permission_id)
    values (p_role_id, v_perm_id)
    on conflict do nothing;
  else
    delete from identity.role_permissions
     where role_id = p_role_id
       and permission_id = v_perm_id;
  end if;
end;
$fn$;

revoke all on function public.admin_roles() from public, anon;
grant execute on function public.admin_roles() to authenticated;

revoke all on function public.admin_set_role_permission(uuid, text, boolean) from public, anon;
grant execute on function public.admin_set_role_permission(uuid, text, boolean) to authenticated;
