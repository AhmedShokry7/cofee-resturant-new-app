# مواصفات قاعدة بيانات — تطبيق طلبات الكافيه/المطعم
## وثيقة مُلزِمة (Constitution) للتنفيذ على Supabase / PostgreSQL

**الحالة:** مُعتمدة للتنفيذ. هذه الوثيقة هي **مصدر الحقيقة الوحيد**. أي بنية قاعدة أو قرار مخالف لها يُعد خطأً.
**النطاق:** قاعدة Supabase/PostgreSQL جديدة لتطبيق كافيه/مطعم — علامة تجارية واحدة، **متعددة الفروع**، تطبيق للعملاء + لوحة إدارة مستقلة أمنيًا.
**ترتيب العمل:** قاعدة البيانات والأمان أولًا ← واجهات التطبيق في مرحلة لاحقة منفصلة تمامًا.
**مستند сопровождения التنفيذي:** `OPENCODE_SUPABASE_EXECUTION_PROMPT.md`.

---

## 0. كيف تُقرأ هذه الوثيقة

| القسم |nature | الحالة |
|---|---|---|
| §1 القواعد الملزمة | قواعد تنفيذ لا تُخترق | 🟢 مُلزم |
| §2 القرارات المعتمدة | قرارات حُسمت. **لا تُ reopen بلا موافقة صريحة** | 🟢 مُلزم |
| §3..§6 المعمارية والمبادئ | | 🟢 مُلزم |
| §7 قاموس البيانات | الحقول والأنواع والمفاتيح لكل جدول | 🟢 مُلزم |
| §8 تدفقات الأعمال | حدود RPC | 🟢 مُلزم |
| §9 معايير RLS/RBAC | شروط قبول إلزامية | 🟢 مُلزم |
| §10 خريطة الشاشات ← الجداول | **تتبعability: لا شاشة بلا جدول** | 🟢 مُلزم |
| §11 migrations | الترتيب والقيود | 🟢 مُلزم |
| §12 اختبارات القبول | 30 اختبارًا | 🟢 مُلزم |
| §13 التسليم | المخرجات المطلوبة | 🟢 مُلزم |

---

## 1. القواعد الملزمة (لا يجوز تجاوزها)

1. نفّذ على **مشروع Supabase الجديد الذي يحدده صاحب المشروع في هذه الجلسة فقط**. لا تستخدم أو تعدّل أي مشروع قديم.
2. **لا تستنتج هدف الاتصال من ملفات `.env` قديمة.** تحقّق من هوية المشروع واعرض **Project Ref** قبل أي كتابة.
3. افحص القاعدة **قراءة فقط أولًا**؛ لا تفترض أنها فارغة لمجرد أنها جديدة.
4. اعرض خطة التنفيذ والمخاطر **وانتظر موافقة صريحة** قبل تطبيق أي migration أو تغيير.
5. **لا تضع `service_role` أو الأسرار في Flutter أو Git أو السجلات.** لا تطبع مفاتيح أو كلمات مرور في التقارير.
6. **لا تستخدم `DROP ... CASCADE` أو reset أو حذفًا شاملًا كاختصار.**
7. استخدم migrations محفوظة في المشروع وقابلة للمراجعة، **ولا تغيّر تاريخ migrations مطبَّقة دون موافقة موثقة**.
8. **لا تعدّل واجهات Flutter في هذه المهمة.**
9. **لا تدّعِ نجاح اختبار أو نشر migration ما لم يحدث فعلًا وتوجد نتيجة موثقة.**
10. إذا ظهر تعارض أو اتصال بقاعدة غير متوقعة، **توقّف واعرضه** بدل اتخاذ قرار تخميني.
11. **لا تُنشئ جدولًا خارج قاموس البيانات في §7** دون إضافته أولاً لهذه الوثيقة ومراجعته.
12. **لا تُنهِ العمل بإعلان «قاعدة البيانات جاهزة» قبل اجتياز كل اختبارات §12.**

---

## 2. القرارات المعتمدة (LOCKED)

> هذه القرارات حُسمت بناءً على مراجعة المتطلبات وفحص الكود. **مُثبَّتة في هذه الوثيقة.**

### 2.1 القرار D1 — تعدد الفروع ✅ مُعتمد

- علامة تجارية **واحدة**، **عدّة فروع** من اليوم الأول.
- الفروع مرئية في لوحة الإدارة (إدارة كاملة: بيانات، أسعار، توافر، مخزون).
- **العميل يختار الفرع عند الطلب.** الفرع المختار يحدد: الأسعار المعروضة، التوافر، المخزون، ومنطق الاستلام.
- نموذج البيانات: **كل صف تجاري يحمل `branch_id`**. لا يوجد «فرع افتراضي ضمني» في أي مسار كتابة.
- رأس الطلب يجمّد الفرع؛ تغيير فرع المنتج لاحقًا **لا يمس** الطلب القديم.
- العزل بين الفروع مضمون بـRLS على مستوى الموظف + `branch_id` على مستوى الصف.

### 2.2 القرار D2 — فصل هوية الإدارة عن العملاء ✅ مُعتمد

**الآلية المعتمدة:**

| البُعد | العملاء | الإدارة والموظفون |
|---|---|---|
| مساحة المصادقة | `auth.users` | `auth.users` (نفس المساحة) |
| جدول الربط | `identity.profiles` | `identity.staff_members` |
| بريد مكرر | — | **غير مسموح** — بريد واحد = حساب واحد واحد فقط |
| الدور | لا يوجد | من `identity.roles` عبر `identity.staff_roles` |
| فرض الصلاحيات | RLS بالملكية | RLS بالملكية **+** RLS بالأدوار والصلاحيات |

**الأساس التقني:** بريد إلكتروني فريد عالميًا في `auth.users`، لذلك **لا يمكن وجود حسابين مستقلين بنفس البريد**. هذا قيد تقني موثّق، لا نقص في التصميم.

**الأثر المطلوب (must-have):**
- الموظف **is not** عميل. `profiles` و`staff_members` منفصلان تمامًا.
- **تعزيز الأدوار:** حساب في `staff_members` يُمنع عليه استخدام مسارات العملاء (المفضلة، السلة، loyalty كعميل).
- حساب عميل **لا يستطيع** أن يصبح موظفًا. لا自助 registration في `staff_members`.
- **تسجيل الدخول للموظف يمر عبر بوابة `/admin`** ويتطلب فحصًا إضافيًا: `staff_members.status = 'active'` + `branch_scope` صالح + الأدوار موجودة. الموظف المعطَّل أو بلا فرع مصرّح به **يُرفض** حتى لو كان بريده صحيحًا.
- invitation فقط: `staff_members` يُنشأ بحالة `invited`، ويُفعَّل بقبول دعوة عبر Edge Function موثوقة.

**بديل مسموح (يحتاج موافقة صريحة):** مشروع Supabase منفصل للإدارة. مُستثنى من D2 الحالي.

### 2.3 القرار D3 — كل ميزة لها شاشة في التطبيق داخل النطاق ✅ مُعتمد

- **لا يوجد مؤجَّل من الميزات التي لها شاشة.** انظر §10 لتتبعability الكاملة.
- المؤجَّل **محدود حرفيًا** بما هو في §10.4 ولا غير.

### 2.4 القرار D4 — نموذج اللغة الثنائية ✅ مُعتمد

| المحتوى | الأسلوب |
|---|---|
| أسماء/وصف المنتجات والفئات والباقات والبنرات والكوبونات والأسئلة | **أعمدة مفصولة**: `name_ar`, `name_en`, `description_ar`, `description_en` |
| نصوص قانونية ومحتوى تحريري طويل | `content_ar`, `content_en` |
| قيم مرجعية (enum/حالة) | **أعمدة `*_label`** في جداول المراجع، أو `label_ar`/`label_en` |
| **لا `JSONB` للترجمة.** | السبب: الترجمة تُقرأ في كل استعلام كتالوج، وتُفلتر وتُرتَّب — الفهرسة والوضوح أهم من المرونة. |

> Languages قابلة للتوسعة لاحقًا بإضافة أعمدة + migration. مقبول لأن الكتالوج أصغر حجمًا في النموذذج المعياري.

### 2.5 القرار D5 — أنواع المبالغ والتوقيت ✅ مُعتمد

| النوع | الاستخدام |
|---|---|
| `numeric(12,2)` | كل المبالغ (سعر، خصم، رسوم، ضريبة، رصيد) |
| `timestamptz` | كل الأوقات |
| `int` | الكميات والنقاط والأعداد |
| `text` | الأسماء والرموز |

- **ممنوع `float`/`double` للمال.** (`double` في `ProductModel.price` في الكود — سبب إضافي للتحويل.)
- **العملة الافتراضية: `SAR` (ريال سعودي).** قابلة للتغيير عبر `core.app_settings`. (مُستندة إلى محتوى التطبيق الحالي: EGP في `loyalty_page.dart:150` وعناوين سعودية في `addresses_list.dart`، مقابل `$` في `formatters.dart:4` — التعارض يُحل هنا.)
- **العملة تُخزَّن دائمًا في جدول واحدة فقط** (`core.brands.currency_code`) ولا تُكرَّر.

### 2.6 القرار D6 — الفهرسة والبحث ✅ مُعتمد

- `pg_trgm` + GIN للبحث التقريبي العربي/الإنجليزي.
- **تطبيع النص العربي في الدالة** (`unaccent`-like مخصص): توحيد `أإآ←ا`, `ة←ه`, `ى←ي`, `ؤ←و`, `ئ←ي`, حذف التشكيل والتطويل، توحيد الأرقام العربية `٠-٩←0-9`، ضغط المسافات.
- **مصدر الـtriggers:** نفس منطق `normalizeText` الموجود في `lib/features/assistant/data/assistant_language.dart:14-48` — **يجب نقله حرفيًا** إلى الدالة `core.normalize_ar()`.
- البحث عبر **RPC واحد**: `catalog.search_products(...)`.
- **لا View للبحث.** السبب: البحث يحتاج ranking + تطبيع + alias lookup — استعلام مركّب، لا Projectable read.
- `catalog.search_vector` Maintenance عبر **Trigger** على `products` و`categories` — لا إعادة حساب مجدولة.
- **حدود:** pagination إلزامي، `page_size` بحد أقصى 100.

### 2.7 القرار D7 — الهوية والمعرفات ✅ مُعتمد

- كل مفتاح أساسي **uuid** مع `gen_random_uuid()`.
- **الروابط بالفهرس لا بالنص.** يمنع كسر `product_variants.dart:62-68` عند تغيير اسم فئة.
- لا حقول `display_name` مكررة تُستخدم كمفاتيح.

### 2.8 القرار D8 — مفتاح مخزون المتغيّرات ✅ مُعتمد

`inventory.branch_stock` يحتاج مفتاحًا يميّز المنتج层面 من المنتج + المتغيّر (حجم كبير + سكر أقل).
عمود `option_value_id` nullable **لا يصلح** كجزء من `PRIMARY KEY` في Postgres (NULL ≠ NULL).

**الحل المعتمد:** عمود **`variant_key uuid NOT NULL DEFAULT '00000000-0000-0000-0000-000000000000'::uuid`** يُستخدم في الـPK. القيم `000...0` = المنتج بلا متغيّر.

