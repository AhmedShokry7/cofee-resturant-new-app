import 'dart:typed_data';

import 'package:admin_app/core/models/admin_product_image.dart';
import 'package:admin_app/features/staff/domain/entities/staff_edit_outcome.dart';
import 'package:admin_app/features/staff/domain/repositories/staff_repository.dart';

/// رفع ملف صورة إلى مجلد الموظف ثم تسجيل مساره.
class UploadStaffImageUseCase {
  const UploadStaffImageUseCase(this._repository);

  final StaffRepository _repository;

  Future<StaffEditOutcome> call({
    required String staffId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    String? replaces,
    void Function(AdminImageUploadPhase phase)? onPhase,
  }) => _repository.uploadStaffImage(
    staffId: staffId,
    bytes: bytes,
    fileName: fileName,
    contentType: contentType,
    replaces: replaces,
    onPhase: onPhase,
  );
}
