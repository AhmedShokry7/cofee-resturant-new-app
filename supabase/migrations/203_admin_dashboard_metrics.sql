-- 203_admin_dashboard_metrics.sql
--
-- اللوحة التي رسمها التصميم تحتاج أكثر من بطاقات اليوم.
--
-- 202 أعطت اللوحة أرقام اليوم وأمس وقائمة الحالات وأفضل المنتجات. ما تبقّى في
-- التصميم ثلاثة أشياء لا وجود لها في القاعدة:
--   1. حركة البيع على مدى ثلاثين يومًا (منحنى)، وهي مجرد تجميع يومي لـ grand_total؛
--   2. توزيع الطلبات على قنوات الاستلام (استلام / توصيل / داخل الفرع)، وهي
--      fulfillment_type الموجود أصلًا؛
--   3. هدف الشهر، وهو الرقم الوحيد في التصميم الذي لا يقابله عمود، فصار إعدادًا
--      حقيقيًا في core.app_settings يُكتب من اللوحة لا يُحسب.
--
-- ما لا يُخترع هنا:
--   الإيراد مجموع grand_total لغير الملغى فقط، كما في 202. واليوم بحدود
--   Asia/Riyadh وما قبله بمقارنة أمس في نفس الساعة. والنطاق هو نطاق الطلبات:
--   identity.can_manage_branch(o.branch_id). ولا يُفتح شيء بصلاحية تحليلات غير
--   موجودة؛ الباب يبقى orders.read.
--
-- المقياسان غير المرتبطين بفرع:
--   عدّ العملاء وهدف الشهر يخصّان الشركة كلها، لا فرعًا. identity.profiles لا
--   تحمل branch_id أصلًا، فالعميل ليس ملك فرع. لذلك يُرجعان فقط لمن يدير كل
--   الفروع (identity.manages_all_branches)، بدل أن يقرأ مدير فرع واحد رقم
--   الشركة ويظنّه رقم فرعه. والعميل لا يُعدّ إلا بصلاحية customers.read، وهي
--   نفس بوابة تعريف العميل.
--
-- تعريف «العميل الجديد» مستعار حرفيًا من 160: بروفايل أُنشئ هذا الشهر ولا يوجد
-- له صف في identity.staff_members. تغييره هنا وحده كان سيخالف صفحة العملاء
-- ويعطي رقمين لسؤال واحد.
--
-- الهدف يُحفظ في core.app_settings بمفتاح monthly_revenue_target، ويُكتب عبر
-- admin_set_revenue_target وحدها: صلاحية settings.write + نطاق كل الفروع، وسجل
-- تدقيق core.revenue_target.update. ولا يُزرع صف مسبقًا: اللوحة تقول «لم يُحدَّد
-- هدف» حتى يكتبه المالك، وهذا أصدق من رقم مزروع لا يستطيع تفسيره.

