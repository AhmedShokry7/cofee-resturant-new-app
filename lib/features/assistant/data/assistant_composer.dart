/// Local response composer: LLM-style varied replies without a server.
///
/// Instead of one hard-coded sentence per case, every situation has a pool
/// of templates with `{slots}`. The template rotates with the conversation
/// ([seed], usually the chat count) so the bot never sounds like a broken
/// record, while staying fully deterministic for tests (fresh chat always
/// picks the first template).
class AssistantComposer {
  const AssistantComposer._();

  static String pick(List<String> pool, int seed) => pool[seed % pool.length];

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
    'Your usual is {product}.',
    '{product} — you know what you like.',
    '{product} it is, your all-time favorite.',
  ];

  static const String usualUnknownLead =
      "I don't know your usual yet — nothing you ordered repeats often enough "
      'to be called a habit. ';

  static const List<String> affirmSuggest = [
    'Perfect — enjoy it.',
    'Great pick.',
  ];

  static const List<String> affirmGeneral = ['Got it!', 'On it!'];

  static const List<String> denySuggest = [
    'No problem at all — tell me the mood and I will re-pick: strong, sweet, cold, or cheap?',
    'All good! Give me a direction — strong, sweet, cold, or cheap — and I will find another one.',
  ];

  static const List<String> denyGeneral = ['No worries!', 'All good!'];

  static const List<String> identity = [
    'I am your coffee assistant here in the app — I suggest drinks, track '
        'orders and check coupons.',
    'Think of me as your personal barista helper: drink ideas, order tracking '
        'and offers, all in one chat.',
  ];

  static const List<String> farewell = [
    'See you soon — enjoy your coffee!',
    'Bye for now! I will be right here when the craving hits.',
  ];

  static const List<String> fallback = [
    "I couldn't quite catch that. I can suggest drinks, track your orders, or check coupons — try one of those.",
    "Hmm, I didn't get that. Tell me what you're in the mood for, or ask about your order.",
    'Not sure I follow. I shine at drink suggestions, order tracking and coupon hunting — tell me which one you want.',
    'I want to help, but I need a little more. Are we talking drinks, orders, or offers?',
  ];

  // ==================== Egyptian Arabic pools ====================

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
    'المعتاد بتاعك هو {product}.',
    '{product} — انت عارف بتحب إيه.',
    '{product} زي كل مرة — اختيار موفق!',
  ];

  static const String usualUnknownLeadAr =
      'لسه معرفش المعتاد بتاعك — مفيش طلب متكرر يتسما عادة. ';

  static const List<String> affirmSuggestAr = ['تمام! بالهنا.', 'اختيار حلو.'];

  static const List<String> affirmGeneralAr = ['تمام!', 'معاك!'];

  static const List<String> denySuggestAr = [
    'ولا يهمك — قولي المود وأنا أختار من جديد: قوي، مسكر، ساقع، ولا رخيص؟',
    'عادي! اديني اتجاه — قوي، مسكر، ساقع، ولا رخيص — وهلاقيلك غيره.',
  ];

  static const List<String> denyGeneralAr = ['ولا يهمك!', 'عادي خالص!'];

  static const List<String> identityAr = [
    'أنا مساعد القهوة بتاعك هنا في التطبيق — برشح مشروبات، بتابع الطلبات، '
        'وبدور على العروض.',
    'اعتبرني الباريستا المساعد بتاعك: ترشيحات مشروبات، متابعة طلبات وعروض، '
        'كل ده في الشات.',
  ];

  static const List<String> farewellAr = [
    'أشوفك قريب — استمتع بقهوتك!',
    'سلام دلوقتي! هكون هنا أول ما نفسك تهفك على قهوة.',
  ];

  static const List<String> fallbackAr = [
    'مش قادر ألقطها كده. أقدر أرشحلك مشروبات، أتابع طلباتك، أو أشوفلك العروض — جرب واحدة من دول.',
    'همم، مفهمتش قصدك. قولي نفسك في إيه، أو اسألني عن طلبك.',
    'مش متأكد إني فاهم. أنا شاطر في ترشيح المشروبات ومتابعة الطلبات وتدوير العروض — قولي واحدة من دول.',
    'عايز أساعدك بس محتاج توضيح. بنتكلم عن مشروبات، طلبات، ولا عروض؟',
  ];

  static const List<String> tasteQuestionsAr = [
    ' عايزه سخن ولا ساقع — قوي ولا مسكر؟',
    ' سخن ولا ساقع النهاردة؟ قوي ولا مسكر؟',
    ' قولي سخن ولا ساقع، قوي ولا مسكر، وهظبطها ليك بعد كده.',
  ];
}
