import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/bundles/data/model/bundle_model.dart';
import 'package:new_coffee/features/categories/data/model/category_model.dart';
import 'package:new_coffee/features/home/data/model/banner_model.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';

part 'home_state.dart';

/// Loads everything the home screen renders.
///
/// Before this, each of the seven home widgets called a Dart getter directly
/// during build, so the data was fixed at compile time and could not change
/// without a release. One cubit loads it once and every widget reads the same
/// snapshot, which is also one round trip instead of seven.
class HomeCubit extends Cubit<HomeState> {
  HomeCubit({
    required CatalogRepository repository,
    this.branchId,
  })  : _repository = repository,
        super(const HomeState()) {
    load();
  }

  final CatalogRepository _repository;

  /// Branch whose prices and availability apply. Null until the customer picks.
  ///
  /// Mutable so [setBranch] can switch it. It was final before, which meant
  /// setBranch reloaded with the old value and silently did nothing.
  String? branchId;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, error: null));

    // Each section loads independently so one failing source does not blank the
    // whole page. A section that fails keeps its previous value and the page
    // reports which ones are degraded.
    try {
      final results = await Future.wait([
        _repository.getBanners(),
        _repository.getBundles(branchId: branchId),
        _repository.getCategories(),
        _repository.getFeatured(branchId: branchId, limit: 10),
        // Candidate pool for recommendations. Loaded once here so the weather
        // rule can filter it without a query per temperature change.
        _repository.getProducts(branchId: branchId, limit: 50),
      ]);

      final bundles = results[1] as List<BundleModel>;
      final products = results[4] as List<ProductModel>;

      // Resolve the products a bundle contains in one query, rather than per
      // card. This also replaces the old bundleProducts() helper, which read
      // them out of the Dart menu list.
      final componentIds = <String>{
        for (final b in bundles)
          for (final c in b.components) c.productId,
      }.toList();

      final productsById = <String, ProductModel>{
        for (final p in products) p.id: p,
      };

      // Only keep components we actually resolved. A dangling component id
      // would otherwise crash the card when it reads the map.
      final bundleProducts = <String, ProductModel>{};
      for (final id in componentIds) {
        final product = productsById[id];
        if (product != null) bundleProducts[id] = product;
      }

      emit(HomeState(
        banners: results[0] as List<BannerModel>,
        bundles: bundles,
        categories: results[2] as List<CategoryModel>,
        popular: _toProducts(results[3] as List<FeaturedProduct>),
        recommendationPool: products,
        bundleProducts: bundleProducts,
        isLoading: false,
      ));
    } catch (error, stackTrace) {
      emit(state.copyWith(isLoading: false, error: error.toString()));
      addError(error, stackTrace);
    }
  }

  /// Products contained by the loaded bundles, keyed by product id.
  ///
  /// Used to show a bundle's contents and the saving it represents, which used
  /// to be computed from the compiled-in menu.
  List<ProductModel> productsIn(BundleModel bundle) => [
        for (final c in bundle.components)
          if (state.bundleProducts[c.productId] != null)
            state.bundleProducts[c.productId]!,
      ];

  /// What the bundle contents would cost at their own prices.
  double originalTotalFor(BundleModel bundle) {
    var total = 0.0;
    for (final c in bundle.components) {
      final product = state.bundleProducts[c.productId];
      if (product != null) total += product.price * c.quantity;
    }
    return total;
  }

  /// Never negative: a bundle can be priced above its contents.
  double savingFor(BundleModel bundle) {
    final saving = originalTotalFor(bundle) - bundle.price;
    return saving > 0 ? saving : 0;
  }

  /// Reloads after the customer picks a different branch.
  ///
  /// Skips the reload when the branch is unchanged, so tapping the active
  /// branch chip does not refire five queries.
  Future<void> setBranch(String? branchId) {
    if (branchId == this.branchId) return Future.value();
    this.branchId = branchId;
    return load();
  }

  /// Featured rows carry the fields a card needs, so no second query is needed
  /// to render the carousel.
  static List<ProductModel> _toProducts(List<FeaturedProduct> featured) =>
      featured
          .map((f) => ProductModel(
                id: f.productId,
                name: f.nameEn,
                nameAr: f.nameAr,
                nameEn: f.nameEn,
                category: '',
                description: '',
                price: f.effectivePrice,
                image: f.imageUrl ?? '',
                isFeatured: f.source == 'manual',
              ))
          .toList();
}