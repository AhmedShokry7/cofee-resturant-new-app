import 'package:admin_app/features/audit/data/models/admin_audit_log.dart';
import 'package:admin_app/features/audit/data/models/admin_audit_metrics.dart';
import 'package:admin_app/features/audit/presentation/models/audit_filters.dart';

enum AdminAuditStatus { initial, loading, ready, failure }

class AdminAuditState {
  const AdminAuditState({
    this.status = AdminAuditStatus.initial,
    this.logs = const <AdminAuditLog>[],
    this.total = 0,
    this.metrics = AdminAuditMetrics.empty,
    this.search = '',
    this.domain = AuditDomainFilter.all,
    this.criticalOnly = false,
    this.page = 0,
    this.pageSize = 20,
    this.isRefreshingRows = false,
    this.errorMessage,
  });

  final AdminAuditStatus status;
  final List<AdminAuditLog> logs;

  /// The number of rows the server matched, across every page.
  final int total;
  final AdminAuditMetrics metrics;
  final String search;
  final AuditDomainFilter domain;
  final bool criticalOnly;
  final int page;
  final int pageSize;
  final bool isRefreshingRows;
  final String? errorMessage;

  bool get isLoading => status == AdminAuditStatus.loading;
  bool get isFailure => status == AdminAuditStatus.failure;
  bool get hasLogs => logs.isNotEmpty;

  bool get hasData => hasLogs || total > 0 || metrics.total > 0;

  int get pages => total <= 0 ? 0 : (total + pageSize - 1) ~/ pageSize;

  bool get hasActiveFilters =>
      search.trim().isNotEmpty ||
      domain != AuditDomainFilter.all ||
      criticalOnly;

  AdminAuditState copyWith({
    AdminAuditStatus? status,
    List<AdminAuditLog>? logs,
    int? total,
    AdminAuditMetrics? metrics,
    String? search,
    AuditDomainFilter? domain,
    bool? criticalOnly,
    int? page,
    bool? isRefreshingRows,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AdminAuditState(
      status: status ?? this.status,
      logs: logs ?? this.logs,
      total: total ?? this.total,
      metrics: metrics ?? this.metrics,
      search: search ?? this.search,
      domain: domain ?? this.domain,
      criticalOnly: criticalOnly ?? this.criticalOnly,
      page: page ?? this.page,
      pageSize: pageSize,
      isRefreshingRows: isRefreshingRows ?? this.isRefreshingRows,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
