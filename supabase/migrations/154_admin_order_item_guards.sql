-- 154_admin_order_item_guards.sql
--
-- Hardens admin_add_order_item and admin_remove_order_item so that:
--   * an order that is completed, cancelled or refunded cannot be edited;
--   * the recompute of subtotal / grand_total happens inside the same
--     transaction as the item write (already the case, now explicit);
--   * an audit row is written to orders.order_events using the existing
--     'order_status' event type, so the edit is traceable.
--
-- Permission: orders.status.update (unchanged).
--
-- The client-side OrderEditRules in the Flutter app must stay in sync with
-- these rules; the server is the authority.
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
  v_item_id uuid;
  v_product catalog.products%rowtype;
  v_unit_price numeric(12,2);
  v_status text;
  v_payment_status text;
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

  select status, payment_status into v_status, v_payment_status
    from orders.orders where id = p_order_id;
  if v_status is null then
    raise exception 'order not found' using errcode = '22023';
  end if;
  if v_status in ('completed', 'cancelled') then
    raise exception 'order is not editable' using errcode = '22023';
  end if;
  if v_payment_status = 'refunded' then
    raise exception 'refunded order is not editable' using errcode = '22023';
  end if;

  select * into v_product from catalog.products where id = p_product_id;
  if not found then
    raise exception 'product not found' using errcode = '22023';
  end if;

  v_unit_price := v_product.base_price;

  insert into orders.order_items (
    order_id, product_id, product_name_ar, product_name_en, sku_snapshot,
    image_snapshot, unit_price, quantity, line_total, discount_total,
    product_discount_total, options_key, note
  )
  values (
    p_order_id, p_product_id, v_product.name_ar, v_product.name_en, v_product.sku,
    v_product.image_url, v_unit_price, p_quantity, round(v_unit_price * p_quantity, 2),
    0, 0, '', ''
  )
  returning id into v_item_id;

  update orders.orders
     set subtotal = coalesce((select sum(line_total) from orders.order_items where order_id = p_order_id), 0),
         grand_total = coalesce((select sum(line_total) from orders.order_items where order_id = p_order_id), 0),
         updated_at = now()
   where id = p_order_id;

  insert into orders.order_events (order_id, event_type, payload)
  values (p_order_id, 'order_status', jsonb_build_object('action', 'add_item', 'item_id', v_item_id, 'product_id', p_product_id, 'quantity', p_quantity));

  return v_item_id;
end;
$fn$;

create or replace function public.admin_remove_order_item(
  p_order_item_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_order_id uuid;
  v_status text;
  v_payment_status text;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('orders.status.update') then
    raise exception 'missing permission: orders.status.update' using errcode = '42501';
  end if;

  select order_id into v_order_id from orders.order_items where id = p_order_item_id;
  if v_order_id is null then
    raise exception 'order item not found' using errcode = '22023';
  end if;

  select status, payment_status into v_status, v_payment_status
    from orders.orders where id = v_order_id;
  if v_status in ('completed', 'cancelled') then
    raise exception 'order is not editable' using errcode = '22023';
  end if;
  if v_payment_status = 'refunded' then
    raise exception 'refunded order is not editable' using errcode = '22023';
  end if;

  delete from orders.order_items where id = p_order_item_id;

  update orders.orders
     set subtotal = coalesce((select sum(line_total) from orders.order_items where order_id = v_order_id), 0),
         grand_total = coalesce((select sum(line_total) from orders.order_items where order_id = v_order_id), 0),
         updated_at = now()
   where id = v_order_id;

  insert into orders.order_events (order_id, event_type, payload)
  values (v_order_id, 'order_status', jsonb_build_object('action', 'remove_item', 'item_id', p_order_item_id));
end;
$fn$;

revoke all on function public.admin_add_order_item(uuid, uuid, int) from public, anon;
grant execute on function public.admin_add_order_item(uuid, uuid, int) to authenticated;

revoke all on function public.admin_remove_order_item(uuid) from public, anon;
grant execute on function public.admin_remove_order_item(uuid) to authenticated;