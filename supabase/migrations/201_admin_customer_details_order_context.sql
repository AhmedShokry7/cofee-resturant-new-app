-- 201_admin_customer_details_order_context.sql
--
-- بطاقة «طلبات العميل» في حوار العميل تعرض تاريخ الطلب واسم الفرع ونوع
-- الاستلام، وهي تقرأ الثلاثة من نفس الكائن الذي ترجعه admin_customer_details
-- (161). تلك الدالة كانت تُرجع id و branch_id و status و grand_total و placed_at
-- و items فقط: لا اسم فرع ولا نوع استلام. فالفرع كان يختفي من السطر، والتبديل
-- المحلي في الدارت كان يعرف delivery و pickup فقط، فيطبع الرمز الخام dine_in
-- لطلبات الفرع، و«استلام» لكل طلب تنقصه الخانة أصلًا.
--
-- الإصلاح هنا في مصدر البيانات لا في العرض: قوائم الطلبات الأخرى التي يقرأها
-- الأدمن (153 و158) تُرجع فرعًا باسمه ونوع استلام صريحًا، فكانت هذه البطاقة هي
-- الحالة الشاذة. يُضيف هذا الملف الحقلين بنفس الأسماء وبنفس الصلة core.branches
-- التي تستخدمها 158، فلا يحتاج العرض إلى عمود لم تُكتب له ترجمة في الطلبات.

create or replace function public.admin_customer_details(p_customer_id uuid)
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

  return (
    select jsonb_build_object(
      'profile', jsonb_build_object(
        'id', p.id,
        'full_name', p.full_name,
        'email', p.email,
        'phone', p.phone,
        'avatar_url', p.avatar_url,
        'language', p.language,
        'last_seen_at', p.last_seen_at,
        'created_at', p.created_at,
        'updated_at', p.updated_at,
        'is_vip', p.is_vip,
        'is_blacklisted', p.is_blacklisted,
        'admin_notes', p.admin_notes
      ),
      'addresses', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', a.id,
          'label', a.label,
          'details', a.details,
          'is_default', a.is_default
        ) order by a.created_at)
        from identity.customer_addresses a
        where a.user_id = p.id and a.archived_at is null
      ), '[]'::jsonb),
      'orders', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', o.id,
          'branch_id', o.branch_id,
          'branch_name_ar', b.name_ar,
          'branch_name_en', b.name_en,
          'fulfillment_type', o.fulfillment_type,
          'status', o.status,
          'grand_total', o.grand_total,
          'placed_at', o.placed_at,
          'items', coalesce((
            select jsonb_agg(jsonb_build_object(
              'product_name_ar', pr2.name_ar,
              'product_name_en', pr2.name_en,
              'quantity', oi.quantity,
              'unit_price', oi.unit_price,
              'line_total', oi.line_total
            ) order by oi.id)
            from orders.order_items oi
            left join catalog.products pr2 on pr2.id = oi.product_id
            where oi.order_id = o.id
          ), '[]'::jsonb)
        ) order by o.placed_at desc)
        from orders.orders o
        left join core.branches b on b.id = o.branch_id
        where o.user_id = p.id
      ), '[]'::jsonb),
      'subscriptions', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', recent.id,
          'status', case
            when recent.status = 'active'
              and recent.ends_at is not null
              and recent.ends_at <= now() then 'expired'
            else recent.status
          end,
          'starts_at', recent.starts_at,
          'ends_at', recent.ends_at,
          'cups_entitled', recent.cups_entitled,
          'cups_used', recent.cups_used,
          'cups_carried_over', recent.cups_carried_over,
          'cups_reserved', recent.cups_reserved,
          'auto_renew', recent.auto_renew,
          'plan', jsonb_build_object(
            'name_ar', pl.name_ar,
            'name_en', pl.name_en
          )
        ) order by recent.created_at desc)
        from (
          select sub.*
            from subscriptions.subscriptions sub
           where sub.user_id = p.id
           order by sub.created_at desc
           limit 20
        ) recent
        left join subscriptions.plans pl on pl.id = recent.plan_id
      ), '[]'::jsonb)
    )
    from identity.profiles p
    where p.id = p_customer_id
  );
end;
$fn$;

revoke all on function public.admin_customer_details(uuid) from public, anon;
grant execute on function public.admin_customer_details(uuid) to authenticated;
