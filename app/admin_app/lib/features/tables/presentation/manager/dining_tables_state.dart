import 'package:admin_app/features/tables/data/models/dining_enums.dart';
import 'package:admin_app/features/tables/data/models/dining_overview.dart';
import 'package:admin_app/features/tables/data/models/dining_reservation.dart';
import 'package:admin_app/features/tables/data/models/dining_table.dart';

enum DiningStatus { initial, loading, ready, failure }

enum DiningView { tables, reservations }

class DiningTablesState {
  const DiningTablesState({
    this.status = DiningStatus.initial,
    this.tables = const <DiningTable>[],
    this.reservations = const <DiningReservation>[],
    this.branches = const <DiningBranch>[],
    this.metrics = const DiningMetrics(),
    this.branchId,
    this.search = '',
    this.area,
    this.view = DiningView.tables,
    this.isRefreshing = false,
    this.errorMessage,
  });

  final DiningStatus status;
  final List<DiningTable> tables;
  final List<DiningReservation> reservations;
  final List<DiningBranch> branches;
  final DiningMetrics metrics;
  final String? branchId;
  final String search;

  /// Null means every area.
  final DiningArea? area;
  final DiningView view;
  final bool isRefreshing;
  final String? errorMessage;

  bool get isLoading => status == DiningStatus.loading;
  bool get isFailure => status == DiningStatus.failure;
  bool get hasData =>
      tables.isNotEmpty || reservations.isNotEmpty || metrics.tables > 0;
  bool get hasBranches => branches.isNotEmpty;

  bool get hasActiveFilters => search.trim().isNotEmpty || area != null;

  List<DiningTable> get filteredTables {
    final query = search.trim().toLowerCase();
    return tables
        .where((table) {
          if (area != null && table.area != area) return false;
          if (query.isEmpty) return true;
          if (table.name.toLowerCase().contains(query)) return true;
          if (table.note.toLowerCase().contains(query)) return true;
          if (table.activeOrder?.orderNumber.toLowerCase().contains(query) ??
              false) {
            return true;
          }
          final current = table.reservation;
          if (current != null &&
              (current.customerName.toLowerCase().contains(query) ||
                  current.customerPhone.contains(query))) {
            return true;
          }
          final next = table.nextReservation;
          if (next != null &&
              (next.customerName.toLowerCase().contains(query) ||
                  next.customerPhone.contains(query))) {
            return true;
          }
          return false;
        })
        .toList(growable: false);
  }

  List<DiningReservation> get filteredReservations {
    final query = search.trim().toLowerCase();
    return reservations
        .where((reservation) {
          if (area != null && reservation.area != area) return false;
          if (query.isEmpty) return true;
          return reservation.customerName.toLowerCase().contains(query) ||
              reservation.customerPhone.contains(query) ||
              reservation.tableName.toLowerCase().contains(query) ||
              reservation.note.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  /// Confirmed and seated bookings, earliest first.
  List<DiningReservation> get openReservations {
    final rows = filteredReservations
        .where((reservation) => reservation.isOpen)
        .toList(growable: false);
    rows.sort(_byReservedFor);
    return rows;
  }

  /// The visible history of finished bookings, newest first.
  List<DiningReservation> get closedReservations {
    final rows = filteredReservations
        .where((reservation) => reservation.isClosed)
        .toList(growable: false);
    rows.sort((a, b) => _byReservedFor(b, a));
    return rows;
  }

  List<DiningTable> get activeTables =>
      tables.where((table) => table.isActive).toList(growable: false);

  int tableCountFor(DiningArea value) =>
      tables.where((table) => table.area == value).length;

  DiningBranch? get selectedBranch {
    for (final branch in branches) {
      if (branch.id == branchId) return branch;
    }
    return null;
  }

  DiningTable? tableById(String? id) {
    if (id == null) return null;
    for (final table in tables) {
      if (table.id == id) return table;
    }
    return null;
  }

  static int _byReservedFor(DiningReservation a, DiningReservation b) {
    final left = a.reservedFor;
    final right = b.reservedFor;
    if (left == null && right == null) return 0;
    if (left == null) return 1;
    if (right == null) return -1;
    return left.compareTo(right);
  }

  DiningTablesState copyWith({
    DiningStatus? status,
    List<DiningTable>? tables,
    List<DiningReservation>? reservations,
    List<DiningBranch>? branches,
    DiningMetrics? metrics,
    String? branchId,
    bool clearBranch = false,
    String? search,
    DiningArea? area,
    bool clearArea = false,
    DiningView? view,
    bool? isRefreshing,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DiningTablesState(
      status: status ?? this.status,
      tables: tables ?? this.tables,
      reservations: reservations ?? this.reservations,
      branches: branches ?? this.branches,
      metrics: metrics ?? this.metrics,
      branchId: clearBranch ? null : (branchId ?? this.branchId),
      search: search ?? this.search,
      area: clearArea ? null : (area ?? this.area),
      view: view ?? this.view,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
