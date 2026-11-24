-- custom_roles_and_permission_guards_test.sql
--
-- Exercises 267_custom_role_management.sql inside a rolled-back transaction.
-- Every RPC is called as a real authenticated JWT (owner, then a manager who
-- holds admin.role.write but is not the owner).
--
-- PREREQUISITES: 004 (roles/permissions), 267 (the RPCs under test).
-- The fixture rows use fixed, test-only ids and are rolled back.

begin;

insert into auth.users (id, email) values
  ('a1000000-0000-4000-8000-000000000001', 'role-owner@test.local'),
  ('a1000000-0000-4000-8000-000000000002', 'role-manager@test.local');

insert into identity.profiles (id, full_name, email)
values
  ('a1000000-0000-4000-8000-000000000001', 'Role Owner', 'role-owner@test.local'),
  ('a1000000-0000-4000-8000-000000000002', 'Role Manager', 'role-manager@test.local')
on conflict (id) do nothing;

insert into identity.staff_members (id, user_id, status, full_name, email)
values
  ('b1000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001',
   'active', 'Role Owner', 'role-owner@test.local'),
  ('b1000000-0000-4000-8000-000000000002', 'a1000000-0000-4000-8000-000000000002',
   'active', 'Role Manager', 'role-manager@test.local');

-- The manager role is the least-powerful role that can call the role RPCs.
-- It deliberately does NOT hold orders.cancel, so the grant guard is testable.
insert into identity.roles (code, name_ar, name_en, description, is_system)
values ('tmp_role_manager', 'مدير أدوار اختبار', 'Test Role Manager',
        'temporary test role', false);

insert into identity.role_permissions (role_id, permission_id)
select r.id, p.id
  from identity.roles r
  join identity.permissions p on p.code in (
    'admin.role.read', 'admin.role.write', 'orders.read', 'orders.status.update'
  )
 where r.code = 'tmp_role_manager';

insert into identity.staff_roles (staff_id, role_id, branch_id)
select 'b1000000-0000-4000-8000-000000000001', r.id, null
  from identity.roles r where r.code = 'owner';

insert into identity.staff_roles (staff_id, role_id, branch_id)
select 'b1000000-0000-4000-8000-000000000002', r.id, null
  from identity.roles r where r.code = 'tmp_role_manager';

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"a1000000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}',
  true);

-- ---------------------------------------------------------------------------
-- 1. Owner creates a custom role; names/description/perm set are persisted.
-- ---------------------------------------------------------------------------
do $$
declare
  v_id uuid;
  v_role identity.roles%rowtype;
  v_codes text[];
begin
  v_id := public.admin_create_role(
    '  دور تجريبي  ', 'Custom Role AR', '  وصف  ', array['orders.read', 'orders.read']);

  select * into v_role from identity.roles where id = v_id;
  if v_role.name_ar <> 'دور تجريبي' or v_role.name_en <> 'Custom Role AR' then
    raise exception 'FAIL 1a: names were not normalized (%)', v_role;
  end if;
  if v_role.description <> 'وصف' or v_role.is_system then
    raise exception 'FAIL 1b: description/system flag wrong (%)', v_role;
  end if;
  if v_role.code !~ '^[a-z_]+$' then
    raise exception 'FAIL 1c: generated code violates the table check (%)', v_role.code;
  end if;

  select array_agg(p.code order by p.code) into v_codes
    from identity.role_permissions rp
    join identity.permissions p on p.id = rp.permission_id
   where rp.role_id = v_id;
  if v_codes <> array['orders.read'] then
    raise exception 'FAIL 1d: permission set is %', v_codes;
  end if;

  -- Same name, different case and outer spaces: duplicate by design.
  begin
    perform public.admin_create_role('دور تجريبي', '  custom role ar  ', null, '{}');
    raise exception 'FAIL 1e: duplicate name was accepted';
  exception
    when unique_violation then null;
  end;

  begin
    perform public.admin_create_role('', 'No Arabic', null, '{}');
    raise exception 'FAIL 1f: empty Arabic name was accepted';
  exception
    when others then
      if sqlstate <> '22023' then raise; end if;
  end;

  begin
    perform public.admin_create_role('دور ثان', 'Second Role', null, array['not.a.permission']);
    raise exception 'FAIL 1g: unknown permission was accepted';
  exception
    when others then
      if sqlstate <> '22023' then raise; end if;
  end;

  -- The owner may grant an owner-only permission; a non-owner may not revoke it.
  perform public.admin_create_role('دور مالك فقط', 'Owner Only Target', null,
                                   array['marketing.consent.write']);
end $$;

-- ---------------------------------------------------------------------------
-- 2. Non-owner can create only with permissions held; owner-only stays owner.
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"a1000000-0000-4000-8000-000000000002","role":"authenticated","aud":"authenticated"}',
  true);

