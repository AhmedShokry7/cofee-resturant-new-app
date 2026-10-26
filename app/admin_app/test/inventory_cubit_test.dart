import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/features/inventory/data/models/admin_inventory_draft.dart';
import 'package:admin_app/features/inventory/data/models/admin_inventory_filters.dart';
import 'package:admin_app/features/inventory/data/models/admin_inventory_item.dart';
import 'package:admin_app/features/inventory/data/models/admin_inventory_material_option.dart';
import 'package:admin_app/features/inventory/data/models/admin_inventory_metrics.dart';
import 'package:admin_app/features/inventory/data/models/admin_stock_movement.dart';
import 'package:admin_app/features/inventory/data/models/admin_stock_movement_draft.dart';
import 'package:admin_app/features/inventory/data/models/admin_stock_movement_metrics.dart';
import 'package:admin_app/features/inventory/data/repositories/admin_inventory_repository.dart';
import 'package:admin_app/features/inventory/presentation/manager/admin_inventory_cubit.dart';
import 'package:admin_app/features/inventory/presentation/manager/admin_inventory_state.dart';
import 'package:admin_app/features/inventory/presentation/manager/admin_stock_movements_cubit.dart';
import 'package:admin_app/features/inventory/presentation/manager/admin_stock_movements_state.dart';
import 'package:admin_app/features/inventory/presentation/models/inventory_filters.dart';

AdminInventoryItem _item(int index) => AdminInventoryItem(
  id: 'm$index',
  nameAr: 'مادة $index',
  nameEn: 'Material $index',
  unit: 'kg',
  status: 'ok',
);

AdminStockMovement _movement(int id) => AdminStockMovement(
  id: id,
  type: 'receipt',
  quantityDelta: 2,
  balanceAfter: 12,
  materialNameAr: 'بن',
  materialNameEn: 'Beans',
  branchNameAr: 'المعادي',
  branchNameEn: 'Maadi',
  actorName: 'Mona Ali',
  createdAt: DateTime.utc(2026, 10, 1, 9, 30),
);

const _filters = AdminInventoryFilters(
  branches: <AdminInventoryBranchOption>[
    AdminInventoryBranchOption(
      id: 'b1',
      code: 'MAADI',
      nameAr: 'المعادي',
      nameEn: 'Maadi',
    ),
    AdminInventoryBranchOption(
      id: 'b2',
      code: 'NASR',
      nameAr: 'مدينة نصر',
      nameEn: 'Nasr City',
    ),
  ],
  categories: <AdminInventoryCategoryOption>[
    AdminInventoryCategoryOption(value: 'حبوب البن', count: 4),
  ],
);

class _FakeInventoryRepository extends AdminInventoryRepository {
  _FakeInventoryRepository();

  List<AdminInventoryItem> items = <AdminInventoryItem>[];
  int total = 0;
  AdminInventoryMetrics metrics = AdminInventoryMetrics.empty;
  AdminInventoryFilters filters = _filters;
  List<AdminInventoryMaterialOption> options =
      const <AdminInventoryMaterialOption>[];
  List<AdminStockMovement> movements = <AdminStockMovement>[];
  int movementTotal = 0;
  AdminStockMovementMetrics movementMetrics = AdminStockMovementMetrics.empty;

  bool failRows = false;
  bool failMetrics = false;
  bool failFilters = false;
  bool failMovementRows = false;

  int loadCalls = 0;
  int metricsCalls = 0;
  int filtersCalls = 0;
  int movementLoadCalls = 0;
  int movementMetricsCalls = 0;
  int optionCalls = 0;

  String? lastSearch;
  String? lastCategory;
  String? lastStatus;
  String? lastBranchId;
  String? lastType;
  String? lastPeriod;
  int? lastPage;
  int? lastPageSize;
  String? lastOptionSearch;
  String? lastOptionBranchId;

  AdminInventoryPage Function(int page)? pageBuilder;
  AdminStockMovementPage Function(int page)? movementPageBuilder;

  InventoryMaterialSaveOutcome saveOutcome = InventoryMaterialSaveOutcome.saved;
  InventoryMutationOutcome deleteOutcome = InventoryMutationOutcome.success;
  InventoryMovementOutcome movementOutcome = InventoryMovementOutcome.success;
  AdminInventoryDraft? savedDraft;
  String? deletedId;
  AdminStockMovementDraft? recordedDraft;

  @override
  Future<AdminInventoryPage> loadPage({
    String? search,
    String? category,
    String? status,
    String? branchId,
    int page = 0,
    int pageSize = 10,
  }) async {
    loadCalls += 1;
    lastSearch = search;
    lastCategory = category;
    lastStatus = status;
    lastBranchId = branchId;
    lastPage = page;
    lastPageSize = pageSize;
    if (failRows) throw StateError('rows failed');
    if (pageBuilder != null) return pageBuilder!(page);
    return AdminInventoryPage(rows: items, total: total);
  }

