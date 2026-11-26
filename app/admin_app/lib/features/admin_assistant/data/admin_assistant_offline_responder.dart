import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/features/admin_assistant/data/admin_assistant_business_data.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum AdminAssistantOfflineIntent {
  greeting,
  thanks,
  compareDrinks,
  productCopy,
  recommendation,
  cafeKnowledge,
  liveBusinessData,
  clarify,
}

enum AdminAssistantMood { neutral, frustrated, urgent, confused, positive }

/// Result of the first, cheap understanding pass. The app can inspect this in
/// tests without contacting Supabase or an LLM provider.
class AdminAssistantOfflineAnalysis {
  const AdminAssistantOfflineAnalysis({
    required this.intent,
    required this.normalizedText,
    required this.entities,
    required this.isArabic,
    this.liveDataKind = '',
    this.mood = AdminAssistantMood.neutral,
  });

  final AdminAssistantOfflineIntent intent;
  final String normalizedText;
  final Set<String> entities;
  final bool isArabic;
  final String liveDataKind;
  final AdminAssistantMood mood;
}

class AdminAssistantOfflineResponder {
  const AdminAssistantOfflineResponder(this._client);

  final SupabaseClient _client;

  /// Pipeline: normalize noisy text, understand intent/entities, retrieve a
  /// grounded local or approved article, then compose a bounded answer.
  Future<String> reply(
    String query, {
    List<Map<String, String>> history = const [],
    AdminAssistantBusinessData? businessData,
    String? assistantName,
  }) async {
    final contextualQuery = contextualizeQuery(query, history);
    final analysis = understand(contextualQuery);
    final contextual = _resolveFollowUp(query, history, analysis);
    final effective = contextual ?? analysis;

    if (effective.intent == AdminAssistantOfflineIntent.liveBusinessData) {
      if (businessData != null) {
        final answer = businessData.offlineReply(
          contextualQuery,
          arabic: effective.isArabic,
        );
        return _compose(
          _adaptTone(answer, effective.mood, arabic: effective.isArabic),
        );
      }
      return effective.liveDataKind.startsWith('unsupported')
          ? (effective.isArabic
                ? 'قراءة هذا النوع من البيانات ليست موصولة بالمساعد بعد. أقدر حاليًا قراءة ملخصات المبيعات والطلبات والمخزون الخام ضمن صلاحيات حسابك.'
                : 'This data source is not connected to the assistant yet. I can currently read sales, order, and raw-material inventory summaries within your account permissions.')
          : (effective.isArabic
                ? 'لم أتمكن من جلب البيانات من لوحة التحكم الآن. تحقق من الاتصال والصلاحيات وحاول مرة أخرى.'
                : 'I couldn’t retrieve the dashboard data right now. Check the connection and permissions, then try again.');
    }

    final local = _localAnswer(effective, assistantName: assistantName);
    if (local != null) {
      return _compose(
        _adaptTone(local, effective.mood, arabic: effective.isArabic),
      );
    }

    if (effective.intent == AdminAssistantOfflineIntent.cafeKnowledge) {
      final article = await _searchApprovedArticle(
        query,
        arabic: effective.isArabic,
      );
      if (article != null) return _compose(article);
    }

    return _compose(
      effective.isArabic
          ? 'لم أجد معلومة معتمدة كفاية للإجابة من غير تخمين. اكتب اسم المشروب أو المكوّن، أو وضّح المطلوب (معلومة، مقارنة، وصف منتج، أو رقم تشغيلي).'
          : 'I couldn’t find enough approved information to answer without guessing. Name the drink or ingredient, or clarify whether you need an explanation, comparison, product copy, or an operational figure.',
    );
  }

  /// Keeps short period corrections attached to the previous business
  /// question, so "من أول الشهر" still resolves as a sales query.
  static String contextualizeQuery(
    String query,
    List<Map<String, String>> history,
  ) {
    if (history.isEmpty) return query;
    final previousUser = history.reversed
        .where((message) => message['role'] == 'user')
        .map((message) => message['content'] ?? '')
        .firstWhere((content) => content.trim().isNotEmpty, orElse: () => '');
    if (previousUser.isEmpty ||
        understand(previousUser).intent !=
            AdminAssistantOfflineIntent.liveBusinessData) {
      return query;
    }
    final text = _normalize(query);
    final hasPeriod = _containsAny(text, const [
      'اليوم',
      'النهارده',
      'النهاردة',
      'امس',
      'امبارح',
      'الاسبوع',
      'الشهر',
      'من اول الشهر',
      'من بداية الشهر',
      'بداية الشهر',
      'من البداية',
      'اللي فات',
      'this month',
      'month to date',
      'this week',
      'last week',
      'today',
      'yesterday',
      'from the beginning',
    ]);
    final hasMetric = _containsAny(text, const [
      'مبيعات',
      'ايرادات',
      'ارباح',
      'طلبات',
      'متوسط',
      'sales',
      'revenue',
      'orders',
      'average',
      'top products',
      'مخزون',
      'مواد خام',
    ]);
    if (hasPeriod && !hasMetric) return '$previousUser $query';
    return query;
  }

  static AdminAssistantOfflineAnalysis understand(String input) {
    final text = _normalize(input);
    final tokens = text.split(' ').where((item) => item.isNotEmpty).toSet();
    final hasArabic = RegExp(r'[\u0600-\u06ff]').hasMatch(input);
    final hasLatin = RegExp(r'[a-zA-Z]').hasMatch(input);
    final entities = <String>{};
    for (final entry in _entityTerms.entries) {
      if (entry.value.any(
        (term) => _hasTerm(_expandAffixes(text), _normalize(term)),
      )) {
        entities.add(entry.key);
      }
    }

    final intent = _isGreeting(tokens)
        ? AdminAssistantOfflineIntent.greeting
        : _isThanks(tokens)
        ? AdminAssistantOfflineIntent.thanks
        : entities.length >= 2 && _isComparison(text)
        ? AdminAssistantOfflineIntent.compareDrinks
        : _asksForCopy(text)
        ? AdminAssistantOfflineIntent.productCopy
        : _asksForLiveData(text)
        ? AdminAssistantOfflineIntent.liveBusinessData
        : _asksForRecommendation(text)
        ? AdminAssistantOfflineIntent.recommendation
        : _looksLikeKnowledgeQuestion(text, entities)
        ? AdminAssistantOfflineIntent.cafeKnowledge
        : AdminAssistantOfflineIntent.clarify;

    return AdminAssistantOfflineAnalysis(
      intent: intent,
      normalizedText: text,
      entities: entities,
      isArabic: hasArabic || (!hasLatin && AppLocale.instance.isArabic),
      liveDataKind: intent == AdminAssistantOfflineIntent.liveBusinessData
          ? _liveDataKind(text)
          : '',
      mood: detectMood(input),
    );
  }

