import 'package:new_coffee/features/assistant/data/assistant_actions.dart';
import 'package:new_coffee/features/assistant/data/assistant_catalog.dart';
import 'package:new_coffee/features/assistant/data/assistant_composer.dart';
import 'package:new_coffee/features/assistant/data/assistant_greetings.dart';
import 'package:new_coffee/features/assistant/data/assistant_intents.dart';
import 'package:new_coffee/features/assistant/data/assistant_language.dart';
import 'package:new_coffee/features/assistant/data/assistant_memory.dart';
import 'package:new_coffee/features/assistant/data/assistant_order.dart';
import 'package:new_coffee/features/assistant/data/assistant_phrases.dart';
import 'package:new_coffee/features/assistant/data/knowledge/coffee_knowledge.dart';
import 'package:new_coffee/features/assistant/data/knowledge/faq_knowledge.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/features/home/data/greeting.dart';
import 'package:new_coffee/features/assistant/data/assistant_snapshot.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';


import 'package:new_coffee/shared/utils/formatters.dart';

/// One synonym hit: [start]..[end] in normalized text, [kind] 0 = product
/// name, 1 = generic category word.
typedef _MatchSpan = ({int start, int end, int kind, String value});

class AssistantAnswer {
  const AssistantAnswer({
    required this.text,
    this.sourceId,
    this.topic = 'general',
    this.quickReplies = const [],
    this.products = const [],
    this.navigateRoute,
    this.navigateLabel,
    this.actions = const [],
  });

  final String text;
  final String? sourceId;
  final String topic;
  final List<String> quickReplies;
  final List<ProductModel> products;
  final String? navigateRoute;
  final String? navigateLabel;

  /// Tool calls for the UI layer to execute (e.g. add items to the cart).
  final List<CartAction> actions;
}

class AssistantEngine {
  static const List<String> defaultQuickReplies = [
    'Suggest a drink',
    'Track my order',
    'Any coupons?',
  ];

  static AssistantAnswer answer(
    String query, {
    required AssistantSnapshot snapshot,
    required AssistantMemory memory,
    required DateTime now,
    Set<String> favoriteIds = const {},
    Set<String> cartProductIds = const {},
    bool isReturning = false,
    String? firstName,
  }) =>
      AssistantSnapshot.run(
        snapshot,
        () => _answer(
          query,
          memory: memory,
          now: now,
          favoriteIds: favoriteIds,
          cartProductIds: cartProductIds,
          isReturning: isReturning,
          firstName: firstName,
        ),
      );

  static AssistantAnswer _answer(
    String query, {
    required AssistantMemory memory,
    required DateTime now,
    Set<String> favoriteIds = const {},
    Set<String> cartProductIds = const {},
    bool isReturning = false,
    String? firstName,
  }) {
    // Corrections first: "مش عايز لاتيه" rejects Latte before anything else.
    final negatedIds = _negatedProductIds(query);
    for (final id in negatedIds) {
      memory.dismissProduct(id);
    }
    // LLM-style accommodation: answer in the user's own language and
    // remember it for the next greeting. Falls back to the app language
    // when the message carries no detectable script (adaptive to customer).
    final hasArabicScript = prefersArabic(query);
    final hasLatinScript = RegExp(r'[A-Za-z]').hasMatch(query);
    final arabic = hasArabicScript
        ? true
        : hasLatinScript
            ? false
            : AppLocale.instance.isArabic;
    memory.replyArabic = arabic;
    var leadPrefix = '';
    if (negatedIds.isNotEmpty) {
      final names = negatedIds
          .map(_productNameOf)
          .whereType<String>()
          .join(', ');
      leadPrefix = arabic
          ? (names.isEmpty
                ? 'تمام — مش ده. تحب تجرب إيه بدلها؟ '
                : 'تمام — بلاش $names. تحب تجرب إيه بدلها؟ ')
          : (names.isEmpty
                ? 'Got it — not that one. How about these instead? '
                : 'Got it — no $names. How about these instead? ');
    }
    // Refine an in-progress draft ("لا قصدي كبير", "خليه صغير", "من غير سكر")
    // without starting a new order.
    if (memory.draft.items.isNotEmpty) {
      final wanted = _expandAll(query, tokenize(query).toSet()).wanted;
      if (wanted.isEmpty) {
        final normalized = normalizeText(query);
        final cold = normalized.contains('ساقع') ||
            normalized.contains('بارد') ||
            normalized.contains('متلج') ||
            normalized.contains('مثلج') ||
            normalized.contains('ثلج') ||
            normalized.contains('cold') ||
            normalized.contains('iced');
        final hot = normalized.contains('سخن') ||
            normalized.contains('دافي') ||
            normalized.contains('حار') ||
            normalized.contains('hot');
        if (cold || hot) {
          final last = memory.draft.items.last;
          final lastProduct =
              AssistantSnapshot.current.productById(last.productId);
          if (lastProduct != null) {
            final lastName = AssistantSnapshot.canonicalName(lastProduct);
            final base = normalizeText(lastName).replaceAll('iced', '').trim();
            for (final product in AssistantSnapshot.current.products) {
              final candidate = AssistantSnapshot.canonicalName(product);
              final candidateCold = normalizeText(candidate).contains('iced') ||
                  normalizeText(candidate).contains('cold');
              final candidateBase =
                  normalizeText(candidate).replaceAll('iced', '').trim();
              final match = cold
                  ? (candidateCold && candidateBase == base)
                  : (!candidateCold && candidateBase == base);
              if (match) {
                memory.draft.items.removeLast();
                memory.draft.add(
                  OrderDraftItem(
                    productId: product.id,
                    quantity: last.quantity,
                    size: last.size,
                    sugar: last.sugar,
                  ),
                );
                return _draftTotal(memory, arabic: arabic);
              }
            }
          }
        }
        final newSize = OrderVariants.sizeFromQuery(query);
        final newSugar = OrderVariants.sugarFromQuery(query);
        if (newSize != null || newSugar != null) {
          memory.draft.updateLast(size: newSize, sugar: newSugar);
          return _draftTotal(memory, arabic: arabic);
        }
      }
    }
    // Draft follow-ups shortcut intent detection (price / clarification).
    if (memory.draft.items.isNotEmpty && _asksPrice(query)) {
      return _draftTotal(memory, arabic: arabic);
    }
    final priceAnswer = _productPriceAnswer(query, arabic: arabic);
    if (priceAnswer != null) return priceAnswer;
    if (memory.pendingQuestion == 'order_clarify') {
      final resolved = _resolveClarify(query, memory: memory, arabic: arabic);
      if (resolved != null) return resolved;
    }
    var intent = detectIntent(
      query,
      recentQueries: memory.recentQueries,
      lastTopic: memory.lastTopic,
    );
    if (negatedIds.isNotEmpty &&
        (intent == AssistantIntent.deny ||
            intent == AssistantIntent.unknown)) {
      intent = AssistantIntent.suggestDrink;
    }
    return respond(
      intent,
      query,
      memory: memory,
      now: now,
      favoriteIds: favoriteIds,
      cartProductIds: cartProductIds,
      isReturning: isReturning,
      firstName: firstName,
      leadPrefix: leadPrefix,
      negatedIds: negatedIds,
      arabic: arabic,
    );
  }

