-- banner_links_test.sql
-- Behaviour test for 222_marketing_banner_links.sql: the two link tables a banner
-- page reads to show everything the admin chose, not only the one row
-- `banners.target_id` can hold.
--
-- STATUS: NOT EXECUTED.
--   The app-side author of migration 222 has no write path to a database: the
--   Supabase Management API answers 401 with the token in .env, no cloud CLI is
--   installed, and the service-role key is off-limits by policy. So nothing below
--   was observed running. Treat every assertion as a claim to be checked the first
--   time someone applies 222 on an isolated database, not as a pass.
--
--   One attempt WAS made and it failed before any assertion ran. This file used to
--   open with `\set ON_ERROR_STOP on` and mark each section with `\echo`. Those are
--   psql meta-commands, not SQL, and the Supabase SQL Editor answers
--   `42601: syntax error at or near "\" LINE 53` for them. They are gone: the
--   markers are plain comments now, each section title lives in the RAISE NOTICE of
--   the block that proves it, and the file ends with the single report row the other
--   tests in this directory return, so an editor run shows something readable.
--
-- RUN THIS ONLY AGAINST AN ISOLATED, NON-PRODUCTION DATABASE, and only after
-- 222 has been applied to it. Section 0 checks exactly that, so a database without
-- the migration says so in words instead of failing on a missing table.
--
-- Paste the whole file into the Supabase SQL Editor and Run, or:
--   psql "$LOCAL_DB_URL" -v ON_ERROR_STOP=1 -f banner_links_test.sql
--   supabase db query --linked -f banner_links_test.sql
--
-- Every row-count assertion that concerns access runs as the real anon or
-- authenticated role with real JWT claims, the way set_default_address_test.sql
-- does: a check made while connected as postgres proves nothing about RLS, because
-- that role bypasses it. The grant checks near the end are metadata introspection
-- (has_table_privilege), which does report another role's rights, so those run as
-- the connecting role.
--
-- The script leaves the database unchanged: every fixture is created in one
-- transaction that is rolled back at the end. The ids are passed to the
-- assertions through transaction-local custom GUCs, so reading them needs no
-- grant and works the same under any SET ROLE.
--
-- WHAT THIS PROVES, IN ORDER
--   0  the migration is actually present in this database
--   1  a link to a product, category or banner that does not exist is refused:
--      the dangling id is the failure this feature exists to remove, and a real
--      foreign key is the only thing that can remove it
--   2  choosing the same product twice for one banner is refused by the composite
--      primary key, so a card cannot appear twice on the page
--   3  sort_order defaults to 0, the same ascending display column as banners
--   4  anon reads the links of a published banner, through the bridge view the
--      customer app actually queries, and the same rows through the base table
--   5  anon reads nothing for a draft banner - the links follow banners_public_read
--      instead of being open like 056's coupon links
--   6  an admin sees the draft's links too, because RLS ORs the permissive SELECT
--      policies and *_admin_write covers select
--   7  an admin writes: link, reorder, delete
--   8  a staff member without settings.write writes nothing
--   9  the views are security_invoker and both client roles hold SELECT on the
--      BASE table - the mistake 033 caught in 032's views (42501 through an open
--      view) - and authenticated holds the INSERT/UPDATE/DELETE the policies above
--      assume, which an RLS policy on its own cannot grant
--  10  removing a banner or a product takes its links with it, so no row can be
--      left pointing at nothing

begin;

-- ---------------------------------------------------------------------------
-- Fixtures: two categories with three products, one published banner and one
-- draft, each linked to one product and one category.
-- ---------------------------------------------------------------------------
insert into catalog.categories (id, name_ar, name_en, sort_order, is_active)
values
  ('2d100000-0000-4000-8000-000000000001', 'حارة الروابط', 'Links Hot', 1, true),
  ('2d100000-0000-4000-8000-000000000002', 'باردة الروابط', 'Links Cold', 2, true);

insert into catalog.products
  (id, category_id, sku, slug, name_ar, name_en, base_price, sort_order, is_active)
values
  ('2d200000-0000-4000-8000-000000000001', '2d100000-0000-4000-8000-000000000001', 'BL-1', 'bl-1', 'روابط 1', 'Link One', 15, 1, true),
  ('2d200000-0000-4000-8000-000000000002', '2d100000-0000-4000-8000-000000000001', 'BL-2', 'bl-2', 'روابط 2', 'Link Two', 18, 2, true),
  ('2d200000-0000-4000-8000-000000000003', '2d100000-0000-4000-8000-000000000002', 'BL-3', 'bl-3', 'روابط 3', 'Link Three', 20, 3, true);

