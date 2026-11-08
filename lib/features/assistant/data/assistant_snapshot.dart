import 'dart:async';

import 'package:new_coffee/features/assistant/data/assistant_actions.dart';
import 'package:new_coffee/features/assistant/data/assistant_order.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';
import 'package:new_coffee/features/orders/data/model/order_item_model.dart';

/// Whether a snapshot data source was read successfully.
///
/// A failed read must not be reported as "the shop has nothing": the model
/// would tell a customer with orders that they have none, or deny a menu that
/// simply could not be loaded.
enum DataState { unknown, loaded, failed }

/// Repository-backed data available to the assistant's synchronous engine.
///
/// The engine makes dozens of small catalogue lookups while answering. Passing
/// one snapshot through every helper signature would obscure the actual logic,
/// so the snapshot is installed in a [Zone] at the public entry points. All
/// deeper helpers read [AssistantSnapshot.current]. Zones nest safely, and a
/// missing snapshot yields an explicitly empty catalogue rather than a global
/// constant list.
class AssistantSnapshot {
  const AssistantSnapshot({
    required this.products,
    this.orders = const [],
    this.optionsByProductId = const {},
    this.productsState = DataState.loaded,
    this.ordersState = DataState.loaded,
  });

  const AssistantSnapshot.empty()
    : products = const [],
      orders = const [],
      optionsByProductId = const {},
      productsState = DataState.unknown,
      ordersState = DataState.unknown;

  final List<ProductModel> products;
  final List<OrderItemModel> orders;
  final Map<String, List<OptionGroup>> optionsByProductId;

  /// Whether the catalogue and the order history were actually read. A failed
  /// read leaves an empty list but [DataState.failed], so callers can tell
  /// "nothing there" apart from "could not look".
  final DataState productsState;
  final DataState ordersState;

  static const _zoneKey = #assistantSnapshot;

  static AssistantSnapshot get current =>
      Zone.current[_zoneKey] as AssistantSnapshot? ??
      const AssistantSnapshot.empty();

  static T run<T>(AssistantSnapshot snapshot, T Function() body) =>
      runZoned(body, zoneValues: {_zoneKey: snapshot});

  /// Loads enough catalogue context for one chat session.
  ///
  /// The products and the option groups are read side by side: neither needs
  /// the other, and asking for the groups for the whole menu lets the two
  /// requests travel together instead of one after the other. Reading the
  /// groups product by product cost about six queries per product, which was
  /// most of the time the assistant took to open.
  ///
  /// Order history is best-effort: guests have none, and a failed history read
  /// must not silence the assistant.
  static Future<AssistantSnapshot> load({
    required CatalogRepository catalog,
    required Future<List<OrderItemModel>> Function() activeOrders,
    String? branchId,
    int productLimit = 200,
  }) async {
    // An empty list asks for every product, so this read can start before the
    // product query has answered. Each concurrent read gets its error handler
    // attached right away: a future that fails while we await the products
    // would otherwise surface as an unhandled async error.
    final optionsFuture = catalog
        .getOptionsByProduct(const [])
        .then<Map<String, List<OptionGroup>>>(
          (groups) => groups,
          // A product without its option groups still belongs in the catalogue.
          onError: (_) => const <String, List<OptionGroup>>{},
        );
    final ordersFuture = activeOrders().then(
      (orders) => (orders: orders, failed: false),
      // A failed history read is not "the customer has no orders": keep the
      // list empty but mark it failed so the answer does not assert a fact.
      onError: (_) => (orders: const <OrderItemModel>[], failed: true),
    );
    final productsFuture = catalog.getProducts(
      branchId: branchId,
      limit: productLimit,
    );

    final products = await productsFuture;
    final optionsByProduct = await optionsFuture;
    final ordersResult = await ordersFuture;

    return AssistantSnapshot(
      products: products,
      orders: ordersResult.orders,
      optionsByProductId: optionsByProduct,
      ordersState: ordersResult.failed ? DataState.failed : DataState.loaded,
    );
  }

  Map<String, ProductModel> get productsById => {
    for (final product in products) product.id: product,
  };

  ProductModel? productById(String id) => productsById[id];

  /// Canonical product name for matching and assistant replies. Prefer the
  /// exact English catalogue name so Arabic sentences do not transliterate a
  /// branded/menu name; fall back only when the catalogue has no English name.
  static String canonicalName(ProductModel product) {
    final nameEn = product.nameEn?.trim();
    if (nameEn != null && nameEn.isNotEmpty) return nameEn;
    return product.name;
  }

