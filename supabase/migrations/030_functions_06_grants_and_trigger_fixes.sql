-- 030_functions_06_grants_and_trigger_fixes.sql
--
-- Three defects found by running the acceptance suite as a real
-- `authenticated` session.
--
-- BUG A -- the admin panel could not write anything.
--   Migration 023 granted only SELECT on catalogue tables to `authenticated`.
--   The RLS policies for those tables are permission-gated and were correct,
--   but no DML privilege ever reached the role, so a permitted staff member got
--     42501 permission denied for table option_groups
--   even though has_permission('catalog.product.write') was true.
--
--   Fix: grant the primitive DML privileges and let RLS do the gating, which is
--   the intended least-privilege model. anon stays read-only.
--
-- BUG B -- notifications could not be inserted at all.
--   uq_notifications_dedupe is a PARTIAL unique index:
--     unique (user_id, dedupe_key) where dedupe_key is not null
--   but both notification triggers wrote
--     on conflict (user_id, dedupe_key) do nothing
--   without restating the predicate. Postgres cannot infer a partial unique
--   index for ON CONFLICT unless the WHERE clause is repeated, so every
--   order-status or loyalty notification raised
--     42P10 there is no unique or exclusion constraint matching the
--            ON CONFLICT specification
--   which aborted orders.place_order() at the loyalty step.
--
--   Fix: restate the predicate in both triggers.

-- ---------------------------------------------------------------------------
-- BUG A: DML for the authenticated role. RLS still decides every row.
-- ---------------------------------------------------------------------------
grant insert, update, delete on
  core.brands, core.branches, core.delivery_zones, core.delivery_zone_branches,
  core.app_settings, core.legal_documents, core.faq_items, core.onboarding_slides,
  catalog.categories, catalog.products, catalog.product_images,
  catalog.option_groups, catalog.option_values, catalog.product_option_groups,
  catalog.product_aliases, catalog.category_aliases,
  catalog.bundles, catalog.bundle_items, catalog.branch_product_pricing,
  marketing.banners, marketing.coupons, marketing.coupons_categories,
  loyalty.loyalty_rules, loyalty.loyalty_rewards,
  payments.payment_methods, orders.status_transitions
  to authenticated;

grant update on identity.staff_members to authenticated;

-- anon keeps read-only access to the public catalogue.
grant select on
  catalog.product_search, catalog.category_search
  to anon;

-- ---------------------------------------------------------------------------
-- BUG B: ON CONFLICT must restate the partial-index predicate.
-- ---------------------------------------------------------------------------
create or replace function engagement.notify_order_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_user uuid;
  v_dedupe text;
begin
  if tg_op = 'UPDATE' and new.status is not distinct from old.status then
    return new;
  end if;

  select user_id into v_user from orders.orders where id = new.id;

  v_dedupe := 'order:' || new.id::text || ':' || new.status;

  insert into engagement.notifications
    (user_id, type, title_ar, title_en, body_ar, body_en,
     payload, related_entity_type, related_entity_id, dedupe_key)
  values (
    v_user,
    'order_status',
    'تحديث حالة الطلب ' || new.order_number,
    'Order ' || new.order_number || ' updated',
    'حالة طلبك الآن: ' || new.status,
    'Your order status is now: ' || new.status,
    jsonb_build_object('order_id', new.id, 'order_number', new.order_number,
                       'status', new.status, 'total', new.grand_total,
                       'branch_id', new.branch_id),
    'order',
    new.id,
    v_dedupe
  )
  on conflict (user_id, dedupe_key) where dedupe_key is not null do nothing;

  return new;
end;
$fn$;

create or replace function engagement.notify_loyalty()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_dedupe text;
begin
  v_dedupe := 'loyalty:' || new.user_id::text || ':' || new.id::text;

  insert into engagement.notifications
    (user_id, type, title_ar, title_en, body_ar, body_en,
     payload, related_entity_type, related_entity_id, dedupe_key)
  values (
    new.user_id,
    'loyalty',
    case when new.points > 0 then 'ربحت نقاط' else 'استخدمت نقاط' end,
    case when new.points > 0 then 'Points earned' else 'Points redeemed' end,
    case when new.points > 0
      then 'ربحت ' || new.points || ' نقطة. رصيدك ' || new.balance_after
      else 'استخدمت ' || abs(new.points) || ' نقطة. رصيدك ' || new.balance_after end,
    case when new.points > 0
      then 'You earned ' || new.points || ' points. Balance: ' || new.balance_after
      else 'You used ' || abs(new.points) || ' points. Balance: ' || new.balance_after end,
    jsonb_build_object('points', new.points, 'balance_after', new.balance_after, 'reason', new.reason),
    'loyalty', new.id, v_dedupe
  )
  on conflict (user_id, dedupe_key) where dedupe_key is not null do nothing;

  return new;
end;
$fn$;

-- ---------------------------------------------------------------------------
-- Regression guard: ON CONFLICT inference against a partial unique index is a
-- runtime-only failure, so nothing at DDL time catches it. This view makes the
-- two notification triggers easy to re-check after any change.
-- ---------------------------------------------------------------------------
create or replace view _ops.partial_unique_indexes as
  select n.nspname || '.' || c.relname as table_name,
         i.relname as index_name,
         pg_get_expr(x.indexprs, x.indrelid) as predicate
    from pg_index x
    join pg_class c on c.oid = x.indrelid
    join pg_class i on i.oid = x.indexrelid
    join pg_namespace n on n.oid = c.relnamespace
   where x.indpred is not null
     and n.nspname in ('identity','core','catalog','orders','inventory',
                       'payments','loyalty','marketing','engagement')
   order by 1, 2;

revoke all on _ops.partial_unique_indexes from anon, authenticated;