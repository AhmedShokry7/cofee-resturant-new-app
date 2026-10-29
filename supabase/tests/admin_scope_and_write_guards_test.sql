-- admin_scope_and_write_guards_test.sql
-- سلوك خمس دوال أدمن بعد 211_admin_scope_and_write_guards.sql.
--
-- STATUS: EXECUTED AND PASSED on 2026-10-29 against the live project
-- webzzasosevzymftgszn, inside the rolled-back transaction below, after 211 was
-- applied by name. The report row came back as:
--   verdict = 'reached the end: no assertion failed', own_branch_write = 'paid',
--   global_write = 'refunded', untouched_order = 'pending',
--   vip_by_write_holder = true, blacklist_by_read_only = false
--
-- CONTROL RUN (the same file, the same day, BEFORE 211 was applied): it died at
--   FAIL 1a: a branch-1 cashier sees 3 carts, expected only the branch-1 cart
-- That is the leak, measured rather than asserted, and the reason this file is
-- worth keeping: it fails against the old definitions and passes against the new
-- ones. Section 6 re-runs the same shape after the patch and reaches the end.
--
-- الحالة: يُجرَّب كل نداء بدور حقيقي وبتوكيل JWT حقيقي، فالأطراف المراد
-- إثباتها (نطاق الفرع، صلاحية الكتابة، رفض حساب الموظف) تُختبر ولا يُكتفى
-- بقراءة نصّها من pg_policies كما فعل avatars_staff_signed_read_test.sql.
--
-- PREREQUISITES: 004/011/013/021/123/137 (identity، مصفوفة الأدوار، orders،
-- payments)، 141 (customers.write)، 160/161/201 (بطاقة العميل)، 176/186
-- (pos_customers ونطاق الفروع)، 188 (فصل حساب الموظف عن صف العميل)، و211.
-- على قاعدة بلا 211 يفشل هذا الملف عند FAIL 1a: كاشير الفرع الأول يرى سلّتين
-- لا سلّة، وهو بالضبط التسريب الذي يسدّه الملف.
--
-- ما لا يغطيه هذا الملف: صلاحيات الكتابة المباشرة على الجداول (لا سياسات RLS
-- مسّها 211)، ولا دورة حياة الحالة (211 لا يغيّر الانتقالات ولا يتحقق منها).

begin;

-- ---------------------------------------------------------------------------
-- البيانات: فرعان، عميلان بسلّة لكل منهما، وأربعة موظفين بنطاقات مختلفة،
-- وثلاثة طلبات: واحد في كل فرع وثالث من نقطة البيع بلا حساب عميل.
-- ---------------------------------------------------------------------------
insert into core.branches (id, brand_id, code, name_ar, name_en, address, is_active, settings)
values
  ('5d100000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000001', 'SG-B1', 'فرع الحرس 1', 'Guard Branch 1', 'addr1', true, '{}'::jsonb),
  ('5d200000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000001', 'SG-B2', 'فرع الحرس 2', 'Guard Branch 2', 'addr2', true, '{}'::jsonb);

insert into auth.users (id, email)
values
  ('5f100000-0000-4000-8000-000000000001', 'sg-cust-1@test.local'),
  ('5f100000-0000-4000-8000-000000000002', 'sg-cust-2@test.local'),
  ('5e100000-0000-4000-8000-000000000001', 'sg-cashier-1@test.local'),
  ('5e100000-0000-4000-8000-000000000002', 'sg-cashier-2@test.local'),
  ('5e100000-0000-4000-8000-000000000003', 'sg-branch-mgr@test.local'),
  ('5e100000-0000-4000-8000-000000000004', 'sg-manager@test.local'),
  ('5e100000-0000-4000-8000-000000000005', 'sg-target-staff@test.local');

-- trigger على auth.users يكتب profiles لكلّ حساب، و188 يحذف صفّ من صار موظفًا.
insert into identity.profiles (id, full_name, email, phone)
values
  ('5f100000-0000-4000-8000-000000000001', 'SG Cust One', 'sg-cust-1@test.local', '0500000001'),
  ('5f100000-0000-4000-8000-000000000002', 'SG Cust Two', 'sg-cust-2@test.local', '0500000002')
on conflict (id) do nothing;

update identity.profiles
   set full_name = case id
         when '5f100000-0000-4000-8000-000000000001'::uuid then 'SG Cust One'
         else 'SG Cust Two' end
 where id in ('5f100000-0000-4000-8000-000000000001'::uuid,
              '5f100000-0000-4000-8000-000000000002'::uuid);

