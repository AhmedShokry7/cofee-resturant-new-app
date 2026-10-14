/// Local response composer: LLM-style varied replies without a server.
///
/// Instead of one hard-coded sentence per case, every situation has a pool
/// of templates with `{slots}`. The template rotates with the conversation
/// ([seed], usually the chat count) so the bot never sounds like a broken
/// record, while staying fully deterministic for tests (fresh chat always
/// picks the first template).
class AssistantComposer {
  const AssistantComposer._();

  static String pick(List<String> pool, int seed) =>
      pool[seed % pool.length];

  static String fill(String template, Map<String, String> slots) {
    var result = template;
    slots.forEach((key, value) {
      result = result.replaceAll('{$key}', value);
    });
    return result;
  }

  // Every lead keeps the words "top picks" so suggestions stay
  // recognizable no matter which variation is picked.
  static const List<String> suggestLeads = [
    'Here are my top picks for you right now: {names}.',
    'My top picks for you: {names}.',
    'Fresh top picks for you today: {names}.',
  ];

  static const List<String> suggestPrefLeads = [
    'here are my top picks for you: {names}.',
    'my top picks for you: {names}.',
    'fresh top picks for you: {names}.',
  ];

  static String suggestText({
    required String names,
    String? preferenceCategory,
    required int seed,
    String leadPrefix = '',
    bool arabic = false,
  }) {
    if (arabic) {
      final body = preferenceCategory == null
          ? fill(pick(suggestLeadsAr, seed), {'names': names})
          : 'بما إنك بتحب $preferenceCategory، ${fill(pick(suggestPrefLeadsAr, seed), {'names': names})}';
      return '$leadPrefix$body';
    }
    final preference = preferenceCategory == null
        ? null
        : 'you usually enjoy $preferenceCategory';
    final body = preference == null
        ? fill(pick(suggestLeads, seed), {'names': names})
        : 'Since $preference, ${fill(pick(suggestPrefLeads, seed), {'names': names})}';
    return '$leadPrefix$body';
  }

  static const List<String> usualFound = [
    'Your usual is {product} — excellent choice! Want it again today?',
    'Back to {product}? You clearly know what you love. Enjoy!',
    '{product} it is — your all-time favorite. Shall I keep it coming?',
  ];

  static const String usualUnknownLead =
      "I don't know your usual yet — tell me what you love and I'll remember it. ";

  static const List<String> affirmSuggest = [
    'Perfect! Tell me how to fine-tune it — stronger, sweeter, colder, or cheaper?',
    'Love it! Want me to adjust — maybe stronger or sweeter?',
  ];

  static const List<String> affirmGeneral = [
    'Got it! What next — a drink idea, your order status, or coupons?',
    'On it! Anything else — suggestions, orders, or offers?',
  ];

  static const List<String> denySuggest = [
    'No problem at all — tell me the mood and I will re-pick: strong, sweet, cold, or cheap?',
    'All good! Give me a direction — strong, sweet, cold, or cheap — and I will find another one.',
  ];

  static const List<String> denyGeneral = [
    'No worries! I am here whenever you need a suggestion or an order update.',
    'Totally fine! Just say the word when you want a drink idea or your order status.',
  ];

  static const List<String> identity = [
    'I am your coffee assistant here in the app — I suggest drinks, track orders and hunt coupons. How can I help?',
    'Think of me as your personal barista helper: drink ideas, order tracking and offers, all in one chat.',
  ];

  static const List<String> farewell = [
    'See you soon — enjoy your coffee!',
    'Bye for now! I will be right here when the craving hits.',
  ];

  static const List<String> fallback = [
    "I couldn't quite catch that. I can suggest drinks, track your orders, or check coupons — try one of those.",
    "Hmm, I didn't get that. Tell me what you're in the mood for, or ask about your order.",
    'Not sure I follow. I shine at drink suggestions, order tracking and coupon hunting — pick one below.',
    'I want to help, but I need a little more. Are we talking drinks, orders, or offers?',
  ];

