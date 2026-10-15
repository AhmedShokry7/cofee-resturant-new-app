-- 010_catalog_04_bundles_pricing.sql
-- Bundles and per-branch pricing / availability (D1).

-- ---------------------------------------------------------------------------
-- Bundles. bundle_items.quantity is NEW: BundleModel had only
-- List<String> productIds with no quantity per component.
-- ---------------------------------------------------------------------------
create table if not exists catalog.bundles (
  id             uuid primary key default extensions.gen_random_uuid(),
  name_ar        text not null check (length(btrim(name_ar)) > 0),
  name_en        text not null check (length(btrim(name_en)) > 0),
  description_ar text,
  description_en text,
  image_url      text,
  bundle_price   numeric(12,2) check (bundle_price > 0),
  sort_order     integer not null default 0,
  is_active      boolean not null default true,
  starts_at      timestamptz,
  ends_at        timestamptz,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  constraint ck_bundles_window check (
    ends_at is null or starts_at is null or ends_at > starts_at
  )
);

comment on table catalog.bundles is
  'Bundles. bundle_price NULL means price is the sum of components (server-computed).';

create index if not exists ix_bundles_active
  on catalog.bundles (sort_order) where is_active;

create trigger tr_bundles_updated_at
  before update on catalog.bundles
  for each row execute function core.set_updated_at();

create table if not exists catalog.bundle_items (
  id            uuid primary key default extensions.gen_random_uuid(),
  bundle_id     uuid not null references catalog.bundles(id) on delete cascade,
  product_id    uuid not null references catalog.products(id) on delete restrict,
  quantity      integer not null default 1 check (quantity > 0),
  allow_options boolean not null default false,
  sort_order    integer not null default 0,
  unique (bundle_id, product_id)
);

comment on table catalog.bundle_items is
  'Bundle components with explicit quantity (was missing entirely in BundleModel).';

create index if not exists ix_bundle_items_product
  on catalog.bundle_items (product_id);

-- ---------------------------------------------------------------------------
-- Per-branch price override and availability (D1).
-- The base_price on the product is preserved; this only overrides it.
-- ---------------------------------------------------------------------------
create table if not exists catalog.branch_product_pricing (
  branch_id          uuid not null references core.branches(id) on delete cascade,
  product_id         uuid not null references catalog.products(id) on delete cascade,
  price_override     numeric(12,2) check (price_override >= 0),
  is_available       boolean not null default true,
  is_featured        boolean not null default false,
  unavailable_reason text,
  updated_at         timestamptz not null default now(),
  primary key (branch_id, product_id),
  constraint ck_bpp_featured_needs_available check (not is_featured or is_available)
);

comment on table catalog.branch_product_pricing is
  'Branch-specific price/availability. price_override NULL falls back to products.base_price.';

create index if not exists ix_bpp_product
  on catalog.branch_product_pricing (product_id) where price_override is not null;
create index if not exists ix_bpp_featured
  on catalog.branch_product_pricing (branch_id) where is_featured and is_available;