import 'dart:typed_data';

import 'package:admin_app/core/models/admin_product_image.dart';
import 'package:admin_app/features/branches/domain/entities/branch_mutation_outcome.dart';
import 'package:admin_app/features/branches/domain/repositories/branch_repository.dart';

/// رفع صورة الفرع وربطها به.
class UploadBranchImageUseCase {
  const UploadBranchImageUseCase(this._repository);

  final BranchRepository _repository;

  Future<BranchMutationOutcome> call({
    required String branchId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    void Function(AdminImageUploadPhase phase)? onPhase,
  }) => _repository.uploadBranchImage(
    branchId: branchId,
    bytes: bytes,
    fileName: fileName,
    contentType: contentType,
    onPhase: onPhase,
  );
}
