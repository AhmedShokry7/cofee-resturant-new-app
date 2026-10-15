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
    this.productSlug,
    this.aliases = const [],
    this.tags = const [],
  });

  /// Menu product id this row describes.
  final String productId;

  /// Stable product slug. Catalogue ids differ between the compiled mock and
  /// the database, so ingredient matching keys on the slug and keeps the id
  /// only for backward compatibility.
  final String? productSlug;

  /// Canonical ingredient ids (see [IngredientLexicon]).
  final List<String> ingredients;

  /// Extra names/spellings customers use for this product.
  final List<String> aliases;

  /// Mood tags: strong, sweet, cold, hot, cheap, creamy...
  final List<String> tags;

  Map<String, dynamic> toJson() => {
    'productId': productId,
    if (productSlug != null) 'productSlug': productSlug,
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
        productSlug: value['productSlug']?.toString(),
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

  static const Map<String, List<String>> _ingredientsByProductSlug = {
    'espresso': ['espresso'],
    'cappuccino': ['espresso', 'milk', 'foam'],
    'latte': ['espresso', 'milk'],
    'mocha': ['espresso', 'milk', 'chocolate', 'cream'],
    'americano': ['espresso', 'water'],
    'iced-latte': ['espresso', 'milk', 'ice'],
    'green-tea': ['tea', 'water'],
    'masala-tea': ['tea', 'milk', 'spices', 'ginger', 'cardamom', 'cinnamon'],
    'cheesecake': ['cheese', 'cream', 'biscuit', 'sugar', 'egg'],
    'chocolate-brownie': ['chocolate', 'cocoa', 'butter', 'egg', 'flour'],
    'chocolate-chip-cookie': ['chocolate', 'butter', 'flour', 'sugar', 'egg'],
    'butter-croissant': ['butter', 'flour', 'milk'],
    'chocolate-milkshake': ['milk', 'ice_cream', 'chocolate', 'cream'],
    'cola': ['soda', 'ice', 'sugar'],
    'butter-bread': ['flour', 'butter', 'milk', 'egg'],
    'glazed-donut': ['flour', 'sugar', 'glaze', 'egg'],
  };

  /// Legacy compiled-menu ids for the same slugs. Kept so rows serialized
  /// before the slug migration still resolve.
  static const Map<String, String> _legacyIdsByProductSlug = {
    'espresso': '1',
    'cappuccino': '2',
    'latte': '3',
    'mocha': '4',
    'americano': '5',
    'iced-latte': '6',
    'green-tea': '7',
    'masala-tea': '8',
    'cheesecake': '9',
    'chocolate-brownie': '10',
    'chocolate-chip-cookie': '11',
    'butter-croissant': '12',
    'chocolate-milkshake': '13',
    'cola': '14',
    'butter-bread': '15',
    'glazed-donut': '16',
  };

  @override
  Future<List<ProductKnowledge>> load() async {
    return [
      for (final entry in _ingredientsByProductSlug.entries)
        ProductKnowledge(
          productId: _legacyIdsByProductSlug[entry.key] ?? entry.key,
          productSlug: entry.key,
          ingredients: entry.value,
        ),
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
