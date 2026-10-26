import 'package:admin_app/features/inventory/domain/entities/admin_inventory_filters.dart';
import 'package:admin_app/features/inventory/domain/entities/admin_inventory_item.dart';
import 'package:admin_app/features/inventory/domain/entities/admin_inventory_metrics.dart';
import 'package:admin_app/features/inventory/presentation/models/inventory_filters.dart';

enum AdminInventoryStatus { initial, loading, ready, failure }

class AdminInventoryState {
  const AdminInventoryState({
    this.status = AdminInventoryStatus.initial,
    this.items = const <AdminInventoryItem>[],
    this.total = 0,
    this.metrics = AdminInventoryMetrics.empty,
    this.filters = AdminInventoryFilters.empty,
    this.search = '',
    this.category,
    this.statusFilter = InventoryStatusFilter.all,
    this.branchId,
    this.page = 0,
    this.pageSize = 10,
    this.isRefreshingRows = false,
    this.errorMessage,
  });

  final AdminInventoryStatus status;
  final List<AdminInventoryItem> items;

  /// The number of materials the server matched, across every page.
  final int total;
  final AdminInventoryMetrics metrics;
  final AdminInventoryFilters filters;
  final String search;
  final String? category;
  final InventoryStatusFilter statusFilter;

  /// Null means every branch in the caller scope.
  final String? branchId;
  final int page;
  final int pageSize;
  final bool isRefreshingRows;
  final String? errorMessage;

  bool get isLoading => status == AdminInventoryStatus.loading;
  bool get isFailure => status == AdminInventoryStatus.failure;
  bool get hasItems => items.isNotEmpty;

  bool get hasData =>
      hasItems || total > 0 || metrics.total > 0 || filters.hasBranches;

  int get pages => total <= 0 ? 0 : (total + pageSize - 1) ~/ pageSize;

  bool get hasActiveFilters =>
      search.trim().isNotEmpty ||
      (category != null && category!.trim().isNotEmpty) ||
      statusFilter != InventoryStatusFilter.all ||
      branchId != null;

  AdminInventoryState copyWith({
    AdminInventoryStatus? status,
    List<AdminInventoryItem>? items,
    int? total,
    AdminInventoryMetrics? metrics,
    AdminInventoryFilters? filters,
    String? search,
    String? category,
    bool clearCategory = false,
    InventoryStatusFilter? statusFilter,
    String? branchId,
    bool clearBranch = false,
    int? page,
    bool? isRefreshingRows,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AdminInventoryState(
      status: status ?? this.status,
      items: items ?? this.items,
      total: total ?? this.total,
      metrics: metrics ?? this.metrics,
      filters: filters ?? this.filters,
      search: search ?? this.search,
      category: clearCategory ? null : (category ?? this.category),
      statusFilter: statusFilter ?? this.statusFilter,
      branchId: clearBranch ? null : (branchId ?? this.branchId),
      page: page ?? this.page,
      pageSize: pageSize,
      isRefreshingRows: isRefreshingRows ?? this.isRefreshingRows,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
