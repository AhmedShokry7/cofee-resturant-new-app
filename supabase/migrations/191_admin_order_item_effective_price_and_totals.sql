-- 191_admin_order_item_effective_price_and_totals.sql
--
-- Records the rest of topic B from
-- supabase/proposals/186_admin_orders_branch_scope_and_totals.PROPOSED.sql,
-- which is also already deployed in webzzasosevzymftgszn but absent from the
-- chain (146_admin_order_items.sql and 154_admin_order_item_guards.sql still
-- hold the pre-audit bodies).
--
--  * admin_recompute_order_totals(uuid) is a private helper: it is deliberately
--    NOT granted to authenticated, so a client can only reach it through the
--    two item RPCs.
--  * admin_add_order_item guards the branch with identity.can_manage_branch,
--    prices the line with catalog.resolve_effective_price instead of
--    catalog.products.base_price, and recomputes the totals so ck_orders_total
--    keeps holding on orders that carry a delivery fee or a coupon.
--  * admin_remove_order_item guards the branch and recomputes the totals.
--
-- Inventory is still untouched by design (audit topic C), and delivery_fee is
-- not re-priced on an added line (audit topic E).
--
-- This file is a no-op against the live project: it replays the deployed
-- definitions verbatim.

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

revoke all on function public.admin_recompute_order_totals(uuid) from public, anon, authenticated;
grant execute on function public.admin_recompute_order_totals(uuid) to service_role;

create or replace function public.admin_add_order_item(p_order_id uuid, p_product_id uuid, p_quantity integer)
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

revoke all on function public.admin_add_order_item(uuid, uuid, int) from public, anon;
grant execute on function public.admin_add_order_item(uuid, uuid, int) to authenticated;

create or replace function public.admin_remove_order_item(p_order_item_id uuid)
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

revoke all on function public.admin_remove_order_item(uuid) from public, anon;
grant execute on function public.admin_remove_order_item(uuid) to authenticated;
