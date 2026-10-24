-- tools/db_replay/assertions.sql
--
-- The state the repository promises after the migrations have been replayed.
-- Every line answers with PASS or FAIL, so the report is readable.
\set ON_ERROR_STOP on

\echo '-- the migration chain'
select case when (select count(*) from supabase_migrations.schema_migrations) = :'applied'
       then 'PASS' else 'FAIL' end as every_migration_is_recorded_once;

select case when count(*) = 0 then 'PASS' else 'FAIL' end as no_duplicate_migration_version
  from (
    select version from supabase_migrations.schema_migrations group by version having count(*) > 1
  ) d;

\echo '-- the push objects the duplicate 097 version had left out'
select case when to_regclass('engagement.push_deliveries') is not null
       then 'PASS' else 'FAIL' end as push_deliveries_table_exists;

select case when to_regclass('public.push_deliveries') is not null
       then 'PASS' else 'FAIL' end as push_deliveries_bridge_exists;

select case when to_regprocedure('public.register_device_token(text,text,text,text)') is not null
       then 'PASS' else 'FAIL' end as register_device_token_exists;

\echo '-- the schema the skipped files used to leave out'
select case when exists (
         select 1 from information_schema.columns
          where table_schema = 'identity' and table_name = 'permissions'
            and column_name = 'name_en')
       then 'PASS' else 'FAIL' end as permissions_name_en_exists;

select case when (select pg_get_constraintdef(oid) from pg_constraint
                   where conrelid = 'identity.permissions'::regclass
                     and conname = 'permissions_code_check') like '%\.[a-z_]+)+%'
       then 'PASS' else 'FAIL' end as permission_code_allows_three_segments;

select case when exists (
         select 1 from information_schema.columns
          where table_schema = 'catalog' and table_name = 'categories'
            and column_name = 'slug')
       then 'PASS' else 'FAIL' end as categories_slug_exists;

select case when not exists (
         select 1 from pg_constraint where conname = 'fk_branch_stock_variant')
       then 'PASS' else 'FAIL' end as stock_variant_foreign_key_dropped;

select case when exists (
         select 1 from pg_trigger
          where tgname in ('tr_branch_stock_variant', 'tr_movements_variant'))
       then 'PASS' else 'FAIL' end as stock_variant_triggers_exist;

\echo '-- the push objects the duplicate 097 version had left out'
select case when to_regclass('engagement.push_deliveries') is not null
       then 'PASS' else 'FAIL' end as push_deliveries_table_exists;

select case when to_regprocedure('public.register_device_token(text,text,text,text)') is not null
       then 'PASS' else 'FAIL' end as register_device_token_exists;

\echo '-- the grants'
select case when has_function_privilege(
                'anon', 'marketing.coupon_eligible_lines(uuid,uuid)', 'EXECUTE')
       then 'FAIL' else 'PASS' end as coupon_eligible_lines_not_for_anon;

select case when has_function_privilege(
                'anon', 'marketing.allocate_coupon_discount(uuid,uuid,numeric)', 'EXECUTE')
       then 'FAIL' else 'PASS' end as allocate_coupon_discount_not_for_anon;

select case when has_function_privilege(
                'authenticated', 'marketing.allocate_coupon_discount(uuid,uuid,numeric)', 'EXECUTE')
       then 'PASS' else 'FAIL' end as allocate_coupon_discount_for_customer;

select case when has_table_privilege('authenticated', 'public.saved_cards', 'SELECT')
       then 'PASS' else 'FAIL' end as saved_cards_readable_by_customer;

select case when has_table_privilege('anon', 'public.saved_cards', 'SELECT')
       then 'FAIL' else 'PASS' end as saved_cards_not_readable_by_anon;

select case when has_table_privilege('service_role', 'public.push_deliveries', 'INSERT')
       then 'PASS' else 'FAIL' end as push_deliveries_writable_by_service_role;

select case when has_table_privilege('authenticated', 'public.cart_items', 'INSERT')
       then 'FAIL' else 'PASS' end as cart_items_read_only_for_customer;

select case when has_function_privilege(
                'anon', 'public.validate_coupon_for_cart(uuid,text,jsonb)', 'EXECUTE')
       then 'FAIL' else 'PASS' end as validate_coupon_for_cart_not_for_anon;

