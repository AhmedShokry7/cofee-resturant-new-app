import 'package:new_coffee/features/assistant/data/assistant_language.dart';
import 'package:new_coffee/features/assistant/data/assistant_phrases.dart';
import 'package:new_coffee/features/assistant/data/assistant_server_memory.dart';

/// One thing the assistant is allowed to remember from what the customer said.
class ExtractedMemory {
  const ExtractedMemory({
    required this.kind,
    required this.key,
    required this.value,
    required this.confidence,
    this.isSecret = false,
  });

  final AssistantMemoryKind kind;

  /// The dedupe key the server supersedes on, e.g. `prefers:latte`,
  /// `allergy:milk`, `name:first`.
  final String key;
  final String value;

  /// How sure the assistant may be. A sentence the customer typed is not the
  /// same as a guess inferred from three orders, and the number has to travel
  /// with the memory so a guess is never served as a fact.
  final double confidence;

  /// Health, allergy and identity details: stored encrypted, never returned as
  /// text, never reused across customers.
  final bool isSecret;
}

/// Turns a customer's own words into memories worth keeping.
///
/// Most sentences must produce nothing. A chat is full of "اه", "تمام" and
/// half-formed orders; storing those would fill the memory with noise and turn
/// "continuous learning" into "continuous guessing". So this file is mostly
/// rules about what is *not* memory, and the few shapes that are.
///
/// The four kinds are decided here and nowhere else, because the whole point of
/// the distinction is that the answer path cannot afford to re-guess it.
class AssistantMemoryExtractor {
  const AssistantMemoryExtractor._();

  /// Every phrase is matched against text that already went through
  /// [normalizeText], so a pattern written with أ or ة or ال can never match
  /// (أحلى becomes احلي, الطعم loses its article). Normalising the phrases
  /// themselves is the only way the rules cannot drift from the text again.
  ///
  /// [words] is for Latin phrases, which need their boundaries: "i like" must
  /// not fire inside "dislike".
  static RegExp _anyOf({
    List<String> contains = const [],
    List<String> words = const [],
  }) => RegExp(
    [
      for (final phrase in contains) RegExp.escape(normalizeText(phrase)),
      for (final phrase in words)
        '\\b${RegExp.escape(normalizeText(phrase))}\\b',
    ].join('|'),
    caseSensitive: false,
  );

  static final _preference = _anyOf(
    contains: [
      'بحب',
      'بحب جدا',
      'عشان بحب',
      'بعشق',
      'أفضل',
      'فضّل',
      'بموت على',
      'أحب',
    ],
    words: [
      'i love',
      'i like',
      'i prefer',
      'my favourite',
      'my favorite',
      'i am partial to',
      "i'm partial to",
    ],
  );

  static final _rejection = _anyOf(
    contains: ['مش بحب', 'ما بحبش', 'لا أحب', 'أكره', 'متكرش', 'بكره'],
    words: [
      'i hate',
      'i do not like',
      "i don't like",
      'i am not into',
      'never order',
      'never drink',
    ],
  );

  static final _opinion = _anyOf(
    contains: [
      'أحلى',
      'أحسن',
      'الطعم',
      'عجبتني',
      'ما عجبتني',
      'مش حلوة',
      'مظبوط',
      'مبسوط',
    ],
    words: [
      'the best',
      'is great',
      'was good',
      'was bad',
      'tastes',
      'not impressed',
    ],
  );

  /// Allergies and health are facts about a body, so they are stored encrypted.
  static final _allergy = _anyOf(
    contains: ['حساسية', 'عندي حساسية', 'ما كليش', 'مشاكل كلي', 'بطنى', 'معدة'],
    words: [
      'allergic',
      'allergy',
      'intolerant',
      'intolerance',
      'gluten',
      'lactose',
      'celiac',
      'upset stomach',
      'reflux',
    ],
  );

  static final _routine = _anyOf(
    contains: [
      'كل يوم',
      'كل صباح',
      'كل ما',
      'عادة',
      'المعتاد',
      'دايما',
      'روتين',
    ],
    words: [
      'every day',
      'every morning',
      'usually',
      'normally',
      'my routine',
      'always order',
    ],
  );

  static final _name = _anyOf(
    contains: ['اسمي', 'انا اسمي'],
    words: ['my name is', 'i am called'],
  );

  /// The words that mean "what I just said was wrong" — the signal the
  /// assistant learns from most.
  static final _correction = _anyOf(
    contains: ['غلط', 'مش كده', 'مش صح', 'أقصد', 'بالظبط مش', 'لا مش'],
    words: ['that is wrong', 'i meant', 'correction'],
  );