-- target_type 'none' with no target_id: the banner under test is the link tables,
-- not the single target column 222 leaves alone.
insert into marketing.banners
  (id, title_ar, title_en, image_url, target_type, sort_order, is_published)
values
  ('2d300000-0000-4000-8000-000000000001', 'بانر منشور', 'Published Banner', 'https://example.test/published.jpg', 'none', 1, true),
  ('2d300000-0000-4000-8000-000000000002', 'بانر مسودة', 'Draft Banner', 'https://example.test/draft.jpg', 'none', 2, false);

insert into marketing.banner_products (banner_id, product_id, sort_order)
values
  ('2d300000-0000-4000-8000-000000000001', '2d200000-0000-4000-8000-000000000001', 0),
  ('2d300000-0000-4000-8000-000000000001', '2d200000-0000-4000-8000-000000000003', 1),
  ('2d300000-0000-4000-8000-000000000002', '2d200000-0000-4000-8000-000000000002', 0);

insert into marketing.banner_categories (banner_id, category_id, sort_order)
values
  ('2d300000-0000-4000-8000-000000000001', '2d100000-0000-4000-8000-000000000002', 0),
  ('2d300000-0000-4000-8000-000000000002', '2d100000-0000-4000-8000-000000000001', 0);

-- One staff member who holds settings.write through the seeded manager role and
-- one who does not. Only (id, email) is written to auth.users; on a Supabase
-- version that adds more NOT NULL columns there, extend this insert rather than
-- dropping the test.
insert into auth.users (id, email)
values
  ('2d400000-0000-4000-8000-000000000001', 'bl-manager@test.local'),
  ('2d400000-0000-4000-8000-000000000002', 'bl-cashier@test.local');

insert into identity.staff_members (id, user_id, status, full_name, email)
values
  ('2d500000-0000-4000-8000-000000000001', '2d400000-0000-4000-8000-000000000001', 'active', 'BL Manager', 'bl-manager@test.local'),
  ('2d500000-0000-4000-8000-000000000002', '2d400000-0000-4000-8000-000000000002', 'active', 'BL Cashier', 'bl-cashier@test.local');

insert into identity.staff_roles (staff_id, role_id, branch_id)
select '2d500000-0000-4000-8000-000000000001', r.id, null
  from identity.roles r where r.code = 'manager';

insert into identity.staff_roles (staff_id, role_id, branch_id)
select '2d500000-0000-4000-8000-000000000002', r.id, null
  from identity.roles r where r.code = 'cashier';

select set_config('bl.published', '2d300000-0000-4000-8000-000000000001', true);
select set_config('bl.draft', '2d300000-0000-4000-8000-000000000002', true);
select set_config('bl.p1', '2d200000-0000-4000-8000-000000000001', true);
select set_config('bl.p2', '2d200000-0000-4000-8000-000000000002', true);
select set_config('bl.p3', '2d200000-0000-4000-8000-000000000003', true);
select set_config('bl.cat_cold', '2d100000-0000-4000-8000-000000000002', true);
select set_config('bl.manager', '2d400000-0000-4000-8000-000000000001', true);
select set_config('bl.cashier', '2d400000-0000-4000-8000-000000000002', true);

-- ---------------------------------------------------------------------------
-- 0. The migration is here. Everything below reads or writes these objects, so a
-- database that has not had 222 applied would otherwise fail with a confusing
-- missing-table error on the first fixture insert instead of naming the real cause.
-- ---------------------------------------------------------------------------
do $$
begin
  if to_regclass('marketing.banner_products') is null then
    raise exception 'FAIL 0: marketing.banner_products does not exist - apply 222_marketing_banner_links.sql to this database first';
  end if;
  if to_regclass('marketing.banner_categories') is null then
    raise exception 'FAIL 0: marketing.banner_categories does not exist - apply 222_marketing_banner_links.sql first';
  end if;
  if to_regclass('public.banner_products') is null then
    raise exception 'FAIL 0: the public.banner_products bridge view is missing - apply 222 first';
  end if;
  if to_regclass('public.banner_categories') is null then
    raise exception 'FAIL 0: the public.banner_categories bridge view is missing - apply 222 first';
  end if;
  raise notice 'PASS 0: the link tables and both bridge views exist';
end $$;