-- ---------------------------------------------------------------------------
-- 1. مقاييس اللوحة: جسم 202 موسّعًا
-- ---------------------------------------------------------------------------
create or replace function public.admin_dashboard_metrics()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_day_start timestamptz := (
    date_trunc('day', now() at time zone 'Asia/Riyadh')
    at time zone 'Asia/Riyadh'
  );
  v_yesterday_start timestamptz := v_day_start - interval '1 day';
  v_week_start timestamptz := v_day_start - interval '6 days';
  v_prev_week_start timestamptz := v_day_start - interval '13 days';
  v_series_start timestamptz := v_day_start - interval '29 days';
  v_month_start timestamptz := (
    date_trunc('month', now() at time zone 'Asia/Riyadh')
    at time zone 'Asia/Riyadh'
  );
  -- مثل 160 حرفيًا: الشهر السابق يُحسب من منتصف ليل الرياض وليس من منتصف ليل UTC.
  v_prev_month_start timestamptz := (
    date_trunc('month', now() at time zone 'Asia/Riyadh')
    at time zone 'Asia/Riyadh'
  ) - interval '1 month';
  v_company_scope boolean := identity.manages_all_branches();
  v_can_read_customers boolean := identity.has_permission('customers.read');
  v_target numeric;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('orders.read') then
    raise exception 'missing permission: orders.read' using errcode = '42501';
  end if;

  if v_company_scope then
    select nullif(s.value #>> '{}', '')::numeric
      into v_target
      from core.app_settings s
     where s.key = 'monthly_revenue_target';
  end if;

  return (
    with scoped as materialized (
      select
        o.id,
        o.order_number,
        o.status,
        o.grand_total,
        o.placed_at,
        o.fulfillment_type,
        o.user_id,
        o.pos_customer_id
      from orders.orders o
      where identity.can_manage_branch(o.branch_id)
    ),
    customer_profiles as materialized (
      select p.id, p.created_at
      from identity.profiles p
      where not exists (
        select 1 from identity.staff_members sm where sm.user_id = p.id
      )
    ),
    totals as (
      select
        count(*) filter (
          where s.placed_at >= v_day_start and s.status <> 'cancelled'
        )::int as today_orders,
        coalesce(sum(s.grand_total) filter (
          where s.placed_at >= v_day_start and s.status <> 'cancelled'
        ), 0)::numeric as today_revenue,
        count(*) filter (
          where s.placed_at >= v_yesterday_start
            and s.placed_at < v_day_start
            and s.status <> 'cancelled'
        )::int as yesterday_orders,
        coalesce(sum(s.grand_total) filter (
          where s.placed_at >= v_yesterday_start
            and s.placed_at < v_day_start
            and s.status <> 'cancelled'
        ), 0)::numeric as yesterday_revenue,
        count(*) filter (
          where s.placed_at >= v_week_start and s.status <> 'cancelled'
        )::int as week_orders,
        coalesce(sum(s.grand_total) filter (
          where s.placed_at >= v_week_start and s.status <> 'cancelled'
        ), 0)::numeric as week_revenue,
        count(*) filter (
          where s.placed_at >= v_prev_week_start
            and s.placed_at < v_week_start
            and s.status <> 'cancelled'
        )::int as prev_week_orders,
        coalesce(sum(s.grand_total) filter (
          where s.placed_at >= v_prev_week_start
            and s.placed_at < v_week_start
            and s.status <> 'cancelled'
        ), 0)::numeric as prev_week_revenue,
        count(*) filter (
          where s.placed_at >= v_month_start and s.status <> 'cancelled'
        )::int as month_orders,
        coalesce(sum(s.grand_total) filter (
          where s.placed_at >= v_month_start and s.status <> 'cancelled'
        ), 0)::numeric as month_revenue,
        count(*) filter (
          where s.status not in ('completed', 'cancelled')
        )::int as active_orders,
        count(*)::int as total_orders
      from scoped s
    ),
    status_breakdown as (
      select coalesce(jsonb_agg(jsonb_build_object(
        'status', s.status,
        'orders', s.orders,
        'revenue', s.revenue
      ) order by s.rank), '[]'::jsonb) as items
      from (
        select
          o.status,
          case o.status
            when 'pending' then 0
            when 'confirmed' then 1
            when 'preparing' then 2
            when 'ready' then 3
            when 'out_for_delivery' then 4
            when 'completed' then 5
            else 6
          end as rank,
          count(*)::int as orders,
          coalesce(sum(o.grand_total), 0)::numeric as revenue
        from scoped o
        where o.placed_at >= v_week_start
        group by o.status
      ) s
    ),
    sales_series as (
      select coalesce(jsonb_agg(jsonb_build_object(
        'date', to_char(d.day at time zone 'Asia/Riyadh', 'YYYY-MM-DD'),
        'revenue', d.revenue,
        'orders', d.orders
      ) order by d.day), '[]'::jsonb) as items
      from (
        select
          g.day,
          coalesce(sum(o.grand_total) filter (
            where o.status <> 'cancelled'
          ), 0)::numeric as revenue,
          count(o.id) filter (
            where o.status <> 'cancelled'
          )::int as orders
        from generate_series(
          v_series_start, v_day_start, interval '1 day'
        ) as g(day)
        left join scoped o
          on o.placed_at >= g.day
         and o.placed_at < g.day + interval '1 day'
        group by g.day
      ) d
    ),
    channels as (
      select coalesce(jsonb_agg(jsonb_build_object(
        'channel', c.fulfillment_type,
        'orders', c.orders,
        'revenue', c.revenue
      ) order by c.orders desc), '[]'::jsonb) as items
      from (
        select
          s.fulfillment_type,
          count(*)::int as orders,
          coalesce(sum(s.grand_total), 0)::numeric as revenue
        from scoped s
        where s.placed_at >= v_series_start
          and s.status <> 'cancelled'
        group by s.fulfillment_type
      ) c
    ),
    top_products as (
      select coalesce(jsonb_agg(jsonb_build_object(
        'product_name_ar', p.product_name_ar,
        'product_name_en', p.product_name_en,
        'quantity', p.quantity,
        'revenue', p.revenue
      ) order by p.quantity desc, p.revenue desc), '[]'::jsonb) as items
      from (
        select
          oi.product_name_ar,
          oi.product_name_en,
          sum(oi.quantity)::int as quantity,
          coalesce(sum(oi.line_total), 0)::numeric as revenue
        from orders.order_items oi
        join scoped o on o.id = oi.order_id
        where o.placed_at >= v_week_start
          and o.status <> 'cancelled'
        group by oi.product_name_ar, oi.product_name_en
        order by sum(oi.quantity) desc, coalesce(sum(oi.line_total), 0) desc
        limit 5
      ) p
    ),
    recent_orders as (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', r.id,
        'order_number', r.order_number,
        'customer_name', r.customer_name,
        'status', r.status,
        'fulfillment_type', r.fulfillment_type,
        'grand_total', r.grand_total,
        'items_count', r.items_count,
        'placed_at', r.placed_at
      ) order by r.placed_at desc), '[]'::jsonb) as items
      from (
        select
          s.id,
          s.order_number,
          s.status,
          s.fulfillment_type,
          s.grand_total,
          s.placed_at,
          coalesce(p.full_name, pc.full_name) as customer_name,
          (
            select count(*)::int
            from orders.order_items oi
            where oi.order_id = s.id
          ) as items_count
        from scoped s
        left join identity.profiles p on p.id = s.user_id
        left join orders.pos_customers pc on pc.id = s.pos_customer_id
        order by s.placed_at desc
        limit 6
      ) r
    )
    select jsonb_build_object(
      'today_orders', t.today_orders,
      'today_revenue', t.today_revenue,
      'yesterday_orders', t.yesterday_orders,
      'yesterday_revenue', t.yesterday_revenue,
      'average_order_value', case
        when t.today_orders = 0 then 0
        else round(t.today_revenue / t.today_orders, 2)
      end,
      'yesterday_average_order_value', case
        when t.yesterday_orders = 0 then 0
        else round(t.yesterday_revenue / t.yesterday_orders, 2)
      end,
      'active_orders', t.active_orders,
      'total_orders', t.total_orders,
      'week_orders', t.week_orders,
      'week_revenue', t.week_revenue,
      'prev_week_orders', t.prev_week_orders,
      'prev_week_revenue', t.prev_week_revenue,
      'month_orders', t.month_orders,
      'month_revenue', t.month_revenue,
      'monthly_revenue_target', v_target,
      'new_customers', case
        when v_can_read_customers and v_company_scope then (
          select count(*)::int
          from customer_profiles c
          where c.created_at >= v_month_start
        )
      end,
      'previous_new_customers', case
        when v_can_read_customers and v_company_scope then (
          select count(*)::int
          from customer_profiles c
          where c.created_at >= v_prev_month_start
            and c.created_at < v_month_start
        )
      end,
      'status_breakdown', sb.items,
      'sales_series', ss.items,
      'channels', ch.items,
      'top_products', tp.items,
      'recent_orders', ro.items
    )
    from totals t
    cross join status_breakdown sb
    cross join sales_series ss
    cross join channels ch
    cross join top_products tp
    cross join recent_orders ro
  );