insert into identity.staff_members (id, user_id, status, full_name, email)
values
  ('61100000-0000-4000-8000-000000000001', '5e100000-0000-4000-8000-000000000001', 'active', 'SG Cashier One', 'sg-cashier-1@test.local'),
  ('61100000-0000-4000-8000-000000000002', '5e100000-0000-4000-8000-000000000002', 'active', 'SG Cashier Two', 'sg-cashier-2@test.local'),
  ('61100000-0000-4000-8000-000000000003', '5e100000-0000-4000-8000-000000000003', 'active', 'SG Branch Manager', 'sg-branch-mgr@test.local'),
  ('61100000-0000-4000-8000-000000000004', '5e100000-0000-4000-8000-000000000004', 'active', 'SG Manager', 'sg-manager@test.local'),
  ('61100000-0000-4000-8000-000000000005', '5e100000-0000-4000-8000-000000000005', 'active', 'SG Target Staff', 'sg-target-staff@test.local');

-- PK هو (staff_id, role_id): صف دور واحد يحمل فرعًا واحدًا، فالنطاق المتعدد
-- يحتاج دورين مختلفين. branch_id = NULL يعني النطاق العام (018).
insert into identity.staff_roles (staff_id, role_id, branch_id)
select '61100000-0000-4000-8000-000000000001', r.id, '5d100000-0000-4000-8000-000000000001'::uuid
from identity.roles r where r.code = 'cashier';

insert into identity.staff_roles (staff_id, role_id, branch_id)
select '61100000-0000-4000-8000-000000000002', r.id, '5d200000-0000-4000-8000-000000000002'::uuid
from identity.roles r where r.code = 'cashier';

insert into identity.staff_roles (staff_id, role_id, branch_id)
select '61100000-0000-4000-8000-000000000003', r.id, '5d200000-0000-4000-8000-000000000002'::uuid
from identity.roles r where r.code = 'branch_manager';

insert into identity.staff_roles (staff_id, role_id, branch_id)
select '61100000-0000-4000-8000-000000000004', r.id, null
from identity.roles r where r.code = 'manager';

insert into identity.staff_roles (staff_id, role_id, branch_id)
select '61100000-0000-4000-8000-000000000005', r.id, '5d100000-0000-4000-8000-000000000001'::uuid
from identity.roles r where r.code = 'cashier';

-- الدور المركّب الذي لا exists في 137: قراءة عملاء بلا كتابة. هو بالضبط ما يفتح
-- 148:59-76 الباب فيه، وبه تُختبر القاعدة الجديدة في 211 لا الافتراض القديم.
insert into identity.role_permissions (role_id, permission_id)
select r.id, p.id from identity.roles r, identity.permissions p
 where r.code = 'branch_manager' and p.code = 'customers.read';

insert into orders.carts (id, user_id, branch_id, status)
values
  ('71100000-0000-4000-8000-000000000001', '5f100000-0000-4000-8000-000000000001', '5d100000-0000-4000-8000-000000000001', 'active'),
  ('71100000-0000-4000-8000-000000000002', '5f100000-0000-4000-8000-000000000002', '5d200000-0000-4000-8000-000000000002', 'abandoned');

-- created_by يشير إلى auth.users لا إلى identity.staff_members.
insert into orders.pos_customers (id, full_name, created_by)
values ('72200000-0000-4000-8000-000000000001', 'SG Walk In', '5e100000-0000-4000-8000-000000000004');

