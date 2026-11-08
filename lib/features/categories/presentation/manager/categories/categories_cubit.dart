import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/di/branch_cubit_binding.dart';
import 'package:new_coffee/features/branch/presentation/manager/branch/branch_cubit.dart';
import 'package:new_coffee/features/bundles/data/model/bundle_model.dart';
import 'package:new_coffee/features/categories/data/model/category_model.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';
import 'package:new_coffee/shared/utils/cache_manager.dart';

part 'categories_state.dart';

/// Loads the category tabs and the products under the selected one.
///
/// Previously the page called `getCategoriesList()` and `getMenuList()`
/// directly during build, so the tabs were fixed at compile time. It also
/// matched products to categories by display name, which breaks the moment a
/// category is renamed or translated.
///
/// بيانات التصنيفات والمنتجات تُخزّن مؤقتاً في [CacheManager] لمدة 5 دقائق
/// لتقليل الجولات المتكررة إلى Supabase عند فتح شاشة التصنيفات.
class CategoriesCubit extends Cubit<CategoriesState> {
  CategoriesCubit({
    required this._repository,
    this.branchId,
    BranchCubit? branchCubit,
  }) : super(const CategoriesState()) {
    if (branchCubit != null) _branchBinding.bind(branchCubit, setBranch);
  }

  bool _loadStarted = false;
  final BranchCubitBinding _branchBinding = BranchCubitBinding();

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

  /// Names stored on legacy rows that have no slug, in the language the row
  /// was written in. Not UI strings: the rule must not follow the app language.
  static const Set<String> bundlesNames = {bundlesSlug, 'الباقات'};

  Future<void> load() async {
    if (isClosed) return;
    emit(state.copyWith(isLoading: true, error: null));
    try {
      // All three queries resolve before isLoading drops. Emitting the
      // categories on their own marked the load finished while products and
      // bundles were still in flight, so the page briefly rendered "no
      // products" for a category it had simply not fetched yet.
      final cacheBranch = branchId ?? 'base';

      final results = await Future.wait([
        _repository.getCategories(),
        _repository.getProducts(branchId: branchId, limit: 60),
        _repository.getBundles(branchId: branchId),
      ]);
      final categories = results[0] as List<CategoryModel>;
      final products = results[1] as List<ProductModel>;
      final bundles = results[2] as List<BundleModel>;

      // Store in cache for subsequent page opens.
      CacheManager().set('categories_list', categories);
      CacheManager().set('categories_products_$cacheBranch', products);
      CacheManager().set('categories_bundles_$cacheBranch', bundles);

      if (isClosed) return;

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
      if (isClosed) return;
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

  @override
  Future<void> close() async {
    await _branchBinding.close();
    await super.close();
  }

  void select(int index) {
    if (index < 0 || index >= state.categories.length) return;
    if (index == state.index) return;
    emit(state.copyWith(index: index));
  }

  /// The tab whose row carries [categoryId], or null when no row does.
  ///
  /// The id is tried before the slug: a banner stores the id, and the legacy rows
  /// carry only a slug. Reading the answer instead of moving the selection is
  /// what lets a page opened for one category ignore the shared tab index:
  /// selecting there would also change what the catalogue tab shows when the
  /// customer goes back to it, for a category nobody tapped.
  int? indexOf(String? categoryId) {
    if (categoryId == null || categoryId.isEmpty) return null;
    final byId = state.categories.indexWhere((c) => c.id == categoryId);
    if (byId >= 0) return byId;
    final bySlug = state.categories.indexWhere((c) => c.slug == categoryId);
    return bySlug >= 0 ? bySlug : null;
  }

  /// Selects the category tab matching [categoryId], if it exists.
  void selectCategoryById(String? categoryId) {
    final index = indexOf(categoryId);
    if (index != null) select(index);
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
  /// The slug is the reliable key. The name fallback covers legacy rows with no
  /// slug and is checked against the two names the row stores, never against
  /// the displayed label: that label is localized, so the rule would change
  /// with the app language, and matching only the English one silently stopped
  /// finding the bundles tab as soon as the app was switched to Arabic.
  bool isBundlesTab(int index) {
    final categories = state.categories;
    if (categories.isEmpty) return false;
    final category = categories[index.clamp(0, categories.length - 1)];
    if (category.slug == bundlesSlug) return true;
    return {category.nameAr, category.nameEn}.any(
      (name) =>
          name != null && bundlesNames.contains(name.trim().toLowerCase()),
    );
  }
}