  /// Identifies turns that may contain customer names, purchases, or loyalty
  /// details. These turns must not be replayed into a language-model prompt.
  static bool isCustomerDataQuery(String input) {
    final analysis = understand(input);
    return analysis.intent == AdminAssistantOfflineIntent.liveBusinessData &&
        (analysis.liveDataKind.startsWith('customer_') ||
            analysis.liveDataKind == 'order_lookup');
  }

  static bool asksForPerCouponPerformance(String input) {
    final text = _normalize(input);
    return _containsAny(text, const [
      'اداء كل كوبون',
      'اداء الكوبونات',
      'قارن الكوبونات',
      'مقارنة الكوبونات',
      'تفاصيل الكوبونات',
      'تفاصيل كل كوبون',
      'اكثر كوبون استخداما',
      'اقل كوبون استخداما',
      'coupon performance',
      'compare coupons',
      'each coupon',
      'per coupon',
      'coupon details',
      'most redeemed coupon',
    ]);
  }

  /// Detects explicit order-creation commands. Analytics questions about order
  /// counts intentionally do not match this list.
  static bool asksToCreateOrder(String input) {
    final text = _normalize(input);
    return _containsAny(text, const [
      'اعمل طلب',
      'اعملي طلب',
      'انشئ طلب',
      'انشاء طلب',
      'سجل طلب جديد',
      'ضيف طلب جديد',
      'افتح طلب جديد',
      'نفذ طلب جديد',
      'اعمل اوردر',
      'اعملي اوردر',
      'سجل اوردر',
      'create an order',
      'create order',
      'place an order',
      'place order',
      'make an order',
      'make order',
    ]);
  }

  static AdminAssistantMood detectMood(String input) {
    final text = _normalize(input);
    if (_containsAny(text, const [
      'بسرعه',
      'بسرعة',
      'حالاً',
      'حالا',
      'ضروري',
      'بسرعة لو سمحت',
      'urgent',
      'right now',
      'asap',
      'quickly',
    ])) {
      return AdminAssistantMood.urgent;
    }
    if (_containsAny(text, const [
      'مش شغال',
      'غلط',
      'باظ',
      'زهقت',
      'تعبت',
      'مستفز',
      'سيء',
      'وحش',
      'كل مره',
      'ما ينفعش',
      'مش نافع',
      'not working',
      'wrong again',
      'frustrated',
      'this is broken',
    ])) {
      return AdminAssistantMood.frustrated;
    }
    if (_containsAny(text, const [
      'يعني ايه',
      'ازاي',
      'كيف',
      'مش واضح',
      'اشرح',
      'وضح',
      'i do not understand',
      'what does that mean',
      'explain',
      'confused',
    ])) {
      return AdminAssistantMood.confused;
    }
    if (_containsAny(text, const [
      'ممتاز',
      'رائع',
      'جميل',
      'حلو جدا',
      'فرحان',
      'مبسوط',
      'great',
      'awesome',
      'love it',
      'happy',
    ])) {
      return AdminAssistantMood.positive;
    }
    return AdminAssistantMood.neutral;
  }

  static String moodInstruction(String query, {required bool arabic}) =>
      switch (detectMood(query)) {
        AdminAssistantMood.frustrated =>
          arabic
              ? 'المستخدم قد يكون منزعجًا من التجربة؛ ابدأ باعتراف موجز بالمشكلة ثم أعطِ خطوة أو إجابة واضحة، من غير لوم أو مبالغة.'
              : 'The user may be frustrated with the experience; briefly acknowledge the problem, then give a clear answer or next step without blame or overdoing it.',
        AdminAssistantMood.urgent =>
          arabic
              ? 'المستخدم يبدو مستعجلًا؛ ابدأ بالخلاصة مباشرة ثم أضف التفصيل الضروري فقط.'
              : 'The user seems in a hurry; lead with the answer and include only essential detail.',
        AdminAssistantMood.confused =>
          arabic
              ? 'بسّط الشرح واستخدم مثالًا قصيرًا عند الحاجة، ولا تفترض أن المستخدم يعرف المصطلحات.'
              : 'Explain simply and use a short example if helpful; do not assume the user knows the terminology.',
        AdminAssistantMood.positive =>
          arabic
              ? 'حافظ على النبرة الودودة والإيجابية، مع إجابة مباشرة.'
              : 'Keep a warm, positive tone while answering directly.',
        AdminAssistantMood.neutral =>
          arabic
              ? 'استخدم نبرة ودودة وواضحة، وأكمل الجملة والفكرة قبل إرسال الرد.'
              : 'Use a friendly, clear tone and finish the sentence and thought before sending.',
      };

  String _adaptTone(
    String answer,
    AdminAssistantMood mood, {
    required bool arabic,
  }) => switch (mood) {
    AdminAssistantMood.frustrated =>
      arabic
          ? 'فاهم إن ده محبط. $answer'
          : 'I understand this is frustrating. $answer',
    AdminAssistantMood.urgent =>
      arabic ? 'الخلاصة: $answer' : 'Here’s the short answer: $answer',
    AdminAssistantMood.confused =>
      arabic
          ? 'خلّيني أوضحها ببساطة: $answer'
          : 'Let me put it simply: $answer',
    AdminAssistantMood.neutral || AdminAssistantMood.positive => answer,
  };

