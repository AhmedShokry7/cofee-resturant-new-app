-- replay_catchup_test.sql
--
-- Proves that the numbered chain the Supabase CLI applies ends in a database the
-- app can actually use.  Four files (004b, 004c, 007b, 012b) are named with a
-- letter suffix, so the CLI never applies them; 189 re-applies their effects.
-- Without that catch-up the chain alone produces: a permissions table with no
-- English label and a single-dot code CHECK, a categories table with no slug,
-- and a stock table whose variant_key foreign key rejects the "no variant"
-- sentinel.
--
-- Runs inside the harness transaction and always rolls back.
begin;

-- ---------------------------------------------------------------------------
-- 1. permissions.name_en exists and is required (the 004b effect).
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_attribute
    where attrelid = 'identity.permissions'::regclass
      and attname = 'name_en' and not attisdropped
  ) then
    raise exception 'FAIL 1: identity.permissions has no name_en column';
  end if;
  if exists (
    select 1 from pg_attribute
    where attrelid = 'identity.permissions'::regclass
      and attname = 'name_en' and attnotnull is not true
  ) then
    raise exception 'FAIL 1: permissions.name_en is nullable, so D4 is not enforced';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 2. The code CHECK accepts the multi-segment codes the app writes and still
--    rejects junk (the 004c effect).  A from-scratch chain allows exactly one
--    dot, so every three-segment code below would fail there.
-- ---------------------------------------------------------------------------
insert into identity.permissions (code, name_ar, name_en, description)
values
  ('replay.catchup.write', 'كتابة الاختبار', 'Write replay fixture', 'three segments'),
  ('replay.catchup.status.update', 'تحديث حالة الاختبار', 'Update replay status', 'four segments');

do $$
begin
  begin
    insert into identity.permissions (code, name_ar, name_en)
    values ('Catalog.Product.Write', 'x', 'x');
    raise exception 'FAIL 2: a mixed-case permission code was accepted';
  exception when check_violation then
    null;
  end;
  begin
    insert into identity.permissions (code, name_ar, name_en)
    values ('orders', 'x', 'x');
    raise exception 'FAIL 2: a dotless permission code was accepted';
  exception when check_violation then
    null;
  end;
end $$;

-- ---------------------------------------------------------------------------
-- 3. categories.slug exists, is required and unique (the 007b effect).
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_attribute
    where attrelid = 'catalog.categories'::regclass
      and attname = 'slug' and not attisdropped
  ) then
    raise exception 'FAIL 3: catalog.categories has no slug column';
  end if;
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'catalog.categories'::regclass
      and conname in ('categories_slug_unique', 'categories_slug_key')
  ) then
    raise exception 'FAIL 3: categories.slug has no unique constraint';
  end if;
  if not exists (
    select 1 from pg_indexes where indexname = 'ix_categories_slug'
  ) then
    raise exception 'FAIL 3: ix_categories_slug is missing';
  end if;
end $$;

do $$
declare
  v_category uuid;
begin
  insert into catalog.categories (name_ar, name_en, slug, sort_order, is_active)
  values ('اختبار سلاج', 'Slug Test', 'replay-catchup-slug', 999, true)
  returning id into v_category;

  if v_category is null then
    raise exception 'FAIL 3: the category fixture was not written';
  end if;

  begin
    insert into catalog.categories (name_ar, name_en, slug, sort_order, is_active)
    values ('اختبار سلاج مكرر', 'Slug Test Duplicate', 'replay-catchup-slug', 998, true);
    raise exception 'FAIL 3: a duplicate category slug was accepted';
  exception when unique_violation then
    if sqlstate <> '23505' then raise; end if;
  end;

  begin
    insert into catalog.categories (name_ar, name_en, sort_order, is_active)
    values ('بلا سلاج', 'No Slug', 997, true);
    raise exception 'FAIL 3: a category without a slug was accepted';
  exception when not_null_violation then
    if sqlstate <> '23502' then raise; end if;
  end;
end $$;

-- ---------------------------------------------------------------------------
-- 4. Stock rows use the sentinel variant key (the 012b effect).  A
--    from-scratch chain still has the option_values foreign key here, so the
--    first insert below fails with 23503 there.
-- ---------------------------------------------------------------------------
do $$
declare
  v_branch  uuid;
  v_product uuid;
  v_rows    integer;
begin
  if exists (
    select 1 from pg_constraint
    where conrelid = 'inventory.branch_stock'::regclass
      and conname = 'fk_branch_stock_variant'
  ) then
    raise exception 'FAIL 4: branch_stock still points variant_key at option_values with a foreign key';
  end if;
  if not exists (
    select 1 from pg_trigger
    where tgrelid = 'inventory.branch_stock'::regclass
      and tgname = 'tr_branch_stock_variant'
  ) then
    raise exception 'FAIL 4: tr_branch_stock_variant is missing';
  end if;
  if not exists (
    select 1 from pg_trigger
    where tgrelid = 'inventory.stock_movements'::regclass
      and tgname = 'tr_movements_variant'
  ) then
    raise exception 'FAIL 4: tr_movements_variant is missing';
  end if;

  select b.id, p.id into v_branch, v_product
    from core.branches b, catalog.products p
   order by b.id, p.id limit 1;
  if v_branch is null or v_product is null then
    raise exception 'FAIL 4: no branch/product pair for the stock fixture';
  end if;

  delete from inventory.branch_stock
   where branch_id = v_branch and product_id = v_product;

  insert into inventory.branch_stock (branch_id, product_id, quantity_on_hand)
  values (v_branch, v_product, 5);

  select count(*) into v_rows from inventory.branch_stock
   where branch_id = v_branch and product_id = v_product
     and variant_key = '00000000-0000-0000-0000-000000000000'::uuid;
  if v_rows <> 1 then
    raise exception 'FAIL 4: the sentinel stock row was not written';
  end if;

  -- The guard is a deferrable constraint trigger, so it only speaks at commit.
  -- This transaction never commits, which is why it is forced immediate here;
  -- without that, a from-scratch chain missing the trigger would look clean.
  set constraints all immediate;
  begin
    insert into inventory.branch_stock (branch_id, product_id, variant_key, quantity_on_hand)
    values (v_branch, v_product, '11111111-1111-1111-1111-111111111111'::uuid, 1);
    raise exception 'FAIL 4: a variant key that the product does not offer was accepted';
  exception when others then
    if sqlstate <> '23503' then raise; end if;
  end;
  set constraints all deferred;
end $$;

-- ---------------------------------------------------------------------------
-- Verdict.
-- ---------------------------------------------------------------------------
select
  'replay catch-up' as test,
  (select count(*) from pg_attribute
    where attrelid = 'identity.permissions'::regclass
      and attname = 'name_en' and attnotnull) as permissions_name_en,
  (select pg_get_constraintdef(oid) from pg_constraint
    where conname = 'permissions_code_check') as permission_code_check,
  (select count(*) from pg_indexes where indexname = 'ix_categories_slug') as category_slug_index,
  (select count(*) from pg_trigger
    where tgname in ('tr_branch_stock_variant', 'tr_movements_variant')
      and not tgisinternal) as variant_triggers,
  (select count(*) from pg_constraint
    where conname in ('fk_branch_stock_variant', 'fk_movements_variant')) as leftover_foreign_keys;

rollback;
