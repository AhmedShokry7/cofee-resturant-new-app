import 'package:new_coffee/features/assistant/data/assistant_engine.dart';
import 'package:new_coffee/features/assistant/data/assistant_intents.dart';
import 'package:new_coffee/features/assistant/data/assistant_language.dart';
import 'package:new_coffee/features/assistant/data/assistant_memory.dart';
import 'package:new_coffee/features/assistant/data/assistant_order.dart';
import 'package:new_coffee/features/assistant/data/assistant_phrases.dart';
import 'package:new_coffee/features/assistant/data/assistant_snapshot.dart';

/// Who is allowed to answer one sentence.
enum AnswerOwner {
  /// Live app data answers it: the menu, the cart, this customer's own orders.
  liveData,

  /// A fact the shop wrote down answers it: the hours, delivery, payment, what
  /// a drink is made of.
  shopKnowledge,

  /// Nothing local is sure enough. The language model reads the sentence, and
  /// the offline engine stays as the fallback for when it cannot be reached.
  languageModel,
}

/// What the sentence is about, matched from its own words.
///
/// The keyword scorer the offline engine answers with picked the wrong subject
/// for most of the thirty measured customer sentences: "الطلب اللي عملته امبارح
/// وصل ولا لاء" (order status) scored a drink suggestion, "الموكا بكام" (a
/// price) scored the coupon page, "ممكن طلبين لاتيه واحد سادة والتاني نيس" (an
/// order) scored order status and was answered with "لسه معندكش طلبات". The
/// subject cannot come from the winning intent, then: it is matched against the
/// sentence, and the intent stays as one signal among them.
enum SentenceSubject {
  /// Something only the app knows: this customer's order or its delivery.
  ownOrder,

  /// The basket on the screen.
  cart,

  /// An ingredient nothing on the menu has. The shop knows its own recipe
  /// exactly, and a guessed answer to an allergy question is not a wording
  /// problem.
  ingredient,

  /// A product that is on the menu.
  menuItem,

  /// A fact the shop wrote down: the hours, delivery, payment, refunds.
  shopFact,

  /// A request the menu can be searched for.
  recommendation,

  /// Nothing above matched: the customer asked about something the app holds no
  /// record of, or in words it cannot place.
  none,
}

/// Reads a sentence before anyone answers it.
///
/// The offline engine answers by scoring keywords against an intent table, and
/// it always found *some* intent, so it always answered with confidence:
/// measured on thirty real customer sentences, twenty-eight were answered
/// locally and two reached the language model — which is how "عايز اشترك في
/// الاشتراك الشهري" and "ايه احسن حاجة للاولاد الصغار؟" both came back as the
/// default three-drink list. This layer owns the one question the engine cannot
/// answer about itself: does the app actually hold the data this sentence asks
/// about?
class AssistantUnderstanding {
  const AssistantUnderstanding({
    required this.intent,
    required this.subject,
    required this.owner,
    required this.reason,
    required this.knowledgeScore,
    required this.mentionsMenuItem,
    required this.safeToLearn,
    this.deviceIntent,
  });

  /// Intents answered by the shape of the conversation, not by data.
  static const Set<AssistantIntent> discourse = {
    AssistantIntent.greeting,
    AssistantIntent.thanks,
    AssistantIntent.farewell,
    AssistantIntent.affirm,
    AssistantIntent.deny,
    AssistantIntent.selectOrdinal,
    AssistantIntent.memory,
  };

  /// Words that point at this customer's own order.
  ///
  /// Whole-word matching keeps "توصل" (does delivery reach) out of "وصل" (did
  /// mine arrive), so the delivery-zone question stays a shop fact and only a
  /// question about an order that exists becomes live data.
  static const List<String> ownOrderWords = [
    'وصل',
    'اتأخر',
    'تأخر',
    'طلبي',
    'طلبته',
    'مشيت',
    'اتجهز',
    'my order',
    'delivered',
    'arrived',
    'tracking',
  ];

