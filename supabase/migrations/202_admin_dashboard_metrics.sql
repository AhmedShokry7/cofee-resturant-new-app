-- 202_admin_dashboard_metrics.sql
--
-- لوحة التحكم كانت الشاشة الوحيدة التي لا صفحة لها: مسار «dashboard» يسقط في
-- AdminFeaturePlaceholder ويطبع «قريبًا»، بينما كل رقم تحتاجه اللوحة مكتوب فعلًا
-- في orders.orders. لا شيء هنا يُختَرع؛ التجميع يُقرأ من نفس الجدول الذي تقرأه
-- شاشة الطلبات.
--
-- صلاحيات ونطاق: لا توجد صلاحية تحليلات في identity.permissions (المجموعة هي
-- orders.read و customers.read وما إليهما)، فلو اختُرعت واحدة لأصبحت اللوحة
-- مغلقة أمام كل الأدوار الموجودة. لذا تُفتح الباب بـ orders.read وحدها، لأنه
-- نفس الباب الذي يفتح قائمة الطلبات. والنطاق هو نفس الشرط الذي تستخدمه
-- admin_orders منذ 183 و185: identity.can_manage_branch(o.branch_id). بلا هذا
-- الشرط يرى مدير فرعٍ واحد مجموع كل الفروع، فيعرضه على أنه مجموع فرعه.
--
-- الإيراد: مجموع grand_total للطلبات التي لم تُلغَ. الطلب الملغي لم يُسلَّم منه
-- شيء، وإدخاله في مجموع اليوم ينفخ رقمًا لا يستطيع الأدمن أن يفسّره. الطلب
-- الذي رُدّ ماله يبقى داخل المجموعة لأنه أُكمل ثم رُدّ بماله، وحذفه كان سيغيّر
-- رقم اليوم بلا أي كتابة في القاعدة.
--
-- اليوم: حدود اليوم بتوقيت Asia/Riyadh كما في 160، والمقارنة دائمًا بأمس نفس
-- الساعة، حتى لا يقارن رقم «اليوم حتى الآن» بيومٍ كامل.

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
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('orders.read') then
    raise exception 'missing permission: orders.read' using errcode = '42501';
  end if;

  return (
    with scoped as (
      select
        o.id,
        o.status,
        o.grand_total,
        o.placed_at
      from orders.orders o
      where identity.can_manage_branch(o.branch_id)
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
        from orders.orders o
        where identity.can_manage_branch(o.branch_id)
          and o.placed_at >= v_week_start
        group by o.status
      ) s
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
        join orders.orders o on o.id = oi.order_id
        where identity.can_manage_branch(o.branch_id)
          and o.placed_at >= v_week_start
          and o.status <> 'cancelled'
        group by oi.product_name_ar, oi.product_name_en
        order by sum(oi.quantity) desc, coalesce(sum(oi.line_total), 0) desc
        limit 5
      ) p
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
      'active_orders', t.active_orders,
      'total_orders', t.total_orders,
      'status_breakdown', sb.items,
      'top_products', tp.items
    )
    from totals t
    cross join status_breakdown sb
    cross join top_products tp
  );
end;
$fn$;

revoke all on function public.admin_dashboard_metrics() from public, anon;
grant execute on function public.admin_dashboard_metrics() to authenticated;
