import 'package:admin_app/features/inventory/data/models/admin_inventory_filters.dart';
import 'package:admin_app/features/inventory/data/models/admin_stock_movement.dart';
import 'package:admin_app/features/inventory/data/models/admin_stock_movement_metrics.dart';
import 'package:admin_app/features/inventory/presentation/models/inventory_filters.dart';

enum AdminStockMovementsStatus { initial, loading, ready, failure }

class AdminStockMovementsState {
  const AdminStockMovementsState({
    this.status = AdminStockMovementsStatus.initial,
    this.movements = const <AdminStockMovement>[],
    this.total = 0,
    this.metrics = AdminStockMovementMetrics.empty,
    this.filters = AdminInventoryFilters.empty,
    this.search = '',
    this.type = StockMovementTypeFilter.all,
    this.period = StockMovementPeriod.all,
    this.branchId,
    this.page = 0,
    this.pageSize = 10,
    this.isRefreshingRows = false,
    this.errorMessage,
  });

  final AdminStockMovementsStatus status;
  final List<AdminStockMovement> movements;

  /// The number of movements the server matched, across every page.
  final int total;
  final AdminStockMovementMetrics metrics;
  final AdminInventoryFilters filters;
  final String search;
  final StockMovementTypeFilter type;
  final StockMovementPeriod period;

  /// Null means every branch in the caller scope.
  final String? branchId;
  final int page;
  final int pageSize;
  final bool isRefreshingRows;
  final String? errorMessage;

  bool get isLoading => status == AdminStockMovementsStatus.loading;
  bool get isFailure => status == AdminStockMovementsStatus.failure;
  bool get hasMovements => movements.isNotEmpty;

  bool get hasData =>
      hasMovements || total > 0 || metrics.total > 0 || filters.hasBranches;

  int get pages => total <= 0 ? 0 : (total + pageSize - 1) ~/ pageSize;

  bool get hasActiveFilters =>
      search.trim().isNotEmpty ||
      type != StockMovementTypeFilter.all ||
      period != StockMovementPeriod.all ||
      branchId != null;

  AdminStockMovementsState copyWith({
    AdminStockMovementsStatus? status,
    List<AdminStockMovement>? movements,
    int? total,
    AdminStockMovementMetrics? metrics,
    AdminInventoryFilters? filters,
    String? search,
    StockMovementTypeFilter? type,
    StockMovementPeriod? period,
    String? branchId,
    bool clearBranch = false,
    int? page,
    bool? isRefreshingRows,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AdminStockMovementsState(
      status: status ?? this.status,
      movements: movements ?? this.movements,
      total: total ?? this.total,
      metrics: metrics ?? this.metrics,
      filters: filters ?? this.filters,
      search: search ?? this.search,
      type: type ?? this.type,
      period: period ?? this.period,
      branchId: clearBranch ? null : (branchId ?? this.branchId),
      page: page ?? this.page,
      pageSize: pageSize,
      isRefreshingRows: isRefreshingRows ?? this.isRefreshingRows,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