```sql
PRIMARY KEY (branch_id, product_id, variant_key)
```

### 2.9 القرار D9 — رصيد الولاء: مصدر حقيقة واحد ✅ مُعتمد

كان التصميم الأول يضع رصيد النقاط في مكانين:
- `identity.profiles.loyalty_points`
- `loyalty.loyalty_accounts.points_balance`

**الحل المعتمد:**
1. **حُذف `profiles.loyalty_points`.** لا يتكرر الرقم في أي مكان.
2. المصدر الوحيد للحقيقة = `loyalty.loyalty_accounts.points_balance` (دفتر حسابات حقيقي).
3. للقراءة السريعة، يُنشأ **`identity.user_points`** كـView يعرض `profiles` + الرصيد.
4. كل تغيير في الرصيد **يبدأ من `loyalty.loyalty_transactions`** (سطر مسجَّل)، ويحدّث الرصيد داخل نفس المعاملة.

**السبب:** التكرار يجعل رقمين مختلفين في شاشتين. ودفتر الحركات هو ما يمنع الصرف المزدوج عند التزامن.

### 2.10 القرار D10 — `public` تبقى فارغة ✅ مُعتمد

لا جداول ولا دوال في `public` إطلاقًا — مطابقةً تامة لـ§4.

---

## 3. هدف النظام والنطاق

### 3.1 ما ينشئه هذا النظام

- علامة تجارية واحدة، **عدّة فروع**.
- تطبيق للعملاء + **لوحة إدارة** بصلاحيات متباعدة.
- **فصل أمني حقيقي** بين حسابات العملاء وحسابات الإدارة.
- تسجيل عميل بالبريد وكلمة المرور + تأكيد بريد + استعادة كلمة مرور.
- الكتالوج كاملًا: تصنيفات، منتجات، صور، أحجام، متغيرات، إضافات، مرادفات بحث.
- **أسعار وتوافر على مستوى الفرع** مع الاحتفاظ بالسعر الأساسي.
- سلة وطلبات وبنود طلبات مع **لقطة سعرية واسمية وخيارات وقت الطلب**.
- **اختيار الفرع من العميل** عند الطلب (استلام من الفرع أو توصيل).
- مناطق توصيل وربطها بالفروع، ورسوم توصيل **محسوبة على الخادم**.
- **مخزون لكل فرع + سجل حركات مخزون**.
- دفع نقدي + إطار آمن لحالة الدفع الإلكتروني (بلا بوابة حقيقية في v1).
- بانرات + كوبونات + باقات + توصيات.
- **ولاء ونقاط ومكافآت.**
- **تقييمات منتجات.**
- **سجل إشعارات داخل التطبيق** + تفضيلات + رموز أجهزة.
- **مساعدة ذكاء اصطناعي محلية** (بيانات معرفة المنتج + مرادفات البحث).
- أدوار وصلاحيات + سجل تدقيق.

### 3.2 قائمة صريحة لما لا يفعله

- ❌ لا تسجيل/دخول بالهاتف (الشاشات موجودة لكنها محاكاة حاليًا — تُؤجل).
- ❌ لا بوابة دفع حقيقية ولا webhooks.
- ❌ لا Push عبر مزود خارجي (FCM/OneSignal). جدول الإشعارات جاهز للربط لاحقًا.
- ❌ لا ذكاء اصطناعي **خارجي** (لا LLM، لا API خارجي).
- ❌ لا تعدد علامات تجارية / SaaS متعدد المستأجرين.
- ❌ لا Page Builder / تخزين واجهات كـJSON.
- ❌ لا تخزين بيانات الطقس. (يُجلب من Open-Meteo وقت العرض.)

---

## 4. معماريات المخططات (Schemas)

> **مبدأ التصميم:** كل نطاق عمل في `schema` مستقل. هذا يجعل التصلاح والصلاحيات والنسخ الاحتياطي أوضح، ويمنع تسريب جداول إدارية إلى PostgREST.

| Schema | النطاق | PostgREST | الجداول |
|---|---|---|---|
| `identity` | الملفات الشخصية، العناوين، الموظفون، الأدوار، التدقيق | ✅ مكشوف | 9 |
| `core` | العلامة، الفروع، المناطق، الإعدادات، المحتوى التحريري | ✅ مكشوف | 8 |
| `catalog` | التصنيفات، المنتجات، الخيارات، الباقات، الأسعار بالفرع | ✅ مكشوف | 13 |
| `orders` | السلة، الطلبات، البنود، التاريخ | ✅ مكشوف (قراءة مملوكة) | 9 |
| `inventory` | المخزون وحركاته | ✅ مكشوف (قراءة إدارية فقط) | 2 |
| `payments` | طرق الدفع، المحاولات، المعاملات | ✅ مكشوف (قراءة إدارية فقط) | 3 |
| `loyalty` | الحساب، الحركات، القواعد، المكافآت | ✅ مكشوف (قراءة مملوكة) | 4 |
| `marketing` | البانرات، الكوبونات، الاستهلاك | ✅ مكشوف | 4 |
| `engagement` | التقييمات، المفضلة، الإشعارات، التفضيلات، الأجهزة | ✅ مكشوف | 5 |
| `ai` | معرفة المنتج للمساعد المحلي + المعرفة العامة | ❌ **غير مكشوف** | 2 |

**`public`:** تبقى فارغة من الجداول. تُستخدم فقط لـ`extensions` و`pgtle`/`postgis` إن لزم.
> **قاعدة إلزامية (SPEC §8.3):** كل schema في القائمة أعلاهmarked ✅ يجب إضافتها إلى **API → Settings → Exposed schemas** في لوحة Supabase، أو التطبيق لن يصل إليها. **هذا إعداد Dashboard ولا يُطبَّق بـmigration** — يجب توثيقه كخطوة يدوية.

### 4.1 اعتماد `SECURITY DEFINER`

الدوال التي تحتاج `SECURITY DEFINER` **محدودة صراحةً ولا غير** (§8). كل دالة:
- `SET search_path = ''` ثم参考资料 بأسماء كاملة (`public.core.branches`) — **لا تعتمد على search_path**.
- تفحص هوية المتصل عبر `auth.uid()`.
- تفحص الدور/الصلاحية عبر `identity.has_permission()`.
- **لا تستخدم `SECURITY DEFINER` ل читание عادية.** overuse هو أشهر خطأ أمني في Supabase.

---

## 5. مبادئ البيانات

1. PostgreSQL هو مصدر البيانات الأساسي الوحيد. **لا مصدر ثانٍ للبيانات indulgence** في v1.
2. PK وFK و`UNIQUE` و`CHECK` و`NOT NULL` على كل عمود لا معنى ل-null له.
3. `timestamptz` للتوقيتات، `numeric(12,2)` للمبالغ.
4. **العلاقات بأvarchar/فهارس، لا بنصوص عرض.**
5. **لا تعتمد على إخفاء عناصر الواجهة.** الصلاحيات في القاعدة.
6. **العميل لا يحدد:** دوره الإداري، سعر المنتج المرجعي، الإجمالي النهائي، حالة نجاح الدفع، حركات المخزون، سعر بند الطلب.
7. التحقق من الأسعار والخصومات ورسوم التوصيل والإجماليات **على الخادم من بيانات موثوقة**.
8. **لقطة الاسم والسعر والخيارات داخل بنود الطلب** — لا تُقرأ من الكتالوج أبدًا عند العرض.
9. عمليات الطلب والمخزون **ذرية ومقاومة للتكرار**.
10. **لا حذف مادي** للطلبات والمدفوعات وحركات المخزون. الحذف = `archived_at` / `voided_at`.
11. **لا تخزّن بيانات البطاقات الحساسة** — فقط مراجع المزود وآخر4 والب-holder.
12. **نصوص حرة (CHECK) بدل CHECK على قيم غير مقيدة:** استخدم **جداول مرجعية** عند إضافة قيمة فعلية.

---

## 6. الهوية والمصادقة

### 6.1 العملاء
- بيانات الملف **منفصلة** عن بيانات الاعتماد (`identity.profiles` ≠ `auth.users`).
- تسجيل بالبريد وكلمة المرور + تأكيد بريد + استعادة كلمة مرور.
- سياسات العميل **بالملكية الموثوقة من `auth.uid()`** — لا يُثق بـ`user_id` يرسله التطبيق.
- العميل يقرأ/يكتب بياناته فقط.

### 6.2 الإدارة والموظفون
راجع **§2.2 (D2)** — هذا هو التنفيذ.

### 6.3 تسجيل الهاتف
مؤجل. عند التنفيذ: **Edge Function موثوقة + مزود SMS**. لا يُنفَّذ في v1.

---

## 7. قاموس البيانات

> تنبيه: `PK` = مفتاح أساسي، `FK` = مفتاح أجنبي، `UQ` = فريد، `CK` = تحقق، `IX` = فهرس، `?` = nullable.
> `RLS: enabled` لكل الجداول بلا استثناء. سياسة كل جدول موصوفة.

---

### 7.1 `identity`

#### `identity.profiles`
ملف العميل. الغرض: بيانات العرض linked بـ`auth.users`.
```
id            uuid  PK  → auth.users(id) ON DELETE CASCADE
full_name     text
email         text      (denormalized للعرض فقط؛ مصدر الحقيقة auth.users)
phone         text ?
avatar_url    text ?
branch_id          uuid ?  FK → core.branches(id)    -- فرع العميل المفضل (افتراضي فقط)
language          text  NOT NULL DEFAULT 'ar'  CK in ('ar','en')
last_seen_at      timestamptz ?
created_at        timestamptz NOT NULL DEFAULT now()
updated_at        timestamptz NOT NULL DEFAULT now()
```
`IX (email)` · `RLS: enabled` — `SELECT` بملكية، `UPDATE` بملكية (لا `role`، ولا `loyalty_points` — انظر **D9**).

#### `identity.customer_addresses`
```
id            uuid PK
user_id       uuid NOT NULL FK → identity.profiles(id) ON DELETE CASCADE
label         text NOT NULL            -- 'home','work'
details       text NOT NULL            -- نص العنوان
latitude      numeric(9,6) ?
longitude     numeric(9,6) ?
is_default    boolean NOT NULL DEFAULT false
archived_at   timestamptz ?
created_at    timestamptz NOT NULL DEFAULT now()
```
`IX (user_id) WHERE archived_at IS NULL` · `RLS: enabled` — ملكية كاملة للعميل.

#### `identity.staff_members`
```
id            uuid PK
user_id       uuid NOT NULL UQ FK → auth.users(id) ON DELETE RESTRICT
status        text NOT NULL DEFAULT 'invited'  CK in ('invited','active','suspended')
invited_by    uuid ? FK → identity.staff_members(id)
invited_at    timestamptz NOT NULL DEFAULT now()
accepted_at   timestamptz ?
suspended_at  timestamptz ?
full_name     text NOT NULL
email         text NOT NULL
created_at    timestamptz NOT NULL DEFAULT now()
```
`UQ (email)` · **لا trigger للإدراج التلقائي.** `RLS: enabled` — قراءة لـ`active` فقط، كتابة إدارية فقط عبر RPC.

