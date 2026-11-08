/// A curated, bilingual knowledge entry for general coffee education.
///
/// IMPORTANT:
/// - This content is not authoritative for the live menu, prices, stock,
///   ingredients, allergens, branch hours, delivery, or order status.
/// - Live/business questions must be answered from the relevant data source.
/// - Brewing ratios and times are starting points; equipment and taste vary.
class KnowledgeArticle {
  const KnowledgeArticle({
    required this.id,
    required this.title,
    required this.keywords,
    required this.body,
    required this.topic,
    required this.titleAr,
    required this.bodyAr,
    this.keywordsAr = const [],
  }) : assert(id != ''),
       assert(title != ''),
       assert(titleAr != ''),
       assert(body != ''),
       assert(bodyAr != ''),
       assert(topic != '');

  /// Stable identifier. Do not change existing IDs without updating references.
  final String id;

  /// English display title and search terms.
  final String title;
  final List<String> keywords;

  /// English educational answer.
  final String body;

  /// Existing topic key, retained for compatibility with current consumers.
  final String topic;

  /// Arabic display title and search terms.
  final String titleAr;
  final List<String> keywordsAr;

  /// Arabic educational answer.
  final String bodyAr;

  String titleFor({required bool arabic}) => arabic ? titleAr : title;

  String bodyFor({required bool arabic}) => arabic ? bodyAr : body;

  /// Search terms for the selected language.
  ///
  /// Arabic searches also include English coffee terms because customers
  /// commonly write terms such as "V60", "Latte", and "Decaf" in Arabic chats.
  /// Keep matching/ranking logic outside this model.
  List<String> keywordsFor({required bool arabic}) =>
      arabic ? [...keywords, ...keywordsAr] : keywords;
}

