import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/catalog/data/models/admin_category.dart';
import 'package:admin_app/features/catalog/data/models/admin_product.dart';
import 'package:admin_app/features/catalog/data/repositories/admin_product_repository.dart';
import 'package:admin_app/features/catalog/presentation/manager/admin_product_cubit.dart';
import 'package:admin_app/features/catalog/presentation/manager/admin_product_excel_controller.dart';
import 'package:admin_app/features/catalog/presentation/widgets/product_page_view.dart';

class _Repository extends AdminProductRepository {
  final products = const <AdminProduct>[
    AdminProduct(
      id: 'p1',
      nameAr: 'قهوة أولى',
      nameEn: 'Coffee one',
      sku: 'SKU-1',
      slug: 'coffee-one',
      basePrice: 10,
    ),
    AdminProduct(
      id: 'p2',
      nameAr: 'قهوة ثانية',
      nameEn: 'Coffee two',
      sku: 'SKU-2',
      slug: 'coffee-two',
      basePrice: 20,
    ),
  ];
  final deleted = <String>[];

  @override
  Future<AdminCatalogSnapshot> loadCatalog({
    String? branchId,
    int? limit,
    int offset = 0,
    String? search,
  }) async {
    final page = limit == null
        ? products
        : products.skip(offset).take(limit).toList(growable: false);
    return AdminCatalogSnapshot(
      products: page,
      categories: const <AdminCategory>[],
      total: products.length,
    );
  }

  @override
  Future<void> deleteProduct(String productId) async {
    deleted.add(productId);
  }
}

void _setViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  testWidgets('select all exposes a confirmed bulk delete action', (
    tester,
  ) async {
    _setViewport(tester);
    final repository = _Repository();
    final cubit = AdminProductCubit(repository: repository);
    final excel = ProductExcelController(cubit: cubit, onProgress: (_) {});
    addTearDown(cubit.close);
    await cubit.load();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductPageView(cubit: cubit, excel: excel),
        ),
      ),
    );
    await tester.pumpAndSettle();

    cubit.toggleSelection('p1');
    await tester.pumpAndSettle();

    await tester.tap(find.text(S.selectAllProducts(2)));
    await tester.pumpAndSettle();
    expect(cubit.state.selectedIds, <String>{'p1', 'p2'});
    expect(find.text(S.selectedProductsCount(2)), findsOneWidget);

    await tester.tap(find.text(S.deleteSelectedProducts));
    await tester.pumpAndSettle();
    expect(find.text(S.deleteProductsConfirm(2)), findsOneWidget);

    await tester.tap(find.text(S.cancel));
    await tester.pumpAndSettle();
    expect(repository.deleted, isEmpty);

    await tester.tap(find.text(S.deleteSelectedProducts));
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.delete).last);
    await tester.pumpAndSettle();

    expect(repository.deleted, containsAll(<String>['p1', 'p2']));
    expect(cubit.state.products, isEmpty);
    expect(cubit.state.selectedIds, isEmpty);
  });
}
