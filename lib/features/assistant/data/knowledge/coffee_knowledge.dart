class KnowledgeArticle {
  const KnowledgeArticle({
    required this.id,
    required this.title,
    required this.keywords,
    required this.body,
    required this.topic,
    this.titleAr,
    this.bodyAr,
    this.keywordsAr = const [],
  });

  final String id;
  final String title;
  final List<String> keywords;
  final String body;
  final String topic;

  /// Arabic title. Falls back to the English one when it is missing.
  final String? titleAr;

  /// Arabic body.
  ///
  /// The customer reads the answer, not the model: an Arabic question that
  /// matched an English article used to be answered in English.
  final String? bodyAr;

  /// The Arabic spellings customers use for this topic.
  ///
  /// Without them the article cannot be found by an Arabic question at all,
  /// because the matching is word based.
  final List<String> keywordsAr;

  /// The article in the customer's language.
  String bodyFor({required bool arabic}) =>
      arabic ? (bodyAr ?? body) : body;

  /// The article title in the customer's language.
  String titleFor({required bool arabic}) =>
      arabic ? (titleAr ?? title) : title;

  /// Every spelling that can lead to this article.
  List<String> keywordsFor({required bool arabic}) =>
      arabic ? [...keywords, ...keywordsAr] : keywords;
}

