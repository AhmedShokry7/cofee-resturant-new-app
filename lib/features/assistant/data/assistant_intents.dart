import 'package:new_coffee/features/assistant/data/assistant_language.dart';
import 'package:new_coffee/features/assistant/data/assistant_phrases.dart';

enum AssistantIntent {
  greeting,
  complaint,
  suggestDrink,
  orderStatus,
  showCoupons,
  thanks,
  usualOrder,
  botIdentity,
  farewell,
  affirm,
  deny,
  placeOrder,
  addToCart,
  cancelOrder,
  payNow,
  payCash,
  selectOrdinal,
  unknown,
}

/// Tokenizes any language (Arabic + Latin). Arabic stopwords included —
/// intent-bearing dialect words (عايز، بدي، ...) are NOT stopwords.
Set<String> tokenize(String text) {
  return tokenizeUnicode(text, _stopwords);
}

const Set<String> _stopwords = {
  // English (NOTE: "want" is intentionally NOT here — "i want coffee"
  // carries the whole intent).
  'the', 'and', 'for', 'with', 'you', 'your', 'are', 'what', 'how',
  'can', 'please', 'need', 'have', 'has', 'that', 'this',
  'from', 'about', 'there', 'here', 'will', 'would', 'could', 'should',
  'does', 'did', 'not', 'they', 'them', 'then', 'than', 'also', 'just',
  'like', 'get', 'got',
  // Arabic (normalized forms). NOTE: yes/no words (اه، ايوه، ايه، لا، لاء)
  // are intentionally NOT stopwords — they carry affirm/deny intent.
  // هذا/هذه demonstratives (foreigner Arabic) are noise — dropped.
  'انا', 'انت', 'انتي', 'هو', 'هي', 'احنا', 'انتو', 'ده', 'دي',
  'في', 'فيه', 'علي', 'من', 'الي', 'اي', 'ليه',
  'كده', 'كدا', 'عشان', 'لو', 'ممكن', 'عندك', 'عندكم',
  'يا', 'مش', 'ما', 'و', 'او',
  'بعد', 'قبل', 'بين', 'كل', 'جدا', 'اوي', 'كتير',
  'هذا', 'هذه', 'هاذا', 'هذي', 'ذلك', 'ذاك', 'تكفي', 'تكفى',
};

/// Detects the user intent with exact + typo-tolerant (fuzzy) keyword
/// matching and dialect phrase matching.
///
/// [recentQueries] + [lastTopic] give sentence-context awareness: a bare
/// follow-up ("something else?", "تاني؟") after a suggestion keeps the
/// suggestion intent instead of falling back.
AssistantIntent detectIntent(
  String query, {
  List<String> recentQueries = const [],
  String? lastTopic,
}) {
  final normalized = normalizeText(query);
  if (normalized.isEmpty) return AssistantIntent.unknown;
  final tokens = tokenize(query);
  final scores = scoreIntents(normalized, tokens);

  var best = AssistantIntent.unknown;
  var bestScore = 0.0;
  for (final entry in scores.entries) {
    if (entry.value > bestScore) {
      bestScore = entry.value;
      best = entry.key;
    }
  }

  // Ties involving discourse markers (yes/no) go to the action intent:
  // "طيب اطلب" means order, "ok suggest" means suggest — the weak
  // affirm/deny reading only wins outright with no competition.
  const weak = {AssistantIntent.affirm, AssistantIntent.deny};
  if (weak.contains(best) && bestScore > 0) {
    for (final entry in scores.entries) {
      if (entry.key == AssistantIntent.unknown ||
          weak.contains(entry.key)) {
        continue;
      }
      if (entry.value >= bestScore) {
        best = entry.key;
        bestScore = entry.value;
        break;
      }
    }
  }

  if (best == AssistantIntent.unknown && _isFollowUp(normalized, tokens)) {
    final history = [...recentQueries, ?lastTopic];
    final context = normalizeText(history.join(' '));
    if (context.contains('suggest') ||
        lastTopic == 'suggest' ||
        _mentionsDrink(context)) {
      return AssistantIntent.suggestDrink;
    }
  }
  return best;
}

