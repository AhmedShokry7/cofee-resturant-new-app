import 'package:admin_app/features/branches/domain/entities/admin_branch_draft.dart';
import 'package:admin_app/features/branches/domain/entities/branch_save_outcome.dart';
import 'package:admin_app/features/branches/domain/repositories/branch_repository.dart';

/// حفظ فرع جديد أو تعديل فرع.
class SaveBranchUseCase {
  const SaveBranchUseCase(this._repository);

  final BranchRepository _repository;

  Future<BranchSaveOutcome> call(AdminBranchDraft draft) =>
      _repository.saveBranch(draft);
}
