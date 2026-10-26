import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/features/inventory/data/models/admin_inventory_filters.dart';
import 'package:admin_app/features/inventory/data/models/admin_inventory_material_option.dart';
import 'package:admin_app/features/inventory/data/models/admin_stock_movement.dart';
import 'package:admin_app/features/inventory/data/models/admin_stock_movement_draft.dart';
import 'package:admin_app/features/inventory/data/models/admin_stock_movement_metrics.dart';
import 'package:admin_app/features/inventory/data/repositories/admin_inventory_repository.dart';
import 'package:admin_app/features/inventory/presentation/manager/admin_stock_movements_state.dart';
import 'package:admin_app/features/inventory/presentation/models/inventory_filters.dart';

class AdminStockMovementsCubit extends Cubit<AdminStockMovementsState> {
  AdminStockMovementsCubit({AdminInventoryRepository? repository})
    : _repository = repository ?? AdminInventoryRepository(),
      super(const AdminStockMovementsState());

  final AdminInventoryRepository _repository;
  Timer? _searchTimer;
  int _requestId = 0;

  Future<void> load() async {
    if (state.isLoading) return;
    await _fetch(withSummary: true, first: true);
  }

  Future<void> refresh() => _fetch(withSummary: true);

  void updateSearch(String value) {
    final normalized = value.trim();
    if (normalized == state.search) return;
    emit(state.copyWith(search: normalized, page: 0));
    _searchTimer?.cancel();
    if (normalized.isEmpty) {
      _fetch(withSummary: false);
      return;
    }
    _searchTimer = Timer(
      const Duration(milliseconds: 350),
      () => _fetch(withSummary: false),
    );
  }

  void setType(StockMovementTypeFilter type) {
    if (type == state.type) return;
    emit(state.copyWith(type: type, page: 0));
    _fetch(withSummary: false);
  }

  void setPeriod(StockMovementPeriod period) {
    if (period == state.period) return;
    emit(state.copyWith(period: period, page: 0));
    _fetch(withSummary: true);
  }

  void setBranch(String? branchId) {
    if (branchId == state.branchId) return;
    emit(
      state.copyWith(
        branchId: branchId,
        clearBranch: branchId == null,
        page: 0,
      ),
    );
    _fetch(withSummary: true);
  }

  void setPage(int page) {
    final maxPage = state.pages == 0 ? 0 : state.pages - 1;
    final target = page.clamp(0, maxPage);
    if (target == state.page) return;
    emit(state.copyWith(page: target));
    _fetch(withSummary: false);
  }

  void clearFilters() {
    _searchTimer?.cancel();
    if (!state.hasActiveFilters) return;
    emit(
      state.copyWith(
        search: '',
        type: StockMovementTypeFilter.all,
        period: StockMovementPeriod.all,
        clearBranch: true,
        page: 0,
      ),
    );
    _fetch(withSummary: true);
  }

  Future<List<AdminInventoryMaterialOption>> searchMaterials({
    String? search,
    String? branchId,
  }) {
    return _repository.searchMaterials(search: search, branchId: branchId);
  }

  Future<InventoryMovementOutcome> recordMovement(
    AdminStockMovementDraft draft,
  ) async {
    final outcome = await _repository.recordMovement(draft);
    if (outcome == InventoryMovementOutcome.success) await refresh();
    return outcome;
  }

  Future<void> _fetch({required bool withSummary, bool first = false}) async {
    final request = ++_requestId;
    if (first) {
      emit(
        state.copyWith(
          status: AdminStockMovementsStatus.loading,
          clearError: true,
          isRefreshingRows: false,
        ),
      );
    } else {
      emit(state.copyWith(isRefreshingRows: true, clearError: true));
    }

    final rowsFuture = _repository.loadMovements(
      search: state.search,
      type: state.type.value,
      period: state.period.value,
      branchId: state.branchId,
      page: state.page,
      pageSize: state.pageSize,
    );
    final metricsFuture = withSummary
        ? _loadMetricsSafely()
        : Future<AdminStockMovementMetrics?>.value(null);
    final filtersFuture = withSummary
        ? _loadFiltersSafely()
        : Future<AdminInventoryFilters?>.value(null);

    Object? pageFailure;
    var page = const AdminStockMovementPage();
    try {
      page = await rowsFuture;
    } catch (error) {
      pageFailure = error;
    }
    final metrics = await metricsFuture;
    final filters = await filtersFuture;
    if (isClosed || request != _requestId) return;

    if (pageFailure != null) {
      emit(
        state.copyWith(
          status: state.hasMovements
              ? AdminStockMovementsStatus.ready
              : AdminStockMovementsStatus.failure,
          metrics: metrics,
          filters: filters,
          isRefreshingRows: false,
          errorMessage: '$pageFailure',
        ),
      );
      return;
    }

    final pages = page.total <= 0
        ? 0
        : (page.total + state.pageSize - 1) ~/ state.pageSize;
    if (page.rows.isEmpty && page.total > 0 && state.page >= pages) {
      emit(state.copyWith(page: pages - 1));
      return _fetch(withSummary: false);
    }

    emit(
      state.copyWith(
        status: AdminStockMovementsStatus.ready,
        movements: page.rows,
        total: page.total,
        metrics: metrics,
        filters: filters,
        isRefreshingRows: false,
        clearError: true,
      ),
    );
  }

  Future<AdminStockMovementMetrics?> _loadMetricsSafely() async {
    try {
      return await _repository.loadMovementMetrics(
        branchId: state.branchId,
        period: state.period.value,
      );
    } catch (_) {
      return null;
    }
  }

  Future<AdminInventoryFilters?> _loadFiltersSafely() async {
    try {
      return await _repository.loadFilters();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> close() {
    _searchTimer?.cancel();
    return super.close();
  }
}
