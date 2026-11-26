-- Let staff managers remove an invitation record after confirming in the UI.
-- Deleting an accepted invitation never deletes the employee account; it only
-- removes that invitation from the sent-invitations history.
create or replace function public.admin_delete_staff_invitation(
  p_invitation_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_uid uuid := auth.uid();
  v_invitation identity.staff_invitations%rowtype;
begin
  if v_uid is null or not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('admin.staff.write') then
    raise exception 'missing permission: admin.staff.write' using errcode = '42501';
  end if;

  select * into v_invitation
    from identity.staff_invitations
   where id = p_invitation_id
   for update;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;

  if v_invitation.branch_id is null then
    if not identity.manages_all_branches() then
      raise exception 'out of scope' using errcode = '42501';
    end if;
  elsif not identity.can_manage_branch(v_invitation.branch_id) then
    raise exception 'out of scope' using errcode = '42501';
  end if;

  perform identity.audit(
    'staff.invite.delete',
    'staff_invitation',
    v_invitation.id,
    jsonb_build_object(
      'email', v_invitation.email,
      'full_name', v_invitation.full_name,
      'status', v_invitation.status
    ),
    null,
    v_invitation.branch_id
  );

  delete from identity.staff_invitations where id = v_invitation.id;
  return jsonb_build_object('ok', true);
end;
$fn$;

comment on function public.admin_delete_staff_invitation(uuid) is
  'Delete one invitation record in the caller’s manageable branch scope. '
  'Requires admin.staff.write and records an audit event. Accepted staff accounts remain untouched.';

revoke all on function public.admin_delete_staff_invitation(uuid) from public, anon;
grant execute on function public.admin_delete_staff_invitation(uuid) to authenticated;

notify pgrst, 'reload schema';