insert into orders.orders (
  id, order_number, user_id, pos_customer_id, branch_id, fulfillment_type, status,
  payment_status, subtotal, discount_total, delivery_fee, tax_total, grand_total,
  currency_code, customer_note, placed_at, loyalty_points_earned, idempotency_key,
  order_source
)
values
  ('8b100000-0000-4000-8000-000000000001', 'SG-1',
   '5f100000-0000-4000-8000-000000000001', null, '5d100000-0000-4000-8000-000000000001',
   'dine_in', 'confirmed', 'unpaid', 100.00, 0.00, 0.00, 0.00, 100.00, 'SAR', 'sg1',
   '2026-01-01T10:00:00Z', 0, 'sg-test-1', 'online'),
  ('8b200000-0000-4000-8000-000000000002', 'SG-2',
   '5f100000-0000-4000-8000-000000000002', null, '5d200000-0000-4000-8000-000000000002',
   -- 'delivery' كان يفشل بـ ck_orders_delivery_needs_zone: طلب الاستلام أبيضّ
   -- من قيود الطلبات ولا يغيّر شيئًا في أطراف الاختبار.
   'pickup', 'confirmed', 'unpaid', 80.00, 0.00, 0.00, 0.00, 80.00, 'SAR', 'sg2',
   '2026-01-01T11:00:00Z', 0, 'sg-test-2', 'online'),
  ('8b300000-0000-4000-8000-000000000003', 'SG-3',
   null, '72200000-0000-4000-8000-000000000001', '5d200000-0000-4000-8000-000000000002',
   'dine_in', 'completed', 'pending', 45.00, 0.00, 0.00, 0.00, 45.00, 'SAR', 'sg3',
   '2026-01-01T12:00:00Z', 0, 'sg-test-3', 'pos');

insert into payments.payment_transactions (
  id, order_id, provider, method_id, amount, currency_code, status,
  paid_at, verified_by_server, created_at
)
values
  ('9c100000-0000-4000-8000-000000000001', '8b100000-0000-4000-8000-000000000001',
   'pos_counter', (select id from payments.payment_methods where code = 'cash'),
   100.00, 'SAR', 'captured', '2026-01-01T10:00:00Z', true, '2026-01-01T10:00:00Z'),
  ('9c200000-0000-4000-8000-000000000002', '8b200000-0000-4000-8000-000000000002',
   'pos_counter', (select id from payments.payment_methods where code = 'cash'),
   80.00, 'SAR', 'captured', '2026-01-01T11:00:00Z', true, '2026-01-01T11:00:00Z'),
  ('9c300000-0000-4000-8000-000000000003', '8b300000-0000-4000-8000-000000000003',
   'pos_counter', (select id from payments.payment_methods where code = 'cash'),
   45.00, 'SAR', 'captured', '2026-01-01T12:00:00Z', true, '2026-01-01T12:00:00Z');

set local role authenticated;

-- ---------------------------------------------------------------------------
-- 1. كاشير الفرع الأول: سلّته وحدها، ومدفوعاته وحدها.
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"5e100000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v jsonb;
begin
  v := public.admin_abandoned_carts();
  if jsonb_array_length(v) <> 1 then
    raise exception 'FAIL 1a: a branch-1 cashier sees % carts, expected only the branch-1 cart',
      jsonb_array_length(v);
  end if;
  if (v -> 0 ->> 'branch_id')::uuid <> '5d100000-0000-4000-8000-000000000001' then
    raise exception 'FAIL 1a: the cashier list is not the own-branch cart (%)', v -> 0 ->> 'branch_id';
  end if;
  -- اسم العميل وبريده كانا يعبران حدّ الفرع مع السلّة.
  if (v -> 0 ->> 'customer_name') <> 'SG Cust One' then
    raise exception 'FAIL 1a: the surviving cart is not branch 1''s (%)', v -> 0 ->> 'customer_name';
  end if;
end $$;

do $$
declare v jsonb;
begin
  v := public.admin_payments();
  if jsonb_array_length(v) <> 1 or (v -> 0 ->> 'order_number') <> 'SG-1' then
    raise exception 'FAIL 1b: the cashier payment list left its branch (%)', coalesce(v::text, 'null');
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 2. كاشير الفرع الأول مع طلبات الفرع الآخر: لا قلب حالة دفع، ولا رقم وهمي بصمت.
-- ---------------------------------------------------------------------------
do $$
begin
  perform public.admin_update_payment_status(
    '8b200000-0000-4000-8000-000000000002', 'paid');
  raise exception 'FAIL 2a: a branch-1 cashier flipped the payment status of a branch-2 order';
exception
  when others then
    if sqlstate <> '42501' then raise; end if;
    if sqlerrm not like '%you do not manage this branch%' then raise; end if;
end $$;

do $$
begin
  perform public.admin_update_payment_status(
    '00000000-0000-0000-0000-000000000000', 'paid');
  raise exception 'FAIL 2b: an unknown order id was accepted in silence';
exception
  when others then
    if sqlstate <> 'P0002' then raise; end if;
    if sqlerrm not like '%not found%' then raise; end if;
end $$;

-- حالة غير معروفة ترفض قبل فحص الفرع: ترتيب 159 لم يمسّه التوسيع.
do $$
begin
  perform public.admin_update_payment_status(
    '8b200000-0000-4000-8000-000000000002', 'settled');
  raise exception 'FAIL 2c: an unknown payment status was accepted';
