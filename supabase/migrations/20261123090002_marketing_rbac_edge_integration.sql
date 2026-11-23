-- Official migration: Marketing Hub P0.6 (derived from approved local proposal
-- supabase/proposals/p05_marketing_rbac_edge_integration.PROPOSED.sql).
-- Purpose: marketing permissions seed + owner-only guard replacement for
-- admin_set_role_permission (251). Edge consent/channel contract in handlers.
-- see RBAC ESCALATION GUARD below).
-- Tests: supabase/tests/marketing_hub_rbac_test.sql

insert into identity.permissions (code, name_ar, name_en, description) values
  ('marketing.read', 'قراءة التسويق', 'Read marketing', 'List and inspect marketing campaigns'),
  ('marketing.create', 'إنشاء التسويق', 'Create marketing', 'Create and edit draft campaigns'),
  ('marketing.review', 'مراجعة التسويق', 'Review marketing', 'Approve or return campaigns for review'),
  ('marketing.schedule', 'جدولة التسويق', 'Schedule marketing', 'Schedule approved campaigns'),
  ('marketing.send', 'إرسال التسويق', 'Send marketing', 'Pause, resume, and cancel campaign executions'),
  ('marketing.consent.read', 'قراءة موافقات التسويق', 'Read marketing consent', 'View customer marketing consent state'),
  ('marketing.consent.write', 'كتابة موافقات التسويق', 'Write marketing consent', 'Record consent through staff support path only')
on conflict (code) do update
  set name_ar = excluded.name_ar,
      name_en = excluded.name_en,
      description = excluded.description;

-- Conservative default assignment. Owner remains implicit in has_permission().
-- marketing.consent.write is intentionally NOT granted to manager by default.
insert into identity.role_permissions (role_id, permission_id)
select r.id, p.id
  from identity.roles r
  join identity.permissions p
    on p.code in (
      'marketing.read',
      'marketing.create',
      'marketing.review',
      'marketing.schedule',
      'marketing.send',
      'marketing.consent.read'
    )
 where r.code = 'manager'
on conflict do nothing;

insert into identity.role_permissions (role_id, permission_id)
select r.id, p.id
  from identity.roles r
  join identity.permissions p on p.code = 'marketing.read'
 where r.code = 'branch_manager'
on conflict do nothing;

-- cashier and generic staff receive no marketing permissions by default.

-- ---------------------------------------------------------------------------
-- RBAC ESCALATION GUARD (proposed replacement for 251 admin_set_role_permission)
-- ---------------------------------------------------------------------------
-- 251's guard is only `admin.role.write`. Any manager with that permission can
-- grant `marketing.consent.write` to any non-owner role, including their own.
-- This proposal replaces the RPC inside the RBAC layer (not the UI) with
-- explicit owner-only protection for sensitive permissions and self-grant.
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
  v_role_code text;
  v_perm_id uuid;
  v_caller_is_owner boolean := false;
  v_caller_holds_target boolean := false;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('admin.role.write') then
    raise exception 'missing permission: admin.role.write' using errcode = '42501';
  end if;

  select code into v_role_code from identity.roles where id = p_role_id;
  if v_role_code is null then
    raise exception 'role not found' using errcode = 'P0002';
  end if;
  if v_role_code = 'owner' then
    raise exception 'owner role permissions are implicit and cannot be changed'
      using errcode = '42501';
  end if;
  if p_granted is null then
    raise exception 'granted flag is required' using errcode = '22023';
  end if;

  select id into v_perm_id from identity.permissions where code = p_permission_code;
  if v_perm_id is null then
    raise exception 'unknown permission %', p_permission_code using errcode = '22023';
  end if;

  -- Caller is owner only if explicitly assigned the owner role through
  -- staff_members (staff_roles.staff_id references staff_members.id, never
  -- auth.users directly; 004). Mirrors identity.has_permission resolution.
  select exists (
    select 1
      from identity.staff_members sm
      join identity.staff_roles sr on sr.staff_id = sm.id
      join identity.roles r on r.id = sr.role_id
     where sm.user_id = auth.uid()
       and sm.status = 'active'
       and r.code = 'owner'
  ) into v_caller_is_owner;

  select exists (
    select 1
      from identity.staff_members sm
      join identity.staff_roles sr on sr.staff_id = sm.id
     where sm.user_id = auth.uid()
       and sm.status = 'active'
       and sr.role_id = p_role_id
  ) into v_caller_holds_target;

  -- Owner-only sensitive permissions: cannot be granted/revoked by non-owners.
  if p_permission_code in ('marketing.consent.write', 'admin.role.write')
     and not v_caller_is_owner then
    raise exception 'owner-only permission: %', p_permission_code using errcode = '42501';
  end if;

  -- No self-escalation: non-owners cannot modify a role they themselves hold.
  if v_caller_holds_target and not v_caller_is_owner then
    raise exception 'cannot modify a role you hold' using errcode = '42501';
  end if;

  if p_granted then
    insert into identity.role_permissions (role_id, permission_id)
    values (p_role_id, v_perm_id)
    on conflict do nothing;
  else
    delete from identity.role_permissions
     where role_id = p_role_id and permission_id = v_perm_id;
  end if;
end;
$fn$;

revoke all on function public.admin_set_role_permission(uuid, text, boolean)
  from public, anon;
grant execute on function public.admin_set_role_permission(uuid, text, boolean)
  to authenticated;

-- Edge integration contract (implemented in send-push/send-email handlers):
--   * promo -> purpose promotions, loyalty -> loyalty_marketing
--   * DB-backed marketing.campaign_recipients.notification_id is the only
--     trusted channel/purpose source; request payload marketing keys are ignored.
--   * push/email handlers skip channel_not_targeted when recipient.channel
--     differs from the handler channel.
--   * missing/revoked consent skips before provider calls.
--   * email also requires verified Auth email matching profiles.email.
--   * operational order_status/system types remain under existing preference rules.
