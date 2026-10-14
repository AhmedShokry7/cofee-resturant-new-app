import 'package:new_coffee/features/assistant/data/assistant_intents.dart';
import 'package:new_coffee/features/assistant/data/assistant_memory.dart';
import 'package:new_coffee/features/assistant/data/knowledge/coffee_knowledge.dart';
import 'package:new_coffee/features/assistant/data/knowledge/faq_knowledge.dart';
import 'package:new_coffee/features/home/data/greeting.dart';
import 'package:new_coffee/features/menu/data/menu_list.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/orders/data/orders_list.dart';

class AssistantAnswer {
  const AssistantAnswer({
    required this.text,
    this.sourceId,
    this.topic = 'general',
    this.quickReplies = const [],
    this.products = const [],
    this.navigateRoute,
    this.navigateLabel,
  });

  final String text;
  final String? sourceId;
  final String topic;
  final List<String> quickReplies;
  final List<ProductModel> products;
  final String? navigateRoute;
  final String? navigateLabel;
}

class AssistantEngine {
  static const List<String> defaultQuickReplies = [
    'Suggest a drink',
    'Track my order',
    'Any coupons?',
  ];

  static AssistantAnswer answer(
    String query, {
    required AssistantMemory memory,
    required DateTime now,
    Set<String> favoriteIds = const {},
  }) {
    final intent = detectIntent(query);
    switch (intent) {
      case AssistantIntent.greeting:
        return AssistantAnswer(
          text:
              '${getGreeting(now)}! I am your coffee assistant. I can suggest drinks, track orders and answer coffee questions.',
          topic: 'greeting',
          quickReplies: defaultQuickReplies,
        );
      case AssistantIntent.suggestDrink:
        return _suggest(query, memory: memory, now: now, favoriteIds: favoriteIds);
      case AssistantIntent.orderStatus:
        return _orderStatus();
      case AssistantIntent.showCoupons:
        return const AssistantAnswer(
          text:
              'We have active coupons right now. Open the Coupon page to copy a code and apply it at checkout.',
          topic: 'faq',
          sourceId: 'faq-coupon',
          quickReplies: ['Track my order', 'Suggest a drink'],
          navigateRoute: 'couponRoute',
          navigateLabel: 'Open Coupons',
        );
      case AssistantIntent.unknown:
        return _answerFromKnowledge(query, memory: memory);
    }
  }

  static AssistantAnswer _suggest(
    String query, {
    required AssistantMemory memory,
    required DateTime now,
    required Set<String> favoriteIds,
  }) {
    final tokens = tokenize(query);
    final scored = getMenuList().map((product) {
      var score = 1.0;
      score += (memory.categoryScores[product.category] ?? 0) * 0.6;
      if (favoriteIds.contains(product.id)) score += 0.5;
      if (isDaytime(now) &&
          (product.category == 'Hot Coffee' || product.category == 'Tea')) {
        score += 0.4;
      }
      if (!isDaytime(now) && product.category == 'Cold Coffee') score += 0.3;
      if (tokens.contains('strong')) {
        if (product.name == 'Espresso' || product.name == 'Americano') {
          score += 1.5;
        }
      }
      if (tokens.contains('sweet') || tokens.contains('chocolate')) {
        if (product.name == 'Mocha' || product.category == 'Desserts') {
          score += 1.5;
        }
      }
      if (tokens.contains('cheap') || tokens.contains('light')) {
        score += (60 - product.price) / 60;
      }
      if (product.hasDiscount) score += 0.3;
      for (final token in tokens) {
        if (product.name.toLowerCase().contains(token)) score += 1;
        if (product.category.toLowerCase().contains(token)) score += 1.5;
      }
      return MapEntry(product, score);
    }).toList()..sort((a, b) => b.value.compareTo(a.value));

    final picks = <ProductModel>[];
    for (final entry in scored) {
      if (picks.length >= 3) break;
      if (picks.any((picked) => picked.category == entry.key.category)) {
        continue;
      }
      picks.add(entry.key);
    }
    for (final entry in scored) {
      if (picks.length >= 3) break;
      if (!picks.any((picked) => picked.id == entry.key.id)) {
        picks.add(entry.key);
      }
    }

    final names = picks.map((product) => product.name).join(', ');
    final topCategory = memory.topCategory();
    final personal = topCategory == null
        ? 'Here are my top picks for you right now: $names.'
        : 'Since you enjoy $topCategory, I picked these for you: $names.';
    return AssistantAnswer(
      text: personal,
      topic: 'suggest',
      sourceId: 'suggest',
      products: picks,
      quickReplies: const ['Something stronger', 'Something sweet', 'Any coupons?'],
    );
  }

  static AssistantAnswer _orderStatus() {
    final active =
        getOrdersList().where((order) => order.status.name == 'active');
    if (active.isEmpty) {
      return const AssistantAnswer(
        text:
            'You have no active orders right now. Your last orders live on the My Orders screen.',
        topic: 'orders',
        sourceId: 'faq-track',
        quickReplies: ['Suggest a drink', 'Any coupons?'],
      );
    }
    final names = active.map((order) => order.product.name).join(', ');
    return AssistantAnswer(
      text:
          'You have ${active.length} active order${active.length == 1 ? '' : 's'}: $names. '
          'Open Track Order on any of them to see exactly where it is.',
      topic: 'orders',
      sourceId: 'faq-track',
      quickReplies: ['Suggest a drink', 'Any coupons?'],
    );
  }

  static List<(KnowledgeArticle, double)> rankArticles(
    String query,
    AssistantMemory memory, {
    int limit = 3,
  }) {
    final tokens = tokenize(query);
    final scored = <(KnowledgeArticle, double)>[];
    for (final article in [...faqKnowledge, ...coffeeKnowledge]) {
      var score = 0.0;
      for (final keyword in article.keywords) {
        if (tokens.contains(keyword)) score += 2;
        if (query.toLowerCase().contains(keyword)) score += 1;
      }
      if (article.title.toLowerCase().contains(query.toLowerCase().trim()) &&
          query.trim().length > 3) {
        score += 3;
      }
      score *= memory.sourceBoost(article.id);
      if (score > 0) scored.add((article, score));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored.take(limit).toList();
  }

  static AssistantAnswer _answerFromKnowledge(
    String query, {
    required AssistantMemory memory,
  }) {
    final ranked = rankArticles(query, memory, limit: 1);
    final best = ranked.isEmpty ? null : ranked.first.$1;
    final bestScore = ranked.isEmpty ? 0.0 : ranked.first.$2;

    if (best == null || bestScore < 2) {
      return const AssistantAnswer(
        text:
            'I did not catch that. I can suggest drinks, track your order, explain our menu or answer coffee questions.',
        topic: 'fallback',
        quickReplies: defaultQuickReplies,
      );
    }
    return AssistantAnswer(
      text: best.body,
      topic: best.topic,
      sourceId: best.id,
      quickReplies: const ['Suggest a drink', 'Track my order', 'Any coupons?'],
    );
  }
}
