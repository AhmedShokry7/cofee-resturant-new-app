-- 267_custom_role_management.sql
--
-- Custom roles and rule-enforced permission management.
--
-- Before this file the admin UI could only toggle one permission on one
-- existing role. There was no create/update RPC, no duplicate-name rule, and
-- a manager holding admin.role.write could grant any permission they did not
-- hold. This migration adds the missing role commands and closes that gap
-- inside the database, not in the Flutter form.
--
-- Rules enforced here:
--   * admin.role.write is still required for every write; owner is implicit.
--   * owner role is immutable.
--   * a non-owner cannot modify a role they hold themselves.
--   * a non-owner may add only permissions they already hold.
--   * admin.role.write and marketing.consent.write stay owner-only.
--   * custom role names are unique (case-insensitive, both languages).
--   * system role names/descriptions are immutable; their permissions remain
--     editable, matching the previous admin_set_role_permission behaviour.
--   * branch scoping is untouched: permissions are global and staff_roles
--     keeps carrying the branch. No existing role/staff assignment is altered.
--
-- The duplicate-name check is deliberately a function check, not a unique
-- index: the Phase 1.3 test fixtures create throw-away roles with the same
-- names on every run, and an index would break that harness.

create or replace function identity.role_name_taken(
  p_name_ar text,
  p_name_en text,
  p_exclude_id uuid default null
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $fn$
  select exists (
    select 1
      from identity.roles r
     where (p_exclude_id is null or r.id <> p_exclude_id)
       and (
         lower(btrim(r.name_ar)) in (
           lower(btrim(coalesce(p_name_ar, ''))),
           lower(btrim(coalesce(p_name_en, '')))
         )
         or lower(btrim(r.name_en)) in (
           lower(btrim(coalesce(p_name_ar, ''))),
           lower(btrim(coalesce(p_name_en, '')))
         )
       )
  );
$fn$;

comment on function identity.role_name_taken(text, text, uuid) is
  'Case-insensitive duplicate-role-name probe across both language columns.';

revoke all on function identity.role_name_taken(text, text, uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Permission catalogue: same rows, plus description and whether the caller
-- may grant the permission. The role editor uses can_grant to disable checks
-- the server would reject anyway.
-- ---------------------------------------------------------------------------
create or replace function public.admin_permissions()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_caller_is_owner boolean := false;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not (identity.has_permission('admin.role.read')
          or identity.has_permission('admin.staff.read')
          or identity.has_permission('admin.role.write')) then
    raise exception 'missing permission: admin.role.read, admin.staff.read or admin.role.write'
      using errcode = '42501';
  end if;

  select exists (
    select 1
      from identity.staff_members sm
      join identity.staff_roles sr on sr.staff_id = sm.id
      join identity.roles r on r.id = sr.role_id
     where sm.user_id = auth.uid()
       and sm.status = 'active'
       and r.code = 'owner'
  ) into v_caller_is_owner;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'code', p.code,
      'name_ar', p.name_ar,
      'name_en', p.name_en,
      'description', coalesce(p.description, ''),
      'can_grant', identity.has_permission(p.code),
      -- Owner-only permissions cannot be granted OR revoked by anyone else.
      'can_revoke', v_caller_is_owner
        or p.code not in ('admin.role.write', 'marketing.consent.write')
    ) order by p.code)
    from identity.permissions p
  ), '[]'::jsonb);
end;
$fn$;

revoke all on function public.admin_permissions() from public, anon;
grant execute on function public.admin_permissions() to authenticated;

-- ---------------------------------------------------------------------------
-- Role list: expose description. Permissions stay the effective set, so the
-- owner still shows every permission even though it stores none.
-- ---------------------------------------------------------------------------
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
      'description', coalesce(r.description, ''),
      'is_system', r.is_system,
      'permissions', coalesce((
        select jsonb_agg(p.code order by p.code)
          from identity.permissions p
         where r.code = 'owner'
            or exists (
              select 1
                from identity.role_permissions rp
               where rp.role_id = r.id
                 and rp.permission_id = p.id
            )
      ), '[]'::jsonb)
    ) order by r.code)
    from identity.roles r
  ), '[]'::jsonb);
end;
$fn$;

revoke all on function public.admin_roles() from public, anon;
grant execute on function public.admin_roles() to authenticated;

