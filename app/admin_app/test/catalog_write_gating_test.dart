import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/catalog/admin_catalog_snapshot.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/models/admin_category.dart';
import 'package:admin_app/core/models/admin_product.dart';
import 'package:admin_app/core/search/admin_search_controller.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/banners/data/repositories/admin_banner_repository.dart';
import 'package:admin_app/features/banners/domain/entities/admin_banner.dart';
import 'package:admin_app/features/banners/presentation/manager/admin_banner_cubit.dart';
import 'package:admin_app/features/banners/presentation/pages/banner_page.dart';
import 'package:admin_app/features/bundles/data/repositories/admin_bundle_repository.dart';
import 'package:admin_app/features/bundles/domain/entities/admin_bundle.dart';
import 'package:admin_app/features/bundles/presentation/manager/admin_bundle_cubit.dart';
import 'package:admin_app/features/bundles/presentation/pages/bundle_page.dart';
import 'package:admin_app/features/catalog/data/repositories/admin_product_repository.dart';
import 'package:admin_app/features/catalog/presentation/manager/admin_product_cubit.dart';
import 'package:admin_app/features/catalog/presentation/pages/product_page.dart';
import 'package:admin_app/features/catalog/presentation/widgets/product_card_footer.dart';
import 'package:admin_app/shared/widgets/admin_selection_checkbox.dart';

/// القاعدة هي التي تقرر: 117 و184 ترفضان كتابة المنتج والباقة بلا
/// `catalog.product.write`، و022 ترفض كتابة البانر بلا `settings.write`.
/// الصفحات تُفتح للجميع للقراءة، أما أدوات الكتابة فلمن يُقبل فعله وحده.
class _FakeProductRepository extends AdminProductRepository {
  @override
  Future<AdminCatalogSnapshot> loadCatalog({
    String? branchId,
    int? limit,
    int offset = 0,
    String? search,
  }) async {
    return const AdminCatalogSnapshot(
      products: <AdminProduct>[
        AdminProduct(
          id: 'p1',
          nameAr: 'قهوة أولى',
          nameEn: 'Coffee one',
          sku: 'SKU-1',
          slug: 'coffee-one',
          basePrice: 10,
        ),
      ],
      categories: <AdminCategory>[
        AdminCategory(id: 'c1', nameAr: 'قهوة', nameEn: 'Coffee'),
      ],
      total: 1,
    );
  }
}

class _FakeCatalogRepository extends AdminProductRepository {
  @override
  Future<AdminCatalogSnapshot> loadCatalog({
    String? branchId,
    int? limit,
    int offset = 0,
    String? search,
  }) async {
    return const AdminCatalogSnapshot(
      products: <AdminProduct>[],
      categories: <AdminCategory>[],
    );
  }
}

class _FakeBannerRepository extends AdminBannerRepository {
  @override
  Future<List<AdminBanner>> loadBanners() async => const <AdminBanner>[
    AdminBanner(
      id: 'b1',
      titleAr: 'عنوان',
      titleEn: 'Title',
      imageUrl: 'https://example.com/b.png',
      targetType: 'none',
    ),
  ];
}

class _FakeBundleRepository extends AdminBundleRepository {
  @override
  Future<List<AdminBundle>> loadBundles() async => const <AdminBundle>[
    AdminBundle(id: 'bd1', nameAr: 'إفطار', nameEn: 'Breakfast'),
  ];
}

