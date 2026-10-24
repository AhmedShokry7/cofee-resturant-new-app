-- 139_admin_carts.sql
create or replace function public.admin_abandoned_carts()
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
      'id', c.id,
      'user_id', c.user_id,
      'customer_name', p.full_name,
      'customer_email', p.email,
      'branch_id', c.branch_id,
      'branch_name_ar', b.name_ar,
      'branch_name_en', b.name_en,
      'status', c.status,
      'expires_at', c.expires_at,
      'created_at', c.created_at,
      'updated_at', c.updated_at,
      'total', coalesce((select sum(ci.line_total) from orders.cart_items ci where ci.cart_id = c.id), 0),
      'items', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', ci.id,
          'product_id', ci.product_id,
          'product_name_ar', pr.name_ar,
          'product_name_en', pr.name_en,
          'image_url', pr.image_url,
          'quantity', ci.quantity,
          'unit_price', ci.unit_price,
          'line_total', ci.line_total,
          'note', ci.note
        ) order by ci.created_at)
        from orders.cart_items ci
        left join catalog.products pr on pr.id = ci.product_id
        where ci.cart_id = c.id
      ), '[]'::jsonb)
    ) order by c.updated_at desc)
    from orders.carts c
    left join identity.profiles p on p.id = c.user_id
    left join core.branches b on b.id = c.branch_id
    where c.status in ('active', 'abandoned')
  ), '[]'::jsonb);
end;
$fn$;

revoke all on function public.admin_abandoned_carts() from public, anon;
grant execute on function public.admin_abandoned_carts() to authenticated;
