-- 068_delivery_zones_geography_and_fees.sql
--
-- The delivery-zone table declared a `polygon jsonb` column in 005 and the
-- comment claimed GeoJSON "validated in the application layer". Nothing ever
-- validated it: no seed row set it, the public view omitted it, no RPC returned
-- it, and no Dart code read it. Zone selection was a free-text dropdown and the
-- fee was one flat `delivery_fee` scalar, so a customer 80 km outside the area
-- could be told they were served, and the courier distance never affected price.
--
-- This makes zones real geography and makes the fee a function of the zone's
-- own rule.
--
-- Deliberately NOT PostGIS. The project installs only pg_trgm and pgcrypto
-- (001), and a managed Supabase project cannot add an extension from a
-- migration without extra dashboard configuration. Ray casting against GeoJSON
-- plus a haversine distance is a few dozen lines of plpgsql, the zone count is
-- tiny, and nothing here needs a spatial index to stay fast. If zone counts ever
-- reach thousands, the helpers below are the only thing that would need to move
-- behind PostGIS.
--
-- Shape of a zone now:
--   * polygon zone — `polygon` holds GeoJSON Polygon/MultiPolygon, centre and
--     radius unused. Covers a point when it is inside the outer ring and
--     outside every hole.
--   * radius zone  — `center_latitude` / `center_longitude` / `radius_km`.
--     Covers a point within `radius_km` of the centre.
--   * legacy zone  — neither set. Deliberately covers everywhere, so the two
--     seeded rows keep working until someone gives them geometry. This is the
--     one behaviour that must not change silently.

-- ---------------------------------------------------------------------------
-- Schema
-- ---------------------------------------------------------------------------

alter table core.delivery_zones
  add column if not exists center_latitude  numeric(9,6),
  add column if not exists center_longitude numeric(9,6),
  add column if not exists radius_km         numeric(8,3),
  add column if not exists fee_method        text not null default 'fixed',
  add column if not exists fee_per_km        numeric(12,2),
  add column if not exists max_delivery_fee  numeric(12,2),
  add column if not exists free_delivery_over numeric(12,2);

-- A zone declares exactly one geometry, never two. Legacy rows (neither set)
-- stay legal.
do $migration$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'ck_zones_geometry_shape'
  ) then
    alter table core.delivery_zones
      add constraint ck_zones_geometry_shape check (
        num_nonnulls(polygon, radius_km) <= 1
      );
  end if;
  if not exists (
    select 1 from pg_constraint where conname = 'ck_zones_radius_complete'
  ) then
    alter table core.delivery_zones
      add constraint ck_zones_radius_complete check (
        radius_km is null
        or (radius_km > 0
            and center_latitude between -90 and 90
            and center_longitude between -180 and 180)
      );
  end if;
  if not exists (
    select 1 from pg_constraint where conname = 'ck_zones_fee_method'
  ) then
    alter table core.delivery_zones
      add constraint ck_zones_fee_method check (
        fee_method in ('fixed', 'per_km', 'free')
      );
  end if;
  -- A per_km rule with no rate would silently price every delivery at zero,
  -- which is worse than refusing the configuration.
  if not exists (
    select 1 from pg_constraint where conname = 'ck_zones_per_km_rate'
  ) then
    alter table core.delivery_zones
      add constraint ck_zones_per_km_rate check (
        fee_method <> 'per_km' or fee_per_km is not null
      );
  end if;
end;
$migration$;

comment on column core.delivery_zones.polygon is
  'GeoJSON Polygon or MultiPolygon. Null together with radius_km means the zone '
  'covers everything (legacy rows). Mutually exclusive with radius_km.';
comment on column core.delivery_zones.fee_method is
  'fixed: delivery_fee applies. per_km: delivery_fee is replaced by '
  'distance_km * fee_per_km, capped by max_delivery_fee. free: always zero. '
  'free_delivery_over waives any of them above that subtotal.';

-- ---------------------------------------------------------------------------
-- Geometry helpers
-- ---------------------------------------------------------------------------