void _setViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpProducts(
  WidgetTester tester, {
  required bool canManage,
  bool canManageCategories = false,
}) async {
  final cubit = AdminProductCubit(repository: _FakeProductRepository());
  final search = AdminSearchController();
  addTearDown(cubit.close);
  addTearDown(search.dispose);
  await cubit.load();

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ProductPage(
          searchController: search,
          cubit: cubit,
          canManage: canManage,
          canManageCategories: canManageCategories,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpBanners(
  WidgetTester tester, {
  required bool canManage,
}) async {
  final cubit = AdminBannerCubit(repository: _FakeBannerRepository());
  final search = AdminSearchController();
  addTearDown(cubit.close);
  addTearDown(search.dispose);
  await cubit.load();

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: BannerPage(
          searchController: search,
          cubit: cubit,
          canManage: canManage,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpBundles(
  WidgetTester tester, {
  required bool canManage,
}) async {
  final cubit = AdminBundleCubit(
    repository: _FakeBundleRepository(),
    productRepository: _FakeCatalogRepository(),
  );
  final search = AdminSearchController();
  addTearDown(cubit.close);
  addTearDown(search.dispose);
  await cubit.load();

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: BundlePage(
          searchController: search,
          cubit: cubit,
          canManage: canManage,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  group('products', () {
    testWidgets('the writer keeps every product control', (tester) async {
      _setViewport(tester);
      await _pumpProducts(tester, canManage: true);

      expect(find.text(S.addProduct), findsOneWidget);
      expect(find.byType(ProductCardSaveBar), findsOneWidget);
      expect(find.byType(ProductCardFooter), findsOneWidget);
      expect(find.byType(AdminSelectionCheckBox), findsOneWidget);
      // القالب الفارغ داخل حوار الاستيراد، فلا زرّ استيراد مستقلّ للكاتب.
      expect(find.text(S.excelImport), findsOneWidget);
      expect(find.text(S.downloadSampleFile), findsNothing);
      expect(find.text(S.excelExport), findsOneWidget);
    });

    testWidgets('a reader keeps the catalogue and loses the writes', (
      tester,
    ) async {
      _setViewport(tester);
      await _pumpProducts(tester, canManage: false);

      // القراءة لم تُمنع: المنتج لا يزال معروضًا كما قرأته القاعدة.
      expect(find.text('Coffee one'), findsOneWidget);

      expect(find.text(S.addProduct), findsNothing);
      expect(find.byType(ProductCardSaveBar), findsNothing);
      expect(find.byType(ProductCardFooter), findsNothing);
      expect(find.byType(AdminSelectionCheckBox), findsNothing);
      // الاستيراد كتابة على الجدول فيُحجب، ويبقى القالب والتصدير: قراءتان.
      expect(find.text(S.excelImport), findsNothing);
      expect(find.text(S.downloadSampleFile), findsOneWidget);
      expect(find.text(S.excelExport), findsOneWidget);
    });

    testWidgets('the fields of a read-only card refuse the edit', (
      tester,
    ) async {
      _setViewport(tester);
      await _pumpProducts(tester, canManage: false);

      final name = find.byType(TextField).first;
      await tester.tap(name);
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(name).readOnly, isTrue);
    });
  });

  group('banners', () {
    testWidgets('the writer sees the banner controls', (tester) async {
      _setViewport(tester);
      await _pumpBanners(tester, canManage: true);

      expect(find.text(S.addBanner), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
      expect(find.byIcon(AppIcons.edit01), findsOneWidget);
      expect(find.byIcon(AppIcons.delete01), findsOneWidget);
    });

    testWidgets('022 refuses a non-writer, so nothing invites the refusal', (
      tester,
    ) async {
      _setViewport(tester);
      await _pumpBanners(tester, canManage: false);

      expect(find.text('Title'), findsOneWidget);
      expect(find.text(S.addBanner), findsNothing);
      expect(find.byType(Switch), findsNothing);
      expect(find.byIcon(AppIcons.edit01), findsNothing);
      expect(find.byIcon(AppIcons.delete01), findsNothing);
    });
  });

  group('bundles', () {
    testWidgets('the writer sees the bundle controls', (tester) async {
      _setViewport(tester);
      await _pumpBundles(tester, canManage: true);

      expect(find.text(S.addBundle), findsOneWidget);
      expect(find.byType(AdminSelectionCheckBox), findsOneWidget);
      expect(find.text(S.delete), findsOneWidget);
    });

    testWidgets('a reader keeps the bundles and loses the writes', (
      tester,
    ) async {
      _setViewport(tester);
      await _pumpBundles(tester, canManage: false);

      expect(find.text('Breakfast'), findsOneWidget);
      expect(find.text(S.addBundle), findsNothing);
      expect(find.byType(AdminSelectionCheckBox), findsNothing);
      expect(find.text(S.delete), findsNothing);
    });
  });
}
