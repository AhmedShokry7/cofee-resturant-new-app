import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/theme_class.dart';
import 'package:admin_app/features/inventory/domain/entities/admin_inventory_filters.dart';
import 'package:admin_app/features/inventory/domain/entities/admin_inventory_item.dart';
import 'package:admin_app/features/inventory/domain/entities/admin_inventory_metrics.dart';
import 'package:admin_app/features/inventory/domain/entities/admin_stock_movement.dart';
import 'package:admin_app/features/inventory/domain/entities/admin_stock_movement_metrics.dart';
import 'package:admin_app/features/inventory/presentation/models/inventory_filters.dart';
import 'package:admin_app/features/inventory/presentation/widgets/inventory_page_body.dart';
import 'package:admin_app/features/inventory/presentation/widgets/stock_movement_details_dialog.dart';
import 'package:admin_app/features/inventory/presentation/widgets/stock_movements_page_body.dart';
import 'package:admin_app/shared/widgets/admin_page_frame.dart';

const _filters = AdminInventoryFilters(
  branches: <AdminInventoryBranchOption>[
    AdminInventoryBranchOption(
      id: 'b1',
      code: 'MAADI',
      nameAr: 'المعادي',
      nameEn: 'Maadi',
    ),
  ],
  categories: <AdminInventoryCategoryOption>[
    AdminInventoryCategoryOption(value: 'حبوب البن', count: 4),
  ],
);

const _inventoryMetrics = AdminInventoryMetrics(
  total: 18,
  low: 3,
  out: 2,
  stockValue: 12500.75,
  categories: 6,
  branches: 2,
  latestMovementAt: null,
);

AdminInventoryItem _item(int id, {String status = 'low'}) => AdminInventoryItem(
  id: 'm$id',
  sku: 'BEAN-$id',
  nameAr: 'حبوب أرابيكا $id',
  nameEn: 'Arabica beans $id',
  category: 'حبوب البن',
  unit: 'kg',
  unitCost: 420.5,
  reorderLevel: 10,
  quantityOnHand: 4.5,
  stockValue: 1892.25,
  status: status,
  lastMovementAt: DateTime.utc(2026, 10, 24, 9, 15),
);

const _movement = AdminStockMovement(
  id: 7,
  type: 'receipt',
  quantityDelta: 3,
  balanceAfter: 13,
  unitCost: 40,
  movementValue: 120,
  reference: 'INV-9',
  note: 'شحنة الأسبوع',
  materialSku: 'BEAN-7',
  materialNameAr: 'حبوب أرابيكا 7',
  materialNameEn: 'Arabica beans 7',
  unit: 'kg',
  branchCode: 'MAADI',
  branchNameAr: 'المعادي',
  branchNameEn: 'Maadi',
  actorName: 'Mona Ali',
  actorEmail: 'mona@example.com',
  createdAt: null,
);

const _movementMetrics = AdminStockMovementMetrics(
  total: 22,
  receipts: 9,
  issues: 8,
  waste: 3,
  counts: 2,
  receivedValue: 5400.25,
  issuedValue: 3100,
  wasteValue: 220.5,
  actors: 4,
);

void _setViewport(WidgetTester tester, double width, [double height = 1100]) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pump(
  WidgetTester tester,
  Widget body, {
  bool dark = false,
  TextDirection direction = TextDirection.ltr,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? ThemeClass.dark() : ThemeClass.light(),
      builder: (context, child) =>
          Directionality(textDirection: direction, child: child!),
      home: Scaffold(body: body),
    ),
  );
  await tester.pump();
}

Future<void> _pumpInventory(
  WidgetTester tester, {
  List<AdminInventoryItem>? items,
  AdminInventoryMetrics metrics = _inventoryMetrics,
  int total = 18,
  String search = '',
  InventoryStatusFilter statusFilter = InventoryStatusFilter.all,
  bool canAdjust = true,
  bool canEdit = true,
  bool dark = false,
  TextDirection direction = TextDirection.ltr,
}) async {
  await _pump(
    tester,
    _InventoryHarness(
      items: items ?? <AdminInventoryItem>[_item(1)],
      metrics: metrics,
      total: total,
      search: search,
      statusFilter: statusFilter,
      canAdjust: canAdjust,
      canEdit: canEdit,
    ),
    dark: dark,
    direction: direction,
  );
}

