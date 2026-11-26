-- Small aggregate-only read APIs for the admin assistant. They intentionally
-- return no customer, card, provider-reference, note or employee identity data.

create or replace function public.admin_assistant_order_metrics(
  p_from timestamptz default null,
  p_until timestamptz default null,
  p_branch_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_from timestamptz := coalesce(p_from, now() - interval '30 days');
  v_until timestamptz := coalesce(p_until, now());
begin
  if not identity.is_staff()
     or not identity.has_permission('orders.read') then
    raise exception 'missing permission: orders.read' using errcode = '42501';
  end if;
  if v_from >= v_until or v_until - v_from > interval '366 days' then
    raise exception 'invalid report window' using errcode = '22023';
  end if;
  if p_branch_id is not null
     and not identity.can_manage_branch(p_branch_id) then
    raise exception 'branch out of scope' using errcode = '42501';
  end if;

  return (
    with scoped as materialized (
      select o.branch_id, o.status, o.fulfillment_type, o.payment_status,
             o.grand_total, o.currency_code, o.placed_at, o.completed_at,
             b.name_ar as branch_name_ar, b.name_en as branch_name_en
        from orders.orders o
        join core.branches b on b.id = o.branch_id
       where identity.can_manage_branch(o.branch_id)
         and (p_branch_id is null or o.branch_id = p_branch_id)
         and o.test_only is not true
         and o.placed_at >= v_from and o.placed_at < v_until
    ), status_rows as (
      select status, count(*)::int as orders
        from scoped group by status
    ), fulfillment_rows as (
      select fulfillment_type, count(*)::int as orders,
             count(*) filter (where status <> 'cancelled')::int as active_or_completed_orders
        from scoped group by fulfillment_type
    ), payment_rows as (
      select payment_status, count(*)::int as orders
        from scoped group by payment_status
    ), revenue_rows as (
      select currency_code,
             count(*) filter (where status <> 'cancelled')::int as orders,
             coalesce(sum(grand_total) filter (where status <> 'cancelled'), 0)::numeric as order_total
        from scoped group by currency_code
    ), branch_rows as (
      select branch_id, branch_name_ar, branch_name_en, currency_code,
             count(*)::int as orders,
             count(*) filter (where status <> 'cancelled')::int as non_cancelled_orders,
             coalesce(sum(grand_total) filter (where status <> 'cancelled'), 0)::numeric as order_total
        from scoped group by branch_id, branch_name_ar, branch_name_en, currency_code
    ), invoice_rows as (
      select i.status, count(*)::int as invoices
        from orders.invoices i
        join orders.orders io on io.id = i.order_id
       where identity.can_manage_branch(i.branch_id)
         and (p_branch_id is null or i.branch_id = p_branch_id)
         and i.test_only is not true
         and io.test_only is not true
         and i.issued_at >= v_from and i.issued_at < v_until
       group by i.status
    ), completed as (
      select extract(epoch from (completed_at - placed_at)) / 60.0 as minutes
        from scoped
       where status = 'completed'
         and completed_at is not null
         and completed_at >= placed_at
    )
    select jsonb_build_object(
      'from', v_from,
      'until', v_until,
      'orders', (select count(*)::int from scoped),
      'cancelled_orders', (select count(*)::int from scoped where status = 'cancelled'),
      'completed_orders', (select count(*)::int from scoped where status = 'completed'),
      'average_completed_minutes', (select round(avg(minutes)::numeric, 2) from completed),
      'status_counts', coalesce((
        select jsonb_agg(jsonb_build_object('status', status, 'orders', orders) order by status)
          from status_rows
      ), '[]'::jsonb),
      'fulfillment_counts', coalesce((
        select jsonb_agg(jsonb_build_object(
          'fulfillment_type', fulfillment_type,
          'orders', orders,
          'non_cancelled_orders', active_or_completed_orders
        ) order by fulfillment_type)
          from fulfillment_rows
      ), '[]'::jsonb),
      'payment_status_counts', coalesce((
        select jsonb_agg(jsonb_build_object('status', payment_status, 'orders', orders) order by payment_status)
          from payment_rows
      ), '[]'::jsonb),
      'order_totals_by_currency', coalesce((
        select jsonb_agg(jsonb_build_object(
          'currency_code', currency_code,
          'orders', orders,
          'order_total', order_total
        ) order by currency_code)
          from revenue_rows
      ), '[]'::jsonb),
      'branch_comparison', coalesce((
        select jsonb_agg(jsonb_build_object(
          'branch_name_ar', branch_name_ar,
          'branch_name_en', branch_name_en,
          'currency_code', currency_code,
          'orders', orders,
          'non_cancelled_orders', non_cancelled_orders,
          'order_total', order_total
        ) order by branch_name_ar, branch_name_en, currency_code)
          from branch_rows
      ), '[]'::jsonb),
      'invoice_status_counts', coalesce((
        select jsonb_agg(jsonb_build_object('status', status, 'invoices', invoices) order by status)
          from invoice_rows
      ), '[]'::jsonb)
    )
  );
end;
$fn$;

comment on function public.admin_assistant_order_metrics(timestamptz, timestamptz, uuid) is
  'Aggregate order, fulfillment, payment-status, branch and invoice metrics. Every row is server-scoped to the staff member.';
revoke all on function public.admin_assistant_order_metrics(timestamptz, timestamptz, uuid) from public, anon;
grant execute on function public.admin_assistant_order_metrics(timestamptz, timestamptz, uuid) to authenticated;

create or replace function public.admin_assistant_payment_metrics(
  p_from timestamptz default null,
  p_until timestamptz default null,
  p_branch_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_from timestamptz := coalesce(p_from, now() - interval '30 days');
  v_until timestamptz := coalesce(p_until, now());
begin
  if not identity.is_staff()
     or not identity.has_permission('payments.read') then
    raise exception 'missing permission: payments.read' using errcode = '42501';
  end if;
  if v_from >= v_until or v_until - v_from > interval '366 days' then
    raise exception 'invalid report window' using errcode = '22023';
  end if;
  if p_branch_id is not null
     and not identity.can_manage_branch(p_branch_id) then
    raise exception 'branch out of scope' using errcode = '42501';
  end if;

  return (
    with scoped as materialized (
      select t.status, t.refund_status, t.amount, t.currency_code,
             coalesce(m.code, 'unknown') as method_code,
             coalesce(m.name_ar, '') as method_name_ar,
             coalesce(m.name_en, '') as method_name_en
        from payments.payment_transactions t
        join orders.orders o on o.id = t.order_id
        left join payments.payment_methods m on m.id = t.method_id
       where identity.can_manage_branch(o.branch_id)
         and (p_branch_id is null or o.branch_id = p_branch_id)
         and o.test_only is not true
         and t.created_at >= v_from and t.created_at < v_until
    ), status_rows as (
      select status, currency_code, count(*)::int as transactions,
             coalesce(sum(amount), 0)::numeric as recorded_amount
        from scoped group by status, currency_code
    ), refund_rows as (
      select refund_status, count(*)::int as transactions
        from scoped group by refund_status
    ), currency_rows as (
      select currency_code,
             count(*) filter (where status = 'captured')::int as captured_transactions,
             coalesce(sum(amount) filter (where status = 'captured'), 0)::numeric as captured_transaction_amount
        from scoped group by currency_code
    ), method_rows as (
      select method_code, method_name_ar, method_name_en,
             count(*)::int as transactions,
             count(*) filter (where status = 'captured')::int as captured_transactions
        from scoped group by method_code, method_name_ar, method_name_en
    )
    select jsonb_build_object(
      'from', v_from,
      'until', v_until,
      'transactions', (select count(*)::int from scoped),
      'status_counts', coalesce((
        select jsonb_agg(jsonb_build_object(
          'status', status,
          'currency_code', currency_code,
          'transactions', transactions,
          'recorded_amount', recorded_amount
        ) order by status, currency_code) from status_rows
      ), '[]'::jsonb),
      'refund_status_counts', coalesce((
        select jsonb_agg(jsonb_build_object(
          'refund_status', refund_status,
          'transactions', transactions
        ) order by refund_status) from refund_rows
      ), '[]'::jsonb),
      'captured_by_currency', coalesce((
        select jsonb_agg(jsonb_build_object(
          'currency_code', currency_code,
          'captured_transactions', captured_transactions,
          'captured_transaction_amount', captured_transaction_amount
        ) order by currency_code) from currency_rows
      ), '[]'::jsonb),
      'methods', coalesce((
        select jsonb_agg(jsonb_build_object(
          'method_code', method_code,
          'method_name_ar', method_name_ar,
          'method_name_en', method_name_en,
          'transactions', transactions,
          'captured_transactions', captured_transactions
        ) order by method_code) from method_rows
      ), '[]'::jsonb)
    )
  );
end;
$fn$;

comment on function public.admin_assistant_payment_metrics(timestamptz, timestamptz, uuid) is
  'Aggregate payment transaction status and captured amounts by currency for branches the staff member can manage; contains no card or customer identity data.';
revoke all on function public.admin_assistant_payment_metrics(timestamptz, timestamptz, uuid) from public, anon;
grant execute on function public.admin_assistant_payment_metrics(timestamptz, timestamptz, uuid) to authenticated;

create or replace function public.admin_assistant_dining_summary(
  p_branch_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_target uuid := p_branch_id;
  v_branch jsonb;
  v_metrics jsonb;
  v_table_status_counts jsonb;
begin
  if not identity.is_staff()
     or not identity.has_permission('tables.read') then
    raise exception 'missing permission: tables.read' using errcode = '42501';
  end if;

  if v_target is null then
    select b.id into v_target
      from core.branches b
     where b.is_active and identity.can_manage_branch(b.id)
     order by b.name_ar, b.name_en
     limit 1;
  end if;
  if v_target is null or not identity.can_manage_branch(v_target) then
    raise exception 'branch out of scope' using errcode = '42501';
  end if;

  select jsonb_build_object(
    'name_ar', b.name_ar,
    'name_en', b.name_en,
    'is_active', b.is_active
  ) into v_branch
    from core.branches b where b.id = v_target;

  with table_states as (
    select t.id,
      case
        when not t.is_active then 'inactive'
        when exists (
          select 1 from orders.orders o
           where o.floor_table_id = t.id
             and o.status not in ('completed', 'cancelled')
             and o.test_only is not true
        ) then 'occupied'
        when exists (
          select 1 from floor.reservations r
           where r.table_id = t.id
             and (r.status = 'seated' or (
               r.status = 'confirmed'
               and r.reserved_for <= now() + interval '30 minutes'
               and r.reserved_for + make_interval(mins => r.duration_minutes) > now()
             ))
        ) then case when exists (
          select 1 from floor.reservations r
           where r.table_id = t.id and r.status = 'seated'
        ) then 'seated' else 'reserved' end
        else 'available'
      end as status
      from floor.tables t
     where t.branch_id = v_target
  ), status_counts as (
    select status, count(*)::int as tables from table_states group by status
  )
  select
    coalesce(jsonb_agg(jsonb_build_object('status', status, 'tables', tables) order by status), '[]'::jsonb),
    jsonb_build_object(
      'tables', coalesce(sum(tables) filter (where status <> 'inactive'), 0),
      'available', coalesce(sum(tables) filter (where status = 'available'), 0),
      'occupied', coalesce(sum(tables) filter (where status = 'occupied'), 0),
      'reserved', coalesce(sum(tables) filter (where status in ('reserved', 'seated')), 0),
      'reservations_today', (
        select count(*)::int from floor.reservations r
         where r.branch_id = v_target
           and r.status in ('confirmed', 'seated')
           and r.reserved_for >= date_trunc('day', now())
           and r.reserved_for < date_trunc('day', now()) + interval '1 day'
      ),
      'upcoming', (
        select count(*)::int from floor.reservations r
         where r.branch_id = v_target and r.status = 'confirmed'
           and r.reserved_for >= now()
           and r.reserved_for < now() + interval '7 days'
      )
    )
    into v_table_status_counts, v_metrics
    from status_counts;

  return jsonb_build_object(
    'branch', coalesce(v_branch, '{}'::jsonb),
    'metrics', coalesce(v_metrics, '{}'::jsonb),
    'table_status_counts', coalesce(v_table_status_counts, '[]'::jsonb)
  );
end;
$fn$;

comment on function public.admin_assistant_dining_summary(uuid) is
  'Branch-scoped dining/reservation counts and table status counts without reservation identity or notes.';
revoke all on function public.admin_assistant_dining_summary(uuid) from public, anon;
grant execute on function public.admin_assistant_dining_summary(uuid) to authenticated;

notify pgrst, 'reload schema';
