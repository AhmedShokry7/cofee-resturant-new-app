import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/models/admin_branch.dart';
import 'package:admin_app/features/branches/presentation/widgets/branch_cards.dart';
import 'package:admin_app/features/branches/presentation/widgets/branch_delivery_settings_dialog.dart';
import 'package:admin_app/features/branches/presentation/widgets/branch_product_pricing_dialog.dart';
import 'package:admin_app/core/models/admin_delivery_zone.dart';
import 'package:admin_app/features/delivery_zones/data/repositories/admin_delivery_zone_repository.dart';
import 'package:admin_app/shared/widgets/delivery_zone_form_dialog.dart';
import 'package:admin_app/core/models/admin_category.dart';
import 'package:admin_app/core/models/admin_product.dart';
import 'package:admin_app/features/catalog/data/repositories/admin_product_repository.dart';
import 'package:admin_app/core/catalog/admin_catalog_snapshot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

class _FakeZoneRepository extends AdminDeliveryZoneRepository {
  _FakeZoneRepository({required this.zones, required this.links});

  final List<AdminDeliveryZone> zones;
  final List<Map<String, dynamic>> links;

  @override
  Future<List<AdminDeliveryZone>> loadZones() async => zones;

  @override
  Future<List<Map<String, dynamic>>> loadZoneBranches() async => links;
}

class _FakeProductRepository extends AdminProductRepository {
  String? savedBranchId;
  static const product = AdminProduct(
    id: 'product-1',
    nameAr: 'قهوة عربية',
    nameEn: 'Arabic coffee',
    sku: 'COF-1',
    slug: 'arabic-coffee',
    basePrice: 24,
  );

  @override
  Future<AdminCatalogSnapshot> loadCatalog({
    String? branchId,
    int? limit,
    int offset = 0,
    String? search,
  }) async => AdminCatalogSnapshot(
    products: search == null || product.nameEn.contains(search)
        ? const [product]
        : const [],
    categories: const <AdminCategory>[],
    branchId: branchId,
    total: 1,
  );

  @override
  Future<List<Map<String, dynamic>>> loadBranchProductPricing(
    String productId,
  ) async => const [];

  @override
  Future<void> saveBranchProductDiscount({
    required String branchId,
    required String productId,
    double? discountPercentage,
    DateTime? discountStartsAt,
    DateTime? discountEndsAt,
    required bool useGeneralDiscount,
  }) async {
    savedBranchId = branchId;
  }
}

const _branch = AdminBranch(
  id: 'branch-a',
  code: 'A',
  nameAr: 'فرع الرياض',
  nameEn: 'Riyadh branch',
  address: 'طريق الملك فهد، الرياض',
  latitude: 24.7136,
  longitude: 46.6753,
);

const _zoneA = AdminDeliveryZone(
  id: 'zone-a',
  nameAr: 'شمال الرياض',
  nameEn: 'North Riyadh',
  deliveryFee: 12,
  minOrderAmount: 0,
  radiusKm: 20,
  feeMethod: 'fixed',
);

const _zoneB = AdminDeliveryZone(
  id: 'zone-b',
  nameAr: 'جدة',
  nameEn: 'Jeddah',
  deliveryFee: 15,
  minOrderAmount: 0,
  radiusKm: 15,
  feeMethod: 'fixed',
);

const _oldMisplacedZone = AdminDeliveryZone(
  id: 'zone-misplaced',
  nameAr: 'نطاق قديم',
  nameEn: 'Old zone',
  deliveryFee: 15,
  minOrderAmount: 0,
  centerLatitude: 33.3152,
  centerLongitude: 44.3661,
  radiusKm: 15,
  feeMethod: 'fixed',
);

