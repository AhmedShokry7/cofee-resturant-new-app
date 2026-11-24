-- 268_abandoned_carts_eligibility.sql
--
-- The admin cart page must only show carts that are genuinely abandoned and
-- still worth acting on. The previous RPC returned every active/abandoned
-- cart in the managed branches, including empty carts, carts made only of
-- zero-priced lines and carts whose total was zero.
--
-- Eligibility is decided here, in the database, from the same canonical
-- stored totals orders.get_cart_summary() reads. A line counts when its
-- product still exists, its quantity is positive and its stored total is not
-- negative. The cart's total is the
-- rounded sum of those lines, so free lines may sit beside paid ones but an
-- all-free cart is excluded. Converted carts were already excluded by the
-- status filter; an order does not keep the cart active.
--
-- Branch scope, ordering, customer/branch fields and item details are
-- unchanged. No table, index, RLS policy or pricing rule is touched.

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
    with eligible as (
      select c.id,
             coalesce(round(sum(ci.line_total), 2), 0) as total
        from orders.carts c
        join orders.cart_items ci on ci.cart_id = c.id
        join catalog.products pr on pr.id = ci.product_id
       where c.status in ('active', 'abandoned')
         and identity.can_manage_branch(c.branch_id)
         and ci.quantity > 0
         and ci.line_total >= 0
       group by c.id
      having coalesce(round(sum(ci.line_total), 2), 0) > 0
    )
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
      'total', e.total,
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
        ) order by ci.created_at, ci.id)
        from orders.cart_items ci
        join catalog.products pr on pr.id = ci.product_id
        where ci.cart_id = c.id
          and ci.quantity > 0
          and ci.line_total >= 0
      ), '[]'::jsonb)
    ) order by c.updated_at desc, c.id desc)
    from eligible e
    join orders.carts c on c.id = e.id
    left join identity.profiles p on p.id = c.user_id
    left join core.branches b on b.id = c.branch_id
  ), '[]'::jsonb);
end;
$fn$;

comment on function public.admin_abandoned_carts() is
  'Active/abandoned carts of managed branches that have at least one valid line and a positive canonical total.';

revoke all on function public.admin_abandoned_carts() from public, anon;
grant execute on function public.admin_abandoned_carts() to authenticated;

notify pgrst, 'reload schema';
