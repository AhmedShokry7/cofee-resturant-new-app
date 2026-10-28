-- 204_admin_dashboard_setup_and_month_baseline.sql
--
-- اللوحة الجديدة تسأل القاعدة أربعة أسئلة لا تجيب عنها 203.
--
--   1. «كم كان الشهر الماضي؟» — البلاطة العلوية تطبع نسبة نمو، والنسبة لا
--      تُختلق من رقم واحد. 203 أرسلت الشهر الحالي فقط، فصار النقص يُخفى بشريط
--      بلا دلتا. هنا يُرسل prev_month_orders وprev_month_revenue من نفس
--      scoped وبنفس استثناء الملغى، فتُحسب النسبة من رقمي القاعدة.
--   2. «كم عميلًا عندك؟» — البطاقة تقول عدد العملاء لا عملاء الشهر، و203 كانت
--      تعرف الجديد منهم فقط. يُرسل total_customers مع customers_before_month
--      ليكون الرقم أمام مقارنته لا أمام تقدير.
--   3. «هل متجرك جاهز؟» — بطاقة خطوات البداية كانت أجمل ما في التصميم وأكذبها
--      لو بقيت: لا مصدر لها. صارت أربع خطوات تُقرأ من القاعدة نفسها، ولا يُعرض
--      من الخطوات إلا ما يملك القارئ فعله أصلًا. لا زر «تم» ولا حالة تُخزَّن:
--      الخطوة تُقاس لا تُعلَّم.
--   4. «ما صورة المنتج؟» — قائمة الأكثر مبيعًا فيها صورة 37 بكسل. الصورة ليست
--      في catalog.products بل في orders.order_items.image_snapshot، وهي لقطة
--      السطر التي لا تتحرك (011)، فاللوحة تعرض الصورة التي رآها العميل وقت
--      الشراء لا صورة اليوم التي قد تكون تغيّرت.
--
-- ما لم يتغيّر: النطاق هو identity.can_manage_branch(o.branch_id)، والإيراد
-- مجموع grand_total لغير الملغى، واليوم بحدود Asia/Riyadh، والباب orders.read.
-- عدّ العملاء وهدف الشهر يخصّان الشركة كلها فلا يُرجعان إلا لـ
-- manages_all_branches مع customers.read، وتعريف «العميل الجديد» باقٍ حرفيًا
-- كما في 160.
--
-- ما حُذف: status_breakdown. لم تعد اللوحة تعرض لوحة حالات، لأن حالة كل طلب
-- صارت عمودًا في جدول أحدث الطلبات؛ وإبقاء تجميع لا يقرأه أحد يكلّف القاعدة
-- عملًا بلا مقابل.

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
  v_can_write_settings boolean := identity.has_permission('settings.write');
  v_can_write_catalog boolean := identity.has_permission('catalog.product.write');
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
          where s.placed_at >= v_prev_month_start
            and s.placed_at < v_month_start
            and s.status <> 'cancelled'
        )::int as prev_month_orders,
        coalesce(sum(s.grand_total) filter (
          where s.placed_at >= v_prev_month_start
            and s.placed_at < v_month_start
            and s.status <> 'cancelled'
        ), 0)::numeric as prev_month_revenue,
        count(*) filter (
          where s.status not in ('completed', 'cancelled')
        )::int as active_orders,
        count(*)::int as total_orders
      from scoped s
    ),
    -- عدّ واحد للبروفايلات بدل أربعة: الأربعة كانت تمشي على نفس الصفوف
      -- أربع مرات لتجيب نفس السؤال بأربع نوافذ زمنية.
    customer_counts as (
      select
        count(*)::int as total_customers,
        count(*) filter (where c.created_at < v_month_start)::int
          as customers_before_month,
        count(*) filter (where c.created_at >= v_month_start)::int
          as new_customers,
        count(*) filter (
          where c.created_at >= v_prev_month_start
            and c.created_at < v_month_start
        )::int as previous_new_customers
      from customer_profiles c
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
        'image_url', p.image_url,
        'quantity', p.quantity,
        'revenue', p.revenue
      ) order by p.quantity desc, p.revenue desc), '[]'::jsonb) as items
      from (
        select
          oi.product_name_ar,
          oi.product_name_en,
          -- max لا arbitrary: منتج باعه طلبان بصورة قديمة وواحد بصورة جديدة
          -- يجب أن يعطي نفس السطر نفس الصورة في كل مرة تُفتح فيها اللوحة.
          max(oi.image_snapshot) as image_url,
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
    ),
    -- خطوة لا تُعرض لمن لا يملك فعلها: لا يُقال لكاشير «ارفع صورة فرعك» وهو
    -- لا يستطيع كتابتها، وإلا صار العدّاد «٢/٤» كاذبًا بالنسبة له لا ناقصًا.
    setup_steps as (
      select coalesce(jsonb_agg(jsonb_build_object(
        'key', s.key,
        'done', s.done
      ) order by s.step_order), '[]'::jsonb) as items
      from (
        select
          1 as step_order,
          'first_product' as key,
          exists (
            select 1 from catalog.products p
            where p.is_active and p.archived_at is null
          ) as done
        where v_can_write_catalog
        union all
        select
          2,
          'branch_image',
          exists (
            select 1 from core.branches b
            where identity.can_manage_branch(b.id)
              and nullif(btrim(coalesce(b.image_url, '')), '') is not null
          )
        where v_can_write_settings
        union all
        select 3, 'revenue_target', (v_target is not null)
        where v_can_write_settings and v_company_scope
        union all
        select
          4,
          'first_order',
          exists (
            select 1 from scoped o where o.status <> 'cancelled'
          )
      ) s
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
      'prev_month_orders', t.prev_month_orders,
      'prev_month_revenue', t.prev_month_revenue,
      'monthly_revenue_target', v_target,
      'total_customers', case
        when v_can_read_customers and v_company_scope then cc.total_customers
      end,
      'customers_before_month', case
        when v_can_read_customers and v_company_scope
        then cc.customers_before_month
      end,
      'new_customers', case
        when v_can_read_customers and v_company_scope then cc.new_customers
      end,
      'previous_new_customers', case
        when v_can_read_customers and v_company_scope
        then cc.previous_new_customers
      end,
      'sales_series', ss.items,
      'channels', ch.items,
      'top_products', tp.items,
      'recent_orders', ro.items,
      'setup_steps', st.items
    )
    from totals t
    cross join customer_counts cc
    cross join sales_series ss
    cross join channels ch
    cross join top_products tp
    cross join recent_orders ro
    cross join setup_steps st
  );
end;
$fn$;

revoke all on function public.admin_dashboard_metrics() from public, anon;
grant execute on function public.admin_dashboard_metrics() to authenticated;

comment on function public.admin_dashboard_metrics() is
  'Admin dashboard metrics for the reader''s managed branches: today, week, '
  'month and previous-month baselines, customer counts, 30-day sales series, '
  'channels, best sellers with their line image snapshot, recent orders, and '
  'the owner setup checklist.';
