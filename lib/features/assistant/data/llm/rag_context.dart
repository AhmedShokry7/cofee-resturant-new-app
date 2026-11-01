import 'package:new_coffee/features/assistant/data/assistant_catalog.dart';
import 'package:new_coffee/features/assistant/data/assistant_engine.dart';
import 'package:new_coffee/features/assistant/data/assistant_language.dart';
import 'package:new_coffee/features/assistant/data/assistant_memory.dart';
import 'package:new_coffee/features/assistant/data/assistant_snapshot.dart';
import 'package:new_coffee/features/assistant/data/knowledge/coffee_knowledge.dart';
import 'package:new_coffee/features/assistant/data/knowledge/faq_knowledge.dart';
import 'package:new_coffee/features/assistant/data/model/chat_message.dart';

String buildSystemPrompt({required AssistantMemory memory}) {
  final buffer = StringBuffer(
    'You are the friendly in-app assistant of a coffee shop app. '
    'Understand natural, colloquial Arabic (Iraqi/Gulf, Saudi, Egyptian, Levantine), '
    'English, and mixed Arabic/English, including typos and informal wording. '
    'Answer in the customer language, in the same dialect they used. '
    'Talk like a warm barista in a chat: answer the question directly, then offer '
    'one natural next step. Never list more than two options. '
    'Keep the reply to two or three short sentences. '
    'Never use markdown: no tables, no bullet lists, no numbered lists, no '
    'headings, no bold, no emoji. Write plain sentences, the way a person types '
    'in a chat. '
    'Use only provided local knowledge and live app data; never invent products, prices, '
    'ingredients, allergens, stock, hours, or fees. '
    'When the customer asks about an ingredient or an allergen, answer only from the '
    'ingredients listed in the menu; if it is not listed, say the shop does not have it. '
    'Write every amount with Latin digits and the SAR currency, exactly as the menu '
    'lists it; never name another currency. '
    'Name each product once. Never repeat a product in the same answer. '
    'If the local knowledge answers the question, use its wording. '
    'Ask one short clarification question when the request is genuinely ambiguous. '
    'For follow-ups, use recent conversation context. ',
  );
  final top = memory.topCategory();
  if (top != null) buffer.write('The user enjoys $top. ');
  if (memory.replyArabic) {
    buffer.write('The user prefers Egyptian Arabic. ');
  }
  if (memory.totalChats > 0) {
    buffer.write('They have chatted ${memory.totalChats} times before. ');
  }
  // The examples matter more than the rules: they show the length, the tone
  // and the grounding far better than a paragraph of instructions does. They are
  // plain text on purpose — a single Markdown table in an example is enough to
  // make the model answer every comparison with a table.
  buffer.write(
    '''
Examples of the right answer, written as plain chat messages:

Customer: مرحبا
Assistant: أهلاً بيك! أنا مساعد القهوة، أقدر أرشحلك مشروب على مزاجك أو أتابع طلبك لو طلبت. إيه اللي يحلو النهاردة؟

Customer: كام سعر اللاتيه؟
Assistant: سعر اللاتيه 35.00 SAR. تحبه ساخن ولا بارد؟

Customer: امتى بتقفلوا؟
Assistant: بنفتح كل يوم من 7:00 الصبح لحد 11:00 بالليل. تحب أجهزلك طلب قبل ما نقفل؟

Customer: ايه احلى مشروب؟
Assistant: أحلى مشروب عندي الموكا بـ 45.00 SAR، إسبريسو مع شوكولاتة ولبن. تحب أضيفه لك؟

Customer: عندكم حاجه بالمكسرات؟
Assistant: لا، مفيش حاجة عندنا فيها مكسرات. بس التشيز كيك عندنا وآمن من المكسرات، تحبه؟

Customer: ايه الفرق بين اللاتيه والكابتشينو؟
Assistant: اللاتيه لبن أكتر ورغوة خفيفة، والكابتشينو رغوة أكتر وأقوى في الطعم. اللاتيه أنعم لو بتحب القهوة سهلة.''',
  );
  return buffer.toString();
}

List<Map<String, String>> buildHistory(
  List<ChatMessage> messages, {
  int maxTurns = 4,
}) {
  final meaningful = messages
      .where((message) => message.text.trim().isNotEmpty)
      .toList();
  final tail = meaningful.length > maxTurns * 2
      ? meaningful.sublist(meaningful.length - maxTurns * 2)
      : meaningful;
  return [
    for (final message in tail)
      {
        'role': message.role == MessageRole.user ? 'user' : 'assistant',
        'content': message.text,
      },
  ];
}