  /// The connectives that make a product name worth cutting out of a sentence.
  static const _stopwords = {
    'عايز',
    'عوز',
    'عاوز',
    'ابغى',
    'أبغى',
    'بدي',
    'ابي',
    'أبي',
    'لي',
    'الي',
    'و',
    'في',
    'من',
    'على',
    'ان',
    'إن',
    'اي',
    'ايه',
    'إيه',
    'هو',
    'هي',
    'مع',
    'حاجة',
    'شي',
    'نوع',
    'كافيه',
    'قهوة',
    'مشروب',
    'الطلب',
    'طلبات',
    'i',
    'a',
    'an',
    'the',
    'and',
    'or',
    'with',
    'for',
    'me',
    'my',
    'to',
    'of',
    'some',
    'can',
    'you',
    'have',
    'please',
    'like',
    'love',
    'prefer',
    'order',
    'drink',
    'coffee',
    'one',
    'want',
    'would',
    'could',
    'very',
  };

  /// Memories worth writing for this sentence, possibly none.
  ///
  /// [products] is the menu vocabulary the assistant already has; a preference
  /// is only recorded when it names something real, otherwise "بحب" would be
  /// stored against the whole sentence.
  static List<ExtractedMemory> extract(
    String text, {
    required List<String> products,
  }) {
    final clean = normalizeText(text);
    if (clean.length < 4) return const [];

    final out = <ExtractedMemory>[];

    // 1. A stated allergy outranks everything else in the sentence.
    if (_allergy.hasMatch(clean)) {
      final named = _matchingProducts(clean, products);
      out.add(
        ExtractedMemory(
          kind: AssistantMemoryKind.fact,
          key: named.isEmpty
              ? 'health:allergy'
              : 'allergy:${named.first.toLowerCase()}',
          value: text.trim(),
          confidence: 0.95,
          isSecret: true,
        ),
      );
      return out;
    }

    // 2. A name is a fact with a fixed key, so a rename supersedes it.
    final nameMatch = _name.firstMatch(clean);
    if (nameMatch != null) {
      final given = _afterKeyword(text, nameMatch);
      if (given != null && given.split(' ').length <= 3) {
        out.add(
          ExtractedMemory(
            kind: AssistantMemoryKind.fact,
            key: 'name:first',
            value: given,
            confidence: 0.95,
          ),
        );
      }
    }

    // 3. Taste: preference or rejection, but only about a product that exists.
    final rejecting = _rejection.hasMatch(clean);
    final liking = !rejecting && _preference.hasMatch(clean);
    if (rejecting || liking) {
      for (final product in _matchingProducts(clean, products)) {
        final slug = product.toLowerCase();
        out.add(
          ExtractedMemory(
            // "X أحلى من Y" is a judgement about the menu, not a fact about it.
            kind: _opinion.hasMatch(clean)
                ? AssistantMemoryKind.opinion
                : AssistantMemoryKind.preference,
            key: rejecting ? 'dislikes:$slug' : 'prefers:$slug',
            value: text.trim(),
            confidence: 0.8,
          ),
        );
      }
    }

    // 4. A routine is a habit the customer told us, which is weaker than a
    //    direct preference and is stored as such.
    if (out.isEmpty && _routine.hasMatch(clean)) {
      final named = _matchingProducts(clean, products);
      out.add(
        ExtractedMemory(
          kind: named.isEmpty
              ? AssistantMemoryKind.assumption
              : AssistantMemoryKind.preference,
          key: named.isEmpty
              ? 'routine:general'
              : 'prefers:${named.first.toLowerCase()}',
          value: text.trim(),
          confidence: named.isEmpty ? 0.4 : 0.7,
        ),
      );
    }

    // 5. A correction with no product named is still worth keeping: it is the
    //    assistant being told its last answer was wrong.
    if (out.isEmpty && _correction.hasMatch(clean)) {
      out.add(
        ExtractedMemory(
          kind: AssistantMemoryKind.assumption,
          key: 'correction:${clean.hashCode}',
          value: text.trim(),
          confidence: 0.5,
        ),
      );
    }

    // Arabic keywords are matched with the app's own normaliser, so a preference
    // written with tatweel or an alef variant still lands on the same key.
    return List<ExtractedMemory>.unmodifiable(out);
  }

