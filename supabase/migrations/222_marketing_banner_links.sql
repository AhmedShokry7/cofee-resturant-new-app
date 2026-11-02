-- supabase/migrations/222_marketing_banner_links.sql
--
-- WHY THIS EXISTS
--
-- `marketing.banners` carries exactly one link: `target_type` plus a single
-- `target_id` (015). The dashboard asks the admin for "the products and the
-- categories this banner promotes", but the schema has nowhere to put a second
-- one, so every save keeps one row and the banner page can only ever show that
-- one. Coupons met the same problem and solved it with two link tables
-- (`coupons_categories` in 022/030 and `coupons_products` in 056); banners have
-- no equivalent, which is why a banner "loses" everything the admin picked
-- except the last choice.
--
-- WHAT CHANGES
--
--   * `marketing.banner_products`   (banner_id, product_id,   sort_order)
--   * `marketing.banner_categories` (banner_id, category_id,  sort_order)
--
-- `banners.target_type` / `target_id` are untouched and still drive the CTA and
-- the banner's own row, so a banner with no link rows behaves exactly as it
-- does today. The link tables only add to what the page shows.
--
-- Two tables rather than one typed column: a `link_id uuid` that could point at
-- a product or a category cannot carry a real foreign key, and a dangling id is
-- precisely the failure this feature is trying to remove. The composite primary
-- key also makes the same product chosen twice a no-op instead of a duplicate
-- card, which is the same reason 033 had to add natural keys to the seed.
--
-- RLS keeps the shape of 056: public read, writes gated on
-- `identity.has_permission('settings.write')` so the dashboard needs no new
-- permission. Public read is narrower than 056's `using (true)` on purpose --
-- it follows `banners_public_read` (022) and hides the links of an unpublished
-- banner. An admin still sees them, because RLS combines the permissive SELECT
-- policies with OR and `*_admin_write` is `for all`.
--
-- The bridge views exist because the customer app talks to PostgREST, which only
-- sees `public` (032). `security_invoker = true` means the CALLING role needs
-- SELECT on the base table, not only on the view -- the lesson 033 learned the
-- hard way when three views answered 42501.

-- ---------------------------------------------------------------------------
-- 1. The link tables.
-- ---------------------------------------------------------------------------
create table if not exists marketing.banner_products (
  banner_id  uuid    not null references marketing.banners(id)  on delete cascade,
  product_id uuid    not null references catalog.products(id)   on delete cascade,
  sort_order integer not null default 0,
  constraint pk_banner_products primary key (banner_id, product_id)
);

comment on table marketing.banner_products is
  'Products a banner promotes in addition to its own target_id.';
comment on column marketing.banner_products.sort_order is
  'Where the product sits in the banner page strip. Ascending, like banners.sort_order.';

create table if not exists marketing.banner_categories (
  banner_id   uuid    not null references marketing.banners(id)  on delete cascade,
  category_id uuid    not null references catalog.categories(id) on delete cascade,
  sort_order  integer not null default 0,
  constraint pk_banner_categories primary key (banner_id, category_id)
);

comment on table marketing.banner_categories is
  'Categories a banner promotes; every product of each one joins the strip.';
comment on column marketing.banner_categories.sort_order is
  'Where the category sits in the banner page strip. Ascending, like banners.sort_order.';

-- The primary key already serves the only read the app makes
-- (`where banner_id = …`); `sort_order` orders a handful of rows the customer
-- picked by hand, so no second index is added.

-- ---------------------------------------------------------------------------
-- 2. Row level security.
-- ---------------------------------------------------------------------------
alter table marketing.banner_products enable row level security;
alter table marketing.banner_categories enable row level security;

drop policy if exists banner_products_public_read on marketing.banner_products;
create policy banner_products_public_read on marketing.banner_products
  for select to anon, authenticated
  using (
    exists (
      select 1 from marketing.banners b
       where b.id = banner_products.banner_id and b.is_published
    )
  );

drop policy if exists banner_products_admin_write on marketing.banner_products;
create policy banner_products_admin_write on marketing.banner_products
  for all to authenticated
  using (identity.has_permission('settings.write'))
  with check (identity.has_permission('settings.write'));

drop policy if exists banner_categories_public_read on marketing.banner_categories;
create policy banner_categories_public_read on marketing.banner_categories
  for select to anon, authenticated
  using (
    exists (
      select 1 from marketing.banners b
       where b.id = banner_categories.banner_id and b.is_published
    )
  );

drop policy if exists banner_categories_admin_write on marketing.banner_categories;
create policy banner_categories_admin_write on marketing.banner_categories
  for all to authenticated
  using (identity.has_permission('settings.write'))
  with check (identity.has_permission('settings.write'));

-- ---------------------------------------------------------------------------
-- 3. Public bridge views, in the shape 032 uses for every readable table.
-- ---------------------------------------------------------------------------
create or replace view public.banner_products with (security_invoker = true) as
  select banner_id, product_id, sort_order from marketing.banner_products;

create or replace view public.banner_categories with (security_invoker = true) as
  select banner_id, category_id, sort_order from marketing.banner_categories;

-- ---------------------------------------------------------------------------
-- 4. Grants: the view is only a door, the calling role needs the table too.
-- ---------------------------------------------------------------------------
grant select on marketing.banner_products, marketing.banner_categories
  to anon;

grant select on marketing.banner_products, marketing.banner_categories
  to authenticated;

-- 056:53 shape. The `*_admin_write` policies above only decide WHICH rows a role
-- may touch; a table-level grant decides whether it may write at all. Without
-- this line an admin holding settings.write gets 42501 permission denied for the
-- table, and the RLS policy never runs. The dashboard writes the base table
-- directly (the bridge views stay read-only, as in 032), and RLS is what keeps
-- the write to settings.write.
grant insert, update, delete
  on marketing.banner_products, marketing.banner_categories
  to authenticated;

grant select on public.banner_products, public.banner_categories
  to anon, authenticated;