  AdminAssistantOfflineAnalysis? _resolveFollowUp(
    String query,
    List<Map<String, String>> history,
    AdminAssistantOfflineAnalysis current,
  ) {
    if (history.isEmpty ||
        current.intent != AdminAssistantOfflineIntent.clarify) {
      return null;
    }
    final text = _normalize(query);
    const followUps = [
      'والتاني',
      'والتانيه',
      'طب والتاني',
      'وضح اكتر',
      'ممكن توضح',
      'كمل',
      'ليه',
      'طيب بعدين',
      'more',
      'why',
      'explain more',
      'and the other',
    ];
    if (!followUps.any((phrase) => _hasTerm(text, _normalize(phrase)))) {
      return null;
    }

    final previousUser = history.reversed
        .where((message) => message['role'] == 'user')
        .map((message) => message['content'] ?? '')
        .take(4)
        .join(' ');
    final previous = understand(previousUser);
    if (previous.intent == AdminAssistantOfflineIntent.compareDrinks ||
        previous.intent == AdminAssistantOfflineIntent.cafeKnowledge) {
      return AdminAssistantOfflineAnalysis(
        intent: previous.intent,
        normalizedText: previous.normalizedText,
        entities: previous.entities,
        isArabic: current.isArabic,
        liveDataKind: previous.liveDataKind,
        mood: current.mood,
      );
    }
    return null;
  }

  String? _localAnswer(
    AdminAssistantOfflineAnalysis analysis, {
    String? assistantName,
  }) {
    final ar = analysis.isArabic;
    final q = analysis.normalizedText;
    switch (analysis.intent) {
      case AdminAssistantOfflineIntent.greeting:
        final name = _firstName(assistantName);
        return ar
            ? 'أهلًا${name == null ? ' بيك' : ' يا $name'}! أقدر أساعدك بمعلومات الكافيه وبياناته المسموح بها، ولو في حاجة ناقصة هقولك بوضوح.'
            : 'Hi${name == null ? '' : ' $name'}! I can help with cafe information and data available to your role, and I’ll be clear whenever something is missing.';
      case AdminAssistantOfflineIntent.thanks:
        return ar
            ? 'العفو! أنا موجود لو احتجت معلومة أو مقارنة تانية.'
            : 'You’re welcome! I’m here if you need another explanation or comparison.';
      case AdminAssistantOfflineIntent.compareDrinks:
        return _compare(analysis.entities, ar: ar);
      case AdminAssistantOfflineIntent.productCopy:
        return _productCopyPrompt(q, ar: ar);
      case AdminAssistantOfflineIntent.recommendation:
        return ar
            ? 'أرشح لك بعد ما أعرف تفضيلك: تحبها سخنة ولا باردة؟ بطعم قهوة قوي ولا خفيف؟ وهل في مكوّن أو حساسية لازم أتجنبها؟ هاقارن إجابتك بالمنيو المعتمد بدل ما أخمّن صنفًا أو توفره.'
            : 'I can narrow it down if you tell me: hot or iced, strong coffee or mild, and any ingredient or allergy to avoid? I’ll use the approved menu rather than guess a product or its availability.';
      case AdminAssistantOfflineIntent.cafeKnowledge:
        final fact = _localFact(analysis.entities, q, ar: ar);
        if (fact != null) return fact;
        return null;
      case AdminAssistantOfflineIntent.liveBusinessData:
      case AdminAssistantOfflineIntent.clarify:
        return null;
    }
  }

