-- 194_record_live_admin_write_rpcs_and_rls_guard.sql
--
-- Five objects exist in project webzzasosevzymftgszn and in NO file in this
-- repository. They were created by hand in the SQL Editor, so a database
-- rebuilt from this chain would not have them at all:
--
--  * public.admin_create_delivery_zone / public.admin_update_delivery_zone -
--    the delivery zone dialog in the admin app calls both (see
--    app/admin_app/lib/features/delivery_zones), so a rebuilt database breaks
--    that page while the live project works.
--  * public.admin_update_category / public.admin_set_category_active - same,
--    for category editing and the active toggle.
--  * public.rls_auto_enable, plus the event trigger "ensure_rls" bound to it
--    on ddl_command_end for CREATE TABLE / CREATE TABLE AS / SELECT INTO. It
--    is SECURITY DEFINER, is NOT granted to authenticated, and its live owner
--    is not the migration role; on a rebuilt database the owner will be
--    whoever runs the chain, which is fine for its purpose but is a real
--    difference. The chain has no other event trigger.
--
-- Every definition below was copied verbatim from pg_get_functiondef on
-- 2026-10-27 and rehearsed inside "begin; ... rollback;" as a no-op: the live
-- bodies and their ACLs were unchanged by it. Do not edit a body without
-- re-running a live diff.

create or replace function public.rls_auto_enable()
returns event_trigger
language plpgsql
security definer
set search_path = 'pg_catalog'
as $fn$
DECLARE
  cmd record;
  tbl name;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        SELECT c.relname INTO tbl FROM pg_catalog.pg_class c WHERE c.oid = cmd.objid;
        EXECUTE format('alter table if exists %I.%I enable row level security', cmd.schema_name, tbl);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$fn$;

revoke all on function public.rls_auto_enable() from public, anon, authenticated;
grant execute on function public.rls_auto_enable() to service_role;

-- the binding that makes the guard run at all. Postgres has no
-- if-not-exists form for an event trigger, so it is dropped in the same
-- transaction and recreated: a no-op on the live project, and on a rebuilt
-- database the drop matches nothing.
drop event trigger if exists ensure_rls;
create event trigger ensure_rls
  on ddl_command_end
  when tag in ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
  execute function public.rls_auto_enable();

create or replace function public.admin_create_delivery_zone(p_name_ar text, p_name_en text, p_delivery_fee numeric, p_min_order_amount numeric, p_estimated_minutes integer DEFAULT NULL::integer, p_center_latitude numeric DEFAULT NULL::numeric, p_center_longitude numeric DEFAULT NULL::numeric, p_radius_km numeric DEFAULT NULL::numeric, p_fee_method text DEFAULT 'flat'::text, p_fee_per_km numeric DEFAULT NULL::numeric, p_max_delivery_fee numeric DEFAULT NULL::numeric, p_free_delivery_over numeric DEFAULT NULL::numeric, p_is_active boolean DEFAULT true)
returns uuid
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_brand_id uuid;
  v_id uuid;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('settings.write') then
    raise exception 'missing permission: settings.write' using errcode = '42501';
  end if;

  select id into v_brand_id from core.brands limit 1;
  if v_brand_id is null then
    raise exception 'no brand' using errcode = '22023';
  end if;

  insert into core.delivery_zones (
    brand_id, name_ar, name_en, delivery_fee, min_order_amount, estimated_minutes,
    center_latitude, center_longitude, radius_km, fee_method, fee_per_km,
    max_delivery_fee, free_delivery_over, is_active
  )
  values (
    v_brand_id, p_name_ar, p_name_en, p_delivery_fee, p_min_order_amount, p_estimated_minutes,
    p_center_latitude, p_center_longitude, p_radius_km, p_fee_method, p_fee_per_km,
    p_max_delivery_fee, p_free_delivery_over, p_is_active
  )
  returning id into v_id;

  return v_id;
end;
$fn$;

revoke all on function public.admin_create_delivery_zone(text, text, numeric, numeric, integer, numeric, numeric, numeric, text, numeric, numeric, numeric, boolean) from public, anon;
grant execute on function public.admin_create_delivery_zone(text, text, numeric, numeric, integer, numeric, numeric, numeric, text, numeric, numeric, numeric, boolean) to authenticated;
grant execute on function public.admin_create_delivery_zone(text, text, numeric, numeric, integer, numeric, numeric, numeric, text, numeric, numeric, numeric, boolean) to service_role;