#### `identity.roles`
```
id            uuid PK
code          text NOT NULL UQ  CK ~ '^[a-z_]+$'
name_ar       text NOT NULL
name_en       text NOT NULL
description   text ?
is_system     boolean NOT NULL DEFAULT false   -- الأدوار الأساسية لا تُحذف
created_at    timestamptz NOT NULL DEFAULT now()
```
الأدوار الأساسية التأسيسية: `owner`, `manager`, `branch_manager`, `staff`, `cashier`.

#### `identity.permissions`
```
id            uuid PK
code          text NOT NULL UQ  CK ~ '^[a-z_]+\.[a-z_]+$'
name_ar       text NOT NULL
description   text ?
```
نمط: `<مجال>.<فعل>` — `catalog.product.write`, `orders.order.cancel`, `inventory.stock.adjust`.

#### `identity.role_permissions`
```
role_id       uuid NOT NULL FK → identity.roles(id) ON DELETE CASCADE
permission_id uuid NOT NULL FK → identity.permissions(id) ON DELETE CASCADE
PK (role_id, permission_id)
```

#### `identity.staff_roles`
```
staff_id      uuid NOT NULL FK → identity.staff_members(id) ON DELETE CASCADE
role_id       uuid NOT NULL FK → identity.roles(id) ON DELETE RESTRICT
branch_id     uuid ? FK → core.branches(id)   -- NULL = كل الفروع
PK (staff_id, role_id, branch_id)
```
> **ملاحظة:** `branch_id` في PK مع NULL لا يعمل في Postgres (NULL ≠ NULL). الحل المعتمد: `uq_staff_role_scope` على `(staff_id, role_id, COALESCE(branch_id, '00000000-0000-0000-0000-000000000000'::uuid))` — index expression فريد. **مطلوب تنفيذه صراحة.**

#### `identity.audit_log`
```
id            bigserial PK
actor_user_id uuid ?  FK → auth.users(id)     -- NULL = نظام
actor_role    text ?
action        text NOT NULL                  -- 'price.update','order.cancel',...
entity_type   text NOT NULL                  -- 'product','order','stock',...
entity_id     uuid ?
branch_id     uuid ? FK → core.branches(id)
old_values    jsonb ?
new_values    jsonb ?
ip            inet ?
created_at    timestamptz NOT NULL DEFAULT now()
```
`IX (entity_type, entity_id, created_at DESC)` · `IX (actor_user_id, created_at DESC)` · `RLS: enabled` — قراءة بـ`audit.read` فقط. **كتابة عبر trigger أو SECURITY DEFINER — لا سكربت عميل.**

---

### 7.2 `core`

#### `core.brands`
```
id            uuid PK
name_ar       text NOT NULL
name_en       text NOT NULL
logo_url      text ?
currency_code text NOT NULL DEFAULT 'SAR' CK ~ '^[A-Z]{3}$'
tax_included  boolean NOT NULL DEFAULT true
tax_rate      numeric(5,2) NOT NULL DEFAULT 0  CK >= 0
support_email text ?
support_phone text ?
created_at    timestamptz NOT NULL DEFAULT now()
updated_at    timestamptz NOT NULL DEFAULT now()
```
**جدول واحد فقط (علامة تجارية واحدة)** — متعددة العلامات مؤجلة.

#### `core.branches`
```
id            uuid PK
brand_id      uuid NOT NULL FK → core.brands(id) ON DELETE RESTRICT
code          text NOT NULL UQ CK ~ '^[A-Z0-9_-]+$'
name_ar       text NOT NULL
name_en       text NOT NULL
address       text NOT NULL
latitude      numeric(9,6) ?
longitude     numeric(9,6) ?
phone         text ?
is_active     boolean NOT NULL DEFAULT true
opens_at      time ?
closes_at     time ?
settings      jsonb NOT NULL DEFAULT '{}'::jsonb   -- bag للإعدادات النادرة
created_at    timestamptz NOT NULL DEFAULT now()
updated_at    timestamptz NOT NULL DEFAULT now()
```
`IX (brand_id) WHERE is_active` · `RLS: enabled` — `SELECT` **عام** (العميل يحتاج قائمة الفروع لاختيار فرع). `INSERT/UPDATE/DELETE` إدارية فقط.
> **قرار تصميمي:** `is_active=false` يعني الفرع لا يظهر في قائمة اختيار العميل، لكنه يبقى مرئيًا في الطلبات التاريخية.

#### `core.delivery_zones`
```
id            uuid PK
brand_id      uuid NOT NULL FK → core.brands(id) ON DELETE CASCADE
name_ar       text NOT NULL
name_en       text NOT NULL
delivery_fee  numeric(12,2) NOT NULL DEFAULT 0 CK >= 0
min_order_amount numeric(12,2) NOT NULL DEFAULT 0 CK >= 0
estimated_minutes int ?  CK > 0
polygon       jsonb ?   -- GeoJSON
is_active     boolean NOT NULL DEFAULT true
created_at    timestamptz NOT NULL DEFAULT now()
updated_at    timestamptz NOT NULL DEFAULT now()
```
`RLS: enabled` — قراءة عامة نشطة.

#### `core.delivery_zone_branches`
```
zone_id       uuid NOT NULL FK → core.delivery_zones(id) ON DELETE CASCADE
branch_id     uuid NOT NULL FK → core.branches(id) ON DELETE CASCADE
PK (zone_id, branch_id)
```
`IX (branch_id)` — يُستخدم للتحقق «هل هذا الفرع يخدم هذه المنطقة».

#### `core.app_settings`
```
key           text PK  CK ~ '^[a-z_]+$'
value         jsonb NOT NULL
value_type    text NOT NULL CK in ('string','number','boolean','json')
is_public     boolean NOT NULL DEFAULT false   -- عام = يقرأه التطبيق
description   text ?
updated_at    timestamptz NOT NULL DEFAULT now()
updated_by    uuid ? FK → auth.users(id)
```
قيود مقترحة (تُوثَّق لا تُفرض): `delivery_fee_default`, `cart_max_items`, `tax_enabled`, `app_version_min`, `support_whatsapp`.
`RLS: enabled` — قراءة `is_public = true` من `anon`؛ تعديل إداري.

#### `core.legal_documents`
```
id            uuid PK
slug          text NOT NULL UQ   -- 'privacy','terms'
title_ar      text NOT NULL
title_en      text NOT NULL
content_ar    text NOT NULL
content_en    text NOT NULL
version       text NOT NULL DEFAULT '1.0'
is_published  boolean NOT NULL DEFAULT false
published_at  timestamptz ?
created_at    timestamptz NOT NULL DEFAULT now()
```
`RLS: enabled` — قراءة `is_published`. (يغطي `privacy_policy_text.dart`.)

#### `core.faq_items`
```
id            uuid PK
category      text NOT NULL DEFAULT 'general'
question_ar   text NOT NULL
question_en   text NOT NULL
answer_ar     text NOT NULL
answer_en     text NOT NULL
sort_order    int NOT NULL DEFAULT 0
is_active     boolean NOT NULL DEFAULT true
created_at    timestamptz NOT NULL DEFAULT now()
```
`IX (sort_order)` · قراءة عامة.

#### `core.onboarding_slides`
```
id            uuid PK
image_url     text NOT NULL
title_ar      text NOT NULL
title_en      text NOT NULL
body_ar       text NOT NULL
body_en       text NOT NULL
sort_order    int NOT NULL
is_active     boolean NOT NULL DEFAULT true
```
`RLS: enabled` قراءة عامة.

---

### 7.3 `catalog`

#### `catalog.categories`
```
id            uuid PK
parent_id     uuid ? FK → catalog.categories(id) ON DELETE SET NULL   -- دعم الفئات الفرعية
name_ar       text NOT NULL
name_en       text NOT NULL
description_ar text
description_en text
image_url     text ?
icon_key      text ?   -- مفتاح أصل محلي (لا تُخزَّن IconData)
sort_order    int NOT NULL DEFAULT 0
is_active     boolean NOT NULL DEFAULT true
created_at    timestamptz NOT NULL DEFAULT now()
updated_at    timestamptz NOT NULL DEFAULT now()
```
`IX (parent_id, sort_order)` · `IX (sort_order) WHERE is_active` · قراءة عامة.
> **حل لمشكلة `CategoryModel`:** التطبيق اليوم يستخدم `label` كنص مفتاح. عمود `id` يحلّ ذلك. حقل `icon_key` يستبدل `IconData`.

#### `catalog.products`
```
id                uuid PK
category_id       uuid NOT NULL FK → catalog.categories(id) ON DELETE RESTRICT
sku               text NOT NULL UQ
slug              text NOT NULL UQ
name_ar           text NOT NULL
name_en           text NOT NULL
description_ar    text
description_en    text
base_price        numeric(12,2) NOT NULL CK >= 0     -- السعر الأساسي (مرجعي)
compare_at_price  numeric(12,2) ?  CK > 0            -- السعر قبل الخصم
image_url         text ?                              -- الصورة الرئيسية
is_active         boolean NOT NULL DEFAULT true       -- التوفر/النشر
is_featured       boolean NOT NULL DEFAULT false      -- "الأكثر مبيعًا" اليدوي
prep_minutes      int ?  CK >= 0
is_calorie_tracked boolean NOT NULL DEFAULT false
allergens         text[] NOT NULL DEFAULT '{}'
sort_order        int NOT NULL DEFAULT 0
archived_at       timestamptz ?
created_at        timestamptz NOT NULL DEFAULT now()
updated_at        timestamptz NOT NULL DEFAULT now()
```
`IX (category_id) WHERE is_active AND archived_at IS NULL` · `IX (sort_order)` · `IX GIN(search_vector)` (مُدار بـtrigger).
`RLS: enabled` قراءة عامة لـ`is_active AND archived_at IS NULL`؛ الكتابة إدارية.
> **ملاحظة `is_featured`:** «الأكثر مبيعًا» المحسوب يأتي من §8 `catalog.get_best_sellers()` على طلبات مكتملة. `is_featured` للاستثنائtls التحريري فقط. **ليس بديلًا عن الحساب.**

#### `catalog.product_images`
```
id            uuid PK
product_id    uuid NOT NULL FK → catalog.products(id) ON DELETE CASCADE
image_url     text NOT NULL
alt_ar        text
alt_en        text
sort_order    int NOT NULL DEFAULT 0
is_primary    boolean NOT NULL DEFAULT false
created_at    timestamptz NOT NULL DEFAULT now()
```
`UQ` جزئي: `(product_id) WHERE is_primary` — مفتاح جزئي فريد يضمن صورة رئيسية واحدة.

#### `catalog.option_groups`
```
id            uuid PK
code          text NOT NULL UQ     -- 'size','sugar','extras'
name_ar       text NOT NULL
name_en       text NOT NULL
description_ar text
description_en text
selection_type text NOT NULL CK in ('single','multiple')
min_select    int NOT NULL DEFAULT 0 CK >= 0
max_select    int ?  CK > 0
is_required   boolean NOT NULL DEFAULT false
sort_order    int NOT NULL DEFAULT 0
is_active     boolean NOT NULL DEFAULT true
created_at    timestamptz NOT NULL DEFAULT now()
```
`CK` متقاطع: `CHECK (max_select IS NULL OR max_select >= min_select)` · `CHECK (selection_type = 'single' OR max_select = 1)`.
> **هذا هو الفارق الجوهري عن `product_variants.dart`.** الأحجام، السكر، الإضافات كلها **مجموعات خيارات** واحدة — قابلة للإعداد من لوحة الإدارة بدل enum مُجمَّد.

