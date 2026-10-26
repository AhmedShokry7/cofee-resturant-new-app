import 'package:admin_app/features/kitchen/domain/entities/admin_kitchen_filters.dart';
import 'package:admin_app/features/kitchen/domain/entities/admin_kitchen_metrics.dart';
import 'package:admin_app/features/kitchen/domain/entities/admin_kitchen_ticket.dart';

enum AdminKitchenStatus { initial, loading, ready, failure }

class AdminKitchenState {
  const AdminKitchenState({
    this.status = AdminKitchenStatus.initial,
    this.tickets = const <AdminKitchenTicket>[],
    this.total = 0,
    this.metrics = AdminKitchenMetrics.empty,
    this.filters = AdminKitchenFilters.empty,
    this.search = '',
    this.branchId,
    this.isRefreshing = false,
    this.busyTicketIds = const <String>{},
    this.busyItemIds = const <String>{},
    this.lastUpdatedAt,
    this.now,
    this.errorMessage,
  });

  final AdminKitchenStatus status;
  final List<AdminKitchenTicket> tickets;
  final int total;
  final AdminKitchenMetrics metrics;
  final AdminKitchenFilters filters;
  final String search;

  /// Null means every branch in the caller scope.
  final String? branchId;
  final bool isRefreshing;
  final Set<String> busyTicketIds;
  final Set<String> busyItemIds;
  final DateTime? lastUpdatedAt;

  /// The clock the cards use for the live elapsed timer.
  final DateTime? now;
  final String? errorMessage;

  bool get isLoading => status == AdminKitchenStatus.loading;
  bool get isFailure => status == AdminKitchenStatus.failure;
  bool get hasTickets => tickets.isNotEmpty;

  bool get hasData =>
      hasTickets ||
      metrics.active > 0 ||
      metrics.completedToday > 0 ||
      filters.hasBranches;

  bool get hasActiveFilters => search.trim().isNotEmpty || branchId != null;

  bool isTicketBusy(String id) => busyTicketIds.contains(id);

  bool isItemBusy(String id) => busyItemIds.contains(id);

  List<AdminKitchenTicket> ticketsFor(KitchenTicketStatus status) => tickets
      .where((ticket) => ticket.status == status)
      .toList(growable: false);

  AdminKitchenState copyWith({
    AdminKitchenStatus? status,
    List<AdminKitchenTicket>? tickets,
    int? total,
    AdminKitchenMetrics? metrics,
    AdminKitchenFilters? filters,
    String? search,
    String? branchId,
    bool clearBranch = false,
    bool? isRefreshing,
    Set<String>? busyTicketIds,
    Set<String>? busyItemIds,
    DateTime? lastUpdatedAt,
    DateTime? now,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AdminKitchenState(
      status: status ?? this.status,
      tickets: tickets ?? this.tickets,
      total: total ?? this.total,
      metrics: metrics ?? this.metrics,
      filters: filters ?? this.filters,
      search: search ?? this.search,
      branchId: clearBranch ? null : (branchId ?? this.branchId),
      isRefreshing: isRefreshing ?? this.isRefreshing,
      busyTicketIds: busyTicketIds ?? this.busyTicketIds,
      busyItemIds: busyItemIds ?? this.busyItemIds,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      now: now ?? this.now,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
