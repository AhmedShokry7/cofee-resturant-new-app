# ربط التطبيق بالقاعدة — دليل التشغيل

المرحلة: **طبقة المصادقة فقط**. الكتالوج والسلة والطلبات ما زالت على البيانات الثابتة.

---

## 1. حالة الربط الآن

| الجزء | الحالة |
|---|---|
| `supabase_flutter` مثبَّت | ✅ `2.18.3` |
| عميل Supabase يُبنى من `--dart-define` | ✅ |
| `SupabaseAuthRepository` ينفّذ واجهة `AuthRepository` القائمة | ✅ |
| ربطه في `app_providers.dart` | ✅ سطر واحد |
| دخول/تسجيل/استعادة كلمة مرور حقيقية | ✅ |
| فحص ثابت + اختبارات | ✅ 0 أخطاء |

**لم يتغير أي شاشة ولا أي Cubit.** واجهة `AuthRepository` كانت موجودة أصلًا، فكان الربط تغييرًا في التنفيذ لا في الاستهلاك.

---

## 2. ⚠️ خطوة واحدة يدوية — لا بديل لها بـSQL

> **Supabase Dashboard → Settings → API → Exposed schemas**
>
> أضف:
> ```
> identity, core, catalog, orders, inventory, payments, loyalty, marketing, engagement
> ```
> واترك `public` و`graphql_public`. **لا تضف `ai`** — مقيَّد عمدًا.

**جُرّب هذا وتأكد أن الاستعلام يعيد `0` صف ثم `1`:**

```sql
-- بعد الإعداد، هذا يجب أن يُرجع 10 صفوف
select count(*) from catalog.categories;
```

**لماذا لا يمكن عملها من SQL:** الإعداد يُحفظ في `pgrst.db_schemas` على مستوى المنصّة نفسها،
لا في قاعدة البيانات. جرّبنا `ALTER ROLE authenticator SET pgrst.db_schemas …` — يُحفظ فعلًا،
لكن PostgREST المُدار لا يقرأه، ويستمر بإرجاع `PGRST205`.

**قبل هذه الخطوة، التطبيق يتصل بالقاعدة بنجاح لكن لا يرى أي جدول.**

---

## 3. التشغيل

التشغيل العادي من زر Debug أو من CLI يستخدم إعدادات Supabase العامة للمشروع تلقائيًا، فلا يحتاج تمرير أي قيم.
على Windows، يمكنك اختياريًا مزامنة الإعدادات من `.env` قبل التشغيل:

```powershell
.\tools\run_flutter.ps1
```

ولإنشاء APK:

```powershell
.\tools\build_apk.ps1
```

يمكن أيضًا اختيار إعداد التشغيل **new_cofee (Supabase)** من VS Code؛ يُحدَّث ملف الإعداد المحلي تلقائيًا قبل كل تشغيل.
الأدوات تقرأ من `.env` فقط `SUPABASE_URL` و`SUPABASE_PUBLISHABLE_KEY`، وتضعهما في `.env.flutter.json` المتجاهل بواسطة Git. لا تمرر `SUPABASE_SERVICE_ROLE_KEY` أو `SUPABASE_ACCESS_TOKEN` إلى Flutter.

إذا غُيّر `.env`، تُحدَّث القيم تلقائيًا في التشغيل أو البناء التالي.

التشغيل المباشر بأوامر Flutter لا يقرأ `.env` وحده، لكنه يستخدم إعدادات المشروع العامة الافتراضية المعرّفة في التطبيق.

```bash
# المسار المباشر، عند الحاجة فقط:
flutter run --dart-define-from-file=.env.flutter.json
```

**أو بدون مفاتيح:** التطبيق يعمل كالمعتاد على البيانات الثابتة المحلية. لا ينهار.

> **لا تمرّر `SUPABASE_SERVICE_ROLE_KEY` أبدًا.** يتجاوز كل RLS.

---

## 4. الاختبارات

```bash
# الافتراضي: 12 ناجح، 9 متخطاة (لا يحتاج إنترنت)
flutter test

# معCredentials — يثبت الاتصال والدخول الحقيقي
flutter test test/integration/supabase_integration_test.dart ^
  --dart-define=SUPABASE_URL=... ^
  --dart-define=SUPABASE_PUBLISHABLE_KEY=... ^
  --dart-define=TEST_USER_EMAIL=... ^
  --dart-define=TEST_USER_PASSWORD=...

# بعد خطوة الـDashboard فقط
flutter test test/integration/supabase_integration_test.dart ^
  ... ^
  --dart-define=SCHEMAS_EXPOSED=true
```

---

## 5. ما يُثبته كل مستوى

| المستوى | يثبت |
|---|---|
| بلا مفاتيح | التطبيق سليم، والتحليل نظيف، والبيانات الثابتة تعمل |
| + credentials | الاتصال ✅، الدخول الحقيقي ✅، `currentUser()` يعيد الجلسة الحقيقية ✅ (كان `null` دائمًا قبل) |
| + `SCHEMAS_EXPOSED` | الكتالوج يُقرأ، البحث العربي عبر RPC، عزل RLS فعلي من العميل |

---

## 6. ما تغيّر في السلوك — والأهم

| قبل | الآن |
|---|---|
| `signIn` يقبل أي بريد/كلمة مرور | **يتحقق من الخادم ويرفض الخطأ** |
| `currentUser()` يرجع `null` دائمًا | **يرجع المستخدم الحقيقي** |
| استعادة كلمة المرور بلا رمز | **تتطلب جلسة استرجاع من رابط البريد**، وإلا ترفض |
| الدخول الاجتماعي يعيد `AuthUser(id: "google")` | **يرمي استثناءً صريحًا** — لا يختلق هوية |
| الهاتف يقبل أي رمز | **مؤجل — يرمي استثناءً صريحًا** |

> **ملاحظة أمنية:** الشاشة تنقل من «نسيت كلمة المرور» إلى «تعيين كلمة المرور» مباشرة.
> مع Supabase لن ينجح التعيين **إلا بعد فتح رابط البريد**، والترميز الآن يرفض ذلك برسالة واضحة
> بدل أن يبدو كأنه يعمل. **الربط بـdeep link** يحتاج قرارًا منفصلًا.

---

## 7. الخطوة التالية

1. نفّذ خطوة الـ`Exposed schemas`.
2. أعد تشغيل الاختبار مع `SCHEMAS_EXPOSED=true`.
3. بعدها: `SupabaseProductRepository` خلف واجهة الكتالوج — نفس النمط بالضبط.