  String? _localFact(Set<String> entities, String query, {required bool ar}) {
    if (entities.contains('espresso')) {
      return ar
          ? 'الإسبريسو قهوة مركزة تُحضّر بتمرير مياه ساخنة بضغط خلال بن مطحون ناعم. حجم الشوت والوصفة يختلفان حسب الكافيه.'
          : 'Espresso is concentrated coffee made by forcing hot water through finely ground coffee. Shot size and recipe vary by cafe.';
    }
    if (entities.contains('cold_brew') || entities.contains('iced_coffee')) {
      return ar
          ? 'الآيس كوفي اسم عام لمشروبات قهوة باردة. الآيس لاتيه عادةً إسبريسو ولبن بارد وثلج، أما الكولد برو فيُنقع فيه البن بمياه باردة أو بدرجة الغرفة لساعات. التوفر والوصفة يعتمدان على منيو الكافيه.'
          : 'Iced coffee is a broad term. An iced latte is usually espresso, cold milk, and ice; cold brew steeps coffee in cool or room-temperature water for hours. The cafe menu determines what is available.';
    }
    if (entities.contains('arabica') || entities.contains('robusta')) {
      return ar
          ? 'الأرابيكا غالبًا نكهتها أوسع وأنعم، والروبوستا غالبًا أقوى ومرارتها أوضح وكافيينها أعلى بالوزن. دي اتجاهات عامة؛ المنشأ والتحميص والتحضير يغيّروا الطعم.'
          : 'Arabica often has a wider, more delicate flavor range; Robusta is often stronger, more bitter, and higher in caffeine by weight. These are tendencies, and origin, roast, and brewing all matter.';
    }
    if (entities.contains('decaf') ||
        _containsAny(query, const ['كافيين', 'caffeine'])) {
      return ar
          ? 'القهوة منزوعة الكافيين ما زال فيها عادةً قدر قليل من الكافيين، وليست خالية منه تمامًا. الكمية تختلف حسب الحبوب وطريقة التحضير.'
          : 'Decaf coffee usually still contains a small amount of caffeine; it is not always completely caffeine-free. The amount varies by beans and brewing method.';
    }
    if (entities.contains('v60')) {
      return ar
          ? 'الـV60 طريقة ترشيح يدوية: بن بطحن متوسط مائل للنعومة، ومياه ساخنة تُصب تدريجيًا على دفعات. كنقطة بداية عامة، نسبة 1:15 وحرارة 92–96°م مناسبة للتجربة، ثم عدّل حسب الطعم.'
          : 'A V60 is a manual pour-over method. Start with a medium-fine grind and pour hot water in controlled stages. A 1:15 coffee-to-water ratio and 92–96°C are reasonable starting points; adjust to taste.';
    }
    if (entities.contains('french_press')) {
      return ar
          ? 'للفرنش برس ابدأ بطحن خشن ونسبة تقارب 1 جزء قهوة إلى 15 جزء مياه بالوزن. انقع نحو 4 دقائق واضغط ببطء، وعدّل الوصفة حسب ذوقك.'
          : 'For French press, start with coarse grounds and about 1 part coffee to 15 parts water by weight. Steep for around 4 minutes, press slowly, and adjust to taste.';
    }
    if (entities.contains('mocha')) {
      return ar
          ? 'الموكا غالبًا إسبريسو مع شوكولاتة أو كاكاو ولبن. الإضافات والحلاوة والمكونات الدقيقة تختلف حسب وصفة الكافيه، فراجع بطاقة المنتج للحساسية والمكونات المؤكدة.'
          : 'Mocha commonly combines espresso, chocolate or cocoa, and milk. Additions, sweetness, and exact ingredients vary by cafe, so check the product record for confirmed ingredients and allergen details.';
    }
    if (entities.contains('americano')) {
      return ar
          ? 'الأمريكانو يتكوّن عادةً من إسبريسو ومياه ساخنة، فيكون أخف تركيزًا من الشوت وحده مع بقاء طعم القهوة واضحًا. الحجم والنسبة يختلفان حسب وصفة الكافيه.'
          : 'An Americano is usually espresso diluted with hot water. It is less concentrated than a straight shot while keeping a clear coffee flavor. Size and ratio vary by cafe.';
    }
    if (entities.contains('flat_white')) {
      return ar
          ? 'الفلات وايت عادةً إسبريسو مع لبن مبخر بقوام ناعم ورغوة دقيقة، وحجمه غالبًا أصغر من اللاتيه. التفاصيل تختلف حسب وصفة الكافيه.'
          : 'A flat white is commonly espresso with steamed milk and fine microfoam, often served smaller than a latte. Exact details vary by cafe.';
    }
    if (entities.contains('cortado')) {
      return ar
          ? 'الكورتادو إسبريسو مع كمية قريبة منه من اللبن المبخر لتخفيف حدّة القهوة مع الحفاظ على حضورها. النسبة والحجم يختلفان حسب الوصفة.'
          : 'A cortado pairs espresso with a similar amount of steamed milk, softening the coffee while keeping it prominent. Ratios and serving size vary.';
    }
    if (entities.contains('macchiato')) {
      return ar
          ? 'الماكياتو التقليدي إسبريسو مع لمسة صغيرة من اللبن أو الرغوة. بعض المقاهي تستخدم الاسم لمشروبات مختلفة، فراجع وصف المنتج لمعرفة نسخة الكافيه.'
          : 'A traditional macchiato is espresso marked with a small amount of milk or foam. Some cafes use the name for different drinks, so check the cafe’s product description.';
    }
    if (_containsAny(query, const [
      'لبن نباتي',
      'حليب نباتي',
      'بديل اللبن',
      'oat milk',
      'almond milk',
      'plant milk',
    ])) {
      return ar
          ? 'بدائل اللبن تشمل الشوفان واللوز والصويا وجوز الهند. الطعم والرغوة ومسببات الحساسية تختلف بين الأنواع والعلامات؛ لا تؤكد توفر بديل أو خلوه من مسببات الحساسية إلا بعد مراجعة بيانات المنتج.'
          : 'Common milk alternatives include oat, almond, soy, and coconut. Taste, foam, and allergens vary by brand; verify the product record before confirming availability or allergen safety.';
    }
    if (_containsAny(query, const ['حساسيه', 'حساسي', 'allergy', 'allergen'])) {
      return ar
          ? 'الحساسية سؤال لازم إجابته تكون من مكونات المنتج المعتمدة، لأن الوصفة ومخاطر التلامس تختلف. ابعت اسم المنتج لأبحث في المعرفة المعتمدة، ولا تعتمد على تخمين عام.'
          : 'Allergy questions must be answered from the approved ingredient record because recipes and cross-contact risks vary. Share the product name so I can check approved knowledge; don’t rely on a general guess.';
    }
    return null;
  }

  String _compare(Set<String> entities, {required bool ar}) {
    final latte = entities.contains('latte');
    final cappuccino = entities.contains('cappuccino');
    final mocha = entities.contains('mocha');
    if (latte && cappuccino) {
      return ar
          ? 'الاتنين أساسهم الإسبريسو واللبن. اللاتيه فيه لبن مبخر أكتر عادةً ورغوته أخف، فطعمه أنعم وإحساس القهوة أهدى. الكابتشينو رغوته أوضح وإحساس الإسبريسو فيه أقوى غالبًا. النسب الدقيقة بتختلف حسب وصفة الكافيه.'
          : 'Both are espresso and milk drinks. A latte usually has more steamed milk and a thinner foam layer, so it tastes smoother and milder. A cappuccino usually has more noticeable foam and a stronger coffee impression. Exact proportions vary by cafe recipe.';
    }
    if (latte && mocha) {
      return ar
          ? 'اللاتيه إسبريسو ولبن مبخر بطعم قهوة ناعم. الموكا قريبة منه لكنها تضيف شوكولاتة أو كاكاو غالبًا، لذلك تكون أحلى عادةً. مكونات وصفة الكافيه هي المرجع النهائي.'
          : 'A latte is espresso with steamed milk and a smooth coffee flavor. A mocha is similar but commonly adds chocolate or cocoa, making it sweeter. The cafe recipe is the final source for ingredients.';
    }
    if (entities.contains('arabica') && entities.contains('robusta')) {
      return ar
          ? 'الأرابيكا غالبًا نكهتها أوسع وأنعم، بينما الروبوستا غالبًا أقوى ومرارتها أوضح وكافيينها أعلى بالوزن. الاختيار يعتمد على الطعم المطلوب وطريقة التحضير؛ دي اتجاهات عامة وليست قاعدة ثابتة.'
          : 'Arabica often has a wider, more delicate flavor, while Robusta is often stronger, more bitter, and higher in caffeine by weight. The better choice depends on the desired flavor and brew method; these are tendencies, not rules.';
    }
    if (entities.contains('cold_brew') && entities.contains('iced_coffee')) {
      return ar
          ? 'الآيس كوفي وصف عام لقهوة تُقدّم باردة، أما الكولد برو فهو طريقة تحضير بنقع القهوة في مياه باردة لساعات. ممكن يكون الكولد برو نوعًا من القهوة الباردة، لكنهما مش نفس طريقة التحضير.'
          : 'Iced coffee is a broad description for coffee served cold. Cold brew is a brewing method that steeps coffee in cool water for hours. Cold brew can be a type of iced coffee, but the terms describe different things.';
    }
    if (entities.contains('v60') && entities.contains('cold_brew')) {
      return ar
          ? 'الـV60 ترشيح سريع بمياه ساخنة تُصب على البن، فيظهر الطعم والرائحة بوضوح. الكولد برو نقع طويل بمياه باردة أو بدرجة الغرفة، وغالبًا يكون أنعم وأقل حموضة محسوسة. النتيجة تتأثر بالبن والوصفة.'
          : 'V60 is a quick hot-water pour-over that highlights aroma and flavor. Cold brew steeps coffee in cool water for a long time and often tastes smoother with less perceived acidity. Beans and recipe affect the result.';
    }
    return ar
        ? 'المشروبان مختلفان في القوام والمكونات. اكتب اسميهما بوضوح وسأقارن بينهما من المعرفة المتاحة.'
        : 'The drinks differ in texture and ingredients. Name both clearly and I’ll compare them using available knowledge.';
  }

