-- restore_grants_regression_test.sql
--
-- Positive and negative privilege assertions that complement
-- harden_grants_test.sql, which only checks that sensitive functions are NOT
-- reachable. That blind spot is what let 081_harden_function_and_view_grants.sql
-- ship: every assertion in it still passes while the entire customer app is down.
--
-- Background. 081 revoked EXECUTE from the PUBLIC pseudo-role on the internal
-- schemas. PUBLIC is inherited by every role, so `authenticated`, `service_role`
-- and `supabase_auth_admin` lost EXECUTE as well. Two consequences broke the app:
--   * RLS policy qualifiers call identity.has_permission() / is_staff() /
--     can_manage_branch() / manages_all_branches(). A policy expression that
--     raises aborts the whole query, so every authenticated catalogue read died
--     with 42501.
--   * The public.* bridges are SECURITY INVOKER, so the caller must be able to
--     execute the wrapped catalog./orders./marketing./subscriptions. function.
--
-- Run as a privileged role; has_function_privilege reports another role's rights.
--
-- Restored by 083_restore_client_function_execute_grants.sql, except the two
-- search rebuild functions: 205_admin_set_category_image.sql took them off the
-- positive list in section 6 rather than granting them back. See that file for
-- why a client-rol write there is not wanted.

\set ON_ERROR_STOP on

-- ---------------------------------------------------------------------------
-- 1. RLS policy helpers must be executable by `authenticated`.
--    61 policies call has_permission alone. Without this, every authenticated
--    read of catalog.*, core.*, marketing.*, orders.* ... fails.
-- ---------------------------------------------------------------------------
select case when has_function_privilege('authenticated','identity.has_permission(text)','EXECUTE')
       then 'PASS' else 'FAIL: authenticated cannot execute identity.has_permission' end as t1;
select case when has_function_privilege('authenticated','identity.is_staff()','EXECUTE')
       then 'PASS' else 'FAIL: authenticated cannot execute identity.is_staff' end as t2;
select case when has_function_privilege('authenticated','identity.can_manage_branch(uuid)','EXECUTE')
       then 'PASS' else 'FAIL: authenticated cannot execute identity.can_manage_branch' end as t3;
select case when has_function_privilege('authenticated','identity.manages_all_branches()','EXECUTE')
       then 'PASS' else 'FAIL: authenticated cannot execute identity.manages_all_branches' end as t4;

-- ---------------------------------------------------------------------------
-- 2. Guest catalogue RPC targets. 036 section 2 granted these public bridges to
--    anon so the menu renders before sign-in; both roles need the wrapped
--    function because the bridge is SECURITY INVOKER.
-- ---------------------------------------------------------------------------
select case when has_function_privilege('anon','catalog.get_featured(uuid,integer)','EXECUTE')
       then 'PASS' else 'FAIL: anon cannot execute catalog.get_featured' end as t5;
select case when has_function_privilege('anon','catalog.search_products(text,uuid,uuid,numeric,numeric,text,integer,integer)','EXECUTE')
       then 'PASS' else 'FAIL: anon cannot execute catalog.search_products' end as t6;
select case when has_function_privilege('anon','catalog.get_best_sellers(uuid,interval,integer)','EXECUTE')
       then 'PASS' else 'FAIL: anon cannot execute catalog.get_best_sellers' end as t7;
select case when has_function_privilege('anon','catalog.resolve_effective_price(uuid,uuid,uuid[])','EXECUTE')
       then 'PASS' else 'FAIL: anon cannot execute catalog.resolve_effective_price' end as t8;
select case when has_function_privilege('anon','core.active_branches()','EXECUTE')
       then 'PASS' else 'FAIL: anon cannot execute core.active_branches' end as t9;
select case when has_function_privilege('authenticated','catalog.get_featured(uuid,integer)','EXECUTE')
       then 'PASS' else 'FAIL: authenticated cannot execute catalog.get_featured' end as t10;
select case when has_function_privilege('authenticated','catalog.search_products(text,uuid,uuid,numeric,numeric,text,integer,integer)','EXECUTE')
       then 'PASS' else 'FAIL: authenticated cannot execute catalog.search_products' end as t11;