void main() {
  testWidgets('branch card keeps delivery settings action on narrow screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BranchCards(
            branches: const [_branch],
            canManage: true,
            canManagePricing: true,
            onEdit: (_) {},
            onChangeImage: (_) {},
            onManageDelivery: (_) {},
            onManagePricing: (_) {},
            onToggleActive: (_) {},
            onDelete: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('branch-menu-branch-a')));
    await tester.pumpAndSettle();

    expect(find.text(S.manageDelivery), findsOneWidget);
    expect(find.text(S.manageBranchPricing), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('branch pricing editor is opened from the branch context', (
    tester,
  ) async {
    final repository = _FakeProductRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BranchProductPricingDialog(
            branch: _branch,
            repository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Arabic coffee'), findsOneWidget);
    await tester.tap(find.text('Arabic coffee'));
    await tester.pumpAndSettle();
    expect(find.text(S.discountPercentage), findsOneWidget);
    expect(find.text(S.useGeneralDiscount), findsOneWidget);
    await tester.tap(find.text(S.save));
    await tester.pumpAndSettle();
    expect(repository.savedBranchId, _branch.id);
    expect(tester.takeException(), isNull);
  });

  testWidgets('branch settings show only zones assigned to this branch', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BranchDeliverySettingsDialog(
            branch: _branch,
            onEditBranch: () {},
            repository: _FakeZoneRepository(
              zones: const [_zoneA, _zoneB],
              links: const [
                {'zone_id': 'zone-a', 'branch_id': 'branch-a'},
                {'zone_id': 'zone-b', 'branch_id': 'branch-b'},
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(_branch.address), findsWidgets);
    expect(find.text('North Riyadh'), findsOneWidget);
    expect(find.text('Jeddah'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new zone map starts at the selected branch location', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BranchDeliverySettingsDialog(
            branch: _branch,
            onEditBranch: () {},
            repository: _FakeZoneRepository(zones: const [], links: const []),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.addDeliveryZone).first);
    await tester.pumpAndSettle();

    expect(find.byType(DeliveryZoneFormDialog), findsOneWidget);
    expect(find.text(_branch.address), findsWidgets);
    final latitudeField = tester.widget<TextField>(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == S.centerLatitude,
      ),
    );
    final longitudeField = tester.widget<TextField>(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == S.centerLongitude,
      ),
    );
    expect(latitudeField.controller?.text, '24.7136');
    expect(longitudeField.controller?.text, '46.6753');
    expect(find.byIcon(Icons.radar), findsNothing);
    var circleLayer = tester.widget<PolygonLayer>(find.byType(PolygonLayer));
    expect(circleLayer.polygons.single.points, hasLength(72));
    final branchCenter = const LatLng(24.7136, 46.6753);
    expect(
      const Distance().as(
        LengthUnit.Kilometer,
        branchCenter,
        circleLayer.polygons.single.points.first,
      ),
      closeTo(20, 0.1),
    );

    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == S.deliveryRadiusKm,
      ),
      '8',
    );
    await tester.pump();
    circleLayer = tester.widget<PolygonLayer>(find.byType(PolygonLayer));
    expect(
      const Distance().as(
        LengthUnit.Kilometer,
        branchCenter,
        circleLayer.polygons.single.points.first,
      ),
      closeTo(8, 0.1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'editing a zone opens the map at its branch, not old zone center',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BranchDeliverySettingsDialog(
              branch: _branch,
              onEditBranch: () {},
              repository: _FakeZoneRepository(
                zones: const [_oldMisplacedZone],
                links: const [
                  {'zone_id': 'zone-misplaced', 'branch_id': 'branch-a'},
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
      expect(map.options.initialCenter, const LatLng(24.7136, 46.6753));
      expect(
        tester
            .widget<TextField>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is TextField &&
                    widget.decoration?.labelText == S.centerLatitude,
              ),
            )
            .controller
            ?.text,
        '33.3152',
      );
      expect(tester.takeException(), isNull);
    },
  );

  // أجرة لا تُقرأ رقمًا كانت تُكتب صفرًا فيتحوّل الحي إلى توصيل مجاني بلا كلمة.
  testWidgets('a fee typed in Arabic numerals is the fee the zone keeps', (
    tester,
  ) async {
    final zone = await _saveZone(tester, fee: '١٢٫٥');

    expect(zone?.deliveryFee, 12.5);
    expect(zone?.minOrderAmount, 0);
  });

  testWidgets('an unreadable fee is refused instead of written as zero', (
    tester,
  ) async {
    final zone = await _saveZone(tester, fee: '1.2.3');

    expect(zone, isNull);
    expect(find.text(S.invalidDeliveryZoneFields), findsOneWidget);
  });
}

/// يفتح نموذج حيّ على مركز الفرع، يكتب الأجرة ويحفظ، فيرجع ما قبله Navigator.
Future<AdminDeliveryZone?> _saveZone(
  WidgetTester tester, {
  required String fee,
}) async {
  tester.view.physicalSize = const Size(1100, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  AdminDeliveryZone? result;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showDialog<AdminDeliveryZone>(
                context: context,
                builder: (_) => const DeliveryZoneFormDialog(
                  defaultLatitude: 24.7136,
                  defaultLongitude: 46.6753,
                ),
              );
            },
            child: const Text('open zone form'),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('open zone form'));
  await tester.pumpAndSettle();

  await tester.enterText(_labeled(S.zoneNameArabic), 'حي شمال');
  await tester.enterText(_labeled(S.deliveryFeeAmount), fee);
  await tester.pump();
  await tester.tap(find.widgetWithText(FilledButton, S.save));
  await tester.pumpAndSettle();

  return result;
}

Finder _labeled(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);
