import 'dart:typed_data';

import 'package:admin_app/core/models/admin_product_image.dart';
import 'package:admin_app/features/bundles/domain/repositories/bundle_repository.dart';

/// رفع صورة الباقة وحفظ رابطها.
class UploadBundleImageUseCase {
  const UploadBundleImageUseCase(this._repository);

  final BundleRepository _repository;

  Future<String> call({
    String? bundleId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    void Function(AdminImageUploadPhase phase)? onPhase,
  }) => _repository.uploadBundleImage(
    bundleId: bundleId,
    bytes: bytes,
    fileName: fileName,
    contentType: contentType,
    onPhase: onPhase,
  );
}