const List<KnowledgeArticle> coffeeKnowledge = [
  KnowledgeArticle(
    id: 'espresso-basics',
    title: 'Espresso basics',
    titleAr: 'أساسيات الإسبريسو',
    keywords: ['espresso', 'shot', 'strong', 'intense', 'crema', 'bold'],
    keywordsAr: [
      'اسبريسو',
      'اسبرسو',
      'شوت',
      'جرعه',
      'قوي',
      'مركز',
      'كرما',
    ],
    body:
        'Espresso is a concentrated 25 to 30 ml shot brewed by forcing hot water through finely ground coffee. '
        'Look for a thick golden crema on top: that is the sign of a fresh, well-pulled shot.',
    bodyAr:
        'الإسبريسو جرعة مركزة من 25 لـ 30 مل، بتتحضّر بدفع ماء ساخن تحت ضغط على قهوة مطحونة ناعم. '
        'دوّر على طبقة كرما ذهبية سميكة فوقها: دي علامة جرعة طازة متحضّرة كويس.',
    topic: 'brewing',
  ),
  KnowledgeArticle(
    id: 'cappuccino-guide',
    title: 'What is a cappuccino?',
    titleAr: 'إيه الكابتشينو؟',
    keywords: ['cappuccino', 'foam', 'classic', 'milk foam'],
    keywordsAr: [
      'كابتشينو',
      'كبشينو',
      'رغوه',
      'زبد',
      'كلاسيك',
      'فرق',
    ],
    body:
        'A cappuccino is one part espresso, one part steamed milk and one part airy milk foam. '
        'It tastes stronger and drier than a latte, and it is best enjoyed fresh while the foam holds.',
    bodyAr:
        'الكابتشينو تلات أجزاء: جزء إسبريسو، جزء لبن مبخر، وجزء رغوة لبني خفيف. '
        'طعمه أقوى وأكثر جفاف من اللاتيه، وأحسن ما يتشرب طازة والا رغوة لسة موجودة.',
    topic: 'drinks',
  ),
  KnowledgeArticle(
    id: 'latte-guide',
    title: 'What is a latte?',
    titleAr: 'إيه اللاتيه؟',
    keywords: ['latte', 'milky', 'mild', 'smooth', 'creamy'],
    keywordsAr: [
      'لاتيه',
      'لاتي',
      'لبن',
      'حلي',
      'ناعم',
      'سلس',
      'فرق',
    ],
    body:
        'A latte is mostly steamed milk with a single or double espresso shot, finished with a thin layer of foam. '
        'Pick it when you want something smooth, mild and creamy.',
    bodyAr:
        'اللاتيه معظمه لبن مبخر مع جرعة أو اتنين إسبريسو، وطبقة رغوة رقيقة في الآخر. '
        'اختاره لما تكون عايز حاجة سلسة وخفيفة وكريمية.',
    topic: 'drinks',
  ),
  KnowledgeArticle(
    id: 'mocha-guide',
    title: 'What is a mocha?',
    titleAr: 'إيه الموكا؟',
    keywords: ['mocha', 'chocolate', 'sweet', 'cocoa', 'dessert'],
    keywordsAr: [
      'موكا',
      'موكه',
      'شوكولاتة',
      'كاكاو',
      'حلو',
      'حلوا',
    ],
    body:
        'A mocha is espresso mixed with chocolate and steamed milk, often topped with whipped cream. '
        'It is the sweetest espresso drink we make, great as an afternoon treat.',
    bodyAr:
        'الموكا إسبريسو مخلوط بالشوكولاتة واللبن المبخر، وبيتوجّه أحيانًا بكريمة مخفوقة. '
        'وأحلى مشروب إسبريسو حلو عندنا، ويناسب وقت الضهر.',
    topic: 'drinks',
  ),
  KnowledgeArticle(
    id: 'cold-coffee-guide',
    title: 'Cold coffee options',
    titleAr: 'خيارات القهوة الباردة',
    keywords: ['cold', 'iced', 'summer', 'hot weather', 'refreshing', 'cold brew'],
    keywordsAr: [
      'بارد',
      'بارده',
      'مثلج',
      'متلج',
      'صيف',
      'حر',
      'منعش',
      'اترطب',
    ],
    body:
        'For hot days, go for an Iced Latte for creamy refreshment, or a Chocolate Milkshake when you want '
        'something indulgent. Cold drinks keep their flavor best when served over plenty of ice.',
    bodyAr:
        'في الجو الحر، خد Iced Latte منعشة وكريمية، أو Chocolate Milkshake لو عايز حاجة تدل. '
        'والمشروبات الباردة بتفضل طعمها أحسن على تلج كتير.',
    topic: 'drinks',
  ),
  KnowledgeArticle(
    id: 'arabica-vs-robusta',
    title: 'Arabica vs Robusta',
    titleAr: 'العربية ضد الروبوستا',
    keywords: ['arabica', 'robusta', 'beans', 'bean', 'origin', 'blend'],
    keywordsAr: [
      'عربي',
      'ارابيكا',
      'روبوستا',
      'بن',
      'حبوب',
      'اصلي',
      'نوع البن',
      'انواع البن',
    ],
    body:
        'Arabica beans taste sweeter and more aromatic with less caffeine. Robusta is bolder, more bitter '
        'and has almost twice the caffeine. Most specialty drinks here use 100% Arabica.',
    bodyAr:
        'بن العربية طعمها أحلى وأعطر وبكافيين أقل، والروبوستا أقوى وأمر وحلاوتها معدومة تقريبًا وكافيينها الضعف. '
        'معظم مشروباتنا هنا 100% عربية.',
    topic: 'beans',
  ),
  KnowledgeArticle(
    id: 'grind-guide',
    title: 'Grind size guide',
    titleAr: 'دليل درجة الطحن',
    keywords: ['grind', 'grinder', 'fine', 'coarse', 'grounds'],
    keywordsAr: [
      'طحن',
      'مطحنة',
      'ناعم',
      'خشن',
      'مطحون',
      'درجه الطحن',
    ],
    body:
        'Match the grind to the brew: fine like sugar for espresso, medium for drip, and coarse like sea salt '
        'for French press. Too fine tastes bitter, too coarse tastes sour and weak.',
    bodyAr:
        'ظبّط الدرجة على طريقة التحضير: ناعم زي السكر للإسبريسو، متوسط للفلتر، وخشن زي الملح للـ French press. '
        'الناعم أوي بيطلع مر، والخشن بيطلع حامض وضعيف.',
    topic: 'brewing',
  ),
  KnowledgeArticle(
    id: 'french-press',
    title: 'French press at home',
    titleAr: 'الـ French press في البيت',
    keywords: ['french press', 'press', 'home', 'brew at home', 'plunger'],
    keywordsAr: [
      'فرنش press',
      'كبسه',
      'في البيت',
      'اغلي في البيت',
    ],
    body:
        'Use coarse coffee, 1 part coffee to 15 parts water just off the boil. Steep 4 minutes, break the '
        'crust, skim the foam, then press slowly. Full-bodied and forgiving.',
    bodyAr:
        'استخدم قهوة خشنة، جزء قهوة لـ 15 جزء مياه سخنة برا ما تغلي. سيبه 4 دقايق، اكسر القشرة، '
        'شيل الرغوة، وبعدين اضغط ببطء. نتيجة كاملة وطريقة سهلة.',
    topic: 'brewing',
  ),
  KnowledgeArticle(
    id: 'pour-over',
    title: 'Pour over at home',
    titleAr: 'الـ Pour over في البيت',
    keywords: ['pour over', 'v60', 'drip', 'filter', 'pourover'],
    keywordsAr: [
      'pour over',
      'فلتر',
      'مقهى',
      'في البيت',
      'قمعه',
    ],
    body:
        'Use medium-fine coffee and water around 92 to 94 C. Bloom with a little water for 30 seconds, then '
        'pour in slow circles. Total brew time is about 2 and a half to 3 minutes for a clean, bright cup.',
    bodyAr:
        'استخدم قهوة شبه ناعمة ومية حوالين 92 لـ 94 درجة. ابدأ بقليل من المية 30 ثانية، وبعدين '
        'صبّ في دواير بطيئة. الوقت الكلي حوالي دقيقتين ونص لـ 3 دقايق.',
    topic: 'brewing',
  ),
  KnowledgeArticle(
    id: 'caffeine-guide',
    title: 'Caffeine guide',
    titleAr: 'دليل الكافيين',
    keywords: ['caffeine', 'energy', 'awake', 'sleep', 'mg', 'strong', 'wired'],
    keywordsAr: [
      'كافيين',
      'كام كافيين',
      'كافيين كام',
      'منبه',
      'صحي',
      'نوم',
      'مليجرام',
      'مليغرام',
      'بيصحي',
    ],
    body:
        'A single espresso shot has about 60 to 75 mg of caffeine, a milk-based cup has 60 to 150 mg depending '
        'on the shots, and a cola has around 30 to 40 mg. Avoid caffeine 6 hours before bed if it keeps you up.',
    bodyAr:
        'جرعة الإسبريسو فيها حوالي 60 لـ 75 مليغرام كافيين، وأي كوب بلبن فيه من 60 لـ 150 حسب عدد الجرعات، '
        'والكولا حوالي 30 لـ 40. تجنب الكافيين قبل النوم بـ 6 ساعات لو بيصحيّك.',
    topic: 'caffeine',
  ),
  KnowledgeArticle(
    id: 'decaf-guide',
    title: 'Decaf options',
    titleAr: 'خيارات بدون كافيين',
    keywords: ['decaf', 'decaffeinated', 'low caffeine', 'no caffeine', 'evening', 'night'],
    keywordsAr: [
      'ديكاف',
      'بلا كافيين',
      'كافيين قليل',
      'بالليل',
      'مسائي',
      'من غير كافيين',
    ],
    body:
        'Want the taste without the buzz? Ask for any milk drink decaf, or try our Green Tea and Masala Tea, '
        'which are naturally much lower in caffeine than coffee.',
    bodyAr:
        'عايز الطعم بدون الصرعة؟ اطلب أي مشروب بلبن ديكاف، أو جرّب Green Tea وMasala Tea — '
        'دول كافيينهم طبيعي أقل بكتير من القهوة.',
    topic: 'caffeine',
  ),
  KnowledgeArticle(
    id: 'milk-guide',
    title: 'Milk options',
    titleAr: 'خيارات اللبن',
    keywords: ['milk', 'oat', 'almond', 'soy', 'lactose', 'dairy', 'skim'],
    keywordsAr: [
      'لبن',
      'حليب',
      'شوفان',
      'لوز',
      'صويا',
      'لاكتوز',
    ],
    body:
        'Whole milk gives the creamiest foam, while oat milk steams closest to dairy. Tell us if you are '
        'lactose intolerant and we will happily swap your milk at no fuss.',
    bodyAr:
        'لبن كامل الدسم بيطلع رغوة أكتر كريمية، وحليب الشوفان بيتبخر أقرب لللبن. '
        'قولنا لو عندك حساسية من اللاكتوز وهنبدّل اللبن من غير أي مشاكل.',
    topic: 'drinks',
  ),
  KnowledgeArticle(
    id: 'tea-guide',
    title: 'Tea options',
    titleAr: 'خيارات الشاي',
    keywords: ['tea', 'green tea', 'masala', 'chai', 'herbal'],
    keywordsAr: [
      'شاي',
      'شاي اخضر',
      'مالالا',
      'كرك',
      'شاي بالهيل',
      'انواع الشاي',
    ],
    body:
        'Our Green Tea is light and calming with natural antioxidants. Masala Tea is warm and spiced with '
        'cardamom, ginger and cinnamon, blended with milk for comfort.',
    bodyAr:
        'الشاي الأخضر خفيف ومريح وفيه مضادات أكسدة طبيعية. ومالالا دافي بالهيل والزنجبيل والقرفة، مخلوط بلبن.',
    topic: 'drinks',
  ),
  KnowledgeArticle(
    id: 'bean-storage',
    title: 'Keeping beans fresh',
    titleAr: 'تخزين البن طازج',
    keywords: ['store', 'storage', 'fresh', 'keep', 'beans', 'stale'],
    keywordsAr: [
      'تخزين',
      'احفظ',
      'طازج',
      'البن',
      'يبوظ',
    ],
    body:
        'Keep beans in an airtight container at room temperature, away from light and moisture. '
        'Buy small amounts often and grind right before brewing for the best flavor.',
    bodyAr:
        'خلي البن في علبة محكمة في درجة حرارة الغرفة، بعيد عن الضوء والرطوبة. '
        'اشتري كميات صغيرة كتير واطحنه قبل التحضير علشان أحسن طعم.',
    topic: 'beans',
  ),
  KnowledgeArticle(
    id: 'snacks-pairing',
    title: 'What to eat with coffee',
    titleAr: 'إيه اللي يتاكل مع القهوة',
    keywords: ['snack', 'eat', 'food', 'pair', 'cookie', 'croissant', 'cake', 'brownie', 'hungry'],
    keywordsAr: [
      'اكل',
      'وجبه',
      'كوكي',
      'كرواسون',
      'براوني',
      'تشيز كيك',
      'جوعان',
      'يتاكل مع',
      'ماشي مع',
      'مع القهوه',
      'حاجه مع القهوه',
      'ينفع مع',
      'ينفع مع القهوه',
      'اكمل مع',
      'احسن حاجه مع',
      'ايه يتاكل مع',
    ],
    body:
        'Chocolate Chip Cookies and Brownies pair perfectly with espresso, while a Butter Croissant is the '
        'classic match for a morning Latte or Cappuccino.',
    bodyAr:
        'كوكيز الشوكولاتة والبراوني مع الإسبريسو ماشيين زي الفل، وكرواسون الزبد هو الاقتران الكلاسيكي '
        'مع اللاتيه أو الكابتشينو في الصبح.',
    topic: 'food',
  ),
];
