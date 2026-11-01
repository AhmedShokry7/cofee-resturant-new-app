import 'dart:async';

import 'package:new_coffee/features/assistant/data/assistant_actions.dart';
import 'package:new_coffee/features/assistant/data/assistant_order.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';
import 'package:new_coffee/features/orders/data/model/order_item_model.dart';

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
  });

  const AssistantSnapshot.empty()
    : products = const [],
      orders = const [],
      optionsByProductId = const {};

  final List<ProductModel> products;
  final List<OrderItemModel> orders;
  final Map<String, List<OptionGroup>> optionsByProductId;

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
    // product query has answered.
    final optionsFuture = catalog.getOptionsByProduct(const []);
    final ordersFuture = activeOrders();
    final productsFuture = catalog.getProducts(
      branchId: branchId,
      limit: productLimit,
    );

    final products = await productsFuture;

    Map<String, List<OptionGroup>> optionsByProduct = const {};
    try {
      optionsByProduct = await optionsFuture;
    } catch (_) {
      // A product without its option groups still belongs in the catalogue.
      optionsByProduct = const {};
    }
    List<OrderItemModel> orders = const [];
    try {
      orders = await ordersFuture;
    } catch (_) {
      orders = const [];
    }
    return AssistantSnapshot(
      products: products,
      orders: orders,
      optionsByProductId: optionsByProduct,
    );
  }

  Map<String, ProductModel> get productsById => {
    for (final product in products) product.id: product,
  };

  ProductModel? productById(String id) => productsById[id];

  /// Canonical English name used for synonym matching. Display text stays
  /// locale-aware elsewhere.
  static String canonicalName(ProductModel product) {
    final nameEn = product.nameEn?.trim();
    if (nameEn != null && nameEn.isNotEmpty) return nameEn;
    return product.name;
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
  CartAction cartActionFor(OrderDraftItem item, {required bool arabic}) =>
      CartAction(
        productId: item.productId,
        quantity: item.quantity,
        note: variantNoteFor(item, arabic: arabic),
        optionValueIds: optionIdsFor(item),
        unitPrice: item.size == null ? null : estimatedUnitPriceFor(item),
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
