-- Keep branch addresses in the same language pair as branch names.
alter table core.branches
  add column if not exists address_ar text,
  add column if not exists address_en text;

update core.branches
   set address_ar = coalesce(nullif(btrim(address_ar), ''), address),
       address_en = coalesce(
         nullif(btrim(address_en), ''),
         case code
           when 'MAIN' then 'King Fahd Road, Olaya, Riyadh'
           when 'JEDDAH' then 'Tahlia Street, Al Rawdah, Jeddah'
           else address
         end
       );

create or replace view public.branches
with (security_invoker = true) as
  select id, code, name_ar, name_en, address, latitude, longitude, phone,
         is_active, opens_at, closes_at, created_at, address_ar, address_en
    from core.branches;

-- The public wrapper depends on the core function's return type, so replace
-- both functions when adding the localized address columns to the RPC shape.
drop function if exists public.active_branches();
drop function if exists core.active_branches();

create function core.active_branches()
returns table (
  id uuid,
  code text,
  name_ar text,
  name_en text,
  address text,
  address_ar text,
  address_en text,
  latitude numeric,
  longitude numeric,
  phone text
)
language sql
stable
security definer
set search_path = ''
as $fn$
  select b.id, b.code, b.name_ar, b.name_en, b.address,
         b.address_ar, b.address_en, b.latitude, b.longitude, b.phone
    from core.branches b
   where b.is_active
   order by b.name_en;
$fn$;

revoke all on function core.active_branches() from public;
grant execute on function core.active_branches() to anon, authenticated;

create function public.active_branches()
returns table (
  id uuid,
  code text,
  name_ar text,
  name_en text,
  address text,
  address_ar text,
  address_en text,
  latitude numeric,
  longitude numeric,
  phone text
)
language sql
stable
security invoker
set search_path = ''
as $fn$
  select * from core.active_branches();
$fn$;

revoke all on function public.active_branches() from public;
grant execute on function public.active_branches() to anon, authenticated;
