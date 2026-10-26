import 'package:admin_app/features/branches/domain/entities/branch_mutation_outcome.dart';
import 'package:admin_app/features/branches/domain/repositories/branch_repository.dart';

/// ربط صورة بفرع أو مسح رابطها.
class SetBranchImageUseCase {
  const SetBranchImageUseCase(this._repository);

  final BranchRepository _repository;

  Future<BranchMutationOutcome> call(String branchId, String? imageUrl) =>
      _repository.setBranchImage(branchId, imageUrl);
}
