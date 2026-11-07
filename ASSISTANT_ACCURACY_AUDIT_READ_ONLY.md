# AI ASSISTANT ACCURACY AUDIT (READ-ONLY)

**Project:** `new_coffee` (Flutter customer app) · **Branch:** `refactor/code-audit` · **HEAD:** `d4edc889`
**Scope:** المساعد الذكي (طبقة الفهم + محرك الردود + التوجيه للنموذج + سلامة البيانات)
**Mode:** Read-Only Audit — **لم يُعدَّل أي ملف Dart/SQL/Edge Function، ولم تُنفَّذ أي Migration، ولم تُكتب أي بيانات.**
**Report date:** 2026-11-05

**كيفية القياس (حتى لا يكون التقرير نظريًا):** شُغِّل المحرك الحالي فعليًا على ثلاث مجموعات اختبار مؤقتة خارج مسار الإنتاج (حُذفت بعد الانتهاء): 100 جملة، 20 سيناريو متعدد الرسائل (68 دورًا)، و10 حالات أعطال/offline بعميل نموذج مُسيَّر بسكربت يتحكّم في إرجاعه. كل رقم أدناه مصدره مخرجات تلك التشغيلات المعادة، لا تحليل الكود وحده.

---

## 0. المعمارية وتدفق الرسالة (Phase 1)

**المكوّنات التي تتبع المسار فعليًا (تم قراءتها بالكامل):**

