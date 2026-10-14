import 'package:new_coffee/features/assistant/data/assistant_language.dart';
import 'package:new_coffee/features/assistant/data/product_knowledge.dart';
import 'package:new_coffee/features/menu/data/menu_list.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';

/// The bot's internal product brain: names, aliases, ingredients and tags.
///
/// Built once from a [ProductKnowledgeRepository] (local mock today, real
/// database tomorrow) and cached. The engine asks it:
/// - which products contain these ingredients?
/// - what is this product made of?
class AssistantCatalog {
  AssistantCatalog._(this._knowledge);

  final List<ProductKnowledge> _knowledge;

  static AssistantCatalog? _current;

  /// Cached catalog (empty until [load] runs once).
  static AssistantCatalog get current => _current ?? AssistantCatalog._(const []);

  /// Loads (or reloads) knowledge, e.g. after the database connects.
  /// Safe to call repeatedly; failures keep the previous catalog.
  static Future<void> load({
    ProductKnowledgeRepository repository =
        const LocalProductKnowledgeRepository(),
  }) async {
    try {
      _current = AssistantCatalog._(await repository.load());
    } catch (_) {
      _current ??= AssistantCatalog._(const []);
    }
  }

  List<ProductKnowledge> get rows => List.unmodifiable(_knowledge);

  ProductKnowledge? knowledgeOf(String productId) {
    for (final row in _knowledge) {
      if (row.productId == productId) return row;
    }
    return null;
  }

  /// Ingredient ids mentioned anywhere in [query] (whole words).
  Set<String> detectIngredients(String query) {
    final normalized = normalizeText(query);
    if (normalized.isEmpty) return {};
    final found = <String>{};
    for (final entry in IngredientLexicon.words.entries) {
      final word = normalizeText(entry.key);
      if (word.length < 3) continue;
      var index = normalized.indexOf(word);
      while (index >= 0) {
        if (_wholeWord(normalized, index, word.length)) {
          found.add(entry.value);
          break;
        }
        index = normalized.indexOf(word, index + 1);
      }
    }
    return found;
  }

  /// Products ranked by ingredient overlap: full matches first, then
  /// partial, preferring precise (few-ingredient) products on ties.
  /// Products in [excludeIds] (e.g. rejected) are skipped.
  List<ProductModel> matchByIngredients(
    Set<String> ingredients, {
    Set<String> excludeIds = const {},
    int limit = 3,
  }) {
    if (ingredients.isEmpty) return const [];
    final menu = getMenuList();
    final scored = <MapEntry<ProductModel, double>>[];
    for (final product in menu) {
      if (excludeIds.contains(product.id)) continue;
      final row = knowledgeOf(product.id);
      if (row == null || row.ingredients.isEmpty) continue;
      final matched = ingredients
          .where((ingredient) => row.ingredients.contains(ingredient))
          .length;
      if (matched == 0) continue;
      // Full coverage wins; fewer total ingredients = more precise pick.
      final coverage = matched / ingredients.length;
      final precision = matched / row.ingredients.length;
      scored.add(MapEntry(product, coverage * 2 + precision));
    }
    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(limit).map((entry) => entry.key).toList();
  }

  /// Human-readable ingredient list for confirmations ("cocoa, butter...").
  String describeIngredients(String productId) {
    final row = knowledgeOf(productId);
    if (row == null) return '';
    return row.ingredients.join(', ');
  }

  /// DB-ready export (seed a remote database from the local table).
  List<Map<String, dynamic>> exportJson() =>
      _knowledge.map((row) => row.toJson()).toList();

  static bool _wholeWord(String text, int index, int length) {
    final beforeOk = index == 0 || text[index - 1] == ' ';
    final end = index + length;
    final afterOk = end >= text.length || text[end] == ' ';
    return beforeOk && afterOk;
  }
}
