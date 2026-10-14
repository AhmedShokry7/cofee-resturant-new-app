enum AssistantIntent {
  greeting,
  suggestDrink,
  orderStatus,
  showCoupons,
  unknown,
}

class _IntentPattern {
  const _IntentPattern(this.intent, this.keywords);

  final AssistantIntent intent;
  final List<String> keywords;
}

const List<_IntentPattern> _intentPatterns = [
  _IntentPattern(AssistantIntent.greeting, [
    'hello',
    'hi',
    'hey',
    'salam',
    'morning',
    'evening',
    'good day',
  ]),
  _IntentPattern(AssistantIntent.suggestDrink, [
    'suggest',
    'recommend',
    'best',
    'favorite',
    'favourite',
    'try',
    'new',
    'bored',
    'surprise',
    'what should',
    'ideas',
    'strong',
    'sweet',
    'cheap',
    'light',
    'something',
  ]),
  _IntentPattern(AssistantIntent.orderStatus, [
    'order',
    'status',
    'where',
    'delivered',
    'package',
    'arrived',
    'tracking',
    'track',
    'my order',
  ]),
  _IntentPattern(AssistantIntent.showCoupons, [
    'coupon',
    'discount',
    'promo',
    'offer',
    'code',
    'deal',
    'sale',
  ]),
];

Set<String> tokenize(String text) {
  return text
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((token) => token.length > 1 && !_stopwords.contains(token))
      .toSet();
}

const Set<String> _stopwords = {
  'the',
  'and',
  'for',
  'with',
  'you',
  'your',
  'are',
  'what',
  'how',
  'can',
  'please',
  'want',
  'need',
  'have',
  'has',
  'that',
  'this',
  'from',
  'about',
  'there',
  'here',
  'will',
  'would',
  'could',
  'should',
  'does',
  'did',
  'not',
};

AssistantIntent detectIntent(String query) {
  final tokens = tokenize(query);
  var best = AssistantIntent.unknown;
  var bestScore = 0;

  for (final pattern in _intentPatterns) {
    var score = 0;
    for (final keyword in pattern.keywords) {
      if (tokens.contains(keyword)) score += 2;
      if (query.toLowerCase().contains(keyword)) score += 1;
    }
    if (score > bestScore) {
      bestScore = score;
      best = pattern.intent;
    }
  }
  return best;
}
