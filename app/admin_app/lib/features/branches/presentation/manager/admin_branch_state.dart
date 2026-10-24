import 'package:admin_app/features/branches/data/models/admin_branch.dart';

enum AdminBranchStatus { initial, loading, ready, failure }

class AdminBranchState {
  const AdminBranchState({
    this.status = AdminBranchStatus.initial,
    this.branches = const <AdminBranch>[],
    this.errorMessage,
  });

  final AdminBranchStatus status;
  final List<AdminBranch> branches;
  final String? errorMessage;

  bool get isLoading => status == AdminBranchStatus.loading;
  bool get hasBranches => branches.isNotEmpty;

  AdminBranchState copyWith({
    AdminBranchStatus? status,
    List<AdminBranch>? branches,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AdminBranchState(
      status: status ?? this.status,
      branches: branches ?? this.branches,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