Future<void> _pumpMovements(
  WidgetTester tester, {
  List<AdminStockMovement>? movements,
  AdminStockMovementMetrics metrics = _movementMetrics,
  int total = 22,
  String search = '',
  bool canAdjust = true,
  bool dark = false,
  TextDirection direction = TextDirection.ltr,
}) async {
  await _pump(
    tester,
    _MovementsHarness(
      movements: movements ?? <AdminStockMovement>[_movement],
      metrics: metrics,
      total: total,
      search: search,
      canAdjust: canAdjust,
    ),
    dark: dark,
    direction: direction,
  );
}

class _InventoryHarness extends StatefulWidget {
  const _InventoryHarness({
    required this.items,
    required this.metrics,
    required this.total,
    required this.search,
    required this.statusFilter,
    required this.canAdjust,
    required this.canEdit,
  });

  final List<AdminInventoryItem> items;
  final AdminInventoryMetrics metrics;
  final int total;
  final String search;
  final InventoryStatusFilter statusFilter;
  final bool canAdjust;
  final bool canEdit;

  @override
  State<_InventoryHarness> createState() => _InventoryHarnessState();
}

class _InventoryHarnessState extends State<_InventoryHarness> {
  late String _search = widget.search;
  late InventoryStatusFilter _statusFilter = widget.statusFilter;
  String? _category;
  String? _branchId;
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    return InventoryPageBody(
      items: widget.items,
      total: widget.total,
      page: _page,
      pages: widget.total == 0 ? 0 : (widget.total + 9) ~/ 10,
      pageSize: 10,
      search: _search,
      category: _category,
      statusFilter: _statusFilter,
      branchId: _branchId,
      filters: _filters,
      metrics: widget.metrics,
      isRefreshingRows: false,
      canAdjust: widget.canAdjust,
      canEdit: widget.canEdit,
      onAdd: () {},
      onEdit: (_) {},
      onMovement: (_) {},
      onRecordMovement: () {},
      onDelete: (_) {},
      onSearchChanged: (value) => setState(() {
        _search = value.trim();
        _page = 0;
      }),
      onCategoryChanged: (value) => setState(() {
        _category = value;
        _page = 0;
      }),
      onStatusChanged: (value) => setState(() {
        _statusFilter = value;
        _page = 0;
      }),
      onBranchChanged: (value) => setState(() {
        _branchId = value;
        _page = 0;
      }),
      onClearFilters: () => setState(() {
        _search = '';
        _category = null;
        _statusFilter = InventoryStatusFilter.all;
        _branchId = null;
        _page = 0;
      }),
      onPageChanged: (value) => setState(() => _page = value),
      onRefresh: () {},
    );
  }
}

class _MovementsHarness extends StatefulWidget {
  const _MovementsHarness({
    required this.movements,
    required this.metrics,
    required this.total,
    required this.search,
    required this.canAdjust,
  });

  final List<AdminStockMovement> movements;
  final AdminStockMovementMetrics metrics;
  final int total;
  final String search;
  final bool canAdjust;

  @override
  State<_MovementsHarness> createState() => _MovementsHarnessState();
}