/// General educational knowledge only. Never use it to infer live business data.
const List<KnowledgeArticle> coffeeKnowledge = [
  KnowledgeArticle(
    id: 'espresso-basics',
    title: 'Espresso basics',
    titleAr: 'أساسيات الإسبريسو',
    keywords: [
      'espresso',
      'espresso shot',
      'single espresso',
      'double espresso',
      'shot',
      'crema',
      'espresso crema',
    ],
    keywordsAr: [
      'اسبريسو',
      'إسبريسو',
      'اسبرسو',
      'شوت اسبريسو',
      'جرعة اسبريسو',
      'دبل اسبريسو',
      'سنجل اسبريسو',
      'كريما',
      'كريمة الاسبريسو',
    ],
    body:
        'Espresso is a concentrated coffee brewed by forcing hot water through '
        'finely ground coffee under pressure. A single shot is often served '
        'around 25–30 ml, but dose, yield and serving size vary by recipe. '
        'The golden crema is a normal part of espresso, but its thickness or '
        'appearance alone does not prove that a shot is fresh or well extracted.',
    bodyAr:
        'الإسبريسو قهوة مركزة بتتحضّر بمرور مياه ساخنة بضغط عالٍ خلال بن مطحون '
        'ناعم. الشوت الواحد غالبًا بيتقدم بحجم يقارب 25–30 مل، لكن الكمية '
        'بتختلف حسب الوصفة وطريقة التحضير. طبقة الكريما الذهبية جزء طبيعي من '
        'الإسبريسو، لكن شكلها أو سُمكها لوحده مش دليل كافي على جودة الشوت أو طزاجته.',
    topic: 'brewing',
  ),
  KnowledgeArticle(
    id: 'cappuccino-guide',
    title: 'What is a cappuccino?',
    titleAr: 'إيه هو الكابتشينو؟',
    keywords: [
      'cappuccino',
      'cappucino',
      'cappuccino milk',
      'milk foam',
      'microfoam',
      'foam coffee',
    ],
    keywordsAr: [
      'كابتشينو',
      'كابتشينو',
      'كبشينو',
      'كابتشينو لبن',
      'رغوة الكابتشينو',
      'فوم الكابتشينو',
      'رغوة اللبن',
      'قهوة برغوة',
    ],
    body:
        'A cappuccino combines espresso with steamed milk and a noticeable '
        'layer of milk foam. Traditional descriptions often use roughly equal '
        'parts, but cup size and café style can change the proportions. '
        'Compared with a latte, a cappuccino usually has a stronger coffee '
        'impression and a foamier texture.',
    bodyAr:
        'الكابتشينو بيتكوّن من إسبريسو ولبن مبخر وطبقة واضحة من رغوة اللبن. '
        'الوصف التقليدي بيقرب المكونات من أجزاء متساوية، لكن النسب وحجم الكوب '
        'بيختلفوا من وصفة للتانية. مقارنة باللاتيه، الكابتشينو غالبًا إحساس '
        'القهوة فيه أوضح وقوام الرغوة فيه أكبر.',
    topic: 'drinks',
  ),
  KnowledgeArticle(
    id: 'latte-guide',
    title: 'What is a latte?',
    titleAr: 'إيه هو اللاتيه؟',
    keywords: [
      'latte',
      'caffe latte',
      'cafe latte',
      'milky coffee',
      'mild coffee',
      'creamy coffee',
      'latte milk',
    ],
    keywordsAr: [
      'لاتيه',
      'لاتي',
      'كافيه لاتيه',
      'قهوة بالحليب',
      'قهوة باللبن',
      'مشروب لاتيه',
      'لاتيه لبن',
    ],
    body:
        'A latte is an espresso-based drink with a relatively generous amount '
        'of steamed milk and a thin layer of foam. It is usually smoother and '
        'milder in coffee intensity than a cappuccino. The exact espresso-to-milk '
        'ratio depends on the cup size and the café recipe.',
    bodyAr:
        'اللاتيه مشروب أساسه الإسبريسو، ومعاه كمية أكبر نسبيًا من اللبن المبخر '
        'وطبقة رغوة خفيفة. غالبًا قوامه أنعم وإحساس القهوة فيه أهدى من '
        'الكابتشينو. نسبة الإسبريسو للبن بتختلف حسب حجم الكوب ووصفة الكافيه.',
    topic: 'drinks',
  ),
  KnowledgeArticle(
    id: 'mocha-guide',
    title: 'What is a mocha?',
    titleAr: 'إيه هي الموكا؟',
    keywords: [
      'mocha',
      'caffe mocha',
      'cafe mocha',
      'chocolate coffee',
      'coffee with chocolate',
      'cocoa coffee',
    ],
    keywordsAr: [
      'موكا',
      'موكه',
      'كافيه موكا',
      'قهوة بالشوكولاتة',
      'قهوة بالكاكاو',
      'مشروب موكا',
      'موكا بالشوكولاتة',
    ],
    body:
        'A mocha is commonly an espresso drink made with chocolate or cocoa '
        'and milk. Some recipes include whipped cream or other toppings, while '
        'others do not. Sweetness, chocolate type and ingredients vary by café, '
        'so check the product details for the exact recipe.',
    bodyAr:
        'الموكا غالبًا مشروب أساسه الإسبريسو وبيتضاف له شوكولاتة أو كاكاو '
        'ولبن. بعض الوصفات بيكون عليها كريمة مخفوقة أو إضافات، ووصفات تانية '
        'لأ. درجة الحلاوة ونوع الشوكولاتة والمكونات بتختلف حسب الكافيه، '
        'فلازم نرجع لتفاصيل المنتج لمعرفة الوصفة الفعلية.',
    topic: 'drinks',
  ),
  KnowledgeArticle(
    id: 'cold-coffee-guide',
    title: 'Cold coffee options',
    titleAr: 'أنواع القهوة الباردة',
    keywords: [
      'cold coffee',
      'iced coffee',
      'iced latte',
      'cold brew',
      'frappe',
      'frappuccino',
      'coffee over ice',
    ],
    keywordsAr: [
      'قهوة باردة',
      'قهوة مثلجة',
      'قهوة ساقعة',
      'ايس كوفي',
      'آيس كوفي',
      'ايس لاتيه',
      'آيس لاتيه',
      'كولد برو',
      'فرابيه',
      'فرابيه قهوة',
    ],
    body:
        'Iced coffee is a broad category of coffee drinks served cold or over '
        'ice. An iced latte is typically espresso with cold milk and ice, while '
        'cold brew is made by steeping coffee grounds in cool or room-temperature '
        'water for an extended period. Recipes and available options vary by café.',
    bodyAr:
        'القهوة الباردة اسم عام لمشروبات القهوة اللي بتتقدم ساقعة أو مع تلج. '
        'الآيس لاتيه غالبًا بيتكوّن من إسبريسو ولبن بارد وتلج، أما الكولد برو '
        'فبيتحضّر بنقع البن في مياه باردة أو بدرجة حرارة الغرفة لمدة طويلة. '
        'الوصفات والأصناف المتاحة بتختلف من كافيه للتاني.',
    topic: 'drinks',
  ),
  KnowledgeArticle(
    id: 'arabica-vs-robusta',
    title: 'Arabica vs Robusta',
    titleAr: 'الفرق بين الأرابيكا والروبوستا',
    keywords: [
      'arabica',
      'robusta',
      'coffee bean types',
      'coffee varieties',
      'coffee species',
      'arabica vs robusta',
    ],
    keywordsAr: [
      'ارابيكا',
      'أرابيكا',
      'روبوستا',
      'الفرق بين الأرابيكا والروبوستا',
      'الفرق بين انواع البن',
      'أنواع حبوب القهوة',
      'نوع حبوب القهوة',
      'بن ارابيكا',
      'بن روبوستا',
    ],
    body:
        'Arabica and Robusta are two widely used coffee species. Arabica is '
        'often associated with a broader range of delicate aromas and flavors. '
        'Robusta often has a stronger, more bitter profile and generally more '
        'caffeine by weight. These are broad tendencies, not guarantees: origin, '
        'variety, processing, roast and brewing all affect the cup.',
    bodyAr:
        'الأرابيكا والروبوستا نوعان مشهوران من حبوب القهوة. الأرابيكا غالبًا '
        'بتتميز بتنوع أكبر في الروائح والنكهات، والروبوستا غالبًا طعمها أقوى '
        'ومرارتها أوضح وكمية الكافيين فيها أعلى عادةً بالنسبة للوزن. دي صفات '
        'عامة مش قواعد ثابتة؛ بلد المنشأ والمعالجة والتحميص وطريقة التحضير '
        'كلها بتأثر على الطعم.',
    topic: 'beans',
  ),
  KnowledgeArticle(
    id: 'grind-guide',
    title: 'Coffee grind size guide',
    titleAr: 'دليل درجات طحن القهوة',
    keywords: [
      'grind size',
      'coffee grind',
      'grinder',
      'fine grind',
      'coarse grind',
      'medium grind',
      'coffee grounds',
    ],
    keywordsAr: [
      'درجة طحن القهوة',
      'درجات طحن البن',
      'طحن البن',
      'مطحنة القهوة',
      'طحن ناعم',
      'طحن خشن',
      'طحن متوسط',
      'البن مطحون',
    ],
    body:
        'Grind size should match the brewing method. Espresso generally needs '
        'a fine grind, pour-over usually uses a medium-fine grind, and French '
        'press commonly uses a coarse grind. If extraction is too fast or too '
        'slow, adjust gradually and taste the result. Sourness or bitterness '
        'can have several causes, so grind size is not the only factor.',
    bodyAr:
        'درجة الطحن لازم تناسب طريقة التحضير. الإسبريسو غالبًا محتاج طحن ناعم، '
        'والبور أوفر طحن متوسط مائل للنعومة، والفرنش برس طحن خشن. لو الاستخلاص '
        'سريع أو بطيء زيادة، غيّر درجة الطحن بالتدريج وجرّب الطعم. الحموضة '
        'أو المرارة ممكن يكون ليهم أسباب مختلفة، فدرجة الطحن مش العامل الوحيد.',
    topic: 'brewing',
  ),
  KnowledgeArticle(
    id: 'french-press',
    title: 'French press at home',
    titleAr: 'تحضير القهوة بالفرنش برس',
    keywords: [
      'french press',
      'cafetiere',
      'coffee plunger',
      'immersion brewing',
      'french press recipe',
    ],
    keywordsAr: [
      'فرنش برس',
      'فرنش بريس',
      'فرينش برس',
      'تحضير القهوة بالفرنش برس',
      'طريقة الفرنش برس',
      'القهوة المكبوسة',
    ],
    body:
        'For a simple French press starting point, use coarse-ground coffee '
        'and about 1 part coffee to 15 parts water by weight. Add hot water, '
        'stir gently, steep for around 4 minutes, then press slowly. Adjust '
        'the ratio and steeping time to suit your taste and equipment.',
    bodyAr:
        'كبداية بسيطة للفرنش برس، استخدم بن خشن بنسبة تقريبية جزء قهوة إلى '
        '15 جزء مياه بالوزن. ضيف المياه الساخنة وقلّب بهدوء، وسيب القهوة '
        'حوالي 4 دقايق، وبعدها اضغط المكبس ببطء. تقدر تعدّل النسبة ووقت '
        'النقع حسب ذوقك والأداة اللي بتستخدمها.',
    topic: 'brewing',
  ),
  KnowledgeArticle(
    id: 'pour-over',
    title: 'Pour-over coffee at home',
    titleAr: 'تحضير القهوة بالبور أوفر',
    keywords: [
      'pour over',
      'pourover',
      'v60',
      'drip coffee',
      'filter coffee',
      'manual brewing',
      'coffee dripper',
    ],
    keywordsAr: [
      'بور اوفر',
      'بور أوفر',
      'v60',
      'في ستين',
      'قهوة مقطرة',
      'قهوة فلتر',
      'تحضير القهوة بالفلتر',
      'طريقة v60',
      'طريقة تحضير v60',
    ],
    body:
        'Pour-over is a manual filter method in which hot water is poured '
        'gradually over ground coffee. A useful starting point is a medium-fine '
        'grind and water around 92–96°C. Wet the grounds evenly first, then pour '
        'in controlled stages. Grind, ratio, pouring pattern and total brew time '
        'can all be adjusted to change the flavor.',
    bodyAr:
        'البور أوفر طريقة تحضير يدوية باستخدام فلتر، وبتصب فيها المياه الساخنة '
        'بالتدريج على البن. كبداية، جرّب طحن متوسط مائل للنعومة ومياه بدرجة '
        'حرارة حوالي 92–96 مئوية. بلّل البن بالتساوي في الأول، وبعدها صب '
        'على مراحل وبهدوء. درجة الطحن ونسبة القهوة للمياه وطريقة الصب ووقت '
        'التحضير كلهم بيأثروا على النتيجة.',
    topic: 'brewing',
  ),
  KnowledgeArticle(
    id: 'caffeine-guide',
    title: 'Caffeine in coffee',
    titleAr: 'معلومات عن الكافيين في القهوة',
    keywords: [
      'caffeine',
      'coffee caffeine',
      'caffeine content',
      'mg caffeine',
      'milligrams of caffeine',
      'does coffee have caffeine',
    ],
    keywordsAr: [
      'كافيين',
      'الكافيين',
      'كام كافيين',
      'كم كافيين',
      'كمية الكافيين',
      'نسبة الكافيين',
      'مليجرام كافيين',
      'مليغرام كافيين',
      'القهوة بتصحصح',
      'القهوة والنوم',
    ],
    body:
        'Caffeine varies considerably with the coffee bean, dose, number of '
        'espresso shots, serving size and brewing method. A drink name alone '
        'is not enough to calculate its caffeine content. For an exact figure, '
        'use verified product or supplier information rather than a general estimate.',
    bodyAr:
        'كمية الكافيين بتختلف بشكل كبير حسب نوع البن والجرعة وعدد شوتات '
        'الإسبريسو وحجم المشروب وطريقة التحضير. اسم المشروب لوحده مش كفاية '
        'علشان نحدد كمية الكافيين بدقة. لو محتاج رقم محدد، لازم نعتمد على '
        'بيانات موثوقة للمنتج أو المورد بدل التخمين.',
    topic: 'caffeine',
  ),
  KnowledgeArticle(
    id: 'decaf-guide',
    title: 'What does decaf mean?',
    titleAr: 'يعني إيه ديكاف؟',
    keywords: [
      'decaf',
      'decaffeinated',
      'decaffeinated coffee',
      'low caffeine coffee',
      'coffee without caffeine',
    ],
    keywordsAr: [
      'ديكاف',
      'دي كاف',
      'قهوة ديكاف',
      'قهوة بدون كافيين',
      'قهوة منزوعة الكافيين',
      'كافيين قليل',
      'من غير كافيين',
      'بلا كافيين',
    ],
    body:
        'Decaf coffee has had most of its caffeine removed, but it is not '
        'necessarily completely caffeine-free. The remaining amount depends '
        'on the beans and decaffeination process. Whether a café offers decaf '
        'must be checked against its current menu.',
    bodyAr:
        'قهوة الديكاف بيتم إزالة معظم الكافيين منها، لكنها مش بالضرورة خالية '
        'منه تمامًا. الكمية المتبقية بتعتمد على نوع البن وطريقة إزالة الكافيين. '
        'وتوفر الديكاف في أي كافيه لازم يتأكد من المنيو الحالي.',
    topic: 'caffeine',
  ),
  KnowledgeArticle(
    id: 'caffeine-benefits',
    title: 'What caffeine can do',
    titleAr: 'تأثير الكافيين وفوايد القهوة',
    keywords: [
      'coffee benefits',
      'benefit of caffeine',
      'alertness',
      'focus',
      'energy from coffee',
      'does coffee help focus',
      'effect of coffee',
      'what does coffee do',
    ],
    keywordsAr: [
      'فايدة القهوة',
      'فوائد القهوة',
      'فوائد الكافيين',
      'القهوة والتركيز',
      'القهوة والطاقة',
      'القهوة بتصحصح',
      'هل القهوة مفيدة',
      'وظيفة القهوة',
      'تأثير القهوة',
      'تأثيرها على الجسم',
      'القهوة للجسم',
      'الصحة والقهوة',
    ],
    body:
        'Caffeine can temporarily increase alertness and reduce sleepiness. '
        'The effect and duration vary between people. This is not evidence that '
        'coffee prevents or treats disease. The FDA notes that sensitivity '
        'depends on factors such as body weight, medicines, health conditions '
        'and individual response. Source: https://www.fda.gov/consumers/consumer-updates/spilling-beans-how-much-caffeine-too-much',
    bodyAr:
        'الكافيين ممكن يزود اليقظة مؤقتًا ويقلل الإحساس بالنعاس، لكن التأثير '
        'ومدته بيختلفوا من شخص للتاني. ده مش معناه إن القهوة بتمنع الأمراض '
        'أو بتعالجها. إدارة الغذاء والدواء الأمريكية FDA بتوضح إن الاستجابة '
        'بتختلف حسب عوامل منها الوزن والأدوية والحالة الصحية وحساسية الشخص. '
        'المصدر: https://www.fda.gov/consumers/consumer-updates/spilling-beans-how-much-caffeine-too-much',
    topic: 'caffeine',
  ),
  KnowledgeArticle(
    id: 'caffeine-risks',
    title: 'Caffeine limits and possible side effects',
    titleAr: 'أضرار الكافيين والحدود العامة',
    keywords: [
      'coffee side effects',
      'too much caffeine',
      'caffeine limit',
      'caffeine sleep',
      'caffeine pregnancy',
      'coffee blood pressure',
      'caffeine anxiety',
      'caffeine headache',
      'coffee stomach',
    ],
    keywordsAr: [
      'أضرار القهوة',
      'اضرار القهوة',
      'أضرار الكافيين',
      'الكافيين والنوم',
      'القهوة والضغط',
      'القهوة والحمل',
      'الكافيين والحامل',
      'خفقان القهوة',
      'قلق من القهوة',
      'القهوة والصداع',
      'القهوة والحموضة',
      'القهوة والمعدة',
      'القهوة والقلب',
      'كمية القهوة الآمنة',
      'الحد اليومي للكافيين',
    ],
    body:
        'Too much caffeine can cause unwanted effects such as sleep disruption, '
        'jitters or a fast heartbeat; sensitivity differs. FDA cites 400 mg/day '
        'as an amount not generally associated with negative effects for most '
        'healthy adults, not a target or guarantee. EFSA advises no more than '
        '200 mg/day during pregnancy. Drink caffeine from all sources counts, '
        'and exact drink amounts need verified recipe data. Sources: '
        'https://www.fda.gov/consumers/consumer-updates/spilling-beans-how-much-caffeine-too-much '
        'https://www.efsa.europa.eu/en/topics/topic/caffeine',
    bodyAr:
        'زيادة الكافيين ممكن تسبب اضطراب النوم أو رعشة وتوتر أو خفقان، '
        'والحساسية بتختلف. بتذكر FDA إن 400 مجم يوميًا لا ترتبط عادةً '
        'بآثار سلبية لمعظم البالغين الأصحاء؛ ده مش هدفًا يوميًا ولا ضمانًا '
        'يناسب كل شخص. وتوصي EFSA بألا يزيد الاستهلاك على 200 مجم يوميًا '
        'أثناء الحمل. لازم نحسب كل مصادر الكافيين، وما نحددش كمية مشروب '
        'من اسمه بس من غير وصفة موثقة. المصادر: '
        'https://www.fda.gov/consumers/consumer-updates/spilling-beans-how-much-caffeine-too-much '
        'https://www.efsa.europa.eu/en/topics/topic/caffeine',
    topic: 'caffeine',
  ),
  KnowledgeArticle(
    id: 'milk-guide',
    title: 'Milk and milk alternatives',
    titleAr: 'اللبن وبدائله',
    keywords: [
      'milk',
      'dairy milk',
      'oat milk',
      'almond milk',
      'soy milk',
      'lactose',
      'lactose free',
      'plant milk',
      'milk alternatives',
    ],
    keywordsAr: [
      'لبن',
      'حليب',
      'أنواع الحليب',
      'بدائل اللبن',
      'بدائل الحليب',
      'حليب الشوفان',
      'لبن الشوفان',
      'حليب اللوز',
      'لبن اللوز',
      'حليب الصويا',
      'لبن الصويا',
      'لاكتوز',
      'خالي من اللاكتوز',
      'حساسية اللبن',
    ],
    body:
        'Different milks and plant-based alternatives can change a drink’s '
        'flavor, texture and nutritional profile. They are not automatically '
        'allergen-safe: ingredients, shared equipment and cross-contact matter. '
        'Confirm the exact ingredients and preparation process with the café '
        'before ordering if you have an allergy or intolerance.',
    bodyAr:
        'أنواع اللبن والبدائل النباتية ممكن تغيّر طعم المشروب وقوامه وقيمته '
        'الغذائية. ومش معنى إن البديل نباتي إنه آمن تلقائيًا من مسببات الحساسية؛ '
        'المكونات والأدوات المشتركة والتلامس العرضي كلهم مهمين. لو عندك حساسية '
        'أو عدم تحمّل، اتأكد من المكونات وطريقة التحضير مع الكافيه قبل الطلب.',
    topic: 'drinks',
  ),
  KnowledgeArticle(
    id: 'tea-guide',
    title: 'Tea styles',
    titleAr: 'أنواع الشاي',
    keywords: [
      'tea',
      'green tea',
      'black tea',
      'masala chai',
      'chai',
      'herbal tea',
      'tea types',
    ],
    keywordsAr: [
      'شاي',
      'أنواع الشاي',
      'شاي اخضر',
      'شاي أخضر',
      'شاي اسود',
      'شاي أسود',
      'ماسالا',
      'ماسالا تشاي',
      'شاي ماسالا',
      'تشاي',
      'كرك',
      'شاي بالهيل',
      'شاي اعشاب',
      'شاي أعشاب',
    ],
    body:
        'Tea includes several styles with different leaves and preparation '
        'methods. Green tea is generally less oxidized than black tea. Masala '
        'chai is commonly made with black tea and spices such as cardamom, '
        'ginger or cinnamon, often with milk. Recipes differ, and the exact '
        'ingredients of a café drink should be checked on its product details.',
    bodyAr:
        'الشاي ليه أنواع وطرق تحضير مختلفة. الشاي الأخضر عادةً أقل أكسدة من '
        'الشاي الأسود. أما الماسالا تشاي فغالبًا بيتحضّر بشاي أسود وتوابل زي '
        'الهيل أو الزنجبيل أو القرفة، وممكن يتضاف له لبن. الوصفات بتختلف، '
        'ولمعرفة مكونات مشروب معين لازم نراجع تفاصيل المنتج في المنيو.',
    topic: 'drinks',
  ),
  KnowledgeArticle(
    id: 'bean-storage',
    title: 'How to store coffee beans',
    titleAr: 'إزاي تخزّن حبوب القهوة؟',
    keywords: [
      'coffee storage',
      'store coffee beans',
      'keep coffee fresh',
      'coffee freshness',
      'stale coffee',
      'coffee container',
    ],
    keywordsAr: [
      'تخزين البن',
      'تخزين حبوب القهوة',
      'حفظ البن',
      'حفظ القهوة',
      'الحفاظ على نضارة البن',
      'البن يبوظ',
      'البن يفقد طعمه',
      'طريقة تخزين القهوة',
    ],
    body:
        'Store coffee beans in an airtight, opaque container in a cool, dry '
        'place away from direct sunlight, heat and moisture. Whole beans usually '
        'retain their quality longer than ground coffee. For the best flavor, '
        'grind shortly before brewing and avoid repeatedly exposing the beans '
        'to air and humidity.',
    bodyAr:
        'احفظ حبوب القهوة في عبوة محكمة ومعتمة، في مكان بارد وجاف وبعيد عن '
        'الشمس المباشرة والحرارة والرطوبة. الحبوب الكاملة غالبًا بتحافظ على '
        'جودتها مدة أطول من البن المطحون. علشان أفضل نكهة، اطحن البن قبل '
        'التحضير بوقت قصير، وقلّل تعرضه المتكرر للهواء والرطوبة.',
    topic: 'beans',
  ),
  KnowledgeArticle(
    id: 'snacks-pairing',
    title: 'What goes well with coffee?',
    titleAr: 'إيه الأكل اللي يناسب القهوة؟',
    keywords: [
      'coffee pairing',
      'food with coffee',
      'snack with coffee',
      'coffee and dessert',
      'cookie with coffee',
      'croissant with coffee',
      'cake with coffee',
      'what to eat with coffee',
    ],
    keywordsAr: [
      'أكل مع القهوة',
      'إيه اللي يتاكل مع القهوة',
      'حاجة مع القهوة',
      'وجبة خفيفة مع القهوة',
      'سناك مع القهوة',
      'حلويات مع القهوة',
      'حاجة حلوة مع القهوة',
      'كوكي مع القهوة',
      'كرواسون مع القهوة',
      'براوني مع القهوة',
      'تشيز كيك مع القهوة',
      'ايه احسن حاجه مع القهوه',
      'ايه ناكل مع القهوه',
      'وش يناسب القهوه',
      'وش اكل مع القهوه',
      'شو بناكل مع القهوه',
      'شو بناسب القهوه',
      'ايش يناسب القهوه',
      'ايش اكل مع القهوه',
      'عايز حاجه حلوه مع القهوه',
      'عاوز حاجه حلوه مع القهوه',
      'ابي شي حلو مع القهوه',
      'ابغى شي حلو مع القهوه',
      'ودي بشي حلو مع القهوه',
    ],
    body:
        'Coffee can pair well with many baked goods and desserts. Chocolate '
        'desserts often complement espresso, while croissants and other pastries '
        'can work well with milk-based drinks. These are taste suggestions only; '
        'they do not indicate that any item is available at a particular café.',
    bodyAr:
        'القهوة ممكن تناسب أنواع كتير من المخبوزات والحلويات. حلويات الشوكولاتة '
        'غالبًا بتكون مناسبة مع الإسبريسو، والكرواسون والمخبوزات ممكن تمشي '
        'حلو مع المشروبات اللي فيها لبن. دي اقتراحات حسب الذوق فقط، ومش معناها '
        'إن الأصناف دي متوفرة في كافيه معين.',
    topic: 'food',
  ),
];