select case when has_function_privilege('authenticated','core.active_branches()','EXECUTE')
       then 'PASS' else 'FAIL: authenticated cannot execute core.active_branches' end as t12;

-- ---------------------------------------------------------------------------
-- 3. The public bridge itself must still be reachable for those same roles.
--    Grants on the bridge are worthless if the wrapper is gone.
-- ---------------------------------------------------------------------------
select case when has_function_privilege('anon','public.get_featured(uuid,integer)','EXECUTE')
       then 'PASS' else 'FAIL: anon cannot execute public.get_featured' end as t13;
select case when has_function_privilege('anon','public.search_products(text,uuid,uuid,numeric,numeric,text,integer,integer)','EXECUTE')
       then 'PASS' else 'FAIL: anon cannot execute public.search_products' end as t14;
select case when has_function_privilege('anon','public.active_branches()','EXECUTE')
       then 'PASS' else 'FAIL: anon cannot execute public.active_branches' end as t15;

-- ---------------------------------------------------------------------------
-- 4. Checkout-time resolution is signed-in only. public.resolve_delivery_zone is
--    SECURITY INVOKER over all three, so authenticated needs each one; anon must
--    not gain them (delivery zones are still readable for guests through the
--    public.delivery_zones_for_branch bridge and the core.delivery_zones table).
-- ---------------------------------------------------------------------------
select case when has_function_privilege('authenticated','core.delivery_zone_fee(uuid,uuid,numeric,numeric,numeric)','EXECUTE')
       then 'PASS' else 'FAIL: authenticated cannot execute core.delivery_zone_fee' end as t16;
select case when has_function_privilege('authenticated','core.geo_distance_km(numeric,numeric,numeric,numeric)','EXECUTE')
       then 'PASS' else 'FAIL: authenticated cannot execute core.geo_distance_km' end as t17;
select case when has_function_privilege('authenticated','core.zone_covers_point(uuid,numeric,numeric)','EXECUTE')
       then 'PASS' else 'FAIL: authenticated cannot execute core.zone_covers_point' end as t18;
select case when has_function_privilege('anon','core.delivery_zone_fee(uuid,uuid,numeric,numeric,numeric)','EXECUTE')
       then 'FAIL: anon can execute core.delivery_zone_fee' else 'PASS' end as t19;
select case when has_function_privilege('anon','core.zone_covers_point(uuid,numeric,numeric)','EXECUTE')
       then 'FAIL: anon can execute core.zone_covers_point' else 'PASS' end as t20;
select case when has_function_privilege('anon','marketing.validate_coupon(text,numeric,uuid)','EXECUTE')
       then 'FAIL: anon can execute marketing.validate_coupon' else 'PASS' end as t21;

-- ---------------------------------------------------------------------------
-- 5. Coupons and subscriptions: authenticated only.
--    036 section 3 and 074 grant the bridges to authenticated only.
-- ---------------------------------------------------------------------------
select case when has_function_privilege('authenticated','marketing.validate_coupon(text,numeric,uuid)','EXECUTE')
       then 'PASS' else 'FAIL: authenticated cannot execute marketing.validate_coupon' end as t22;
select case when has_function_privilege('authenticated','subscriptions.my_subscription()','EXECUTE')
       then 'PASS' else 'FAIL: authenticated cannot execute subscriptions.my_subscription' end as t23;
select case when has_function_privilege('authenticated','subscriptions.list_plans(uuid)','EXECUTE')
       then 'PASS' else 'FAIL: authenticated cannot execute subscriptions.list_plans' end as t24;
select case when has_function_privilege('authenticated','subscriptions.plan_products_list(uuid)','EXECUTE')
       then 'PASS' else 'FAIL: authenticated cannot execute subscriptions.plan_products_list' end as t25;
select case when has_function_privilege('authenticated','subscriptions.create_pending_subscription(uuid,text)','EXECUTE')
       then 'PASS' else 'FAIL: authenticated cannot execute subscriptions.create_pending_subscription' end as t26;