  /// The menu items named inside the sentence.
  ///
  /// Two vocabularies are consulted. The names the catalogue carries, and the
  /// dialect words the rest of the assistant already maps onto those names
  /// ([AssistantPhrases.productSynonyms]). Without the second one, an
  /// Arabic-speaking customer who says "انا بحب اللاتيه" to an English-named
  /// menu is remembered as nothing — which is exactly the memory the customer
  /// asked for.
  ///
  /// The longest phrase is served first and consumes the words it matched, so
  /// "ايس لاتيه" is Iced Latte and does not also file a preference for Latte.
  /// That is the rule [AssistantEngine] already uses for recommendations; a
  /// memory that disagreed with the answer would be worse than no memory.
  static List<String> _matchingProducts(
    String normalized,
    List<String> products,
  ) {
    // Keyed by the words that make the match, so two dialect spellings that
    // normalise to the same words file one memory, not two.
    final candidates = <String, ({List<String> words, String name})>{};
    void add(List<String> words, String name) {
      if (words.isEmpty) return;
      candidates.putIfAbsent(words.join(' '), () => (words: words, name: name));
    }

    for (final name in products) {
      add(_contentWords(name), name);
    }
    for (final entry in AssistantPhrases.productSynonyms.entries) {
      final target = normalizeText(entry.value);
      for (final name in products) {
        if (normalizeText(name) != target) continue;
        add(_contentWords(entry.key), name);
      }
    }

    final ordered = candidates.values.toList()
      ..sort((a, b) {
        final byLength = b.words
            .join(' ')
            .length
            .compareTo(a.words.join(' ').length);
        return byLength != 0
            ? byLength
            : a.words.join(' ').compareTo(b.words.join(' '));
      });

    final claimed = <({int start, int end})>[];
    final found = <String>[];

    int? firstFree(String needle) {
      var index = normalized.indexOf(needle);
      while (index >= 0) {
        final isFree = !claimed.any(
          (span) => span.start < index + needle.length && index < span.end,
        );
        if (isFree) return index;
        index = normalized.indexOf(needle, index + 1);
      }
      return null;
    }

    for (final candidate in ordered) {
      final spans = <({int start, int end})>[];
      for (final word in candidate.words) {
        final at = firstFree(word);
        if (at == null) {
          spans.clear();
          break;
        }
        spans.add((start: at, end: at + word.length));
      }
      if (spans.isEmpty) continue;
      // The match is real: nothing shorter may read these letters again.
      claimed.addAll(spans);
      found.add(candidate.name.trim());
    }
    return found;
  }

  /// The words of a name that carry meaning: short enough to be a word, long
  /// enough to be a noun, and not one of the connectives that sit around it.
  static List<String> _contentWords(String name) =>
      normalizeText(name)
          .split(' ')
          .where((word) => word.length > 2 && !_stopwords.contains(word))
          .toList();

  /// The word right after "اسمي" / "my name is", as the customer typed it.
  ///
  /// The position comes from the normalised sentence, so the raw text is
  /// counted in whole words rather than in characters — أ and ا are the same
  /// word but not the same length.
  static String? _afterKeyword(String text, RegExpMatch match) {
    final before = normalizeText(text).substring(0, match.end);
    final skipped = before.split(' ').where((word) => word.isNotEmpty).length;
    final words = text
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (skipped >= words.length) return null;
    final given = words[skipped].replaceAll(
      RegExp(r'[^\p{L}\p{N}]+', unicode: true),
      '',
    );
    return given.isEmpty ? null : given;
  }

  /// The recalled memories, rendered for the language model's prompt.
  ///
  /// Each line is tagged with its kind so the model can tell a customer's
  /// stated fact from an assumption the bot made, and is told to ask rather
  /// than act on the weak ones.
  static String toPromptContext(List<AssistantMemoryItem> items) {
    if (items.isEmpty) return '';
    final buffer = StringBuffer(
      'What this customer has told us (newest first):\n',
    );
    for (final item in items) {
      final label = switch (item.kind) {
        AssistantMemoryKind.fact => 'fact',
        AssistantMemoryKind.preference => 'preference',
        AssistantMemoryKind.opinion => 'opinion',
        AssistantMemoryKind.assumption => 'assumption',
      };
      final value = item.isReadable ? item.value : '(kept private)';
      final caution = item.kind == AssistantMemoryKind.assumption
          ? ' — unconfirmed, ask rather than assume'
          : '';
      buffer.writeln('- [$label] ${item.key}: $value$caution');
    }
    return buffer.toString();
  }
}