-- ---------------------------------------------------------------------------
-- 1 to 5 run as the connecting role: a foreign key and a primary key are enforced
-- for every role, so nothing there depends on RLS.
-- ---------------------------------------------------------------------------
do $$
declare v_failed boolean := false;
begin
  begin
    insert into marketing.banner_products (banner_id, product_id)
    values (current_setting('bl.published')::uuid,
            '00000000-0000-4000-8000-000000000000');
  exception when foreign_key_violation then
    v_failed := true;
  end;
  if not v_failed then
    raise exception 'FAIL 1: a dangling product link was accepted';
  end if;
  raise notice 'PASS 1: product_id carries a real foreign key';
end $$;

do $$
declare v_failed boolean := false;
begin
  begin
    insert into marketing.banner_categories (banner_id, category_id)
    values (current_setting('bl.published')::uuid,
            '00000000-0000-4000-8000-000000000000');
  exception when foreign_key_violation then
    v_failed := true;
  end;
  if not v_failed then
    raise exception 'FAIL 2: a dangling category link was accepted';
  end if;
  raise notice 'PASS 2: category_id carries a real foreign key';
end $$;

do $$
declare v_failed boolean := false;
begin
  begin
    insert into marketing.banner_products (banner_id, product_id)
    values ('00000000-0000-4000-8000-000000000000', current_setting('bl.p1')::uuid);
  exception when foreign_key_violation then
    v_failed := true;
  end;
  if not v_failed then
    raise exception 'FAIL 3: a link to a banner that never existed was accepted';
  end if;
  raise notice 'PASS 3: banner_id carries a real foreign key';
end $$;

-- 4. The dashboard writes these rows on every save. Without the composite key a
-- second pick of the same product would be a second row, and the banner page would
-- show the same card twice.
do $$
declare v_failed boolean := false;
begin
  begin
    insert into marketing.banner_products (banner_id, product_id)
    values (current_setting('bl.published')::uuid, current_setting('bl.p1')::uuid);
  exception when unique_violation then
    v_failed := true;
  end;
  if not v_failed then
    raise exception 'FAIL 4: a duplicate product link was accepted';
  end if;
  raise notice 'PASS 4: (banner_id, product_id) is the primary key';
end $$;

do $$
declare v_order integer;
begin
  insert into marketing.banner_products (banner_id, product_id)
  values (current_setting('bl.draft')::uuid, current_setting('bl.p3')::uuid)
  on conflict do nothing;

  select bp.sort_order into v_order
    from marketing.banner_products bp
   where bp.banner_id = current_setting('bl.draft')::uuid
     and bp.product_id = current_setting('bl.p3')::uuid;
  if v_order is distinct from 0 then
    raise exception 'FAIL 5: sort_order defaulted to %', coalesce(v_order::text, 'null');
  end if;
  raise notice 'PASS 5: a link saved without an order sorts first';
end $$;

-- ---------------------------------------------------------------------------
-- 6 onward: the customer app is anon until sign-in, so the read the banner page
-- makes has to be proven as anon, through the view PostgREST actually queries.
-- ---------------------------------------------------------------------------
set local role anon;

do $$
declare v_rows integer;
begin
  select count(*) into v_rows from public.banner_products
   where banner_id = current_setting('bl.published')::uuid;
  if v_rows <> 2 then
    raise exception 'FAIL 6: anon saw % product links for a published banner, expected 2', v_rows;
  end if;

  select count(*) into v_rows from public.banner_categories
   where banner_id = current_setting('bl.published')::uuid;
  if v_rows <> 1 then
    raise exception 'FAIL 6: anon saw % category links for a published banner, expected 1', v_rows;
  end if;

  -- The same two reads against the base table: the view is a door, not a second
  -- copy of the data, so the policy has to answer identically either way.
  select count(*) into v_rows from marketing.banner_products
   where banner_id = current_setting('bl.published')::uuid;
  if v_rows <> 2 then
    raise exception 'FAIL 6: the base table answered % product links, expected 2', v_rows;
  end if;
  raise notice 'PASS 6: the strip of a published banner is readable by anon, view and table alike';
end $$;

do $$
declare v_first uuid;
begin
  select product_id into v_first from public.banner_products
   where banner_id = current_setting('bl.published')::uuid
   order by sort_order asc
   limit 1;
  if v_first <> current_setting('bl.p1')::uuid then
    raise exception 'FAIL 7: sort_order asc did not put the first pick first';
  end if;
  raise notice 'PASS 7: sort_order is an ascending display column';
end $$;