  @override
  Future<AdminInventoryMetrics> loadMetrics({String? branchId}) async {
    metricsCalls += 1;
    if (failMetrics) throw StateError('metrics failed');
    return metrics;
  }

  @override
  Future<AdminInventoryFilters> loadFilters() async {
    filtersCalls += 1;
    if (failFilters) throw StateError('filters failed');
    return filters;
  }

  @override
  Future<List<AdminInventoryMaterialOption>> searchMaterials({
    String? search,
    String? branchId,
    int limit = 30,
  }) async {
    optionCalls += 1;
    lastOptionSearch = search;
    lastOptionBranchId = branchId;
    return options;
  }

  @override
  Future<InventoryMaterialSaveOutcome> saveMaterial(
    AdminInventoryDraft draft,
  ) async {
    savedDraft = draft;
    return saveOutcome;
  }

  @override
  Future<InventoryMutationOutcome> deleteMaterial(String materialId) async {
    deletedId = materialId;
    return deleteOutcome;
  }

  @override
  Future<InventoryMovementOutcome> recordMovement(
    AdminStockMovementDraft draft,
  ) async {
    recordedDraft = draft;
    return movementOutcome;
  }

  @override
  Future<AdminStockMovementPage> loadMovements({
    String? search,
    String? type,
    String? period,
    String? branchId,
    int page = 0,
    int pageSize = 10,
  }) async {
    movementLoadCalls += 1;
    lastSearch = search;
    lastType = type;
    lastPeriod = period;
    lastBranchId = branchId;
    lastPage = page;
    lastPageSize = pageSize;
    if (failMovementRows) throw StateError('movements failed');
    if (movementPageBuilder != null) return movementPageBuilder!(page);
    return AdminStockMovementPage(rows: movements, total: movementTotal);
  }

  @override
  Future<AdminStockMovementMetrics> loadMovementMetrics({
    String? branchId,
    String? period,
  }) async {
    movementMetricsCalls += 1;
    lastBranchId = branchId;
    lastPeriod = period;
    return movementMetrics;
  }
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  group('AdminInventoryCubit', () {
    test('load fetches rows, metrics and filters together', () async {
      final repository = _FakeInventoryRepository()
        ..items = <AdminInventoryItem>[_item(1), _item(2)]
        ..total = 2
        ..metrics = const AdminInventoryMetrics(
          total: 2,
          low: 1,
          stockValue: 400,
          categories: 1,
          branches: 2,
        );
      final cubit = AdminInventoryCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.status, AdminInventoryStatus.ready);
      expect(cubit.state.items, hasLength(2));
      expect(cubit.state.total, 2);
      expect(cubit.state.metrics.low, 1);
      expect(cubit.state.filters.hasBranches, isTrue);
      expect(cubit.state.hasData, isTrue);
      expect(repository.loadCalls, 1);
      expect(repository.metricsCalls, 1);
      expect(repository.filtersCalls, 1);
      expect(repository.lastPage, 0);
      expect(repository.lastPageSize, 10);
    });

    test('search is debounced and clearing it reloads at once', () async {
      final repository = _FakeInventoryRepository();
      final cubit = AdminInventoryCubit(repository: repository);
      addTearDown(cubit.close);
      await cubit.load();
      expect(repository.loadCalls, 1);

      cubit.updateSearch(' milk ');
      expect(cubit.state.search, 'milk');
      expect(cubit.state.page, 0);
      expect(repository.loadCalls, 1);

      await Future<void>.delayed(const Duration(milliseconds: 420));
      expect(repository.loadCalls, 2);
      expect(repository.lastSearch, 'milk');
      expect(repository.metricsCalls, 1);

      cubit.updateSearch('');
      await _settle();
      expect(repository.loadCalls, 3);
      expect(repository.lastSearch ?? '', isEmpty);
    });

    test('filters reset the page and branch changes reload metrics', () async {
      final repository = _FakeInventoryRepository()
        ..items = List<AdminInventoryItem>.generate(10, _item)
        ..total = 25;
      final cubit = AdminInventoryCubit(repository: repository);
      addTearDown(cubit.close);
      await cubit.load();

      cubit.setPage(1);
      await _settle();
      expect(cubit.state.page, 1);
      expect(repository.lastPage, 1);

      cubit.setCategory('حبوب البن');
      await _settle();
      expect(cubit.state.page, 0);
      expect(cubit.state.category, 'حبوب البن');
      expect(repository.lastCategory, 'حبوب البن');
      expect(repository.lastPage, 0);

      cubit.setStatusFilter(InventoryStatusFilter.low);
      await _settle();
      expect(repository.lastStatus, 'low');

      final metricsBefore = repository.metricsCalls;
      cubit.setBranch('b1');
      await _settle();
      expect(cubit.state.branchId, 'b1');
      expect(repository.lastBranchId, 'b1');
      expect(repository.metricsCalls, metricsBefore + 1);

      cubit.clearFilters();
      await _settle();
      expect(cubit.state.search, isEmpty);
      expect(cubit.state.category, isNull);
      expect(cubit.state.statusFilter, InventoryStatusFilter.all);
      expect(cubit.state.branchId, isNull);
      expect(cubit.state.page, 0);
      expect(repository.metricsCalls, metricsBefore + 2);
    });

    test('a filter that empties the page steps back one page', () async {
      final rows = List<AdminInventoryItem>.generate(10, _item);
      final repository = _FakeInventoryRepository()
        ..pageBuilder = (page) => page >= 2
            ? const AdminInventoryPage(rows: <AdminInventoryItem>[], total: 15)
            : AdminInventoryPage(rows: rows, total: page == 0 ? 25 : 15);
      final cubit = AdminInventoryCubit(repository: repository);
      addTearDown(cubit.close);
      await cubit.load();
      expect(cubit.state.page, 0);

      cubit.setPage(2);
      await _settle();

      expect(cubit.state.page, 1);
      expect(cubit.state.items, hasLength(10));
      expect(cubit.state.total, 15);
      expect(repository.loadCalls, 3);
    });

    test('a summary failure keeps the rows usable', () async {
      final repository = _FakeInventoryRepository()
        ..items = <AdminInventoryItem>[_item(1)]
        ..total = 1
        ..metrics = AdminInventoryMetrics.empty
        ..failMetrics = true
        ..failFilters = true;
      final cubit = AdminInventoryCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.status, AdminInventoryStatus.ready);
      expect(cubit.state.items, hasLength(1));
      expect(cubit.state.metrics, AdminInventoryMetrics.empty);
      expect(cubit.state.filters.hasBranches, isFalse);
    });