#### `catalog.option_values`
```
id             uuid PK
group_id       uuid NOT NULL FK → catalog.option_groups(id) ON DELETE CASCADE
code           text NOT NULL
name_ar        text NOT NULL
name_en        text NOT NULL
price_delta    numeric(12,2) NOT NULL DEFAULT 0
short_label    text ?          -- 'S','M','L'
sort_order     int NOT NULL DEFAULT 0
is_active      boolean NOT NULL DEFAULT true
is_default     boolean NOT NULL DEFAULT false
UNIQUE (group_id, code)
```
`price_delta` يُـ**يُضاف** للسعر الأساسي. (يكافئ `DrinkSize.priceDelta` في `product_variants.dart:15` لكن قابل للإدارة.)

#### `catalog.product_option_groups`
```
product_id     uuid NOT NULL FK → catalog.products(id) ON DELETE CASCADE
group_id       uuid NOT NULL FK → catalog.option_groups(id) ON DELETE RESTRICT
sort_order     int NOT NULL DEFAULT 0
is_required    boolean NOT NULL DEFAULT false   -- تجاوز افتراضي المجموعة
PRIMARY KEY (product_id, group_id)
```
> **هذا يحل "الأحجام للمنتجات التي تحتاجها فقط".** الربط صريح لا استنتاج من `Set<String> sizedCategories`.

#### `catalog.product_aliases`
**جديد — يحفظ وظيفة البحث العربي التي اليوم تعتمد على `AssistantPhrases.productSynonyms`.**
```
id            uuid PK
product_id    uuid NOT NULL FK → catalog.products(id) ON DELETE CASCADE
alias         text NOT NULL      -- 'لاتيه','كابتشينو','لاتتي'
locale        text NOT NULL DEFAULT 'ar' CK in ('ar','en')
alias_normalized text NOT NULL     -- ناتج core.normalize_ar(alias)
created_at    timestamptz NOT NULL DEFAULT now()
UNIQUE (product_id, alias_normalized)
IX GIN (alias_normalized gin_trgm_ops)
```

#### `catalog.category_aliases`
```
id            uuid PK
category_id   uuid NOT NULL FK → catalog.categories(id) ON DELETE CASCADE
alias         text NOT NULL
locale        text NOT NULL DEFAULT 'ar' CK in ('ar','en')
alias_normalized text NOT NULL
UNIQUE (category_id, alias_normalized)
IX GIN (alias_normalized gin_trgm_ops)
```

#### `catalog.bundles`
```
id            uuid PK
name_ar       text NOT NULL
name_en       text NOT NULL
description_ar text
description_en text
image_url     text ?
bundle_price  numeric(12,2) ?  CK > 0    -- NULL = sum components
sort_order    int NOT NULL DEFAULT 0
is_active     boolean NOT NULL DEFAULT true
starts_at     timestamptz ?
ends_at       timestamptz ?
created_at    timestamptz NOT NULL DEFAULT now()
updated_at    timestamptz NOT NULL DEFAULT now()
CHECK (ends_at IS NULL OR starts_at IS NULL OR ends_at > starts_at)
```

#### `catalog.bundle_items`
```
id            uuid PK
bundle_id     uuid NOT NULL FK → catalog.bundles(id) ON DELETE CASCADE
product_id    uuid NOT NULL FK → catalog.products(id) ON DELETE RESTRICT
quantity      int NOT NULL DEFAULT 1 CK > 0      -- الكمية الناقصة اليوم
allow_options boolean NOT NULL DEFAULT false
sort_order    int NOT NULL DEFAULT 0
UNIQUE (bundle_id, product_id)
```

#### `catalog.branch_product_pricing`
**سعر/توافر على مستوى الفرع — جديد كليًا.**
```
branch_id         uuid NOT NULL FK → core.branches(id) ON DELETE CASCADE
product_id        uuid NOT NULL FK → catalog.products(id) ON DELETE CASCADE
price_override    numeric(12,2) ?  CK >= 0     -- NULL = استخدم base_price
is_available      boolean NOT NULL DEFAULT true
is_featured       boolean NOT NULL DEFAULT false
unavailable_reason text ?
updated_at        timestamptz NOT NULL DEFAULT now()
PRIMARY KEY (branch_id, product_id)
IX (product_id) WHERE price_override IS NOT NULL
```
`RLS: enabled` قراءة عامة (العميل يحتاج السعر الفعلي لفرعه المختار).

---

### 7.4 `orders`

> **مفتاح D1:** `branch_id` مطلوب في `carts` و`orders`. العميل يختار الفرع قبل الطلب.

#### `orders.carts`
```
id             uuid PK
user_id        uuid NOT NULL FK → identity.profiles(id) ON DELETE CASCADE
branch_id      uuid NOT NULL FK → core.branches(id) ON DELETE RESTRICT   -- D1
status         text NOT NULL DEFAULT 'active' CK in ('active','converted','abandoned')
expires_at     timestamptz NOT NULL DEFAULT (now() + interval '7 days')
created_at     timestamptz NOT NULL DEFAULT now()
updated_at     timestamptz NOT NULL DEFAULT now()
UNIQUE (user_id) WHERE status = 'active'
```
**`UNIQUE (user_id) WHERE status='active'`** — سلة نشطة واحدة لكل مستخدم لكل فرع. Index فريد جزئي.
`RLS: enabled` — `SELECT` بملكية. **الكتابة عبر RPC فقط.**

#### `orders.cart_items`
```
id             uuid PK
cart_id        uuid NOT NULL FK → orders.carts(id) ON DELETE CASCADE
product_id     uuid NOT NULL FK → catalog.products(id) ON DELETE RESTRICT
quantity       int NOT NULL DEFAULT 1 CK > 0
note           text NOT NULL DEFAULT ''
unit_price     numeric(12,2) NOT NULL CK >= 0   -- snapshot مُعاد التحقق منه على الخادم
line_total     numeric(12,2) NOT NULL CK >= 0   -- مُحسوب، لا يُرسل من العميل
created_at     timestamptz NOT NULL DEFAULT now()
UNIQUE (cart_id, product_id, note)
```
> **`unit_price` هنا مُحسَّب على الخادم** في RPC، وليس مُرسلًا من التطبيق — يعالج `loyalty_page.dart:24` الذي يمرر `unitPrice: 0`.

#### `orders.cart_item_options`
```
id             uuid PK
cart_item_id   uuid NOT NULL FK → orders.cart_items(id) ON DELETE CASCADE
option_value_id uuid NOT NULL FK → catalog.option_values(id) ON DELETE RESTRICT
option_name_ar text NOT NULL    -- snapshot
option_name_en text NOT NULL    -- snapshot
price_delta    numeric(12,2) NOT NULL DEFAULT 0  -- snapshot
```
**هذا هو حقل الخيارات الذي يُفقد اليوم في `CartItem.note`.**

#### `orders.orders`
```
id                uuid PK
order_number      text NOT NULL UQ           -- 'ORD-2026-000123'
user_id           uuid NOT NULL FK → identity.profiles(id) ON DELETE RESTRICT
branch_id         uuid NOT NULL FK → core.branches(id) ON DELETE RESTRICT   -- D1
fulfillment_type  text NOT NULL CK in ('pickup','delivery')
delivery_zone_id  uuid ? FK → core.delivery_zones(id) ON DELETE RESTRICT
delivery_address_snapshot jsonb NOT NULL DEFAULT '{}'  -- لقطة العنوان
status            text NOT NULL CK in ('pending','confirmed','preparing','ready','out_for_delivery','completed','cancelled')
payment_method_id uuid ? FK → payments.payment_methods(id)
payment_status    text NOT NULL DEFAULT 'unpaid' CK in ('unpaid','pending','paid','failed','refunded')
subtotal          numeric(12,2) NOT NULL CK >= 0
discount_total    numeric(12,2) NOT NULL DEFAULT 0 CK >= 0
delivery_fee      numeric(12,2) NOT NULL DEFAULT 0 CK >= 0
tax_total         numeric(12,2) NOT NULL DEFAULT 0 CK >= 0
grand_total       numeric(12,2) NOT NULL CK >= 0
currency_code     text NOT NULL DEFAULT 'SAR'
customer_note     text NOT NULL DEFAULT ''
loyalty_points_earned   int NOT NULL DEFAULT 0
loyalty_points_redeemed int NOT NULL DEFAULT 0
idempotency_key   text NOT NULL UQ          -- D5: منع التكرار
placed_at         timestamptz NOT NULL DEFAULT now()
completed_at      timestamptz ?
cancelled_at      timestamptz ?
cancel_reason     text ?
created_at        timestamptz NOT NULL DEFAULT now()
updated_at        timestamptz NOT NULL DEFAULT now()
CHECK (grand_total = subtotal - discount_total + delivery_fee + tax_total)
```
`IX (user_id, placed_at DESC)` · `IX (branch_id, status, placed_at DESC)` · `IX (status) WHERE status NOT IN ('completed','cancelled')`
`RLS: enabled` — `SELECT` بملكية. **`INSERT` ممنوع تمامًا على العميل** — عبر `orders.place_order()` فقط.
> **CHECK على `grand_total`:** يجعل أي تلاعب منطقيًا مستحيلاً حتى لو تسرّب خطأ برمجي.
> **`CHECK ... IN (...)` على `status`:** الطلب الأساسي 7 حالات مقابل `OrderStatus` بـ3 قيم في `order_status.dart` — يُوسَّع التطبيق عند الربط (§10.1).

#### `orders.order_items`
**لقطة تاريخية كاملة — لا يُقرأ أي شيء من الكتالوج عند العرض.**
```
id               uuid PK
order_id         uuid NOT NULL FK → orders.orders(id) ON DELETE RESTRICT
product_id       uuid ? FK → catalog.products(id) ON DELETE SET NULL   -- مرجع فقط
option_group_name_ar text NOT NULL  -- snapshot
option_group_name_en text NOT NULL
product_name_ar  text NOT NULL    -- snapshot
product_name_en  text NOT NULL    -- snapshot
sku_snapshot     text NOT NULL    -- snapshot
image_snapshot   text ?           -- snapshot
unit_price       numeric(12,2) NOT NULL CK >= 0   -- السعر بعد الخيارات
quantity         int NOT NULL CK > 0
line_total       numeric(12,2) NOT NULL CK >= 0
note             text NOT NULL DEFAULT ''
created_at       timestamptz NOT NULL DEFAULT now()
```
`IX (order_id)` · `RLS` بالملكية عبر `order_id → user_id`.
> ⚠️ **هذا الجدول هوIMPLEMENTATION المباشرة للمتطلب §4.13.** `order_details_page.dart:78` اليوم يحسب من السعر الحالي — خطأ فوترة.

