-- 018_rls_00_helpers.sql
--
-- Authorization helpers, then RLS switched on everywhere.
--
-- These helpers are SECURITY DEFINER on purpose. A policy that queries an
-- RLS-protected table would recurse infinitely; SECURITY DEFINER makes the
-- helper read as its owner (postgres), so the policy can call it safely.
-- Every one pins search_path = '' and qualifies every name.

-- ---------------------------------------------------------------------------
-- Is the caller an active back-office user?
-- ---------------------------------------------------------------------------
create or replace function identity.is_staff()
returns boolean
language sql
stable
security definer
set search_path = ''
as $fn$
  select exists (
    select 1 from identity.staff_members
    where user_id = auth.uid() and status = 'active'
  );
$fn$;

comment on function identity.is_staff() is
  'True when auth.uid() has an active staff_members row. Suspended staff return false.';

-- ---------------------------------------------------------------------------
-- Does the caller hold a permission code?
-- The owner role is privileged by convention and short-circuits to true.
-- ---------------------------------------------------------------------------
create or replace function identity.has_permission(p_code text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $fn$
  select exists (
    select 1
    from identity.staff_members sm
    join identity.staff_roles  sr on sr.staff_id = sm.id
    join identity.roles        r  on r.id = sr.role_id
    where sm.user_id = auth.uid()
      and sm.status = 'active'
      and (
        r.code = 'owner'
        or exists (
          select 1
          from identity.role_permissions rp
          join identity.permissions p on p.id = rp.permission_id
          where rp.role_id = r.id and p.code = p_code
        )
      )
  );
$fn$;

comment on function identity.has_permission(text) is
  'Permission check used by RLS policies. Owner role implicitly holds every permission.';

-- ---------------------------------------------------------------------------
-- Branch scope (D1). A staff row with branch_id NULL means "all branches".
-- ---------------------------------------------------------------------------
create or replace function identity.manages_all_branches()
returns boolean
language sql
stable
security definer
set search_path = ''
as $fn$
  select exists (
    select 1
    from identity.staff_members sm
    join identity.staff_roles  sr on sr.staff_id = sm.id
    where sm.user_id = auth.uid()
      and sm.status = 'active'
      and sr.branch_id is null
  );
$fn$;

create or replace function identity.can_manage_branch(p_branch_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $fn$
  select exists (
    select 1
    from identity.staff_members sm
    join identity.staff_roles  sr on sr.staff_id = sm.id
    where sm.user_id = auth.uid()
      and sm.status = 'active'
      and (sr.branch_id is null or sr.branch_id = p_branch_id)
  );
$fn$;

comment on function identity.can_manage_branch(uuid) is
  'True when the caller may manage this specific branch (D1 branch scoping).';

-- ---------------------------------------------------------------------------
-- Enable RLS on every table. No exceptions.
-- ---------------------------------------------------------------------------
do $$
declare
  t text;
begin
  foreach t in array array[
    'identity.profiles','identity.customer_addresses','identity.staff_members',
    'identity.roles','identity.permissions','identity.role_permissions',
    'identity.staff_roles','identity.audit_log',
    'core.brands','core.branches','core.delivery_zones','core.delivery_zone_branches',
    'core.app_settings','core.legal_documents','core.faq_items','core.onboarding_slides',
    'catalog.categories','catalog.products','catalog.product_images',
    'catalog.option_groups','catalog.option_values','catalog.product_option_groups',
    'catalog.product_aliases','catalog.category_aliases',
    'catalog.product_search','catalog.category_search',
    'catalog.bundles','catalog.bundle_items','catalog.branch_product_pricing',
    'orders.carts','orders.cart_items','orders.cart_item_options','orders.orders',
    'orders.order_items','orders.order_item_options','orders.order_status_history',
    'orders.order_events','orders.status_transitions',
    'inventory.branch_stock','inventory.stock_movements',
    'payments.payment_methods','payments.payment_attempts','payments.payment_transactions',
    'loyalty.loyalty_rules','loyalty.loyalty_accounts','loyalty.loyalty_transactions',
    'loyalty.loyalty_rewards',
    'marketing.banners','marketing.coupons','marketing.coupons_categories',
    'marketing.coupon_redemptions',
    'engagement.product_reviews','engagement.notifications',
    'engagement.notification_preferences','engagement.device_tokens',
    'ai.product_knowledge','ai.knowledge_articles'
  ] loop
    execute format('alter table %s enable row level security', t);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- No table grants yet. Revoke everything from anon/authenticated first so
-- nothing is reachable until 023_grants re-grants deliberately.
-- ai.* is never granted to any client role (spec section 4).
-- ---------------------------------------------------------------------------
do $$
declare
  t text;
begin
  foreach t in array array[
    'identity.profiles','identity.customer_addresses','identity.staff_members',
    'identity.roles','identity.permissions','identity.role_permissions',
    'identity.staff_roles','identity.audit_log',
    'core.brands','core.branches','core.delivery_zones','core.delivery_zone_branches',
    'core.app_settings','core.legal_documents','core.faq_items','core.onboarding_slides',
    'catalog.categories','catalog.products','catalog.product_images',
    'catalog.option_groups','catalog.option_values','catalog.product_option_groups',
    'catalog.product_aliases','catalog.category_aliases',
    'catalog.product_search','catalog.category_search',
    'catalog.bundles','catalog.bundle_items','catalog.branch_product_pricing',
    'orders.carts','orders.cart_items','orders.cart_item_options','orders.orders',
    'orders.order_items','orders.order_item_options','orders.order_status_history',
    'orders.order_events','orders.status_transitions',
    'inventory.branch_stock','inventory.stock_movements',
    'payments.payment_methods','payments.payment_attempts','payments.payment_transactions',
    'loyalty.loyalty_rules','loyalty.loyalty_accounts','loyalty.loyalty_transactions',
    'loyalty.loyalty_rewards',
    'marketing.banners','marketing.coupons','marketing.coupons_categories',
    'marketing.coupon_redemptions',
    'engagement.product_reviews','engagement.notifications',
    'engagement.notification_preferences','engagement.device_tokens'
  ] loop
    execute format('revoke all on table %s from anon, authenticated', t);
    execute format('grant select on table %s to service_role', t);
  end loop;
end $$;

-- ai is intentionally absent from the grant loop above.
revoke all on schema ai from anon, authenticated;
revoke all on all tables in schema ai from anon, authenticated;
grant all on all tables in schema ai to service_role;