  String _productCopyPrompt(String query, {required bool ar}) {
    final latte = _containsAny(query, const ['latte', 'لاتيه']);
    final cappuccino = _containsAny(query, const ['cappuccino', 'كابتشينو']);
    final mocha = _containsAny(query, const ['mocha', 'موكا']);
    final iced = _containsAny(query, const [
      'iced',
      'ايس',
      'مثلج',
      'بارد',
      'ساقع',
    ]);
    final oat = _containsAny(query, const [
      'oat milk',
      'حليب شوفان',
      'لبن شوفان',
    ]);
    final caramel = _containsAny(query, const ['caramel', 'كراميل']);
    final chocolate = _containsAny(query, const [
      'chocolate',
      'شوكولاته',
      'كاكاو',
    ]);
    final namedDrink = latte || cappuccino || mocha;
    if (namedDrink) {
      final name = mocha
          ? (ar ? 'الموكا' : 'mocha')
          : cappuccino
          ? (ar ? 'الكابتشينو' : 'cappuccino')
          : (ar ? 'اللاتيه' : 'latte');
      final modifiers = [
        if (iced) ar ? 'مثلج' : 'iced',
        if (oat) ar ? 'بحليب الشوفان' : 'with oat milk',
        if (caramel) ar ? 'بنكهة الكراميل' : 'with caramel',
        if (chocolate && !mocha) ar ? 'مع الشوكولاتة' : 'with chocolate',
      ];
      final description = ar
          ? 'اكتشف ${modifiers.isEmpty ? name : '$name ${modifiers.join(' و')}'}، مشروب قهوة بطابع متوازن وقوام غني. وصف قصير للمنيو — تأكد من مطابقة المكونات وطريقة التقديم للوصفة المعتمدة قبل النشر.'
          : 'Meet ${modifiers.isEmpty ? name : '$name ${modifiers.join(' ')}'}. A balanced coffee drink with a satisfying texture. Short menu copy — verify ingredients and serving style against the approved recipe before publishing.';
      return description;
    }
    if (!_containsAny(query, const [
      'espresso',
      'اسبرسو',
      'اسبريسو',
      'قهوه',
      'قهوة',
      'chocolate',
      'شوكولاته',
      'كاكاو',
      'milk',
      'لبن',
      'حليب',
      'oat',
      'شوفان',
      'caramel',
      'كراميل',
    ])) {
      return ar
          ? 'أكيد. ابعتلي اسم المنتج ومكوناته الأساسية والجمهور المستهدف، وأكتب لك وصفًا جذابًا من غير ما أضيف مكونات أو وعود غير مؤكدة.'
          : 'Sure. Send the product name, its main ingredients, and target audience. I’ll write appealing copy without adding unverified ingredients or claims.';
    }
    return ar
        ? 'أقدر أصيغ وصفًا اعتمادًا على المكونات التي ذكرتها فقط. اكتب اسم المنتج وحجمه ونبرة الوصف المطلوبة (فخمة، ودودة، أو قصيرة للمنيو).'
        : 'I can write copy using only the ingredients you provided. Send the product name, serving size, and tone (premium, friendly, or short menu copy).';
  }

  Future<String?> _searchApprovedArticle(
    String query, {
    required bool arabic,
  }) async {
    try {
      final raw = await _client
          .rpc(
            'assistant_search_knowledge',
            params: <String, dynamic>{
              'p_query': query,
              'p_branch_id': null,
              'p_locale': arabic ? 'ar' : 'en',
              'p_limit': 4,
            },
          )
          .timeout(const Duration(milliseconds: 1200));
      if (raw is! List) return null;
      final candidates =
          raw
              .whereType<Map>()
              .map((row) {
                final rawScore = row['score'];
                final score = rawScore is num
                    ? rawScore.toDouble()
                    : double.tryParse('$rawScore') ?? 0;
                return (row: row, score: score);
              })
              .where(
                (item) =>
                    item.row['source_type'] == 'article' && item.score >= 0.28,
              )
              .toList()
            ..sort((a, b) => b.score.compareTo(a.score));
      if (candidates.isEmpty) return null;
      final row = candidates.first.row;
      final title = '${row['title'] ?? ''}'.trim();
      final body = '${row['body'] ?? ''}'.trim();
      if (body.isEmpty) return null;
      return title.isEmpty ? body : '$title\n$body';
    } catch (_) {
      // Deterministic local answers remain available if Supabase is offline too.
      return null;
    }
  }