#### `orders.order_item_options`
```
id                  uuid PK
order_item_id       uuid NOT NULL FK → orders.order_items(id) ON DELETE CASCADE
option_value_id     uuid ? FK → catalog.option_values(id) ON DELETE SET NULL
option_name_ar      text NOT NULL   -- snapshot
option_name_en      text NOT NULL   -- snapshot
price_delta         numeric(12,2) NOT NULL DEFAULT 0
```

#### `orders.order_status_history`
```
id            uuid PK
order_id      uuid NOT NULL FK → orders.orders(id) ON DELETE CASCADE
from_status   text ?
to_status     text NOT NULL
changed_by    uuid ? FK → auth.users(id)
note          text ?
created_at    timestamptz NOT NULL DEFAULT now()
IX (order_id, created_at)
```
**يلبّي متطلب «تاريخ انتقالات الحالة».** Transition مسموحة عبر trigger/SECURITY DEFINER.

#### `orders.order_events`
سجل تدقيق خفيف على مستوى الطلب (دعم).
```
id           bigserial PK
order_id     uuid NOT NULL FK → orders.orders(id) ON DELETE CASCADE
event_type   text NOT NULL
payload      jsonb NOT NULL DEFAULT '{}'
created_at   timestamptz NOT NULL DEFAULT now()
IX (order_id, created_at)
```

---

### 7.5 `inventory`

#### `inventory.branch_stock`
```
branch_id          uuid NOT NULL FK → core.branches(id) ON DELETE CASCADE
product_id         uuid NOT NULL FK → catalog.products(id) ON DELETE CASCADE
variant_key        uuid NOT NULL DEFAULT '00000000-0000-0000-0000-000000000000'::uuid  -- D8
quantity_on_hand   int NOT NULL DEFAULT 0
quantity_reserved  int NOT NULL DEFAULT 0
reorder_level      int NOT NULL DEFAULT 0
allow_negative     boolean NOT NULL DEFAULT false
updated_at         timestamptz NOT NULL DEFAULT now()
PRIMARY KEY (branch_id, product_id, variant_key)
FK (variant_key) REFERENCES catalog.option_values(id) ON DELETE CASCADE  DEFERRABLE
```
> **`variant_key` وليس `option_value_id`** — قرار **D8**. المفتاح `000...0` يعني «المنتج بلا متغيّر»، وكل قيمة أخرى يجب أن تكون `option_values.id` موجودة.
> `CK (quantity_on_hand >= 0 OR allow_negative)`.
> `RLS: enabled` — **قراءة إدارية فقط** (`inventory.read`). العميل لا يرى المخزون.

#### `inventory.stock_movements`
```
id             bigserial PK
branch_id      uuid NOT NULL FK → core.branches(id) ON DELETE RESTRICT
product_id     uuid NOT NULL FK → catalog.products(id) ON DELETE RESTRICT
option_value_id uuid ? FK → catalog.option_values(id) ON DELETE SET NULL
quantity_delta int NOT NULL        -- سالب = خصم
reason         text NOT NULL CK in ('sale','return','restock','adjustment','waste','cancellation')
reference_type text ?              -- 'order','manual'
reference_id   uuid ?              -- orders.orders(id) عند 'sale'
actor_user_id  uuid ? FK → auth.users(id)
note           text ?
created_at     timestamptz NOT NULL DEFAULT now()
```
`IX (branch_id, created_at DESC)` · `IX (reference_type, reference_id)`
**لا يُكتب أبدًا من العميل.** يُكتب من `place_order()` و`cancel_order()` (deduct) و`cancel_order()` (return) و RPC إداري للتعديل.

---

### 7.6 `payments`

#### `payments.payment_methods`
```
id             uuid PK
code           text NOT NULL UQ   -- 'cash','card','apple_pay','mada'
name_ar        text NOT NULL
name_en        text NOT NULL
is_active      boolean NOT NULL DEFAULT true
is_online      boolean NOT NULL DEFAULT false
sort_order     int NOT NULL DEFAULT 0
requires_saved_card boolean NOT NULL DEFAULT false
```
> يغطي `getPaymentMethodsList()` (4 طرق اليوم) + `saved_cards` كخيار.

#### `payments.payment_attempts`
```
id             uuid PK
order_id       uuid NOT NULL FK → orders.orders(id) ON DELETE CASCADE
method_id      uuid NOT NULL FK → payments.payment_methods(id)
status         text NOT NULL CK in ('initiated','requires_action','processing','succeeded','failed','cancelled')
failure_code   text ?
failure_message text ?
client_initiated boolean NOT NULL DEFAULT true
started_at     timestamptz NOT NULL DEFAULT now()
finished_at    timestamptz ?
```
`IX (order_id, started_at DESC)`

#### `payments.payment_transactions`
```
id                  uuid PK
order_id            uuid NOT NULL FK → orders.orders(id) ON DELETE CASCADE
attempt_id          uuid ? FK → payments.payment_attempts(id)
provider            text ?          -- 'mada','stripe',...
provider_reference  text ?          -- مرجع المزود
amount              numeric(12,2) NOT NULL CK >= 0
currency_code       text NOT NULL DEFAULT 'SAR'
status              text NOT NULL CK in ('pending','authorized','captured','failed','refunded','voided')
paid_at             timestamptz ?
refunded_at         timestamptz ?
card_brand          text ?          -- tokenized فقط
card_last4          text ?  CK ~ '^[0-9]{4}$'
card_holder_name    text ?
verified_by_server  boolean NOT NULL DEFAULT false   -- D5 §3
created_at          timestamptz NOT NULL DEFAULT now()
```
**لا يوجد عمود PAN ولا CVV. لا يوجد.** `verified_by_server` يبقى `false` في v1.
`RLS: enabled` — العميل يقرأ معاملاته فقط؛ لا يكتب.

---

### 7.7 `loyalty`

> **قرار D3:** الولاء داخل النطاق — الشاشة موجودة وتعمل.

#### `loyalty.loyalty_accounts`
```
user_id            uuid PK FK → identity.profiles(id) ON DELETE CASCADE
points_balance     int NOT NULL DEFAULT 0 CK >= 0
lifetime_points    int NOT NULL DEFAULT 0 CK >= 0
tier               text NOT NULL DEFAULT 'bronze' CK in ('bronze','silver','gold','platinum')
updated_at         timestamptz NOT NULL DEFAULT now()
```
> **تنبيه معماري — D9:** لا يوجد `loyalty_points` في `profiles`. رصيد النقاط يُقرأ عبر **View `identity.user_points`** (يُنشأ في migration 004) أو عبر `loyalty.loyalty_accounts` مباشرة. **مصدر الحقيقة الوحيد** = `loyalty.loyalty_accounts.points_balance`.

#### `loyalty.loyalty_rules`
```
id             uuid PK
code           text NOT NULL UQ
name_ar        text NOT NULL
name_en        text NOT NULL
points_per_currency_unit numeric(12,4) NOT NULL DEFAULT 1  CK >= 0
point_value    numeric(12,2) NOT NULL DEFAULT 0.05  CK >= 0   -- قيمة النقطة نقدًا
is_active      boolean NOT NULL DEFAULT true
valid_from     timestamptz NOT NULL DEFAULT now()
valid_to       timestamptz ?
```
> يكافئ `loyalty_rules.dart:3` «1 نقطة لكل 1 وحدة».

#### `loyalty.loyalty_transactions`
```
id             uuid PK
user_id        uuid NOT NULL FK → identity.profiles(id) ON DELETE CASCADE
points         int NOT NULL        -- موجب = كسب، سالب = صرف
balance_after  int NOT NULL        -- رصيد بعد الحركة
reason         text NOT NULL CK in ('earn_order','redeem_reward','expire','adjustment','refund')
reference_type text ?              -- 'order'
reference_id   uuid ?              -- orders.orders(id)
note           text ?
created_at     timestamptz NOT NULL DEFAULT now()
IX (user_id, created_at DESC)
```

#### `loyalty.loyalty_rewards`
```
id              uuid PK
product_id      uuid NOT NULL FK → catalog.products(id) ON DELETE RESTRICT
points_cost     int NOT NULL CK > 0                 -- يكافئ LoyaltyRules.rewardCosts
stock_available int ?  CK >= 0
is_active       boolean NOT NULL DEFAULT true
UNIQUE (product_id)
```
> **يحل نقصًا حقيقيًا:** `getRewardsList()` اليوم يحسب `pointsCost` من `Map<String,int>` ثابت. الحقل يصبح صفًا قابلًا للإدارة.

---

### 7.8 `marketing`

#### `marketing.banners`
```
id            uuid PK
title_ar      text NOT NULL
title_en      text NOT NULL
subtitle_ar   text
subtitle_en   text
description_ar text
description_en text
image_url     text NOT NULL
cta_label_ar  text
cta_label_en  text
target_type   text NOT NULL DEFAULT 'category' CK in ('category','product','bundle','url','none')
target_id     uuid ?         -- FK لامتنوعة حسب target_type (يُفحص بـCHECK أو trigger)
target_url    text ?
sort_order    int NOT NULL DEFAULT 0
starts_at     timestamptz ?
ends_at       timestamptz ?
is_published  boolean NOT NULL DEFAULT false
```
> **يكمل نقص `BannerModel`** الذي كان بلا ترتيب ولا صلاحية ولا نشر. `target_type` يحل مشكلة `targetCategory` النصي.
`CHECK (ends_at IS NULL OR starts_at IS NULL OR ends_at > starts_at)`

#### `marketing.coupons`
**يعالج عيب `CouponModel` الذي فيه نسبة داخل نص.**
```
id               uuid PK
code             text NOT NULL UQ CHECK (code = upper(code))
title_ar         text NOT NULL
title_en         text NOT NULL
description_ar   text
description_en   text
discount_type    text NOT NULL CK in ('percentage','fixed_amount')
discount_value   numeric(12,2) NOT NULL CK > 0
max_discount     numeric(12,2) ?  CK > 0     -- سقف للنسبة
min_order_amount numeric(12,2) NOT NULL DEFAULT 0 CK >= 0
applies_to       text NOT NULL DEFAULT 'all' CK in ('all','category','product')
usage_limit      int ?  CK > 0
per_user_limit   int NOT NULL DEFAULT 1 CK > 0
starts_at        timestamptz ?
ends_at          timestamptz ?
is_active        boolean NOT NULL DEFAULT true
created_at       timestamptz NOT NULL DEFAULT now()
CHECK (discount_type <> 'percentage' OR discount_value <= 100)
```
> **العيب المُصلَح:** `discount_value` عدد حقيقي. لا MORE استخراج بـ regex (`checkout_cubit.dart:68`).
> **`applies_to`:** يفرض `min_order_amount` بشكل حقيقي — النص الإعلاني في `coupons_list.dart:9` كان وعدًا غير مُنفَّذ.

#### `marketing.coupon_redemptions`
```
id           uuid PK
coupon_id    uuid NOT NULL FK → marketing.coupons(id) ON DELETE RESTRICT
user_id      uuid NOT NULL FK → identity.profiles(id) ON DELETE CASCADE
order_id     uuid NOT NULL FK → orders.orders(id) ON DELETE CASCADE
amount       numeric(12,2) NOT NULL CHECK (amount > 0)   -- الخصم الممنوح
created_at   timestamptz NOT NULL DEFAULT now()
UNIQUE (coupon_id, order_id)
IX (coupon_id, user_id)
```

