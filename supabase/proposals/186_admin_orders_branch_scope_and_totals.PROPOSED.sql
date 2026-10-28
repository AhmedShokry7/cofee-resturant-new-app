-- 186_admin_orders_branch_scope_and_totals.sql
--
-- PROPOSED BY THE ORDERS FEATURE AUDIT — NOT APPLIED ANYWHERE.
--
-- MOVED ON 2026-10-27 OUT OF supabase/migrations/ ON PURPOSE. This file is a
-- review draft, not a link in the migration chain: the owner approved only the
-- branch-isolation part, split into
-- supabase/migrations/186_admin_orders_payments_branch_scope.sql, and the rest
-- stays here until each of its own decisions is taken. See
-- supabase/proposals/README.md for the impact analysis and the tests each part
-- still needs.
--   * Sections 1 and 2 below are SUPERSEDED by that file and must not be
--     applied from here. They differ in one place: section 2 hides subscription
--     tenders from branch-scoped staff, which the approved scope keeps visible.
--   * Sections 3 and 4 are the still-undrafted decisions — status delegation,
--     item pricing, invoice totals. Their SQL is kept here complete so nothing
--     written during the audit is lost.
--
-- Nothing in this file has been run against the project database. It is here so
-- the owner can read the exact SQL, decide, and apply it by hand. 161-185 are
-- still pending too, so this file only becomes part of the chain once those are
-- applied in order and this one is reviewed.
--
-- Four defects, each with the migration that introduced the body being replaced:
--
-- 1. public.admin_orders() (144, last rewritten by 176) and public.admin_payments()
--    (147, last rewritten by 178) are SECURITY DEFINER reads gated only by
--    orders.read / payments.read. They have no branch predicate, so a cashier
--    scoped to one branch receives every branch's orders, names, phones,
--    emails, card last4 and holder names. Every other admin read in the schema
--    already scopes itself: 183 and 185 filter with identity.can_manage_branch,
--    and the RLS policies of 021 do the same. These two RPCs are the outliers.
--
-- 2. public.admin_update_order_status() (145) writes orders.orders.status
--    directly. It ignores orders.status_transitions, writes no
--    orders.order_status_history row, no identity.audit row, no
--    completed_at/cancelled_at side effects, no restock and no loyalty clawback,
--    and it accepts 'cancelled' — the exact thing 079 exists to prevent. It also
--    updates by id alone, so a wrong id is a silent no-op.
--
-- 3. public.admin_add_order_item() / public.admin_remove_order_item() (146,
--    guarded by 154) recompute subtotal AND grand_total as sum(line_total).
--    ck_orders_total (011:113) requires
--    grand_total = round(subtotal - discount_total + delivery_fee + tax_total, 2),
--    so any order with a delivery fee or a coupon makes the item edit fail with
--    a constraint violation, and the admin screen reports a generic error.
--    admin_add_order_item also prices the new line from catalog.products.base_price
--    instead of catalog.resolve_effective_price, so a branch or product discount
--    is silently ignored on a line the customer never agreed to.
--
-- 4. Neither item RPC checks the branch of the order it writes, so orders.status.update
--    in one branch edits invoices in another.
--
-- TWO BEHAVIOUR CHANGES THE OWNER MUST EXPLICITLY ACCEPT:
--   * Fix 2 makes the seeded status_transitions matrix authoritative. A status
--     the admin menu offers but the matrix forbids (ready -> pending,
--     completed -> preparing, ...) will now be refused instead of written.
--   * Fix 2 routes 'cancelled' through orders.cancel_order, which demands
--     orders.cancel (137:93 — the cashier role has orders.status.update but NOT
--     orders.cancel). After this file, a cashier cannot cancel from the orders
--     page; grant cashier 'orders.cancel' or keep cancellation manager-only.
--   * Fix 3 makes the totals land where ck_orders_total expects them. It does
--     not re-validate the coupon and does not touch delivery_fee, so an added
--     line can push a delivery order over a zone minimum it was priced under;
--     the stored fee simply stays as it was. Repricing the zone is a separate
--     decision.
--
-- DELIBERATELY NOT HERE: admin_add_order_item still does not deduct inventory and
-- admin_remove_order_item still does not restore it. That is an inventory-rule
-- change, not an integrity fix, and it needs its own decision. 107:110-143 has
-- the restock pattern to copy if the owner wants it.
--
-- REVIEW CHECKLIST
--   select count(*) from orders.orders o
--    where not identity.can_manage_branch(o.branch_id);   -- as a branch cashier:
--                                                         -- must become 0
--   select from_status, to_status, is_allowed
--     from orders.status_transitions order by from_status, to_status;
--                                                         -- the matrix the UI must match
--   After applying: an order with delivery_fee > 0 accepts a new line and keeps
--   round(subtotal - discount_total + delivery_fee + tax_total, 2) = grand_total.