  /// Builds the reply for an already-detected [intent]. The smart fallback
  /// reuses this to answer with a recovered intent instead of giving up.
  static AssistantAnswer respond(
    AssistantIntent intent,
    String query, {
    required AssistantMemory memory,
    required DateTime now,
    Set<String> favoriteIds = const {},
    Set<String> cartProductIds = const {},
    bool isReturning = false,
    String? firstName,
    String leadPrefix = '',
    Set<String> negatedIds = const {},
    bool arabic = false,
  }) {
    final replies = arabic
        ? AssistantComposer.quickRepliesAr
        : defaultQuickReplies;
    switch (intent) {
      case AssistantIntent.greeting:
        memory.pendingQuestion = null;
        return AssistantAnswer(
          text: arabic
              ? AssistantGreetings.chatGreetingAr(
                  isReturning: isReturning || memory.totalChats > 0,
                  firstName: firstName,
                  now: now,
                )
              : AssistantGreetings.chatGreeting(
                  isReturning: isReturning || memory.totalChats > 0,
                  firstName: firstName,
                  now: now,
                ),
          topic: 'greeting',
          quickReplies: replies,
        );
      case AssistantIntent.thanks:
        return AssistantAnswer(
          text: arabic
              ? 'العفو! تحب حاجة تانية — ترشيح مشروب، حالة طلبك، ولا أحدث العروض؟'
              : 'You are most welcome! Anything else — a drink idea, your order status, or our latest offers?',
          topic: 'thanks',
          quickReplies: replies,
        );
      case AssistantIntent.suggestDrink:
        return _suggest(
          query,
          memory: memory,
          now: now,
          favoriteIds: favoriteIds,
          cartProductIds: cartProductIds,
          leadPrefix: leadPrefix,
          negatedIds: negatedIds,
          arabic: arabic,
        );
      case AssistantIntent.usualOrder:
        return _usual(
          query,
          memory: memory,
          now: now,
          favoriteIds: favoriteIds,
          arabic: arabic,
        );
      case AssistantIntent.orderStatus:
        memory.pendingQuestion = null;
        return _orderStatus(arabic: arabic);
      case AssistantIntent.showCoupons:
        memory.pendingQuestion = null;
        return AssistantAnswer(
          text: arabic
              ? 'في عروض شغالة دلوقتي. افتح صفحة العروض وانسخ الكود واستخدمه عند الدفع.'
              : 'We have active coupons right now. Open the Coupon page to copy a code and apply it at checkout.',
          topic: 'faq',
          sourceId: 'faq-coupon',
          quickReplies: arabic
              ? const ['فين الاوردر؟', 'رشحلي مشروب']
              : const ['Track my order', 'Suggest a drink'],
          navigateRoute: 'couponRoute',
          navigateLabel: arabic ? 'العروض' : 'Open Coupons',
        );
      case AssistantIntent.botIdentity:
        return AssistantAnswer(
          text: AssistantComposer.pick(
            arabic
                ? AssistantComposer.identityAr
                : AssistantComposer.identity,
            memory.totalChats,
          ),
          topic: 'identity',
          quickReplies: replies,
        );
      case AssistantIntent.farewell:
        return AssistantAnswer(
          text: AssistantComposer.pick(
            arabic
                ? AssistantComposer.farewellAr
                : AssistantComposer.farewell,
            memory.totalChats,
          ),
          topic: 'farewell',
          quickReplies: replies,
        );
      case AssistantIntent.affirm:
        if (memory.pendingQuestion == 'order_confirm') {
          return _executeConfirm(memory, arabic: arabic);
        }
        return _affirm(memory, arabic: arabic);
      case AssistantIntent.deny:
        if (memory.pendingQuestion == 'order_confirm') {
          return _cancelDraft(memory, arabic: arabic);
        }
        if (memory.pendingQuestion == 'order_payment') {
          return _cancelDraft(memory, arabic: arabic, keptInCart: true);
        }
        if (memory.pendingQuestion == 'order_clarify') {
          // Drops the unclear dessert; confirms whatever is already known.
          memory.pendingDessertSize = null;
          if (memory.draft.items.isNotEmpty) {
            return _confirmDraftMessage(memory, arabic: arabic);
          }
          return _cancelDraft(memory, arabic: arabic);
        }
        return _deny(memory, arabic: arabic);
      case AssistantIntent.placeOrder:
        return _takeOrder(query, memory: memory, now: now, arabic: arabic);
      case AssistantIntent.addToCart:
        return _addDirect(query, memory: memory, arabic: arabic);
      case AssistantIntent.cancelOrder:
        return _cancelDraft(memory, arabic: arabic);
      case AssistantIntent.payNow:
        return _payChoice(memory, arabic: arabic, now: true);
      case AssistantIntent.payCash:
        return _payChoice(memory, arabic: arabic, now: false);
      case AssistantIntent.complaint:
        return _complaint(
          query,
          memory: memory,
          now: now,
          favoriteIds: favoriteIds,
          cartProductIds: cartProductIds,
          arabic: arabic,
        );
      case AssistantIntent.selectOrdinal:
        final picked = _pickOrdinal(query, memory);
        if (picked != null) return _selectAnswer(picked, memory, arabic: arabic);
        return _suggest(
          query,
          memory: memory,
          now: now,
          favoriteIds: favoriteIds,
          cartProductIds: cartProductIds,
          arabic: arabic,
        );
      case AssistantIntent.unknown:
        return _smartFallback(
          query,
          memory: memory,
          now: now,
          favoriteIds: favoriteIds,
          cartProductIds: cartProductIds,
          arabic: arabic,
        );
    }
  }

  static String? _productNameOf(String id) {
    for (final product in AssistantSnapshot.current.products) {
      if (product.id == id) return product.name;
    }
    return null;
  }

  static String? _productIdOfName(String name) {
    for (final product in AssistantSnapshot.current.products) {
      if (AssistantSnapshot.canonicalName(product) == name) return product.id;
    }
    return null;
  }

  static bool _isWholeWord(String text, int index, int length) {
    final beforeOk = index == 0 || text[index - 1] == ' ';
    final end = index + length;
    final afterOk = end >= text.length || text[end] == ' ';
    return beforeOk && afterOk;
  }

