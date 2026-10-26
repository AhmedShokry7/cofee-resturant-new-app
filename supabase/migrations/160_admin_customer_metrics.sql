-- 160_admin_customer_metrics.sql
create or replace function public.admin_customers()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('customers.read') then
    raise exception 'missing permission: customers.read' using errcode = '42501';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', p.id,
      'full_name', p.full_name,
      'email', p.email,
      'phone', p.phone,
      'avatar_url', p.avatar_url,
      'language', p.language,
      'last_seen_at', p.last_seen_at,
      'created_at', p.created_at,
      'updated_at', p.updated_at,
      'orders_count', coalesce(o.cnt, 0),
      'total_spent', coalesce(o.spent, 0),
      'last_order_at', o.last_order_at,
      'is_vip', p.is_vip,
      'is_blacklisted', p.is_blacklisted,
      'admin_notes', p.admin_notes
    ) order by p.created_at desc)
    from identity.profiles p
    left join lateral (
      select
        count(*)::int as cnt,
        coalesce(sum(grand_total), 0)::numeric as spent,
        max(placed_at) as last_order_at
      from orders.orders
      where user_id = p.id
    ) o on true
    where not exists (
      select 1 from identity.staff_members sm where sm.user_id = p.id
    )
  ), '[]'::jsonb);
end;
$fn$;

revoke all on function public.admin_customers() from public, anon;
grant execute on function public.admin_customers() to authenticated;

create or replace function public.admin_customer_metrics()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_month_start timestamptz := (
    date_trunc('month', now() at time zone 'Asia/Riyadh')
    at time zone 'Asia/Riyadh'
  );
  v_previous_month_start timestamptz := (
    date_trunc('month', now() at time zone 'Asia/Riyadh')
    at time zone 'Asia/Riyadh'
  ) - interval '1 month';
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('customers.read') then
    raise exception 'missing permission: customers.read' using errcode = '42501';
  end if;

  return (
    with customers as (
      select p.id, p.created_at
        from identity.profiles p
       where not exists (
         select 1 from identity.staff_members sm where sm.user_id = p.id
       )
    ),
    order_stats as (
      select
        o.user_id,
        count(*) filter (where o.placed_at >= v_month_start) as current_orders,
        count(*) filter (
          where o.placed_at >= v_previous_month_start
            and o.placed_at < v_month_start
        ) as previous_orders,
        coalesce(sum(o.grand_total) filter (
          where o.placed_at >= v_month_start
        ), 0) as current_spent,
        coalesce(sum(o.grand_total) filter (
          where o.placed_at >= v_previous_month_start
            and o.placed_at < v_month_start
        ), 0) as previous_spent
        from orders.orders o
        join customers c on c.id = o.user_id
       group by o.user_id
    )
    select jsonb_build_object(
      'total_customers', (select count(*) from customers),
      'previous_total_customers', (
        select count(*) from customers where created_at < v_month_start
      ),
      'new_customers', (
        select count(*) from customers where created_at >= v_month_start
      ),
      'previous_new_customers', (
        select count(*)
          from customers
         where created_at >= v_previous_month_start
           and created_at < v_month_start
      ),
      'current_buyers', (
        select count(*) from order_stats where current_orders > 0
      ),
      'previous_buyers', (
        select count(*) from order_stats where previous_orders > 0
      ),
      'current_spent', (
        select coalesce(sum(current_spent), 0) from order_stats
      ),
      'previous_spent', (
        select coalesce(sum(previous_spent), 0) from order_stats
      ),
      'current_repeat_buyers', (
        select count(*) from order_stats where current_orders >= 2
      ),
      'previous_repeat_buyers', (
        select count(*) from order_stats where previous_orders >= 2
      )
    )
  );
end;
$fn$;

revoke all on function public.admin_customer_metrics() from public, anon;
grant execute on function public.admin_customer_metrics() to authenticated;