#### `marketing.coupons_categories`
```
coupon_id    uuid NOT NULL FK → marketing.coupons(id) ON DELETE CASCADE
category_id  uuid NOT NULL FK → catalog.categories(id) ON DELETE CASCADE
PRIMARY KEY (coupon_id, category_id)
```

---

### 7.9 `engagement`

#### `engagement.product_reviews`
```
id            uuid PK
product_id    uuid NOT NULL FK → catalog.products(id) ON DELETE CASCADE
user_id       uuid NOT NULL FK → identity.profiles(id) ON DELETE CASCADE
order_id      uuid ? FK → orders.orders(id) ON DELETE SET NULL   -- شراء موثّق
rating        int NOT NULL CHECK (rating BETWEEN 1 AND 5)
title_ar      text
title_en      text
body_ar       text
body_en       text
is_published  boolean NOT NULL DEFAULT true
created_at    timestamptz NOT NULL DEFAULT now()
updated_at    timestamptz NOT NULL DEFAULT now()
UNIQUE (product_id, user_id)
IX (product_id) WHERE is_published
```
`RLS` — قراءة `is_published` للجميع؛ كتابة لمستخدمه فقط؛ **و`INSERT` يتطلب `order_id` يخصّه ويحتوي المنتج** (شرط «شراء موثّق»).

#### `engagement.customer_favorites`
```
id            uuid PK
user_id       uuid NOT NULL FK → identity.profiles(id) ON DELETE CASCADE
product_id    uuid NOT NULL FK → catalog.products(id) ON DELETE CASCADE
created_at    timestamptz NOT NULL DEFAULT now()
UNIQUE (user_id, product_id)
IX (user_id, created_at DESC)
IX (product_id)
```
`RLS` — ملكية العميل فقط لجميع العمليات؛ **لا كتابة مباشرة لغير المالك**، وحذف المنتج يحذف إشاراته المرجعية تلقائيًا.

#### `engagement.notifications`
```
id            uuid PK
user_id       uuid NOT NULL FK → identity.profiles(id) ON DELETE CASCADE
type          text NOT NULL CK in ('order_status','promo','system','loyalty')
title_ar      text NOT NULL
title_en      text NOT NULL
body_ar       text NOT NULL
body_en       text NOT NULL
payload       jsonb NOT NULL DEFAULT '{}'   -- e.g. {"order_id": "..."}
related_entity_type text ?
related_entity_id   uuid ?
is_read       boolean NOT NULL DEFAULT false
read_at       timestamptz ?
dedupe_key    text ?   -- لمنع التكرار
created_at    timestamptz NOT NULL DEFAULT now()
UNIQUE (user_id, dedupe_key)
IX (user_id, is_read, created_at DESC)
```
> **`dedupe_key` يلبّي متطلب «منع التكرار».** `UNIQUE(user_id, dedupe_key)` — وNULL مسموحة (متعددة).
> **كتابة الإشعارات من الخادم فقط** (trigger على تغيّر حالة الطلب + Edge Function).

#### `engagement.notification_preferences`
```
user_id             uuid PK FK → identity.profiles(id) ON DELETE CASCADE
order_status        boolean NOT NULL DEFAULT true
promo               boolean NOT NULL DEFAULT true
loyalty             boolean NOT NULL DEFAULT true
system              boolean NOT NULL DEFAULT true
push_enabled        boolean NOT NULL DEFAULT false
updated_at          timestamptz NOT NULL DEFAULT now()
```

#### `engagement.device_tokens`
```
id            uuid PK
user_id       uuid NOT NULL FK → identity.profiles(id) ON DELETE CASCADE
platform      text NOT NULL CK in ('ios','android','web')
token         text NOT NULL
app_version   text ?
device_name   text ?
last_seen_at  timestamptz NOT NULL DEFAULT now()
created_at    timestamptz NOT NULL DEFAULT now()
UNIQUE (platform, token)
IX (user_id)
```
**يوجد مسبقًا لـ Push في v2. الإرسال عبر Edge Function — لا مفتاح في العميل.**

---

### 7.10 `ai` — ❌ غير مكشوف لـPostgREST

#### `ai.product_knowledge`
```
product_id     uuid PK FK → catalog.products(id) ON DELETE CASCADE
ingredients    text[] NOT NULL DEFAULT '{}'
tags           text[] NOT NULL DEFAULT '{}'
allergens      text[] NOT NULL DEFAULT '{}'
flavor_notes_ar text
flavor_notes_en text
prep_notes_ar  text
prep_notes_en  text
updated_at     timestamptz NOT NULL DEFAULT now()
```
> **يحفظ قدرة المساعد المحلي** التي اليوم في `product_knowledge.dart:67-84`. يُقرأ عبر **Edge Function** فقط (لا يُكشف الجدول).
> ⚠️ **ملاحظة أمنية:** إذا احتاج المساعد إلى المعرفة محليًا داخل العميل، يجب إما كشف قراءة آمنة عبر RPC محدود أو تحميلها عبر Edge Function. **تُحسم في مرحلة التطبيق.**

#### `ai.knowledge_articles`
```
id          uuid PK
slug        text NOT NULL UQ
category    text NOT NULL DEFAULT 'faq'
title_ar    text NOT NULL
title_en    text NOT NULL
body_ar     text NOT NULL
body_en     text NOT NULL
keywords    text[] NOT NULL DEFAULT '{}'
sort_order  int NOT NULL DEFAULT 0
is_active   boolean NOT NULL DEFAULT true
```
> يغطي `coffee_knowledge.dart` (13 مقالة) + `faq_knowledge.dart` (10 مقالات).

---

## 8. تدفقات الأعمال الحرجة — حدود RPC

> **مبدأ:** `SECURITY DEFINER` **فقط** حيث يوجد سبب واضح: **عملية ذرية**، أو **تحقق مركزي**، أو **منطق لا ينبغي تكراره في العميل**. لا أكثر.

| # | الدالة | Schema | السبب المبرر |
|---|---|---|---|
| 1 | `catalog.search_products(p_query, p_branch_id, p_category_id, p_min, p_max, p_sort, p_page, p_page_size)` | `catalog` | تطبيع + trigram + alias + pagination. استعلام مركّب لا يُعبَّر عنه بـView. |
| 2 | `catalog.get_best_sellers(p_branch_id, p_period, p_limit)` | `catalog` | تجميع على `order_items` + `orders.status='completed'` + `placed_at`. |
| 3 | `catalog.get_featured(p_branch_id)` | `catalog` | يدمج يدوي + محسوب بترتيب واضح ومفسَّر. |
| 4 | `catalog.resolve_effective_price(p_branch_id, p_product_id, p_options)` | `catalog` | تحقق مركزي للسعر. **العميل لا يحدد السعر.** |
| 5 | `orders.upsert_cart_item(...)` | `orders` | إعادة حساب السعر على الخادم + كتابة atomically. |
| 6 | `orders.get_cart_summary(p_cart_id)` | `orders` | إجماليات موحّدة. لا يثق بحقول العميل. |
| 7 | **`orders.place_order(p_cart_id, p_idempotency_key, p_fulfillment_type, p_delivery_zone_id, p_coupon_code, p_note)`** | `orders` | **الأهم**: ذرّي، يتحقق من الأسعار والتوافر والمنطقة والمخزون، يخصم المخزون، يسجل النقاط، يمنع التكرار. |
| 8 | `orders.cancel_order(p_order_id, p_reason)` | `orders` | ذرّي + إرجاع المخزون + سجل انتقالات. |
| 9 | `orders.update_order_status(p_order_id, p_to_status)` | `orders` | انتقالات مسموحة فقط + صلاحية. |
| 10 | `marketing.validate_coupon(p_code, p_branch_id, p_subtotal)` | `marketing` | تحقق مركزي + `per_user_limit`. |
| 11 | `loyalty.redeem_reward(p_product_id)` | `loyalty` | ذرّي: خصم نقاط + إضافة للسلة. |
| 12 | `core.normalize_ar(p_text)` | `core` | دالة نقية مشتركة. يُمرَّر للـsearch vector. |
| 13 | `identity.has_permission(p_code)` | `identity` | تُستخدم داخل سياسات RLS. |
| 14 | `inventory.adjust_stock(...)` | `inventory` | صلاحية إدارية + سجل حركة إجباري. |

### 8.1 قواعد إلزامية للدوال
- كل دالة `SECURITY DEFINER` → `SET search_path = ''` + أسماء schema كاملة.
- التحقق من `auth.uid()` داخل الدالة (لا تثق بـ`p_user_id`).
- `place_order` **يجب** أن تكون داخل معاملة واحدة مع `SELECT ... FOR UPDATE` على المخزون والسلة.
- `idempotency_key` يُفحص أولًا؛ عند التكرار يُعاد نفس النتيجة ولا يُنشأ طلب ثانٍ.

---

## 9. معايير RLS / RBAC — شروط قبول إلزامية

1. **RLS مفعّل على كل جدول** بلا استثناء. أي استثناء يُوثَّق صراحة في التقرير.
2. **RLS مُفعّل ليس كافيًا.** يجب توثيق **محتوى كل سياسة** وسببها. «مفعّل» ≠ «آمن».
3. العميل A لا يقرأ/يعدّل سلة أو طلبات أو إشعارات العميل B.
4. العميل لا يصل إلى `inventory`، ولا `staff_members`، ولا `role_permissions`، ولا `audit_log`.
5. المستخدم العادي لا يمنح نفسه دورًا ولا يغيّر `user_id` ولا `staff_id`.
6. موظف الفرع لا يعدّل فرعًا غير مُسند له إلا بصلاحية `*.all_branches` صريحة.
7. العميل لا يكتب `base_price` ولا `grand_total` ولا `payment_status` ولا `stock_movements`.
8. **اختبارات §12 تُنفَّذ بجلسات/أدوار مستخدمين حقيقيين** (anon / authenticated بمستخدمين حقيقيين). **اختبار واحد بصفة `postgres` أو `service_role` لا يُعتبر إثباتًا لـRLS** — ويجب التصريح بذلك في التقرير إن تعذر.
9. كل دالة `SECURITY DEFINER` تُراجَع يدويًا: أقل صلاحية، `search_path` مثبَّت، تحقق من المتصل.
10. لا `GRANT` واسع لـ`anon` أو `authenticated` افتراضيًا.
11. **لا تعتمد على metadata يستطيع المستخدم تعديلها** لتحديد الصلاحيات (لا `profiles.role`).
12. اختبر **المنع والسماح معًا** — «لا يستطيع X» و«يستطيع Y».

### 9.1 ملخص سياسات الوصول

