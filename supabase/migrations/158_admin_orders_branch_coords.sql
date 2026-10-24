-- 144_admin_orders.sql
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
      'branch_id', o.branch_id,
      'branch_name_ar', b.name_ar,
      'branch_name_en', b.name_en,
      'branch_latitude', b.latitude,
      'branch_longitude', b.longitude,
      'fulfillment_type', o.fulfillment_type,
      'status', o.status,
      'payment_status', o.payment_status,
      'subtotal', o.subtotal,
      'discount_total', o.discount_total,
      'delivery_fee', o.delivery_fee,
      'tax_total', o.tax_total,
      'grand_total', o.grand_total,
      'placed_at', o.placed_at,
      'items', coalesce((
        select jsonb_agg(jsonb_build_object(
          'product_name_ar', oi.product_name_ar,
          'product_name_en', oi.product_name_en,
          'quantity', oi.quantity,
          'unit_price', oi.unit_price,
          'line_total', oi.line_total
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

