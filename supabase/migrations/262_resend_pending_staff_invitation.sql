-- Let an administrator resend a live invitation without creating a second one.
-- The existing token is returned only after the caller's staff permission and
-- branch scope have been checked again.

create or replace function public.admin_resend_staff_invitation(p_email text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_uid uuid := auth.uid();
  v_caller identity.staff_members%rowtype;
  v_invitation identity.staff_invitations%rowtype;
begin
  if v_uid is null or not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  select * into v_caller
    from identity.staff_members
   where user_id = v_uid
     and status = 'active';
  if not found or not identity.has_permission('admin.staff.write') then
    raise exception 'missing permission: admin.staff.write' using errcode = '42501';
  end if;

  select * into v_invitation
    from identity.staff_invitations
   where email = lower(btrim(coalesce(p_email, '')))
     and status = 'pending'
     and expires_at > now()
   order by created_at desc
   limit 1
   for update;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'invitation_not_found');
  end if;

  if v_invitation.branch_id is null then
    if not identity.manages_all_branches() then
      return jsonb_build_object('ok', false, 'reason', 'not_your_branch');
    end if;
  elsif not identity.can_manage_branch(v_invitation.branch_id) then
    return jsonb_build_object('ok', false, 'reason', 'not_your_branch');
  end if;

  if v_invitation.role_code = 'owner' and not exists (
    select 1
      from identity.staff_roles sr
      join identity.roles r on r.id = sr.role_id
     where sr.staff_id = v_caller.id
       and r.code = 'owner'
  ) then
    return jsonb_build_object('ok', false, 'reason', 'owner_only');
  end if;

  perform identity.audit(
    'staff.invite.resend',
    'staff_invitation',
    v_invitation.id,
    null,
    jsonb_build_object('email', v_invitation.email),
    v_invitation.branch_id
  );

  return jsonb_build_object(
    'ok', true,
    'invitation_id', v_invitation.id,
    'token', v_invitation.token,
    'email', v_invitation.email,
    'full_name', v_invitation.full_name,
    'role_code', v_invitation.role_code,
    'branch_id', v_invitation.branch_id,
    'expires_at', v_invitation.expires_at
  );
end;
$fn$;

comment on function public.admin_resend_staff_invitation(text) is
  'Return a live invitation to an authorized admin for a resend, after checking '
  'the current branch scope and owner-role restriction.';

revoke all on function public.admin_resend_staff_invitation(text) from public, anon;
grant execute on function public.admin_resend_staff_invitation(text) to authenticated;

notify pgrst, 'reload schema';
