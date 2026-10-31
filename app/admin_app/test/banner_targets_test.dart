import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/catalog/admin_catalog_snapshot.dart';
import 'package:admin_app/core/catalog/catalog_data.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/banners/domain/entities/admin_banner.dart';
import 'package:admin_app/features/banners/presentation/widgets/banner_data_dialog.dart';
import 'package:admin_app/features/banners/presentation/widgets/banner_records.dart';

/// قراءة الكتالوج التي تملأ قائمتي الهدف: الرفض فيها حالةٌ تختلف عن «لا
/// منتجات»، والحوار كان يسوّي الاثنين في قائمةٍ فارغة.
class _CatalogFake implements CatalogData {
  _CatalogFake({this.refuse = false});

  final bool refuse;
  int loads = 0;

  @override
  Future<AdminCatalogSnapshot> loadCatalog({
    String? branchId,
    int? limit,
    int offset = 0,
    String? search,
  }) {
    loads++;
    if (refuse) return Future<AdminCatalogSnapshot>.error(StateError('401'));
    return Future.value(
      const AdminCatalogSnapshot(products: [], categories: []),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
}

const AdminBanner _banner = AdminBanner(
  id: 'b1',
  titleAr: 'عرض الشتاء',
  titleEn: 'Winter offer',
  imageUrl: 'https://example.com/b.png',
  targetType: 'product',
  sortOrder: 3,
);

Future<void> _pumpDialog(WidgetTester tester, CatalogData catalog) async {
  tester.view.physicalSize = const Size(1200, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: BannerDataDialog(
          initialBanner: _banner,
          catalog: catalog,
          onSave: (_) async {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  testWidgets('رفض الكتالوج يقول ذلك ولا يُعرض كقائمة خالية', (tester) async {
    final catalog = _CatalogFake(refuse: true);
    await _pumpDialog(tester, catalog);

    expect(find.textContaining(S.couldNotLoadProducts), findsOneWidget);
    expect(find.widgetWithText(TextButton, S.retry), findsOneWidget);
    expect(catalog.loads, 1);

    await tester.tap(find.widgetWithText(TextButton, S.retry));
    await tester.pumpAndSettle();

    // إعادة المحاولة قراءةٌ جديدة، لا رسالةٌ تُعاد طباعتها.
    expect(catalog.loads, 2);
  });

  testWidgets('فراغٌ بعد قراءةٍ ناجحة لا يُسمّى فشلًا', (tester) async {
    await _pumpDialog(tester, _CatalogFake());

    expect(find.textContaining(S.noProductsFound), findsOneWidget);
    expect(find.textContaining(S.couldNotLoadProducts), findsNothing);
    expect(find.widgetWithText(TextButton, S.retry), findsNothing);
  });

  testWidgets('بطاقة البانر تطبع الهدف والترتيب بالعربية', (tester) async {
    AppLocale.instance.debugSet(AppLanguage.arabic);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 240,
            child: BannerRecords(banners: const <AdminBanner>[_banner]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('نوع الهدف: منتج'), findsOneWidget);
    expect(find.textContaining('ترتيب العرض: ٣'), findsOneWidget);
    expect(find.textContaining('Type:'), findsNothing);
  });
}
