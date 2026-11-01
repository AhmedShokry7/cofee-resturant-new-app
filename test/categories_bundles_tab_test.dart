import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/features/bundles/data/model/bundle_model.dart';
import 'package:new_coffee/features/categories/data/model/category_model.dart';
import 'package:new_coffee/features/categories/presentation/manager/categories/categories_cubit.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';
import 'package:new_coffee/shared/utils/cache_manager.dart';

/// Which tab shows bundles instead of products.
///
/// The rule used to consult the localized strings table, so it changed with
/// the app language: a label that happened to equal `S.bundles` was enough to
/// flip a tab.
void main() {
  setUp(() {
    CacheManager().clear();
    AppLocale.instance.debugSet(AppLanguage.english);
  });
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  Future<CategoriesCubit> cubitWith(List<CategoryModel> categories) async {
    final cubit = CategoriesCubit(repository: _FakeCatalog(categories));
    cubit.ensureLoaded();
    await cubit.stream.firstWhere((state) => !state.isLoading);
    return cubit;
  }

  CategoryModel category({
    required String id,
    String? label,
    String? slug,
    String? nameAr,
    String? nameEn,
  }) => CategoryModel(
    id: id,
    label: label,
    slug: slug,
    nameAr: nameAr,
    nameEn: nameEn,
    icon: AppIcons.coffee,
  );

  test('a category with the bundles slug is the bundles tab', () async {
    final cubit = await cubitWith([
      category(id: 'c1', label: 'Coffee', slug: 'hot-coffee'),
      category(id: 'c2', label: 'Combos', slug: 'bundles'),
    ]);

    expect(cubit.isBundlesTab(0), isFalse);
    expect(cubit.isBundlesTab(1), isTrue);
    await cubit.close();
  });

  test('a legacy row with no slug matches its stored English name', () async {
    final cubit = await cubitWith([
      category(id: 'c1', label: 'Bundles', nameEn: 'Bundles'),
    ]);

    expect(cubit.isBundlesTab(0), isTrue);
    await cubit.close();
  });

  test('the rule follows the stored names, not the displayed label', () async {
    final cubit = await cubitWith([
      // Stored bilingually, displayed in English.
      category(id: 'c1', label: 'Coffee', nameAr: 'الباقات', nameEn: 'Bundles'),
      // Only the Arabic name is stored.
      category(id: 'c2', label: 'Tea', nameAr: 'الباقات'),
      // Neither stored name belongs to the bundles category.
      category(id: 'c3', label: 'Bundles', nameEn: 'Snacks'),
    ]);

    expect(cubit.isBundlesTab(0), isTrue);
    expect(cubit.isBundlesTab(1), isTrue);
    expect(
      cubit.isBundlesTab(2),
      isFalse,
      reason: 'the display label alone must not select the tab',
    );

    AppLocale.instance.debugSet(AppLanguage.arabic);
    expect(cubit.isBundlesTab(2), isFalse, reason: 'not language dependent');
    await cubit.close();
  });

  test('an empty catalogue has no bundles tab', () async {
    final cubit = await cubitWith(const []);
    expect(cubit.isBundlesTab(0), isFalse);
    await cubit.close();
  });
}

class _FakeCatalog implements CatalogRepository {
  _FakeCatalog(this._categories);

  final List<CategoryModel> _categories;

  @override
  Future<List<CategoryModel>> getCategories({
    bool includeInactive = false,
  }) async => _categories;

  @override
  Future<List<ProductModel>> getProducts({
    String? branchId,
    String? categoryId,
    int limit = CatalogLimits.products,
    int offset = 0,
  }) async => const [];

  @override
  Future<List<BundleModel>> getBundles({
    String? branchId,
    int limit = CatalogLimits.bundles,
  }) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
