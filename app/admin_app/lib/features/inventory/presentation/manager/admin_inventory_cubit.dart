import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/features/inventory/di/inventory_dependencies.dart';
import 'package:admin_app/features/inventory/domain/entities/admin_inventory_draft.dart';
import 'package:admin_app/features/inventory/domain/entities/admin_inventory_filters.dart';
import 'package:admin_app/features/inventory/domain/entities/admin_inventory_item.dart';
import 'package:admin_app/features/inventory/domain/entities/admin_inventory_material_option.dart';
import 'package:admin_app/features/inventory/domain/entities/admin_inventory_metrics.dart';
import 'package:admin_app/features/inventory/domain/entities/admin_stock_movement_draft.dart';
import 'package:admin_app/features/inventory/domain/entities/inventory_material_save_outcome.dart';
import 'package:admin_app/features/inventory/domain/entities/inventory_movement_outcome.dart';
import 'package:admin_app/features/inventory/domain/entities/inventory_mutation_outcome.dart';
import 'package:admin_app/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:admin_app/features/inventory/domain/usecases/delete_material.dart';
import 'package:admin_app/features/inventory/domain/usecases/load_inventory_filters.dart';
import 'package:admin_app/features/inventory/domain/usecases/load_inventory_metrics.dart';
import 'package:admin_app/features/inventory/domain/usecases/load_inventory_page.dart';
import 'package:admin_app/features/inventory/domain/usecases/record_movement.dart';
import 'package:admin_app/features/inventory/domain/usecases/save_material.dart';
import 'package:admin_app/features/inventory/domain/usecases/search_materials.dart';
import 'package:admin_app/features/inventory/presentation/manager/admin_inventory_state.dart';
import 'package:admin_app/features/inventory/presentation/models/inventory_filters.dart';

class AdminInventoryCubit extends Cubit<AdminInventoryState> {
  AdminInventoryCubit({InventoryRepository? repository})
    : this._withUseCases(repository ?? InventoryDependencies.repository);

  AdminInventoryCubit._withUseCases(InventoryRepository repository)
    : _loadInventoryPage = LoadInventoryPageUseCase(repository),
      _loadInventoryMetrics = LoadInventoryMetricsUseCase(repository),
      _loadInventoryFilters = LoadInventoryFiltersUseCase(repository),
      _searchMaterials = SearchMaterialsUseCase(repository),
      _saveMaterial = SaveMaterialUseCase(repository),
      _deleteMaterial = DeleteMaterialUseCase(repository),
      _recordMovement = RecordMovementUseCase(repository),
      super(const AdminInventoryState());

  final LoadInventoryPageUseCase _loadInventoryPage;
  final LoadInventoryMetricsUseCase _loadInventoryMetrics;
  final LoadInventoryFiltersUseCase _loadInventoryFilters;
  final SearchMaterialsUseCase _searchMaterials;
  final SaveMaterialUseCase _saveMaterial;
  final DeleteMaterialUseCase _deleteMaterial;
  final RecordMovementUseCase _recordMovement;
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

  void setCategory(String? category) {
    final normalized = category?.trim();
    final next = normalized == null || normalized.isEmpty ? null : normalized;
    if (next == state.category) return;
    emit(state.copyWith(category: next, clearCategory: next == null, page: 0));
    _fetch(withSummary: false);
  }

  void setStatusFilter(InventoryStatusFilter filter) {
    if (filter == state.statusFilter) return;
    emit(state.copyWith(statusFilter: filter, page: 0));
    _fetch(withSummary: false);
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
        clearCategory: true,
        statusFilter: InventoryStatusFilter.all,
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
    return _searchMaterials(search: search, branchId: branchId);
  }

  Future<InventoryMaterialSaveOutcome> saveMaterial(
    AdminInventoryDraft draft,
  ) async {
    final outcome = await _saveMaterial(draft);
    if (outcome == InventoryMaterialSaveOutcome.saved) await refresh();
    return outcome;
  }

  Future<InventoryMutationOutcome> deleteMaterial(String materialId) async {
    final outcome = await _deleteMaterial(materialId);
    if (outcome == InventoryMutationOutcome.success) await refresh();
    return outcome;
  }

  Future<InventoryMovementOutcome> recordMovement(
    AdminStockMovementDraft draft,
  ) async {
    final outcome = await _recordMovement(draft);
    if (outcome == InventoryMovementOutcome.success) await refresh();
    return outcome;
  }

  Future<void> _fetch({required bool withSummary, bool first = false}) async {
    final request = ++_requestId;
    if (first) {
      emit(
        state.copyWith(
          status: AdminInventoryStatus.loading,
          clearError: true,
          isRefreshingRows: false,
        ),
      );
    } else {
      emit(state.copyWith(isRefreshingRows: true, clearError: true));
    }

    final rowsFuture = _loadInventoryPage(
      search: state.search,
      category: state.category,
      status: state.statusFilter.value,
      branchId: state.branchId,
      page: state.page,
      pageSize: state.pageSize,
    );
    final metricsFuture = withSummary
        ? _loadMetricsSafely()
        : Future<AdminInventoryMetrics?>.value(null);
    final filtersFuture = withSummary
        ? _loadFiltersSafely()
        : Future<AdminInventoryFilters?>.value(null);

    Object? pageFailure;
    var page = const AdminInventoryPage();
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
          status: state.hasItems
              ? AdminInventoryStatus.ready
              : AdminInventoryStatus.failure,
          metrics: metrics,
          filters: filters,
          isRefreshingRows: false,
          errorMessage: '$pageFailure',
        ),
      );
      return;
    }

    // A filter change can remove the last row of the current page; step back
    // to the last page that still has data instead of showing an empty page.
    final pages = page.total <= 0
        ? 0
        : (page.total + state.pageSize - 1) ~/ state.pageSize;
    if (page.rows.isEmpty && page.total > 0 && state.page >= pages) {
      emit(state.copyWith(page: pages - 1));
      return _fetch(withSummary: false);
    }

    emit(
      state.copyWith(
        status: AdminInventoryStatus.ready,
        items: page.rows,
        total: page.total,
        metrics: metrics,
        filters: filters,
        isRefreshingRows: false,
        clearError: true,
      ),
    );
  }

  Future<AdminInventoryMetrics?> _loadMetricsSafely() async {
    try {
      return await _loadInventoryMetrics(branchId: state.branchId);
    } catch (_) {
      return null;
    }
  }

  Future<AdminInventoryFilters?> _loadFiltersSafely() async {
    try {
      return await _loadInventoryFilters();
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
