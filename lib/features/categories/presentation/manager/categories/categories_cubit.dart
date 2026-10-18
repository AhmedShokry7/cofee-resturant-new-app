import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/bundles/data/model/bundle_model.dart';
import 'package:new_coffee/features/categories/data/model/category_model.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';

part 'categories_state.dart';

/// Loads the category tabs and the products under the selected one.
///
/// Previously the page called `getCategoriesList()` and `getMenuList()`
/// directly during build, so the tabs were fixed at compile time. It also
/// matched products to categories by display name, which breaks the moment a
/// category is renamed or translated.
class CategoriesCubit extends Cubit<CategoriesState> {
  CategoriesCubit({required this._repository, this.branchId})
    : super(const CategoriesState());

  bool _loadStarted = false;

  void ensureLoaded() {
    if (_loadStarted) return;
    _loadStarted = true;
    load();
  }

  final CatalogRepository _repository;

  /// Branch whose prices and availability apply. Null until the customer picks.
  String? branchId;

  /// The category whose bundles get a dedicated tab.
  static const String bundlesSlug = 'bundles';

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final results = await Future.wait([
        _repository.getCategories(),
        _repository.getProducts(branchId: branchId, limit: 200),
        _repository.getBundles(branchId: branchId),
      ]);

      final categories = results[0] as List<CategoryModel>;
      final products = results[1] as List<ProductModel>;
      final bundles = results[2] as List<BundleModel>;

      // Keep the selected tab valid. The old code did
      // `index.clamp(0, categories.length - 1)`, which throws when the list is
      // empty, and kept rendering a stale tab if the backend returned fewer
      // categories than the hard-coded list had.
      final maxIndex = categories.isEmpty ? 0 : categories.length - 1;

      emit(
        state.copyWith(
          categories: categories,
          products: products,
          bundles: bundles,
          index: state.index.clamp(0, maxIndex),
          isLoading: false,
        ),
      );
    } catch (error, stackTrace) {
      emit(state.copyWith(isLoading: false, error: error.toString()));
      addError(error, stackTrace);
    }
  }

  /// Reloads after the customer picks a different branch.
  Future<void> setBranch(String? branchId) {
    if (branchId == this.branchId) return Future.value();
    this.branchId = branchId;
    return load();
  }

  void select(int index) {
    if (index < 0 || index >= state.categories.length) return;
    if (index == state.index) return;
    emit(state.copyWith(index: index));
  }

  /// Selects the category tab matching [categoryId], if it exists.
  void selectCategoryById(String? categoryId) {
    if (categoryId == null || categoryId.isEmpty) return;
    var index = state.categories.indexWhere((c) => c.id == categoryId);
    if (index < 0) {
      index = state.categories.indexWhere((c) => c.slug == categoryId);
    }
    if (index >= 0) select(index);
  }

  /// Products in the tab at [index].
  ///
  /// Joins on the category id, not the label. A product whose category failed to
  /// resolve keeps a null id and is excluded rather than silently landing in
  /// whichever tab happened to share its display name.
  List<ProductModel> productsAt(int index) {
    final categories = state.categories;
    if (categories.isEmpty) return const [];
    final safeIndex = index.clamp(0, categories.length - 1);
    final id = categories[safeIndex].id;
    if (id == null) return const [];
    return state.products
        .where((p) => p.categoryId == id)
        .toList(growable: false);
  }

  /// True when the tab at [index] should render bundles instead of products.
///
/// The slug is the reliable key. The label fallback covers legacy rows with no
  /// slug, and has to be checked against *both* names: [CategoryModel.label] is
  /// localized, so matching only the English one silently stopped finding the
  /// bundles tab as soon as the app was switched to Arabic.
  bool isBundlesTab(int index) {
    final categories = state.categories;
    if (categories.isEmpty) return false;
    final safeIndex = index.clamp(0, categories.length - 1);
    final category = categories[safeIndex];
    if (category.slug == bundlesSlug) return true;
    final label = category.label.trim().toLowerCase();
    if (label.isEmpty) return false;
    final names = {
      'bundles',
      S.bundles.trim().toLowerCase(),
      category.nameEn?.trim().toLowerCase() ?? '',
      category.nameAr?.trim().toLowerCase() ?? '',
    };
    return names.contains(label);
  }
}
