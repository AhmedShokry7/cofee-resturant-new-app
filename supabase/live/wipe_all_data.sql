-- wipe_all_data.sql
--
-- Empties the application data so the client starts from zero.
--
-- THIS DELETES EVERY BUSINESS ROW AND EVERY AUTH USER, INCLUDING THE ACCOUNT
-- YOU SIGN IN WITH. Take a backup first (Supabase Dashboard -> Database ->
-- Backups) and read the two lists below before running it.
--
-- Close the admin app and every dashboard tab before you run it. Open tabs
-- keep short read locks on these tables, and a table cannot be emptied while
-- another session is reading it. The script still retries on its own, but
-- closing the tabs makes it finish on the first attempt.
--
-- If it reports wipe_blocked_by_active_sessions, nothing was deleted: the
-- whole transaction rolled back, so fix the locks and run it again.
--
-- What is NOT touched:
--   * every schema, table, column, index, constraint, trigger, function,
--     policy, view and RLS rule;
--   * the migration history in supabase_migrations.schema_migrations;
--   * Supabase internals (auth schema, storage buckets, realtime setup).
--
-- What is preserved on purpose (system reference data the dashboard needs):
--   * identity.permissions / identity.roles / identity.role_permissions
--     -> the roles and permission codes used by every admin page;
--   * orders.status_transitions     -> the order status workflow;
--   * payments.payment_methods      -> cash / card / apple pay / mada;
--   * core.brands                   -> the single organisation row that
--                                      admin_save_branch() requires;
--   * loyalty.loyalty_rules         -> the default earning rule.
--
-- Everything else in the schemas below is truncated: branches, delivery
-- zones, products, categories, bundles, customers, staff, orders, carts,
-- payments, inventory, kitchen tickets, tables/reservations, subscriptions,
-- loyalty accounts/rewards, banners, coupons, reviews, notifications, audit
-- log and the AI tables.
--
-- Uploaded files in Storage are not rows in these schemas. If the old product
-- or branch pictures should go too, clear the product-images / branch-images
-- folders from Supabase Dashboard -> Storage after this script.
--
-- After the wipe nobody can sign in until a new owner is created. The commented
-- block at the bottom shows the two steps.

begin;

-- Waiting a few seconds for a read lock is fine; waiting forever leaves the
-- editor spinning and ends in a deadlock instead. The retry loop below turns
-- both into another attempt.
set local lock_timeout = '5s';

do $$
declare
  v_schemas constant text[] := array[
    'core', 'catalog', 'orders', 'inventory', 'payments', 'loyalty',
    'marketing', 'engagement', 'identity', 'kitchen', 'floor',
    'subscriptions', 'ai', 'public'
  ];
  v_keep constant text[] := array[
    'identity.permissions',
    'identity.roles',
    'identity.role_permissions',
    'orders.status_transitions',
    'payments.payment_methods',
    'core.brands',
    'loyalty.loyalty_rules'
  ];
  v_tables  text;
  v_attempt integer := 0;
begin
  select string_agg(format('%I.%I', t.schemaname, t.tablename), ', '
                    order by t.schemaname, t.tablename)
    into v_tables
    from pg_tables t
   where t.schemaname = any (v_schemas)
     and (t.schemaname || '.' || t.tablename) <> all (v_keep);

  if v_tables is null then
    return;
  end if;

  -- Each attempt is its own subtransaction: a deadlock or a lock timeout
  -- rolls back that attempt only, so the next one starts clean.
  loop
    v_attempt := v_attempt + 1;
    begin
      execute 'truncate table ' || v_tables || ' restart identity cascade';
      exit;
    exception
      when deadlock_detected or lock_not_available then
        if v_attempt >= 8 then
          raise exception 'wipe_blocked_by_active_sessions'
            using errcode = 'P0001',
                  detail = format('still locked after %s attempts', v_attempt),
                  hint = 'Close the admin app and every dashboard tab, then run the script again. Nothing was deleted.';
        end if;
        perform pg_sleep(least(v_attempt, 4));
    end;
  end loop;
end $$;

-- The staff and profile rows are already gone, so the restrict foreign key
-- from identity.staff_members no longer blocks deleting the auth users.
do $$
declare
  v_attempt integer := 0;
begin
  loop
    v_attempt := v_attempt + 1;
    begin
      delete from auth.users;
      exit;
    exception
      when deadlock_detected or lock_not_available then
        if v_attempt >= 8 then
          raise exception 'wipe_blocked_by_active_sessions'
            using errcode = 'P0001',
                  detail = format('auth users still locked after %s attempts', v_attempt),
                  hint = 'Close the admin app and every dashboard tab, then run the script again. Nothing was deleted.';
        end if;
        perform pg_sleep(least(v_attempt, 4));
    end;
  end loop;
end $$;

commit;

-- ---------------------------------------------------------------------------
-- Result: reference rows that stay, and the business tables that are empty.
-- ---------------------------------------------------------------------------
select 'roles' as kept, count(*) as rows from identity.roles
union all
select 'permissions', count(*) from identity.permissions
union all
select 'role_permissions', count(*) from identity.role_permissions
union all
select 'status_transitions', count(*) from orders.status_transitions
union all
select 'payment_methods', count(*) from payments.payment_methods
union all
select 'brands', count(*) from core.brands
union all
select 'loyalty_rules', count(*) from loyalty.loyalty_rules
union all
select 'auth users', count(*) from auth.users
union all
select 'branches', count(*) from core.branches
union all
select 'categories', count(*) from catalog.categories
union all
select 'products', count(*) from catalog.products
union all
select 'orders', count(*) from orders.orders
union all
select 'customers', count(*) from identity.profiles
union all
select 'staff', count(*) from identity.staff_members;

-- ---------------------------------------------------------------------------
-- Rename the reference brand before creating branches
-- ---------------------------------------------------------------------------
-- core.brands keeps the single organisation row that admin_save_branch()
-- requires. Replace the values with the client's real identity.
--
-- update core.brands
--    set name_ar = 'اسم العلامة',
--        name_en = 'Brand name',
--        support_email = 'support@example.com',
--        support_phone = '+20...';

-- ---------------------------------------------------------------------------
-- Create the first owner after the wipe
-- ---------------------------------------------------------------------------
-- 1. Supabase Dashboard -> Authentication -> Users -> Add user.
--    Use the client's real email, set a strong password and confirm the email.
--
-- 2. Replace the email below and run this block in the SQL Editor.
--
-- insert into identity.staff_members (user_id, status, full_name, email)
-- select u.id, 'active', 'Owner', u.email
--   from auth.users u
--  where u.email = 'owner@example.com'
-- on conflict (user_id) do update
--   set status = 'active',
--       full_name = excluded.full_name;
--
-- insert into identity.staff_roles (staff_id, role_id)
-- select sm.id, r.id
--   from identity.staff_members sm
--   join identity.roles r on r.code = 'owner'
--  where sm.email = 'owner@example.com'
-- on conflict do nothing;
