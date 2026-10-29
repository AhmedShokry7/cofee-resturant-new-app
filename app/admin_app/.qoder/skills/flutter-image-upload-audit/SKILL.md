---
name: flutter-image-upload-audit
description: تدقيق مسار رفع الصور في تطبيق الأدمن من زرّ الانتقاء إلى الدلو (Supabase Storage) إلى صفّ القاعدة إلى العرض. تتبّع القيود الحقيقية (سقف الحجم، سقف أضلاع الصورة، بادئة المسار، صلاحية سياسة الدلو، ممنوع فكّ/ترميز الصورة كاملة على خيط الواجهة) قبل أي تعديل في شاشات الصور. تُستخدم عند تقرير «الصورة لا تُرفع» أو «التطبيق يتجمّد عند رفع صورة» أو عند تعديل أي منتقي أو معاين أو محرر صور.
---

# تدقيق مسار رفع الصور

القاعدة الحاكمة: **الصورة تُصغَّر عند دخولها، وتُفكّ مرة واحدة، وتُكتب في مكان واحد.** أي انحراف عن واحدة من هذه الثلاثة يُولّد أحد عَرَضين فقط: إما الرفض («الصورة أكبر من المسموح») أو التجمّد ثم خروج التبويب.

## ٠. Places that are the single source of truth

| القيد | أين يسكن | ما يجب أن يظلّ وحيدًا |
| --- | --- | --- |
| سقف حجم الملف | `adminImageMaxBytes` في `lib/core/models/admin_product_image.dart` | لا حرف `5 * 1024 * 1024` في أي مستودع |
| أضلاع الانتقاء والجودة | `adminImageMaxEdge` و`adminImageQuality` في `lib/core/services/admin_image_picker.dart` | الانتقاء عند أي شاشة يمرّ بـ `pickAdminImage` |
| عرض فكّ المعاينة | `AppDimensions.imagePreviewCacheWidth` | كل `Image.memory` في لوحة الأدمن يحمل `cacheWidth` |
| الدلو وبادئة المسار | دلو `product-images` وكل المسارات تبدأ `products/` | لا مسار خارج هذه البادئة |
| سطر الصورة بعد الملف | داخل `uploadXImage` في المستودع | الـ Cubit لا يكتب السطر مرة ثانية بعد الرفع |
| نوع الصورة | `adminImageSniffedType` في `lib/core/services/admin_image_bytes.dart` يرجّح على اسم الملف | لا تُصدّق اسم الملف ولا ما يقوله الجهاز |
| كتابة سطر صورة التصنيف | `public.admin_set_category_image` (ترحيلة 205) — لا `update public.categories` من العميل | لا كتابة مباشرة على جدول يملك `SECURITY INVOKER trigger` |

## ١. القراءة (لا تعديل)

1. كل مواضع الانتقاء: `grep -n "pickImage(\|readAsBytes()" lib` — يجب أن يكون الناتج داخل `admin_image_picker.dart` وحده. أي انتقاء في widget هو العَرَض الأول للتجمّد.
2. كل مواضع فكّ الصورة: `grep -n "Image.memory(\|decodeImage(\|encodePng(\|encodeJpg(" lib` — ابحث عن ترميز أو فكّ داخل `build` أو داخل `LayoutBuilder`: هذا يعني عملاً كاملاً على خيط الواجهة مع كل إطار سحب.
3. حدود القاعدة: آخر تعريف للدلو وسياساته في `supabase/migrations/` (ابحث عن `storage.buckets` و`create policy` على `storage.objects`)، لا أول نتيجة.
4. حدود المستودعات: هل يرفض المستودع الحجم قبل الإرسال؟ ومن يملك صلاحية الكتابة التي تطلبها سياسة الدلو (`identity.has_permission('catalog.product.write')`)؟

## ٢. النتائج

صنّف كل ملاحظة Confirmed / Refuted / Unverified بملف:سطر، وافحص دائمًا الفرضيتين اللتين تُخلط بينهما الشاشات:

- **الرفع فُرفض**: غالبًا الحجم بعد التصغير، أو نوع لا يقبله الدلو، أو بادئة مسار خارج `products/`، أو صلاحية ساطور الدلو.
- **الصورة رفعت ولا تظهر**: مسار العرض (CORS في بناء الويب، أو `CachedNetworkImage` يحتاج ترويسات عبور) — لا علاقة له بالرفع، ويُذكر في قسم منفصل.
- **التبويب يسقط**: صورة بأكملها على خيط الواجهة (كانفس المتصفح، أو `decodeImage`/`encodePng` من حزمة `image`، أو `Image.memory` بغير `cacheWidth`).
- **الكتابة تنجح في RLS وتفشل داخل trigger**: `permission denied for function <name> (42501)` على جدول تعرف أنه محمي بسياسات صحيحة. الساطور هنا ليس السياسة بل صلاحية تنفيذ دالة يناديها `SECURITY INVOKER trigger` باسم الدور العميل. افحص السلسلة قبل أي hypothesis عن الرولت:

```
select p.proname, pg_get_userbyid(p.proowner), p.prosecdef, p.proacl
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='catalog' and p.proname in ('trg_category_search','rebuild_category_search');
select tgrelid::regclass, tgname, tgfoid::regproc, (select prosecdef from pg_proc where oid=tgfoid)
  from pg_trigger where not tgisinternal and tgname ilike '%search%';
select has_function_privilege('authenticated','catalog.rebuild_category_search(uuid)','EXECUTE');
```

