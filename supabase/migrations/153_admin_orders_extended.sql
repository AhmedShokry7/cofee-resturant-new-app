-- 153_admin_orders_extended.sql
--
-- Extends public.admin_orders() so the dashboard can render a complete
-- order detail page without extra round trips.
--
-- Added to the order object:
--   * payment_method_id  (uuid, may be null)  -- payment method chosen
--   * delivery_address    (jsonb)               -- the address snapshot
--   * customer_phone      (text, may be null)   -- from identity.profiles
--
-- Added to each item:
--   * id                  (uuid)                -- needed by
--                                                 admin_remove_order_item
--   * product_id          (uuid, may be null)   -- needed by
--                                                 admin_add_order_item checks
--   * image_url           (text, may be null)   -- product image snapshot
--   * note                (text)                -- customer note on the line
--
-- Backward compatible: every existing field is kept with the same name and
-- type. New fields are additive and may be null for older rows.
--
-- Security: same permission gate as before (orders.read). No new data is
-- exposed beyond what an authorized admin already needs to see; customer
-- phone is part of the customer record already readable through
-- admin_customer_details.
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
      'customer_name', p.full_name,
      'customer_email', p.email,
      'customer_phone', p.phone,
      'customer_avatar_url', p.avatar_url,
      'branch_id', o.branch_id,
      'branch_name_ar', b.name_ar,
      'branch_name_en', b.name_en,
      'fulfillment_type', o.fulfillment_type,
      'status', o.status,
      'payment_method_id', o.payment_method_id,
      'payment_status', o.payment_status,
      'subtotal', o.subtotal,
      'discount_total', o.discount_total,
      'delivery_fee', o.delivery_fee,
      'tax_total', o.tax_total,
      'grand_total', o.grand_total,
      'placed_at', o.placed_at,
      'delivery_address_snapshot', o.delivery_address_snapshot,
      'items', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', oi.id,
          'product_id', oi.product_id,
          'product_name_ar', oi.product_name_ar,
          'product_name_en', oi.product_name_en,
          'image_url', oi.image_snapshot,
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
    left join core.branches b on b.id = o.branch_id
  ), '[]'::jsonb);
end;
$fn$;

revoke all on function public.admin_orders() from public, anon;
grant execute on function public.admin_orders() to authenticated;