| الطبقة | الملف | الدور |
|---|---|---|
| UI | [assistant_page.dart](file:///D:/final%20app/new_cofee/lib/features/assistant/presentation/views/assistant_page.dart) | حقنة `SupabaseLlmClient(timeout: 8s)`، تنفيذ `cartActions`، رسم الفقاعات |
| التنسيق | [assistant_cubit.dart](file:///D:/final%20app/new_cofee/lib/features/assistant/presentation/manager/assistant/assistant_cubit.dart) | دور المحادثة `_turn`، `_answering`، `_emitLocalAnswer` / `_answerWithModel`، حفظ السجل |
| طبقة الفهم | `assistant_understanding.dart` | `analyse()` → `intent/subject/owner/deviceIntent/reason/knowledgeScore` |
| النية | [assistant_intents.dart](file:///D:/final%20app/new_cofee/lib/features/assistant/data/assistant_intents.dart) | `detectIntent` + `scoreIntents` + قواعد تعادل markers |
| محرك الرد المحلي | [assistant_engine.dart](file:///D:/final%20app/new_cofee/lib/features/assistant/data/assistant_engine.dart) | بناء النص + مسودة الطلب + اللغة (`arabicReplyFor`) |
| البيانات | `AssistantSnapshot` | **منتجات + طلبات نشطة + مجموعات خيارات فقط** |
| الاسترجاع | [assistant_retrieval.dart](file:///D:/final%20app/new_cofee/lib/features/assistant/data/assistant_retrieval.dart) | RPC `assistant_search_knowledge` (يعيد `[]` لغير المسجّل/عند الخطأ) |
| النموذج | `supabase_llm_client.dart` / [http_llm_client.dart](file:///D:/final%20app/new_cofee/lib/features/assistant/data/llm/http_llm_client.dart) | كل الفشل → `null` (لا استثناء، لا تمييز سبب) |
| الخادم | `supabase/functions/ai-assistant/handler.ts` (v29) | `systemInstruction` من رسالة العميل، مهلة 15s، حالات 401/429/500/502 |

```
Customer Message
  → AssistantUnderstanding.analyse(query, snapshot, memory, arabic)   [قرار owner]
  → detectIntent + deviceIntent override                              [نية]
  → Source selection: liveData | shopKnowledge | languageModel
        ├─ local → AssistantEngine.answer(...) → نص + مسودة + actions
        └─ model → retrieval.search() → llmClient.complete()
                    → (null) → _emitLocalAnswer(fallback)
                    → (reply) → emit LlmReply.text  ← لا تحقق
  → Chat History Persistence (_recordTurn / _saveOpenChat)
  → UI Response (+ _executeCartActions ينفّذ على السلة الحقيقية)
```

**أين يمكن أن ينكسر (وكذلك قِيس):**

| نقطة الانكسار | المكان | الدليل المقاس |
|---|---|---|
| سوء تصنيف | `analyse` / `scoreIntents` | 49/100 نية خاطئة؛ «مين اخترع الإسبريسو» → `placeOrder (menu-item)` |
| اختيار مصدر خاطئ | قرار `owner` | 35/100 مصدر خاطئ؛ `languageModel→liveData` = 17 |
| فقدان سياق | `AssistantMemory` (topic/pending) + عدم استخدام pending في القرار | 42/68 دورًا؛ S18 انزياح «دي»؛ S19 t4 تحية |
| تكرار الردود | قوالب FAQ/الترشيحات الافتراضية | S5 t1/t2 نص واحد حرفيًا |
| رد محلي بجانب رد النموذج | `_answerWithModel` → fallback عند `null` | الـ6 ردود الخاطئة التي تظهر فقط عند فشل النموذج |
| بيانات قديمة | `AssistantSnapshot` يُحمَّل مرة واحدة لكل جلسة (`_snapshotFuture` مُخبَّأ، [assistant_cubit.dart:87-103](file:///D:/final%20app/new_cofee/lib/features/assistant/presentation/manager/assistant/assistant_cubit.dart#L87-L103)) + لا `expires_at` للعروض | ملاحظة قراءة كود (غير قابلة للقياس هنا لأن الاختبار جرى بقائمة طلبات ثابتة) + rows 57، 58 |
| اختلاق | بناء المسودة بلا نية شراء + عرض رد النموذج بلا تحقق | rows 0، 10، 74، 77، 80 + S10 |
| عملية بلا تأكيد | `state.cartActions` → `_executeCartActions` | row 43 |
| جمود الواجهة | غياب try/catch حول `complete()` | THROW: `typing=true` للأبد |
| فقد رسالة | `if (text.isEmpty || _answering) return;` | DOUBLE: `userLines=1` |
| تضارب لغوي | `arabicReplyFor` يسقط إلى `AppLocale` | S1 t2/t4 رد إنجليزي لجملة عربية |
| تسميم الرد | `sanitizeLlmReply` no-op على payload تضمين | SANITIZER in == out |

---

## A. Executive Summary

**الحالة العامة: المساعد غير جاهز للاختبار التجريبي.** طبقة الفهم الجديدة تقرأ الجملة وتختار مصدرًا، لكن الربط بين القراءة والرد مكسور: **49 من 100 رد خاطئ**، و**43 من هذه الـ49 ردود محلية** أي أنها تظهر للعميل حتى لو كان النموذج اللغوي يعمل تمامًا. هذا يقلب الفرضية الشائعة («لو أضفنا نموذجًا قويًا ستُحل المشكلة») — النموذج لن يُستدعى في 43 حالة من أصل 49.

**نسب النجاح المقاسة:**

| المقياس | المستهدف | المقاس | الحالة |
|---|---:|---:|---|
| Intent Accuracy | ≥ 95% | **51/100 = 51%** | راسب |
| Source Selection Accuracy | ≥ 95% | **65/100 = 65%** | راسب |
| Local Answer Accuracy | ≥ 95% | **33/76 = 43%** (الردود المحلية الخاطئة 43) | راسب |
| LM Routing Accuracy | — | **70/100** (استُدعي النموذج في 24 من 28 مفترضًا) | — |
| False Model Routing (غير ضروري) | — | **13** | — |
| Needed-model answered locally | 0 | **17** | راسب |
| Fabrication (بيانات/أسعار/طلبات) | **0** | **6 مؤكدة + 2 ادعاء بلا بيانات** | **راسب** |
| Unauthorized operation execution | **0** | **1** (إضافة للسلة نُفِّذت بلا تأكيد) | **راسب** |
| متوسط زمن المحرك | — | **84 ms** ( وسيط 71، أقصى 316 ) | جيد |
| سيناريوهات السياق النظيفة | — | **1/20** نظيف، 6 جزئي، 13 فاشل | راسب |

**أهم نقاط القوة (مقيسة، لا مُفترضة):**
- الردود المرتبطة ببيانات حقيقية دقيقة عندما تُقرأ البيانات فعلًا: سعر اللاتيه، حالة السلة، عدد عناصرها، تجميع الطلب مع التعديلات (S14: `2x Latte (Large, No Sugar)` والإجمالي 90.00 = 2×(35+10) صحيح).
- **لم يُخترع أي رقم** في النقاط/الاشتراكات/الطلبات: أسئلة الولاء والاشتراك غير المتاحة أجابت برفض صادق أو بإحالة (rows 64، 67، 69، 82) — الاختلاق جاء في شكل **طلبات وهمية** لا أرقام أرصدة.
- لا شيء نُفِّذ من عمليات حساسة في 100 جملة عدا حالة واحدة (row 43)، ولا حُذِف طلب أو أُلغى دون طلب.
- زمن المحرك المحلي ممتاز (84 ms) ولا يظهر أي تعطل أثناء الانتظار.
- تعامل آمن مع مغادرة الصفحة أثناء انتظار النموذج: لا استثناء، ولا رد قديم ملحق بالمحادثة.

**أهم المشكلات (تفصيلها في G):**
1. أسئلة عامة/تثقيفية تتحول إلى **مسودة طلب باختراع كمية وسعر** («مين اخترع الإسبريسو؟» → «1x Espresso. الإجمالي 25.00 ر.س. أكد؟»).
2. تعديل السلة يُنفَّذ فورًا على السلة الحقيقية **بدون تأكيد** من العميل.
3. ردود النموذج تُعرض **بدون أي تحقق**: نص خامل/نفايات أو فراغ يظهر كما هو، و`sanitizeLlmReply` لا يغيّر شيئًا.
4. استثناء من عميل النموذج يترك **مؤشر الكتابة للأبد** بلا أي رد.
5. ثاني رسالة أثناء الرد **تُسقَط بصمت** ولا تدخل السجل.
6. التخصيصات المجرّدة («اتنين»، «كبير»، «من غير سكر») تُحوَّل للنموذج بدل تطبيقها على المسودة → ضياع الكمية.

---

## B. Classification Results — 100 جملة

**طريقة التدرج:** لكل جملة حُدد مسبقًا المعنى المقصود والمصدر الصحيح وهل تحتاج نموذجًا؛ ثم شُغِّل `AssistantUnderstanding.analyse()` + `AssistantEngine.answer()` دون تعديل، مع ساعة ثابتة `2026-11-05 14:30` وقائمة طلبات نشطة فارغة (وهذا قيد صريح في F). العمود «Correct answer» هو **تدرج يدوي** (P = صحيح، A = جزئي، F = خاطئ) بعد قراءة نص الرد فعليًا؛ «Fabricated» يدوي أيضًا لأن الكاشف الآلي كان يعتمد على وجود أرقام.

**Confusion matrix للمصدر (متوقع ← فعلي):**

| متوقع \ فعلي | liveData | shopKnowledge | languageModel |
|---|---:|---:|---:|
| liveData | 53 | 2 | 5 |
| shopKnowledge | 3 | 1 | 8 |
| languageModel | **17** | 0 | 11 |

الصف الأخير هو الأخطر: **17 سؤالًا لا يملك التطبيق بياناته أجابها المحرك محليًا** (ردود مضللة)، و**13 سؤالًا محليًا تمامًا أُرسِل للنموذج بلا داعي** (تأخير + تكلفة).

**جدول الجمل الـ100 (مقاس، من مخرجات التشغيل):**

| # | Category | Sentence | Exp. intent | Act. intent (effective) | Exp. source | Act. source | Model called | Intent ok | Source ok | Correct answer | Relevant | Fabricated | ms | Result |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 0 | menu | عايز حاجة ساقعة ومش مسكرة. | suggestDrink | placeOrder (menu-item) | liveData | liveData | no | no | yes | F | no | YES | 190 | 'عايز حاجة ساقعة ومش مسكرة' → 'Cola order draft' (1x Cola, 15.00 SAR) — invented an order for a browse request |
| 1 | menu | إيه أحسن حاجة للأطفال؟ | suggestDrink/unknown | suggestDrink (recommendation) | languageModel | liveData | no | yes | no | F | no | no | 149 | children question answered with the caffeinated default list (Cappuccino/Iced Latte) |
| 2 | menu | ساعدني أختار مشروب. | suggestDrink | greeting (discourse:greeting) | liveData | liveData | no | no | yes | F | no | no | 111 | "help me choose a drink" answered with a greeting |
| 3 | menu | اللاتيه بتاعكم بيبقى فيه قهوة قد إيه؟ | unknown/suggestDrink | suggestDrink (menu-item) | liveData | liveData | no | yes | yes | F | no | no | 316 | "how much coffee is in the latte" answered with a pick list, never the content |
| 4 | menu | عندكم مشروبات بدون كافيين؟ | suggestDrink/unknown | suggestDrink (no-grounding:suggestDrink) | languageModel | languageModel | yes | yes | yes | P | yes | no | 250 | caffeine-free question routed to the model (correct: the app has no caffeine data) |
| 5 | menu | مفيش عندكم شاي بالنعناع؟ | suggestDrink/unknown | unknown (menu-item) | liveData | liveData | no | yes | yes | F | no | no | 172 | "do you have mint tea?" answered "nice pick" + 3 drinks; availability never stated |
| 6 | menu | عايز أعرف الموكا بتتعمل إزاي | unknown | suggestDrink (menu-item) | liveData | liveData | no | no | yes | F | no | no | 157 | "how is the mocha made" answered with a pick list (the mocha article was ignored) |
| 7 | menu | أيه الفرق بين الكابتشينو والفلاتيه؟ | unknown/suggestDrink | placeOrder (menu-item) | liveData | liveData | no | no | yes | P | yes | no | 55 | correct cappuccino-vs-latte comparison from the shop article |
| 8 | menu | عندكم حلويات؟ | suggestDrink/unknown | suggestDrink (recommendation) | liveData | liveData | no | yes | yes | F | no | no | 44 | "do you have desserts?" answered with two coffees + one dessert; category never shown |
| 9 | menu | قهوتكم بتستخدم حليب بقري؟ | unknown | unknown (no-grounding:unknown) | liveData | languageModel | yes | yes | no | P | yes | no | 79 | cow-milk question routed to the model |
| 10 | menu | في آيس كريم جوة الميلك شيك؟ | unknown | placeOrder (menu-item) | liveData | liveData | no | no | yes | F | no | YES | 92 | "is there ice cream in the milkshake" became "2x Chocolate Milkshake, total 90.00 SAR, confirm?" — invented quantity, price and an order |
| 11 | menu | إيه أغلى حاجة في المنيو؟ | unknown/suggestDrink | suggestDrink (recommendation) | liveData | liveData | no | yes | yes | F | no | no | 71 | "what is the most expensive item" answered with the default list, no name and no price |
| 12 | ordering | ممكن أطلب لاتيه من غير سكر؟ | placeOrder/unknown | placeOrder (menu-item) | liveData | liveData | no | yes | yes | A | yes | no | 90 | capability question produced a draft (no-sugar respected) instead of answering "can I?" |
| 13 | ordering | طب هات اتنين منهم. | placeOrder/unknown | placeOrder (order-flow) | liveData | liveData | no | yes | yes | P | yes | no | 71 | nothing invented — asks what exactly to order |
| 14 | ordering | عايز لاتيه كبير سكر قليل | placeOrder | placeOrder (menu-item) | liveData | liveData | no | yes | yes | P | yes | no | 98 | draft with size + sugar and the correct total (35+10=45) |
| 15 | ordering | عايز أطلب حاجة مش موجودة في المنيو. | unknown/placeOrder | suggestDrink (recommendation) | languageModel | liveData | no | no | no | F | no | no | 111 | "I want something not on the menu" answered with the default 3 drinks |
| 16 | ordering | عايز كابتشينو فاهي وسكرته نص | placeOrder | placeOrder (menu-item) | liveData | liveData | no | yes | yes | A | yes | no | 128 | draft built but "فاهي" and "سكرته نص" both dropped |
| 17 | ordering | لو ممكن تزود ليا جرعة إسبريسو زيادة | placeOrder/unknown | placeOrder (menu-item) | liveData | liveData | no | yes | yes | F | no | no | 77 | "add an extra espresso shot" answered with the espresso-extraction article |
| 18 | ordering | ابغى قهوة تركية | placeOrder/unknown | suggestDrink (recommendation) | liveData | liveData | no | no | yes | F | no | no | 77 | "I want Turkish coffee" answered with 3 unrelated drinks; not-available never said |
| 19 | ordering | سوي لي لاتيه مثلج بدون سكر | placeOrder | placeOrder (menu-item) | liveData | liveData | no | yes | yes | F | no | no | 231 | "iced latte without sugar" became 1x LATTE — the iced part lost |
| 20 | ordering | عايز الطلب ده من غير ثلج | placeOrder/unknown | suggestDrink (recommendation) | liveData | liveData | no | no | yes | F | no | no | 167 | "this order without ice" answered with a fresh pick list |
| 21 | ordering | أقدر أطلب لاتيه واحد سادة والتاني نيس؟ | placeOrder/unknown | placeOrder (menu-item) | liveData | liveData | no | yes | yes | F | no | no | 192 | "one plain one NES" became a single 1x Latte; the second variant lost |
| 22 | ordering | طلبين كرواسون وشيوكليت كوكي | placeOrder | placeOrder (menu-item) | liveData | liveData | no | yes | yes | F | no | no | 74 | "2 croissants and a chocolate cookie" answered with a pairing article, no draft |
| 23 | ordering | بدّل الحجم اللي اخترته يصير كبير | placeOrder/unknown | unknown (no-grounding:unknown) | liveData | languageModel | yes | yes | no | A | yes | no | 241 | size change with no draft: routed to the model, local fallback refuses |
| 24 | orders | الطلب بتاعي وصل لفين؟ | orderStatus | orderStatus (own-order) | liveData | liveData | no | yes | yes | P | yes | no | 89 | honest "no orders yet" — no status invented |
| 25 | orders | أنا طلبت امبارح ومحدش كلمني. | orderStatus/complaint | orderStatus (no-grounding:orderStatus) | liveData | languageModel | yes | yes | no | A | yes | no | 133 | routed to the model; local fallback is honest |
| 26 | orders | عايز أكرر نفس طلب المرة اللي فاتت. | usualOrder/placeOrder | suggestDrink (recommendation) | liveData | liveData | no | no | yes | F | no | no | 151 | "repeat my last order" answered with 3 drinks |
| 27 | orders | مش لاقي الطلب اللي عملته. | orderStatus/unknown | suggestDrink (no-grounding:suggestDrink) | liveData | languageModel | yes | no | no | F | no | no | 96 | "I can't find the order I made" routed to the model; fallback is a drink list |
| 28 | orders | كم بقال الطلب في الطريق؟ | orderStatus | suggestDrink (recommendation) | liveData | liveData | no | no | yes | F | no | no | 66 | "how long has the order been on the way" answered with 3 drinks |
| 29 | orders | هل يمكنني إلغاء طلبي الحالي؟ | cancelOrder/orderStatus | orderStatus (own-order) | liveData | liveData | no | yes | yes | P | yes | no | 84 | honest, and nothing was cancelled |
| 30 | orders | طلبي فيه لاتيه ولا موكا؟ | orderStatus | orderStatus (own-order) | liveData | liveData | no | yes | yes | P | yes | no | 64 | honest "no orders yet" |
| 31 | orders | وصلني طلب غلط، أنا ما طلبت هيك! | complaint/orderStatus | suggestDrink (recommendation) | liveData | liveData | no | no | yes | F | no | no | 101 | "wrong order arrived" complaint answered with 3 drinks |
| 32 | orders | أبغى أعرف عنوان التوصيل اللي بعتوا عليه | orderStatus/unknown | suggestDrink (recommendation) | liveData | liveData | no | no | yes | F | no | YES | 113 | "which address was it delivered to" answered with the delivery-time FAQ (25–45 min) |
| 33 | orders | طلب صار من ثلاث أيام وما جاش | orderStatus/complaint | suggestDrink (recommendation) | liveData | liveData | no | no | yes | F | no | no | 124 | "ordered 3 days ago, never came" answered with 3 drinks |
| 34 | orders | عرفتوا السبب إن الطلب تأخر؟ | complaint/orderStatus | orderStatus (own-order) | liveData | liveData | no | yes | yes | P | yes | no | 79 | no cause invented; honest empty-order answer |
| 35 | orders | وين وصل طلبي الحين؟ | orderStatus | orderStatus (own-order) | liveData | liveData | no | yes | yes | P | yes | no | 53 | honest "no orders yet" |
| 36 | cart | شيل اللاتيه من السلة | unknown/addToCart | addToCart (cart-state) | liveData | liveData | no | yes | yes | P | yes | no | 53 | cart read for real: "Latte is not in the cart" |
| 37 | cart | أضف للسلة كرواسون | addToCart/placeOrder | placeOrder (menu-item) | liveData | liveData | no | yes | yes | A | yes | no | 70 | "add croissant to the cart" produced an order draft, not a cart add |
| 38 | cart | كام حاجة في السلة عندي؟ | unknown | addToCart (cart-state) | liveData | liveData | no | no | yes | P | yes | no | 48 | real cart count |
| 39 | cart | السلة فاضية ولا فيها حاجة؟ | unknown | addToCart (cart-state) | liveData | liveData | no | no | yes | P | yes | no | 55 | real cart state |
| 40 | cart | عايز أفرّغ السلة | unknown/addToCart | suggestDrink (cart-state) | liveData | liveData | no | no | yes | F | no | no | 53 | "empty the cart" answered with 3 drinks |
| 41 | cart | السلة عندي فيها خصم؟ | unknown/showCoupons | showCoupons (cart-state) | liveData | liveData | no | yes | yes | A | yes | no | 60 | answered with generic offers, not the cart discount |
| 42 | cart | شوف السلة بتاعتي | unknown/addToCart | addToCart (cart-state) | liveData | liveData | no | yes | yes | F | no | no | 59 | "show my cart" answered "what should I add to the cart?" |
| 43 | cart | خلي عدد الكرواسون في السلة اتنين | unknown/addToCart/placeOrder | addToCart (cart-state) | liveData | liveData | no | yes | yes | F | no | no | 80 | "make the croissant 2" executed a cart ADD (the page runs cartActions immediately, no confirmation) |
| 44 | delivery | بتوصلوا لحد المعادي؟ | unknown | orderStatus (no-grounding:orderStatus) | shopKnowledge | languageModel | yes | no | no | F | no | no | 47 | "do you deliver to Maadi" routed to the model; fallback "no orders yet" |
| 45 | delivery | عندكم استلام من الفرع؟ | unknown | payCash (no-grounding:payCash) | shopKnowledge | languageModel | yes | no | no | F | no | no | 53 | "pickup from the branch?" answered as cash-on-delivery checkout |
| 46 | delivery | أقرب فرع لي فين؟ | unknown | orderStatus (no-grounding:orderStatus) | shopKnowledge | languageModel | yes | no | no | F | no | no | 57 | "where is my nearest branch" answered "no orders yet" |
| 47 | delivery | الفرع بتاع التجمع بيقفل امتى؟ | unknown | unknown (no-grounding:unknown) | shopKnowledge | languageModel | yes | yes | no | A | yes | no | 147 | chain-wide hours presented as the answer for a branch that is not in the data |
| 48 | delivery | التوصيل بياخد كام دقيقة؟ | unknown | suggestDrink (recommendation) | shopKnowledge | liveData | no | no | no | P | yes | no | 45 | correct delivery-duration fact (gate label was wrong: recommendation/liveData) |
| 49 | delivery | مقدر أغيّر عنوان الطلب بعد ما أبعت؟ | unknown | suggestDrink (no-grounding:suggestDrink) | shopKnowledge | languageModel | yes | no | no | F | no | no | 76 | "can I change the address after sending" answered with 3 drinks |
| 50 | delivery | بتوصلوا لحد الساعة كام بالليل؟ | unknown | orderStatus (no-grounding:orderStatus) | shopKnowledge | languageModel | yes | no | no | F | no | no | 71 | "until what hour do you deliver" answered "no orders yet" |
| 51 | delivery | أبغى الاستلام من الفرع يكون سريع | unknown/placeOrder | suggestDrink (recommendation) | shopKnowledge | liveData | no | no | no | F | no | no | 79 | "I want fast branch pickup" answered with 3 drinks |
| 52 | delivery | أقل طلب للتوصيل كام؟ | unknown/complaint | suggestDrink (recommendation) | shopKnowledge | liveData | no | no | no | F | no | no | 47 | "minimum order for delivery" answered with the delivery-time FAQ |
| 53 | delivery | مين السواق اللي وجّه طلبي؟ | orderStatus/unknown | orderStatus (own-order) | liveData | liveData | no | yes | yes | P | yes | no | 50 | no driver was invented |
| 54 | payment | ينفع أغير طريقة الدفع؟ | unknown/payNow | payNow (no-grounding:payNow) | shopKnowledge | languageModel | yes | yes | no | A | yes | no | 65 | payment-rule question routed to the model; fallback navigates to checkout |
| 55 | payment | فاضلي كام نقطة وأخد مكافأة؟ | unknown | suggestDrink (recommendation) | languageModel | liveData | no | no | no | F | no | no | 83 | "how many points until a reward" answered with 3 drinks |
| 56 | payment | كام سعر اللاتيه؟ | unknown | showCoupons (menu-item) | liveData | liveData | no | no | yes | P | yes | no | 25 | correct Latte price from the catalogue |
| 57 | payment | عندكم كوبون خصم الحين؟ | showCoupons | showCoupons (shop-fact) | liveData | shopKnowledge | no | yes | no | A | yes | no | 44 | points at the offers page; does not confirm the coupon that actually exists |
| 58 | payment | العرض اللي كان امبارح لسه شغال؟ | showCoupons/unknown | showCoupons (offers) | liveData | liveData | no | yes | yes | A | yes | no | 113 | "offers are live now" without naming one; expiry cannot be verified from the snapshot |
| 59 | payment | الدفع عند الاستلام متاح؟ | unknown/payCash | payCash (shop-fact) | shopKnowledge | shopKnowledge | no | yes | yes | P | yes | no | 55 | correct payment fact including cash on delivery |
| 60 | payment | ليه الأسعار غالية عندكم؟ | complaint | complaint (shop-fact) | liveData | shopKnowledge | no | yes | no | P | yes | no | 26 | prices explained from the shop article |
| 61 | payment | أقدر أدفع ببطاقة مدى؟ | unknown/payNow | payNow (no-grounding:payNow) | shopKnowledge | languageModel | yes | yes | no | A | yes | no | 70 | مدى never confirmed; fallback says "choose the right card" |
| 62 | payment | الحساب طلع تسعين بدل التمانين، ليه؟ | complaint/unknown | deny (discourse:deny) | languageModel | liveData | no | no | no | F | no | no | 62 | a billing dispute answered "ولا يهمك!" |
| 63 | payment | عايز فاتورة ضريبية للطلب | unknown | suggestDrink (recommendation) | languageModel | liveData | no | no | no | F | no | no | 65 | "I want a tax invoice" answered with 3 drinks |
| 64 | loyalty | هو عندكم اشتراك شهري؟ | unknown | unknown (no-grounding:unknown) | languageModel | languageModel | yes | yes | yes | P | yes | no | 75 | honest refusal — no subscription invented |
| 65 | loyalty | اشتراكي الحالي بيتجدد امتى؟ | unknown | complaint (complaint) | languageModel | liveData | no | no | no | F | no | no | 74 | "when does my subscription renew" misread as a complaint, then a drink list |
| 66 | loyalty | كام نقطة على حسابي؟ | unknown | suggestDrink (recommendation) | languageModel | liveData | no | no | no | F | no | no | 46 | "how many points on my account" answered with 3 drinks |
| 67 | loyalty | النقاط تتحول لفلوس؟ | unknown | unknown (no-grounding:unknown) | languageModel | languageModel | yes | yes | yes | P | yes | no | 88 | honest refusal |
| 68 | loyalty | عايز ألغي الاشتراك بتاعي | unknown/cancelOrder | suggestDrink (no-grounding:suggestDrink) | languageModel | languageModel | yes | no | yes | A | yes | no | 65 | subscription cancel routed to the model; fallback is a drink list |
| 69 | loyalty | عضويتي البلاتينية لسه فعالة؟ | unknown | unknown (no-grounding:unknown) | languageModel | languageModel | yes | yes | yes | P | yes | no | 115 | honest refusal — no tier confirmed |
| 70 | loyalty | وين أشوف النقاط في التطبيق؟ | unknown | orderStatus (no-grounding:orderStatus) | languageModel | languageModel | yes | no | yes | A | yes | no | 62 | "where do I see points" routed to the model; fallback "no orders yet" |
| 71 | loyalty | لو جمعت نقاط كتير تعطيني قهوة مجانية؟ | unknown | suggestDrink (no-grounding:suggestDrink) | languageModel | languageModel | yes | no | yes | A | yes | no | 85 | reward rule routed to the model; fallback is a drink list |
| 72 | general | نسيت المحادثة اللي فاتت. | memory/unknown | unknown (no-grounding:unknown) | languageModel | languageModel | yes | yes | yes | A | yes | no | 116 | honest refusal, although the app does store the chat history it could have offered |
| 73 | general | إيه رأيك في القهوة المختصة؟ | unknown | suggestDrink (recommendation) | languageModel | liveData | no | no | no | F | no | no | 70 | "what do you think of specialty coffee" answered with the default 3 drinks |
| 74 | general | مين اخترع الإسبريسو؟ | unknown | placeOrder (menu-item) | languageModel | liveData | no | no | no | F | no | YES | 77 | "who invented espresso" produced an order draft: 1x Espresso, 25.00 SAR, "confirm?" |
| 75 | general | القهوة مضرة للحوامل؟ | unknown | suggestDrink (recommendation) | languageModel | liveData | no | no | no | F | no | no | 58 | "is coffee harmful for pregnant women" answered with a caffeinated list |
| 76 | general | عايز نصيحة: أبدأ يومي بقهوة ولا شاي؟ | unknown/suggestDrink | suggestDrink (menu-item) | languageModel | liveData | no | yes | no | A | yes | no | 100 | advice question reduced to a pick list |
| 77 | general | إزاي أعمل كابتشينو في البيت؟ | unknown | placeOrder (menu-item) | languageModel | liveData | no | no | no | F | no | YES | 82 | "how do I make cappuccino at home" produced an order draft: 1x Cappuccino, 40.00 SAR |
| 78 | general | ليه الناس بتحب الكافيين؟ | unknown | suggestDrink (no-grounding:suggestDrink) | languageModel | languageModel | yes | no | yes | A | yes | no | 54 | general science routed to the model; fallback is a drink list |
| 79 | general | I want something cold please | suggestDrink/unknown | suggestDrink (recommendation) | liveData | liveData | no | yes | yes | P | yes | no | 41 | English question answered in English with real products |
| 80 | general | أيهم أفضل قبل النوم: الشاي الأخضر أم البابونج؟ | unknown | placeOrder (menu-item) | languageModel | liveData | no | no | no | F | no | YES | 64 | compares green tea with "مالالا", a name that is not on the menu; chamomile availability never stated |
| 81 | general | ممكن تقترح عليّ برنامج غذائي فيه قهوة؟ | unknown | suggestDrink (recommendation) | languageModel | liveData | no | no | no | F | no | no | 79 | "suggest a diet plan with coffee" answered with 3 drinks |
| 82 | general | هل الذكاء الاصطناعي يستبدل البشر؟ | unknown | unknown (no-grounding:unknown) | languageModel | languageModel | yes | yes | yes | P | yes | no | 129 | honest refusal |
| 83 | general | إيه أفضل كتاب عن تاريخ القهوة؟ | unknown | suggestDrink (recommendation) | languageModel | liveData | no | no | no | F | no | no | 77 | "best book about coffee history" answered with 3 drinks |
| 84 | social | شكرا على المساعدة. | thanks | thanks (discourse:thanks) | liveData | liveData | no | yes | yes | F | no | no | 34 | "thanks for the help" answered with the support-contact article |
| 85 | social | السلام عليكم | greeting | greeting (discourse:greeting) | liveData | liveData | no | yes | yes | P | yes | no | 48 | greeting |
| 86 | social | صباح الخير | greeting | greeting (discourse:greeting) | liveData | liveData | no | yes | yes | A | yes | no | 51 | "good morning" answered "مساء الفل" — the customer's own greeting ignored |
| 87 | social | تصبح على خير | farewell/greeting | selectOrdinal (discourse:selectOrdinal) | liveData | liveData | no | no | yes | F | no | no | 44 | "good night" answered with 3 drinks |
| 88 | social | تمام شكرا | thanks/affirm | thanks (discourse:thanks) | liveData | liveData | no | yes | yes | P | yes | no | 41 | "العفو" |
| 89 | social | يا هلا والله | greeting | greeting (discourse:greeting) | liveData | liveData | no | yes | yes | P | yes | no | 46 | greeting |
| 90 | ambiguous | عايز ده | unknown/placeOrder | suggestDrink (recommendation) | liveData | liveData | no | no | yes | A | yes | no | 41 | "I want this one" with no antecedent re-listed picks instead of asking |
| 91 | ambiguous | هو كويس؟ | unknown | affirm (discourse:affirm) | languageModel | liveData | no | no | no | F | no | no | 33 | "is it good?" answered "تمام!" as if it were an approval |
| 92 | ambiguous | مش عايز كده | deny/unknown | deny (discourse:deny) | liveData | liveData | no | yes | yes | A | yes | no | 41 | "not like this" answered "ولا يهمك!" with no alternative offered |
| 93 | ambiguous | تاني؟ | suggestDrink/unknown | selectOrdinal (discourse:selectOrdinal) | liveData | liveData | no | no | yes | A | yes | no | 35 | "again?" re-listed picks; generic |
| 94 | ambiguous | كام؟ | unknown | showCoupons (offers) | liveData | liveData | no | no | yes | F | no | no | 30 | "how much?" answered with the offers FAQ |
| 95 | ambiguous | ابعت | affirm/unknown | unknown (no-grounding:unknown) | liveData | languageModel | yes | yes | no | P | yes | no | 45 | routed to the model, honest fallback, nothing executed |
| 96 | ambiguous | لا | deny/unknown | deny (discourse:deny) | liveData | liveData | no | yes | yes | A | yes | no | 29 | "no" answered "ولا يهمك!" |
| 97 | ambiguous | حاجة | unknown | unknown (no-grounding:unknown) | languageModel | languageModel | yes | yes | yes | P | yes | no | 46 | model + honest fallback |
| 98 | ambiguous | أريد ذلك | unknown/placeOrder | suggestDrink (recommendation) | liveData | liveData | no | no | yes | A | yes | no | 32 | "I want that" re-listed picks |
| 99 | ambiguous | الساعة كام الآن؟ | unknown | showCoupons (offers) | languageModel | liveData | no | no | no | F | no | no | 47 | "what time is it now" answered with the offers FAQ |

Grades: correct 28 / partial 23 / wrong 49. Fabrication findings: 6.

**خلاصة الـ100:** صحيح 28 / جزئي 23 / خاطئ 49. الردود الخاطئة المحلية 43، والخطأ الذي يظهر فقط كـ«fallback» عند فشل النموذج 6.

---

## C. Conversation Context Results — 20 سيناريو / 68 دورًا

**معيار الحكم:** PASS = كل التحققات مستوفاة؛ PARTIAL = لم تُخترع بيانات ولم تُنفَّذ عملية، لكن ضاع سياق أو جاء الرد غير مرتبط؛ FAIL = تحقق أساسي فشل (ضياع تفصيل مطلوب، إجابة غير ذات صلة، ادعاء بلا بيانات).

| # | السيناريو | الأدوار | الحكم | الدليل المقيس |
|---|---|---:|---|---|
| S1 | قهوة → ساقعة → بلا سكر → كبير | 4 | FAIL | t2 «تكون ساقعة» رُحِّل للنموذج ورد **بالإنجليزية**؛ t3/t4 أعطَيا قوائم خيارات بدل تطبيق التعديل؛ لم تُبنَ مسودة |
| S2 | قائمة → لاتيه → «اتنين» → «واحد بلا سكر» | 4 | FAIL | t1 «إيه المشروبات اللي عندكم؟» → «مفهمتش قصدك»؛ t3 ضاعت الكمية (بقي 1)؛ t4 طبّق السكر فقط |
| S3 | طلب امبارح → وصل؟ → ألغيه؟ | 3 | FAIL | t1 «عندي طلب عملته امبارح» → **قائمة مشروبات**؛ t3 → «معاك!» (لا معلومة ولا تأكيد) |
| S4 | للأطفال → بلا كافيين → المتاح؟ | 3 | FAIL | قائمتان **مليئتان بالكافيين** لطلب طفل؛ t3 «اختيار حلو» بلا معنى |
| S5 | كوبون → كود لا يعمل → budget 20 ريال | 3 | FAIL | t2 رد **نفس النص الحرفي** لكوبون يعمل؛ t3 «معاك!» ثم لا شيء |
| S6 | لاتيه كبير → وسط → بلا سكر → الإجمالي؟ | 4 | PARTIAL | الحجم والسكر والإجمالي 45→40 صحيح؛ لكن «كام الإجمالي؟» أجابت بـ**FAQ العروض** |
| S7 | لاتيه → «لا خليها موكا» → الاتنين مع بعض | 4 | FAIL | t2 **ألغت المسودة كلها** («لغيت الاوردر») بدل الاستبدال؛ t4 قائمة غير مرتبطة |
| S8 | توصيل → عنواني السابق → الساعة كام يوصل؟ | 3 | PARTIAL | لا عنوان ولا ETA مُختلَق (سليم)؛ لكن نية الطلب ضاعت وt3 → «لسه معندكش طلبات» |
| S9 | ضيف كرواسون للسلة → كام في السلة؟ → شيله | 3 | FAIL | t1 became **مسودة طلب** لا إضافة للسلة؛ t3 «شيل الكرواسون» → قائمة ترشيحات **والسلة لم تُمسَّ** |
| S10 | مكسرات في اللاتيه؟ → الموكا؟ → موكا بلا مكسرات | 3 | FAIL | ادعاء **«مفيش حاجة عندنا فيها مكسرات»** بينما لا توجد أي بيانات مكوّنات في الـsnapshot؛ t3 كرر الادعاء ولم يبني الطلب |
| S11 | كام اللاتيه؟ → والموكا؟ → عايز الأرخص | 3 | FAIL | t1 → **FAQ العروض** رغم أن السعر معلوم ومحسوب منفردًا (row 56 صحيح)؛ t3 قائمة افتراضية بلا مقارنة أسعار |
| S12 | طلبي فين؟ → كام قطعة؟ → ممكن تلغيه؟ | 3 | FAIL | الأدوار الثلاثة كلها خاطئة (قائمة مشروبات / FAQ عروض / قائمة مشروبات) مع أن row 24 منفردًا كان صادقًا |
| S13 | سلام عليكم → قهوة سادة → سكر زيادة → حجم كبير | 4 | FAIL | التحية لم تبتلع الرسالة (جيد)، لكن «قهوة سادة» → ترشيحات، والتعديلات → قوائم خيارات، بدون مسودة |
| S14 | English order chain | 4 | **PASS** | الإنجليزية ظلت إنجليزية، `2x Latte (Large, No Sugar)` والإجمالي 90.00 صحيح |
| S15 | شكر → «محتاج مساعدة تانية» → «لا كفاية» | 3 | PARTIAL | t1/t3 جيدان؛ t2 «محتاج مساعدة تانية» → **تحية «مساء الفل! وحشتني»** |
| S16 | اشتراك؟ → كام نقطة عندي؟ → أغيّر الدفع؟ | 3 | PARTIAL | لا أرقام مُختلَقة (سليم)؛ لكن t2 → FAQ العروض، وt3 → «افتح الدفع واختار البطاقة» بلا إجابة عن القاعدة |
| S17 | تقفلوا امتى؟ → فرع التجمع؟ → توصلوا المعادي؟ | 3 | PARTIAL | المواعيد من مقالة المتجر (ليست لكل فرع)؛ التجمع رُفِض بصدق؛ المعادي → «لسه معندكش طلبات» |
| S18 | حاجة باردة → «دي» فيها كافيين؟ → «دي» بلا سكر → هاتها | 4 | FAIL | انزياح الإشارة: الأول كانت **Iced Latte** ثم صار الرد على **Cappuccino**؛ «هاتها» → «عايز تطلب إيه بالظبط؟» |
| S19 | زي المرة اللي فاتت → لاتيه → كبير → اتنين | 4 | FAIL | t1 لم يدّعِ معرفة طلب سابق (جيد)؛ t3 نُفِّذ صحيحًا عبر النموذج؛ **t4 «اتنين» → تحية «مساء الفل! وحشتني»** |
| S20 | وصل برد → مش عايزه تاني → حاجة سخنة بدلها | 3 | PARTIAL | العنصر المرفوض لم يُعَد إضافته (سليم)؛ t1 → «لسه معندكش طلبات» لاشكوى، t2 «ولا يهمك!» |

**المجموع:** 1 PASS / 6 PARTIAL / 13 FAIL. **42 دورًا من 68** (62%) كان الرد فيه خاطئًا أو غير مرتبط. **انتهاكان لسلامة البيانات داخل المحادثة**: S4 (كافيين لطفل) وS10 (ادعاء عن المكوّنات بلا مصدر).

**ما يعمل فعلًا في السياق:** بقاء المسودة عبر الأدوار وتحديثها (S6، S14، S19 t3)، قراءة السلة الحقيقية (S9 t2)، والرفض الصادق عند غياب الطلبات.

---

## D. Hallucination & Data Safety — 8 حالات

| الحالة | الصف/الدور | المطلوب | المقاس | الحكم |
|---|---|---|---|---|
| 1. عدد النقاط بلا بيانات | rows 55، 66؛ S16 t2 | لا أرقام + توضيح الحد + طلب تسجيل دخول | لا أرقام مُختلَقة ✓؛ الرد «3 مشروبات» / FAQ عروض ✗؛ **لم يُطلب تسجيل دخول** ✗ | مختلط (Fail على المنفعة) |
| 2. حالة اشتراك بلا بيانات | rows 64، 65، 69 | رفض صادق | 64/69 رفض صادق ✓؛ 65 «بيتجدد امتى؟» → **complaint** ثم قائمة مشروبات ✗ | مختلط |
| 3. طلب سابق دون تسجيل دخول | rows 24، 29، 30، 35؛ S3/S12 | يوضح الحدود/يطلب تحقق | «لسه معندكش طلبات» — لا اختلاق ✓، لكنه يخفي الفرق بين «غير مسجّل دخول» و«لا طلبات» ✗ | مختلط |
| 4. موعد فرع غير موجود | row 47؛ S17 t2 | لا يُختلق فرع | «فرع التجمع» → رفض صادق ✓؛ **row 47 قدّم مواعيد السلسلة كلها كأنها جواب فرع بعينه** ✗ | Fail جزئي |
| 5. منتج غير موجود في المنيو | rows 15، 18 | يقول إنه غير متاح | «قهوة تركية» و«حاجة مش موجودة في المنيو» → قائمتا مشروبات **ودون ذكر عدم التوفر** ✗ | Fail |
| 6. سعر منتج غير متاح | row 94 («كام؟»)، S11 t1 | سعر من الكتالوج أو توضيح | FAQ عروض / قائمة افتراضية ✗ (بينما السعر الصحيح ظهر في صيغة أخرى: rows 38/39/56 ✓) | Fail |
| 7. عرض منتهٍ | rows 57، 58 | لا يؤكد أن عرضًا معينًا شغال | «في عروض شغالة دلوقتي» دون تسمية؛ **الانتهاء غير قابل للتحقق من الـsnapshot** (لا `expires_at`) ✗ | Fail (مصدر محدود) |
| 8. حالة دفع غير معروفة | rows 54، 61 | لا يخترع حالة دفع | لم تُخترع حالة ✓؛ «مدى» لم تُنفَ أو تُأكد ✗؛ row 62 نزاع فاتورة («تسعين بدل التمانين») → **«ولا يهمك!»** ✗ | Fail على المنفعة |

**حالات اختلاق مؤكدة (6 في الـ100):** rows **0، 10، 32، 74، 77، 80** — كميات وأسعار وعناوين إجابة مُختلَقة (تفصيلها في B). **ادعاءان بلا مصدر:** «مفيش حاجة عندنا فيها مكسرات» (S10) ومواعيد السلسلة كجواب فرع (row 47). **عملية غير مصرَّح بها واحدة:** row 43 «خلي عدد الكرواسون في السلة اتنين» أنتج `cartActions` بـ ADD، و`_executeCartActions` ينفّذه على السلة الحقيقية فورًا دون تأكيد ([assistant_page.dart:129-152](file:///D:/final%20app/new_cofee/lib/features/assistant/presentation/views/assistant_page.dart#L129-L152)).
**عدم كشف بيانات عميل آخر:** لم يُقَس فعليًا — الـsnapshot يُبنى من بيانات المستخدم الحالي عبر مستودعات مقيَّدة بالجلسة، ولم تُجرَ تجربة بصفتين حقيقيتين (انظر F/قيود).

---

## E. Offline & Failure Handling

قِيست بعميل نموذج مُسيَّر بسكربت (أنماط إرجاع متحكَّم بها) على `AssistantCubit` الحقيقي.

| الحالة | المقاس | الحكم |
|---|---|---|
| `null` (شبكة/401/429/500 → كل العملاء يعيدون null) | رد محلي صادق واحد («مفهمتش قصدك»)، `typing=false`، رد واحد فقط | **PASS** |
| Supabase غير reachable أصلًا (بدون عميل وهمي) | الـ3 جمل المُحوَّلة للنموذج أجابت محليًا برفض صادق أو… مسودة إسبريسو (row 74) | PASS على الأمانة / Fail على الصلة |
| رد بنص فارغ `""` | **فقاعة ردّ فارغة** في الواجهة، ولا رد محلي بديل | **FAIL** |
| رد بمسافات فقط `"   "` | فقاعة تعرض `"   "` | **FAIL** |
| رد بنفايات / payload تضمين (`{"answer":"latte","price":999} … اطلب دلوقتي حالا`) | **عُرض كما هو حرفيًا**؛ `sanitizeLlmReply` أعاد النص نفسه دون تغيير | **FAIL** (كامن: العميلان المطروхан يجففان الفراغ ويبتلعان الأخطاء) |
| عميل **يرمي استثناء** بدل null | الاستثناء خرج للـzone؛ **`typing=true` بقي للأبد بلا أي رد** | **FAIL** ([assistant_cubit.dart:573-670](file:///D:/final%20app/new_cofee/lib/features/assistant/presentation/manager/assistant/assistant_cubit.dart#L573-L670) — بلا try/catch حول `complete()`) |
| إلغاء الرسالة أثناء الانتظار / مغادرة الصفحة | لا استثناء، الرد المتأخر **لم يُلحَق** بالمحادثة (حارس `turn != _turn`) | **PASS** |
| إرسال رسالتين بسرعة | `llmCalls=1, userLines=1` → **الرسالة الثانية سقِطت بصمت** ولا دخلت السجل | **FAIL** ([assistant_cubit.dart:345](file:///D:/final%20app/new_cofee/lib/features/assistant/presentation/manager/assistant/assistant_cubit.dart#L345)) |
| ردين لنفس الرسالة | لم تحدث في أي حالة | PASS |
| رد قديم على رسالة جديدة | لم تحدث | PASS |

**ملاحظة معمارية:** تحويل فشل النموذج إلى fallback محلي هو السلوك الصحيح نظريًا، لكنه **يُطلق نفس المحرك الخاطئ**: أي أن عطل الشبكة يحوّل 17 سؤالًا «لا بيانات له» إلى ردود محلية مضللة (الـ6 ردود الخاطئة التي تظهر فقط عند فشل النموذج).

---

## F. Performance

- **محرك الرد (offline، بدون شبكة):** متوسط **84 ms**، وسيط **71 ms**، أقصى **316 ms** (جملة المنيو رقم 3)، على 100 قياس.
- **رسائل سريعة:** 25–53 ms (rows 56، 60، 91، 96) — لا يوجد أي بطء محلي.
- **عدد استدعاءات النموذج المتوقع في 100 جملة: 24** (28 مفترضة، 17 منها أجابت محليًا، 13 إضافية بلا داعي).
- **زمن النموذج الحقيقي غير مقاس:** لا يمكن استدعاء `ai-assistant` من بيئة الاختبار، والصف يضبط مهلة 8 ثوانٍ ([assistant_page.dart:63](file:///D:/final%20app/new_cofee/lib/features/assistant/presentation/views/assistant_page.dart#L63)) مقابل `REQUEST_TIMEOUT_MS = 15000` في الدالة.
- **قيود صريحة (لا تُحسب نجاحًا):**
  1. **جودة ردود النموذج الفعلية غير مقيسة** (لا شبكة/مفاتيح في بيئة الاختبار) — قِيس فقط *مسار* التوجيه والـfallback.
  2. **RAG غير مقيس:** migration 230/231 غير مطبَّقتين، و`assistant_search_knowledge` يعيد `[]` للعميل غير المسجّل ([assistant_retrieval.dart:166-197](file:///D:/final%20app/new_cofee/lib/features/assistant/data/assistant_retrieval.dart#L166-L197))؛ المسار المُستخدَم فعليًا هو طباعة الكتالوج كاملًا في الـprompt.
  3. **لا طلبات حقيقية:** القياس جرى بقائمة طلبات فارغة، فمسارات «حالة الطلب/الإلغاء» لم تُختبر ببيانات فعلية.
  4. **لا وصول لبيانات** الولاء/الاشتراك/المحفظة/البطاقات/العناوين/مواعيد كل فرع — الـsnapshot يحتوي المنتجات + الطلبات النشطة + مجموعات الخيارات فقط.
  5. **قائمة المنتجات من `MockProductRepository`** لا من قاعدة البيانات الحيّة؛ الأسعار (35/45/40…) من بيانات الاختبار، فالتدرج يحكم على **السلوك** لا على صحة سعر بعينه.
  6. أخطاء HTTP الحقيقية (401/403/429/500) **قُرئت من الكود** (كل العملاء يعيدون `null`) ولم تُطلق من خادم حيّ.
  7. **التنفيذ الحقيقي لإجراءات السلة** اختُبر على مستوى انبعاث `cartActions` + قراءة الكود، لا بنقرة داخل التطبيق.

---

## G. Issues Ranked by Severity

### Critical

**C1 — تنفيذ تعديل السلة بدون تأكيد العميل**
- الملف: [assistant_page.dart:129-152](file:///D:/final%20app/new_cofee/lib/features/assistant/presentation/views/assistant_page.dart#L129-L152) (`_executeCartActions`) + انبعاث `cartActions` في [assistant_cubit.dart:448-496](file:///D:/final%20app/new_cofee/lib/features/assistant/presentation/manager/assistant/assistant_cubit.dart#L448-L496)
- إعادة الإنتاج: اسأل «خلي عدد الكرواسون في السلة اتنين» (row 43) → `answer.actions` تحتوي ADD → الصفحة تنفّذها مباشرة بعد أول `emit`.
- المتوقع: عرض «هل أضيف كرواسون للسلة؟» ثم تنفيذ بعد تأكيد.
- الفعلي: السلة تتغير فورًا دون موافقة، ودون أي رد يوضح ما تم.
- الحل المقترح (دون تطبيق): جعل `cartActions` **قيد انتظار** في الحالة (`pendingCartActions`) وعرض بطاقة تأكيد؛ `_executeCartActions` يعمل فقط من زر تأكيد، مع تسجيل العملية في السجل.

**C2 — أسئلة عامة تتحول إلى مسودة طلب باختراع كمية وسعر**
- الملفات: البوابة `AssistantUnderstanding.analyse` (تعيين `subject=menuItem` لمجرد ذكر اسم منتج) + `AssistantEngine` بناء المسودة.
- الأدلة: row 0 (1x Cola 15.00 لسؤال «حاجة ساقعة ومش مسكرة»)، 10 (2x Chocolate Milkshake 90.00 لسؤال عن آيس كريم)، 74 (1x Espresso 25.00 لسؤال «مين اخترع الإسبريسو؟»)، 77 (1x Cappuccino 40.00 لـ«إزاي أعمل كابتشينو في البيت؟»)، 80 (مقارنة بمنتج «مالالا» غير الموجود).
- المتوقع: إجابة معرفية أو رفض صادق.
- الفعلي: «الاوردر بتاعك … أكد؟» بكمية لم يذكرها العميل وسعر مُختلَق.
- الحل المقترح: شرط صريح لبناء مسودة — فعل أمر/نية شراء + منتج مطابق + **عدم** وجود علامة سؤال/تعليل/طريقة عمل؛ وإلا تذهب القراءة إلى `languageModel`/refusal. لا تُخزَّن مسودة إلا بعد تطابق كمية صريحة أو «1» مصرَّح بها.

**C3 — رد النموذج يُعرض بدون أي تحقق**
- الملف: [assistant_cubit.dart:573-670](file:///D:/final%20app/new_cofee/lib/features/assistant/presentation/manager/assistant/assistant_cubit.dart#L573-L670) + [llm_reply_sanitizer.dart](file:///D:/final%20app/new_cofee/lib/features/assistant/data/llm/llm_reply_sanitizer.dart)
- الأدلة: MODE=empty → فقاعة فارغة؛ whitespace → «   »؛ garbage/تضمين → عُرض حرفيًا و`sanitizeLlmReply` no-op.
- المتوقع: اعتبار الرد غير صالح والذهاب للـfallback المحلي مع تسجيل السبب.
- الفعلي: أي نص يصل يُعرض للعميل.
- الحل المقترح: دالة تحقق (`isUsableReply`) — طول أدنى، نسبة whitespace، رفض JSON/أسلوب التعليمات، ومنع أرقام أسعار غير موجودة في الـgrounding؛ عند الرفض → `_emitLocalAnswer(fallback)` بدل العرض. وتدعيم `sanitizeLlmReply` بإزالة نصوص حقن التعليمات (prompt injection) بدل إرجاعها كما وصلت.

**C4 — استثناء من عميل النموذج يترك مؤشر الكتابة مشتعلًا للأبد**
- الملف: [assistant_cubit.dart:573-670](file:///D:/final%20app/new_cofee/lib/features/assistant/presentation/manager/assistant/assistant_cubit.dart#L573-L670) (`await _retrieval.search(...)` / `await _llmClient.complete(...)` بلا try/catch)
- الدليل: THROW → `uncaught=Bad state: edge function blew up`، الحالة النهائية `typing=true` بلا رد.
- المتوقع: fallback محلي وإطفاء `typing` دائمًا.
- الفعلي: المحادثة تتجمد عند «يكتب…» حتى إعادة فتح الصفحة.
- الحل المقترح: `try/catch/finally` حول مسار النموذج مع `finally { emit(typing: false) }`، وتحويل أي استثناء إلى نفس مسار `reply == null`.

### High

**H1 — 17 سؤالًا بلا بيانات أُجيب عليها محليًا بردود غير مرتبطة (False local answers)**
- الأدلة: rows 55، 63، 65، 66، 73، 75، 81، 83، 99، S16…
- الملف: منطق التوزيع في `AssistantUnderstanding` (قرار `owner`) + `AssistantEngine` الذي يملك مسارًا افتراضيًا «قائمة ترشيحات» لكل `suggestDrink`.
- المتوقع: `owner=languageModel` أو refusal صريح «لا أملك هذه المعلومة».
- الفعلي: قائمة 3 مشروبات أو FAQ عروض.
- الحل المقترح: عند `subject=none && knowledgeScore` منخفض && لا `grounding` → **ممنوع** الرد من قائمة الترشيحات الافتراضية؛ إضافة refusal واحد موحَّد لكل «لا بيانات» مع ذكر نوع المعلومات الناقصة وطلب تسجيل دخول عند الحاجة.

**H2 — أسئلة الفروع/التوصيل تُجيب «لسه معندكش طلبات»**
- الأدلة: rows 44، 46، 50، S17 t3؛ السبب: `no-grounding:orderStatus` لأن كلمة «توصيل/فرع» لا ترفع `shopFact`.
- المتوقع: حقيقة المتجر من المقالات أو رفض + إحالة لصفحة الفروع.
- الحل المقترح: فصل `subject` عن `intent` (سؤال عن المتجر لا عن طلب العميل)، ومنع مسار الطلبات إلا عند `subject=ownOrder`.

**H3 — تخصيصات مجرّدة تُرحَّل للنموذج فتضيع الكمية/الحجم**
- الأدلة: 13 استدعاء غير ضروري (rows 9، 23، 25، 27، 44–47، 49، 50، 54، 61، 95)؛ وفي المحادثة: S1 t2/t4، S2 t3، S6 t2، S13 t4، S19 t4 (آخرها وصل إلى ردّ تحية!).
- الملف: `detectIntent`/scoreIntents لا يستخدم `pending=order_confirm` كحالة سياق، والقرارات الأحادية («اتنين»، «كبير») تُعامَل كجمل جديدة.
- المتوقع: تطبيقها على المسودة الحالية (وهذا يحدث أحيانًا: S6 t2 صحيح).
- الحل المقترح: عندما `memory.pending == order_confirm`، تُفسَّر أنماط العدد/الحجم/السكر كـ**تعديل للمسودة** حصريًا، ولا تذهب للنموذج.

**H4 — تبديل لغة الرد داخل المحادثة الواحدة**
- الملف: [assistant_engine.dart:759-763](file:///D:/final%20app/new_cofee/lib/features/assistant/data/assistant_engine.dart#L759-L763) (`arabicReplyFor` يسقط إلى `AppLocale.instance` عند غياب الأحرف اللاتينية)
- الدليل: S1 t2 وt4 رد إنجليزي لجملة عربية صريحة.
- المتوقع: لغة رد ثابتة تتبع لغة العميل في المحادثة.
- الحل المقترح: تثبيت لغة الرد على مستوى `AssistantMemory` من أول رسالة عربية/لاتينية في المحادثة، لا إعادة حسابها لكل رسالة حسب إعداد التطبيق.

**H5 — ادعاء عن المكوّنات/الحساسية بلا أي مصدر بيانات**
- الأدلة: S10 t1/t3 «مفيش حاجة عندنا فيها مكسرات»؛ لا يوجد حقل مكوّنات في الـsnapshot.
- المتوقع: «معلومات المكوّنات غير متاحة — اسأل الدعم/افتح صفحة المنتج».
- الحل المقترح: منع أي رد حساسية/مكوّنات إلا إذا كان النص مستخرجًا من سجل `product_ingredients` موجود فعليًا؛ وإلا refusal. (هذا ثغرة سلامة: خطأ هنا قد يسبب ضررًا صحيًا.)

**H6 — سقوط الرسالة الثانية أثناء الرد**
- الملف: [assistant_cubit.dart:345](file:///D:/final%20app/new_cofee/lib/features/assistant/presentation/manager/assistant/assistant_cubit.dart#L345)
- الدليل: `DOUBLE: llmCalls=1 userLines=1` — الرسالة لا تظهر ولا تُعالَج ولا يوجد أي تنبيه.
- الحل المقترح: طابور أدوار (`_queue`) أو منع الإدخال بصريًا أثناء `typing`؛ لا تُسقَط رسالة كتبها العميل.

### Medium

**M1 — «لا خليها موكا» يلغي المسودة كلها** (S7 t2؛ `reason=discourse:deny` + `subject=menuItem` → `cancelOrder`). المتوقع استبدال الصنف. الحل: تمييز النفي «التصحيحي» (deny + صنف جديد) عن النفي «الإلغائي».

**M2 — انزياح الإشارة «دي»** (S18: Iced Latte → Cappuccino). الحل: تخزين الصنف المشار إليه مؤخرًا في `memory` وربط ضمائر الإشارة به بدل إعادة الترشيح.

**M3 — تحية لا تقرأ تحية العميل** (row 86 «صباح الخير» → «مساء الفل»؛ [assistant_greetings.dart:45-57](file:///D:/final%20app/new_cofee/lib/features/assistant/data/assistant_greetings.dart#L45-L57) تعتمد على `now.hour` فقط). الحل: الرد بنفس صيغة التحية الواردة.

**M4 — الشكر/الوداع يقومان بأفعال** (row 84 «شكرا على المساعدة» → مقالة الدعم؛ row 87 «تصبح على خير» → `selectOrdinal` → مشروبات). الحل: توسيع معجمات discourse والشكر/الوداع قبل أي scoring صنفي.

**M5 — الجمل القصيرة الغامضة تُجيب بـFAQ العروض** (rows 91 «هو كويس؟» → «تمام!»، 94 «كام؟» → عروض، 99 «الساعة كام الآن؟» → عروض). الحل: سؤال توضيح واحد مع سياق عند `subject=none` وقِصَر الرسالة، بدل إسناد عشوائي.

**M6 — السياق يُدهور إجابة صحيحة منفردة** (row 56 سعر اللاتيه صحيح ← S11 t1 FAQ عروض). الحل: تطبيع السعر كقدرة متاحة في كل السياقات.

**M7 — «كام الإجمالي؟» أثناء وجود مسودة → FAQ العروض** (S6 t4). الحل: ربط سؤال المجموع بـ`memory.draft`.

**M8 — تكرار حرفي لرد واحد داخل نفس الجلسة** (S5 t1/t2 نص واحد لكوبون يعمل وآخر لا يعمل؛ rows 28/33/31 نفس القالب). الحل: تمييز فشل الكود عن توفر العروض.

**M9 — بيانات الجلسة تُقرأ مرة واحدة ولا تتحدث**
- الملف: [assistant_cubit.dart:87-103](file:///D:/final%20app/new_cofee/lib/features/assistant/presentation/manager/assistant/assistant_cubit.dart#L87-L103) — `_snapshotFuture` يُخبَّأ عند أول تحميل و`_ensureSnapshot()` في `sendMessage` (سطر 392) يعيد نفس النسخة؛ إعادة التحميل الوحيدة هي `setBranch`.
- المتوقع: طلب تم خلال فتح المحادثة (أو تغيّرت حالته) ينعكس على إجابات «طلبي فين؟».
- الفعلي: المساعد يتحدث عن قائمة منتجات وطلبات لحظة فتح الصفحة. **غير مقاس فعليًا** في هذا التدقيق (لم تتوفّر بيئة بطلبات حيّة) — ملاحظة قراءة كود صريحة.
- الحل المقترح: إبطال `_snapshotFuture` بعد تنفيذ أي إجراء سلة/طلب، أو تحميل نسخة جديدة لكل سؤال يتعلق بـ`subject=ownOrder`/`cart`.

### Low

**L1 — RAG معطّل في الإنتاج:** migrations 230/231 غير مطبَّقة → الاسترجاع `[]`، والمسار الفعلي يطبع الكتالوج كاملًا في الـprompt (تكلفة/خصوصية + لا مصادر).

**L2 — «نسيت المحادثة اللي فاتت» تُرفض** مع أن السجل محفوظ فعليًا (row 72) — قدرة موجودة غير مستغَلة.

**L3 — انتهاء صلاحية العروض غير قابل للتحقق** من الـsnapshot (rows 57، 58) — يحتاج حقل `expires_at`.

**L4 — أداة القياس الآلية تكتشف الاختلاق بالأرقام فقط**، فادعاءات المكوّنات/الفروع تمر بلا راية — يجب أن يكون التدرج يدويًا مع قائمة black-white assertions.

**L5 — لا يوجد أي مقياس جودة (telemetry)** للنوايا/المصادر في الإنتاج، فلا إمكانية مراقبة انحدار بعد الإصلاح.

---

## H. Final Recommendation

**القرار: المساعد يحتاج إعادة تصميم لطبقة الفهم والتوجيه — وليس إصلاحات سطحية — ولا يصلح للاختبار التجريبي الآن.**

المبرر الرقمي: معيار 95% مُقابل **51% نوايا / 65% مصادر / 43% ردود محلية**، و**49 ردًا خاطئًا من 100**، منها **43 محليًا** لا يصلحه أي نموذج. كما أن الهدفين المطلقين (صفر اختلاق، صفر تنفيذ غير مصرَّح به) **مُخترقان** (6 حالات اختلاق + ادعاءان بلا مصدر + تنفيذ تعديل سلة بلا تأكيد). و**13 من 20** سيناريو سياق فاشلة بمعدل ضياع تفاصيل 62% من الأدوار.

**ترتيب العمل المقترح (للمراجعة والاعتماد قبل أي تنفيذ):**
1. **سدّ السلامة أولاً** (C1 تأكيد عمليات السلة، C3 تحقق رد النموذج، C4 `finally typing=false`، H5 منع ادعاءات المكوّنات).
2. **إعادة تعريف قرار الملكية** في البوابة: ملكية الرد تُحسب من «هل توجد بيانات كافية للجواب؟» لا من «هل ذُكر اسم منتج؟» (C2، H1، H2).
3. **آلة حالة للسياق**: pending draft + pending cart confirmation تحكمان تفسير التوابع المجرّدة والعدد/الحجم/السكر (H3، M1، M2، M7).
4. **إصلاحات الحوار الصغيرة** (H4 اللغة، M3–M6) بعد ثبات شجرة القرار.
5. **طبقة قياس دائمة**: تحويل مجموعتي الـ100 والـ20 إلى اختبارات تثبيت (golden set) في `test/` مع عتبات 95%، وإلا سيتكرر الانحدار.
6. **تطبيق migrations 230/231 + تفعيل الاسترجاع** لاحقًا، ثم قياس جودة النموذج الحقيقي في بيئة فيها شبكة وطلبات حقيقية — وهي بنود **غير مقاسة** حتى اليوم.

---

## 12. التسليم النهائي

| # | البند | القيمة |
|---|---|---|
| 1 | عدد الاختبارات المنفذة | **130 مجموعة تشغيل**: 100 جملة + 68 دورًا في 20 سيناريو + 10 حالات أعطال/offline + 8 حالات سلامة بيانات (58 قياسًا فرديًا منها داخل مجموعتي الـ100 والـ20) |
| 2 | نسبة النجاح الفعلية | **28%** ردود صحيحة (28/100)؛ 51% نوايا؛ 65% مصادر؛ 43% ردود محلية؛ **1/20** سيناريو سياق نظيف |
| 3 | أخطاء التصنيف | **49 خطأ نية** (51/100 صحيحة) + **35 خطأ مصدر** (65/100) |
| 4 | الإجابات المضللة | **43 ردًا محليًا خاطئًا** يظهر حتى مع نموذج سليم + **6** تظهر فقط كـfallback عند فشل النموذج + **7** أسئلة بلا بيانات أجيب بقوائم/FAQ (تتداخل مع ما سبق) |
| 5 | حالات اختلاق المعلومات | **6 مؤكدة** في الـ100 (rows 0، 10، 32، 74، 77، 80) **+ 2 ادعاء بلا مصدر** (مكوّنات S10، مواعيد فرع row 47) — **المطلوب صفر** |
| 6 | مشاكل السياق | **13 سيناريو فاشل + 6 جزئي**؛ **42 دورًا من 68** فقدت أو أساءت استخدام السياق |
| 7 | متوسط زمن الاستجابة | **84 ms** للمحرك المحلي (وسيط 71، أقصى 316)؛ زمن النموذج الحقيقي **غير مقاس** |
| 8–9 | أهم 10 مشكلات + الحل لكل منها | C1 تنفيذ السلة بلا تأكيد؛ C2 اختراع مسودات لأسئلة عامة؛ C3 عرض رد النموذج بلا تحقق؛ C4 استثناء يشعل `typing` للأبد؛ H1 ردود محلية لـ17 سؤالًا بلا بيانات؛ H2 أسئلة الفروع بـ«لسه معندكش طلبات»؛ H3 ضياع العدد/الحجم في التوابع؛ H4 تبديل لغة الرد؛ H5 ادعاء مكوّنات بلا بيانات؛ H6 إسقاط الرسالة الثانية — **حلولها مكتوبة في G دون أي تطبيق** |
| 10 | تأكيد عدم التغيير | **لم يتغير الكود ولا قاعدة البيانات.** لا تعديل في أي ملف Dart/SQL/Edge Function، لا Prompts، لا Intent Classifier، لا dependencies، لا migrations، لا كتابة/قراءة بيانات Supabase، لا commit ولا push. الاختبارات المؤقتة أُنشئت في `test/` ثم **حُذفت**، وعادت شجرة العمل إلى حالة ما قبل التدقيق (`git status` مطابق، HEAD `d4edc889`) — والملف الوحيد المضاف هو هذا التقرير. |

**لم تبدأ أي مرحلة إصلاح، التزامًا بالتعليمة: «ممنوع البدء في مرحلة الإصلاح حتى أراجع التقرير وأعتمد خطة التعديلات بنفسي.»**