select case when has_function_privilege('authenticated','subscriptions.reserve_for_order(uuid,uuid,uuid,jsonb,text)','EXECUTE')
       then 'PASS' else 'FAIL: authenticated cannot execute subscriptions.reserve_for_order' end as t27;
select case when has_function_privilege('authenticated','subscriptions.set_auto_renew(uuid,boolean)','EXECUTE')
       then 'PASS' else 'FAIL: authenticated cannot execute subscriptions.set_auto_renew' end as t28;
select case when has_function_privilege('authenticated','subscriptions.cancel_subscription(uuid)','EXECUTE')
       then 'PASS' else 'FAIL: authenticated cannot execute subscriptions.cancel_subscription' end as t29;
select case when has_function_privilege('authenticated','subscriptions.activate_subscription(uuid,text)','EXECUTE')
       then 'PASS' else 'FAIL: authenticated cannot execute subscriptions.activate_subscription' end as t30;
select case when has_function_privilege('authenticated','subscriptions.usage_history(uuid)','EXECUTE')
       then 'PASS' else 'FAIL: authenticated cannot execute subscriptions.usage_history' end as t31;
select case when has_function_privilege('authenticated','subscriptions.generate_qr_token(uuid)','EXECUTE')
       then 'PASS' else 'FAIL: authenticated cannot execute subscriptions.generate_qr_token' end as t32;
select case when has_function_privilege('authenticated','subscriptions.consume_qr(text,uuid,uuid,integer,text)','EXECUTE')
       then 'PASS' else 'FAIL: authenticated cannot execute subscriptions.consume_qr' end as t33;
select case when has_function_privilege('anon','subscriptions.my_subscription()','EXECUTE')
       then 'FAIL: anon can execute subscriptions.my_subscription' else 'PASS' end as t34;

-- ---------------------------------------------------------------------------
-- 6. Trigger functions the calling role must hold. Triggers are SECURITY INVOKER
--    and PostgreSQL checks EXECUTE against the role performing the DML.
--    core.set_updated_at fires on customer-writable tables; the catalog.search
--    chain fires on staff catalogue writes.
--
--    REVISED 2026-10-28 by 205_admin_set_category_image.sql. Two earlier lines
--    here asserted that `authenticated` holds EXECUTE on
--    catalog.rebuild_product_search(uuid) and catalog.rebuild_category_search(uuid),
--    because that is what 083 restored to make the direct
--    `update public.categories set image_url = …` work. That premise is gone:
--    081 revoked those grants on purpose (every signed-in customer is
--    `authenticated`, and the functions are SECURITY DEFINER writes against the
--    search tables), the live ACL no longer carries them, and the category
--    picture write now runs inside admin_set_category_image, whose owner satisfies
--    the trigger. So the positive assertions stop at the trigger functions
--    `authenticated` genuinely calls, and the rebuild functions move to the
--    negative side — with the definer entry points checked as the replacement.
-- ---------------------------------------------------------------------------
select case when has_function_privilege('authenticated','core.set_updated_at()','EXECUTE')
       then 'PASS' else 'FAIL: authenticated cannot execute core.set_updated_at' end as t35;
select case when has_function_privilege('authenticated','core.normalize_ar(text)','EXECUTE')
       then 'PASS' else 'FAIL: authenticated cannot execute core.normalize_ar' end as t36;
select case when has_function_privilege('authenticated','catalog.sync_alias_normalized()','EXECUTE')
       then 'PASS' else 'FAIL: authenticated cannot execute catalog.sync_alias_normalized' end as t37;
select case when has_function_privilege('authenticated','catalog.trg_product_search()','EXECUTE')
       then 'PASS' else 'FAIL: authenticated cannot execute catalog.trg_product_search' end as t38;
select case when has_function_privilege('authenticated','catalog.trg_category_search()','EXECUTE')
       then 'PASS' else 'FAIL: authenticated cannot execute catalog.trg_category_search' end as t39;