  /// Restores the exact English menu spelling when a model transliterates a
  /// product name inside an otherwise Arabic reply.
  static String preserveEnglishProductNames(
    String text,
    Iterable<ProductModel> products,
  ) {
    final aliases = <({String alias, String canonical})>[];
    for (final product in products) {
      final canonical = canonicalName(product).trim();
      if (canonical.isEmpty || !RegExp(r'[A-Za-z]').hasMatch(canonical)) {
        continue;
      }
      final candidates = <String>{
        product.nameAr?.trim() ?? '',
        product.name.trim(),
      }..removeWhere((name) => name.isEmpty || name == canonical);
      for (final alias in candidates) {
        aliases.add((alias: alias, canonical: canonical));
      }
    }
    aliases.sort((a, b) => b.alias.length.compareTo(a.alias.length));
    var result = text;
    for (final entry in aliases) {
      final prefixedPattern = RegExp(
        '([لبوفك])${RegExp.escape(entry.alias)}(?![\\p{L}\\p{N}])',
        unicode: true,
        caseSensitive: false,
      );
      result = result.replaceAllMapped(
        prefixedPattern,
        (match) => '${match.group(1)}ـ${entry.canonical}',
      );
      final pattern = RegExp(
        '(?<![\\p{L}\\p{N}])${RegExp.escape(entry.alias)}(?![\\p{L}\\p{N}])',
        unicode: true,
        caseSensitive: false,
      );
      result = result.replaceAll(pattern, entry.canonical);
    }
    return result;
  }

  /// Stable category key used for scoring and pairing rules.
  static String categoryKey(ProductModel product) {
    final slug = product.categorySlug.trim();
    if (slug.isNotEmpty) return slug;
    return product.category;
  }

  /// Learned score for this product's category, tolerant of rows learned
  /// before categories migrated from display names to slugs.
  static double categoryScore(
    Map<String, double> scores,
    ProductModel product,
  ) {
    final slug = product.categorySlug.trim();
    if (slug.isNotEmpty && scores.containsKey(slug)) {
      return scores[slug] ?? 0;
    }
    return scores[product.category] ?? 0;
  }

  List<OptionGroup> optionsFor(String productId) =>
      optionsByProductId[productId] ?? const [];

  /// Option ids matching an assistant-parsed size/sugar pair.
  ///
  /// Size and sugar words are already canonical codes (`small`, `less`), which
  /// intentionally match the database `option_values.code` values. Anything
  /// the product does not offer is ignored rather than invented.
  List<String> optionIdsFor(OrderDraftItem item) {
    final groups = optionsFor(item.productId);
    final ids = <String>[];
    if (item.size != null) {
      final id = _valueId(groups, 'size', item.size!);
      if (id != null) ids.add(id);
    }
    if (item.sugar != null) {
      final id = _valueId(groups, 'sugar', item.sugar!);
      if (id != null) ids.add(id);
    }
    return ids;
  }

  double estimatedUnitPriceFor(OrderDraftItem item) {
    final product = productById(item.productId);
    if (product == null) return 0;
    final groups = optionsFor(item.productId);
    final ids = optionIdsFor(item).toSet();
    var delta = 0.0;
    for (final group in groups) {
      for (final value in group.values) {
        if (ids.contains(value.id)) delta += value.priceDelta;
      }
    }
    return product.price + delta;
  }

  /// One cart tool call for an assistant draft line.
  ///
  /// The estimated price stays null when no size was requested, preserving the
  /// old base-price behaviour. Option ids are always included so the cart does
  /// not have to recover structured choices from display text.
  CartAction cartActionFor(
    OrderDraftItem item, {
    required bool arabic,
    String? approvedBy,
  }) => CartAction(
    productId: item.productId,
    quantity: item.quantity,
    note: variantNoteFor(item, arabic: arabic),
    optionValueIds: optionIdsFor(item),
    unitPrice: item.size == null ? null : estimatedUnitPriceFor(item),
    approvedBy: approvedBy,
  );

  String variantNoteFor(OrderDraftItem item, {required bool arabic}) {
    final groups = optionsFor(item.productId);
    final ids = optionIdsFor(item).toSet();
    final labels = <String>[];
    for (final group in groups) {
      for (final value in group.values) {
        if (!ids.contains(value.id)) continue;
        final label = arabic ? value.nameAr : value.nameEn;
        labels.add(label.isNotEmpty ? label : value.code);
      }
    }
    if (labels.isNotEmpty) return labels.join(arabic ? '، ' : ', ');
    // The product offers no matching configured option. Fall back to the
    // parsed words so the confirmation still says what the customer asked for.
    return item.variantNote(arabic: arabic);
  }

  static String? _valueId(
    List<OptionGroup> groups,
    String groupCode,
    String valueCode,
  ) {
    for (final group in groups) {
      if (group.code != groupCode) continue;
      for (final value in group.values) {
        if (value.code == valueCode) return value.id;
      }
    }
    return null;
  }
}
