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
    'هذي ترشيحاتي لك الحين: {names}.',
    'أحسن ترشيحات لك: {names}.',
    'ترشيحات اليوم لك: {names}.',
    'هذي على ذوقي: {names}.',
    'لو تسألني أقول لك جرب {names}.',
  ];

  static const List<String> suggestPrefLeadsAr = [
    'هذي ترشيحاتي لك: {names}.',
    'أحسن ترشيحات لك: {names}.',
    'زي ذوقك بالضبط: {names}.',
  ];

  static const List<String> usualFoundAr = [
    'المعتاد حقك هو {product}.',
    '{product} — انت عارف وش تحب.',
    '{product} زي كل مرة — اختيار موفق!',
  ];

  static const String usualUnknownLeadAr =
      'ما أعرف المعتاد حقك بعد — ما فيه طلب متكرر يعتبر عادة. ';

  static const List<String> affirmSuggestAr = [
    'تمام! بالهنا والشفاء.',
    'اختيار حلو.',
    'كفو! بالهنا والشفاء.',
    'حلو! استمتع فيه.',
  ];

  static const List<String> affirmGeneralAr = [
    'تمام!',
    'معك!',
    'كفو، يالله!',
    'ماشي، أمرّك!',
  ];

  static const List<String> denySuggestAr = [
    'عادي — قول لي مزاجك وأختار من جديد: قوي، حلو، بارد، ولا رخيص؟',
    'عادي تمامًا! أعطني اتجاه — قوي، حلو، بارد، ولا رخيص — وأجيب لك غيره.',
    'ماشي، نشيله — حار ولا بارد؟ حلو ولا قوي؟ وأجيب لك أحسن منه.',
    'ولا يهمك يا غالي — قول لي مزاجك وأنا أضبطه.',
  ];

  static const List<String> denyGeneralAr = [
    'ولا يهمك!',
    'عادي تمامًا!',
    'تمام، من غيره!',
    'ولا يهمك يا غالي — تحت أمرك في أي وقت.',
  ];

  static const List<String> identityAr = [
    'أنا مساعد القهوة حقك هنا في التطبيق — أرشح لك مشروبات، أتابع طلباتك، '
        'وأبحث لك عن العروض.',
    'اعتبرني الباريستا المساعد حقك: ترشيحات مشروبات، متابعة طلبات وعروض، '
        'كل هذا في الشات.',
    'أنا مساعدك هنا في التطبيق: أرشح لك على مزاجك، أتابع طلبك، وأجيب لك '
        'أحسن عرض.',
  ];

  static const List<String> farewellAr = [
    'أشوفك قريب — استمتع بقهوتك!',
    'سلام الحين! هكون هنا أول ما تحتاج قهوة.',
    'مع السلامة! لنا لقاء قريب.',
    'الله يحفظك — ألقاك قريب!',
  ];

  static const List<String> fallbackAr = [
    'ما فهمتك زين. أقدر أرشح لك مشروبات، أتابع طلباتك، أو أشوف لك العروض — جرب واحدة من هذي.',
    'همم، ما فهمت قصدك. قول لي وش مزاجك اليوم، أو اسألني عن طلبك.',
    'مو متأكد إني فاهم. أنا مميز في ترشيح المشروبات ومتابعة الطلبات وتدوير العروض — قل لي واحدة من هذي.',
    'أبغى أساعدك بس أحتاج توضيح. نتكلم عن مشروبات، طلبات، ولا عروض؟',
    'مو واصل مزاجك زين — تبغاني أرشح لك شي حار ولا بارد، أتابع طلبك، ولا أشوف لك العروض؟',
    'قل لي كلمة وحدة بس: مشروب، طلب، ولا عرض؟ وأنا أظبطها لك على طول.',
  ];

  static const List<String> tasteQuestionsAr = [
    ' تبغاها حارة ولا باردة — قوية ولا حلوة؟',
    ' حارة ولا باردة اليوم؟ قوية ولا حلوة؟',
    ' قل لي حارة ولا باردة، قوية ولا حلوة، وأضبطها لك بعد كذا.',
    ' باردة ولا حارة؟ حلوة ولا قوية؟ قل لي وأختار لك الأنسب.',
    ' حار ولا مثلج؟ وتحب حلاوة ولا قوة؟ قل لي وأنا أضبطها.',
  ];
}