do $$
declare v_id uuid;
begin
  v_id := public.admin_create_role('دور مدير', 'Manager Made Role', null,
                                   array['orders.read']);
  if v_id is null then
    raise exception 'FAIL 2a: manager could not create a role with a held permission';
  end if;

  begin
    perform public.admin_create_role('دور مرفوض', 'Rejected Role', null,
                                     array['orders.cancel']);
    raise exception 'FAIL 2b: manager granted a permission they do not hold';
  exception
    when others then
      if sqlstate <> '42501' then raise; end if;
  end;

  begin
    perform public.admin_create_role('دور مالك', 'Owner Permission Role', null,
                                     array['admin.role.write']);
    raise exception 'FAIL 2c: manager granted an owner-only permission';
  exception
    when others then
      if sqlstate <> '42501' then raise; end if;
  end;

  -- The catalogue must tell the editor what it may add and what it may remove.
  if not exists (
    select 1 from jsonb_array_elements(public.admin_permissions()) e
     where e ->> 'code' = 'orders.read'
       and (e ->> 'can_grant')::boolean
       and (e ->> 'can_revoke')::boolean
  ) then
    raise exception 'FAIL 2d: held permission is not marked grantable/revocable';
  end if;
  if not exists (
    select 1 from jsonb_array_elements(public.admin_permissions()) e
     where e ->> 'code' = 'orders.cancel'
       and not (e ->> 'can_grant')::boolean
       and (e ->> 'can_revoke')::boolean
  ) then
    raise exception 'FAIL 2e: unheld permission lost its revoke capability';
  end if;
  if not exists (
    select 1 from jsonb_array_elements(public.admin_permissions()) e
     where e ->> 'code' = 'marketing.consent.write'
       and not (e ->> 'can_grant')::boolean
       and not (e ->> 'can_revoke')::boolean
  ) then
    raise exception 'FAIL 2f: owner-only permission is not locked from both sides';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 3. Update replaces the whole set atomically and keeps ids stable.
-- ---------------------------------------------------------------------------
do $$
declare
  v_id uuid;
  v_role identity.roles%rowtype;
  v_codes text[];
begin
  select id into v_id from identity.roles where code = 'tmp_role_manager';

  -- Self-held role: even the name change is refused.
  begin
    perform public.admin_update_role(v_id, 'اسم جديد', 'New Manager Name', null, '{}');
    raise exception 'FAIL 3a: manager modified the role they hold';
  exception
    when others then
      if sqlstate <> '42501' then raise; end if;
  end;

  -- A role the manager does not hold, adding a permission they do hold.
  select id into v_id from identity.roles where name_en = 'Manager Made Role';
  perform public.admin_update_role(v_id, 'دور محدث', 'Updated Manager Role', 'new desc',
                                   array['orders.read', 'orders.status.update']);

  select * into v_role from identity.roles where id = v_id;
  if v_role.name_ar <> 'دور محدث' or v_role.name_en <> 'Updated Manager Role'
     or v_role.description <> 'new desc' then
    raise exception 'FAIL 3b: update did not persist names/description (%)', v_role;
  end if;

  select array_agg(p.code order by p.code) into v_codes
    from identity.role_permissions rp
    join identity.permissions p on p.id = rp.permission_id
   where rp.role_id = v_id;
  if v_codes <> array['orders.read', 'orders.status.update'] then
    raise exception 'FAIL 3c: update did not replace the set (%)', v_codes;
  end if;

  begin
    perform public.admin_update_role(v_id, 'دور محدث', 'Updated Manager Role', 'new desc',
                                     array['orders.read', 'orders.cancel']);
    raise exception 'FAIL 3d: update added an unheld permission';
  exception
    when others then
      if sqlstate <> '42501' then raise; end if;
  end;

  -- Removing an owner-only permission is as forbidden as adding one.
  select id into v_id from identity.roles where name_en = 'Owner Only Target';
  begin
    perform public.admin_update_role(v_id, 'دور مالك فقط', 'Owner Only Target',
                                     null, '{}');
    raise exception 'FAIL 3d2: manager revoked an owner-only permission';
  exception
    when others then
      if sqlstate <> '42501' then raise; end if;
  end;

  begin
    perform public.admin_update_role(
      (select id from identity.roles where code = 'owner'),
      'Owner', 'Owner', null, '{}');
    raise exception 'FAIL 3e: owner role was modified';
  exception
    when others then
      if sqlstate <> '42501' then raise; end if;
  end;
end $$;

-- ---------------------------------------------------------------------------
-- 4. Single-permission write path keeps the same grant guard.
-- ---------------------------------------------------------------------------
do $$
declare v_target uuid;
begin
  select id into v_target from identity.roles where name_en = 'Updated Manager Role';
  begin
    perform public.admin_set_role_permission(v_target, 'orders.cancel', true);
    raise exception 'FAIL 4a: single-permission path bypassed the grant guard';
  exception
    when others then
      if sqlstate <> '42501' then raise; end if;
  end;
end $$;

-- ---------------------------------------------------------------------------
-- 5. System role identity stays immutable for the owner too; permissions stay
--    editable for non-owner roles, matching the old toggle behaviour.
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"a1000000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}',
  true);

do $$
declare
  v_cashier uuid;
  v_name_ar text;
  v_name_en text;
  v_description text;
  v_before text[];
  v_after text[];
begin
  select id, name_ar, name_en, description into v_cashier, v_name_ar, v_name_en, v_description
    from identity.roles where code = 'cashier';
  if v_cashier is null then
    raise exception 'FAIL 5a: cashier role is missing from the fixture database';
  end if;
  begin
    perform public.admin_update_role(v_cashier, 'كاشير معدل', 'Changed Cashier', null, null);
    raise exception 'FAIL 5b: system role name was changed';
  exception
    when others then
      if sqlstate <> '42501' then raise; end if;
  end;

  select coalesce(array_agg(p.code order by p.code), '{}'::text[]) into v_before
    from identity.role_permissions rp join identity.permissions p on p.id = rp.permission_id
   where rp.role_id = v_cashier;
  perform public.admin_update_role(v_cashier, v_name_ar, v_name_en, v_description,
                                   array['orders.read']);
  select coalesce(array_agg(p.code order by p.code), '{}'::text[]) into v_after
    from identity.role_permissions rp join identity.permissions p on p.id = rp.permission_id
   where rp.role_id = v_cashier;
  if v_after <> array['orders.read'] then
    raise exception 'FAIL 5c: system role permissions were not editable (%)', v_after;
  end if;
  perform public.admin_update_role(v_cashier, v_name_ar, v_name_en, v_description, v_before);
end $$;

rollback;
