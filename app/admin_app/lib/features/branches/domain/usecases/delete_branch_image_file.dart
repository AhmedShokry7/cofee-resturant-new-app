import 'package:admin_app/features/branches/domain/repositories/branch_repository.dart';

/// حذف ملف صورة لم يعد الفرع يستخدمه.
class DeleteBranchImageFileUseCase {
  const DeleteBranchImageFileUseCase(this._repository);

  final BranchRepository _repository;

  Future<void> call(String? imageUrl) =>
      _repository.deleteBranchImageFile(imageUrl);
}
