import 'package:admin_app/features/banners/domain/repositories/banner_repository.dart';

/// تحديث رابط صورة البنر.
class UpdateBannerImageUseCase {
  const UpdateBannerImageUseCase(this._repository);

  final BannerRepository _repository;

  Future<void> call(String bannerId, String? imageUrl) =>
      _repository.updateBannerImage(bannerId, imageUrl);
}
