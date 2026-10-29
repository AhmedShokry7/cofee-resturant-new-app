-- 211_admin_scope_and_write_guards.sql
--
-- خمس فجوات في صلاحيات قراءة/كتابة الأدمن، كلها وُجدت بقارنة الدالة بشقيقاتها
-- في نفس السلسلة، ولا واحد منها يغيّر دورة حياة أو تسعيرًا أو مخزونًا:
--
-- 1) public.admin_abandoned_carts() (139:50) يصفّي بالحالة وحدها:
--      `where c.status in ('active','abandoned')`
--    بينما 186 وضع `where identity.can_manage_branch(o.branch_id)` على
--    admin_orders() وadmin_payments() للسبب نفسه — شارة الفرع تقول ثلاثة والقائمة
--    تعرض أربعين. سلة العميل فيها عنوانه واسم منتجاته، فأي حامل `orders.read`
--    كان يقرأ سلال كل الفروع.
--
-- 2) public.admin_update_payment_status(uuid,text) (159) يكتب
--      `update orders.orders ... where id = p_order_id`
--    بلا نطاق فرع وبلا وجود الطلب: مدير فرع يستطيع قلب حالة الدفع في فرع غيره،
--    ورقم عشوائي يرد صمتًا لأن الدالة `returns void`. الشقيقات تفحص النطاق
--    بنفس النص: 200:184-187 (`order % not found` ثم `you do not manage this
--    branch`) و185:93-102 و079:46-47.
--
-- 3) public.admin_payments() (186:199) يسمّي العميل بـ`p.full_name` وحده، بينما
--    admin_orders() في نفس الملف (186:113) تستخدم
--    `coalesce(p.full_name, pc.full_name)` وتصل `orders.pos_customers` (186:159).
--    طلبات الحضور الشخصي التي تُنشأ من نقطة البيع ليس لها `identity.profiles`،
--    فتظهر في صفحة المدفوعات «عميل غير معروف» مع أن الطلب معروف الاسم.
--
-- 4) بطاقة العميل ودالة التعديل تقبلان أي `identity.profiles.id` (201، 141:101)
--    بينما قائمة العملاء (160:43-44) تستبعد حسابات الموظفين صراحةً:
--      `where not exists (select 1 from identity.staff_members sm where sm.user_id = p.id)`
--    اليوم لا تُسرّب البطاقة شيئًا: 188:104-116 يحذف صفّ profiles لأي مستخدم
--    صار موظفًا، و188:94 يقيد إنشاء صفّ لمستخدم موظف، فالفحص عند `where p.id =
--    p_customer_id` لا يجد صفًّا ويرد NULL (تحقّق حيّ: profiles_that_are_staff =
--    0). أي الحماية هنا دفاع زائد مقصود، لا إصلاح تسريب مُشاهَد: المنطق ينتقل
--    من «الصفّ غير موجود أصلًا» إلى «الدالة ترفض حساب الموظف بصريح النص»، فلا
--    يعود التسريب ممكنًا لو توسّع 188 أو أُعيد إنشاء الصفّ يومًا.
--
-- 5) public.admin_update_customer() يكتب `is_vip` و`is_blacklisted`
--    و`admin_notes` وهو محروس بـ`customers.read` (141:104). حيًّا لا يغيّر هذا
--    شيئًا: من يملك customers.read هما owner وmanager فقط، وكلاهما يملك
--    customers.write أيضًا (قراءة حيّة لمصفوفة الأدوار). الفجوة كامنة لا فعلية،
--    لأن 148:59-76 (admin_set_role_permission) يمنح أي حامل `admin.role.write`
--    أي صلاحية لأي دور بلا أي فحص، فلو أُعطِ دور `customers.read` وحدها صار
--    قادرًا على وسم العملاء بالحظر. الكتابة تُحرس بـcustomers.write، والقراءة
--    تبقى على customers.read.
--
-- قراءة حيّة قبل التطبيق: لا صفّ دور واحد يحمل فرعًا لأدوار owner أو manager
-- (نفس الاستعلام في tests/branch_scope_preflight.sql:33-45)، فالصفّ الوحيد في
-- identity.staff_roles هو للمالك بفرع NULL أي النطاق العام. لذلك لا يفقد أي
-- موظف حيّ صلاحية كان يمارسها؛ أثر التضييق على الأدوار المقيّدة بفرع وحدها
-- (cashier / branch_manager / staff / kitchen).
--
-- ما لم يغيّره هذا الملف: لا سياسة RLS، لا منح للدلو، لا أدوار، لا مصفوفة
-- انتقالات الحالة، ولا منع تعديل حالة الدفع على طلب مغلق (قرار owner منفصل).

