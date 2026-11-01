import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/features/bundles/data/bundle_pricing.dart';
import 'package:new_coffee/features/bundles/data/model/bundle_model.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';

ProductModel _product(String id, double price) => ProductModel(
  id: id,
  name: id,
  price: price,
  image: 'assets/images/product.png',
);

void main() {
  test('bundle math honors quantities and always balances', () {
    const bundle = BundleModel(
      id: 'bundle-1',
      productIds: ['a', 'b'],
      price: 100,
      components: [
        BundleComponent(productId: 'a', quantity: 2),
        BundleComponent(productId: 'b', quantity: 1),
      ],
    );
    final products = {'a': _product('a', 30), 'b': _product('b', 50)};

    expect(bundleOriginalTotal(bundle, products), 110);
    expect(bundleSavings(bundle, products), 10);

    final shares = bundleShares(bundle, products);
    expect(shares.values.fold(0.0, (sum, value) => sum + value), 100);
    // Two $30 items weigh 60 against one $50 item, so their combined share is
    // 20% larger.
    expect(shares['a']! / shares['b']!, closeTo(1.2, 0.01));
  });

  test('a bundle priced above its contents never reports savings', () {
    const bundle = BundleModel(
      id: 'bundle-2',
      productIds: ['a'],
      price: 120,
      components: [BundleComponent(productId: 'a', quantity: 1)],
    );
    final products = {'a': _product('a', 100)};

    expect(bundleOriginalTotal(bundle, products), 100);
    expect(bundleSavings(bundle, products), 0);
    expect(bundleShares(bundle, products), {'a': 120});
  });

  test('missing catalogue rows do not invent prices', () {
    const bundle = BundleModel(
      id: 'bundle-3',
      productIds: ['missing'],
      price: 42,
      components: [BundleComponent(productId: 'missing', quantity: 1)],
    );

    expect(bundleProducts(bundle, const {}), isEmpty);
    expect(bundleOriginalTotal(bundle, const {}), 0);
    expect(bundleShares(bundle, const {}), isEmpty);
  });
}
