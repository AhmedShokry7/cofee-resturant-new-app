-- Adds POS cashier attribution to the existing branch-scoped orders report.
-- Customer POS ids are included too, so customer reports can count those orders.
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
      'cashier_name', cashier.full_name,
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
    left join payments.pos_shifts ps on ps.id = o.pos_shift_id
    left join identity.staff_members cashier on cashier.id = ps.opened_by
    left join core.branches b on b.id = o.branch_id
    -- 183 and 185 already answer only for the branches the caller manages; the
    -- directory has to agree with its own counter, otherwise the badge says 3
    -- and the list shows 40.
    where identity.can_manage_branch(o.branch_id)
  ), '[]'::jsonb);
end;
$fn$;

comment on function public.admin_orders() is
  'Branch-scoped order report with customer and POS cashier attribution.';

revoke all on function public.admin_orders() from public, anon;
grant execute on function public.admin_orders() to authenticated;

notify pgrst, 'reload schema';
