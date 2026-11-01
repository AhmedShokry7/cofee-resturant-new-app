import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/features/bundles/data/model/bundle_model.dart';
import 'package:new_coffee/features/home/data/model/banner_model.dart';
import 'package:new_coffee/features/home/presentation/manager/home/home_cubit.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/weather/data/model/weather_model.dart';

/// The two rules the home screen used to run inside its widgets: which rows a
/// banner points at, and how the recommendations strip is ordered.
void main() {
  ProductModel product(
    String id, {
    String categorySlug = '',
    String? categoryId,
  }) => ProductModel(
    id: id,
    name: 'P$id',
    price: 10,
    image: '',
    categorySlug: categorySlug,
    categoryId: categoryId,
  );

  HomeState stateWith(List<ProductModel> pool) =>
      HomeState(recommendationPool: pool);

  group('recommendations', () {
    final pool = [
      product('a'),
      product('b', categorySlug: 'cold-coffee'),
      product('c', categorySlug: 'hot-coffee'),
      product('d'),
      product('e', categorySlug: 'tea'),
    ];

    test('without weather only favourites are promoted', () {
      final picked = stateWith(pool).recommendations(favoriteIds: {'d'});
      expect(picked.map((p) => p.id).toList(), ['d', 'a', 'b', 'c']);
    });

    test('a hot day promotes cold categories', () {
      final picked = stateWith(pool)
          .recommendations(weather: const WeatherModel(temperature: 30));
      expect(picked.map((p) => p.id).toList(), ['b', 'a', 'c', 'd']);
    });

    test('a favourite outranks the weather', () {
      final picked = stateWith(pool).recommendations(
        weather: const WeatherModel(temperature: 30),
        favoriteIds: {'c'},
      );
      expect(picked.first.id, 'c');
    });

    test('rows the weather does not suggest keep menu order', () {
      final picked = stateWith(pool)
          .recommendations(weather: const WeatherModel(temperature: 5));
      expect(picked.map((p) => p.id).toList(), ['c', 'e', 'a', 'b']);
    });

    test('the strip is capped', () {
      final picked = stateWith(pool).recommendations();
      expect(picked.length, HomeState.maxRecommendations);
    });
  });

  group('productsForBanner', () {
    test('a product banner uses the resolved product', () {
      final banner = BannerModel(
        id: 'b1',
        image: '',
        target: BannerTarget.product,
        targetId: 'a',
        targetProduct: product('a'),
      );
      expect(HomeState().productsForBanner(banner).map((p) => p.id).toList(), [
        'a',
      ]);
    });

    test('an unresolved product banner falls back to the pool', () {
      final banner = BannerModel(
        id: 'b1',
        image: '',
        target: BannerTarget.product,
        targetId: 'c',
      );
      final state = HomeState(recommendationPool: [product('c')]);
      expect(state.productsForBanner(banner).map((p) => p.id).toList(), ['c']);
    });

    test('a category banner matches on the category id, not the label', () {
      final banner = BannerModel(
        id: 'b1',
        image: '',
        target: BannerTarget.category,
        targetId: 'cat-1',
      );
      final state = HomeState(
        recommendationPool: [
          product('a', categoryId: 'cat-1'),
          product('b', categoryId: 'cat-2'),
        ],
      );
      expect(state.productsForBanner(banner).map((p) => p.id).toList(), ['a']);
    });

    test('a bundle banner lists its loaded components', () {
      final banner = BannerModel(
        id: 'b1',
        image: '',
        target: BannerTarget.bundle,
        targetId: 'bundle-1',
        targetBundle: BundleModel(
          id: 'bundle-1',
          productIds: const ['a', 'z'],
          price: 20,
          components: const [
            BundleComponent(productId: 'a', quantity: 1),
            BundleComponent(productId: 'z', quantity: 1),
          ],
        ),
      );
      final state = HomeState(bundleProducts: {'a': product('a')});
      expect(state.productsForBanner(banner).map((p) => p.id).toList(), [
        'a',
      ], reason: 'a component the bundle query did not resolve is skipped');
    });

    test('a url or unset banner points at nothing', () {
      final banner = BannerModel(
        id: 'b1',
        image: '',
        target: BannerTarget.url,
        targetUrl: 'https://example.com',
      );
      expect(HomeState().productsForBanner(banner), isEmpty);
    });
  });

  group('BannerTarget', () {
    test('parses every stored code', () {
      for (final target in BannerTarget.values) {
        expect(BannerTarget.fromStorage(target.storage), target);
      }
    });

    test('an unknown code behaves like none', () {
      expect(BannerTarget.fromStorage('dessert'), BannerTarget.none);
      expect(BannerTarget.fromStorage(''), BannerTarget.none);
    });

    test('survives a json round trip', () {
      final banner = BannerModel(
        id: 'b1',
        image: '',
        target: BannerTarget.bundle,
        targetId: 'bundle-1',
      );
      final decoded = BannerModel.fromJson(banner.toJson());
      expect(decoded.target, BannerTarget.bundle);
      expect(decoded.targetId, 'bundle-1');
    });

    test('a row without a type still defaults to category', () {
      final decoded = BannerModel.fromJson(const {'id': 'b1'});
      expect(decoded.target, BannerTarget.category);
    });
  });
}
