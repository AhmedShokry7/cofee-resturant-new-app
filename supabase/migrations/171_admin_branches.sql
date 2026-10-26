-- 171_admin_branches.sql
-- Admin branch management on top of core.branches.
--
-- The admin page used the auto-updatable public.branches view (040) for every
-- operation. That view does not expose brand_id or image_url, so creating a
-- branch and saving a branch picture failed at the PostgREST layer, and the
-- grid had no operational numbers to show.
--
-- This migration:
--   1. adds the missing image_url column;
--   2. replaces direct view writes with permission-checked RPCs;
--   3. adds a directory with real per-branch counters;
--   4. adds the headline metrics the page shows;
--   5. refuses to delete a branch that carries history, and refuses to
--      deactivate or delete the last active branch.
--
-- Read and write both require settings.write, matching the branch RLS policy
-- (020) and the branch destination permission in the admin app.

-- ---------------------------------------------------------------------------
-- 1. Branch picture.
-- ---------------------------------------------------------------------------
alter table core.branches
  add column if not exists image_url text;

comment on column core.branches.image_url is
  'Branch picture URL. Kept out of public.branches because only the back office
   currently renders it.';

-- ---------------------------------------------------------------------------
-- 2. Directory with real operational counters.
-- ---------------------------------------------------------------------------
create or replace function public.admin_branches()
returns jsonb
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

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', b.id,
      'code', b.code,
      'name_ar', b.name_ar,
      'name_en', b.name_en,
      'address', b.address,
      'address_ar', b.address_ar,
      'address_en', b.address_en,
      'latitude', b.latitude,
      'longitude', b.longitude,
      'phone', b.phone,
      'is_active', b.is_active,
      'opens_at', b.opens_at,
      'closes_at', b.closes_at,
      'image_url', b.image_url,
      'created_at', b.created_at,
      'staff_count', coalesce(st.staff_count, 0),
      'zone_count', coalesce(zn.zone_count, 0),
      'orders_30d', coalesce(ord.orders_30d, 0),
      'last_order_at', ord.last_order_at
    ) order by b.is_active desc, b.name_ar)
    from core.branches b
    left join lateral (
      select count(distinct sr.staff_id)::integer as staff_count
        from identity.staff_roles sr
        join identity.staff_members sm on sm.id = sr.staff_id
       where sr.branch_id = b.id
         and sm.status = 'active'
    ) st on true
    left join lateral (
      select count(distinct dzb.zone_id)::integer as zone_count
        from core.delivery_zone_branches dzb
        join core.delivery_zones dz on dz.id = dzb.zone_id
       where dzb.branch_id = b.id
         and dz.is_active
    ) zn on true
    left join lateral (
      select count(*) filter (
               where o.status <> 'cancelled'
                 and o.placed_at >= now() - interval '30 days'
             )::integer as orders_30d,
             max(o.placed_at) filter (
               where o.status <> 'cancelled'
             ) as last_order_at
        from orders.orders o
       where o.branch_id = b.id
    ) ord on true
  ), '[]'::jsonb);
end;
$fn$;

comment on function public.admin_branches is
  'Every branch with its assigned staff, active delivery zones, 30-day orders
   and latest order time for the admin directory.';

revoke all on function public.admin_branches() from public, anon;
grant execute on function public.admin_branches() to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Headline metrics.
-- ---------------------------------------------------------------------------
create or replace function public.admin_branch_metrics()
returns jsonb
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

  return (
    select jsonb_build_object(
      'total', count(*),
      'active', count(*) filter (where b.is_active),
      'inactive', count(*) filter (where not b.is_active),
      'without_location', count(*) filter (
        where b.latitude is null or b.longitude is null
      ),
      'zones_covered', (
        select count(distinct dzb.zone_id)
          from core.delivery_zone_branches dzb
          join core.delivery_zones dz on dz.id = dzb.zone_id
          join core.branches b on b.id = dzb.branch_id
         where dz.is_active
           and b.is_active
      ),
      'orders_30d', (
        select count(*)
          from orders.orders o
         where o.status <> 'cancelled'
           and o.placed_at >= now() - interval '30 days'
      ),
      'staff_assigned', (
        select count(distinct sr.staff_id)
          from identity.staff_roles sr
          join identity.staff_members sm on sm.id = sr.staff_id
         where sr.branch_id is not null
           and sm.status = 'active'
      )
    )
    from core.branches b
  );
