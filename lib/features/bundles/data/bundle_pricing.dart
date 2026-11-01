import 'package:new_coffee/features/bundles/data/model/bundle_model.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';

/// Pure bundle arithmetic over explicitly supplied product rows.
///
/// The old helpers read the compiled menu themselves, which made every caller
/// depend on the same frozen catalogue. These take a product map instead, so
/// home, categories and details can all share one implementation while loading
/// their rows from the repository.
List<ProductModel> bundleProducts(
  BundleModel bundle,
  Map<String, ProductModel> productsById,
) => [
  for (final component in bundle.components)
    if (productsById[component.productId] != null)
      productsById[component.productId]!,
];

/// Sum of the bundle contents at their own prices, honoring quantities.
double bundleOriginalTotal(
  BundleModel bundle,
  Map<String, ProductModel> productsById,
) {
  var total = 0.0;
  for (final component in bundle.components) {
    final product = productsById[component.productId];
    if (product != null) total += product.price * component.quantity;
  }
  return total;
}

/// Never negative: a bundle can legitimately be priced above its contents.
double bundleSavings(
  BundleModel bundle,
  Map<String, ProductModel> productsById,
) {
  final saving = bundleOriginalTotal(bundle, productsById) - bundle.price;
  return saving > 0 ? saving : 0;
}

/// Whole percent the customer keeps, or zero when the bundle is not cheaper.
///
/// The home strip, the details page and the list tile all show this number, and
/// each used to redo the division in its own widget.
int bundleSavingPercent(
  BundleModel bundle,
  Map<String, ProductModel> productsById,
) {
  final original = bundleOriginalTotal(bundle, productsById);
  if (original <= bundle.price) return 0;
  return (((original - bundle.price) / original) * 100).round();
}

/// Splits the bundle price across its components proportionally to their
/// extended prices (rounded to cents, remainder fixed on the last item), so
/// cart lines always add up to exactly the bundle price.
///
/// Quantities participate: two of an item receive twice the share of one.
/// The old splitter ignored quantities entirely.
Map<String, double> bundleShares(
  BundleModel bundle,
  Map<String, ProductModel> productsById,
) {
  final products = bundleProducts(bundle, productsById);
  if (products.isEmpty) return const {};
  final quantities = {
    for (final component in bundle.components)
      component.productId: component.quantity,
  };
  final weights = <String, double>{
    for (final product in products)
      product.id: product.price * (quantities[product.id] ?? 1),
  };
  final totalWeight = weights.values.fold(0.0, (sum, value) => sum + value);

  final shares = <String, double>{};
  if (totalWeight <= 0) {
    final totalQuantity = quantities.values.fold(0, (sum, q) => sum + q);
    if (totalQuantity <= 0) return shares;
    var assigned = 0.0;
    for (var i = 0; i < products.length; i++) {
      final quantity = quantities[products[i].id] ?? 1;
      if (i == products.length - 1) {
        shares[products[i].id] = _cents(bundle.price - assigned);
      } else {
        final share = _cents(bundle.price * quantity / totalQuantity);
        shares[products[i].id] = share;
        assigned += share;
      }
    }
    return shares;
  }

  var assigned = 0.0;
  for (var i = 0; i < products.length; i++) {
    if (i == products.length - 1) {
      shares[products[i].id] = _cents(bundle.price - assigned);
    } else {
      final share = _cents(
        bundle.price * (weights[products[i].id] ?? 0) / totalWeight,
      );
      shares[products[i].id] = share;
      assigned += share;
    }
  }
  return shares;
}

double _cents(double value) => double.parse(value.toStringAsFixed(2));