-- ---------------------------------------------------------------------------
-- 1. Orders directory: only the branches this staff member manages
--    Body is 176:880 verbatim plus the branch predicate.
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
  'The orders this staff member''s branches hold, with customer, source, table '
  'and line snapshots.';

revoke all on function public.admin_orders() from public, anon;
grant execute on function public.admin_orders() to authenticated;

-- ---------------------------------------------------------------------------
-- 2. Payments directory: same predicate
--    Body is 178:478 verbatim plus the branch predicate.
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
  'The payments of the branches this staff member manages, with their order, '
  'customer and tender method.';

revoke all on function public.admin_payments() from public, anon;
grant execute on function public.admin_payments() to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Status writes: delegate, do not re-implement
--    orders.update_order_status (079) and orders.cancel_order (107) already do
--    the branch check, the matrix check, the history row and the audit row, and
--    cancel_order does the restock and the loyalty clawback. 145 duplicated the
--    write and dropped all of it.
--    Both delegates are SECURITY DEFINER and read auth.uid() from the JWT, which
--    a nested call does not change, so the staff member stays the actor.
-- ---------------------------------------------------------------------------
create or replace function public.admin_update_order_status(
  p_order_id uuid,
  p_status text
)
returns void
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('orders.status.update') then
    raise exception 'missing permission: orders.status.update' using errcode = '42501';
  end if;
  if p_status not in ('pending','confirmed','preparing','ready','out_for_delivery','completed','cancelled') then
    raise exception 'invalid status' using errcode = '22023';
  end if;

  if p_status = 'cancelled' then
    -- Needs orders.cancel as well; see the header.
    perform orders.cancel_order(
      p_order_id,
      'cancelled from the admin orders page'
    );
  else
    perform orders.update_order_status(p_order_id, p_status, null);
  end if;
end;
$fn$;

comment on function public.admin_update_order_status(uuid, text) is
  'Admin entry point for a status change. Performs the transition that '
  'orders.update_order_status / orders.cancel_order allow, so branch scope, the '
  'status_transitions matrix, the history row and the audit row are never '
  'skipped.';