  /// Words that ask whether something is allowed, or when and where. They turn
  /// a verb like "اطلب" into a question about the rules instead of an order.
  static const List<String> interrogativeWords = [
    'مقدر',
    'اقدر',
    'ينفع',
    'يمدي',
    'هل',
    'ازاي',
    'ازاى',
    'اين',
    'فين',
    'امتى',
    'متى',
    'كيف',
    'ليه',
    'why',
    'when',
    'where',
    'how',
    'can',
  ];

  /// Words that ask the assistant to search the menu for the customer.
  static const List<String> recommendationWords = [
    'اقترح',
    'اقتراح',
    'رشح',
    'ترشيح',
    'نصح',
    'اجرب',
    'suggest',
    'recommend',
  ];

  /// A limit about the customer's own body or household: a child, a pregnancy,
  /// diabetes, a caffeine intolerance.
  ///
  /// "عايز حاجة تفتح المخ" and "عايز احسن قهوه" both ask the menu to be
  /// searched, but only one of them can be answered by the menu. Sorting the
  /// shop's drinks says nothing about whether a three-year-old should have
  /// espresso, and the default three-drink list was exactly what came back.
  static const List<String> customerLimits = [
    'اولاد',
    'اطفال',
    'طفل',
    'عيال',
    'صغار',
    'رضيع',
    'حامل',
    'كافيين',
    'كافاين',
    'منشط',
    'سكري',
    'ضغط',
    'قلب',
    'حساسية',
    'حساس',
    'دايت',
    'ديت',
    'كيتو',
    'رجيم',
    'kids',
    'child',
    'pregnant',
    'allergic',
  ];

  /// Programmes the assistant is given no data for.
  ///
  /// These are the two domains the customer asks about most and the assistant
  /// cannot answer in any owner's voice: it holds no subscription record and no
  /// loyalty balance, and the only destinations it can open are the coupon page,
  /// the orders, the checkout and its own memory. The sentence still reaches the
  /// language model, which can at least say where in the app to look.
  static const List<String> outOfScopeWords = [
    'اشتراك',
    'اشتراكات',
    'باقة',
    'نقاط',
    'نقاطي',
    'نقاطك',
    'نقطتي',
    'رصيد',
    'subscription',
    'points',
  ];

  /// Words about the app itself rather than what it sells. The screen is not
  /// something the menu can be searched for, and the assistant has no idea what
  /// the customer is looking at.
  ///
  /// Only forms of three letters or more: whole-word matching ignores a
  /// two-letter entry, and "زر" is how the customer says it. The phrase list
  /// below carries that case.
  static const List<String> aboutTheAppWords = [
    'الزر',
    'ازرار',
    'شاشة',
    'الشاشة',
    'تطبيق',
    'التطبيق',
    'اضغط',
    'button',
    'screen',
    'app',
  ];

  /// The customer says they cannot find or cannot do something. This is a
  /// complaint about the screen in front of them, and the answer is never a
  /// drink list.
  static const List<String> stuckOnAppPhrases = [
    'مش لاقي',
    'ما لقيت',
    'مش قادر',
    'مش شايف',
    'مش ظاهر',
    'can\'t find',
    'cannot find',
  ];

  final AssistantIntent intent;
  final SentenceSubject subject;
  final AnswerOwner owner;

  /// The template the offline engine must answer with, or null to keep the one
  /// its keyword scorer picked.
  ///
  /// Routing the sentence was only half the complaint: the scorer picks the
  /// template, and it reads a tie as a drink suggestion. Measured on the same
  /// thirty sentences, "الطلب اللي عملته امبارح وصل ولا لاء" scored
  /// suggestDrink and orderStatus at the same strength and was answered with
  /// "دي ترشيحاتي ليك دلوقتي: Cappuccino, Iced Latte, Cheesecake", and
  /// "ممكن طلبين لاتيه واحد سادة والتاني نيس" — two drinks, spelled out — was
  /// answered with "لسه معندكش طلبات". The subject is read from the sentence's
  /// own words, so where the subject is something the app holds, the subject
  /// chooses the answer.
  final AssistantIntent? deviceIntent;

