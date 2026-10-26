import 'package:admin_app/features/branches/domain/entities/branch_mutation_outcome.dart';
import 'package:admin_app/features/branches/domain/repositories/branch_repository.dart';

/// تفعيل فرع أو تعطيله.
class SetBranchActiveUseCase {
  const SetBranchActiveUseCase(this._repository);

  final BranchRepository _repository;

  Future<BranchMutationOutcome> call(String branchId, bool active) =>
      _repository.setBranchActive(branchId, active);
}
