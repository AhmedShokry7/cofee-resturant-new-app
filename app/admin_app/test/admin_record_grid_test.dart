import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/models/admin_category.dart';
import 'package:admin_app/features/bundles/domain/entities/admin_bundle.dart';
import 'package:admin_app/features/bundles/presentation/widgets/bundle_records.dart';
import 'package:admin_app/features/catalog/presentation/widgets/category_records.dart';
import 'package:admin_app/shared/widgets/category_card.dart';

const AdminCategory _category = AdminCategory(
  id: 'c1',
  nameAr: 'قهوة',
  nameEn: 'Coffee',
);

List<AdminCategory> _categories(int count) => [
  for (var index = 0; index < count; index++)
    _category.copyWith(id: 'c$index', nameEn: 'Coffee $index'),
];

List<AdminBundle> _bundles(int count) => [
  for (var index = 0; index < count; index++)
    const AdminBundle(
      id: 'b1',
      nameAr: 'إفطار',
      nameEn: 'Breakfast',
    ).copyWith(id: 'b$index', nameEn: 'Breakfast $index'),
];

Future<void> _pump(
  WidgetTester tester, {
  required double width,
  double height = 900,
  double textScale = 1,
  required Widget child,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, next) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: next!,
      ),
      home: Scaffold(body: child),
    ),
  );
  await tester.pump();
}

/// القياس الذي حكم به الجدول على نفسه، لا ما نعتقد أنه حسبه.
SliverGridDelegateWithFixedCrossAxisCount _delegate(WidgetTester tester) =>
    tester.widget<GridView>(find.byType(GridView)).gridDelegate
        as SliverGridDelegateWithFixedCrossAxisCount;

/// عرض البطاقة الذي ينتجه عدد الأعمدة هذا في هذا العرض.
double _cardWidth(double gridWidth, int columns) =>
    (gridWidth - (columns - 1) * AppSpacing.md) / columns;

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  group('columns', () {
    // السلّم القديم كان أربع عتبات مكتوبة باليد في نسختين؛ القاعدة الجديدة
    // تقسم على العرض المثالي. تتفقان عند هذه العروض، وتختلفان عند 1400
    // حرفيًا حيث كان السلّم يرى أربعة بينما تكتفي القاعدة بخمسة.
    for (final (width, expected) in const <(double, int)>[
      (1500, 5),
      (1280, 4),
      (900, 3),
      (560, 2),
      (400, 1),
    ]) {
      testWidgets('$width gives $expected columns', (tester) async {
        await _pump(
          tester,
          width: width,
          child: CategoryRecords(categories: _categories(12)),
        );
        expect(_delegate(tester).crossAxisCount, expected);
      });
    }

    testWidgets('the card keeps its ideal width instead of shrinking', (
      tester,
    ) async {
      await _pump(
        tester,
        width: 1000,
        child: CategoryRecords(categories: _categories(12)),
      );
      final columns = _delegate(tester).crossAxisCount;
      final cardWidth = tester.getRect(find.byType(CategoryCard).first).width;

      expect(columns, 3);
      // قاعدة التقسيم تمنع أعمدة تترك بطاقة أضيق من مثاليها إلا بمقدار الفواصل.
      expect(
        cardWidth,
        greaterThanOrEqualTo(
          AppDimensions.recordCardIdealWidth - AppSpacing.md,
        ),
      );
      expect(cardWidth, closeTo(_cardWidth(1000, columns), 0.5));
    });

    testWidgets('bundles use the same rule as categories', (tester) async {
      await _pump(
        tester,
        width: 900,
        child: CategoryRecords(categories: _categories(6)),
      );
      final category = _delegate(tester);

      await _pump(
        tester,
        width: 900,
        child: BundleRecords(bundles: _bundles(6)),
      );
      final bundle = _delegate(tester);

      expect(bundle.crossAxisCount, category.crossAxisCount);
      expect(bundle.mainAxisExtent, category.mainAxisExtent);
    });
  });

  group('card height', () {
    testWidgets('the cell asks the card instead of guessing a ratio', (
      tester,
    ) async {
      await _pump(
        tester,
        width: 900,
        child: CategoryRecords(categories: _categories(6)),
      );
      final columns = _delegate(tester).crossAxisCount;
      final cardWidth = _cardWidth(900, columns);

      expect(
        _delegate(tester).mainAxisExtent,
        CategoryCard.extent(cardWidth, TextScaler.noScaling),
      );
    });

    testWidgets('a larger text scale grows the cell, not the overflow', (
      tester,
    ) async {
      await _pump(
        tester,
        width: 360,
        height: 700,
        child: CategoryRecords(categories: _categories(8)),
      );
      final plain = _delegate(tester).mainAxisExtent!;

      await _pump(
        tester,
        width: 360,
        height: 700,
        textScale: 2,
        child: CategoryRecords(categories: _categories(8)),
      );

      expect(tester.takeException(), isNull);
      expect(_delegate(tester).mainAxisExtent!, greaterThan(plain));
    });

    testWidgets('the bundle count line cannot push the footer out', (
      tester,
    ) async {
      await _pump(
        tester,
        width: 320,
        height: 700,
        textScale: 1.5,
        child: BundleRecords(bundles: _bundles(8)),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Arabic labels fit the same footer', (tester) async {
      AppLocale.instance.debugSet(AppLanguage.arabic);
      await _pump(
        tester,
        width: 560,
        height: 700,
        textScale: 1.5,
        child: CategoryRecords(categories: _categories(6)),
      );
      expect(tester.takeException(), isNull);
      expect(_delegate(tester).crossAxisCount, 2);
    });
  });
}