-- Great-circle distance in kilometres between two WGS84 points.
drop function if exists core.geo_distance_km(numeric, numeric, numeric, numeric);drop function if exists core.geo_point_in_ring(numeric, numeric, jsonb);drop function if exists core.geo_point_in_polygon(numeric, numeric, jsonb);drop function if exists core.zone_covers_point(uuid, numeric, numeric);drop function if exists core.delivery_zone_fee(uuid, uuid, numeric, numeric, numeric);drop function if exists public.resolve_delivery_zone(uuid, numeric, numeric);

create or replace function core.geo_distance_km(
  p_lat1 numeric, p_lng1 numeric, p_lat2 numeric, p_lng2 numeric
)
returns numeric
language sql
immutable
set search_path to ''
as $fn$
  select case
    when p_lat1 is null or p_lng1 is null
      or p_lat2 is null or p_lng2 is null then null
    else round((
      2 * 6371.0088 * asin(
        sqrt(
          power(sin(radians(p_lat2 - p_lat1) / 2), 2)
          + cos(radians(p_lat1)) * cos(radians(p_lat2))
          * power(sin(radians(p_lng2 - p_lng1) / 2), 2)
        )
      )
    )::numeric, 4)
  end;
$fn$;

comment on function core.geo_distance_km(numeric, numeric, numeric, numeric) is
  'Great-circle distance in km, or null when any coordinate is unknown.';

-- Ray casting: is (p_lat, p_lng) inside the closed GeoJSON linear ring?
--
-- GeoJSON positions are [lng, lat], which is the reverse of the argument order
-- here and the single easiest thing to get wrong.
create or replace function core.geo_point_in_ring(
  p_lat numeric, p_lng numeric, p_ring jsonb
)
returns boolean
language plpgsql
immutable
set search_path to ''
as $fn$
declare
  n      int := coalesce(jsonb_array_length(p_ring), 0);
  i      int;
  j      int;
  cx     numeric; cy numeric;  -- current vertex
  px     numeric; py numeric;  -- previous vertex
  inside boolean := false;
begin
  if p_ring is null or n < 3 then
    return false;
  end if;
  j := n - 1;
  for i in 0..n - 1 loop
    cx := (p_ring -> i ->> 0)::numeric;  -- longitude
    cy := (p_ring -> i ->> 1)::numeric;  -- latitude
    px := (p_ring -> j ->> 0)::numeric;
    py := (p_ring -> j ->> 1)::numeric;

    -- A vertex exactly on the latitude of the point is handled by the strict
    -- `>` comparison on both sides; no epsilon is needed for our purposes.
    if ((cy > p_lat) <> (py > p_lat))
       and (p_lng < (px - cx) * (p_lat - cy) / nullif(py - cy, 0) + cx) then
      inside := not inside;
    end if;
    j := i;
  end loop;
  return inside;
end;
$fn$;

comment on function core.geo_point_in_ring(numeric, numeric, jsonb) is
  'Ray-casting point-in-ring against a GeoJSON linear ring.';

-- Point in a GeoJSON Polygon or MultiPolygon. Holes exclude the point.
create or replace function core.geo_point_in_polygon(
  p_lat numeric, p_lng numeric, p_polygon jsonb
)
returns boolean
language plpgsql
immutable
set search_path to ''
as $fn$
declare
  v_type text := p_polygon ->> 'type';
  v_rings jsonb;
  v_multi jsonb;
  r      jsonb;
  k      int;
begin
  if p_polygon is null or v_type is null then
    return null;
  end if;

  if v_type = 'Polygon' then
    v_rings := p_polygon -> 'coordinates';
    if v_rings is null or jsonb_array_length(v_rings) = 0 then
      return null;
    end if;
    if not core.geo_point_in_ring(p_lat, p_lng, v_rings -> 0) then
      return false;
    end if;
    -- Any hole containing the point wins over the outer ring.
    for k in 1..jsonb_array_length(v_rings) - 1 loop
      if core.geo_point_in_ring(p_lat, p_lng, v_rings -> k) then
        return false;
      end if;
    end loop;
    return true;
  end if;

  if v_type = 'MultiPolygon' then
    for v_multi in select * from jsonb_array_elements(p_polygon -> 'coordinates') loop
      if core.geo_point_in_polygon(p_lat, p_lng, v_multi) then
        return true;
      end if;
    end loop;
    return false;
  end if;

  -- An unrecognised shape is never treated as coverage.
  return null;