  /// Why this owner won — the string the tests and the escalated-question log
  /// read, so a wrong decision traces back to one rule.
  final String reason;
  final double knowledgeScore;
  final bool mentionsMenuItem;

  /// Whether the answer may join the shared cache every other customer reads.
  ///
  /// The shape of the question decides, not who answered it: an answer about a
  /// price, an order or a payment is true for one customer and stale or wrong
  /// for the next, and none of them belong in a cache keyed by question text.
  /// Everything the language model is asked is a question the app could not
  /// ground, so it is exactly what the cache is for.
  final bool safeToLearn;

  bool get wantsLanguageModel => owner == AnswerOwner.languageModel;

  static AssistantUnderstanding analyse(
    String query, {
    required AssistantSnapshot snapshot,
    required AssistantMemory memory,
    bool? arabic,
  }) => AssistantSnapshot.run(
    snapshot,
    () => _analyse(
      query,
      memory: memory,
      arabic: arabic ?? AssistantEngine.arabicReplyFor(query),
    ),
  );

  static AssistantUnderstanding _analyse(
    String query, {
    required AssistantMemory memory,
    required bool arabic,
  }) {
    final normalized = normalizeText(query);
    final ranked = scoreIntents(normalized, tokenize(query)).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final intent = ranked.isEmpty || ranked.first.value == 0
        ? AssistantIntent.unknown
        : ranked.first.key;

    final mentioned = AssistantEngine.mentionedProducts(query);
    final namesMenuItem = mentioned.wanted.isNotEmpty;
    final fact = AssistantEngine.factMatch(query, memory, arabic: arabic);
    // The menu is the only authority for "what should I have", and the app is
    // the only place that can put the drinks on screen to tap. A sentence is
    // still a menu question only while it is really about the menu: a limit
    // about the customer's body, a question about the app's own screen, a rule
    // question and a programme the assistant has no record of are each answered
    // by something else.
    final asksAboutMenu =
        intent == AssistantIntent.suggestDrink &&
        !mentionsWord(query, customerLimits) &&
        !mentionsWord(query, interrogativeWords) &&
        !mentionsWord(query, aboutTheAppWords) &&
        !mentionsWord(query, outOfScopeWords) &&
        !mentionsFragment(query, stuckOnAppPhrases);
    final subject = _subjectOf(
      query,
      intent: intent,
      namesMenuItem: namesMenuItem,
      menuLacksIngredient: AssistantEngine.statesMissingIngredient(query),
      mentionsCategory: mentioned.categories.isNotEmpty,
      matchesFact: fact != null,
      asksAboutMenu: asksAboutMenu,
    );

    final deviceIntent = switch (subject) {
      SentenceSubject.ownOrder => AssistantIntent.orderStatus,
      SentenceSubject.menuItem =>
        AssistantEngine.asksPrice(query) || !namesAnOrder(query)
            ? null
            : AssistantIntent.placeOrder,
      SentenceSubject.recommendation => AssistantIntent.suggestDrink,
      _ => null,
    };

    AssistantUnderstanding decide(AnswerOwner owner, String reason) {
      return AssistantUnderstanding(
        intent: intent,
        subject: subject,
        owner: owner,
        reason: reason,
        knowledgeScore: fact?.score ?? 0,
        mentionsMenuItem: namesMenuItem,
        deviceIntent: deviceIntent,
        safeToLearn:
            subject != SentenceSubject.ownOrder &&
            !AssistantEngine.isPerishableQuestion(query),
      );
    }

    if (normalized.isEmpty) {
      return decide(AnswerOwner.languageModel, 'empty');
    }
    // Small talk is answered in the app's own voice; the model would only
    // improvise a greeting.
    if (discourse.contains(intent)) {
      return decide(AnswerOwner.liveData, 'discourse:${intent.name}');
    }
    // Live data first: the model can only guess at this customer's order,
    // their cart, or what is on the menu right now.
    if (subject == SentenceSubject.ownOrder) {
      return decide(AnswerOwner.liveData, 'own-order');
    }
    if (subject == SentenceSubject.cart) {
      return decide(AnswerOwner.liveData, 'cart-state');
    }
    // For a customer who says they are allergic, a fluent guess is worse than
    // no answer at all: only the shop's own recipe may reply.
    if (subject == SentenceSubject.ingredient) {
      return decide(AnswerOwner.liveData, 'ingredient-fact');
    }
    if (subject == SentenceSubject.menuItem) {
      return decide(AnswerOwner.liveData, 'menu-item');
    }
    if (subject == SentenceSubject.shopFact) {
      return decide(AnswerOwner.shopKnowledge, 'shop-fact');
    }
    // Searching the menu is the app's job, and its answer carries the products
    // to tap. An order request is the same case through the order flow — unless
    // the sentence is a question about the rules ("مقدر اغير عنوان الطلب؟").
    if (subject == SentenceSubject.recommendation) {
      return decide(AnswerOwner.liveData, 'recommendation');
    }
    if (intent == AssistantIntent.placeOrder &&
        !mentionsWord(query, interrogativeWords)) {
      return decide(AnswerOwner.liveData, 'order-flow');
    }
    // The offers on screen are live data, whatever the sentence scored.
    if (intent == AssistantIntent.showCoupons) {
      return decide(AnswerOwner.liveData, 'offers');
    }
    // A complaint about the prices is about this shop's prices, and the engine
    // answers it with the cheapest things on the real menu. The model would
    // apologise about numbers it has never seen.
    if (intent == AssistantIntent.complaint) {
      return decide(AnswerOwner.liveData, 'complaint');
    }
    return decide(AnswerOwner.languageModel, 'no-grounding:${intent.name}');
  }

