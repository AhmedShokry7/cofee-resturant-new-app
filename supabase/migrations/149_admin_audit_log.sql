-- 149_admin_audit_log.sql
create or replace function public.admin_audit_log(p_limit int default 200)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('audit.read') then
    raise exception 'missing permission: audit.read' using errcode = '42501';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', a.id,
      'actor_user_id', a.actor_user_id,
      'actor_name', p.full_name,
      'actor_email', p.email,
      'actor_role', a.actor_role,
      'action', a.action,
      'entity_type', a.entity_type,
      'entity_id', a.entity_id,
      'branch_id', a.branch_id,
      'branch_name_ar', b.name_ar,
      'branch_name_en', b.name_en,
      'old_values', a.old_values,
      'new_values', a.new_values,
      'created_at', a.created_at
    ) order by a.created_at desc)
    from identity.audit_log a
    left join identity.profiles p on p.id = a.actor_user_id
    left join core.branches b on b.id = a.branch_id
    limit greatest(1, least(p_limit, 500))
  ), '[]'::jsonb);
end;
$fn$;

revoke all on function public.admin_audit_log(int) from public, anon;
grant execute on function public.admin_audit_log(int) to authenticated;