-- ---------------------------------------------------------------------------
-- Hardened single-permission command. Kept for the staff permission dialog
-- and as the smallest compatible write path; create/update use the bulk RPCs.
-- ---------------------------------------------------------------------------
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

  if p_permission_code in ('marketing.consent.write', 'admin.role.write')
     and not v_caller_is_owner then
    raise exception 'owner-only permission: %', p_permission_code using errcode = '42501';
  end if;

  if v_caller_holds_target and not v_caller_is_owner then
    raise exception 'cannot modify a role you hold' using errcode = '42501';
  end if;

  -- The old definition let a non-owner grant any permission. Only grant a
  -- permission the caller already holds; revocation stays allowed.
  if p_granted and not v_caller_is_owner
     and not identity.has_permission(p_permission_code) then
    raise exception 'cannot grant a permission you do not hold: %', p_permission_code
      using errcode = '42501';
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

-- ---------------------------------------------------------------------------
-- The staff permission dialog also writes identity.role_permissions. Leaving
-- it unguarded would let admin.staff.write grant any permission (including
-- owner-only ones) and bypass every rule above, so it gets the same checks.
-- ---------------------------------------------------------------------------
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
  v_caller_is_owner boolean := false;
  v_caller_shares_role boolean := false;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('admin.staff.write') then
    raise exception 'missing permission: admin.staff.write' using errcode = '42501';
  end if;
  if p_granted is null then
    raise exception 'granted flag is required' using errcode = '22023';
  end if;

  select id into v_perm_id from identity.permissions where code = p_permission_code;
  if v_perm_id is null then
    raise exception 'unknown permission %', p_permission_code using errcode = '22023';
  end if;

  select exists (
    select 1
      from identity.staff_members sm
      join identity.staff_roles sr on sr.staff_id = sm.id
      join identity.roles r on r.id = sr.role_id
     where sm.user_id = auth.uid()
       and sm.status = 'active'
       and r.code = 'owner'
  ) into v_caller_is_owner;

  if p_permission_code in ('marketing.consent.write', 'admin.role.write')
     and not v_caller_is_owner then
    raise exception 'owner-only permission: %', p_permission_code using errcode = '42501';
  end if;

  if p_granted and not v_caller_is_owner
     and not identity.has_permission(p_permission_code) then
    raise exception 'cannot grant a permission you do not hold: %', p_permission_code
      using errcode = '42501';
  end if;

  -- The command edits every role assigned to the target, not one staff row.
  -- A non-owner may not touch a role they hold themselves.
  select exists (
    select 1
      from identity.staff_members target
      join identity.staff_roles target_role on target_role.staff_id = target.id
      join identity.staff_roles caller_role on caller_role.role_id = target_role.role_id
      join identity.staff_members caller on caller.id = caller_role.staff_id
     where target.id = p_staff_id
       and caller.user_id = auth.uid()
       and caller.status = 'active'
  ) into v_caller_shares_role;

  if v_caller_shares_role and not v_caller_is_owner then
    raise exception 'cannot modify permissions of a role you hold' using errcode = '42501';
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

revoke all on function public.admin_set_staff_permission(uuid, text, boolean)
  from public, anon;
grant execute on function public.admin_set_staff_permission(uuid, text, boolean)
  to authenticated;

-- ---------------------------------------------------------------------------
-- Shared validation + permission replacement used by create and update.
-- Returns the normalized code array; raises on unknown/unmanageable grants.
-- ---------------------------------------------------------------------------
create or replace function identity.validate_role_permission_set(
  p_role_id uuid,
  p_permission_codes text[],
  p_caller_is_owner boolean
)
returns text[]
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_codes text[];
  v_existing text[];
  v_added text[];
  v_removed text[];
  v_bad_code text;