| الجدول | anon | authenticated (المالك) | authenticated (موظف) |
|---|---|---|---|
| `core.branches` | ✅ قراءة النشطة | ✅ قراءة | ✅ قراءة |
| `core.delivery_zones` | ✅ قراءة النشطة | ✅ | ✅ |
| `catalog.*` | ✅ قراءة النشطة | ✅ | ✅ |
| `identity.profiles` | ❌ | ✅ ملكيته فقط | ✅ ملكيته فقط |
| `identity.customer_addresses` | ❌ | ✅ ملكيته فقط | ✅ (خدمة فقط) |
| `identity.staff_members` | ❌ | ❌ | ✅ `admin.staff.read` |
| `identity.roles` / `permissions` | ❌ | ❌ | ✅ `admin.role.read` |
| `identity.audit_log` | ❌ | ❌ | ✅ `audit.read` |
| `orders.carts` | ❌ | ✅ قراءة فقط (كتابة RPC) | ✅ خدمة فقط |
| `orders.orders` | ❌ | ✅ قراءة فقط | ✅ `orders.read` |
| `inventory.*` | ❌ | ❌ | ✅ `inventory.read` |
| `payments.*` | ❌ | ✅ قراءة معاملاته فقط | ✅ `payments.read` |
| `loyalty.*` | ❌ | ✅ حسابه فقط | ✅ `loyalty.read` |
| `marketing.banners` | ✅ قراءة المنشورة | ✅ | ✅ |
| `marketing.coupons` | ✅ قراءة النشطة (بدون usage) | ✅ | ✅ |
| `engagement.product_reviews` | ✅ قراءة المنشورة | ✅ كتابة ملكيته | ✅ |
| `engagement.customer_favorites` | ❌ | ✅ ملكيته فقط | ❌ |
| `engagement.notifications` | ❌ | ✅ ملكيته فقط | ✅ `notifications.read` |
| `engagement.device_tokens` | ❌ | ✅ ملكيته فقط | — |
| `ai.*` | ❌ | ❌ | ❌ — **غير مكشوف، يُقرأ بـEdge Function فقط** |

---

## 10. خريطة التتبع: شاشة التطبيق ← الجداول

> **قاعدة إلزامية (D3):** لا شاشة بلا دعم بيانات. كل صف يوثّق الفحص الحالي.

### 10.1 الشاشات (32)

| # | route | الشاشة | الجداول الداعمة | الحالة الحالية |
|---|---|---|---|---|
| 1 | `welcomeView` | `WelcomePage` | `core.app_settings`, `core.brands` | ثابت |
| 2 | `onBoardingView` | `OnBoardingView` | `core.onboarding_slides` | ثابت |
| 3 | `authRoute` | `AuthPage` | Supabase Auth | محاكاة |
| 4 | `signUpRoute` | `SignUpPage` | `identity.profiles` (trigger) | محاكاة |
| 5 | `forgetPasswordRoute` | `ForgetPasswordPage` | Supabase Auth | محاكاة |
| 6 | `resetPasswordRoute` | `ResetPasswordPage` | Supabase Auth | **بلا رمز** |
| 7 | `phoneAuthRoute` | `PhoneAuthPage` | — | **مؤجل** |
| 8 | `otpRoute` | `OtpPage` | — | **مؤجل** |
| 9 | `mainRoute` | `MainPage` | تجميع | — |
| 10 | `home` | `HomePage` | `core.branches`, `marketing.banners`, `catalog.categories`, `catalog.get_best_sellers`, `catalog.get_featured`, `catalog.bundles` | ثابت |
| 11 | `searchRoute` | `SearchPage` | `catalog.search_products`, `product_aliases`, `category_aliases` | in-memory |
| 12 | `categories` | `CategoriesPage` | `catalog.categories`, `catalog.products` | ثابت |
| 13 | `productDetailsRoute` | `ProductDetailsPage` | `catalog.products`, `product_images`, `option_groups`, `option_values`, `product_option_groups`, `engagement.product_reviews` | enums ثابتة |
| 14 | `seeAllProductsRoute` | `SeeAllProductsPage` | `catalog.products` + pagination | ثابت |
| 15 | `bundleDetailsRoute` | `BundleDetailsPage` | `catalog.bundles`, `bundle_items` | ثابت، **بلا كميات** |
| 16 | `bannerDetailsRoute` | `BannerDetailsPage` | `marketing.banners` + `target_type` | ثابت |
| 17 | `cart` | `CartPage` | `orders.carts`, `cart_items`, `cart_item_options` | SharedPrefs |
| 18 | `checkoutRoute` | `CheckoutPage` | `orders.get_cart_summary`, `core.branches`, `core.delivery_zones` | ثابت |
| 19 | `shippingAddressesRoute` | `ShippingAddressesPage` | `identity.customer_addresses` | ثابت، **لا يُحفظ** |
| 20 | `addAddressRoute` | `AddAddressPage` | `identity.customer_addresses` | ثابت |
| 21 | `paymentMethodRoute` | `PaymentMethodPage` | `payments.payment_methods`, `payment_transactions` (tokenized) | ثابت |
| 22 | `addCardRoute` | `AddCardPage` | `payments.payment_transactions` (tokenized فقط) | ثابت |
| 23 | `paymentSuccessRoute` | `PaymentSuccessPage` | `orders.orders`, `payments.payment_transactions` | ثابت |
| 24 | `eReceiptRoute` | `EReceiptPage` | `orders.orders` + `order_items` snapshots + `core.brands` | ثابت |
| 25 | `couponRoute` | `CouponPage` | `marketing.coupons` | ثابت |
| 26 | `loyaltyRoute` | `LoyaltyPage` | `loyalty.loyalty_accounts`, `loyalty_transactions`, `loyalty_rules`, `loyalty_rewards` | SharedPrefs |
| 27 | `ordersRoute` | `OrdersPage` | `orders.orders`, `orders.order_status_history` | ثابت |
| 28 | `orderDetailsRoute` | `OrderDetailsPage` | `orders.order_items` + `order_item_options` (snapshots) | **يقرأ سعرًا حيًا** |
| 29 | `trackOrderRoute` | `TrackOrderPage` | `orders.order_status_history` | ثابت |
| 30 | `leaveReviewRoute` | `LeaveReviewPage` | `engagement.product_reviews` | **يتجاهل المدخلات** |
| 31 | `editProfileRoute` | `EditProfilePage` | `identity.profiles` | **لا يُحفظ** |
| 32 | `savedCardsRoute` | `SavedCardsPage` | `payments.payment_transactions` (tokenized) | SharedPrefs |
| 33 | `notificationsRoute` | `NotificationsPage` | `engagement.notifications`, `notification_preferences` | ثابت |
| 34 | `helpRoute` | `HelpPage` | `core.faq_items` | ثابت |
| 35 | `privacyPolicyRoute` | `PrivacyPolicyPage` | `core.legal_documents` | ثابت |
| 36 | Assistant FAB | `AssistantSheet` | `ai.product_knowledge`, `ai.knowledge_articles`, `catalog.product_aliases` | ثابت |

### 10.2 مصادر البيانات الثابتة اليوم ← الجداول البديلة

| الملف اليوم | الجدول |
|---|---|
| `menu_list.dart` (16) | `catalog.products` |
| `categories_list.dart` (10) | `catalog.categories` |
| `bundles_list.dart` (4) | `catalog.bundles` + `bundle_items` |
| `banners_list.dart` (5) | `marketing.banners` |
| `coupons_list.dart` (4) | `marketing.coupons` |
| `orders_list.dart` (5) | — (بيانات تجريبية) |
| `notifications_list.dart` (4) | — (بيانات تجريبية) |
| `addresses_list.dart` (2) | — (بيانات تجريبية) |
| `payment_methods_list.dart` (4) | `payments.payment_methods` |
| `saved_cards_list.dart` (2) | — (بيانات تجريبية) |
| `faqs_list.dart` (5) | `core.faq_items` |
| `on_boarding_list.dart` (3) | `core.onboarding_slides` |
| `tracking_steps_list.dart` (4) | — (مشتق من `order_status_history`) |
| `product_variants.dart` | `catalog.option_groups` + `option_values` + `product_option_groups` |
| `loyalty_rules.dart` | `loyalty.loyalty_rules` + `loyalty_rewards` |
| `assistant_phrases.dart:282` (`productSynonyms`) | `catalog.product_aliases` |
| `assistant_phrases.dart:312` (`categoryBoosts`) | `catalog.category_aliases` |
| `product_knowledge.dart` (16) | `ai.product_knowledge` |
| `coffee_knowledge.dart` (13) + `faq_knowledge.dart` (10) | `ai.knowledge_articles` |
| `privacy_policy_text.dart` | `core.legal_documents` |
| `app_constant.dart:14` (`deliveryFee`) | `core.delivery_zones.delivery_fee` |

### 10.3 الفجوات التي تُغلق

| الفجوة | الجدول/الإجراء |
|---|---|
| لا双语 | D4 — أعمدة `_ar`/`_en` |
| الخيار يُفقد في السلة | `orders.cart_item_options` |
| الفاتورة تتغير عند تعديل السعر | `orders.order_items` snapshots |
| لا فئات فرعية | `catalog.categories.parent_id` |
| الباقة بلا كميات | `catalog.bundle_items.quantity` |
| لا تواريخ انتهاء للبنرات/الكوبونات | `starts_at` / `ends_at` |
| لا تحقق من الكوبون | `marketing.validate_coupon` + `coupon_redemptions` |
| لا يمنع طلبًا مكررًا | `orders.orders.idempotency_key` UQ |
| لا خصم مخزون | `inventory.branch_stock` + `place_order` ذرّي |
| لا سعرValidity لكل فرع | `catalog.branch_product_pricing` |
| لا اختيار فرع | `branch_id` في `carts` + `orders` |
| «الأكثر مبيعًا» يدوي فقط | `catalog.get_best_sellers()` |
| لا بحث عربي | `product_aliases` + `normalize_ar()` |
| لا سجل انتقالات | `orders.order_status_history` |
| لا سجل تدقيق | `identity.audit_log` |

### 10.4 المؤجَّل (القائمة المُقفلة)

1. تسجيل/دخول الهاتف (Edge Function + SMS).
2. بوابة دفع حقيقية + webhooks.
3. Push عبر FCM/OneSignal (الجداول جاهزة).
4. ذكاء اصطناعي خارجي (LLM).
5. تعدد علامات تجارية / SaaS.
6. Page Builder / تخزين واجهات JSON.

**أي شيء خارج هذه القائمة 且 له شاشة = داخل النطاق.**

---

## 11. خطة migrations