  static bool _looksLikeKnowledgeQuestion(String text, Set<String> entities) =>
      entities.isNotEmpty ||
      _containsAny(text, const [
        'ليه',
        'لماذا',
        'ازاي',
        'كيف',
        'ايه هو',
        'ما هو',
        'يعني ايه',
        'طريقة',
        'تحضير',
        'مكونات',
        'مكون',
        'مقارنه',
        'الفرق',
        'لبن',
        'حليب',
        'سكر',
        'حساسيه',
        'حساسي',
        'allergy',
        'allergen',
        'allergic',
        'كافيين',
        'caffeine',
        'milk',
        'sugar',
        'what is',
        'how to',
        'ingredients',
        'why',
        'meaning',
        'recipe',
        'brew',
        'coffee',
        'قهوة',
        'بن',
        'مشروب',
      ]);

  static bool _isComparison(String text) => _containsAny(text, const [
    'فرق',
    'مقارن',
    'بين',
    'احسن من',
    'افضل من',
    'vs',
    'versus',
    'compare',
    'difference',
    'diff',
    'قارن',
    'اقارن',
    'better than',
    'which is better',
    'which tastes stronger',
    'which is stronger',
    'stronger',
    'انهي احسن',
    'مين احسن',
    'ايهما افضل',
  ]);

  static bool _asksForCopy(String text) => _containsAny(text, const [
    'اكتب وصف',
    'وصف جذاب',
    'وصف منتج',
    'اكتبلي وصف',
    'صياغه',
    'اعلان',
    'كابشن',
    'product description',
    'write a description',
    'write product copy',
    'marketing copy',
    'caption',
  ]);

  static bool _asksForRecommendation(String text) => _containsAny(text, const [
    'رشح',
    'رشحلي',
    'ترشح',
    'ترشحلي',
    'اقترح',
    'اقترحلي',
    'ترشيح',
    'انصحني',
    'انصح',
    'عايز حاجه',
    'ابغى شي',
    'شي يصحصح',
    'حاجه تصحصح',
    'wake me up',
    'recommend',
    'suggest a drink',
    'what should i drink',
    'something strong',
  ]);

  static bool _asksForLiveData(String text) => _containsAny(text, const [
    'مبيعات',
    'خصومات',
    'الخصومات',
    'كوبون',
    'كوبونات',
    'discounts',
    'discount',
    'coupon',
    'coupons',
    'redemptions',
    'المبيعات',
    'ايرادات',
    'ارباح',
    'ربح',
    'مخزون',
    'المخزون',
    'مواد خام',
    'raw materials',
    'low stock materials',
    'طلبات اليوم',
    'الطلبات',
    'طلب',
    'اوردر',
    'الطلبات المتاخره',
    'الاكثر مبيعا',
    'اكثر منتجات مبيعا',
    'خمس منتجات مبيعا',
    'كم بعنا',
    'كم طلب',
    'overdue order',
    'overdue orders',
    'late orders',
    'طلبات متأخرة',
    'الطلبات المتأخرة',
    'حجوزات',
    'مبيعات اليوم',
    'اداء التصنيفات',
    'أداء التصنيفات',
    'category performance',
    'sales by category',
    'السعر',
    'سعر',
    'بكام',
    'متاح',
    'متوفر',
    'قائمة المنتجات',
    'المنتجات',
    'المنيو',
    'بتبيعوا ايه',
    'ايه المنتجات',
    'ماذا تبيعون',
    'what do you sell',
    'what products do you have',
    'products',
    'product',
    'menu',
    'sales',
    'revenue',
    'profit',
    'inventory',
    'stock',
    'price',
    'how much is',
    'available',
    'orders today',
    'orders',
    'order',
    'رقم الطلب',
    'حالة الطلب',
    'تفاصيل الطلب',
    'فين الطلب',
    'تابع الطلب',
    'order number',
    'order details',
    'track order',
    'active orders',
    'order status',
    'average order',
    'متوسط الطلب',
    'متوسط وقت تجهيز',
    'زمن تجهيز',
    'حالات الطلب',
    'الطلبات الملغاة',
    'طلبات ملغاة',
    'الغاءات الطلبات',
    'قارن الفروع',
    'اداء الفروع',
    'المدفوعات',
    'فواتير',
    'استرداد',
    'طرق الدفع',
    'حركة المخزون',
    'حركات المخزون',
    'trend',
    'اتجاه',
    'قنوات',
    'channel',
    'هدف',
    'target',
    'top selling',
    'bookings',
    'reservations',
    'tables',
    'طاولات',
    'الطاولات',
    'حجز',
    'reservation details',
    'حجزي',
    'الحجوزات',
    'عميل',
    'عملاء',
    'customers',
    'customer',
    'loyalty',
    'نقاط',
    'ولاء',
    'رصيد',
    'points balance',
    'نقاط الولاء',
    'رصيد نقاط',
    'اشترى',
    'اشترت',
    'مشتريات',
    'اخر شراء',
    'اخر طلب للعميل',
    'تاريخ العميل',
    'how much did we sell',
  ]);