-- 8. This is the point where 222 is narrower on purpose than 056's coupon links
-- (`using (true)`): an unpublished banner's choices are not public.
do $$
declare v_rows integer;
begin
  select count(*) into v_rows from public.banner_products
   where banner_id = current_setting('bl.draft')::uuid;
  if v_rows <> 0 then
    raise exception 'FAIL 8: anon read % links of a draft banner', v_rows;
  end if;

  select count(*) into v_rows from public.banner_categories
   where banner_id = current_setting('bl.draft')::uuid;
  if v_rows <> 0 then
    raise exception 'FAIL 8: anon read % category links of a draft banner', v_rows;
  end if;
  raise notice 'PASS 8: a draft banner keeps its links private';
end $$;

reset role;
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"2d400000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);

-- 9. RLS ORs the permissive SELECT policies, and banner_products_admin_write is
-- `for all`, so the dashboard can list what it saved.
do $$
declare v_rows integer;
begin
  select count(*) into v_rows from marketing.banner_products
   where banner_id = current_setting('bl.draft')::uuid;
  if v_rows <> 2 then
    raise exception 'FAIL 9: an admin saw % draft links, expected 2', v_rows;
  end if;
  raise notice 'PASS 9: settings.write reads a draft''s links';
end $$;

do $$
declare v_rows integer;
begin
  insert into marketing.banner_categories (banner_id, category_id, sort_order)
  values (current_setting('bl.published')::uuid,
          '2d100000-0000-4000-8000-000000000001', 1)
  on conflict (banner_id, category_id) do update
     set sort_order = excluded.sort_order;

  select count(*) into v_rows from marketing.banner_categories
   where banner_id = current_setting('bl.published')::uuid;
  if v_rows <> 2 then
    raise exception 'FAIL 10: the upsert left % category links, expected 2', v_rows;
  end if;

  update marketing.banner_products set sort_order = 5
   where banner_id = current_setting('bl.published')::uuid
     and product_id = current_setting('bl.p3')::uuid;
  if not exists (select 1 from marketing.banner_products
                  where product_id = current_setting('bl.p3')::uuid and sort_order = 5) then
    raise exception 'FAIL 10: an admin could not reorder a link';
  end if;

  delete from marketing.banner_categories
   where banner_id = current_setting('bl.published')::uuid
     and category_id = '2d100000-0000-4000-8000-000000000001';
  raise notice 'PASS 10: insert, reorder and delete all reach the table';
end $$;

reset role;
select set_config('request.jwt.claims',
  '{"sub":"2d400000-0000-4000-8000-000000000002","role":"authenticated","aud":"authenticated"}', true);
set local role authenticated;

-- 11. bl.p2, not bl.p3: the published banner already links p3, and a duplicate
-- would be stopped by the primary key before RLS ever ran, proving nothing.
do $$
declare
  v_failed boolean := false;
  v_reason text;
begin
  begin
    insert into marketing.banner_products (banner_id, product_id)
    values (current_setting('bl.published')::uuid, current_setting('bl.p2')::uuid);
  exception when insufficient_privilege then
    v_failed := true;
    v_reason := sqlerrm;
  when others then
    v_failed := true;
    v_reason := sqlerrm;
  end;
  if not v_failed then
    raise exception 'FAIL 11: a cashier added a banner link';
  end if;
  if v_reason not like '%row-level security%' then
    raise exception 'FAIL 11: expected an RLS refusal, got: %', v_reason;
  end if;
  raise notice 'PASS 11: the dashboard permission is the only write path';
end $$;

reset role;