  /// Finds products the user rejected in this very message
  /// ("مش عايز لاتيه", "بلاش موكا", "no latte"): a negation marker with a
  /// product mention starting within a few words after it.
  static Set<String> _negatedProductIds(String query) {
    final normalized = normalizeText(query);
    if (normalized.isEmpty) return {};
    // Mention start index -> product id.
    final spots = <int, String>{};
    void addMention(String phrase, String id) {
      final norm = normalizeText(phrase);
      if (norm.length < 3) return;
      var index = normalized.indexOf(norm);
      while (index >= 0) {
        if (_isWholeWord(normalized, index, norm.length)) {
          spots.putIfAbsent(index, () => id);
        }
        index = normalized.indexOf(norm, index + 1);
      }
    }
    for (final product in AssistantSnapshot.current.products) {
      final canonical = AssistantSnapshot.canonicalName(product);
      addMention(canonical, product.id);
      if (product.name != canonical) addMention(product.name, product.id);
    }
    for (final entry in AssistantPhrases.productSynonyms.entries) {
      final id = _productIdOfName(entry.value);
      if (id != null) addMention(entry.key, id);
    }
    if (spots.isEmpty) return {};
    final hits = <String>{};
    for (final rawMarker in AssistantPhrases.productNegations) {
      final marker = normalizeText(rawMarker);
      if (marker.isEmpty) continue;
      var index = normalized.indexOf(marker);
      while (index >= 0) {
        if (_isWholeWord(normalized, index, marker.length)) {
          final end = index + marker.length;
          for (final spot in spots.entries) {
            if (spot.key >= end && spot.key - end <= 14) {
              hits.add(spot.value);
            }
          }
        }
        index = normalized.indexOf(marker, index + 1);
      }
    }
    return hits;
  }