| # | الملف | المحتوى | الاعتماد |
|---|---|---|---|
| 001 | `_extensions_and_schemas.sql` | `pg_trgm`, `pgcrypto`; إنشاء 10 schemas | — |
| 002 | `_core_functions.sql` | `core.normalize_ar()`, `core.set_updated_at()` | 001 |
| 003 | `identity_01_auth_tables.sql` | `profiles`, `customer_addresses` | 001 |
| 004 | `identity_02_rbac.sql` | `staff_members`, `roles`, `permissions`, `role_permissions`, `staff_roles`, `audit_log` + **الأدوار والصلاحيات التأسيسية** | 003 |
| 005 | `core_01_brand_branches.sql` | `brands`, `branches`, `delivery_zones`, `delivery_zone_branches`, `app_settings` | 002 |
| 006 | `core_02_content.sql` | `legal_documents`, `faq_items`, `onboarding_slides` | 005 |
| 007 | `catalog_01_categories_products.sql` | `categories`, `products` | 005 |
| 008 | `catalog_02_images_options.sql` | `product_images`, `option_groups`, `option_values`, `product_option_groups` | 007 |
| 009 | `catalog_03_aliases_search.sql` | `product_aliases`, `category_aliases`, `search_vector` + **triggers** | 008 |
| 010 | `catalog_04_bundles_pricing.sql` | `bundles`, `bundle_items`, `branch_product_pricing` | 008 |
| 011 | `orders_01_schema.sql` | `carts`, `cart_items`, `cart_item_options`, `orders`, `order_items`, `order_item_options`, `order_status_history`, `order_events` | 010 |
| 012 | `inventory_01.sql` | `branch_stock`, `stock_movements` | 011 |
| 013 | `payments_01.sql` | `payment_methods`, `payment_attempts`, `payment_transactions` | 011 |
| 014 | `loyalty_01.sql` | `loyalty_accounts`, `loyalty_rules`, `loyalty_rewards`, `loyalty_transactions` | 011 |
| 015 | `marketing_01.sql` | `banners`, `coupons`, `coupons_categories`, `coupon_redemptions` | 010 |
| 016 | `engagement_01.sql` | `product_reviews`, `notifications`, `notification_preferences`, `device_tokens` | 011 |
| 038 | `engagement_02_customer_favorites.sql` | `customer_favorites`, سياسات الملكية، منح `authenticated`، عرض `public` | 016 |
| 017 | `ai_01.sql` | `product_knowledge`, `knowledge_articles` | 007 |
| 018 | `rls_01_identity.sql` | سياسات `identity` | 004 |
| 019 | `rls_02_core_catalog.sql` | سياسات `core`, `catalog` | 010 |
| 020 | `rls_03_orders_inventory_payments.sql` | سياسات `orders`, `inventory`, `payments` | 013 |
| 021 | `rls_04_loyalty_marketing_engagement.sql` | سياسات `loyalty`, `marketing`, `engagement` | 016 |
| 022 | `grants_01.sql` | مراجعة كل `GRANT` | 021 |
| 023 | `functions_01_core_helpers.sql` | `identity.has_permission()` | 018 |
| 024 | `functions_02_catalog.sql` | `search_products`, `get_best_sellers`, `get_featured`, `resolve_effective_price` | 023 |
| 025 | `functions_03_orders.sql` | `upsert_cart_item`, `get_cart_summary`, **`place_order`**, `cancel_order`, `update_order_status` | 024 |
| 026 | `functions_04_marketing_loyalty_inventory.sql` | `validate_coupon`, `redeem_reward`, `adjust_stock` | 025 |
| 027 | `triggers_01_order_notifications.sql` | إشعار عند تغيّر حالة الطلب | 025 |
| 028 | `_grants_audit.sql` | مراجعة نهائية + تقرير | 027 |
| S1 | `seed_01_reference_data.sql` | الأدوار والصلاحيات الأساسية + طرق الدفع + **بيانات الكتالوج الحالية** (16 منتج، 10 فئات، 5 بنرات، 4 باقات، 4 كوبونات، 12 خيار، ...) | 028 |

**قيود إلزامية على الـmigrations:**
- كل migration **صغير وواضح**، يُطبَّق ويُسجَّل قبل التالي.
- **لا يُعدَّل ملف migration مُطبَّق.** التصحيح = migration جديد.
- `seed` **مفصول** عن `schema`، ولا يُعاد تشغيله على بيانات تشغيل.
- migrations تُحفظ في `supabase/migrations/` داخل المشروع.
- تراجع = `down` صريح أو **استعادة من نسخة** — لا `DROP CASCADE`.

---

## 12. اختبارات القبول

> **يُنفَّذ فعليًا متى سمحت البيئة. ما تعذّر يُذكر صراحة مع السبب — ولا يُ claiming نجاح.**
> **اختبار RLS يُنفَّذ بجلسات مستخدمين حقيقيين. بصفة `postgres` أو مفتاح يتجاوز RLS = ليس إثباتًا.**

### A — الهوية والمصادقة (6)
1. إنشاء حساب عميل بالبريد وكلمة المرور + تأكيد + استعادة كلمة مرور.
2. **عميل وموظف بنفس البريد لا يندمجان** — أو توثيق القيد التقني.
3. **الموظف المعطَّل (`suspended`) يُرفض تسجيل الدخول الإداري** مع بريد صحيح.
4. **الموظف بلا فرع مصرّح به يُرفض** من شاشات فرع آخر.
5. العميل لا يستطيع **إنشاء أو تفعيل** سجل في `staff_members`.
6. العميل لا يستطيع تعديل `staff_id` ولا منح دور.

### B — العزل (5)
7. العميل A لا يقرأ/يعدّل سلة أو طلبات أو إشعارات العميل B.
8. العميل لا يصل إلى `inventory`, `staff_members`, `role_permissions`, `audit_log`.
9. `anon` لا يقرأ جداول العملاء.
10. جداول خاصة لا تُقرأ مجهولًا (فحص `anon` على كل جدول).
11. موظف الفرع لا يعدّل فرعًا غير مُسند إليه إلا بصلاحية صريحة.

### C — الكتالوج والخيارات (4)
12. إضافة منتج لمجموعة خيارات؛ الطلب يُلزم بالحد الأدنى/الأقصى.
13. `single` يرفض اختيار قيمتين؛ `multiple` يحترم `max_select`.
14. تعديل سعر منتج بعد طلب قديم **لا يغيّر** الفاتورة القديمة.
15. `search_products` يرجع نتيجة عربية لـ«لاتيه» و«كابتشينو» عبر `product_aliases`.

### D — الفروع (3)
16. العميل يختار الفرع؛ الأسعار والتوافر **تتغير** حسب `branch_product_pricing`.
17. طلب لمنتج غير متاح في الفرع المختار **يُرفض**.
18. توصيل إلى منطقة لا يخدمها الفرع **يُرفض**.

### E — الطلبات والأسعار (5)
19. **التحقق من السعر والإجمالي ورسوم التوصيل على الخادم** — تعديل `unit_price` من العميل **يُتجاهل**.
20. تعديل `grand_total` من العميل **يُرفض**.
21. نفس `idempotency_key` مرتين → **طلب واحد فقط**.
22. **خصم المخزون مرة واحدة** عند إعادة المحاولة.
23. كل حركة مخزون لها `reason` + `reference_id` صالح.

### F — الحالات والدفع (4)
24. انتقالات غير مسموحة (`completed → preparing`) **تُرفض**.
25. العميل لا يستطيع تزوير `payment_status = 'paid'`.
26. إكمال الطلب يُنشئ `order_status_history` و`loyalty_transactions`.
27. إلغاء الطلب **يُرجع المخزون** ويسجل حركة `cancellation` (مرة واحدة).

### G — الولاء والكوبونات (3)
28. كوبون منتهٍ/غير نشط/تجاوز `per_user_limit` **يُرفض**.
29. redemption الطريق تمنع تجاوز `usage_limit`.
30. `redeem_reward` يخصم نقاط بالترتيب الصحيح ويضيف للسلة ذرّيًا.

### H — المفاتيح والقيود (3)
31. المفاتيح الأجنبية سليمة؛ لا سجلات يتيمة في بيانات الاختبار.
32. `CHECK (grand_total = subtotal - discount + delivery + tax)` **يُطبَّق**.
33. حذف بيانات الاختبار **لا يمس** الطلبات — soft delete فقط.

---

## 13. التسليم النهائي

### 13.0 سجل التنفيذ الفعلي — 2026-10-15

**المشروع:** `webzzasosevzymftgszn` — تم التحقق منه بمطابقة `ref` في توقيع المفتاح مع المضيف، وباتصال Postgres مباشر.

| القياس | القيمة |
|---|---|
| جداول التطبيق | **58** موزّعة على 10 schemas |
| جداول بلا RLS | **0** |
| سياسات RLS | **101** |
| الفهارس | **168** |
| دوال `SECURITY DEFINER` | **24** |
| migrations مُطبّقة | **38** (شاملة 3 seed و6 تصحيحية) |
| جداول في `public` | **0** (قرار D10 مُحقق) |
| اختبارات القبول | **33 / 33 ناجحة** |

**migrations تصحيحية أُضيفت أثناء التنفيذ** (كلها أخطاء حقيقية اكتُشفت بالتشغيل، لا بالقراءة):

| الملف | المشكلة التي أصلحها |
|---|---|
| `002b` | نطاق حذف التشكيل كان يبتلع الأرقام العربية `١٢٣ ← ""` |
| `004b` | `permissions` بلا `name_en` — يخالف D4 |
| `004c` | قيد `code` كان يسمح بمقطع واحد فقط، فرفض `catalog.product.write` |
| `007b` | `categories` بلا `slug` — عُدِّل اسم الملف من `004d` ليأتي بعد `007` الذي ينشئ `catalog.categories` |
| `012b` | FK على `variant_key` كان يرفض القيمة الحارسة (D8) |
| `029` | `similarity()` غير قابل للعزل مع `search_path = ''`؛ وتضارب `cart_item_id` |
| `030` | منح DML مفقود للوحة الإدارة؛ و`ON CONFLICT` على فهرس جزئي |

> **ملاحظة ترتيب (`004d` ← `007b`):** إنشاء `slug` يلمس `catalog.categories` التي ينشئها `007`، لذا يجب أن يُطبَّق بعده ليصحّ **إعادة البناء من الصفر** (§13). نُقل الملف من `004d` إلى `007b` دون تغيير جسمه (idempotent). لا تتأثر قاعدة طُبِّق عليها سابقًا باسم `004d`؛ فأدوات `tools/` لا تقرأ سجل `_ops.migration_log` ولا ترتّب الملفات تلقائيًا. يبقى الاسم `004d` في السجل القديم مرجعًا تاريخيًا، ولا يُعدَّل سجل الإنتاج. الترتيب الصحيح عند إعادة البناء: تطبيق الملفات بترتيب أسمائها (أو باحترام الاعتماد) عبر `tools/run_migration.ps1`.

**إجباري:**
1. Project Ref المستهدف فقط.
2. migrations مرتبة + نتيجة كل واحدة.
3. قاموس البيانات مُطبَّق (مطابق §7).
4. ERD أو وصف العلاقات.
5. **مصفوفة الأدوار والصلاحيات.**
6. **جدول تقارن: شاشة التطبيق ← الجدول ← RPC ← الحالة** (مطابق §10).
7. نتيجة كل اختبار من §12 + خطوات إعادة التشغيل.
8. **إعدادات Dashboard اليدوية** (Auth, Redirect URLs, Exposed schemas, SMTP).
9. تقرير صريح: ما نُفِّذ / ما لم يُنفَّذ ولماذا.
10. الميزات المؤجلة + المخاطر المتبقية.

**معيار الاكتمال:**
> لا يُعتبر العمل مكتملًا لمجرد إنشاء الجداول. يجب أن **يثبت** الاختبارات: فصل الهوية، RLS/RBAC، سلامة الطلبات والأسعار، المخزون، الدفع — وأن تكون migrations **قابلة لإعادة البناء من الصفر** على مشروع جديد بنفس الأوامر.

**قاعدة أخيرة:**
> **لا تبدأ أي مرحلة UI/Flutter قبل تسليم هذا التقرير وانتظار موافقة صريحة.**