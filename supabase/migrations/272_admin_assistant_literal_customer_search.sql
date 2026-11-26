-- Treat assistant-provided customer search text literally; SQL LIKE wildcards
-- must not turn a name lookup into a broad directory enumeration.
create or replace function public.admin_assistant_customer_directory(
  p_search text,
  p_limit integer default 20
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_search text := translate(lower(btrim(left(coalesce(p_search, ''), 80))), 'أإآةى', 'اااهي');
  v_limit integer := greatest(1, least(coalesce(p_limit, 20), 50));
  v_result jsonb;
begin
  if not identity.is_staff()
     or not identity.has_permission('customers.read') then
    raise exception 'missing permission: customers.read' using errcode = '42501';
  end if;
  if char_length(v_search) < 2 then
    return jsonb_build_object('rows', '[]'::jsonb, 'truncated', false);
  end if;

  with scoped_orders as (
    select o.user_id, o.grand_total, o.placed_at
    from orders.orders o
    where o.user_id is not null
      and coalesce(o.test_only, false) = false
      and identity.can_manage_branch(o.branch_id)
  ), matches as (
    select p.id, p.full_name,
           count(so.user_id)::integer as orders_count,
           coalesce(sum(so.grand_total), 0)::numeric(14,2) as total_spent,
           max(so.placed_at) as last_order_at
    from identity.profiles p
    join scoped_orders so on so.user_id = p.id
    where position(v_search in translate(lower(coalesce(p.full_name, '')), 'أإآةى', 'اااهي')) > 0
      and not exists (
        select 1 from identity.staff_members sm where sm.user_id = p.id
      )
    group by p.id, p.full_name
    order by max(so.placed_at) desc nulls last, p.full_name, p.id
    limit v_limit + 1
  )
  select jsonb_build_object(
    'rows', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', page.id,
        'full_name', page.full_name,
        'orders_count', page.orders_count,
        'total_spent', page.total_spent,
        'last_order_at', page.last_order_at
      ) order by page.last_order_at desc nulls last, page.full_name, page.id)
      from (select * from matches limit v_limit) page
    ), '[]'::jsonb),
    'truncated', (select count(*) > v_limit from matches)
  ) into v_result;
  return v_result;
end;
$$;

revoke all on function public.admin_assistant_customer_directory(text, integer) from public, anon;
grant execute on function public.admin_assistant_customer_directory(text, integer) to authenticated;