  // ==================== Egyptian Arabic pools ====================

  static const List<String> quickRepliesAr = [
    'رشحلي مشروب',
    'فين الاوردر؟',
    'في عروض؟',
  ];

  static const List<String> suggestRepliesAr = [
    'حاجة أقوى',
    'حاجة مسكرة',
    'في عروض؟',
  ];

  static const List<String> suggestLeadsAr = [
    'دي ترشيحاتي ليك دلوقتي: {names}.',
    'أحلى ترشيحات ليك: {names}.',
    'ترشيحات النهاردة ليك: {names}.',
  ];

  static const List<String> suggestPrefLeadsAr = [
    'دي ترشيحاتي ليك: {names}.',
    'أحلى ترشيحات ليك: {names}.',
  ];

  static const List<String> usualFoundAr = [
    'المعتاد بتاعك هو {product} — ذوق عالي! تحبه تاني النهاردة؟',
    'نرجع لـ {product}؟ انت عارف بتحب إيه. بالهنا!',
    '{product} زي كل مرة — اختيار موفق!',
  ];

  static const String usualUnknownLeadAr =
      'لسه معرفش المعتاد بتاعك — قولي بتحب إيه وأنا هفتكره. ';

  static const List<String> affirmSuggestAr = [
    'تمام! قولي أظبطها إزاي — أقوى، مسكرة، ساقعة، ولا أرخص؟',
    'حلو! تحب أعدل — أقوى ولا مسكرة؟',
  ];

  static const List<String> affirmGeneralAr = [
    'تمام! تحب إيه تاني — ترشيح مشروب، حالة طلبك، ولا العروض؟',
    'معاك! أي حاجة تانية — ترشيحات، طلبات، ولا عروض؟',
  ];

  static const List<String> denySuggestAr = [
    'ولا يهمك — قولي المود وأنا أختار من جديد: قوي، مسكر، ساقع، ولا رخيص؟',
    'عادي! اديني اتجاه — قوي، مسكر، ساقع، ولا رخيص — وهلاقيلك غيره.',
  ];

  static const List<String> denyGeneralAr = [
    'ولا يهمك! أنا هنا لو احتجت ترشيح أو متابعة طلب.',
    'عادي خالص! قولي بس لو عايز ترشيح مشروب أو حالة طلبك.',
  ];

  static const List<String> identityAr = [
    'أنا مساعد القهوة بتاعك هنا في التطبيق — برشح مشروبات، بتابع الطلبات، وبدور على العروض. أساعدك إزاي؟',
    'اعتبرني الباريستا المساعد بتاعك: ترشيحات مشروبات، متابعة طلبات وعروض، كل ده في الشات.',
  ];

  static const List<String> farewellAr = [
    'أشوفك قريب — استمتع بقهوتك!',
    'سلام دلوقتي! هكون هنا أول ما نفسك تهفك على قهوة.',
  ];

  static const List<String> fallbackAr = [
    'مش قادر ألقطها كده. أقدر أرشحلك مشروبات، أتابع طلباتك، أو أشوفلك العروض — جرب واحدة من دول.',
    'همم، مفهمتش قصدك. قولي نفسك في إيه، أو اسألني عن طلبك.',
    'مش متأكد إني فاهم. أنا شاطر في ترشيح المشروبات ومتابعة الطلبات وتدوير العروض — اختار واحدة من تحت.',
    'عايز أساعدك بس محتاج توضيح. بنتكلم عن مشروبات، طلبات، ولا عروض؟',
  ];

  static const List<String> tasteQuestionsAr = [
    ' عايزه سخن ولا ساقع — قوي ولا مسكر؟',
    ' سخن ولا ساقع النهاردة؟ قوي ولا مسكر؟',
    ' قولي سخن ولا ساقع، قوي ولا مسكر، وهظبطها ليك بعد كده.',
  ];
}
