import 'package:admin_app/features/branches/domain/entities/branch_mutation_outcome.dart';
import 'package:admin_app/features/branches/domain/repositories/branch_repository.dart';

/// حذف فرع.
class DeleteBranchUseCase {
  const DeleteBranchUseCase(this._repository);

  final BranchRepository _repository;

  Future<BranchMutationOutcome> call(String branchId) =>
      _repository.deleteBranch(branchId);
}