create or replace function public.admin_update_delivery_zone(p_id uuid, p_name_ar text, p_name_en text, p_delivery_fee numeric, p_min_order_amount numeric, p_estimated_minutes integer DEFAULT NULL::integer, p_center_latitude numeric DEFAULT NULL::numeric, p_center_longitude numeric DEFAULT NULL::numeric, p_radius_km numeric DEFAULT NULL::numeric, p_fee_method text DEFAULT 'flat'::text, p_fee_per_km numeric DEFAULT NULL::numeric, p_max_delivery_fee numeric DEFAULT NULL::numeric, p_free_delivery_over numeric DEFAULT NULL::numeric, p_is_active boolean DEFAULT true)
returns void
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('settings.write') then
    raise exception 'missing permission: settings.write' using errcode = '42501';
  end if;

  update core.delivery_zones
     set name_ar = p_name_ar,
         name_en = p_name_en,
         delivery_fee = p_delivery_fee,
         min_order_amount = p_min_order_amount,
         estimated_minutes = p_estimated_minutes,
         center_latitude = p_center_latitude,
         center_longitude = p_center_longitude,
         radius_km = p_radius_km,
         fee_method = p_fee_method,
         fee_per_km = p_fee_per_km,
         max_delivery_fee = p_max_delivery_fee,
         free_delivery_over = p_free_delivery_over,
         is_active = p_is_active,
         updated_at = now()
   where id = p_id;
end;
$fn$;

revoke all on function public.admin_update_delivery_zone(uuid, text, text, numeric, numeric, integer, numeric, numeric, numeric, text, numeric, numeric, numeric, boolean) from public, anon;
grant execute on function public.admin_update_delivery_zone(uuid, text, text, numeric, numeric, integer, numeric, numeric, numeric, text, numeric, numeric, numeric, boolean) to authenticated;
grant execute on function public.admin_update_delivery_zone(uuid, text, text, numeric, numeric, integer, numeric, numeric, numeric, text, numeric, numeric, numeric, boolean) to service_role;

create or replace function public.admin_update_category(p_category_id uuid, p_name_ar text DEFAULT NULL::text, p_name_en text DEFAULT NULL::text, p_description_ar text DEFAULT NULL::text, p_description_en text DEFAULT NULL::text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_id uuid;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  if not identity.has_permission('catalog.category.write') then
    raise exception 'missing permission: catalog.category.write' using errcode = '42501';
  end if;

  if not exists (select 1 from catalog.categories c where c.id = p_category_id) then
    raise exception 'unknown category' using errcode = '22023';
  end if;

  if btrim(coalesce(p_name_ar, '')) = '' then
    raise exception 'the category needs an Arabic name' using errcode = '22023';
  end if;

  if btrim(coalesce(p_name_en, '')) = '' then
    raise exception 'the category needs an English name' using errcode = '22023';
  end if;

  update catalog.categories c
     set name_ar = btrim(p_name_ar),
         name_en = btrim(p_name_en),
         description_ar = nullif(btrim(coalesce(p_description_ar, '')), ''),
         description_en = nullif(btrim(coalesce(p_description_en, '')), ''),
         updated_at = now()
   where c.id = p_category_id
   returning c.id into v_id;

  return to_jsonb(c)
    from catalog.categories c
   where c.id = v_id;
end;
$fn$;

revoke all on function public.admin_update_category(uuid, text, text, text, text) from public, anon;
grant execute on function public.admin_update_category(uuid, text, text, text, text) to authenticated;
grant execute on function public.admin_update_category(uuid, text, text, text, text) to service_role;

create or replace function public.admin_set_category_active(p_category_id uuid, p_is_active boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  if not identity.has_permission('catalog.category.write') then
    raise exception 'missing permission: catalog.category.write' using errcode = '42501';
  end if;

  if not exists (select 1 from catalog.categories c where c.id = p_category_id) then
    raise exception 'unknown category' using errcode = '22023';
  end if;

  update catalog.categories c
     set is_active = coalesce(p_is_active, c.is_active),
         updated_at = now()
   where c.id = p_category_id;
end;
$fn$;

revoke all on function public.admin_set_category_active(uuid, boolean) from public, anon;
grant execute on function public.admin_set_category_active(uuid, boolean) to authenticated;
grant execute on function public.admin_set_category_active(uuid, boolean) to service_role;