  static SentenceSubject _subjectOf(
    String query, {
    required AssistantIntent intent,
    required bool namesMenuItem,
    required bool menuLacksIngredient,
    required bool mentionsCategory,
    required bool matchesFact,
    required bool asksAboutMenu,
  }) {
    if (mentionsWord(query, ownOrderWords)) return SentenceSubject.ownOrder;
    if (mentionsWord(query, AssistantPhrases.cartWords)) {
      return SentenceSubject.cart;
    }
    if (menuLacksIngredient) return SentenceSubject.ingredient;
    if (namesMenuItem) return SentenceSubject.menuItem;
    // A search and a fact question share their words ("حاجة باردة" matches the
    // iced-coffee article but asks for a pick), so the ask is checked first.
    if (
        mentionsWord(query, recommendationWords) ||
        mentionsCategory ||
        asksAboutMenu) {
      return SentenceSubject.recommendation;
    }
    if (matchesFact && intent != AssistantIntent.suggestDrink) {
      return SentenceSubject.shopFact;
    }
    return SentenceSubject.none;
  }

  /// True when the customer asked the shop to make an order, not when they only
  /// named a drink. "عايز لاتيه من غير سكر" is an order; "اللاتيه فيه مكسرات؟"
  /// names the same drink but asks about it, and answering it as an order would
  /// put an allergen in the basket.
  static bool namesAnOrder(String query) {
    // The order parser is the strictest reader the app has: it returns items
    // only for whole-word menu names carrying a quantity or a variant, which is
    // exactly the shape of "طلبين لاتيه واحد سادة والتاني نيس".
    if (parseOrderMessage(query).items.isEmpty) return false;
    // "فيه سكر" / "كام سعره" ask what the drink is made of or what it costs.
    if (mentionsFragment(query, const ['فيه', 'فيها', 'بيحتوي', 'سعر', 'كام'])) {
      return false;
    }
    return !mentionsWord(query, interrogativeWords);
  }
}