end;
$fn$;

-- Does this zone serve this point?
--
-- Null when the zone does not exist, so the caller can tell "not covered" from
-- "no such zone". A zone with no geometry returns true on purpose: that is the
-- legacy behaviour and downgrading every existing zone to unserviceable would
-- silently stop delivery for every current branch.
create or replace function core.zone_covers_point(
  p_zone_id uuid, p_lat numeric, p_lng numeric
)
returns boolean
language plpgsql
stable
security definer
set search_path to ''
as $fn$
declare
  v_zone core.delivery_zones%rowtype;
  v_covers boolean;
begin
  if p_zone_id is null then
    return null;
  end if;
  select * into v_zone from core.delivery_zones dz where dz.id = p_zone_id;
  if not found then
    return null;
  end if;
  if p_lat is null or p_lng is null then
    -- Nothing to test against. An address without coordinates cannot be
    -- rejected on geography; the app offers manual zone choice for these.
    return true;
  end if;

  if v_zone.polygon is not null then
    v_covers := core.geo_point_in_polygon(p_lat, p_lng, v_zone.polygon);
    -- Unparseable geometry must not silently widen coverage.
    return coalesce(v_covers, false);
  end if;

  if v_zone.radius_km is not null then
    return core.geo_distance_km(
             p_lat, p_lng, v_zone.center_latitude, v_zone.center_longitude
           ) <= v_zone.radius_km;
  end if;

  return true;
end;
$fn$;

-- ---------------------------------------------------------------------------
-- Fees
-- ---------------------------------------------------------------------------

-- The fee this zone charges for one delivery.
--
-- Distance is measured from the branch to the address, not between zones, so a
-- customer near the edge of a wide zone still pays for how far the courier
-- actually travels.
--
-- `free_delivery_over` applies to every method: it is the common "spend X, get
-- delivery free" rule and making it a third method would just be the same
-- condition evaluated twice.
create or replace function core.delivery_zone_fee(
  p_zone_id uuid,
  p_branch_id uuid,
  p_lat numeric,
  p_lng numeric,
  p_subtotal numeric
)
returns numeric
language plpgsql
stable
security definer
set search_path to ''
as $fn$
declare
  v_zone    core.delivery_zones%rowtype;
  v_branch  record;
  v_distance numeric;
  v_fee     numeric := 0;
begin
  if p_zone_id is null then
    return 0;
  end if;
  select * into v_zone from core.delivery_zones dz where dz.id = p_zone_id;
  if not found then
    return 0;
  end if;

  if v_zone.free_delivery_over is not null
     and p_subtotal is not null
     and p_subtotal >= v_zone.free_delivery_over then
    return 0;
  end if;

  if v_zone.fee_method = 'free' then
    return 0;
  end if;

  if v_zone.fee_method = 'per_km' then
    select b.latitude, b.longitude into v_branch
      from core.branches b where b.id = p_branch_id;
    if v_branch.latitude is not null and v_branch.longitude is not null
       and p_lat is not null and p_lng is not null then
      v_distance := core.geo_distance_km(
        v_branch.latitude, v_branch.longitude, p_lat, p_lng
      );
      v_fee := round(coalesce(v_distance, 0) * v_zone.fee_per_km, 2);
    end if;
    if v_zone.max_delivery_fee is not null then
      v_fee := least(v_fee, v_zone.max_delivery_fee);
    end if;
    return greatest(v_fee, 0);
  end if;

  -- 'fixed', and the fallback for a per_km zone whose distance is unknown
  -- (no branch coordinates, or a legacy address without any).
  return greatest(coalesce(v_zone.delivery_fee, 0), 0);
end;
$fn$;