/// The shop's own knowledge for this question, in the customer's language.
///
/// The ranking has to run in Arabic: an Arabic question matches the Arabic
/// keywords, and without them the model got no knowledge at all and invented
/// the opening hours and the delivery policy.
String buildLocalContext(
  String query,
  AssistantMemory memory, {
  int limit = 4,
  bool? arabic,
}) {
  final inArabic = arabic ?? prefersArabic(query) || memory.replyArabic;
  final ranked = AssistantEngine.rankArticles(
    query,
    memory,
    limit: limit,
    arabic: inArabic,
  );
  final buffer = StringBuffer();
  if (ranked.isNotEmpty) {
    buffer.writeln('Local knowledge (most relevant first):');
    for (final entry in ranked) {
      var body = entry.$1.bodyFor(arabic: inArabic);
      if (body.length > 400) body = '${body.substring(0, 400)}…';
      buffer.writeln('- ${entry.$1.titleFor(arabic: inArabic)}: $body');
    }
  } else {
    buffer.writeln('No local knowledge matched this question.');
  }

  // The facts every answer needs, whether the question matched them or not.
  // The model invents an opening time and a delivery policy when it is not
  // told what they are.
  buffer.writeln('');
  buffer.writeln('The shop, in short:');
  for (final id in _alwaysUsefulArticles) {
    final article = _articleById(id);
    if (article == null) continue;
    var body = article.bodyFor(arabic: inArabic);
    if (body.length > 300) body = '${body.substring(0, 300)}…';
    buffer.writeln('- ${article.titleFor(arabic: inArabic)}: $body');
  }
  return buffer.toString();
}

/// The articles that are true whatever the customer asks.
const List<String> _alwaysUsefulArticles = [
  'faq-hours',
  'faq-delivery',
  'faq-payment',
  'faq-coupon',
];

KnowledgeArticle? _articleById(String id) {
  for (final article in [...faqKnowledge, ...coffeeKnowledge]) {
    if (article.id == id) return article;
  }
  return null;
}

/// Live app data grounding for the backend LLM: real menu (names, prices,
/// categories), real order statuses, cart contents and learned tastes.
/// Keeps the model honest — it answers from facts, not imagination.
String buildLiveContext(
  AssistantMemory memory, {
  required AssistantSnapshot snapshot,
  Set<String> cartProductIds = const {},
}) {
  final buffer = StringBuffer();
  buffer.writeln('Menu (name | category | price in SAR | ingredients):');
  for (final product in snapshot.products) {
    // The ingredients travel with the menu: without them the model answered
    // "we have a gluten-free option" for a shop whose cakes are made of flour.
    final knowledge = AssistantCatalog.current.knowledgeOfProduct(product);
    final ingredients = knowledge?.ingredients.join(', ') ?? '';
    buffer.writeln(
      '- ${product.name} | ${product.category} | ${product.price}'
      '${ingredients.isEmpty ? '' : ' | $ingredients'}',
    );
  }
  // Without this the model names the currency itself, and it guessed wrong:
  // "35 dinars" and "40 IQD" for a shop that charges riyals. The currency is
  // a fact of the shop, not something the model may infer.
  buffer.writeln(
    'Every price above is in SAR (Saudi riyals). Write an amount with Latin '
    'digits and the SAR suffix, e.g. "35.00 SAR". Never name another currency.',
  );
  final orders = snapshot.orders;
  if (orders.isEmpty) {
    buffer.writeln('Orders: none.');
  } else {
    buffer.writeln('Orders (product | status | qty):');
    for (final order in orders) {
      buffer.writeln(
        '- ${order.product.name} | ${order.status.label} | ${order.quantity}',
      );
    }
  }
  if (cartProductIds.isEmpty) {
    buffer.writeln('Cart: empty.');
  } else {
    final names = snapshot.products
        .where((product) => cartProductIds.contains(product.id))
        .map((product) => product.name)
        .join(', ');
    buffer.writeln('Cart: $names.');
  }
  final tastes = memory.exportJson();
  buffer.writeln('Learned tastes: ${tastes['categoryScores']}.');
  buffer.writeln('Rejected products: ${tastes['dismissedIds']}.');
  return buffer.toString();
}
