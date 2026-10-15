-- 008_catalog_02_images_options.sql
--
-- This is the replacement for lib/features/menu/data/product_variants.dart.
--
-- Before: DrinkSize and SugarLevel were frozen Dart enums, and which
-- products offered them was decided by string-matching the category name
-- against `sizedCategories = {'Hot Coffee','Cold Coffee',...}`. Renaming a
-- category silently broke the whole variant table.
--
-- After: reusable option groups with per-product binding, admin-editable.

create table if not exists catalog.product_images (
  id         uuid primary key default extensions.gen_random_uuid(),
  product_id uuid not null references catalog.products(id) on delete cascade,
  image_url  text not null,
  alt_ar     text,
  alt_en     text,
  sort_order integer not null default 0,
  is_primary boolean not null default false,
  created_at timestamptz not null default now()
);

comment on table catalog.product_images is
  'Product gallery. A partial unique index enforces exactly one primary image.';

create index if not exists ix_product_images_product
  on catalog.product_images (product_id, sort_order);

create unique index if not exists uq_product_images_primary
  on catalog.product_images (product_id) where is_primary;

-- ---------------------------------------------------------------------------
-- Option groups: one table covers sizes, sugar levels and extras.
-- ---------------------------------------------------------------------------
create table if not exists catalog.option_groups (
  id             uuid primary key default extensions.gen_random_uuid(),
  code           text not null unique check (code ~ '^[a-z_]+$'),
  name_ar        text not null,
  name_en        text not null,
  description_ar text,
  description_en text,
  selection_type text not null default 'single'
                   check (selection_type in ('single','multiple')),
  min_select     integer not null default 0 check (min_select >= 0),
  max_select     integer check (max_select > 0),
  is_required    boolean not null default false,
  sort_order     integer not null default 0,
  is_active      boolean not null default true,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  constraint ck_option_groups_max check (
    max_select is null or max_select >= min_select
  ),
  constraint ck_option_groups_single check (
    selection_type = 'multiple' or max_select is null or max_select = 1
  ),
  -- is_required implies at least one selection
  constraint ck_option_groups_required check (
    not is_required or min_select >= 1
  )
);

comment on table catalog.option_groups is
  'Reusable option groups. "single" (size, sugar) or "multiple" (extras, add-ons).';

create index if not exists ix_option_groups_sort
  on catalog.option_groups (sort_order) where is_active;

create trigger tr_option_groups_updated_at
  before update on catalog.option_groups
  for each row execute function core.set_updated_at();

-- ---------------------------------------------------------------------------
create table if not exists catalog.option_values (
  id          uuid primary key default extensions.gen_random_uuid(),
  group_id    uuid not null references catalog.option_groups(id) on delete cascade,
  code        text not null check (code ~ '^[a-z0-9_]+$'),
  name_ar     text not null,
  name_en     text not null,
  price_delta numeric(12,2) not null default 0,
  short_label text,
  sort_order  integer not null default 0,
  is_active   boolean not null default true,
  is_default  boolean not null default false,
  created_at  timestamptz not null default now(),
  unique (group_id, code)
);

comment on table catalog.option_values is
  'One selectable value. price_delta is ADDED to base_price (0 / 5 / 10 today).';

create index if not exists ix_option_values_group
  on catalog.option_values (group_id, sort_order) where is_active;

-- ---------------------------------------------------------------------------
-- Which products offer which groups. This is the explicit binding that
-- replaces the category-name string matching.
-- ---------------------------------------------------------------------------
create table if not exists catalog.product_option_groups (
  product_id  uuid not null references catalog.products(id) on delete cascade,
  group_id    uuid not null references catalog.option_groups(id) on delete restrict,
  sort_order  integer not null default 0,
  is_required boolean not null default false,
  primary key (product_id, group_id)
);

comment on table catalog.product_option_groups is
  'Binds option groups to products. is_required here overrides the group default.';

create index if not exists ix_pog_group
  on catalog.product_option_groups (group_id);