exception
  when others then
    if sqlstate <> '22023' then raise; end if;
    if sqlerrm not like '%invalid payment status%' then raise; end if;
end $$;

-- طلب فرع نفسه: الكتابة المسموحة ما زالت تعمل، بلا تضييق زائد.
do $$
begin
  perform public.admin_update_payment_status(
    '8b100000-0000-4000-8000-000000000001', 'paid');
exception
  when others then
    raise exception 'FAIL 2d: the own-branch payment status write was refused (%: %)', sqlstate, sqlerrm;
end $$;

-- ---------------------------------------------------------------------------
-- 3. مدير عام (نطاق كل الفروع): كل القوائم كاملة، واسم عميل نقطة البيع ظاهر.
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"5e100000-0000-4000-8000-000000000004","role":"authenticated","aud":"authenticated"}', true);

-- النطاق العام يرى سلّتي الفرعين معًا، مضافًا إليهما ما كان في القاعدة الحيّة
-- أصلًا، فالعدد المطلق لا يصلح هنا: المحكي هو وجود السلّتين المُعدّتين.
do $$
declare v jsonb; c int;
begin
  v := public.admin_abandoned_carts();
  select count(*) into c from jsonb_array_elements(v) e
   where e ->> 'id' in ('71100000-0000-4000-8000-000000000001',
                        '71100000-0000-4000-8000-000000000002');
  if c <> 2 then
    raise exception 'FAIL 3a: global staff sees % of the two fixture carts', c;
  end if;
end $$;

do $$
declare v jsonb; c int;
begin
  v := public.admin_payments();
  select count(*) into c from jsonb_array_elements(v) e
   where e ->> 'order_number' in ('SG-1','SG-2','SG-3');
  if c <> 3 then
    raise exception 'FAIL 3b: global staff sees % of the three fixture tenders', c;
  end if;
  if not exists (
    select 1 from jsonb_array_elements(v) e
     where e ->> 'order_number' = 'SG-3'
       and e ->> 'customer_name' = 'SG Walk In') then
    raise exception 'FAIL 3b: the pos order still reports no customer name: %',
      (select jsonb_agg(e -> 'customer_name') from jsonb_array_elements(v) e
        where e ->> 'order_number' = 'SG-3');
  end if;
end $$;

-- البطاقة: عميل حقيقي يمرّ، وحساب موظف يرفض بصريح النص.
do $$
declare v jsonb;
begin
  v := public.admin_customer_details('5f100000-0000-4000-8000-000000000001');
  if v is null or (v -> 'profile' ->> 'full_name') <> 'SG Cust One' then
    raise exception 'FAIL 3c: a real customer card stopped working';
  end if;
end $$;

do $$
begin
  perform public.admin_customer_details('5e100000-0000-4000-8000-000000000005');
  raise exception 'FAIL 3d: a staff account opened a customer card';
exception
  when others then
    if sqlstate <> '42501' then raise; end if;
    if sqlerrm not like '%not a customer account%' then raise; end if;
end $$;

-- الكتابة بمالك الصلاحية تمرّ، وعلى حساب موظف ترفض قبل أن تكتب.
do $$
begin
  perform public.admin_update_customer('5f100000-0000-4000-8000-000000000001', p_is_vip := true);
exception
  when others then
    raise exception 'FAIL 3e: customers.write was refused by its own holder (%: %)', sqlstate, sqlerrm;
end $$;

do $$
begin
  perform public.admin_update_customer('5e100000-0000-4000-8000-000000000005', p_is_blacklisted := true);
  raise exception 'FAIL 3f: a staff account was blacklisted through the customer write';
exception
  when others then
    if sqlstate <> '42501' then raise; end if;
    if sqlerrm not like '%not a customer account%' then raise; end if;
end $$;

-- الطلب الأجنبي للمدير العام مسموح: النطاق العام لا يُعاقَب.
do $$
begin
  perform public.admin_update_payment_status('8b200000-0000-4000-8000-000000000002', 'refunded');
exception
  when others then
    raise exception 'FAIL 3g: global staff could not update the payment status (%: %)', sqlstate, sqlerrm;
end $$;

