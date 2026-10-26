import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/features/bundles/data/models/admin_bundle.dart';
import 'package:admin_app/features/bundles/data/repositories/admin_bundle_repository.dart';
import 'package:admin_app/features/bundles/presentation/manager/admin_bundle_cubit.dart';
import 'package:admin_app/features/bundles/presentation/widgets/bundle_records.dart';
import 'package:admin_app/features/catalog/data/models/admin_category.dart';
import 'package:admin_app/features/catalog/data/repositories/admin_product_repository.dart';
import 'package:admin_app/features/catalog/presentation/manager/admin_category_cubit.dart';
import 'package:admin_app/features/catalog/presentation/widgets/category_records.dart';
import 'package:admin_app/shared/widgets/admin_selection_checkbox.dart';

class _FakeCatalogRepository extends AdminProductRepository {
  _FakeCatalogRepository({this.categories = const <AdminCategory>[]});

  final List<AdminCategory> categories;
  final List<String> deletedCategories = <String>[];
  final Set<String> failingCategories = <String>{};

  @override
  Future<AdminCatalogSnapshot> loadCatalog({
    String? branchId,
    int? limit,
    int offset = 0,
    String? search,
  }) async {
    return AdminCatalogSnapshot(
      products: const <Never>[],
      categories: categories,
    );
  }

  @override
  Future<void> deleteCategory(String categoryId) async {
    if (failingCategories.contains(categoryId)) {
      throw StateError('category is in use');
    }
    deletedCategories.add(categoryId);
  }
}

class _FakeBundleRepository extends AdminBundleRepository {
  _FakeBundleRepository({this.bundles = const <AdminBundle>[]});

  final List<AdminBundle> bundles;
  final List<String> deletedBundles = <String>[];
  final Set<String> failingBundles = <String>{};

  @override
  Future<List<AdminBundle>> loadBundles() async => bundles;

  @override
  Future<void> deleteBundle(String bundleId) async {
    if (failingBundles.contains(bundleId)) {
      throw StateError('bundle is in use');
    }
    deletedBundles.add(bundleId);
  }
}

const AdminCategory _coffee = AdminCategory(
  id: 'c1',
  nameAr: 'قهوة',
  nameEn: 'Coffee',
);
const AdminCategory _dessert = AdminCategory(
  id: 'c2',
  nameAr: 'حلويات',
  nameEn: 'Desserts',
);

const AdminBundle _breakfast = AdminBundle(
  id: 'b1',
  nameAr: 'إفطار',
  nameEn: 'Breakfast',
);
const AdminBundle _evening = AdminBundle(
  id: 'b2',
  nameAr: 'مساء',
  nameEn: 'Evening',
);

void main() {
  group('categories', () {
    test('picking and clearing the selection', () async {
      final repository = _FakeCatalogRepository(
        categories: const <AdminCategory>[_coffee, _dessert],
      );
      final cubit = AdminCategoryCubit(repository: repository);
      addTearDown(cubit.close);
      await cubit.load();

      cubit.toggleSelection('c1');
      cubit.selectMany(<String>['c2']);

      expect(cubit.state.selectedIds, <String>{'c1', 'c2'});
      expect(cubit.state.selectedCount, 2);

      cubit.toggleSelection('c1');
      expect(cubit.state.selectedIds, <String>{'c2'});

      cubit.clearSelection();
      expect(cubit.state.selectedIds, isEmpty);
    });

    test('a failure keeps the category selected for a retry', () async {
      final repository = _FakeCatalogRepository(
        categories: const <AdminCategory>[_coffee, _dessert],
      )..failingCategories.add('c2');
      final cubit = AdminCategoryCubit(repository: repository);
      addTearDown(cubit.close);
      await cubit.load();
      cubit.selectMany(<String>['c1', 'c2']);

      final outcome = await cubit.deleteSelected();

      expect(outcome.deleted, 1);
      expect(outcome.failed, 1);
      expect(repository.deletedCategories, <String>['c1']);
      expect(cubit.state.categories.map((category) => category.id), <String>[
        'c2',
      ]);
      expect(cubit.state.selectedIds, <String>{'c2'});
      expect(cubit.state.isDeletingSelected, isFalse);
    });

    test('a reload drops the selection', () async {
      final repository = _FakeCatalogRepository(
        categories: const <AdminCategory>[_coffee],
      );
      final cubit = AdminCategoryCubit(repository: repository);
      addTearDown(cubit.close);
      await cubit.load();
      cubit.toggleSelection('c1');

      await cubit.load();

      expect(cubit.state.selectedIds, isEmpty);
    });
  });

  group('bundles', () {
    test('a failure keeps the bundle selected for a retry', () async {
      final repository = _FakeBundleRepository(
        bundles: const <AdminBundle>[_breakfast, _evening],
      )..failingBundles.add('b2');
      final cubit = AdminBundleCubit(
        repository: repository,
        productRepository: _FakeCatalogRepository(),
      );
      addTearDown(cubit.close);
      await cubit.load();
      cubit.selectMany(<String>['b1', 'b2']);

      final outcome = await cubit.deleteSelected();

      expect(outcome.deleted, 1);
      expect(outcome.failed, 1);
      expect(repository.deletedBundles, <String>['b1']);
      expect(cubit.state.bundles.map((bundle) => bundle.id), <String>['b2']);
      expect(cubit.state.selectedIds, <String>{'b2'});
      expect(cubit.state.isDeletingSelected, isFalse);
    });
  });

  group('cards', () {
    setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
    tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

    testWidgets('a category card reports the pick', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      AdminCategory? picked;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CategoryRecords(
              categories: const <AdminCategory>[_coffee],
              onSelect: (category) => picked = category,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(AdminSelectionCheckBox));
      await tester.pump();

      expect(picked?.id, 'c1');
    });

    testWidgets('a bundle card shows the picked state', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      AdminBundle? picked;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BundleRecords(
              bundles: const <AdminBundle>[_breakfast],
              selectedIds: const <String>{'b1'},
              onSelect: (bundle) => picked = bundle,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        tester
            .widget<AdminSelectionCheckBox>(find.byType(AdminSelectionCheckBox))
            .checked,
        isTrue,
      );

      await tester.tap(find.byType(AdminSelectionCheckBox));
      expect(picked?.id, 'b1');
    });
  });
}
