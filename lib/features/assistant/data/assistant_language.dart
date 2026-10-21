/// Low-level language tools: Arabic normalization, unicode-aware
/// tokenization and typo-tolerant (fuzzy) matching.
///
/// Everything here is pure Dart so it can be unit-tested without Flutter.
library;

/// Normalizes Arabic text so dialects and typos collapse to one form:
/// - alef variants (أ إ آ ا) -> ا
/// - taa marbuta (ة) -> ه, alef maqsura (ى) -> ي
/// - removes tashkeel (diacritics) and tatweel (ـ)
/// - collapses elongated letters (عليهه -> عليه, حلووو -> حلو)
/// - unifies common dialect spellings (e.g. گ/چ/پ -> ك/ج/ب, ؤ/ئ handled)
/// Latin text is lower-cased. Punctuation is replaced with spaces.
String normalizeText(String input) {
  var text = input.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);
    if (_tashkeel.hasMatch(char) || char == 'ـ') continue;
    buffer.write(_alefVariants[char] ?? char);
  }
  text = buffer.toString();
  // Collapse whitespace/punctuation into single spaces.
  text = text.replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ');
  // Detach the conjunction و when glued to a long word (وكريمه -> و كريمه)
  // so matching sees the real word. Needs 4+ letters after و, which keeps
  // واحد / وحش / ودي / وين / ولا / ولو intact. Runs before ال-stripping so
  // والشاي becomes و شاي.
  text = text.replaceAllMapped(
    RegExp('(^| )و(?=\\p{L}{4,})', unicode: true),
    (match) => '${match.group(1)}و ',
  );
  // Strip the Arabic definite article (اللاتيه -> لاتيه) so "the X" and "X"
  // match the same stock. Applied to both queries and keywords, so it is
  // always consistent. Requires 2+ letters after ال (bare ال stays).
  //
  // The preposition is included because the article follows it in the written
  // form: "بالمكسرات" (with nuts) is ب + ال + مكسرات, and the article has to
  // go as well for the ingredient to be found.
  text = text.replaceAllMapped(
    RegExp('(^| |ب)ال(?=\\p{L}{2,})', unicode: true),
    (match) => match.group(1)!,
  );
  // Collapse emphatic elongation (3+ repeats: حلووو -> حلو). Normal
  // double letters (sweet, coffee, اللي) are intentionally preserved
  // so everyday spelling keeps matching exactly.
  text = text.replaceAllMapped(
    RegExp(r'(\p{L})\1{2,}', unicode: true),
    (match) => match.group(1)!,
  );
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}

const Map<String, String> _alefVariants = {
  'أ': 'ا',
  'إ': 'ا',
  'آ': 'ا',
  'ة': 'ه',
  'ى': 'ي',
  'ؤ': 'و',
  'ئ': 'ي',
  'گ': 'ك',
  'چ': 'ج',
  'پ': 'ب',
  'ڤ': 'ف',
  '٠': '0',
  '١': '1',
  '٢': '2',
  '٣': '3',
  '٤': '4',
  '٥': '5',
  '٦': '6',
  '٧': '7',
  '٨': '8',
  '٩': '9',
};

final RegExp _tashkeel = RegExp('[\u064B-\u0652\u0670]');

/// Arabic-script block (includes ء-غ Persian/Urdu extras, harmless here).
final RegExp _arabicScript = RegExp(
  '[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF]',
);

/// Detects the reply language LLM-style: any Arabic-script word means the
/// user is speaking Arabic (Egyptian or otherwise) → answer in Egyptian
/// Arabic. Pure Latin (English or Arabizi) → answer in English.
bool prefersArabic(String text) => _arabicScript.hasMatch(text);

/// Splits normalized (or raw) text into meaningful tokens.
/// Keeps Arabic and Latin words; drops stopwords and 1-char tokens.
Set<String> tokenizeUnicode(String text, [Set<String> stopwords = const {}]) {
  return normalizeText(text)
      .split(' ')
      .where((token) => token.length > 1 && !stopwords.contains(token))
      .toSet();
}

/// Classic Levenshtein edit distance.
int levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  final aRunes = a.runes.toList();
  final bRunes = b.runes.toList();
  var prev = List<int>.generate(bRunes.length + 1, (i) => i);
  for (var i = 1; i <= aRunes.length; i++) {
    final curr = <int>[i];
    for (var j = 1; j <= bRunes.length; j++) {
      curr.add(
        _min3(
          prev[j] + 1,
          curr[j - 1] + 1,
          prev[j - 1] + (aRunes[i - 1] == bRunes[j - 1] ? 0 : 1),
        ),
      );
    }
    prev = curr;
  }
  return prev[bRunes.length];
}

int _min3(int a, int b, int c) => a < b ? (a < c ? a : c) : (b < c ? b : c);

/// 0.0 (totally different) .. 1.0 (identical), typo-tolerant.
double similarity(String a, String b) {
  final x = normalizeText(a);
  final y = normalizeText(b);
  if (x.isEmpty || y.isEmpty) return 0;
  final longest = x.length > y.length ? x.length : y.length;
  return 1 - levenshtein(x, y) / longest;
}

/// True when [token] is [candidate] up to small typos.
/// Short tokens/keywords require exact match (so "unknown" never matches
/// the keyword "no" just by containment); longer ones allow containment
/// ("coupons" matches "coupon") or 1-2 edits.
bool isFuzzyMatch(String token, String candidate) {
  final x = normalizeText(token);
  final y = normalizeText(candidate);
  if (x.isEmpty || y.isEmpty) return false;
  if (x == y) return true;
  if (x.length < 3 || y.length < 3) return false;
  if (x.contains(y) || y.contains(x)) return true;
  final longest = x.length > y.length ? x.length : y.length;
  if (longest < 4) return false;
  final allowed = longest <= 5 ? 1 : 2;
  return levenshtein(x, y) <= allowed;
}

/// Returns the closest entry of [candidates] to [token], or null when
/// nothing is close enough. Used to recover from misspellings.
String? closestMatch(String token, Iterable<String> candidates) {
  final x = normalizeText(token);
  if (x.isEmpty) return null;
  String? best;
  var bestScore = 0.0;
  for (final candidate in candidates) {
    final score = similarity(x, candidate);
    if (score > bestScore) {
      bestScore = score;
      best = candidate;
    }
  }
  if (best == null) return null;
  // Short words need near-exact match; longer words tolerate typos.
  final threshold = x.length <= 4 ? 0.8 : 0.7;
  return bestScore >= threshold ? best : null;
}
