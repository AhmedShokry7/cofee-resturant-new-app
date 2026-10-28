-- 186_admin_orders_payments_branch_scope.sql
--
-- SECURITY-ONLY MIGRATION: branch isolation for the two admin directories.
--
-- STATUS — VERIFIED AGAINST THE LIVE PROJECT ON 2026-10-27
--   Both functions below are ALREADY the deployed state of
--   webzzasosevzymftgszn (cofee-resturant-new-app). After stripping comments
--   and whitespace, the body of section 1 is byte-identical to
--   pg_get_functiondef('public.admin_orders()'::regprocedure)
--   (md5 f8d0fb5b017b1c691ab13d639dc78ccb), and section 2 is byte-identical to
--   the deployed admin_payments() (md5 ac39c2bbfc4f470d3cff51281dc9a1cc).
--   Applying this file to that database therefore changes nothing but the two
--   pg_description rows: neither deployed function carries a comment, so the
--   'comment on function' statements below would be its first.
--   The file still has to stay in supabase/migrations/, because the chain as
--   committed is NOT scoped: 176:880 and 178:478 have no branch predicate, so a
--   database rebuilt from the files would reopen the leak. This file is what
--   makes the files agree with the deployed state.
--   Who applied the live definitions cannot be determined from the repository:
--   supabase_migrations.schema_migrations has no version for them, its newest
--   numeric row is 160, the two timestamp rows that follow
--   (20261025121013_security_hardening_functions_and_rls,
--   20261025121027_performance_rls_initplan_and_fk_indexes) contain RLS,
--   GRANT and search_path hygiene only, and no local migration carries the two
--   comments quoted below. They were applied out of band.
--
-- THE DEFECT THIS FILE CLOSES IN THE CHAIN
--   public.admin_orders()  — latest local body is 176_admin_pos_customers.sql:880
--   public.admin_payments() — latest body is 178_admin_pos_split_payments.sql:478
--   Both are SECURITY DEFINER, so the RLS policies of 021 do not apply to them.
--   Their only gate is identity.is_staff() plus one read permission, so every
--   staff member with orders.read / payments.read receives every branch's rows:
--   admin_orders returns the customer name, e-mail, phone and line items of all
--   branches, and admin_payments returns card_brand, card_last4,
--   card_holder_name and provider_reference of all branches.
--   183_admin_nav_counts.sql:36/43 and 185_admin_unread_work.sql:206/214 already
--   answer for the managed branches only, which is why the sidebar counter and
--   the list disagree if the directories do not.
--
-- WHAT THIS FILE CHANGES — and nothing else
--   admin_orders():    + where identity.can_manage_branch(o.branch_id)
--   admin_payments():  + where identity.can_manage_branch(o.branch_id)
--   The bodies are 176:880 and 178:478 copied verbatim otherwise: same guards,
--   same jsonb_build_object keys in the same order, same types, same
--   'order by o.placed_at desc' / 'order by t.created_at desc', same joins, same
--   REVOKE/GRANT lines. No RLS change, no role or permission data change, no new
--   grant, no wider access anywhere. Live ACLs were already
--   postgres=X | authenticated=X | service_role=X on both, with no anon grant.
--
-- WHY THE PAYMENTS PREDICATE IS THE STRICT ONE
--   075_subscriptions_order_payment_hardening.sql:10-11 dropped the NOT NULL on
--   payment_transactions.order_id and added payment_transactions_one_target
--   (075:21-22), so a subscription payment has no order at all, and
--   subscriptions.subscriptions (074:56-79) has no branch column. A branch-scoped
--   staff member therefore cannot see those tenders: can_manage_branch(null) is
--   false for them and true for a global one, so card data of no branch stays
--   with the people who own every branch. That is the direction the deployed
--   function takes, and the owner chose to keep it on 2026-10-27.
--   The alternative predicate ("where t.order_id is null or ..."), which keeps
--   subscription tenders on every staff member's payments page, is deferred as
--   decision D in supabase/proposals/README.md — it is a widening, not a fix,
--   and must not be slipped in here. It changes no row today: the live database
--   has 3 tenders, none with a null order, and 0 subscriptions.
--
-- VERIFIED IN THE SAME PASS (supabase/tests/branch_scope_preflight.sql)
--   identity.can_manage_branch(p_branch_id) is deployed as the 123 version —
--   staff_members.status = 'active' and (sr.branch_id is null
--   or sr.branch_id = p_branch_id) — with no owner short-circuit, unlike
--   identity.has_permission (123:69; 137_reference_data.sql:52-53 seeds 'owner'
--   with no permission rows). identity.staff_roles today holds exactly one row:
--   role 'owner' with branch_id NULL, so the global admin is not locked out.
--   Re-run the pre-flight before trusting that on any other database: an owner
--   or manager whose role row carries a concrete branch_id would lose the other
--   branches, and the fix for that is RBAC data, which this file does not touch.
--   supabase/tests/admin_orders_branch_scope_test.sql asserts the shape, the
--   sorting and the branch isolation of both functions.
--
-- NOT IN THIS FILE, ON PURPOSE
--   admin_update_order_status delegation, item-add/remove branch guards,
--   effective-price item pricing and the totals recompute live in
--   supabase/proposals/186_admin_orders_branch_scope_and_totals.PROPOSED.sql.
--   They change the order lifecycle, pricing and invoice totals, so each needs
--   its own decision — see supabase/proposals/README.md.
--
-- ROLLBACK: re-running 176 then 178 restores both bodies unscoped; they are
-- idempotent create-or-replace definitions. Do not use it as an escape hatch
-- from a lockout — the lockout cause is staff_roles data, see above.

