/// Structured product knowledge: what each product is made of, in which
/// words customers describe it, and which tags it carries.
///
/// TODAY this is built from the local mock menu ([LocalProductKnowledgeRepository]).
/// TOMORROW (real database): implement [ProductKnowledgeRepository] with
/// Firestore/Supabase/REST — the engine only talks to the repository, so
/// nothing else changes. Rows serialize with [toJson]/[fromJson], so the
/// local table can also SEED the remote database.
class ProductKnowledge {
  const ProductKnowledge({
    required this.productId,
    required this.ingredients,
    this.aliases = const [],
    this.tags = const [],
  });

  /// Menu product id this row describes.
  final String productId;

  /// Canonical ingredient ids (see [IngredientLexicon]).
  final List<String> ingredients;

  /// Extra names/spellings customers use for this product.
  final List<String> aliases;

  /// Mood tags: strong, sweet, cold, hot, cheap, creamy...
  final List<String> tags;

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'ingredients': ingredients,
    'aliases': aliases,
    'tags': tags,
  };

  static ProductKnowledge? fromJson(dynamic value) {
    if (value is! Map) return null;
    try {
      final id = value['productId']?.toString();
      if (id == null || id.isEmpty) return null;
      List<String> strings(dynamic list) => list is List
          ? list.map((item) => item.toString()).toList()
          : const <String>[];
      return ProductKnowledge(
        productId: id,
        ingredients: strings(value['ingredients']),
        aliases: strings(value['aliases']),
        tags: strings(value['tags']),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Source of product-knowledge rows. Swap the implementation when the real
/// database arrives; the engine code stays untouched.
abstract class ProductKnowledgeRepository {
  Future<List<ProductKnowledge>> load();
}

/// Builds knowledge rows from the bundled menu + a static ingredient table.
/// Used until the backend exists (and its [toJson] can seed the backend).
class LocalProductKnowledgeRepository implements ProductKnowledgeRepository {
  const LocalProductKnowledgeRepository();

  static const Map<String, List<String>> _ingredientsByProductId = {
    '1': ['espresso'],
    '2': ['espresso', 'milk', 'foam'],
    '3': ['espresso', 'milk'],
    '4': ['espresso', 'milk', 'chocolate', 'cream'],
    '5': ['espresso', 'water'],
    '6': ['espresso', 'milk', 'ice'],
    '7': ['tea', 'water'],
    '8': ['tea', 'milk', 'spices', 'ginger', 'cardamom', 'cinnamon'],
    '9': ['cheese', 'cream', 'biscuit', 'sugar', 'egg'],
    '10': ['chocolate', 'cocoa', 'butter', 'egg', 'flour'],
    '11': ['chocolate', 'butter', 'flour', 'sugar', 'egg'],
    '12': ['butter', 'flour', 'milk'],
    '13': ['milk', 'ice_cream', 'chocolate', 'cream'],
    '14': ['soda', 'ice', 'sugar'],
    '15': ['flour', 'butter', 'milk', 'egg'],
    '16': ['flour', 'sugar', 'glaze', 'egg'],
  };

  @override
  Future<List<ProductKnowledge>> load() async {
    return [
      for (final entry in _ingredientsByProductId.entries)
        ProductKnowledge(productId: entry.key, ingredients: entry.value),
    ];
  }
}

/// Every way customers name an ingredient (dialects + misspellings),
/// mapped to one canonical id. Matching normalizes text first.
class IngredientLexicon {
  const IngredientLexicon._();

  static const Map<String, String> words = {
    // chocolate family
    'شوكولاته': 'chocolate', 'شيكولاته': 'chocolate', 'شوكولا': 'chocolate',
    'شوكليت': 'chocolate', 'كاكاو': 'chocolate', 'شوكو': 'chocolate',
    'chocolate': 'chocolate', 'choco': 'chocolate', 'cocoa': 'cocoa',
    // cream family
    'كريمه': 'cream', 'كريمة': 'cream', 'كريم': 'cream', 'قشطه': 'cream',
    'قشطة': 'cream', 'ويب كريم': 'cream', 'cream': 'cream',
    'whipped cream': 'cream',
    // milk family
    'حليب': 'milk', 'لبن': 'milk', 'milk': 'milk',
    // ice family
    'تلج': 'ice', 'ثلج': 'ice', 'ايس': 'ice', 'ice': 'ice',
    'ايس كريم': 'ice_cream',
    // coffee family
    'بن': 'espresso', 'قهوه': 'espresso', 'اسبريسو': 'espresso',
    'espresso': 'espresso', 'نسكافيه': 'espresso',
    // water
    'ميه': 'water', 'مياه': 'water', 'ماء': 'water', 'water': 'water',
    // foam
    'رغوه': 'foam', 'فوم': 'foam', 'foam': 'foam',
    // tea family
    'شاي': 'tea', 'تشاي': 'tea', 'tea': 'tea',
    'زنجبيل': 'ginger', 'جنزبيل': 'ginger', 'ginger': 'ginger',
    'هيل': 'cardamom', 'حبهان': 'cardamom', 'cardamom': 'cardamom',
    'بهارات': 'spices', 'توابل': 'spices', 'spices': 'spices',
    'قرفه': 'cinnamon', 'cinnamon': 'cinnamon',
    // dessert building blocks
    'جبنه': 'cheese', 'جبن': 'cheese', 'cheese': 'cheese',
    'بسكوت': 'biscuit', 'biscuit': 'biscuit',
    'سكر': 'sugar', 'sugar': 'sugar',
    'بيض': 'egg', 'egg': 'egg',
    'دقيق': 'flour', 'flour': 'flour',
    'زبده': 'butter', 'butter': 'butter',
    'فانيليا': 'vanilla', 'vanilla': 'vanilla',
    'كراميل': 'caramel', 'caramel': 'caramel',
    'فراوله': 'strawberry', 'فراولة': 'strawberry', 'strawberry': 'strawberry',
    'موز': 'banana', 'banana': 'banana',
    'مانجو': 'mango', 'مانجا': 'mango', 'mango': 'mango',
    'جليز': 'glaze', 'glaze': 'glaze',
    'صودا': 'soda', 'soda': 'soda',
  };
}
