-- Create, update and assign zones from one branch's settings in one transaction.
-- Shared zones are copied on edit so one branch cannot alter another's area.

-- Branch settings save a zone and its branch assignment as one transaction.
-- When a shared zone is edited from one branch's settings, clone it first so
-- changing that branch never silently changes another branch's coverage.
create or replace function public.admin_save_branch_delivery_zone(
  p_branch_id uuid,
  p_id uuid,
  p_name_ar text,
  p_name_en text,
  p_delivery_fee numeric,
  p_min_order_amount numeric,
  p_estimated_minutes integer,
  p_center_latitude numeric,
  p_center_longitude numeric,
  p_radius_km numeric,
  p_fee_method text,
  p_fee_per_km numeric,
  p_max_delivery_fee numeric,
  p_free_delivery_over numeric,
  p_is_active boolean
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_id uuid;
  v_brand_id uuid;
  v_shared boolean := false;
begin
  if not identity.is_staff()
     or not identity.has_permission('settings.write') then
    raise exception 'missing permission: settings.write' using errcode = '42501';
  end if;
  if p_branch_id is null then
    raise exception 'branch is required' using errcode = '22023';
  end if;
  select b.brand_id into v_brand_id
    from core.branches b where b.id = p_branch_id;
  if v_brand_id is null then
    raise exception 'branch not found' using errcode = 'P0002';
  end if;
  if nullif(btrim(coalesce(p_name_ar, '')), '') is null then
    raise exception 'the delivery zone needs an Arabic name' using errcode = '22023';
  end if;
  if p_center_latitude is null or p_center_longitude is null
     or p_center_latitude not between -90 and 90
     or p_center_longitude not between -180 and 180
     or p_radius_km is null or p_radius_km <= 0 then
    raise exception 'a valid center and positive radius are required' using errcode = '22023';
  end if;
  if p_fee_method is null or p_fee_method not in ('fixed', 'per_km', 'free')
     or (p_fee_method = 'per_km' and coalesce(p_fee_per_km, 0) <= 0) then
    raise exception 'invalid delivery fee rule' using errcode = '22023';
  end if;
  if coalesce(p_delivery_fee, 0) < 0
     or coalesce(p_min_order_amount, 0) < 0
     or (p_estimated_minutes is not null and p_estimated_minutes <= 0)
     or (p_max_delivery_fee is not null and p_max_delivery_fee < 0)
     or (p_free_delivery_over is not null and p_free_delivery_over < 0) then
    raise exception 'delivery fees and limits cannot be negative' using errcode = '22023';
  end if;

  if p_id is not null then
    if not exists (
      select 1 from core.delivery_zone_branches dzb
       where dzb.zone_id = p_id and dzb.branch_id = p_branch_id
    ) then
      raise exception 'delivery zone is not assigned to this branch' using errcode = '42501';
    end if;
    if not exists (
      select 1 from core.delivery_zones dz
       where dz.id = p_id and dz.brand_id = v_brand_id
    ) then
      raise exception 'delivery zone not found' using errcode = 'P0002';
    end if;
    select count(*) > 1 into v_shared
      from core.delivery_zone_branches dzb where dzb.zone_id = p_id;
  end if;

  if p_id is null or v_shared then
    insert into core.delivery_zones (
      brand_id, name_ar, name_en, delivery_fee, min_order_amount,
      estimated_minutes, center_latitude, center_longitude, radius_km,
      fee_method, fee_per_km, max_delivery_fee, free_delivery_over, is_active
    ) values (
      v_brand_id, btrim(p_name_ar), coalesce(nullif(btrim(p_name_en), ''), btrim(p_name_ar)),
      coalesce(p_delivery_fee, 0), coalesce(p_min_order_amount, 0),
      p_estimated_minutes, p_center_latitude, p_center_longitude, p_radius_km,
      p_fee_method, p_fee_per_km, p_max_delivery_fee, p_free_delivery_over,
      coalesce(p_is_active, true)
    ) returning id into v_id;

    if v_shared then
      delete from core.delivery_zone_branches dzb
       where dzb.zone_id = p_id and dzb.branch_id = p_branch_id;
    end if;
    insert into core.delivery_zone_branches (zone_id, branch_id)
    values (v_id, p_branch_id);
    return v_id;
  end if;

  update core.delivery_zones dz
     set name_ar = btrim(p_name_ar),
         name_en = coalesce(nullif(btrim(p_name_en), ''), btrim(p_name_ar)),
         delivery_fee = coalesce(p_delivery_fee, 0),
         min_order_amount = coalesce(p_min_order_amount, 0),
         estimated_minutes = p_estimated_minutes,
         center_latitude = p_center_latitude,
         center_longitude = p_center_longitude,
         radius_km = p_radius_km,
         polygon = null,
         fee_method = p_fee_method,
         fee_per_km = p_fee_per_km,
         max_delivery_fee = p_max_delivery_fee,
         free_delivery_over = p_free_delivery_over,
         is_active = coalesce(p_is_active, true)
   where dz.id = p_id;
  return p_id;
end;
$fn$;

revoke all on function public.admin_save_branch_delivery_zone(
  uuid,uuid,text,text,numeric,numeric,integer,numeric,numeric,numeric,text,numeric,numeric,numeric,boolean
) from public, anon;
grant execute on function public.admin_save_branch_delivery_zone(
  uuid,uuid,text,text,numeric,numeric,integer,numeric,numeric,numeric,text,numeric,numeric,numeric,boolean
) to authenticated, service_role;

notify pgrst, 'reload schema';