begin
  select coalesce(array_agg(distinct btrim(c) order by btrim(c)), '{}'::text[])
    into v_codes
    from unnest(coalesce(p_permission_codes, '{}'::text[])) as c
   where nullif(btrim(c), '') is not null;

  select u.c into v_bad_code
    from unnest(v_codes) as u(c)
   where not exists (select 1 from identity.permissions p where p.code = u.c)
   limit 1;
  if v_bad_code is not null then
    raise exception 'unknown permission %', v_bad_code using errcode = '22023';
  end if;

  if p_role_id is not null then
    select coalesce(array_agg(p.code order by p.code), '{}'::text[])
      into v_existing
      from identity.role_permissions rp
      join identity.permissions p on p.id = rp.permission_id
     where rp.role_id = p_role_id;
  else
    v_existing := '{}'::text[];
  end if;

  select coalesce(array_agg(s.c order by s.c), '{}'::text[]) into v_added
    from (select unnest(v_codes) as c except select unnest(v_existing) as c) as s;
  select coalesce(array_agg(s.c order by s.c), '{}'::text[]) into v_removed
    from (select unnest(v_existing) as c except select unnest(v_codes) as c) as s;

  if not p_caller_is_owner then
    -- Owner-only permissions cannot be granted or revoked by anyone else.
    select u.c into v_bad_code
      from unnest(v_added || v_removed) as u(c)
     where u.c in ('admin.role.write', 'marketing.consent.write')
     limit 1;
    if v_bad_code is not null then
      raise exception 'owner-only permission: %', v_bad_code using errcode = '42501';
    end if;

    -- A caller may only add a permission they already hold. Keeping or
    -- removing permissions they do not hold is allowed, so an update never
    -- forces an unrelated revocation.
    select u.c into v_bad_code
      from unnest(v_added) as u(c)
     where not identity.has_permission(u.c)
     limit 1;
    if v_bad_code is not null then
      raise exception 'cannot grant a permission you do not hold: %', v_bad_code
        using errcode = '42501';
    end if;
  end if;

  return v_codes;
end;
$fn$;

comment on function identity.validate_role_permission_set(uuid, text[], boolean) is
  'Normalizes, validates, and authorizes a complete role permission set.';