\echo '-- the bundle identity'
select case when exists (
         select 1 from information_schema.columns
          where table_schema = 'orders' and table_name = 'cart_items'
            and column_name = 'bundle_id')
       then 'PASS' else 'FAIL' end as cart_items_bundle_id_exists;

select case when (select pg_get_constraintdef(oid) from pg_constraint
                   where conrelid = 'orders.cart_items'::regclass
                     and conname = 'cart_items_identity_key') like '%bundle_key%'
       then 'PASS' else 'FAIL' end as cart_item_identity_includes_bundle;

select case when exists (
         select 1 from information_schema.columns
          where table_schema = 'orders' and table_name = 'order_items'
            and column_name = 'source_cart_item_id')
       then 'PASS' else 'FAIL' end as order_items_source_cart_item_exists;

\echo '-- one active cart per customer and branch'
select case when (select indexdef from pg_indexes
                   where schemaname = 'orders'
                     and indexname = 'uq_carts_one_active_per_branch')
             like '%(user_id, branch_id)%'
       then 'PASS' else 'FAIL' end as one_active_cart_per_branch;

\echo '-- the coupon guard in place_order_impl'
select case when (select prosrc from pg_proc
                   where proname = 'place_order_impl'
                     and pronamespace = 'orders'::regnamespace) like '%cannot be applied%'
       then 'PASS' else 'FAIL' end as place_order_refuses_an_unusable_coupon;

\echo '-- the reference data'
select case when (select count(*) from identity.permissions) > 10
       then 'PASS' else 'FAIL' end as permissions_seeded;

select case when (select count(*) from identity.roles) = 5
       then 'PASS' else 'FAIL' end as roles_seeded;

-- The demo catalogue is gone: a database built from the migrations alone
-- carries no products, no categories and no stock.
select case when (select count(*) from catalog.categories) = 0
       then 'PASS' else 'FAIL' end as categories_empty;

select case when (select count(*) from catalog.products) = 0
       then 'PASS' else 'FAIL' end as products_empty;

select case when (select count(*) from inventory.branch_stock) = 0
       then 'PASS' else 'FAIL' end as stock_empty;

\echo '-- the payment and staff bridges of 106'
select case when (select count(*) from pg_class c join pg_namespace n on n.oid = c.relnamespace
                    where n.nspname = 'public' and c.relkind = 'v'
                      and c.relname in ('payment_transactions','payment_attempts','payment_events',
                                        'tap_customers','saved_card_provider','subscriptions',
                                        'staff_members','staff_roles','roles','role_permissions',
                                        'permissions')) = 11
       then 'PASS' else 'FAIL' end as the_eleven_bridges_exist;

select case when (select count(*) from pg_class c join pg_namespace n on n.oid = c.relnamespace
                    where n.nspname = 'public' and c.relkind = 'v'
                      and c.relname in ('payment_transactions','payment_attempts','payment_events',
                                        'tap_customers','saved_card_provider','subscriptions',
                                        'staff_members','staff_roles','roles','role_permissions',
                                        'permissions')
                      and (has_table_privilege('anon', c.oid, 'SELECT')
                           or has_table_privilege('authenticated', c.oid, 'SELECT'))) = 0
       then 'PASS' else 'FAIL' end as no_bridge_is_reachable_by_a_customer;

select case when has_table_privilege('service_role','payments.payment_transactions','INSERT')
            and has_table_privilege('service_role','payments.payment_transactions','UPDATE')
            and has_table_privilege('service_role','orders.orders','UPDATE')
            and has_table_privilege('service_role','subscriptions.subscriptions','SELECT')
       then 'PASS' else 'FAIL' end as the_service_role_may_write_the_payment_state;

select case when (select count(*) from information_schema.columns
                    where table_schema = 'public' and table_name = 'saved_cards'
                      and column_name in ('tap_customer_id','tap_card_id')) = 0
       then 'PASS' else 'FAIL' end as the_customer_saved_cards_hide_the_provider_ids;

select case when has_function_privilege('authenticated','public.activate_subscription(uuid,text)','EXECUTE')
       then 'FAIL' else 'PASS' end as the_activation_rpc_is_not_for_customers;
