import 'dart:typed_data';

import 'package:admin_app/features/banners/domain/repositories/banner_repository.dart';

/// رفع صورة البنر والحصول على رابطها العام.
class UploadBannerImageUseCase {
  const UploadBannerImageUseCase(this._repository);

  final BannerRepository _repository;

  Future<String> call({
    String? bannerId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) => _repository.uploadBannerImage(
    bannerId: bannerId,
    bytes: bytes,
    fileName: fileName,
    contentType: contentType,
  );
}