revoke all on function public.admin_update_order_status(uuid, text) from public, anon;
grant execute on function public.admin_update_order_status(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 4. Item edits: branch-scoped, priced by the database, totals that satisfy
--    ck_orders_total.
-- ---------------------------------------------------------------------------
create or replace function public.admin_add_order_item(
  p_order_id uuid,
  p_product_id uuid,
  p_quantity int
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_item_id    uuid;
  v_order      orders.orders%rowtype;
  v_product    catalog.products%rowtype;
  v_unit_price numeric;
  v_regular    numeric;
  v_available  boolean;
  v_line_total numeric;
  v_discount   numeric;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('orders.status.update') then
    raise exception 'missing permission: orders.status.update' using errcode = '42501';
  end if;
  if p_quantity is null or p_quantity < 1 then
    raise exception 'invalid quantity' using errcode = '22023';
  end if;

  select * into v_order from orders.orders where id = p_order_id for update;
  if not found then
    raise exception 'order % not found', p_order_id using errcode = 'P0002';
  end if;
  if not identity.can_manage_branch(v_order.branch_id) then
    raise exception 'you do not manage this branch' using errcode = '42501';
  end if;
  if v_order.status in ('completed', 'cancelled') then
    raise exception 'order is not editable' using errcode = '22023';
  end if;
  if v_order.payment_status = 'refunded' then
    raise exception 'refunded order is not editable' using errcode = '22023';
  end if;

  select * into v_product from catalog.products where id = p_product_id;
  if not found then
    raise exception 'product not found' using errcode = '22023';
  end if;

  -- The price truth of 175:219 — branch price, product discount, no options.
  -- base_price was the list price the customer was never charged.
  select ep.unit_price, ep.regular_price, ep.is_available
    into v_unit_price, v_regular, v_available
    from catalog.resolve_effective_price(v_order.branch_id, p_product_id) ep;
  if not v_available then
    raise exception 'product is not available in this branch' using errcode = '22023';
  end if;
  v_unit_price := round(v_unit_price, 2);
  v_line_total := round(v_unit_price * p_quantity, 2);
  -- ck_order_items_total pins line_total to unit_price * quantity, so the
  -- product discount is recorded next to the line, never inside it (134).
  v_discount := greatest(round((coalesce(v_regular, v_unit_price) - v_unit_price)
                               * p_quantity, 2), 0);

  insert into orders.order_items (
    order_id, product_id, product_name_ar, product_name_en, sku_snapshot,
    image_snapshot, unit_price, quantity, line_total, discount_total,
    product_discount_total, options_key, note
  )
  values (
    p_order_id, p_product_id, v_product.name_ar, v_product.name_en, v_product.sku,
    v_product.image_url, v_unit_price, p_quantity, v_line_total, 0,
    v_discount, '', ''
  )
  returning id into v_item_id;

  perform public.admin_recompute_order_totals(p_order_id);

  insert into orders.order_events (order_id, event_type, payload)
  values (
    p_order_id, 'order_status',
    jsonb_build_object('action', 'add_item', 'item_id', v_item_id,
                       'product_id', p_product_id, 'quantity', p_quantity,
                       'unit_price', v_unit_price)
  );

  perform identity.audit(
    'order.item.add', 'order', p_order_id, '{}'::jsonb,
    jsonb_build_object('product_id', p_product_id, 'quantity', p_quantity),
    v_order.branch_id
  );

  return v_item_id;
end;
$fn$;

comment on function public.admin_add_order_item(uuid, uuid, int) is
  'Append one line to an editable order of a managed branch, priced by the '
  'catalogue, then recompute the invoice totals.';

-- One place owns the recompute, so add and remove can no longer drift apart.
create or replace function public.admin_recompute_order_totals(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_subtotal numeric;
  v_discount numeric;
  v_tax_rate numeric := 0;
  v_tax_inc  boolean := true;
  v_tax      numeric;
begin
  select coalesce(round(sum(oi.line_total), 2), 0)
    into v_subtotal
    from orders.order_items oi
   where oi.order_id = p_order_id;

  -- The invoice keeps the coupon the customer used, capped at the new subtotal
  -- so ck_orders_discount_capped still holds.
  select least(coalesce(o.discount_total, 0), v_subtotal)
    into v_discount
    from orders.orders o
   where o.id = p_order_id;

  select b.tax_rate, b.tax_included
    into v_tax_rate, v_tax_inc
    from core.brands b
   limit 1;

  if v_tax_inc then
    v_tax := 0;
  else
    v_tax := round((v_subtotal - v_discount) * coalesce(v_tax_rate, 0) / 100, 2);
  end if;

  update orders.orders o
     set subtotal = v_subtotal,
         discount_total = v_discount,
         tax_total = v_tax,
         grand_total = round(
           v_subtotal - v_discount + o.delivery_fee + v_tax, 2),
         product_discount_total = coalesce((
           select round(sum(oi.product_discount_total), 2)
             from orders.order_items oi
            where oi.order_id = p_order_id
         ), 0),
         updated_at = now()
   where o.id = p_order_id;
end;
$fn$;

comment on function public.admin_recompute_order_totals(uuid) is
  'Rebuild subtotal, coupon discount, tax and grand_total of one order so that '
  'ck_orders_total and ck_orders_discount_capped keep holding. The delivery fee '
  'is left as the zone priced it.';

create or replace function public.admin_remove_order_item(
  p_order_item_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_order    orders.orders%rowtype;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('orders.status.update') then
    raise exception 'missing permission: orders.status.update' using errcode = '42501';
  end if;

  select o.* into v_order
    from orders.order_items oi
    join orders.orders o on o.id = oi.order_id
   where oi.id = p_order_item_id
   for update of o;
  if not found then
    raise exception 'order item not found' using errcode = '22023';
  end if;
  if not identity.can_manage_branch(v_order.branch_id) then
    raise exception 'you do not manage this branch' using errcode = '42501';
  end if;
  if v_order.status in ('completed', 'cancelled') then
    raise exception 'order is not editable' using errcode = '22023';
  end if;
  if v_order.payment_status = 'refunded' then
    raise exception 'refunded order is not editable' using errcode = '22023';
  end if;

  delete from orders.order_items where id = p_order_item_id;

  perform public.admin_recompute_order_totals(v_order.id);

  insert into orders.order_events (order_id, event_type, payload)
  values (
    v_order.id, 'order_status',
    jsonb_build_object('action', 'remove_item', 'item_id', p_order_item_id)
  );

  perform identity.audit(
    'order.item.remove', 'order', v_order.id, '{}'::jsonb,
    jsonb_build_object('item_id', p_order_item_id), v_order.branch_id
  );
end;
$fn$;

comment on function public.admin_remove_order_item(uuid) is
  'Delete one line of an editable order of a managed branch and recompute the '
  'invoice. Inventory is not restored — see the header.';

revoke all on function public.admin_add_order_item(uuid, uuid, int) from public, anon;
grant execute on function public.admin_add_order_item(uuid, uuid, int) to authenticated;

revoke all on function public.admin_remove_order_item(uuid) from public, anon;
grant execute on function public.admin_remove_order_item(uuid) to authenticated;

revoke all on function public.admin_recompute_order_totals(uuid) from public, anon;
revoke execute on function public.admin_recompute_order_totals(uuid) from authenticated;
grant execute on function public.admin_recompute_order_totals(uuid) to service_role;

notify pgrst, 'reload schema';

-- ---------------------------------------------------------------------------
-- ROLLBACK
-- There is no in-place rollback: the replaced bodies are 176:880, 178:478, 145,
-- 146 and 154. Re-running 154, then 145, then 176 and 178 restores them, and
-- drop function public.admin_recompute_order_totals(uuid) removes the helper.
-- ---------------------------------------------------------------------------
