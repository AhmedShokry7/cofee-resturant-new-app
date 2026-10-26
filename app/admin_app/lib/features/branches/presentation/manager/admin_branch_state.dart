import 'package:admin_app/core/models/admin_branch.dart';
import 'package:admin_app/features/branches/domain/entities/admin_branch_metrics.dart';

enum AdminBranchStatus { initial, loading, ready, failure }

class AdminBranchState {
  const AdminBranchState({
    this.status = AdminBranchStatus.initial,
    this.branches = const <AdminBranch>[],
    this.metrics = AdminBranchMetrics.empty,
    this.errorMessage,
  });

  final AdminBranchStatus status;
  final List<AdminBranch> branches;
  final AdminBranchMetrics metrics;
  final String? errorMessage;

  bool get isLoading => status == AdminBranchStatus.loading;
  bool get hasBranches => branches.isNotEmpty;

  AdminBranchState copyWith({
    AdminBranchStatus? status,
    List<AdminBranch>? branches,
    AdminBranchMetrics? metrics,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AdminBranchState(
      status: status ?? this.status,
      branches: branches ?? this.branches,
      metrics: metrics ?? this.metrics,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