-- ---------------------------------------------------------------------------
-- 1. سلال المهجورة: نفس نطاق 186.
-- ---------------------------------------------------------------------------
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
      'total', coalesce((select sum(ci.line_total) from orders.cart_items ci where ci.cart_id = c.id), 0),
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
        ) order by ci.created_at)
        from orders.cart_items ci
        left join catalog.products pr on pr.id = ci.product_id
        where ci.cart_id = c.id
      ), '[]'::jsonb)
    ) order by c.updated_at desc)
    from orders.carts c
    left join identity.profiles p on p.id = c.user_id
    left join core.branches b on b.id = c.branch_id
    where c.status in ('active', 'abandoned')
      -- كـadmin_orders() وadmin_payments() في 186: الفرع الذي يديره الموظف فقط.
      and identity.can_manage_branch(c.branch_id)
  ), '[]'::jsonb);
end;
$fn$;

comment on function public.admin_abandoned_carts() is
  'Active and abandoned carts of the branches this staff member manages.';

revoke all on function public.admin_abandoned_carts() from public, anon;
grant execute on function public.admin_abandoned_carts() to authenticated;

-- ---------------------------------------------------------------------------
-- 2. حالة الدفع: نطاق الفرع ووجود الطلب، بنص 200 نفسه.
-- ---------------------------------------------------------------------------
create or replace function public.admin_update_payment_status(
  p_order_id uuid,
  p_payment_status text
)
returns void
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_branch_id uuid;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('orders.status.update') then
    raise exception 'missing permission: orders.status.update' using errcode = '42501';
  end if;
  if p_payment_status not in ('unpaid','pending','paid','failed','refunded') then
    raise exception 'invalid payment status' using errcode = '22023';
  end if;

  select o.branch_id into v_branch_id
    from orders.orders o
   where o.id = p_order_id;
  if v_branch_id is null then
    raise exception 'order % not found', p_order_id using errcode = 'P0002';
  end if;
  if not identity.can_manage_branch(v_branch_id) then
    raise exception 'you do not manage this branch' using errcode = '42501';
  end if;

  update orders.orders
     set payment_status = p_payment_status,
         updated_at = now()
   where id = p_order_id;
end;
$fn$;

revoke all on function public.admin_update_payment_status(uuid, text) from public, anon;
grant execute on function public.admin_update_payment_status(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 3. المدفوعات: اسم عميل نقطة البيع كما يراه جدول الطلبات في 186.
-- ---------------------------------------------------------------------------
create or replace function public.admin_payments()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('payments.read') then
    raise exception 'missing permission: payments.read' using errcode = '42501';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', t.id,
      'order_id', t.order_id,
      'order_number', o.order_number,
      'customer_name', coalesce(p.full_name, pc.full_name),
      'provider', t.provider,
      'provider_reference', t.provider_reference,
      'method_id', t.method_id,
      'method_code', m.code,
      'method_name_ar', m.name_ar,
      'method_name_en', m.name_en,
      'amount', t.amount,
      'currency_code', t.currency_code,
      'status', t.status,
      'paid_at', t.paid_at,
      'refunded_at', t.refunded_at,
      'card_brand', t.card_brand,
      'card_last4', t.card_last4,
      'card_holder_name', t.card_holder_name,
      'verified_by_server', t.verified_by_server,
      'created_at', t.created_at
    ) order by t.created_at desc)
    from payments.payment_transactions t
    left join orders.orders o on o.id = t.order_id
    left join identity.profiles p on p.id = o.user_id
    left join orders.pos_customers pc on pc.id = o.pos_customer_id
    left join payments.payment_methods m on m.id = t.method_id
    where identity.can_manage_branch(o.branch_id)
  ), '[]'::jsonb);
end;
$fn$;

revoke all on function public.admin_payments() from public, anon;
grant execute on function public.admin_payments() to authenticated;

-- ---------------------------------------------------------------------------
-- 4. بطاقة العميل: حساب الموظف ليس عميلًا، وقيده هو قيد 160.
-- ---------------------------------------------------------------------------
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
  if exists (
    select 1 from identity.staff_members sm where sm.user_id = p_customer_id
  ) then
    raise exception 'not a customer account' using errcode = '42501';
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

-- ---------------------------------------------------------------------------
-- 5. تعديل العميل: الكتابة بصلاحية الكتابة، وحساب الموظف خارج النطاق.
-- ---------------------------------------------------------------------------
create or replace function public.admin_update_customer(
  p_customer_id uuid,
  p_is_vip boolean default null,
  p_is_blacklisted boolean default null,
  p_admin_notes text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('customers.write') then
    raise exception 'missing permission: customers.write' using errcode = '42501';
  end if;
  if exists (
    select 1 from identity.staff_members sm where sm.user_id = p_customer_id
  ) then
    raise exception 'not a customer account' using errcode = '42501';
  end if;

  update identity.profiles
     set is_vip = coalesce(p_is_vip, is_vip),
         is_blacklisted = coalesce(p_is_blacklisted, is_blacklisted),
         admin_notes = coalesce(p_admin_notes, admin_notes),
         updated_at = now()
   where id = p_customer_id;
end;
$fn$;

revoke all on function public.admin_update_customer(uuid, boolean, boolean, text) from public, anon;
grant execute on function public.admin_update_customer(uuid, boolean, boolean, text) to authenticated;

notify pgrst, 'reload schema';