end;
$fn$;

revoke all on function public.admin_dashboard_metrics() from public, anon;
grant execute on function public.admin_dashboard_metrics() to authenticated;

-- ---------------------------------------------------------------------------
-- 2. هدف الشهر: الإعداد الوحيد في اللوحة الذي يُكتب لا يُحسب
-- ---------------------------------------------------------------------------
create or replace function public.admin_set_revenue_target(p_value numeric)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_old jsonb;
  v_new jsonb;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('settings.write') then
    raise exception 'missing permission: settings.write' using errcode = '42501';
  end if;
  -- الهدف للشركة لا لفرع، فمن يدير فرعًا واحدًا لا يملك تغيير رقم يقارن به
  -- فرعٌ آخر نفسه.
  if not identity.manages_all_branches() then
    raise exception 'revenue target is company-wide' using errcode = '42501';
  end if;
  if p_value is not null and (p_value < 0 or p_value > 100000000) then
    raise exception 'revenue target out of range' using errcode = '22003';
  end if;

  select s.value
    into v_old
    from core.app_settings s
   where s.key = 'monthly_revenue_target';

  if p_value is null then
    delete from core.app_settings where key = 'monthly_revenue_target';
    v_new := null;
  else
    v_new := to_jsonb(round(p_value, 2));
    insert into core.app_settings (
      key, value, value_type, is_public, description, updated_at, updated_by
    )
    values (
      'monthly_revenue_target',
      v_new,
      'number',
      false,
      'Monthly revenue target shown on the admin dashboard.',
      now(),
      auth.uid()
    )
    on conflict (key) do update
      set value = excluded.value,
          value_type = excluded.value_type,
          is_public = excluded.is_public,
          description = excluded.description,
          updated_at = excluded.updated_at,
          updated_by = excluded.updated_by;
  end if;

  perform identity.audit(
    'core.revenue_target.update',
    'app_setting',
    null,
    v_old,
    v_new,
    null
  );

  return jsonb_build_object('monthly_revenue_target', v_new);
end;
$fn$;

revoke all on function public.admin_set_revenue_target(numeric) from public, anon;
grant execute on function public.admin_set_revenue_target(numeric) to authenticated;

comment on function public.admin_set_revenue_target(numeric) is
  'Owner-only monthly revenue target for the admin dashboard. Null clears it.';