  static String _liveDataKind(String text) {
    if (_containsAny(text, const [
      'خصم',
      'خصومات',
      'كوبون',
      'كوبونات',
      'استخدام الكوبونات',
      'discount',
      'discounts',
      'coupon',
      'coupons',
      'redemptions',
    ])) {
      return 'discounts';
    }
    if (_containsAny(text, const [
      'اداء التصنيفات',
      'أداء التصنيفات',
      'مبيعات التصنيفات',
      'التصنيفات الاكثر مبيعا',
      'category performance',
      'sales by category',
    ])) {
      return 'unsupported_category_performance';
    }
    if (_containsAny(text, const [
      'طلبات متأخرة',
      'الطلبات المتأخرة',
      'overdue orders',
      'late orders',
    ])) {
      return 'unsupported_late_orders';
    }
    if (_containsAny(text, const [
      'حركة المخزون',
      'حركات المخزون',
      'صرف المخزون',
      'استلام المخزون',
      'stock movements',
      'inventory movements',
    ])) {
      return 'inventory_movements';
    }
    if (_containsAny(text, const [
      'المدفوعات',
      'مدفوعات',
      'الفواتير',
      'فواتير',
      'استرداد',
      'استردادات',
      'طريقة الدفع',
      'طرق الدفع',
      'payments',
      'payment',
      'invoices',
      'invoice',
      'refunds',
      'refund',
      'payment methods',
    ])) {
      return 'payment_metrics';
    }
    if (_containsAny(text, const [
      'حالات الطلب',
      'توزيع حالات',
      'الطلبات الملغاة',
      'طلبات ملغاة',
      'الغاءات الطلبات',
      'متوسط وقت تجهيز',
      'زمن تجهيز الطلب',
      'متوسط زمن التحضير',
      'قارن الفروع',
      'اداء الفروع',
      'order status distribution',
      'cancelled orders',
      'average preparation time',
      'branch comparison',
      'branch performance',
    ])) {
      return 'order_metrics';
    }
    if (_containsAny(text, const [
      'مخزون',
      'مخزون خام',
      'مواد خام',
      'مواد المخزون',
      'منخفضة المخزون',
      'نافد',
      'نفد',
      'stock',
      'inventory',
      'raw materials',
    ])) {
      return 'inventory';
    }
    final asksForCustomer = _containsAny(text, const [
      'عميل',
      'العميل',
      'العملاء',
      'customer',
      'customers',
    ]);
    final asksForCustomerHistory = _containsAny(text, const [
      'تفاصيل العميل',
      'بيانات العميل',
      'سجل العميل',
      'سجل مشتريات',
      'مشتريات العميل',
      'اشترى',
      'اشترت',
      'اخر شراء',
      'اخر طلب للعميل',
      'طلباته',
      'طلباتها',
      'عمل ايه',
      'customer details',
      'purchase history',
      'order history',
      'last purchase',
      'last order',
      'what did',
    ]);
    final asksForCustomerPoints = _containsAny(text, const [
      'نقاط',
      'ولاء',
      'رصيد',
      'points',
      'loyalty',
      'balance',
    ]);
    final asksForLoyaltyActivity = _containsAny(text, const [
      'حركة نقاط',
      'حركات نقاط',
      'حركات النقاط',
      'اخر حركات النقاط',
      'سجل النقاط',
      'حساب النقاط',
      'اكتسب',
      'استخدم النقاط',
      'استهلك النقاط',
      'earned',
      'redeemed',
      'points history',
      'points activity',
      'loyalty transactions',
    ]);
    if (asksForCustomerPoints) {
      if (asksForCustomerHistory && asksForLoyaltyActivity) {
        return 'customer_history_and_loyalty_activity';
      }
      if (asksForCustomerHistory) return 'customer_history_and_loyalty';
      return asksForLoyaltyActivity
          ? 'customer_loyalty_activity'
          : 'customer_loyalty';
    }
    if (asksForCustomer && asksForCustomerHistory) return 'customer_history';
    if (asksForCustomerHistory) return 'customer_history';
    if (_containsAny(text, const [
      'حجوزات',
      'حجز',
      'reservation',
      'booking',
      'موعد',
      'appointments',
      'الطاولات',
      'طاولات',
      'tables',
    ])) {
      return _containsAny(text, const [
            'حجز باسم',
            'تفاصيل الحجز',
            'ابحث عن حجز',
            'reservation details',
            'booking for',
          ])
          ? 'unsupported_reservations'
          : 'dining_summary';
    }
    if (_containsAny(text, const [
      'بيانات العميل',
      'تفاصيل العميل',
      'customer details',
      'customer phone',
      'رقم العميل',
      'customers list',
    ])) {
      return 'customer_history';
    }
    if (_containsAny(text, const [
      'عملاء جدد',
      'عدد العملاء',
      'كم عميل',
      'new customers',
      'customer count',
      'registered customers',
    ])) {
      return 'customer_metrics';
    }
    if (_containsAny(text, const [
      'رقم الطلب',
      'حالة الطلب',
      'تفاصيل الطلب',
      'فين الطلب',
      'تابع الطلب',
      'order number',
      'order status',
      'order details',
      'track order',
    ])) {
      return 'order_lookup';
    }
    if (_containsAny(text, const [
      'بتبيعوا ايه',
      'ايه المنتجات',
      'ماذا تبيعون',
      'what do you sell',
      'what products do you have',
    ])) {
      return 'product_catalog';
    }
    if (_containsAny(text, const [
      'الاكثر مبيعا',
      'المنتجات الاكثر مبيعا',
      'اكثر منتجات مبيعا',
      'اكثر خمس منتجات مبيعا',
      'اكثر 5 منتجات مبيعا',
      'top selling',
      'best selling',
      'top products',
      'top five products',
      'top 5 products',
      'best sellers',
    ])) {
      return 'top_products';
    }
    if (_containsAny(text, const [
      'قائمة المنتجات',
      'المنتجات كلها',
      'المنتجات',
      'المنيو',
      'menu',
      'products',
      'product',
    ])) {
      return _containsAny(text, const ['سعر', 'بكام', 'price'])
          ? 'product_details'
          : 'product_catalog';
    }
    if (_containsAny(text, const [
      'سعر',
      'بكام',
      'متاح',
      'متوفر',
      'price',
      'available',
    ])) {
      return 'product_details';
    }
    if (_containsAny(text, const [
      'طلب',
      'طلبات',
      'اوردر',
      'order',
      'orders',
      'متاخر',
      'active orders',
    ])) {
      return 'orders';
    }
    if (_containsAny(text, const [
      'مبيعات',
      'ايرادات',
      'ارباح',
      'ربح',
      'متوسط الطلب',
      'average order',
      'average preparation time',
      'order status distribution',
      'cancelled orders',
      'branch comparison',
      'branch performance',
      'payments',
      'invoices',
      'refunds',
      'payment methods',
      'stock movements',
      'inventory movements',
      'trend',
      'اتجاه',
      'قنوات',
      'channel',
      'هدف',
      'target',
      'sales',
      'revenue',
      'profit',
    ])) {
      return 'sales';
    }
    return 'unsupported';
  }

  static bool _isGreeting(Set<String> tokens) => tokens.any(
    const {
      'hello',
      'hi',
      'hey',
      'مرحبا',
      'اهلا',
      'ازيك',
      'السلام',
      'صباح',
      'مساء',
    }.contains,
  );