الإغلاق الصواب ليس إعادة المنح (الدور `authenticated` هو دور العميل المسجَّل، ومنحه كتابة آمنة التعريف على جداول البحث يفتحها لكل عميل)، بل تمرير الكتابة عبر دالة `admin_*` آمنة التعريف كما في `205_admin_set_category_image.sql` — قياسًا بـ`catalog.sync_product_image_url()` التي تجعل مسار صور المنتجات يعمل أصلًا. ولاحظ أن وجود الترحيلة في السجل لا يعني أن منحها حيّ: `083` مسجَّلة والمنح مفقود لأن الدالة أُعيد إنشاؤها بعدها.

### ما يفعله منتقي الويب فعلًا (قُرئ من `image_picker_for_web`، لا فُرض)

`ImageResizer.resizeImageIfNeeded` يصرّف كانفس بأضلاع `maxWidth`/`maxHeight` ثم `toBlob`: الأضلاع تُطبَّق، لكن
- الجودة لا تُطبَّق إلا على JPEG وWEBP، فصورة PNG كبيرة تعود كبيرة كما هي؛
- الغلاف (`mimeType` والاسم) يبقى اسم الملف الأصلي مع بايتات مختلفة؛
- GIF يُعاد كما هو بلا أي تصغير.

لذا: حارس الحجم لا يكفي عند الانتقاء، ومن يرفض >السقف قبل القراءة يرفض صور PNG سليمة. افحص البايت، ثم أصغر إلى JPEG إن لزم، وسمِّ الملف بما يحمله.

### فحص CORS في نصف دقيقة (لا يحتاج متصفحًا)

```
curl -s -o /dev/null -D - -H "Origin: http://localhost:5000" \
  "https://<project-ref>.supabase.co/storage/v1/object/public/product-images/products/probe.jpg" | grep -i access-control
curl -s -o /dev/null -D - -H "Origin: http://localhost:5000" "https://menu.chcoffee.com.sa/" | grep -i access-control
```

الأولى تجيب `Access-Control-Allow-Origin: *` (حتى على ردّ خطأ)، والثانية تجيب `200` بلا ترويسة عبور. فصور ضيف قديم على ذلك المضيف تسقط في بناء الويب حصرًا، والحلّ ليس في التطبيق: إمّا ترويسة من المضيف أو نقل الصورة إلى الدلو. لا تفتح بسببها تذكرة «رفع الصور معطّل».

### ترتيب الحذف

السطر يُفرَّغ أولًا ثم يُحذف الملف. العكس يترك صفًّا يشير إلى ملف لم يعد موجودًا: صورة مكسورة بلا رسالة. قارن بشقيقاتها: الفرع يكتب السطر قبل الملف، والفئات والباقات والبانرات كانت عكسه.

لا تَدين شاشة لأن وكلاء لم يعملوا: إن تعذّر التشغيل المتوازي صرّح به واقرأ المسار بنفسك.

## ٣. الإصلاح minimal

- التصغير عند الانتقاء لا بعد القراءة: `maxWidth`/`maxHeight`/`imageQuality` تُسلَّم للحزمة، فهي التي تُصغّر كانفس المتصفح؛ وقس `await picked.length()` أولًا لرفض الفارغ قبل حمله.
- ما تجاوز السقف لا يُرفض مباشرة: أصغره إلى JPEG على خيط منفصل (`compute`) وسمِّ ملفه بالامتداد الجديد، ثم ارفض إن بقي أكبر. الرفض المبكر على الحجم وحده يقتل صور PNG السليمة لأن المتصفح لا يطبّق جودة على PNG.
- معاينة تُبنى مرة واحدة عند الفتح وتُخزَّن كبايت ثابتة؛ كيان `MemoryImage` مبني على نفس المتجهات لا يُفكّ من جديد عند كل `setState`.
- الترميز الثقيل يبقى عند الحفظ فقط، ولا يُعاد في كل إطار؛ وأيّة قاعدة عمل ثقيلة تحتاج خيطًا منفصلًا تُذكر كانفتاح لا تُغلقه ضمنيًا.
- رسالة الخطأ: استثناءات الصور تحمل نصًّا جاهزًا للعرض (`AdminProductException.toString()` هو الرسالة)؛ لا تلصقها خلف «تعذّر فتح الصورة».
- أي ترحيلة مقترحة للقاعدة تبقى Suggested/Created بلا تطبيق، وتذكر صراحةً ما لم تغيّره (السياسات، سقف الدلو، الأدوار).

## ٤. البوابات والاختبار

```
dart format lib test
flutter analyze --no-pub lib test
flutter test test/admin_image_picker_test.dart test/category_image_write_test.dart test/admin_product_images_test.dart test/product_image_gallery_test.dart
flutter test
```

اختبر بملف حقيقي من كاميرا هاتف (٨ ميغابكسل فأكثر) لا بصورة مولّدة صغيرة: سقف الأضلاع لا يظهر أثره إلا عليها. ثم: فئة، منتج (إضافة + استبدال + تحرير إطار)، باقة، بانر، فرع — ومن وضع ليلي وعربية RTL، لأن المعاينة هي ما يتجمّد أولًا.
