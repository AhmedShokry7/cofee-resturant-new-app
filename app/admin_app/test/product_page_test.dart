import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/features/catalog/data/models/admin_product.dart';
import 'package:admin_app/features/catalog/presentation/widgets/product_card.dart';
import 'package:admin_app/features/catalog/presentation/widgets/product_records.dart';

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

    expect(find.text('منتج أول'), findsOneWidget);
    expect(find.text('SAR 10.00'), findsOneWidget);
    expect(find.byType(ProductCard), findsNWidgets(5));
  });
}