class _MovementsHarnessState extends State<_MovementsHarness> {
  late String _search = widget.search;
  StockMovementTypeFilter _type = StockMovementTypeFilter.all;
  StockMovementPeriod _period = StockMovementPeriod.all;
  String? _branchId;
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    return StockMovementsPageBody(
      movements: widget.movements,
      total: widget.total,
      page: _page,
      pages: widget.total == 0 ? 0 : (widget.total + 9) ~/ 10,
      pageSize: 10,
      search: _search,
      type: _type,
      period: _period,
      branchId: _branchId,
      filters: _filters,
      metrics: widget.metrics,
      isRefreshingRows: false,
      canAdjust: widget.canAdjust,
      onSearchChanged: (value) => setState(() {
        _search = value.trim();
        _page = 0;
      }),
      onTypeChanged: (value) => setState(() {
        _type = value;
        _page = 0;
      }),
      onPeriodChanged: (value) => setState(() {
        _period = value;
        _page = 0;
      }),
      onBranchChanged: (value) => setState(() {
        _branchId = value;
        _page = 0;
      }),
      onClearFilters: () => setState(() {
        _search = '';
        _type = StockMovementTypeFilter.all;
        _period = StockMovementPeriod.all;
        _branchId = null;
        _page = 0;
      }),
      onPageChanged: (value) => setState(() => _page = value),
      onOpen: (movement) =>
          showStockMovementDetailsDialog(context: context, movement: movement),
      onRecordMovement: () {},
      onRefresh: () {},
    );
  }
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  group('inventory page', () {
    testWidgets('the wide page shows metrics, filters and the material table', (
      tester,
    ) async {
      _setViewport(tester, 1500);
      await _pumpInventory(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(AdminPageFrame), findsOneWidget);
      expect(find.text(S.inventory), findsOneWidget);
      expect(find.text(S.inventorySubtitle), findsOneWidget);
      expect(
        find.byKey(const Key('inventory-record-movement')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('inventory-add-material')), findsOneWidget);

      expect(find.text(S.inventoryMetricTotal), findsOneWidget);
      expect(find.text(S.inventoryMetricValue), findsOneWidget);
      expect(find.text(S.inventoryMetricLow), findsOneWidget);
      expect(find.text(S.inventoryMetricOut), findsOneWidget);

      expect(find.text(S.inventoryFilterAllStatuses), findsOneWidget);
      expect(find.text(S.inventoryFilterAllCategories), findsOneWidget);
      expect(find.text(S.inventoryFilterAllBranches), findsOneWidget);
      expect(find.text(S.inventoryTableMaterial), findsOneWidget);
      expect(find.text(S.inventoryTableOnHand), findsOneWidget);
      expect(find.text(S.inventoryTableReorder), findsOneWidget);
      expect(find.text(S.inventoryTableValue), findsOneWidget);
      expect(find.text(S.inventoryTableLastMovement), findsOneWidget);

      expect(find.byKey(const Key('inventory-row-m1')), findsOneWidget);
      expect(find.byKey(const Key('inventory-card-m1')), findsNothing);
      expect(find.text('Arabica beans 1'), findsOneWidget);
      expect(find.text(S.lowStock), findsOneWidget);
      expect(find.text(S.inventoryRowsLabel(1, 10, 18)), findsOneWidget);
    });

    testWidgets('the narrow page switches to material cards', (tester) async {
      _setViewport(tester, 420, 900);
      await _pumpInventory(tester);

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('inventory-card-m1')), findsOneWidget);
      expect(find.byKey(const Key('inventory-row-m1')), findsNothing);
      expect(find.text(S.inventoryTableMaterial), findsNothing);
      expect(find.text('Arabica beans 1'), findsOneWidget);
      expect(find.text(S.inventoryMetricTotal), findsOneWidget);
    });

    testWidgets('a read-only member sees the note instead of actions', (
      tester,
    ) async {
      _setViewport(tester, 1500);
      await _pumpInventory(tester, canAdjust: false, canEdit: false);

      expect(tester.takeException(), isNull);
      expect(find.text(S.inventoryReadOnly), findsOneWidget);
      expect(find.byKey(const Key('inventory-record-movement')), findsNothing);
      expect(find.byKey(const Key('inventory-add-material')), findsNothing);
    });

    testWidgets('an empty directory explains how to add the first material', (
      tester,
    ) async {
      _setViewport(tester, 1500);
      await _pumpInventory(
        tester,
        items: const <AdminInventoryItem>[],
        metrics: AdminInventoryMetrics.empty,
        total: 0,
      );

      expect(tester.takeException(), isNull);
      expect(find.text(S.rawMaterialsEmpty), findsOneWidget);
      expect(find.text(S.rawMaterialsEmptyHint), findsOneWidget);
      expect(find.text(S.rawMaterialsNoMatches), findsNothing);
      expect(find.text(S.addRawMaterial), findsWidgets);
    });

    testWidgets('a filtered empty directory offers to clear the filters', (
      tester,
    ) async {
      _setViewport(tester, 1500);
      await _pumpInventory(
        tester,
        items: const <AdminInventoryItem>[],
        metrics: AdminInventoryMetrics.empty,
        total: 0,
        search: 'missing',
      );

      expect(tester.takeException(), isNull);
      expect(find.text(S.rawMaterialsNoMatches), findsOneWidget);
      expect(find.text(S.clearFilters), findsOneWidget);

      await tester.tap(find.text(S.clearFilters));
      await tester.pumpAndSettle();

      expect(find.text(S.rawMaterialsNoMatches), findsNothing);
      expect(find.text(S.rawMaterialsEmpty), findsOneWidget);
    });

    testWidgets('the toolbar narrows the rows by stock status', (tester) async {
      _setViewport(tester, 1500);
      await _pumpInventory(tester);

      await tester.tap(find.text(S.inventoryFilterAllStatuses));
      await tester.pumpAndSettle();
      await tester.tap(find.text(S.lowStock).last);
      await tester.pumpAndSettle();

      expect(find.byTooltip(S.clearFilters), findsOneWidget);
      expect(find.text(S.lowStock), findsWidgets);
    });

    testWidgets('the page renders in Arabic RTL and dark mode', (tester) async {
      AppLocale.instance.debugSet(AppLanguage.arabic);
      _setViewport(tester, 1500);
      await _pumpInventory(tester, dark: true, direction: TextDirection.rtl);

      expect(tester.takeException(), isNull);
      expect(find.text(S.inventory), findsOneWidget);
      expect(find.text(S.inventorySubtitle), findsOneWidget);
      expect(find.text('حبوب أرابيكا 1'), findsOneWidget);
    });
  });

  group('stock movements page', () {
    testWidgets('the wide page shows metrics and the movement ledger', (
      tester,
    ) async {
      _setViewport(tester, 1500);
      await _pumpMovements(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(S.stockMovements), findsOneWidget);
      expect(find.text(S.stockMovementsSubtitle), findsOneWidget);
      expect(
        find.byKey(const Key('stock-movements-record-movement')),
        findsOneWidget,
      );

      expect(find.text(S.stockMovementsMetricTotal), findsOneWidget);
      expect(find.text(S.stockMovementsMetricReceipts), findsOneWidget);
      expect(find.text(S.stockMovementsMetricIssues), findsOneWidget);
      expect(find.text(S.stockMovementsMetricWaste), findsOneWidget);

      expect(find.text(S.stockMovementAllTypes), findsOneWidget);
      expect(find.text(S.stockPeriodAll), findsOneWidget);
      expect(find.text(S.inventoryFilterAllBranches), findsOneWidget);
      expect(find.text(S.stockMovementsTableMovement), findsOneWidget);
      expect(find.text(S.inventoryTableMaterial), findsOneWidget);
      expect(find.text(S.stockMovementsTableBranch), findsOneWidget);
      expect(find.text(S.stockMovementsTableQuantity), findsOneWidget);
      expect(find.text(S.stockMovementsTableBalance), findsOneWidget);
      expect(find.text(S.stockMovementsTableValue), findsOneWidget);
      expect(find.text(S.stockMovementsTableActor), findsOneWidget);

      expect(find.byKey(const Key('stock-movement-row-7')), findsOneWidget);
      expect(find.byKey(const Key('stock-movement-card-7')), findsNothing);
      expect(find.text('Arabica beans 7'), findsOneWidget);
      expect(find.text('Maadi'), findsOneWidget);
      expect(find.text('Mona Ali'), findsOneWidget);
      expect(find.text('+3 kg'), findsOneWidget);
      expect(find.text(S.stockMovementsRowsLabel(1, 10, 22)), findsOneWidget);
    });

    testWidgets('the narrow page switches to movement cards', (tester) async {
      _setViewport(tester, 420, 900);
      await _pumpMovements(tester);

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('stock-movement-card-7')), findsOneWidget);
      expect(find.byKey(const Key('stock-movement-row-7')), findsNothing);
      expect(find.text(S.stockMovementsTableMovement), findsNothing);
      expect(find.text('Arabica beans 7'), findsOneWidget);
      expect(find.text(S.movementReceipt), findsOneWidget);
    });

    testWidgets('a read-only member sees the note instead of recording', (
      tester,
    ) async {
      _setViewport(tester, 1500);
      await _pumpMovements(tester, canAdjust: false);

      expect(tester.takeException(), isNull);
      expect(find.text(S.stockMovementsReadOnly), findsOneWidget);
      expect(
        find.byKey(const Key('stock-movements-record-movement')),
        findsNothing,
      );
    });

    testWidgets('an empty ledger explains how to record the first movement', (
      tester,
    ) async {
      _setViewport(tester, 1500);
      await _pumpMovements(
        tester,
        movements: const <AdminStockMovement>[],
        metrics: AdminStockMovementMetrics.empty,
        total: 0,
      );

      expect(tester.takeException(), isNull);
      expect(find.text(S.stockMovementsEmpty), findsOneWidget);
      expect(find.text(S.stockMovementsEmptyHint), findsOneWidget);
      expect(find.text(S.stockMovementAction), findsWidgets);
    });

    testWidgets('a filtered empty ledger offers to clear the filters', (
      tester,
    ) async {
      _setViewport(tester, 1500);
      await _pumpMovements(
        tester,
        movements: const <AdminStockMovement>[],
        metrics: AdminStockMovementMetrics.empty,
        total: 0,
        search: 'missing',
      );

      expect(tester.takeException(), isNull);
      expect(find.text(S.stockMovementsNoMatches), findsOneWidget);
      expect(find.text(S.clearFilters), findsOneWidget);

      await tester.tap(find.text(S.clearFilters));
      await tester.pumpAndSettle();

      expect(find.text(S.stockMovementsNoMatches), findsNothing);
      expect(find.text(S.stockMovementsEmpty), findsOneWidget);
    });

    testWidgets('tapping a row opens the movement details', (tester) async {
      _setViewport(tester, 1500);
      await _pumpMovements(tester);

      await tester.tap(find.byKey(const Key('stock-movement-row-7')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final dialog = find.byKey(const Key('stock-movement-details-dialog'));
      expect(dialog, findsOneWidget);
      Finder inDialog(String text) =>
          find.descendant(of: dialog, matching: find.text(text));

      expect(inDialog(S.stockMovementDetailsTitle), findsOneWidget);
      expect(inDialog(S.stockMovementQuantityChange), findsOneWidget);
      expect(inDialog(S.stockMovementBalanceAfter), findsOneWidget);
      expect(inDialog(S.stockMovementUnitCost), findsOneWidget);
      expect(inDialog(S.stockMovementValue), findsOneWidget);
      expect(inDialog(S.stockMovementsTableActor), findsOneWidget);
      expect(inDialog(S.reference), findsOneWidget);
      expect(inDialog('INV-9'), findsOneWidget);
      expect(inDialog(S.stockMovementNote), findsOneWidget);
      expect(inDialog('شحنة الأسبوع'), findsOneWidget);

      await tester.tap(find.byKey(const Key('stock-movement-details-close')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('stock-movement-details-dialog')),
        findsNothing,
      );
    });

    testWidgets('the ledger filters by movement type', (tester) async {
      _setViewport(tester, 1500);
      await _pumpMovements(tester);

      await tester.tap(find.text(S.stockMovementAllTypes));
      await tester.pumpAndSettle();
      await tester.tap(find.text(S.movementIssue).last);
      await tester.pumpAndSettle();

      expect(find.byTooltip(S.clearFilters), findsOneWidget);
      expect(find.text(S.movementIssue), findsWidgets);
    });
  });
}