comment on function core.delivery_zone_fee(uuid, uuid, numeric, numeric, numeric) is
  'Authoritative delivery fee. Fixed, per-km from the branch, or free; waived '
  'above free_delivery_over. A per_km zone with an unknown distance falls back '
  'to delivery_fee rather than charging nothing.';

-- ---------------------------------------------------------------------------
-- Drop before recreating: return type changed.drop function if exists public.delivery_zones_for_branch(uuid);

-- Client-facing bridges
-- ---------------------------------------------------------------------------

create or replace view public.delivery_zones with (security_invoker = true) as
  select id, name_ar, name_en, delivery_fee, min_order_amount,
         estimated_minutes, is_active,
         center_latitude, center_longitude, radius_km,
         fee_method, fee_per_km, max_delivery_fee, free_delivery_over
    from core.delivery_zones;

-- Extra columns only; signature is unchanged, so the grants in 052 still apply.
drop function if exists public.delivery_zones_for_branch(uuid);
create or replace function public.delivery_zones_for_branch(p_branch_id uuid)
returns table (
  id uuid,
  name_ar text,
  name_en text,
  delivery_fee numeric,
  min_order_amount numeric,
  estimated_minutes integer,
  center_latitude numeric,
  center_longitude numeric,
  radius_km numeric,
  fee_method text,
  fee_per_km numeric,
  max_delivery_fee numeric,
  free_delivery_over numeric
)
language sql
stable
set search_path to ''
as $fn$
  select dz.id, dz.name_ar, dz.name_en, dz.delivery_fee,
         dz.min_order_amount, dz.estimated_minutes,
         dz.center_latitude, dz.center_longitude, dz.radius_km,
         dz.fee_method, dz.fee_per_km, dz.max_delivery_fee,
         dz.free_delivery_over
    from core.delivery_zones dz
    join core.delivery_zone_branches dzb on dzb.zone_id = dz.id
   where dzb.branch_id = p_branch_id
     and dz.is_active
   order by dz.delivery_fee, dz.name_en;
$fn$;

-- Which zone serves this address, and what does it cost?
--
-- Returns ZERO rows when the address is outside every zone the branch serves.
-- That is the whole point of the call: "no delivery to your area" is the
-- absence of an answer, not an exception, and the app distinguishes it from a
-- failed load the same way it distinguishes "no zones" from "could not tell".
--
-- Ordered nearest-first so overlapping zones resolve to the closest one; the
-- fee tiebreak keeps the answer deterministic when two zones are equidistant.
create or replace function public.resolve_delivery_zone(
  p_branch_id uuid,
  p_lat numeric,
  p_lng numeric
)
returns table (
  id uuid,
  name_ar text,
  name_en text,
  distance_km numeric,
  delivery_fee numeric,
  min_order_amount numeric,
  estimated_minutes integer
)
language sql
stable
set search_path to ''
as $fn$
  select dz.id, dz.name_ar, dz.name_en,
         core.geo_distance_km(b.latitude, b.longitude, p_lat, p_lng),
         core.delivery_zone_fee(dz.id, p_branch_id, p_lat, p_lng, 0),
         dz.min_order_amount, dz.estimated_minutes
    from core.delivery_zones dz
    join core.delivery_zone_branches dzb
      on dzb.zone_id = dz.id and dzb.branch_id = p_branch_id
    join core.branches b on b.id = p_branch_id
   where dz.is_active
     and core.zone_covers_point(dz.id, p_lat, p_lng)
   order by 4 nulls last, 5, dz.name_en;
$fn$;

comment on function public.resolve_delivery_zone(uuid, numeric, numeric) is
  'Zones of this branch that cover the point, nearest first, with the fee. '
  'Zero rows means the address is outside every served zone.';

revoke all on function public.delivery_zones_for_branch(uuid) from public;
grant execute on function public.delivery_zones_for_branch(uuid)
  to anon, authenticated, service_role;

revoke all on function public.resolve_delivery_zone(uuid, numeric, numeric)
  from public;
grant execute on function public.resolve_delivery_zone(uuid, numeric, numeric)
  to anon, authenticated, service_role;

notify pgrst, 'reload schema';