-- ---------------------------------------------------------------------------
-- 4. مدير فرع بصلاحية قراءة عملاء فقط: يقرأ، ولا يكتب ولا يرى المدفوعات.
--    هذا هو الدور الذي يصنعه 148 اليوم بلا أي فحص.
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"5e100000-0000-4000-8000-000000000003","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v jsonb;
begin
  v := public.admin_customer_details('5f100000-0000-4000-8000-000000000002');
  if v is null or (v -> 'profile' ->> 'full_name') <> 'SG Cust Two' then
    raise exception 'FAIL 4a: customers.read stopped being enough to read a card';
  end if;
end $$;

do $$
begin
  perform public.admin_update_customer('5f100000-0000-4000-8000-000000000002', p_is_blacklisted := true);
  raise exception 'FAIL 4b: customers.read alone still grants the customer write';
exception
  when others then
    if sqlstate <> '42501' then raise; end if;
    if sqlerrm not like '%missing permission: customers.write%' then raise; end if;
end $$;

do $$
begin
  perform public.admin_payments();
  raise exception 'FAIL 4c: a role without payments.read read the payments directory';
exception
  when others then
    if sqlstate <> '42501' then raise; end if;
    if sqlerrm not like '%missing permission: payments.read%' then raise; end if;
end $$;

do $$
declare v jsonb;
begin
  v := public.admin_abandoned_carts();
  if jsonb_array_length(v) <> 1 or (v -> 0 ->> 'branch_id')::uuid <> '5d200000-0000-4000-8000-000000000002' then
    raise exception 'FAIL 4d: a branch-2 manager sees the carts of another branch (%)', coalesce(v::text, 'null');
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 5. anon ما زال مرفوضًا: 211 أعاد نفس revoke/grant فلم يفتح بابًا.
-- ---------------------------------------------------------------------------
set local role anon;

do $$
begin
  perform public.admin_update_payment_status('8b100000-0000-4000-8000-000000000001', 'paid');
  raise exception 'FAIL 5a: anon executed the payment status write';
exception
  when others then
    if sqlstate <> '42501' then raise; end if;
end $$;

do $$
begin
  perform public.admin_abandoned_carts();
  raise exception 'FAIL 5b: anon executed the carts list';
exception
  when others then
    if sqlstate <> '42501' then raise; end if;
end $$;

reset role;

-- ---------------------------------------------------------------------------
-- 6. صحة التعريف بعد كل هذا: خمس دوال، كلها definer بسند مجرّد، ولا واحدة
--    تنفّذ لـanon. 211 أعاد نفس revoke/grant في كل قسم، فلم يغيّر السند.
--    (proconfig مخزّن حرفيًا search_path=""، فالمقارنة النصية لا مطابقة العنصر.)
-- ---------------------------------------------------------------------------
do $$
declare v int;
begin
  select count(*) into v
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname in ('admin_abandoned_carts','admin_update_payment_status','admin_payments',
                       'admin_customer_details','admin_update_customer');
  if v <> 5 then
    raise exception 'FAIL 6a: expected the five functions, found %', v;
  end if;
  select count(*) into v
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname in ('admin_abandoned_carts','admin_update_payment_status','admin_payments',
                       'admin_customer_details','admin_update_customer')
     and p.prosecdef
     and coalesce(array_to_string(p.proconfig, '|'), '') like '%search_path=%';
  if v <> 5 then
    raise exception 'FAIL 6b: only % of the five keep security definer with a pinned search_path', v;
  end if;
  if exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and p.proname in ('admin_abandoned_carts','admin_update_payment_status','admin_payments',
                         'admin_customer_details','admin_update_customer')
       and has_function_privilege('anon', p.oid, 'execute')) then
    raise exception 'FAIL 6c: anon can execute one of the five';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- التقرير: ما كُتب فعلًا بعد كل الرفض والقبول، لا ما افترضناه.
-- ---------------------------------------------------------------------------
select
  'reached the end: no assertion failed' as verdict,
  (select payment_status from orders.orders where id = '8b100000-0000-4000-8000-000000000001') as own_branch_write,
  (select payment_status from orders.orders where id = '8b200000-0000-4000-8000-000000000002') as global_write,
  (select payment_status from orders.orders where id = '8b300000-0000-4000-8000-000000000003') as untouched_order,
  (select is_vip from identity.profiles where id = '5f100000-0000-4000-8000-000000000001') as vip_by_write_holder,
  (select is_blacklisted from identity.profiles where id = '5f100000-0000-4000-8000-000000000002') as blacklist_by_read_only;

rollback;
