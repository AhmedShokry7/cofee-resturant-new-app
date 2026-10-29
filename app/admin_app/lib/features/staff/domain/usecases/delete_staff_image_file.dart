import 'package:admin_app/features/staff/domain/repositories/staff_repository.dart';

/// حذف ملف صورة لم يعد الموظف يشير إليه.
class DeleteStaffImageFileUseCase {
  const DeleteStaffImageFileUseCase(this._repository);

  final StaffRepository _repository;

  Future<void> call(String? displayedUrl) =>
      _repository.deleteStaffImageFile(displayedUrl);
}
