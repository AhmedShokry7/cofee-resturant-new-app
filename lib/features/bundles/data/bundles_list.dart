import 'package:new_coffee/features/bundles/data/model/bundle_model.dart';
import 'package:new_coffee/features/menu/data/menu_list.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';

List<BundleModel> getBundlesList() {
  return const [
    BundleModel(
      id: 'morning-duo',
      title: 'Morning Duo',
      subtitle: 'Espresso + Butter Croissant',
      productIds: ['1', '12'],
      price: 48,
    ),
    BundleModel(
      id: 'sweet-break',
      title: 'Sweet Break',
      subtitle: 'Latte + Cheesecake',
      productIds: ['3', '9'],
      price: 79,
    ),
    BundleModel(
      id: 'iced-refresh',
      title: 'Iced Refresh',
      subtitle: 'Iced Latte + Glazed Donut',
      price: 56,
      productIds: ['6', '16'],
    ),
    BundleModel(
      id: 'tea-time',
      title: 'Tea Time',
      subtitle: 'Green Tea + Butter Bread',
      productIds: ['7', '15'],
      price: 42,
    ),
  ];
}

/// Products inside a bundle, resolved from the menu.
List<ProductModel> bundleProducts(BundleModel bundle) {
  final menu = getMenuList();
  return [
    for (final id in bundle.productIds)
      for (final product in menu)
        if (product.id == id) product,
  ];
}

/// Sum of the items at menu prices (before the bundle discount).
double bundleOriginalTotal(BundleModel bundle) {
  return bundleProducts(
    bundle,
  ).fold(0, (sum, product) => sum + product.price);
}

double bundleSavings(BundleModel bundle) =>
    bundleOriginalTotal(bundle) - bundle.price;

/// Splits the bundle price across its items proportionally to their menu
/// prices (rounded to cents, remainder fixed on the last item), so cart
/// lines always add up to exactly the bundle price.
Map<String, double> bundleShares(BundleModel bundle) {
  final products = bundleProducts(bundle);
  final shares = <String, double>{};
  if (products.isEmpty) return shares;
  final original = bundleOriginalTotal(bundle);
  if (original <= 0) {
    final even =
        double.parse((bundle.price / products.length).toStringAsFixed(2));
    for (final product in products) {
      shares[product.id] = even;
    }
    return shares;
  }
  var assigned = 0.0;
  for (var i = 0; i < products.length; i++) {
    if (i == products.length - 1) {
      shares[products[i].id] = double.parse(
        (bundle.price - assigned).toStringAsFixed(2),
      );
    } else {
      final share = double.parse(
        (bundle.price * products[i].price / original).toStringAsFixed(2),
      );
      shares[products[i].id] = share;
      assigned += share;
    }
  }
  return shares;
}
