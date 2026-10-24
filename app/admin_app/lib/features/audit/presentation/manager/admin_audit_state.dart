import 'package:admin_app/features/audit/data/models/admin_audit_log.dart';

enum AdminAuditStatus { initial, loading, ready, failure }

class AdminAuditState {
  const AdminAuditState({
    this.status = AdminAuditStatus.initial,
    this.logs = const <AdminAuditLog>[],
    this.errorMessage,
  });

  final AdminAuditStatus status;
  final List<AdminAuditLog> logs;
  final String? errorMessage;

  bool get isLoading => status == AdminAuditStatus.loading;
  bool get hasLogs => logs.isNotEmpty;

  AdminAuditState copyWith({
    AdminAuditStatus? status,
    List<AdminAuditLog>? logs,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AdminAuditState(
      status: status ?? this.status,
      logs: logs ?? this.logs,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
