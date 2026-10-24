-- 143_admin_permissions_and_staff_permission_toggle.sql
create or replace function public.admin_permissions()
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
    select jsonb_agg(jsonb_build_object('code', code, 'name_ar', name_ar, 'name_en', name_en) order by code)
    from identity.permissions
  ), '[]'::jsonb);
end;
$fn$;

create or replace function public.admin_set_staff_permission(
  p_staff_id uuid,
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
  if not identity.has_permission('admin.staff.write') then
    raise exception 'missing permission: admin.staff.write' using errcode = '42501';
  end if;

  select id into v_perm_id from identity.permissions where code = p_permission_code;
  if v_perm_id is null then
    raise exception 'unknown permission %', p_permission_code using errcode = '22023';
  end if;

  if p_granted then
    insert into identity.role_permissions (role_id, permission_id)
    select sr.role_id, v_perm_id
      from identity.staff_roles sr
     where sr.staff_id = p_staff_id
    on conflict do nothing;
  else
    delete from identity.role_permissions rp
     where rp.permission_id = v_perm_id
       and rp.role_id in (select role_id from identity.staff_roles where staff_id = p_staff_id);
  end if;
end;
$fn$;

revoke all on function public.admin_permissions() from public, anon;
grant execute on function public.admin_permissions() to authenticated;

revoke all on function public.admin_set_staff_permission(uuid, text, boolean) from public, anon;
grant execute on function public.admin_set_staff_permission(uuid, text, boolean) to authenticated;