    test('a row failure is retryable', () async {
      final repository = _FakeInventoryRepository()..failRows = true;
      final cubit = AdminInventoryCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.load();
      expect(cubit.state.isFailure, isTrue);
      expect(cubit.state.errorMessage, contains('rows failed'));

      repository
        ..failRows = false
        ..items = <AdminInventoryItem>[_item(1)]
        ..total = 1;
      await cubit.load();
      expect(cubit.state.status, AdminInventoryStatus.ready);
      expect(cubit.state.items, hasLength(1));
    });

    test('saving, deleting and moving refresh only on success', () async {
      final repository = _FakeInventoryRepository()
        ..items = <AdminInventoryItem>[_item(1)]
        ..total = 1;
      final cubit = AdminInventoryCubit(repository: repository);
      addTearDown(cubit.close);
      await cubit.load();
      expect(repository.loadCalls, 1);

      repository.saveOutcome = InventoryMaterialSaveOutcome.duplicateSku;
      final failed = await cubit.saveMaterial(
        const AdminInventoryDraft(nameAr: 'بن'),
      );
      expect(failed, InventoryMaterialSaveOutcome.duplicateSku);
      expect(repository.loadCalls, 1);

      repository.saveOutcome = InventoryMaterialSaveOutcome.saved;
      final saved = await cubit.saveMaterial(
        const AdminInventoryDraft(nameAr: 'بن'),
      );
      expect(saved, InventoryMaterialSaveOutcome.saved);
      expect(repository.savedDraft?.nameAr, 'بن');
      expect(repository.loadCalls, 2);

      repository.deleteOutcome = InventoryMutationOutcome.hasStock;
      final blocked = await cubit.deleteMaterial('m1');
      expect(blocked, InventoryMutationOutcome.hasStock);
      expect(repository.loadCalls, 2);

      repository.deleteOutcome = InventoryMutationOutcome.success;
      await cubit.deleteMaterial('m1');
      expect(repository.deletedId, 'm1');
      expect(repository.loadCalls, 3);

      final draft = AdminStockMovementDraft(
        materialId: 'm1',
        branchId: 'b1',
        type: InventoryMovementType.receipt,
        quantity: 3,
      );
      repository.movementOutcome = InventoryMovementOutcome.success;
      await cubit.recordMovement(draft);
      expect(repository.recordedDraft, same(draft));
      expect(repository.loadCalls, 4);
    });

