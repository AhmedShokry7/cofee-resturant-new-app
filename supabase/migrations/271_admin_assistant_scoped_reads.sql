-- Secure, branch-scoped read surfaces dedicated to the admin assistant.
-- No role receives the coupon-read permission automatically.

insert into identity.permissions (code, name_ar, name_en, description)
values (
  'coupons.read',
  'قراءة تقارير الكوبونات',
  'Read coupon reports',
  'Read coupon redemption reports for assigned branches; grants no write access.'
)
on conflict (code) do update
set name_ar = excluded.name_ar,
    name_en = excluded.name_en,
    description = excluded.description;

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
  v_search text := translate(lower(btrim(coalesce(p_search, ''))), 'أإآةى', 'اااهي');
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
    where translate(lower(coalesce(p.full_name, '')), 'أإآةى', 'اااهي')
          like '%' || v_search || '%'
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

create or replace function public.admin_assistant_customer_orders(
  p_customer_id uuid,
  p_limit integer default 5
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_limit integer := greatest(1, least(coalesce(p_limit, 5), 10));
  v_result jsonb;
begin
  if not identity.is_staff()
     or not identity.has_permission('customers.read') then
    raise exception 'missing permission: customers.read' using errcode = '42501';
  end if;
  if p_customer_id is null or not exists (
    select 1
    from orders.orders o
    join identity.profiles p on p.id = o.user_id
    where o.user_id = p_customer_id
      and coalesce(o.test_only, false) = false
      and identity.can_manage_branch(o.branch_id)
      and not exists (select 1 from identity.staff_members sm where sm.user_id = p.id)
  ) then
    raise exception 'customer has no orders in the permitted branch scope' using errcode = '42501';
  end if;

  select coalesce(jsonb_agg(row_json order by placed_at desc), '[]'::jsonb)
  into v_result
  from (
    select o.placed_at,
      jsonb_build_object(
        'id', o.id,
        'status', o.status,
        'grand_total', o.grand_total,
        'placed_at', o.placed_at,
        'branch_id', o.branch_id,
        'branch_name_ar', b.name_ar,
        'branch_name_en', b.name_en,
        'items', coalesce((
          select jsonb_agg(jsonb_build_object(
            'product_name_ar', oi.product_name_ar,
            'product_name_en', oi.product_name_en,
            'quantity', oi.quantity
          ) order by oi.id)
          from orders.order_items oi where oi.order_id = o.id
        ), '[]'::jsonb)
      ) as row_json
    from orders.orders o
    left join core.branches b on b.id = o.branch_id
    where o.user_id = p_customer_id
      and coalesce(o.test_only, false) = false
      and identity.can_manage_branch(o.branch_id)
    order by o.placed_at desc
    limit v_limit
  ) scoped;
  return v_result;
end;
$$;

create or replace function public.admin_assistant_coupon_report(p_limit integer default 100)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_limit integer := greatest(1, least(coalesce(p_limit, 100), 200));
  v_result jsonb;
begin
  if not identity.is_staff()
     or not identity.has_permission('coupons.read') then
    raise exception 'missing permission: coupons.read' using errcode = '42501';
  end if;

  with scoped as (
    select r.coupon_id, r.user_id, r.amount, r.created_at
    from marketing.coupon_redemptions r
    join orders.orders o on o.id = r.order_id
    where coalesce(o.test_only, false) = false
      and identity.can_manage_branch(o.branch_id)
  ), aggregated as (
    select c.id, c.code, c.title_ar, c.title_en,
           c.discount_type, c.discount_value,
           count(s.coupon_id)::integer as redemptions_count,
           count(distinct s.user_id)::integer as unique_customers,
           coalesce(sum(s.amount), 0)::numeric(14,2) as discount_given,
           max(s.created_at) as last_redeemed_at
    from marketing.coupons c
    join scoped s on s.coupon_id = c.id
    group by c.id
    order by count(s.coupon_id) desc, c.code
    limit v_limit
  )
  select jsonb_build_object(
    'rows', coalesce(jsonb_agg(jsonb_build_object(
      'id', id, 'code', code, 'title_ar', title_ar, 'title_en', title_en,
      'discount_type', discount_type, 'discount_value', discount_value,
      'redemptions_count', redemptions_count,
      'unique_customers', unique_customers,
      'discount_given', discount_given,
      'last_redeemed_at', last_redeemed_at
    ) order by redemptions_count desc, code), '[]'::jsonb),
    'redemptions', coalesce(sum(redemptions_count), 0),
    'coupon_count', (select count(distinct coupon_id) from scoped),
    'unique_customers', (select count(distinct user_id) from scoped),
    'discount_given', coalesce((select sum(amount) from scoped), 0),
    'truncated', (select count(*) > v_limit from (
       select distinct coupon_id from scoped
    ) all_scoped_coupons)
  ) into v_result
  from aggregated;
  return v_result;
end;
$$;

revoke all on function public.admin_assistant_customer_directory(text, integer) from public, anon;
revoke all on function public.admin_assistant_customer_orders(uuid, integer) from public, anon;
revoke all on function public.admin_assistant_coupon_report(integer) from public, anon;
grant execute on function public.admin_assistant_customer_directory(text, integer) to authenticated;
grant execute on function public.admin_assistant_customer_orders(uuid, integer) to authenticated;
grant execute on function public.admin_assistant_coupon_report(integer) to authenticated;
