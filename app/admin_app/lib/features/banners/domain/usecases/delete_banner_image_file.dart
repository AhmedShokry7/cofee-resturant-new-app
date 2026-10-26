import 'package:admin_app/features/banners/domain/repositories/banner_repository.dart';

/// حذف ملف صورة البنر.
class DeleteBannerImageFileUseCase {
  const DeleteBannerImageFileUseCase(this._repository);

  final BannerRepository _repository;

  Future<void> call(String? imageUrl) =>
      _repository.deleteBannerImageFile(imageUrl);
}
