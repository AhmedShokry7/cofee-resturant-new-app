import 'dart:typed_data';

import 'package:admin_app/features/notifications/domain/repositories/notifications_repository.dart';

/// يرفع صورة الحملة ويعيد رابطها العام الذي سيضعه الدفع في الإشعار.
class UploadCampaignImageUseCase {
  const UploadCampaignImageUseCase(this._repository);

  final NotificationsRepository _repository;

  Future<String> call({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) => _repository.uploadCampaignImage(
    bytes: bytes,
    fileName: fileName,
    contentType: contentType,
  );
}

/// يتخلى عن صورة مرفوعة لم تُرسل، فلا تبقى في الدلو بلا صف يشير إليها.
class DiscardCampaignImageUseCase {
  const DiscardCampaignImageUseCase(this._repository);

  final NotificationsRepository _repository;

  Future<void> call(String? imageUrl) =>
      _repository.deleteCampaignImageFile(imageUrl);
}