  static bool _isThanks(Set<String> tokens) => tokens.any(
    const {
      'thanks',
      'thank',
      'شكرا',
      'متشكر',
      'متشكره',
      'تسلم',
      'مشكور',
    }.contains,
  );

  static bool _hasTerm(String text, String phrase) => phrase.contains(' ')
      ? phrase.split(' ').every((word) => _hasTerm(text, word))
      : text == phrase ||
            text.contains(' $phrase ') ||
            text.startsWith('$phrase ') ||
            text.endsWith(' $phrase');

  static bool _containsAny(String text, List<String> phrases) {
    final normalizedText = _normalize(text);
    final expandedText = _expandAffixes(normalizedText);
    final compactText = normalizedText.replaceAll(' ', '');
    return phrases.any((phrase) {
      final normalizedPhrase = _normalize(phrase);
      final isArabicTerm = RegExp(r'[\u0600-\u06ff]')
          .hasMatch(normalizedPhrase);
      final compactPhrase = normalizedPhrase.replaceAll(' ', '');
      return _hasTerm(expandedText, normalizedPhrase) ||
          (isArabicTerm &&
              compactPhrase.length >= 4 &&
              compactText.contains(compactPhrase));
    });
  }

  static String _expandAffixes(String normalizedText) {
    final expanded = <String>[];
    for (final word in normalizedText.split(' ')) {
      if (word.isEmpty) continue;
      expanded.add(word);
      var stem = word;
      var stripped = true;
      while (stripped) {
        stripped = false;
        for (final prefix in const [
          'وال',
          'بال',
          'كال',
          'فال',
          'لل',
          'ال',
          'و',
          'ب',
          'ف',
          'ل',
          'ك',
        ]) {
          if (stem.startsWith(prefix) && stem.length - prefix.length >= 3) {
            stem = stem.substring(prefix.length);
            expanded.add(_normalize(stem));
            stripped = true;
            break;
          }
        }
      }
    }
    return ' ${expanded.toSet().join(' ')} ';
  }

  static String _normalize(String value) {
    var text = value
        .toLowerCase()
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll(RegExp(r'[\u0300-\u036f]'), '')
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    const aliases = <String, String>{
      'كابتشنو': 'كابتشينو',
      'كابوتشينو': 'كابتشينو',
      'كبشينو': 'كابتشينو',
      'كبتشينو': 'كابتشينو',
      'كباتشينو': 'كابتشينو',
      'capuccino': 'cappuccino',
      'cappucino': 'cappuccino',
      'cappuchino': 'cappuccino',
      'cofee': 'coffee',
      'coffe': 'coffee',
      'expresso': 'espresso',
      'اسبرسو': 'اسبريسو',
      'لاتي': 'لاتيه',
      'عاوز': 'اريد',
      'عايز': 'اريد',
      'ابغى': 'اريد',
      'ابي': 'اريد',
      'وش': 'ما',
      'ايش': 'ما',
      'ايه': 'ما',
      'ايس': 'مثلج',
      'ايسد': 'مثلج',
      'كوفى': 'قهوه',
      'رشحلي': 'رشح',
      'ترشحلي': 'رشح',
      'اقترحلي': 'اقترح',
      'تنصحني': 'انصح',
      'نصحني': 'انصح',
      'تصحصحني': 'تصحصح',
      'صحصحني': 'تصحصح',
      'diffrence': 'difference',
      'differnce': 'difference',
      'comapre': 'compare',
      'diff': 'difference',
      'btwn': 'between',
      'capuchino': 'cappuccino',
      'expressoo': 'espresso',
      'lattee': 'latte',
      'اقارن': 'قارن',
      'سعره': 'سعر',
      'سعرها': 'سعر',
      'سعرهم': 'سعر',
      'اسعار': 'سعر',
      'اسعارها': 'سعر',
      'اكتر': 'اكثر',
      'مبعات': 'مبيعات',
      'مبيات': 'مبيعات',
      'مبيعاات': 'مبيعات',
      'ايردات': 'ايرادات',
      'ايرادت': 'ايرادات',
      'ordres': 'orders',
      'ordes': 'orders',
      'reveune': 'revenue',
      'revanue': 'revenue',
      'avrage': 'average',
      'salez': 'sales',
    };
    text = text.split(' ').map((word) => aliases[word] ?? word).join(' ');
    return text;
  }

  static const Map<String, List<String>> _entityTerms = {
    'latte': ['لاتيه', 'لاتي', 'latte', 'caffe latte'],
    'cappuccino': ['كابتشينو', 'كبشينو', 'cappuccino', 'capuccino'],
    'mocha': ['موكا', 'موكه', 'mocha'],
    'espresso': ['اسبريسو', 'espresso'],
    'cold_brew': ['كولد برو', 'cold brew'],
    'iced_coffee': ['ايس كوفي', 'قهوه مثلجه', 'قهوه بارده', 'iced coffee'],
    'v60': ['v60', 'في ستين', 'بور اوفر', 'pour over', 'pourover'],
    'aeropress': ['ايروبرس', 'ايرو برس', 'aeropress'],
    'french_press': ['فرنش برس', 'فرنش بريس', 'french press'],
    'arabica': ['ارابيكا', 'ارابيكا', 'arabica'],
    'robusta': ['روبوستا', 'robusta'],
    'decaf': ['منزوع الكافيين', 'ديكاف', 'decaf', 'decaffeinated'],
    'americano': ['امريكانو', 'americano'],
    'flat_white': ['فلات وايت', 'flat white'],
    'cortado': ['كورتادو', 'cortado'],
    'macchiato': ['ماكياتو', 'مكياتو', 'macchiato'],
  };

  String _compose(String body) => body.trim();

  String? _firstName(String? fullName) {
    final cleaned = fullName?.replaceAll(RegExp(r'[\r\n<>]'), ' ').trim();
    if (cleaned == null || cleaned.isEmpty) return null;
    final first = cleaned.split(RegExp(r'\s+')).first;
    if (first.length > 30) return null;
    return first;
  }
}