-- t40: the rebuild functions stay private to the owner and service_role.
select case when not has_function_privilege('authenticated','catalog.rebuild_product_search(uuid)','EXECUTE')
             and not has_function_privilege('authenticated','catalog.rebuild_category_search(uuid)','EXECUTE')
             and has_function_privilege('postgres','catalog.rebuild_category_search(uuid)','EXECUTE')
       then 'PASS' else 'FAIL: the search rebuild functions are reachable by authenticated again' end as t40;

-- t41: the definer entry points that write catalogue rows in their place.
select case when has_function_privilege('authenticated','public.admin_set_category_image(uuid, text)','EXECUTE')
             and (select p.prosecdef from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                   where n.nspname = 'public' and p.proname = 'admin_set_category_image'
                     and p.pronargs = 2)
             and has_function_privilege('authenticated','public.admin_set_category_active(uuid, boolean)','EXECUTE')
             and has_function_privilege('authenticated','public.admin_set_branch_image(uuid, text)','EXECUTE')
       then 'PASS' else 'FAIL: the security-definer catalogue image/active writes are not reachable by authenticated' end as t41;

-- ---------------------------------------------------------------------------
-- 7. Signup and payment trigger paths.
--    GoTrue inserts into auth.users as supabase_auth_admin, which runs
--    identity.handle_new_user(). Without EXECUTE, every signup aborts.
-- ---------------------------------------------------------------------------
select case when has_function_privilege('supabase_auth_admin','identity.handle_new_user()','EXECUTE')
       then 'PASS' else 'FAIL: supabase_auth_admin cannot execute identity.handle_new_user' end as t42;
select case when has_function_privilege('service_role','payments.guard_payment_status()','EXECUTE')
       then 'PASS' else 'FAIL: service_role cannot execute payments.guard_payment_status' end as t43;
select case when has_function_privilege('authenticated','identity.provision_staff(uuid,text,text,text,uuid)','EXECUTE')
       then 'PASS' else 'FAIL: authenticated cannot execute identity.provision_staff' end as t44;

-- ---------------------------------------------------------------------------
-- 8. Nothing was granted to PUBLIC. A bare "=X/" entry in proacl is the
--    signature of a PUBLIC EXECUTE grant. No entry may begin with '='.
--    This is the specific defect 081 introduced and must never come back.
-- ---------------------------------------------------------------------------
select case when exists (
         select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
          where n.nspname in ('identity','core','catalog','orders','inventory',
                              'payments','loyalty','marketing','engagement','subscriptions')
            and exists (select 1 from unnest(coalesce(p.proacl, '{}')) acl
                         where acl::text like '=X/%')
       ) then 'FAIL: some function in the internal schemas still has PUBLIC EXECUTE'
       else 'PASS' end as t45;

-- ---------------------------------------------------------------------------
-- 9. Intentionally private internals must stay unreachable for anon AND
--    authenticated. Every remaining caller of these is SECURITY DEFINER, so they
--    execute as the owner and need no client grant. 081 section 2 was right about
--    these; harden_grants_test.sql t1-t5 already cover anon/authenticated for the
--    first two, this pins the rest.
-- ---------------------------------------------------------------------------
select case when has_function_privilege('authenticated','loyalty.apply_points(uuid,integer,text,text,uuid,text)','EXECUTE')
       then 'FAIL: authenticated can execute loyalty.apply_points' else 'PASS' end as t46;
select case when has_function_privilege('authenticated','identity.audit(text,text,uuid,jsonb,jsonb,uuid)','EXECUTE')
       then 'FAIL: authenticated can execute identity.audit' else 'PASS' end as t47;
select case when has_function_privilege('authenticated','orders.place_order_impl(uuid,text,text,uuid,text,text,uuid)','EXECUTE')
       then 'FAIL: authenticated can execute orders.place_order_impl' else 'PASS' end as t48;
select case when has_function_privilege('authenticated','subscriptions.finalize_order_consumption(uuid)','EXECUTE')
       then 'FAIL: authenticated can execute subscriptions.finalize_order_consumption' else 'PASS' end as t49;