-- ---------------------------------------------------------------------------
-- 1. Orders directory: only the branches this staff member manages
--    Body is 176:880 verbatim, plus the where clause at the end of the source.
-- ---------------------------------------------------------------------------
create or replace function public.admin_orders()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('orders.read') then
    raise exception 'missing permission: orders.read' using errcode = '42501';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', o.id,
      'order_number', o.order_number,
      'user_id', o.user_id,
      'pos_customer_id', o.pos_customer_id,
      'customer_name', coalesce(p.full_name, pc.full_name),
      'customer_email', coalesce(p.email, pc.email),
      'customer_phone', coalesce(p.phone, pc.phone),
      'customer_avatar_url', p.avatar_url,
      'branch_id', o.branch_id,
      'branch_name_ar', b.name_ar,
      'branch_name_en', b.name_en,
      'branch_latitude', b.latitude,
      'branch_longitude', b.longitude,
      'fulfillment_type', o.fulfillment_type,
      'order_source', o.order_source,
      'table_number', o.table_number,
      'status', o.status,
      'payment_method_id', o.payment_method_id,
      'payment_status', o.payment_status,
      'subtotal', o.subtotal,
      'discount_total', o.discount_total,
      'product_discount_total', o.product_discount_total,
      'delivery_fee', o.delivery_fee,
      'tax_total', o.tax_total,
      'grand_total', o.grand_total,
      'currency_code', o.currency_code,
      'customer_note', o.customer_note,
      'placed_at', o.placed_at,
      'completed_at', o.completed_at,
      'delivery_address_snapshot', o.delivery_address_snapshot,
      'items', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', oi.id,
          'product_id', oi.product_id,
          'product_name_ar', oi.product_name_ar,
          'product_name_en', oi.product_name_en,
          'image_url', oi.image_snapshot,
          'option_group_name_ar', oi.option_group_name_ar,
          'option_group_name_en', oi.option_group_name_en,
          'quantity', oi.quantity,
          'unit_price', oi.unit_price,
          'line_total', oi.line_total,
          'note', oi.note
        ) order by oi.id)
        from orders.order_items oi
        where oi.order_id = o.id
      ), '[]'::jsonb)
    ) order by o.placed_at desc)
    from orders.orders o
    left join identity.profiles p on p.id = o.user_id
    left join orders.pos_customers pc on pc.id = o.pos_customer_id
    left join core.branches b on b.id = o.branch_id
    -- 183 and 185 already answer only for the branches the caller manages; the
    -- directory has to agree with its own counter, otherwise the badge says 3
    -- and the list shows 40.
    where identity.can_manage_branch(o.branch_id)
  ), '[]'::jsonb);
end;
$fn$;

comment on function public.admin_orders() is
  'The orders of the branches this staff member manages, with customer, source, '
  'table and line snapshots.';

revoke all on function public.admin_orders() from public, anon;
grant execute on function public.admin_orders() to authenticated;

-- ---------------------------------------------------------------------------
-- 2. Payments directory: scoped through the order, tenders of no branch left
--    to global staff.  Body is 178:478 verbatim, plus the where clause.
-- ---------------------------------------------------------------------------
create or replace function public.admin_payments()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('payments.read') then
    raise exception 'missing permission: payments.read' using errcode = '42501';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', t.id,
      'order_id', t.order_id,
      'order_number', o.order_number,
      'customer_name', p.full_name,
      'provider', t.provider,
      'provider_reference', t.provider_reference,
      'method_id', t.method_id,
      'method_code', m.code,
      'method_name_ar', m.name_ar,
      'method_name_en', m.name_en,
      'amount', t.amount,
      'currency_code', t.currency_code,
      'status', t.status,
      'paid_at', t.paid_at,
      'refunded_at', t.refunded_at,
      'card_brand', t.card_brand,
      'card_last4', t.card_last4,
      'card_holder_name', t.card_holder_name,
      'verified_by_server', t.verified_by_server,
      'created_at', t.created_at
    ) order by t.created_at desc)
    from payments.payment_transactions t
    left join orders.orders o on o.id = t.order_id
    left join identity.profiles p on p.id = o.user_id
    left join payments.payment_methods m on m.id = t.method_id
    -- can_manage_branch(null) is false for a branch-scoped staff member and true
    -- for a global one, so a tender with no order stays invisible to a branch
    -- cashier. That is the safe direction for card data.
    where identity.can_manage_branch(o.branch_id)
  ), '[]'::jsonb);
end;
$fn$;

comment on function public.admin_payments() is
  'The payments of the branches this staff member manages. A subscription tender '
  'has no branch, so only staff who manage every branch see it.';

revoke all on function public.admin_payments() from public, anon;
grant execute on function public.admin_payments() to authenticated;

notify pgrst, 'reload schema';