revoke all on function identity.validate_role_permission_set(uuid, text[], boolean)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- CREATE ROLE
-- ---------------------------------------------------------------------------
create or replace function public.admin_create_role(
  p_name_ar text,
  p_name_en text,
  p_description text,
  p_permission_codes text[]
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_caller_is_owner boolean := false;
  v_name_ar text;
  v_name_en text;
  v_description text;
  v_codes text[];
  v_code text;
  v_base text;
  v_role_id uuid;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('admin.role.write') then
    raise exception 'missing permission: admin.role.write' using errcode = '42501';
  end if;

  select exists (
    select 1
      from identity.staff_members sm
      join identity.staff_roles sr on sr.staff_id = sm.id
      join identity.roles r on r.id = sr.role_id
     where sm.user_id = auth.uid()
       and sm.status = 'active'
       and r.code = 'owner'
  ) into v_caller_is_owner;

  v_name_ar := btrim(coalesce(p_name_ar, ''));
  v_name_en := nullif(btrim(coalesce(p_name_en, '')), '');
  v_description := nullif(btrim(coalesce(p_description, '')), '');

  if v_name_ar = '' then
    raise exception 'role name in Arabic is required' using errcode = '22023';
  end if;
  if char_length(v_name_ar) > 80 then
    raise exception 'role name in Arabic is too long' using errcode = '22023';
  end if;
  if v_name_en is null then
    v_name_en := v_name_ar;
  end if;
  if char_length(v_name_en) > 80 then
    raise exception 'role name in English is too long' using errcode = '22023';
  end if;
  if char_length(coalesce(v_description, '')) > 500 then
    raise exception 'role description is too long' using errcode = '22023';
  end if;

  -- Serialize the check so two concurrent creates cannot both pass it.
  -- The role table has no unique name index (Phase 1.3 fixtures reuse names).
  perform pg_advisory_xact_lock(hashtext('identity.roles.name'));

  if identity.role_name_taken(v_name_ar, v_name_en) then
    raise exception 'a role with this name already exists' using errcode = '23505';
  end if;

  v_codes := identity.validate_role_permission_set(null, p_permission_codes, v_caller_is_owner);

  -- A readable, stable code derived from the English name. The role table
  -- only accepts lower-case letters and underscores, so the slug is reduced
  -- to that alphabet and a random suffix resolves collisions.
  v_base := regexp_replace(lower(v_name_en), '[^a-z]+', '_', 'g');
  v_base := btrim(v_base, '_');
  if v_base = '' then
    v_base := 'custom_role';
  else
    v_base := 'custom_' || left(v_base, 40);
  end if;

  v_code := v_base;
  while exists (select 1 from identity.roles r where r.code = v_code) loop
    v_code := v_base || '_' || translate(
      substr(replace(extensions.gen_random_uuid()::text, '-', ''), 1, 6),
      '0123456789', 'abcdefghij'
    );
  end loop;

  insert into identity.roles (code, name_ar, name_en, description, is_system)
  values (v_code, v_name_ar, v_name_en, v_description, false)
  returning id into v_role_id;

  insert into identity.role_permissions (role_id, permission_id)
  select v_role_id, p.id
    from identity.permissions p
   where p.code = any(v_codes);

  perform identity.audit(
    'role.create', 'role', v_role_id, null,
    jsonb_build_object(
      'code', v_code,
      'name_ar', v_name_ar,
      'name_en', v_name_en,
      'description', v_description,
      'permissions', to_jsonb(v_codes)
    )
  );

  return v_role_id;
end;
$fn$;

revoke all on function public.admin_create_role(text, text, text, text[])
  from public, anon;
grant execute on function public.admin_create_role(text, text, text, text[])
  to authenticated;

-- ---------------------------------------------------------------------------
-- UPDATE ROLE
-- ---------------------------------------------------------------------------
create or replace function public.admin_update_role(
  p_role_id uuid,
  p_name_ar text,
  p_name_en text,
  p_description text,
  p_permission_codes text[]
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_caller_is_owner boolean := false;
  v_caller_holds_target boolean := false;
  v_role identity.roles%rowtype;
  v_name_ar text;
  v_name_en text;
  v_description text;
  v_codes text[];
  v_old_permissions text[];
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('admin.role.write') then
    raise exception 'missing permission: admin.role.write' using errcode = '42501';
  end if;

  select * into v_role from identity.roles where id = p_role_id for update;
  if not found then
    raise exception 'role not found' using errcode = 'P0002';
  end if;
  if v_role.code = 'owner' then
    raise exception 'owner role is immutable' using errcode = '42501';
  end if;

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

  if v_caller_holds_target and not v_caller_is_owner then
    raise exception 'cannot modify a role you hold' using errcode = '42501';
  end if;

  v_name_ar := btrim(coalesce(p_name_ar, ''));
  v_name_en := nullif(btrim(coalesce(p_name_en, '')), '');
  v_description := nullif(btrim(coalesce(p_description, '')), '');

  if v_name_ar = '' then
    raise exception 'role name in Arabic is required' using errcode = '22023';
  end if;
  if char_length(v_name_ar) > 80 then
    raise exception 'role name in Arabic is too long' using errcode = '22023';
  end if;
  if v_name_en is null then
    v_name_en := v_name_ar;
  end if;
  if char_length(v_name_en) > 80 then
    raise exception 'role name in English is too long' using errcode = '22023';
  end if;
  if char_length(coalesce(v_description, '')) > 500 then
    raise exception 'role description is too long' using errcode = '22023';
  end if;

  if v_role.is_system and (
       lower(btrim(v_role.name_ar)) <> lower(v_name_ar)
       or lower(btrim(v_role.name_en)) <> lower(v_name_en)
       or lower(coalesce(btrim(v_role.description), '')) <> lower(coalesce(v_description, ''))
  ) then
    raise exception 'system role identity cannot be changed' using errcode = '42501';
  end if;

  -- Same serialization as create: without a unique index, the row lock on the
  -- target does not stop another role being created with this name.
  perform pg_advisory_xact_lock(hashtext('identity.roles.name'));

  if identity.role_name_taken(v_name_ar, v_name_en, p_role_id) then
    raise exception 'a role with this name already exists' using errcode = '23505';
  end if;

  select coalesce(array_agg(p.code order by p.code), '{}'::text[])
    into v_old_permissions
    from identity.role_permissions rp
    join identity.permissions p on p.id = rp.permission_id
   where rp.role_id = p_role_id;

  v_codes := identity.validate_role_permission_set(p_role_id, p_permission_codes, v_caller_is_owner);

  delete from identity.role_permissions where role_id = p_role_id;
  insert into identity.role_permissions (role_id, permission_id)
  select p_role_id, p.id
    from identity.permissions p
   where p.code = any(v_codes);

  if not v_role.is_system then
    update identity.roles
       set name_ar = v_name_ar,
           name_en = v_name_en,
           description = v_description
     where id = p_role_id;
  end if;

  perform identity.audit(
    'role.update', 'role', p_role_id,
    jsonb_build_object(
      'name_ar', v_role.name_ar,
      'name_en', v_role.name_en,
      'description', v_role.description,
      'permissions', to_jsonb(v_old_permissions)
    ),
    jsonb_build_object(
      'code', v_role.code,
      'name_ar', v_name_ar,
      'name_en', v_name_en,
      'description', v_description,
      'permissions', to_jsonb(v_codes)
    )
  );

  return p_role_id;
end;
$fn$;

revoke all on function public.admin_update_role(uuid, text, text, text, text[])
  from public, anon;
grant execute on function public.admin_update_role(uuid, text, text, text, text[])
  to authenticated;

notify pgrst, 'reload schema';
