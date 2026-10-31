import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/models/admin_category.dart';
import 'package:admin_app/core/models/admin_product.dart';
import 'package:admin_app/features/catalog/data/repositories/admin_product_repository.dart';
import 'package:admin_app/core/catalog/admin_catalog_snapshot.dart';
import 'package:admin_app/features/catalog/presentation/manager/admin_product_cubit.dart';
import 'package:admin_app/features/catalog/presentation/pages/product_page.dart';
import 'package:admin_app/features/catalog/presentation/widgets/product_card.dart';
import 'package:admin_app/features/catalog/presentation/widgets/product_card_footer.dart';
import 'package:admin_app/features/catalog/presentation/widgets/product_card_rows.dart';
import 'package:admin_app/features/catalog/presentation/widgets/product_dialogs.dart';
import 'package:admin_app/features/catalog/presentation/widgets/product_records.dart';
import 'package:admin_app/core/search/admin_search_controller.dart';

class _FakePageRepository extends AdminProductRepository {
  final List<AdminProduct> saved = <AdminProduct>[];

  @override
  Future<AdminCatalogSnapshot> loadCatalog({
    String? branchId,
    int? limit,
    int offset = 0,
    String? search,
  }) async {
    return const AdminCatalogSnapshot(
      products: <AdminProduct>[],
      categories: <AdminCategory>[
        AdminCategory(id: 'c1', nameAr: 'قهوة', nameEn: 'Coffee'),
      ],
      branchId: 'branch-1',
    );
  }

  @override
  Future<AdminProduct> saveProduct(
    AdminProduct product, {
    String? branchId,
  }) async {
    saved.add(product);
    return product.copyWith(id: 'p1', isDraft: false);
  }
}

void _setViewport(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

const List<AdminProduct> _products = <AdminProduct>[
  AdminProduct(
    id: 'p1',
    nameAr: 'منتج أول',
    nameEn: 'First',
    sku: 'SKU-1',
    slug: 'first',
    basePrice: 10,
  ),
  AdminProduct(
    id: 'p2',
    nameAr: 'منتج ثاني',
    nameEn: 'Second',
    sku: 'SKU-2',
    slug: 'second',
    basePrice: 20,
  ),
  AdminProduct(
    id: 'p3',
    nameAr: 'منتج ثالث',
    nameEn: 'Third',
    sku: 'SKU-3',
    slug: 'third',
    basePrice: 30,
  ),
  AdminProduct(
    id: 'p4',
    nameAr: 'منتج رابع',
    nameEn: 'Fourth',
    sku: 'SKU-4',
    slug: 'fourth',
    basePrice: 40,
  ),
  AdminProduct(
    id: 'p5',
    nameAr: 'منتج خامس',
    nameEn: 'Fifth',
    sku: 'SKU-5',
    slug: 'fifth',
    basePrice: 50,
  ),
];

void main() {
  setUp(() {
    AppLocale.instance.debugSet(AppLanguage.english);
  });

  tearDown(() {
    AppLocale.instance.debugSet(AppLanguage.english);
  });

  testWidgets('add product opens the data dialog and waits for save', (
    tester,
  ) async {
    _setViewport(tester, 1280);

    final repository = _FakePageRepository();
    final cubit = AdminProductCubit(repository: repository);
    final searchController = AdminSearchController();
    addTearDown(cubit.close);
    addTearDown(searchController.dispose);

    await cubit.load();
    await tester.pumpWidget(
      MaterialApp(
        home: ProductPage(
          searchController: searchController,
          cubit: cubit,
          canManage: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(cubit.state.products, isEmpty);

    await tester.tap(find.text(S.addProduct));
    await tester.pumpAndSettle();

    expect(find.byType(ProductDataDialog), findsOneWidget);
    expect(cubit.state.products, isEmpty);
    expect(repository.saved, isEmpty);

    await tester.tap(find.widgetWithText(FilledButton, S.save));
    await tester.pumpAndSettle();

    expect(find.byType(ProductDataDialog), findsOneWidget);
    expect(cubit.state.products, isEmpty);
    expect(repository.saved, isEmpty);

    await tester.tap(find.widgetWithText(TextButton, S.cancel));
    await tester.pumpAndSettle();

    expect(find.byType(ProductDataDialog), findsNothing);
    expect(cubit.state.products, isEmpty);
  });

  testWidgets('the grid fits five cards on a very wide screen', (tester) async {
    _setViewport(tester, 1600);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProductRecords(products: _products)),
      ),
    );
    await tester.pump();

    expect(find.byType(ProductCard), findsNWidgets(5));

    final first = tester.getTopLeft(find.byType(ProductCard).first);
    final second = tester.getTopLeft(find.byType(ProductCard).at(1));
    expect(second.dx - first.dx, lessThan(400));
  });

  testWidgets('the grid keeps at least four cards on a desktop', (
    tester,
  ) async {
    _setViewport(tester, 1280);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProductRecords(products: _products)),
      ),
    );
    await tester.pump();

    final first = tester.getTopLeft(find.byType(ProductCard).first);
    final second = tester.getTopLeft(find.byType(ProductCard).at(1));
    final third = tester.getTopLeft(find.byType(ProductCard).at(2));
    final fourth = tester.getTopLeft(find.byType(ProductCard).at(3));

    // Four cards share the first row, the fifth one wraps to the next row.
    expect(second.dy, first.dy);
    expect(third.dy, first.dy);
    expect(fourth.dy, first.dy);
  });

  testWidgets('the grid drops to one card on a narrow screen', (tester) async {
    _setViewport(tester, 360);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProductRecords(products: _products)),
      ),
    );
    await tester.pump();

    final first = tester.getTopLeft(find.byType(ProductCard).first);
    final second = tester.getTopLeft(find.byType(ProductCard).at(1));
    expect(second.dy, greaterThan(first.dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the card renders the product facts', (tester) async {
    _setViewport(tester, 1280);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProductRecords(products: _products)),
      ),
    );
    await tester.pump();

    expect(find.text('First'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.byType(ProductCard), findsNWidgets(5));
  });

  // النصّ الذي لا يُقرأ رقمًا كان يُكتب صفرًا في القاعدة بلا كلمة؛ الحقل الآن
  // يرفضه، ويقبل ما تقبله بقية حقول المبلغ في التطبيق.
  testWidgets('the card refuses a price it cannot read', (tester) async {
    AdminProduct? saved;
    await _pumpCard(tester, onSave: (product) => saved = product);

    await _typePrice(tester, '1.2.3');
    await tester.tap(find.byType(ProductCardSaveBar));
    await tester.pumpAndSettle();

    expect(saved, isNull);
    expect(find.text(S.invalidPrice), findsOneWidget);
  });

  testWidgets('the card reads a price typed in Arabic numerals', (
    tester,
  ) async {
    AdminProduct? saved;
    await _pumpCard(tester, onSave: (product) => saved = product);

    await _typePrice(tester, '٢٥');
    await tester.tap(find.byType(ProductCardSaveBar));
    await tester.pumpAndSettle();

    expect(saved?.basePrice, 25);
  });
}

Future<void> _pumpCard(
  WidgetTester tester, {
  required ValueChanged<AdminProduct> onSave,
}) async {
  _setViewport(tester, 900);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 420,
            child: ProductCard(
              product: _products.first,
              categories: const <AdminCategory>[],
              onSave: onSave,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _typePrice(WidgetTester tester, String value) async {
  await tester.enterText(
    find.descendant(
      of: find.byType(ProductCardPriceRow),
      matching: find.byType(TextField),
    ),
    value,
  );
  await tester.pump();
}