-- 12. The read half: security_invoker views run as the caller, so the CALLING role
-- needs SELECT on the BASE table - the mistake 032 made and 033 had to fix, where
-- three bridge views answered 42501 through an open door.
-- The write half: an RLS policy only chooses rows. Without a table-level INSERT
-- grant even settings.write is refused before the policy is consulted.
do $$
begin
  if not has_table_privilege('anon', 'marketing.banner_products', 'select') then
    raise exception 'FAIL 12: anon lost SELECT on marketing.banner_products';
  end if;
  if not has_table_privilege('anon', 'marketing.banner_categories', 'select') then
    raise exception 'FAIL 12: anon lost SELECT on marketing.banner_categories';
  end if;
  if not has_table_privilege('authenticated', 'marketing.banner_products', 'select') then
    raise exception 'FAIL 12: authenticated lost SELECT on marketing.banner_products';
  end if;
  if not has_table_privilege('authenticated', 'marketing.banner_categories', 'select') then
    raise exception 'FAIL 12: authenticated lost SELECT on marketing.banner_categories';
  end if;
  if not has_table_privilege('anon', 'public.banner_products', 'select') then
    raise exception 'FAIL 12: anon lost SELECT on public.banner_products';
  end if;
  if not has_table_privilege('anon', 'public.banner_categories', 'select') then
    raise exception 'FAIL 12: anon lost SELECT on public.banner_categories';
  end if;
  if not has_table_privilege('authenticated', 'marketing.banner_products', 'insert') then
    raise exception 'FAIL 12: an admin cannot write marketing.banner_products at all';
  end if;
  if not has_table_privilege('authenticated', 'marketing.banner_categories', 'delete') then
    raise exception 'FAIL 12: an admin cannot delete from marketing.banner_categories';
  end if;
  -- The customer must not reach the table this way at all: anon has no write
  -- grant, and section 11 showed authenticated has none below the permission.
  if has_table_privilege('anon', 'marketing.banner_products', 'insert') then
    raise exception 'FAIL 12: anon may insert banner links';
  end if;
  if has_table_privilege('anon', 'marketing.banner_categories', 'update') then
    raise exception 'FAIL 12: anon may update banner links';
  end if;
  raise notice 'PASS 12: reads reach the table, writes reach it only for authenticated';
end $$;

do $$
declare v_options text;
begin
  select array_to_string(reloptions, ',') into v_options
    from pg_class where oid = 'public.banner_products'::regclass;
  if v_options not like '%security_invoker=true%' then
    raise exception 'FAIL 13: public.banner_products is not security_invoker (%); it would read past RLS', coalesce(v_options, 'null');
  end if;

  select array_to_string(reloptions, ',') into v_options
    from pg_class where oid = 'public.banner_categories'::regclass;
  if v_options not like '%security_invoker=true%' then
    raise exception 'FAIL 13: public.banner_categories is not security_invoker (%)', coalesce(v_options, 'null');
  end if;
  raise notice 'PASS 13: both bridge views defer to the table''s policies';
end $$;

do $$
declare v_ind integer;
begin
  select count(*) into v_ind
    from pg_index i
    join pg_class c on c.oid = i.indrelid
   where c.relname = 'banner_products' and i.indisprimary;
  if v_ind <> 1 then
    raise exception 'FAIL 14: marketing.banner_products has no primary key index';
  end if;
  raise notice 'PASS 14: the banner_id read uses the primary key';
end $$;

-- ---------------------------------------------------------------------------
-- 15 and 16: the cascade. Last, because both destroy fixture rows - and the rows
-- they destroy are the point: nothing may be left linking to a banner or a product
-- that no longer exists.
-- ---------------------------------------------------------------------------
do $$
declare v_rows integer;
begin
  delete from marketing.banners where id = current_setting('bl.published')::uuid;

  select count(*) into v_rows from marketing.banner_products
   where banner_id = current_setting('bl.published')::uuid;
  if v_rows <> 0 then
    raise exception 'FAIL 15: % product links survived the banner', v_rows;
  end if;
  select count(*) into v_rows from marketing.banner_categories
   where banner_id = current_setting('bl.published')::uuid;
  if v_rows <> 0 then
    raise exception 'FAIL 15: % category links survived the banner', v_rows;
  end if;
  raise notice 'PASS 15: on delete cascade from banners';
end $$;

do $$
declare v_rows integer;
begin
  delete from catalog.products where id = current_setting('bl.p3')::uuid;

  select count(*) into v_rows from marketing.banner_products
   where product_id = current_setting('bl.p3')::uuid;
  if v_rows <> 0 then
    raise exception 'FAIL 16: % links survived the product', v_rows;
  end if;
  -- The draft banner's link to p2: the published banner was deleted in section 15,
  -- so the only link left in the database has to be this one.
  if not exists (select 1 from marketing.banner_products
                  where banner_id = current_setting('bl.draft')::uuid
                    and product_id = current_setting('bl.p2')::uuid) then
    raise exception 'FAIL 16: an unrelated link went with the product';
  end if;
  raise notice 'PASS 16: on delete cascade from products, and nothing more';
end $$;

-- The report a runner prints. Everything above raises on the first mismatch, so
-- reaching this row is itself the proof, and the rollback keeps none of it.
select
  'reached the end: no assertion failed' as verdict,
  (select count(*) from marketing.banner_products) as remaining_product_links,
  (select count(*) from marketing.banner_categories) as remaining_category_links;

rollback;
