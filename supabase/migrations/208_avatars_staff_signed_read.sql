-- 208_avatars_staff_signed_read.sql
--
-- يجعل صورة العميل قابلة للعرض في لوحة الأدمن دون تفكيك خصوصية دلو avatars.
--
-- ما الذي كان مكسورًا (فُحص على المشروع الحي لا من الملفات)
--   * `identity.profiles.avatar_url` تخزّن مسارًا داخل دلو `avatars` الخاص
--     (084_customer_profile_avatars.sql)، وتطبيق الأدمن يعرض الصورة فقط حين
--     يكون ما لديه رابط `http(s)` كاملًا — فيطبع Placeholder لكل العملاء.
--   * ترحيلة 152 بنت `public.admin_customer_avatar_url(uuid)` لتنادي
--     `storage.create_signed_url('avatars', path, 60)`. في هذا المشروع لا توجد
--     أي دالة توقيع داخل مخطط `storage`: `pg_proc` يعيد عشرين دالة للمخطط
--     (foldername، extension، can_insert_object، search_v2 ...) ولا واحدة منها
--     create_signed_url أو get_signed_url. فاستدعاء الوظيفة يرفع 42883 متى
--     وُجد مسار، ويعيد null لغير ذلك.
--   * لا نداء واحد للوظيفة في أي مكان: البحث في `lib/` و`test/` لتطبيق الأدمن
--     وتطبيق العميل ومختبرات `supabase/tests/` يعيد صفر نتائج.
--
-- القرار
--   التوقيع يحدث عند الطلب عبر واجهة التخزين نفسها (POST /object/sign/avatars)،
--   وهي تقيس سياسات RLS على دور العميل المسجَّل، فلا مفتاح خدمة في التطبيق
--   ولا رابط دائم في القاعدة. الباقي هنا سياسة قراءة فقط.
--
--   `drop policy` ثم `create policy` بنفس اسم السياسة الأصلي — لا سياسة جديدة
--   موازية — حتى يبقى اسم السياسة واحدًا في `pg_policy` كما لو كتبت هكذا منذ
--   البداية، ولا يُترك زوج من السياسات يوسع بعضه بعضًا بالخطأ لاحقًا.
--
-- ما لم يتغير
--   الدلو يبقى `public = false`، وسقف الملف 5 ميغابايت وأنواع jpeg/png/webp كما
--   هي، وسياسات insert/update/delete الخاصة بصاحب الصورة لا تُمسّ، فلا يملك
--   موظف الكتابة على دلو عميل ولا حذف صوره. ولا منح تنفيذ لأي دالة.

-- ---------------------------------------------------------------------------
-- 1. قراءة العميل من صاحب الصورة إلى من يدير العملاء.
--
--    الشرط الأصلي (ملف المالك = auth.uid()) يبقى كما هو ويُضاف إليه فرع واحد
--    لمالك صلاحية `customers.read`، وهي نفس الصلاحية التي تفتح `admin_customers`
--    و`admin_customer_details` و`admin_customer_avatar_url` من قبلها (080، 152).
--    `anon` غائب عن السياسة كما كان: بلا سياسة له يرفضه الدلو الخاص افتراضًا.
-- ---------------------------------------------------------------------------
drop policy if exists "avatars_select_own_folder" on storage.objects;

create policy "avatars_select_own_folder"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'avatars'
    and (
      (storage.foldername(name))[1] = (select auth.uid()::text)
      or identity.has_permission('customers.read')
    )
  );

-- ---------------------------------------------------------------------------
-- 2. إزالة الوظيفة الميتة.
--
--    ترحيلة 152 لم تعد مطلوبة بعد هذا الملف: الطلب على `/object/sign/avatars`
--    يوقّع قائمة مسارات في نداء واحد لصفحة كاملة، بينما الوظيفة توقّع عميلًا
--    واحدًا وتحتاج دالة غير موجودة. تُسقط حتى لا تبقى في `pg_proc` كطُعم يظن
--    لاحقٌ أنها تعمل.
-- ---------------------------------------------------------------------------
drop function if exists public.admin_customer_avatar_url(uuid);

notify pgrst, 'reload schema';