/// Raw per-intent scores, exposed so the engine can attempt a closest-match
/// recovery when nothing wins outright.
Map<AssistantIntent, double> scoreIntents(
  String normalizedQuery,
  Set<String> tokens,
) {
  final scores = <AssistantIntent, double>{};
  for (final intent in AssistantIntent.values) {
    if (intent == AssistantIntent.unknown) continue;
    var score = 0.0;
    final keywords = [
      for (final raw in AssistantPhrases.intentKeywords[intent] ??
          const <String>[])
        normalizeText(raw),
    ].where((keyword) => keyword.isNotEmpty).toList();
    // Pass 1 — exact hits claim their token (one token scores once, so
    // overlapping verb forms like اطلب/طلب/نطلب cannot stack).
    final claimedTokens = <String>{};
    for (final keyword in keywords) {
      if (tokens.contains(keyword)) {
        score += 2;
        claimedTokens.add(keyword);
      }
    }
    // Pass 2 — substring hits for unclaimed longer keywords.
    for (final keyword in keywords) {
      if (claimedTokens.contains(keyword) || keyword.length < 4) continue;
      if (normalizedQuery.contains(keyword)) score += 1;
    }
    // Pass 3 — typo-tolerant hits on still-free tokens.
    final freeTokens = tokens.difference(claimedTokens);
    for (final keyword in keywords) {
      if (claimedTokens.contains(keyword)) continue;
      for (final token in freeTokens) {
        if (isFuzzyMatch(token, keyword)) {
          score += 1;
          break;
        }
      }
    }
    for (final rawPhrase in AssistantPhrases.intentPhrases[intent] ??
        const <String>[]) {
      final phrase = normalizeText(rawPhrase);
      // Full phrases outrank single keywords: they are more specific.
      if (phrase.length > 3 && normalizedQuery.contains(phrase)) {
        score += 2;
      }
    }
    scores[intent] = score;
  }
  return scores;
}

/// Last-resort recovery: the single closest known word/phrase to anything
/// the user typed (0.0..1.0 similarity). Returns null when even the closest
/// match is too far — then the bot honestly says it didn't understand.
(AssistantIntent, double)? recoverIntent(String query) {
  final tokens = tokenize(query);
  if (tokens.isEmpty) return null;
  AssistantIntent? best;
  var bestScore = 0.0;
  for (final intent in AssistantIntent.values) {
    if (intent == AssistantIntent.unknown) continue;
    final candidates = [
      ...?AssistantPhrases.intentKeywords[intent],
      ...?AssistantPhrases.intentPhrases[intent],
    ];
    for (final token in tokens) {
      for (final candidate in candidates) {
        final score = similarity(token, candidate);
        if (score > bestScore) {
          bestScore = score;
          best = intent;
        }
      }
    }
  }
  if (best == null || bestScore < 0.6) return null;
  return (best, bestScore);
}

bool _isFollowUp(String normalized, Set<String> tokens) {
  if (normalized.isEmpty) return false;
  for (final rawMarker in AssistantPhrases.followUpMarkers) {
    final marker = normalizeText(rawMarker);
    if (marker.isEmpty) continue;
    if (tokens.contains(marker)) return true;
    if (marker.length >= 4 && normalized.contains(marker)) return true;
  }
  return false;
}

bool _mentionsDrink(String normalizedContext) {
  const drinkWords = [
    'drink', 'coffee', 'suggest', 'recommend', 'tea', 'latte', 'mocha',
    'espresso', 'cappuccino', 'مشروب', 'قهوه', 'شاي', 'اقترح', 'رشح',
  ];
  for (final word in drinkWords) {
    if (normalizedContext.contains(normalizeText(word))) return true;
  }
  return false;
}
