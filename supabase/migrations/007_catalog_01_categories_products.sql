-- 007_catalog_01_categories_products.sql
-- Categories and products.
--
-- Two defects in the Flutter models are fixed here:
--   1. CategoryModel had NO id -- relationships were raw English label
--      comparisons (product.category == category.label). Now a real uuid.
--   2. IconData is not storable -- replaced by icon_key (asset name).
--
-- Bilingual by construction (D4): explicit _ar / _en columns, never JSONB.

create table if not exists catalog.categories (
  id             uuid primary key default extensions.gen_random_uuid(),
  parent_id      uuid references catalog.categories(id) on delete set null,
  name_ar        text not null check (length(btrim(name_ar)) > 0),
  name_en        text not null check (length(btrim(name_en)) > 0),
  description_ar text,
  description_en text,
  image_url      text,
  icon_key       text,
  sort_order     integer not null default 0,
  is_active      boolean not null default true,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

comment on table catalog.categories is
  'Product categories. parent_id enables the sub-category support the spec asked for.';

create index if not exists ix_categories_parent_sort
  on catalog.categories (parent_id, sort_order);
create index if not exists ix_categories_active
  on catalog.categories (sort_order) where is_active;

create trigger tr_categories_updated_at
  before update on catalog.categories
  for each row execute function core.set_updated_at();

-- ---------------------------------------------------------------------------
create table if not exists catalog.products (
  id                 uuid primary key default extensions.gen_random_uuid(),
  category_id        uuid not null references catalog.categories(id) on delete restrict,
  sku                text not null unique,
  slug               text not null unique,
  name_ar            text not null check (length(btrim(name_ar)) > 0),
  name_en            text not null check (length(btrim(name_en)) > 0),
  description_ar     text,
  description_en     text,
  base_price         numeric(12,2) not null check (base_price >= 0),
  compare_at_price   numeric(12,2) check (compare_at_price > 0),
  image_url          text,
  is_active          boolean not null default true,
  is_featured        boolean not null default false,
  prep_minutes       integer check (prep_minutes >= 0),
  is_calorie_tracked boolean not null default false,
  allergens          text[] not null default '{}',
  sort_order         integer not null default 0,
  archived_at        timestamptz,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  constraint ck_products_compare_at check (
    compare_at_price is null or compare_at_price > base_price
  )
);

comment on table catalog.products is
  'Products. base_price is a reference price only; the charged price comes from resolve_effective_price().';

create index if not exists ix_products_category_active
  on catalog.products (category_id)
  where is_active and archived_at is null;
create index if not exists ix_products_sort
  on catalog.products (sort_order) where is_active and archived_at is null;
create index if not exists ix_products_featured
  on catalog.products (is_featured) where is_featured and is_active and archived_at is null;
create index if not exists ix_products_allergens on catalog.products using gin (allergens);

create trigger tr_products_updated_at
  before update on catalog.products
  for each row execute function core.set_updated_at();