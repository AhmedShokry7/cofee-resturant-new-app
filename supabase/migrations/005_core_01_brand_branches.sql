-- 005_core_01_brand_branches.sql
-- Brand, branches (D1), delivery zones, and key/value app settings.

-- ---------------------------------------------------------------------------
-- Single brand for v1. Multi-tenant / multi-brand is explicitly deferred
-- (DATABASE_SPEC.md section 10.4).
-- ---------------------------------------------------------------------------
create table if not exists core.brands (
  id            uuid primary key default extensions.gen_random_uuid(),
  name_ar       text not null,
  name_en       text not null,
  logo_url      text,
  currency_code text not null default 'SAR' check (currency_code ~ '^[A-Z]{3}$'),
  tax_included  boolean not null default true,
  tax_rate      numeric(5,2) not null default 0 check (tax_rate >= 0),
  support_email text,
  support_phone text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

comment on table core.brands is
  'The one brand. currency_code is the only place the currency is stored (D5).';

-- ---------------------------------------------------------------------------
-- Branches. The customer picks one; that branch drives pricing, availability,
-- stock and fulfilment (D1).
-- ---------------------------------------------------------------------------
create table if not exists core.branches (
  id         uuid primary key default extensions.gen_random_uuid(),
  brand_id   uuid not null references core.brands(id) on delete restrict,
  code       text not null unique check (code ~ '^[A-Z0-9_-]+$'),
  name_ar    text not null,
  name_en    text not null,
  address    text not null,
  latitude   numeric(9,6) check (latitude between -90 and 90),
  longitude  numeric(9,6) check (longitude between -180 and 180),
  phone      text,
  is_active  boolean not null default true,
  opens_at   time,
  closes_at  time,
  settings   jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint ck_branches_hours check (
    opens_at is null or closes_at is null or opens_at < closes_at
  )
);

comment on table core.branches is
  'Cafe branches. Inactive branches vanish from the customer picker but stay visible on historical orders.';

create index if not exists ix_branches_brand_active
  on core.branches (brand_id) where is_active;
create index if not exists ix_branches_code on core.branches (code);

create trigger tr_branches_updated_at
  before update on core.branches
  for each row execute function core.set_updated_at();

-- profiles.branch_id was left nullable in 003 because core.branches did not
-- exist yet. Wire the FK now.
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'profiles_branch_id_fkey'
      and conrelid = 'identity.profiles'::regclass
  ) then
    alter table identity.profiles
      add constraint profiles_branch_id_fkey
      foreign key (branch_id) references core.branches(id) on delete set null;
  end if;
end $$;

create index if not exists ix_profiles_branch on identity.profiles (branch_id)
  where branch_id is not null;

-- ---------------------------------------------------------------------------
-- Delivery zones. Fee is computed server-side from this table (never from
-- the client). Replaces AppConstant.deliveryFee.
-- ---------------------------------------------------------------------------
create table if not exists core.delivery_zones (
  id                 uuid primary key default extensions.gen_random_uuid(),
  brand_id           uuid not null references core.brands(id) on delete cascade,
  name_ar            text not null,
  name_en            text not null,
  delivery_fee       numeric(12,2) not null default 0 check (delivery_fee >= 0),
  min_order_amount   numeric(12,2) not null default 0 check (min_order_amount >= 0),
  estimated_minutes  integer check (estimated_minutes > 0),
  polygon            jsonb,
  is_active          boolean not null default true,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

comment on table core.delivery_zones is
  'Delivery areas and their fees. polygon is GeoJSON; validated in the application layer.';

create index if not exists ix_zones_brand_active
  on core.delivery_zones (brand_id) where is_active;

create trigger tr_zones_updated_at
  before update on core.delivery_zones
  for each row execute function core.set_updated_at();

-- A zone may be served by several branches, and a branch by several zones.
create table if not exists core.delivery_zone_branches (
  zone_id   uuid not null references core.delivery_zones(id) on delete cascade,
  branch_id uuid not null references core.branches(id) on delete cascade,
  primary key (zone_id, branch_id)
);

comment on table core.delivery_zone_branches is
  'Which branches serve which delivery zones. Used to reject out-of-area orders.';

create index if not exists ix_zone_branches_branch
  on core.delivery_zone_branches (branch_id);

-- ---------------------------------------------------------------------------
-- Key/value settings. is_public rows are readable by the client.
-- ---------------------------------------------------------------------------
create table if not exists core.app_settings (
  key         text primary key check (key ~ '^[a-z_]+$'),
  value       jsonb not null,
  value_type  text not null check (value_type in ('string','number','boolean','json')),
  is_public   boolean not null default false,
  description text,
  updated_at  timestamptz not null default now(),
  updated_by  uuid references auth.users(id) on delete set null
);

comment on table core.app_settings is
  'Typed key/value settings. Only is_public rows are exposed to the client.';

create index if not exists ix_settings_public
  on core.app_settings (key) where is_public;