    test('material search reaches the repository with the branch', () async {
      final repository = _FakeInventoryRepository()
        ..options = const <AdminInventoryMaterialOption>[
          AdminInventoryMaterialOption(id: 'm1', nameAr: 'بن', unit: 'kg'),
        ];
      final cubit = AdminInventoryCubit(repository: repository);
      addTearDown(cubit.close);

      final options = await cubit.searchMaterials(search: 'بن', branchId: 'b1');

      expect(options, hasLength(1));
      expect(repository.optionCalls, 1);
      expect(repository.lastOptionSearch, 'بن');
      expect(repository.lastOptionBranchId, 'b1');
    });
  });

  group('AdminStockMovementsCubit', () {
    test('load fetches the ledger, metrics and filters', () async {
      final repository = _FakeInventoryRepository()
        ..movements = <AdminStockMovement>[_movement(1), _movement(2)]
        ..movementTotal = 2
        ..movementMetrics = const AdminStockMovementMetrics(
          total: 2,
          receipts: 2,
          receivedValue: 300,
          actors: 1,
        );
      final cubit = AdminStockMovementsCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.status, AdminStockMovementsStatus.ready);
      expect(cubit.state.movements, hasLength(2));
      expect(cubit.state.total, 2);
      expect(cubit.state.metrics.receipts, 2);
      expect(cubit.state.filters.hasBranches, isTrue);
      expect(repository.movementLoadCalls, 1);
      expect(repository.movementMetricsCalls, 1);
      expect(repository.filtersCalls, 1);
    });

    test(
      'type resets the page while period and branch reload the metrics',
      () async {
        final repository = _FakeInventoryRepository()
          ..movements = <AdminStockMovement>[_movement(1)]
          ..movementTotal = 25;
        final cubit = AdminStockMovementsCubit(repository: repository);
        addTearDown(cubit.close);
        await cubit.load();
        cubit.setPage(1);
        await _settle();
        expect(cubit.state.page, 1);

        cubit.setType(StockMovementTypeFilter.receipt);
        await _settle();
        expect(cubit.state.type, StockMovementTypeFilter.receipt);
        expect(cubit.state.page, 0);
        expect(repository.lastType, 'receipt');

        final metricsBefore = repository.movementMetricsCalls;
        cubit.setPeriod(StockMovementPeriod.week);
        await _settle();
        expect(cubit.state.period, StockMovementPeriod.week);
        expect(repository.lastPeriod, 'week');
        expect(repository.movementMetricsCalls, metricsBefore + 1);

        cubit.setBranch('b2');
        await _settle();
        expect(cubit.state.branchId, 'b2');
        expect(repository.lastBranchId, 'b2');
        expect(repository.movementMetricsCalls, metricsBefore + 2);

        cubit.clearFilters();
        await _settle();
        expect(cubit.state.type, StockMovementTypeFilter.all);
        expect(cubit.state.period, StockMovementPeriod.all);
        expect(cubit.state.branchId, isNull);
        expect(cubit.state.page, 0);
        expect(repository.movementMetricsCalls, metricsBefore + 3);
      },
    );

    test('search, material lookup and recording refresh the ledger', () async {
      final repository = _FakeInventoryRepository()
        ..movements = <AdminStockMovement>[_movement(1)]
        ..movementTotal = 1
        ..options = const <AdminInventoryMaterialOption>[
          AdminInventoryMaterialOption(id: 'm1', nameAr: 'بن', unit: 'kg'),
        ];
      final cubit = AdminStockMovementsCubit(repository: repository);
      addTearDown(cubit.close);
      await cubit.load();
      expect(repository.movementLoadCalls, 1);

      cubit.updateSearch('بن');
      await Future<void>.delayed(const Duration(milliseconds: 420));
      expect(cubit.state.search, 'بن');
      expect(repository.movementLoadCalls, 2);
      expect(repository.lastSearch, 'بن');

      final options = await cubit.searchMaterials(search: 'بن', branchId: 'b1');
      expect(options, hasLength(1));
      expect(repository.optionCalls, 1);
      expect(repository.lastOptionBranchId, 'b1');

      await cubit.recordMovement(
        AdminStockMovementDraft(
          materialId: 'm1',
          branchId: 'b1',
          type: InventoryMovementType.issue,
          quantity: 1,
        ),
      );
      expect(repository.movementLoadCalls, 3);
      expect(repository.movementMetricsCalls, 2);
    });

    test('a ledger failure keeps its error and retries', () async {
      final repository = _FakeInventoryRepository()..failMovementRows = true;
      final cubit = AdminStockMovementsCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.load();
      expect(cubit.state.isFailure, isTrue);
      expect(cubit.state.errorMessage, contains('movements failed'));

      repository
        ..failMovementRows = false
        ..movements = <AdminStockMovement>[_movement(1)]
        ..movementTotal = 1;
      await cubit.load();
      expect(cubit.state.status, AdminStockMovementsStatus.ready);
      expect(cubit.state.movements, hasLength(1));
    });
  });
}
