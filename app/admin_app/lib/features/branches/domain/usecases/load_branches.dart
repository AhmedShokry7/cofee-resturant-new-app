import 'package:admin_app/core/models/admin_branch.dart';
import 'package:admin_app/features/branches/domain/repositories/branch_repository.dart';

/// قراءة كل فروع العلامة.
class LoadBranchesUseCase {
  const LoadBranchesUseCase(this._repository);

  final BranchRepository _repository;

  Future<List<AdminBranch>> call() => _repository.loadBranches();
}