end;
$fn$;

comment on function public.admin_branch_metrics is
  'Branch counts, active delivery coverage and 30-day order volume.';

revoke all on function public.admin_branch_metrics() from public, anon;
grant execute on function public.admin_branch_metrics() to authenticated;

-- ---------------------------------------------------------------------------
-- 4. Create / update one branch.
-- ---------------------------------------------------------------------------
create or replace function public.admin_save_branch(p_branch jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_id       uuid;
  v_brand_id uuid;
  v_code     text;
  v_name_ar  text;
  v_name_en  text;
  v_address  text;
  v_phone    text;
  v_lat      numeric;
  v_lng      numeric;
  v_opens_at time;
  v_closes_at time;
  v_old      jsonb;
  v_new      jsonb;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('settings.write') then
    raise exception 'missing permission: settings.write' using errcode = '42501';
  end if;
  if p_branch is null or jsonb_typeof(p_branch) <> 'object' then
    return jsonb_build_object('ok', false, 'reason', 'invalid_payload');
  end if;

  begin
    v_id := nullif(btrim(coalesce(p_branch->>'id', '')), '')::uuid;
    v_lat := nullif(btrim(coalesce(p_branch->>'latitude', '')), '')::numeric;
    v_lng := nullif(btrim(coalesce(p_branch->>'longitude', '')), '')::numeric;
    v_opens_at := nullif(btrim(coalesce(p_branch->>'opens_at', '')), '')::time;
    v_closes_at := nullif(btrim(coalesce(p_branch->>'closes_at', '')), '')::time;
  exception
    when data_exception then
      return jsonb_build_object('ok', false, 'reason', 'invalid_payload');
  end;

  v_code := upper(btrim(coalesce(p_branch->>'code', '')));
  v_name_ar := btrim(coalesce(p_branch->>'name_ar', ''));
  v_name_en := btrim(coalesce(p_branch->>'name_en', ''));
  v_address := btrim(coalesce(p_branch->>'address', ''));
  v_phone := nullif(btrim(coalesce(p_branch->>'phone', '')), '');

  if v_code !~ '^[A-Z0-9_-]{1,24}$' then
    return jsonb_build_object('ok', false, 'reason', 'invalid_code');
  end if;
  if v_name_ar = '' then
    return jsonb_build_object('ok', false, 'reason', 'invalid_name');
  end if;
  if v_address = '' then
    return jsonb_build_object('ok', false, 'reason', 'invalid_address');
  end if;
  if (v_lat is null) <> (v_lng is null)
     or (v_lat is not null and v_lat not between -90 and 90)
     or (v_lng is not null and v_lng not between -180 and 180) then
    return jsonb_build_object('ok', false, 'reason', 'invalid_location');
  end if;
  if (v_opens_at is null) <> (v_closes_at is null)
     or (v_opens_at is not null and v_opens_at >= v_closes_at) then
    return jsonb_build_object('ok', false, 'reason', 'invalid_hours');
  end if;
  if v_name_en = '' then
    v_name_en := v_name_ar;
  end if;

  if exists (
    select 1 from core.branches b
     where upper(b.code) = v_code
       and (v_id is null or b.id <> v_id)
  ) then
    return jsonb_build_object('ok', false, 'reason', 'duplicate_code');
  end if;

  if v_id is null then
    select b.id into v_brand_id
      from core.brands b
     order by b.created_at
     limit 1;
    if v_brand_id is null then
      return jsonb_build_object('ok', false, 'reason', 'no_brand');
    end if;

    begin
      insert into core.branches (
        brand_id, code, name_ar, name_en, address, address_ar, address_en,
        latitude, longitude, phone, opens_at, closes_at
      ) values (
        v_brand_id, v_code, v_name_ar, v_name_en, v_address, v_address,
        v_address, v_lat, v_lng, v_phone, v_opens_at, v_closes_at
      ) returning id into v_id;
    exception
      when unique_violation then
        return jsonb_build_object('ok', false, 'reason', 'duplicate_code');
    end;
  else
    select jsonb_build_object(
             'code', b.code,
             'name_ar', b.name_ar,
             'name_en', b.name_en,
             'address', b.address,
             'latitude', b.latitude,
             'longitude', b.longitude,
             'phone', b.phone,
             'opens_at', b.opens_at,
             'closes_at', b.closes_at
           ) into v_old
      from core.branches b
     where b.id = v_id;
    if v_old is null then
      return jsonb_build_object('ok', false, 'reason', 'not_found');
    end if;

    begin
      update core.branches b
         set code = v_code,
             name_ar = v_name_ar,
             name_en = v_name_en,
             address = v_address,
             address_ar = v_address,
             address_en = v_address,
             latitude = v_lat,
             longitude = v_lng,
             phone = v_phone,
             opens_at = v_opens_at,
             closes_at = v_closes_at
       where b.id = v_id;
    exception
      when unique_violation then
        return jsonb_build_object('ok', false, 'reason', 'duplicate_code');
    end;
  end if;

  select jsonb_build_object(
           'code', b.code,
           'name_ar', b.name_ar,
           'name_en', b.name_en,
           'address', b.address,
           'latitude', b.latitude,
           'longitude', b.longitude,
           'phone', b.phone,
           'opens_at', b.opens_at,
           'closes_at', b.closes_at
         ) into v_new
    from core.branches b
   where b.id = v_id;

  perform identity.audit(
    case when v_old is null then 'core.branch.create' else 'core.branch.update' end,
    'branch',
    v_id,
    v_old,
    v_new
  );

  return jsonb_build_object('ok', true, 'id', v_id);
end;
$fn$;

comment on function public.admin_save_branch is
  'Create or update one branch with code, location and opening-hour validation.';

revoke all on function public.admin_save_branch(jsonb) from public, anon;
grant execute on function public.admin_save_branch(jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- 5. Activate / deactivate. The last active branch must stay active, otherwise
--    the customer app has nowhere to send an order.
-- ---------------------------------------------------------------------------
create or replace function public.admin_set_branch_active(
  p_branch_id uuid,
  p_active boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_old jsonb;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('settings.write') then
    raise exception 'missing permission: settings.write' using errcode = '42501';
  end if;
  if p_branch_id is null or p_active is null then
    return jsonb_build_object('ok', false, 'reason', 'invalid_payload');
  end if;

  select jsonb_build_object('code', b.code, 'is_active', b.is_active)
    into v_old
    from core.branches b
   where b.id = p_branch_id;
  if v_old is null then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;

  if not p_active
     and (v_old->>'is_active')::boolean
     and not exists (
       select 1 from core.branches b
        where b.id <> p_branch_id and b.is_active
     ) then
    return jsonb_build_object('ok', false, 'reason', 'last_active');
  end if;

  update core.branches
     set is_active = p_active
   where id = p_branch_id;

  perform identity.audit(
    case when p_active then 'core.branch.activate' else 'core.branch.deactivate' end,
    'branch',
    p_branch_id,
    v_old,
    jsonb_build_object('is_active', p_active)
  );

  return jsonb_build_object('ok', true);
end;
$fn$;

comment on function public.admin_set_branch_active is
  'Activate or deactivate one branch; the last active branch cannot be hidden.';

revoke all on function public.admin_set_branch_active(uuid, boolean) from public, anon;
grant execute on function public.admin_set_branch_active(uuid, boolean) to authenticated;

-- ---------------------------------------------------------------------------
-- 6. Branch picture URL. Uploading the file itself stays in the app against
--    the product-images bucket; this only records the resulting URL.
-- ---------------------------------------------------------------------------
create or replace function public.admin_set_branch_image(
  p_branch_id uuid,
  p_image_url text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_url text := nullif(btrim(coalesce(p_image_url, '')), '');
  v_old jsonb;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('settings.write') then
    raise exception 'missing permission: settings.write' using errcode = '42501';
  end if;
  if p_branch_id is null then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;
  if v_url is not null and v_url !~* '^https?://' then
    return jsonb_build_object('ok', false, 'reason', 'invalid_url');
  end if;

  select jsonb_build_object('has_image', b.image_url is not null) into v_old
    from core.branches b
   where b.id = p_branch_id;
  if v_old is null then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;

  update core.branches
     set image_url = v_url
   where id = p_branch_id;

  perform identity.audit(
    'core.branch.image',
    'branch',
    p_branch_id,
    v_old,
    jsonb_build_object('has_image', v_url is not null)
  );

  return jsonb_build_object('ok', true);
end;
$fn$;

comment on function public.admin_set_branch_image is
  'Record or clear the picture URL of a branch.';

revoke all on function public.admin_set_branch_image(uuid, text) from public, anon;
grant execute on function public.admin_set_branch_image(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 7. Delete only a branch without history. Orders, subscription usage and
--    staff scopes make deletion unsafe, so the branch is kept for reporting.
-- ---------------------------------------------------------------------------
create or replace function public.admin_delete_branch(p_branch_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_old jsonb;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('settings.write') then
    raise exception 'missing permission: settings.write' using errcode = '42501';
  end if;

  select jsonb_build_object(
           'code', b.code,
           'name_ar', b.name_ar,
           'name_en', b.name_en,
           'address', b.address,
           'is_active', b.is_active
         ) into v_old
    from core.branches b
   where b.id = p_branch_id;
  if v_old is null then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;

  if exists (
    select 1 from orders.orders o where o.branch_id = p_branch_id
  ) then
    return jsonb_build_object('ok', false, 'reason', 'has_orders');
  end if;
  if exists (
    select 1 from subscriptions.subscription_usage su
     where su.branch_id = p_branch_id
  ) then
    return jsonb_build_object('ok', false, 'reason', 'has_usage');
  end if;
  if exists (
    select 1 from identity.staff_roles sr where sr.branch_id = p_branch_id
  ) then
    return jsonb_build_object('ok', false, 'reason', 'has_staff');
  end if;
  if (v_old->>'is_active')::boolean
     and not exists (
       select 1 from core.branches b
        where b.id <> p_branch_id and b.is_active
     ) then
    return jsonb_build_object('ok', false, 'reason', 'last_active');
  end if;

  begin
    delete from core.branches where id = p_branch_id;
  exception
    when foreign_key_violation then
      return jsonb_build_object('ok', false, 'reason', 'in_use');
  end;

  perform identity.audit(
    'core.branch.delete',
    'branch',
    p_branch_id,
    v_old,
    null
  );

  return jsonb_build_object('ok', true);
end;
$fn$;

comment on function public.admin_delete_branch is
  'Delete a branch that has no orders, subscription usage or staff scope.';

revoke all on function public.admin_delete_branch(uuid) from public, anon;
grant execute on function public.admin_delete_branch(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 8. Branch picture files share the product-images bucket, but the bucket
--    policy (124) only allows catalog.product.write. A settings manager may
--    upload a branch picture, so allow the dedicated branch folder with
--    settings.write. Product folders keep their stricter policy.
-- ---------------------------------------------------------------------------
drop policy if exists "product_images_branch_insert" on storage.objects;
create policy "product_images_branch_insert"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'product-images'
    and name like 'products/branch-%'
    and identity.has_permission('settings.write')
  );

drop policy if exists "product_images_branch_update" on storage.objects;
create policy "product_images_branch_update"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'product-images'
    and name like 'products/branch-%'
    and identity.has_permission('settings.write')
  )
  with check (
    bucket_id = 'product-images'
    and name like 'products/branch-%'
    and identity.has_permission('settings.write')
  );

drop policy if exists "product_images_branch_delete" on storage.objects;
create policy "product_images_branch_delete"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'product-images'
    and name like 'products/branch-%'
    and identity.has_permission('settings.write')
  );

notify pgrst, 'reload config';
notify pgrst, 'reload schema';
