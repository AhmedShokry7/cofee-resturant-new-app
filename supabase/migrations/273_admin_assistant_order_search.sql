-- Order lookup for the admin assistant. Customer identity is omitted unless
-- the caller also has customers.read; every order is server-side branch scoped.
create or replace function public.admin_assistant_order_search(
  p_search text,
  p_limit integer default 10
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_search text := translate(lower(btrim(left(coalesce(p_search, ''), 80))), 'أإآةى', 'اااهي');
  v_limit integer := greatest(1, least(coalesce(p_limit, 10), 25));
  v_result jsonb;
begin
  if not identity.is_staff()
     or not identity.has_permission('orders.read') then
    raise exception 'missing permission: orders.read' using errcode = '42501';
  end if;
  if char_length(v_search) < 2 then
    return jsonb_build_object('rows', '[]'::jsonb, 'truncated', false);
  end if;

  with matches as (
    select o.id, o.order_number, o.status, o.payment_status,
           o.fulfillment_type, o.grand_total, o.currency_code, o.placed_at,
           b.name_ar as branch_name_ar, b.name_en as branch_name_en,
           case when identity.has_permission('customers.read')
             then coalesce(nullif(p.full_name,''), nullif(pc.full_name,''))
             else null end as customer_name,
           coalesce((
             select jsonb_agg(jsonb_build_object(
               'product_name_ar', oi.product_name_ar,
               'product_name_en', oi.product_name_en,
               'quantity', oi.quantity
             ) order by oi.id)
             from (
               select x.* from orders.order_items x
               where x.order_id = o.id order by x.id limit 12
             ) oi
           ), '[]'::jsonb) as items,
           case when o.status = 'cancelled' then (
             select nullif(btrim(h.note),'')
             from orders.order_status_history h
             where h.order_id = o.id and h.to_status = 'cancelled'
             order by h.created_at desc limit 1
           ) else null end as cancellation_note
    from orders.orders o
    left join core.branches b on b.id = o.branch_id
    left join identity.profiles p on p.id = o.user_id
    left join orders.pos_customers pc on pc.id = o.pos_customer_id
    where coalesce(o.test_only, false) = false
      and identity.can_manage_branch(o.branch_id)
      and (
        position(v_search in translate(lower(coalesce(o.order_number,'')), 'أإآةى', 'اااهي')) > 0
        or (identity.has_permission('customers.read') and position(
          v_search in translate(lower(coalesce(p.full_name, pc.full_name, '')), 'أإآةى', 'اااهي')
        ) > 0)
      )
    order by o.placed_at desc
    limit v_limit + 1
  )
  select jsonb_build_object(
    'rows', coalesce((
      select jsonb_agg(jsonb_build_object(
        'order_number', x.order_number,
        'status', x.status,
        'payment_status', x.payment_status,
        'fulfillment_type', x.fulfillment_type,
        'grand_total', x.grand_total,
        'currency_code', x.currency_code,
        'placed_at', x.placed_at,
        'branch_name_ar', x.branch_name_ar,
        'branch_name_en', x.branch_name_en,
        'customer_name', x.customer_name,
        'items', x.items,
        'cancellation_note', x.cancellation_note
      ) order by x.placed_at desc)
      from (select * from matches limit v_limit) x
    ), '[]'::jsonb),
    'truncated', (select count(*) > v_limit from matches)
  ) into v_result;
  return v_result;
end;
$$;

revoke all on function public.admin_assistant_order_search(text, integer) from public, anon;
grant execute on function public.admin_assistant_order_search(text, integer) to authenticated;