  static AssistantAnswer _suggest(
    String query, {
    required AssistantMemory memory,
    required DateTime now,
    required Set<String> favoriteIds,
    Set<String> cartProductIds = const {},
    String leadPrefix = '',
    Set<String> negatedIds = const {},
    bool arabic = false,
  }) {
    memory.pendingQuestion = null;
    final tokens = tokenize(query).toSet();
    final expanded = _expandAll(query, tokens);
    final wantedProducts = expanded.wanted;
    final ingredientHits = AssistantCatalog.current.detectIngredients(query);
    // Descriptive ask ("the one with chocolate and cream") → confirm the
    // single best match with its picture instead of a generic list.
    if (wantedProducts.isEmpty && _isDescriptiveAsk(query)) {
      final matches = AssistantCatalog.current.matchByIngredients(
        ingredientHits,
        excludeIds: memory.dismissedIds.toSet(),
      );
      if (matches.isNotEmpty) {
        return _ingredientAnswer(matches.first, memory, arabic: arabic);
      }
    }
    // Explicitly requested products forgive past rejections —
    // unless rejected again in this very message.
    for (final name in wantedProducts) {
      final id = _productIdOfName(name);
      if (id != null && !negatedIds.contains(id)) {
        memory.undismissProduct(id);
      }
    }
    // Taste learned from real order history (completed orders).
    final historyBoost = <String, double>{};
    for (final order in AssistantSnapshot.current.orders) {
      if (order.status.name == 'completed') {
        final key = AssistantSnapshot.categoryKey(order.product);
        historyBoost[key] = (historyBoost[key] ?? 0) + 0.4;
      }
    }
    final scored = AssistantSnapshot.current.products
        .where(
          // Dismissed products stay out — unless explicitly requested
          // again (and not re-rejected in this same message).
          (product) =>
              !memory.dismissedIds.contains(product.id) ||
              (wantedProducts.contains(
                    AssistantSnapshot.canonicalName(product),
                  ) &&
                  !negatedIds.contains(product.id)),
        )
        .map((product) {
      final canonicalName = AssistantSnapshot.canonicalName(product);
      final categoryKey = AssistantSnapshot.categoryKey(product);
      var score = 1.0;
      score += AssistantSnapshot.categoryScore(memory.categoryScores, product) * 0.6;
      score += (memory.productScores[product.id] ?? 0) * 0.5;
      score += historyBoost[categoryKey] ?? 0;
      if (expanded.categories.contains(categoryKey)) score += 2;
      // Ingredient overlap: "the one with chocolate" finds Mocha.
      if (ingredientHits.isNotEmpty) {
        final row = AssistantCatalog.current.knowledgeOfProduct(product);
        if (row != null) {
          var matched = 0;
          for (final ingredient in ingredientHits) {
            if (row.ingredients.contains(ingredient)) matched++;
          }
          score += matched * 1.5;
        }
      }
      if (favoriteIds.contains(product.id)) score += 0.5;
      if (wantedProducts.contains(canonicalName)) score += 3;
      if (isDaytime(now) &&
          (categoryKey == 'hot-coffee' || categoryKey == 'tea')) {
        score += 0.4;
      }
      if (!isDaytime(now) && categoryKey == 'cold-coffee') score += 0.3;
      if (tokens.contains('hot') &&
          (categoryKey == 'hot-coffee' || categoryKey == 'tea')) {
        score += 1;
      }
      if (tokens.contains('cold') &&
          (categoryKey == 'cold-coffee' ||
              categoryKey == 'milkshakes' ||
              categoryKey == 'soft-drinks')) {
        score += 1;
      }
      if (tokens.contains('strong')) {
        if (canonicalName == 'Espresso' || canonicalName == 'Americano') {
          score += 1.5;
        }
      }
      if (tokens.contains('sweet') || tokens.contains('chocolate')) {
        if (canonicalName == 'Mocha' || categoryKey == 'desserts') {
          score += 1.5;
        }
      }
      if (tokens.contains('cheap') || tokens.contains('light')) {
        score += (60 - product.price) / 60;
      }
      if (product.hasDiscount) score += 0.3;
      for (final token in tokens) {
        if (normalizeText(canonicalName).contains(token)) score += 1;
        if (normalizeText(product.category).contains(token)) score += 1.5;
      }
      return MapEntry(product, score);
    }).toList()..sort((a, b) => b.value.compareTo(a.value));

    final picks = <ProductModel>[];
    for (final entry in scored) {
      if (picks.length >= 3) break;
      if (picks.any(
        (picked) =>
            AssistantSnapshot.categoryKey(picked) ==
            AssistantSnapshot.categoryKey(entry.key),
      )) {
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
    var text = AssistantComposer.suggestText(
      names: names,
      preferenceCategory: memory.topCategory(),
      seed: memory.totalChats,
      leadPrefix: leadPrefix,
      arabic: arabic,
    );
    final pairing = _pairing(picks, cartProductIds, scored);
    final allPicks = [...picks, ?pairing];
    if (pairing != null) {
      text += arabic
          ? ' ماشي مع اللي في السلة عندك: ${pairing.name}.'
          : ' It pairs well with what is in your cart: ${pairing.name}.';
    }
    if (!_hasConstraints(tokens, wantedProducts, memory) &&
        ingredientHits.isEmpty) {
      memory.pendingQuestion = 'taste';
      text += AssistantComposer.pick(
        arabic
            ? AssistantComposer.tasteQuestionsAr
            : AssistantPhrases.tasteQuestions,
        memory.totalChats,
      );
    }
    memory.lastSuggestedIds = allPicks.map((p) => p.id).toList();
    return AssistantAnswer(
      text: text,
      topic: 'suggest',
      sourceId: 'suggest',
      products: allPicks,
      quickReplies: arabic
          ? AssistantComposer.suggestRepliesAr
          : const ['Something stronger', 'Something sweet', 'Any coupons?'],
    );
  }

  /// True when the request carries any explicit constraint (taste, product)
  /// or the bot already learned this user's taste. Order history silently
  /// steers the picks but never suppresses the clarification question —
  /// like an LLM, the bot still confirms the current mood.
  static bool _hasConstraints(
    Set<String> tokens,
    Set<String> wantedProducts,
    AssistantMemory memory,
  ) {
    if (wantedProducts.isNotEmpty) return true;
    const signals = {
      'sweet', 'strong', 'cheap', 'light', 'hot', 'cold', 'chocolate',
    };
    if (tokens.intersection(signals).isNotEmpty) return true;
    if (memory.preferenceSummary() != null) return true;
    // Generic words ("a drink", "coffee") are not constraints.
    const generic = {
      'drink', 'drinks', 'coffee', 'menu', 'beverage',
      'مشروب', 'مشروبات', 'قهوه',
    };
    for (final token in tokens) {
      if (token.length < 3 || generic.contains(token)) continue;
      for (final product in AssistantSnapshot.current.products) {
        if (normalizeText(product.name).contains(token) ||
            normalizeText(product.category).contains(token)) {
          return true;
        }
      }
    }
    return false;
  }

  /// "Is this the one?" — confirms an ingredient match WITH its picture
  /// (the card below shows the product image).
  static AssistantAnswer _ingredientAnswer(
    ProductModel product,
    AssistantMemory memory, {
    required bool arabic,
  }) {
    memory.pendingQuestion = null;
    return AssistantAnswer(
      text: arabic
          ? 'قصدك ${product.name}؟ هو دا؟'
          : 'Do you mean ${product.name}? Is this the one?',
      topic: 'suggest',
      sourceId: 'ingredient-match',
      products: [product],
      quickReplies: arabic
          ? const ['أيوه هو دا', 'لا مش هو']
          : const ['Yes, this one', 'Not this one'],
    );
  }

  /// True for "which one has X" style asks (اللي فيه / the one with).
  static bool _isDescriptiveAsk(String query) {
    final normalized = normalizeText(query);
    return normalized.contains('لي فيه') ||
        normalized.contains('لي فيها') ||
        normalized.contains('الي فيه') ||
        normalized.contains('الي فيها') ||
        normalized.contains('the one with') ||
        normalized.contains('which one has');
  }

  /// "Completes" the cart: coffee in cart -> dessert pairing and vice versa.
  static ProductModel? _pairing(
    List<ProductModel> picks,
    Set<String> cartIds,
    List<MapEntry<ProductModel, double>> scored,
  ) {
    if (cartIds.isEmpty) return null;
    final menu = AssistantSnapshot.current.products;
    final cartCats = menu
        .where((product) => cartIds.contains(product.id))
        .map(AssistantSnapshot.categoryKey)
        .toSet();
    if (cartCats.isEmpty) return null;
    const drinks = {
      'hot-coffee', 'cold-coffee', 'tea', 'milkshakes', 'soft-drinks',
    };
    const foods = {'desserts', 'snacks', 'bakery', 'donuts'};
    final pickCats =
        picks.map(AssistantSnapshot.categoryKey).toSet();
    String? target;
    if (cartCats.intersection(drinks).isNotEmpty &&
        pickCats.intersection(foods).isEmpty) {
      target = 'desserts';
    } else if (cartCats.intersection(foods).isNotEmpty &&
        pickCats.intersection(drinks).isEmpty) {
      target = 'hot-coffee';
    }
    if (target == null) return null;
    for (final entry in scored) {
      if (AssistantSnapshot.categoryKey(entry.key) == target &&
          !picks.any((picked) => picked.id == entry.key.id)) {
        return entry.key;
      }
    }
    return null;
  }

  /// Empathy first, then a fresh pick (cheap-leaning for price complaints).
  static AssistantAnswer _complaint(
    String query, {
    required AssistantMemory memory,
    required DateTime now,
    required Set<String> favoriteIds,
    Set<String> cartProductIds = const {},
    bool arabic = false,
  }) {
    final normalized = normalizeText(query);
    final priceTalk =
        normalized.contains('غال') || normalized.contains('cheap') ||
        normalized.contains('expensive') || normalized.contains('price');
    return _suggest(
      priceTalk ? '$query cheap' : query,
      memory: memory,
      now: now,
      favoriteIds: favoriteIds,
      cartProductIds: cartProductIds,
      arabic: arabic,
      leadPrefix: arabic
          ? (priceTalk
                ? 'معلش — تعالى ندور على حاجة حنينة على الجيب. '
                : 'متزعلش — تعالى نلاقيلك حاجة أحسن. ')
          : (priceTalk
                ? "Sorry about that — let's find something easier on the wallet. "
                : "Sorry to hear that — let's find you something better. "),
    );
  }

  /// "The first one / التاني" — picks from the latest suggestion.
  static ProductModel? _pickOrdinal(String query, AssistantMemory memory) {
    final ids = memory.lastSuggestedIds;
    if (ids.isEmpty) return null;
    final tokens = tokenize(query);
    int index = -1;
    if (tokens.intersection({'first', 'الاول'}).isNotEmpty) {
      index = 0;
    } else if (tokens.intersection({'second', 'التاني'}).isNotEmpty) {
      index = 1;
    } else if (tokens.intersection({'third', 'التالت'}).isNotEmpty) {
      index = 2;
    } else if (tokens.intersection({'الاخير', 'اخر'}).isNotEmpty ||
        normalizeText(query).contains('last one')) {
      index = ids.length - 1;
    }
    if (index < 0 || index >= ids.length) return null;
    return _productById(ids[index]);
  }

  static ProductModel? _productById(String id) {
    for (final product in AssistantSnapshot.current.products) {
      if (product.id == id) return product;
    }
    return null;
  }

  static AssistantAnswer _selectAnswer(
    ProductModel product,
    AssistantMemory memory, {
    bool arabic = false,
  }) {
    memory.pendingQuestion = null;
    return AssistantAnswer(
      text: arabic
          ? 'اختيار موفق — ${product.name}! دوس على الكارت عشان تفتحه.'
          : 'Excellent choice — ${product.name}! Tap the card to open it.',
      topic: 'suggest',
      sourceId: 'suggest-select',
      products: [product],
      quickReplies: arabic
          ? const ['فين الاوردر؟', 'حاجة تانية']
          : const ['Track my order', 'Something else', 'Any coupons?'],
    );
  }

  /// "My usual" — the single drink this customer loves most, learned from
  /// taps, favorites and real order history.
  static AssistantAnswer _usual(
    String query, {
    required AssistantMemory memory,
    required DateTime now,
    required Set<String> favoriteIds,
    bool arabic = false,
  }) {
    memory.pendingQuestion = null;
    final usual = _usualProduct(memory, favoriteIds);
    if (usual == null) {
      final fallback = _suggest(
        query,
        memory: memory,
        now: now,
        favoriteIds: favoriteIds,
        arabic: arabic,
        leadPrefix: arabic
            ? AssistantComposer.usualUnknownLeadAr
            : AssistantComposer.usualUnknownLead,
      );
      return AssistantAnswer(
        text: fallback.text,
        topic: 'suggest',
        sourceId: 'suggest-usual',
        products: fallback.products,
        quickReplies: fallback.quickReplies,
      );
    }
    return AssistantAnswer(
      text: AssistantComposer.fill(
        AssistantComposer.pick(
          arabic
              ? AssistantComposer.usualFoundAr
              : AssistantComposer.usualFound,
          memory.totalChats,
        ),
        {'product': usual.name},
      ),
      topic: 'suggest',
      sourceId: 'suggest-usual',
      products: [usual],
      quickReplies: arabic
          ? const ['أيوه', 'حاجة تانية', 'فين الاوردر؟']
          : const ['Yes please', 'Something else', 'Track my order'],
    );
  }

  static ProductModel? _usualProduct(
    AssistantMemory memory,
    Set<String> favoriteIds,
  ) {
    final menu = AssistantSnapshot.current.products;
    ProductModel? byId(String id) {
      for (final product in menu) {
        if (product.id == id) return product;
      }
      return null;
    }
    bool available(String id) => !memory.dismissedIds.contains(id);
    final topId = memory.topProductId();
    if (topId != null && available(topId)) {
      final found = byId(topId);
      if (found != null) return found;
    }
    final historyCounts = <String, int>{};
    for (final order in AssistantSnapshot.current.orders) {
      if (order.status.name == 'completed' && available(order.product.id)) {
        historyCounts[order.product.id] =
            (historyCounts[order.product.id] ?? 0) + order.quantity;
      }
    }
    if (historyCounts.isNotEmpty) {
      final top = historyCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final found = byId(top.first.key);
      if (found != null) return found;
    }
    for (final product in menu) {
      if (favoriteIds.contains(product.id) && available(product.id)) {
        return product;
      }
    }
    return null;
  }

  /// "Yes / اه / تمام" — continues whatever the bot just offered.
  static AssistantAnswer _affirm(AssistantMemory memory, {bool arabic = false}) {
    if (memory.lastTopic == 'suggest') {
      return AssistantAnswer(
        text: AssistantComposer.pick(
          arabic
              ? AssistantComposer.affirmSuggestAr
              : AssistantComposer.affirmSuggest,
          memory.totalChats,
        ),
        topic: 'affirm',
        quickReplies: arabic
            ? AssistantComposer.suggestRepliesAr
            : const ['Something stronger', 'Something sweet', 'Yes please'],
      );
    }
    return AssistantAnswer(
      text: AssistantComposer.pick(
        arabic
            ? AssistantComposer.affirmGeneralAr
            : AssistantComposer.affirmGeneral,
        memory.totalChats,
      ),
      topic: 'affirm',
      quickReplies: arabic
          ? AssistantComposer.quickRepliesAr
          : defaultQuickReplies,
    );
  }

  /// "No / لا / بلاش" — backs off gracefully and asks for a direction.
  static AssistantAnswer _deny(AssistantMemory memory, {bool arabic = false}) {
    if (memory.lastTopic == 'suggest') {
      return AssistantAnswer(
        text: arabic
            ? AssistantComposer.pick(
                AssistantComposer.denySuggestAr,
                memory.totalChats,
              )
            : 'No problem at all — tell me the mood and I will re-pick: strong, sweet, cold, or cheap?',
        topic: 'deny',
        quickReplies: arabic
            ? AssistantComposer.suggestRepliesAr
            : const ['Something stronger', 'Something sweet', 'Something else'],
      );
    }
    return AssistantAnswer(
      text: AssistantComposer.pick(
        arabic
            ? AssistantComposer.denyGeneralAr
            : AssistantComposer.denyGeneral,
        memory.totalChats,
      ),
      topic: 'deny',
      quickReplies: arabic
          ? AssistantComposer.quickRepliesAr
          : defaultQuickReplies,
    );
  }

  /// Maps dialect taste words + product names onto the canonical English
  /// tokens the scorer understands (حلو -> sweet, لاتيه -> Latte...).
  /// Returns exact menu names ([wanted]) plus boosted menu [categories]
  /// for generic words (حلا -> Desserts/Snacks/...).
  ///
  /// Overlapping synonyms resolve longest-first, so "ايس لاتيه" matches
  /// Iced Latte — not Latte hiding inside it.
  static ({Set<String> wanted, Set<String> categories}) _expandAll(
    String query,
    Set<String> tokens,
  ) {
    final normalized = normalizeText(query);
    for (final entry in AssistantPhrases.tasteSynonyms.entries) {
      if (_containsWord(normalized, normalizeText(entry.key))) {
        tokens.add(entry.value);
      }
    }
    final spans = <_MatchSpan>[];
    void collect(String phrase, int kind, String value) {
      final synonym = normalizeText(phrase);
      if (synonym.length < 3) return;
      var index = normalized.indexOf(synonym);
      while (index >= 0) {
        if (_isWholeWord(normalized, index, synonym.length)) {
          spans.add(
            (start: index, end: index + synonym.length, kind: kind, value: value),
          );
        }
        index = normalized.indexOf(synonym, index + 1);
      }
    }

    for (final entry in AssistantPhrases.productSynonyms.entries) {
      collect(entry.key, 0, entry.value);
    }
    // Raw menu names too ("i want latte" must find Latte even in Latin).
    for (final product in AssistantSnapshot.current.products) {
      collect(
        AssistantSnapshot.canonicalName(product),
        0,
        AssistantSnapshot.canonicalName(product),
      );
      if (product.name != AssistantSnapshot.canonicalName(product)) {
        collect(product.name, 0, AssistantSnapshot.canonicalName(product));
      }
    }
    for (final entry in AssistantPhrases.categoryBoosts.entries) {
      collect(entry.key, 1, entry.key);
    }
    spans.sort((a, b) => (b.end - b.start).compareTo(a.end - a.start));
    final accepted = <_MatchSpan>[];
    for (final span in spans) {
      var overlaps = false;
      for (final taken in accepted) {
        if (span.start < taken.end && taken.start < span.end) {
          overlaps = true;
          break;
        }
      }
      if (!overlaps) accepted.add(span);
    }
    final wanted = <String>{};
    final categories = <String>{};
    for (final span in accepted) {
      if (span.kind == 0) {
        if (span.value == 'coffee') {
          tokens.add('coffee');
        } else {
          wanted.add(span.value);
        }
      } else {
        categories.addAll(
          AssistantPhrases.categoryBoosts[span.value] ?? const {},
        );
      }
    }
    // Typo recovery: a misspelled product token ("لاتي" / "latteh") that did
    // not match any exact span still resolves to the closest menu name.
    for (final token in tokens) {
      if (token.length < 4) continue;
      final candidates = AssistantSnapshot.current.products
          .map(AssistantSnapshot.canonicalName);
      final match = closestMatch(token, candidates);
      if (match != null) wanted.add(match);
    }
    return (wanted: wanted, categories: categories);
  }

  static bool _containsWord(String normalized, String phrase) {
    if (phrase.length < 3) return false;
    var index = normalized.indexOf(phrase);
    while (index >= 0) {
      if (_isWholeWord(normalized, index, phrase.length)) return true;
      index = normalized.indexOf(phrase, index + 1);
    }
    return false;
  }

  static AssistantAnswer _orderStatus({bool arabic = false}) {
    final orders = AssistantSnapshot.current.orders;
    final active =
        orders.where((order) => order.status.name == 'active').toList();
    final delivered =
        orders.where((order) => order.status.name == 'completed').toList();
    if (active.isEmpty && delivered.isEmpty) {
      return AssistantAnswer(
        text: arabic
            ? 'لسه معندكش طلبات. قولي نفسك في إيه وأنا أرشحلك حاجة!'
            : 'You have no orders yet. Tell me what you feel like and I will suggest something!',
        topic: 'orders',
        sourceId: 'orders-empty',
        quickReplies: arabic
            ? const ['رشحلي مشروب', 'في عروض؟']
            : const ['Suggest a drink', 'Any coupons?'],
      );
    }
    final lines = [
      ...active.map(
        arabic
            ? AssistantGreetings.orderStatusLineAr
            : AssistantGreetings.orderStatusLine,
      ),
      ...delivered
          .take(2)
          .map(
            arabic
                ? AssistantGreetings.orderStatusLineAr
                : AssistantGreetings.orderStatusLine,
          ),
    ];
    return AssistantAnswer(
      text: arabic
          ? '${lines.join(' ')} افتح طلباتي للمتابعة لحظة بلحظة.'
          : '${lines.join(' ')} Open My Orders for live tracking.',
      topic: 'orders',
      sourceId: 'orders-status',
      quickReplies: arabic
          ? const ['رشحلي مشروب', 'في عروض؟']
          : const ['Suggest a drink', 'Any coupons?'],
      navigateRoute: 'ordersRoute',
      navigateLabel: arabic ? 'طلباتي' : 'My Orders',
    );
  }

  // ==================== Conversational ordering ====================

  static bool _asksPrice(String query) {
    final normalized = normalizeText(query);
    // Short markers need whole-word match ("كم" lives inside "كمان").
    if (normalized.split(' ').contains('كم')) return true;
    const markers = [
      'بكام', 'بكم', 'سعر', 'اسعار', 'how much', 'total', 'الحساب',
      'فاتوره', 'التوتال', 'يكلف', 'هيكلف', 'price', 'cost',
    ];
    for (final marker in markers) {
      if (normalized.contains(normalizeText(marker))) return true;
    }
    return false;
  }

  /// "كم سعر اللاتيه؟" → answers with the REAL menu price (no guessing).
  /// Returns null when no product is named (other intents handle it).
  static AssistantAnswer? _productPriceAnswer(
    String query, {
    required bool arabic,
  }) {
    if (!_asksPrice(query)) return null;
    final tokens = tokenize(query).toSet();
    final wanted = _expandAll(query, tokens).wanted;
    if (wanted.isEmpty) return null;
    final lines = <String>[];
    final products = <ProductModel>[];
    for (final name in wanted) {
      for (final product in AssistantSnapshot.current.products) {
        if (AssistantSnapshot.canonicalName(product) == name &&
            !products.any((p) => p.id == product.id)) {
          products.add(product);
          lines.add(
            arabic
                ? '$name بـ ${Formatters.price(product.price)}'
                : '$name is ${Formatters.price(product.price)}',
          );
        }
      }
    }
    if (lines.isEmpty) return null;
    return AssistantAnswer(
      text: arabic
          ? 'الأسعار عندنا: ${lines.join('، ')}.'
          : 'Our prices: ${lines.join(', ')}.',
      topic: 'prices',
      sourceId: 'price-inquiry',
      products: products,
      quickReplies: arabic
          ? const ['عايز اطلب', 'ضيف للسلة']
          : const ['I want to order', 'Add to cart'],
    );
  }

  static AssistantAnswer _draftTotal(
    AssistantMemory memory, {
    required bool arabic,
  }) {
    final summary = memory.draft.describe(arabic: arabic);
    final total = Formatters.price(memory.draft.total());
    return AssistantAnswer(
      text: arabic
          ? 'الاوردر بتاعك: $summary. الإجمالي $total.'
          : 'Your order so far: $summary. Total $total.',
      topic: 'order',
      sourceId: 'order-total',
      products: _draftProducts(memory),
      quickReplies: memory.pendingQuestion == 'order_confirm'
          ? (arabic
                ? const ['أكد الاوردر', 'الغي']
                : const ['Confirm order', 'Cancel'])
          : (arabic
                ? AssistantComposer.quickRepliesAr
                : defaultQuickReplies),
    );
  }

  static List<ProductModel> _draftProducts(AssistantMemory memory) {
    final menu = AssistantSnapshot.current.products;
    final products = <ProductModel>[];
    for (final item in memory.draft.items) {
      for (final product in menu) {
        if (product.id == item.productId &&
            !products.any((p) => p.id == product.id)) {
          products.add(product);
        }
      }
    }
    return products;
  }

  static List<ProductModel> _dessertOptions() {
    const sweetCats = {'desserts', 'snacks', 'bakery', 'donuts'};
    return AssistantSnapshot.current.products
        .where(
          (product) =>
              sweetCats.contains(AssistantSnapshot.categoryKey(product)),
        )
        .take(3)
        .toList();
  }

  /// "اعملي اوردر لاتيه كبير..." → parses, merges into the draft and asks
  /// for confirmation (or asks which dessert when unclear).
  static AssistantAnswer _takeOrder(
    String query, {
    required AssistantMemory memory,
    required DateTime now,
    required bool arabic,
  }) {
    final parsed = parseOrderMessage(query);
    for (final item in parsed.items) {
      memory.draft.add(item);
    }
    if (parsed.items.isEmpty && !parsed.unclearDessert) {
      return AssistantAnswer(
        text: arabic
            ? 'عيني! عايز تطلب إيه بالظبط؟ قولي مثلا "2 لاتيه كبير".'
            : 'With pleasure! What exactly would you like? Say e.g. "2 large lattes".',
        topic: 'order',
        sourceId: 'order-empty',
        quickReplies: arabic
            ? const ['لاتيه كبير', 'كابتشينو', 'تشيز كيك']
            : const ['Large latte', 'Cappuccino', 'Cheesecake'],
      );
    }
    if (parsed.unclearDessert) {
      memory.pendingQuestion = 'order_clarify';
      memory.pendingDessertSize = parsed.unclearSize;
      final known = memory.draft.items.isNotEmpty
          ? (arabic
                ? 'ضفت ${memory.draft.describe(arabic: arabic)}. '
                : 'Added ${memory.draft.describe(arabic: arabic)}. ')
          : '';
      final options = _dessertOptions()
          .map((product) => product.name)
          .join('، ');
      return AssistantAnswer(
        text: arabic
            ? '$knownالحلو نوع إيه بالظبط؟ عندنا $options.'
            : '${known}Which dessert exactly? We have $options.',
        topic: 'order',
        sourceId: 'order-clarify',
        products: _draftProducts(memory),
        quickReplies: _dessertOptions()
            .map((product) => product.name)
            .toList(),
      );
    }
    return _confirmDraftMessage(memory, arabic: arabic);
  }

  /// Resolves the dessert clarification ("تشيز كيك" after "وطبق حلو").
  /// Returns null when the reply names nothing (the bot asks again).
  static AssistantAnswer? _resolveClarify(
    String query, {
    required AssistantMemory memory,
    required bool arabic,
  }) {
    final parsed = parseOrderMessage(query);
    if (parsed.items.isEmpty && !parsed.unclearDessert) return null;
    for (final item in parsed.items) {
      memory.draft.add(
        OrderDraftItem(
          productId: item.productId,
          quantity: item.quantity,
          size: item.size ?? memory.pendingDessertSize,
          sugar: item.sugar,
        ),
      );
    }
    memory.pendingDessertSize = null;
    if (memory.draft.items.isEmpty) {
      final options = _dessertOptions()
          .map((product) => product.name)
          .join('، ');
      return AssistantAnswer(
        text: arabic
            ? 'محددتش — تحب $options؟'
            : 'Pick one for me — $options?',
        topic: 'order',
        sourceId: 'order-clarify',
        quickReplies: _dessertOptions()
            .map((product) => product.name)
            .toList(),
      );
    }
    if (parsed.unclearDessert) {
      memory.pendingQuestion = 'order_clarify';
      return _takeOrderClarifyAgain(memory, arabic: arabic);
    }
    return _confirmDraftMessage(memory, arabic: arabic);
  }

  static AssistantAnswer _takeOrderClarifyAgain(
    AssistantMemory memory, {
    required bool arabic,
  }) {
    final options = _dessertOptions().map((p) => p.name).join('، ');
    return AssistantAnswer(
      text: arabic
          ? 'ضفت ${memory.draft.describe(arabic: arabic)}. والحلو نوع إيه؟ عندنا $options.'
          : 'Added ${memory.draft.describe(arabic: arabic)}. And which dessert? We have $options.',
      topic: 'order',
      sourceId: 'order-clarify',
      products: _draftProducts(memory),
      quickReplies: _dessertOptions().map((p) => p.name).toList(),
    );
  }

  static AssistantAnswer _confirmDraftMessage(
    AssistantMemory memory, {
    required bool arabic,
  }) {
    memory.pendingQuestion = 'order_confirm';
    final summary = memory.draft.describe(arabic: arabic);
    final total = Formatters.price(memory.draft.total());
    return AssistantAnswer(
      text: arabic
          ? 'تمام! الاوردر بتاعك: $summary. الإجمالي $total. أكد؟'
          : 'Got it! Your order: $summary. Total $total. Confirm?',
      topic: 'order',
      sourceId: 'order-confirm',
      products: _draftProducts(memory),
      quickReplies: arabic
          ? const ['أكد الاوردر', 'الغي']
          : const ['Confirm order', 'Cancel'],
    );
  }

  /// "ايوه" on a confirmation → fills the real cart, then asks how to pay.
  static AssistantAnswer _executeConfirm(
    AssistantMemory memory, {
    required bool arabic,
  }) {
    if (memory.draft.items.isEmpty) {
      memory.pendingQuestion = null;
      return AssistantAnswer(
        text: arabic
            ? 'مفيش حاجة في الاوردر حالياً. قولي عايز تطلب إيه.'
            : 'Your order is empty right now. Tell me what to add.',
        topic: 'order',
        sourceId: 'order-empty-confirm',
        quickReplies: arabic
            ? const ['عايز اطلب', 'رشحلي مشروب']
            : const ['I want to order', 'Suggest a drink'],
      );
    }
    final actions = memory.draft.items
        .map(
          (item) => AssistantSnapshot.current.cartActionFor(
            item,
            arabic: arabic,
          ),
        )
        .toList();
    final summary = memory.draft.describe(arabic: arabic);
    final products = _draftProducts(memory);
    memory.draft = OrderDraft();
    memory.pendingQuestion = 'order_payment';
    memory.pendingDessertSize = null;
    return AssistantAnswer(
      text: arabic
          ? 'تمام! حطيت طلبك في السلة: $summary. تحب تدفع دلوقتي ولا عند الاستلام؟'
          : 'Done! Added to your cart: $summary. Pay now or on delivery?',
      topic: 'order',
      sourceId: 'order-confirmed',
      products: products,
      quickReplies: arabic
          ? const ['ادفع دلوقتي', 'عند الاستلام']
          : const ['Pay now', 'Cash on delivery'],
      actions: actions,
    );
  }

  /// "ضيف لاتيه للسلة" → immediate cart action, no confirmation round-trip.
  static AssistantAnswer _addDirect(
    String query, {
    required AssistantMemory memory,
    required bool arabic,
  }) {
    final parsed = parseOrderMessage(query);
    if (parsed.items.isEmpty) {
      return AssistantAnswer(
        text: arabic
            ? 'أضيف إيه للسلة؟ قولي اسم المشروب أو الحلو.'
            : 'What should I add to the cart? Name the drink or dessert.',
        topic: 'order',
        sourceId: 'order-add-empty',
        quickReplies: arabic
            ? const ['لاتيه', 'كابتشينو', 'تشيز كيك']
            : const ['Latte', 'Cappuccino', 'Cheesecake'],
      );
    }
    final names = <String>[];
    final products = <ProductModel>[];
    final actions = <CartAction>[];
    for (final item in parsed.items) {
      for (final product in AssistantSnapshot.current.products) {
        if (product.id == item.productId) {
          final note =
              AssistantSnapshot.current.variantNoteFor(item, arabic: arabic);
          names.add(
            '${item.quantity}x ${product.name}${note.isEmpty ? '' : ' ($note)'}',
          );
          products.add(product);
          actions.add(
            AssistantSnapshot.current.cartActionFor(item, arabic: arabic),
          );
        }
      }
    }
    return AssistantAnswer(
      text: arabic
          ? 'ضفت للسلة: ${names.join(' + ')}.'
          : 'Added to your cart: ${names.join(' + ')}.',
      topic: 'order',
      sourceId: 'order-added',
      products: products,
      quickReplies: arabic
          ? const ['عايز اطلب حاجة تانية', 'عايز ادفع']
          : const ['Order more', 'Checkout'],
      actions: actions,
    );
  }

  static AssistantAnswer _cancelDraft(
    AssistantMemory memory, {
    required bool arabic,
    bool keptInCart = false,
  }) {
    final hadDraft = memory.draft.items.isNotEmpty;
    memory.draft = OrderDraft();
    memory.pendingQuestion = null;
    memory.pendingDessertSize = null;
    if (!hadDraft && !keptInCart) {
      return AssistantAnswer(
        text: arabic
            ? 'مفيش اوردر شغال حالياً.'
            : 'There is no active order right now.',
        topic: 'order',
        sourceId: 'order-cancel-empty',
        quickReplies: arabic
            ? AssistantComposer.quickRepliesAr
            : defaultQuickReplies,
      );
    }
    return AssistantAnswer(
      text: arabic
          ? (keptInCart
                ? 'تمام، طلبك محفوظ في السلة. وقت ما تحب تكمل قولي.'
                : 'تمام، لغيت الاوردر بتاعك.')
          : (keptInCart
                ? 'Done, your order is kept in the cart. Tell me when to continue.'
                : 'Done, your order is cancelled.'),
      topic: 'order',
      sourceId: 'order-cancelled',
      quickReplies: arabic
          ? AssistantComposer.quickRepliesAr
          : defaultQuickReplies,
    );
  }

  /// Pays for the confirmed order: opens real checkout, hinting the method.
  static AssistantAnswer _payChoice(
    AssistantMemory memory, {
    required bool arabic,
    required bool now,
  }) {
    final actions = <CartAction>[];
    var prefix = '';
    if (memory.draft.items.isNotEmpty) {
      // Skipped confirmation: confirm silently, then pay.
      for (final item in memory.draft.items) {
        actions.add(
          AssistantSnapshot.current.cartActionFor(item, arabic: arabic),
        );
      }
      prefix = arabic ? 'ضفت طلبك للسلة. ' : 'Added your order to the cart. ';
      memory.draft = OrderDraft();
    }
    memory.pendingQuestion = null;
    memory.pendingDessertSize = null;
    if (now) {
      return AssistantAnswer(
        text: arabic
            ? '$prefixتمام، افتح الدفع واختار البطاقة المناسبة.'
            : '${prefix}Opening payment — pick your card there.',
        topic: 'order',
        sourceId: 'order-pay-now',
        navigateRoute: 'checkoutRoute',
        navigateLabel: arabic ? 'ادفع دلوقتي' : 'Pay now',
        actions: actions,
      );
    }
    return AssistantAnswer(
      text: arabic
          ? '$prefixتمام، افتح الدفع واختار (عند الاستلام).'
          : '${prefix}Opening checkout — choose On Delivery there.',
      topic: 'order',
      sourceId: 'order-pay-cash',
      navigateRoute: 'checkoutRoute',
      navigateLabel: arabic ? 'إتمام الاوردر' : 'Checkout',
      actions: actions,
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

  /// Never gives up immediately: first checks for recognizable entities
  /// (a product or taste word), then closest-intent recovery for heavy
  /// typos, then the knowledge base, and only finally a varied fallback.
  /// The fallback keeps topic 'fallback' so LLM escalation still works.
  static AssistantAnswer _smartFallback(
    String query, {
    required AssistantMemory memory,
    required DateTime now,
    required Set<String> favoriteIds,
    Set<String> cartProductIds = const {},
    bool arabic = false,
  }) {
    final tokens = tokenize(query).toSet();
    final expanded = _expandAll(query, tokens);
    final wanted = expanded.wanted;
    if (wanted.isNotEmpty) {
      return _suggest(
        query,
        memory: memory,
        now: now,
        favoriteIds: favoriteIds,
        cartProductIds: cartProductIds,
        arabic: arabic,
        leadPrefix: arabic ? 'اختيار جميل. ' : 'Love that choice. ',
      );
    }
    if (expanded.categories.isNotEmpty) {
      return _suggest(
        query,
        memory: memory,
        now: now,
        favoriteIds: favoriteIds,
        cartProductIds: cartProductIds,
        arabic: arabic,
        leadPrefix: arabic ? 'تمام. ' : 'Got you. ',
      );
    }
    // "The one with chocolate and cream" → confirm with its picture.
    final ingredientHits = AssistantCatalog.current.detectIngredients(query);
    if (ingredientHits.isNotEmpty) {
      final matches = AssistantCatalog.current.matchByIngredients(
        ingredientHits,
        excludeIds: memory.dismissedIds.toSet(),
      );
      if (matches.isNotEmpty) {
        return _ingredientAnswer(matches.first, memory, arabic: arabic);
      }
    }
    const tasteTokens = {
      'sweet', 'strong', 'cheap', 'light', 'hot', 'cold', 'chocolate',
    };
    if (tokens.intersection(tasteTokens).isNotEmpty) {
      return _suggest(
        query,
        memory: memory,
        now: now,
        favoriteIds: favoriteIds,
        cartProductIds: cartProductIds,
        leadPrefix: 'Got you. ',
      );
    }
    final recovered = recoverIntent(query);
    if (recovered != null) {
      return respond(
        recovered.$1,
        query,
        memory: memory,
        now: now,
        favoriteIds: favoriteIds,
        cartProductIds: cartProductIds,
        arabic: arabic,
      );
    }
    final ranked = rankArticles(query, memory, limit: 1);
    final best = ranked.isEmpty ? null : ranked.first.$1;
    final bestScore = ranked.isEmpty ? 0.0 : ranked.first.$2;
    if (best != null && bestScore >= 2) {
      return AssistantAnswer(
        // Knowledge base is English; Arabic users get a local intro.
        text: arabic ? 'لقيتلك المعلومة دي: ${best.body}' : best.body,
        topic: best.topic,
        sourceId: best.id,
        quickReplies: arabic
            ? AssistantComposer.quickRepliesAr
            : const ['Suggest a drink', 'Track my order', 'Any coupons?'],
      );
    }
    return AssistantAnswer(
      text: AssistantComposer.pick(
        arabic ? AssistantComposer.fallbackAr : AssistantComposer.fallback,
        memory.totalChats,
      ),
      topic: 'fallback',
      quickReplies: arabic
          ? AssistantComposer.quickRepliesAr
          : defaultQuickReplies,
    );
  }
}