select case when has_function_privilege('authenticated','subscriptions.release_order_consumption(uuid)','EXECUTE')
       then 'FAIL: authenticated can execute subscriptions.release_order_consumption' else 'PASS' end as t50;
select case when has_function_privilege('authenticated','subscriptions.handle_order_status_change()','EXECUTE')
       then 'FAIL: authenticated can execute subscriptions.handle_order_status_change' else 'PASS' end as t51;
select case when has_function_privilege('authenticated','engagement.notify_order_status()','EXECUTE')
       then 'FAIL: authenticated can execute engagement.notify_order_status' else 'PASS' end as t52;
select case when has_function_privilege('authenticated','engagement.notify_loyalty()','EXECUTE')
       then 'FAIL: authenticated can execute engagement.notify_loyalty' else 'PASS' end as t53;
select case when has_function_privilege('authenticated','inventory.validate_stock_variant()','EXECUTE')
       then 'FAIL: authenticated can execute inventory.validate_stock_variant' else 'PASS' end as t54;
select case when has_function_privilege('authenticated','inventory.validate_movement_variant()','EXECUTE')
       then 'FAIL: authenticated can execute inventory.validate_movement_variant' else 'PASS' end as t55;
select case when has_function_privilege('authenticated','core.geo_point_in_polygon(numeric,numeric,jsonb)','EXECUTE')
       then 'FAIL: authenticated can execute core.geo_point_in_polygon' else 'PASS' end as t56;
select case when has_function_privilege('authenticated','inventory.adjust_stock(uuid,uuid,integer,text,text,uuid)','EXECUTE')
       then 'FAIL: authenticated can execute inventory.adjust_stock' else 'PASS' end as t57;
select case when has_function_privilege('anon','identity.provision_staff(uuid,text,text,text,uuid)','EXECUTE')
       then 'FAIL: anon can execute identity.provision_staff' else 'PASS' end as t58;

-- ---------------------------------------------------------------------------
-- 10. RLS must still be enabled everywhere. The repair is grants-only; this
--     guards against a future "fix" that reaches for RLS instead.
-- ---------------------------------------------------------------------------
select case when exists (
         select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
          where c.relkind in ('r','p')
            and n.nspname in ('identity','core','catalog','orders','inventory',
                              'payments','loyalty','marketing','engagement','subscriptions')
            and not c.relrowsecurity
       ) then 'FAIL: a business table has RLS disabled'
       else 'PASS' end as t59;

-- ---------------------------------------------------------------------------
-- 11. Staff data must stay out of reach of a plain customer. spec 9.4 requires
--     this. Note the protection is a table-level REVOKE from 023_grants_01.sql,
--     not an RLS policy, so the check belongs here rather than in a policy test.
--     runtime_grants_behavior_test.js asserts the end-to-end result with a real
--     non-staff user.
-- ---------------------------------------------------------------------------
select case when has_table_privilege('authenticated','identity.staff_members','SELECT')
       then 'FAIL: authenticated can select identity.staff_members' else 'PASS' end as t60;
select case when has_table_privilege('authenticated','identity.staff_roles','SELECT')
       then 'FAIL: authenticated can select identity.staff_roles' else 'PASS' end as t61b;
select case when has_table_privilege('anon','identity.staff_members','SELECT')
       then 'FAIL: anon can select identity.staff_members' else 'PASS' end as t61;
select case when has_table_privilege('anon','identity.audit_log','SELECT')
       then 'FAIL: anon can select identity.audit_log' else 'PASS' end as t62;
select case when has_table_privilege('anon','inventory.branch_stock','SELECT')
       then 'FAIL: anon can select inventory.branch_stock' else 'PASS' end as t63;
select case when has_table_privilege('authenticated','inventory.branch_stock','SELECT')
       then 'FAIL: authenticated can select inventory.branch_stock' else 'PASS' end as t63b;
select case when has_table_privilege('authenticated','inventory.stock_movements','SELECT')
       then 'FAIL: authenticated can select inventory.stock_movements' else 'PASS' end as t63c;