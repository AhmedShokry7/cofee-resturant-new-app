import 'package:admin_app/features/banners/domain/repositories/banner_repository.dart';

/// حذف بنر قائم.
class DeleteBannerUseCase {
  const DeleteBannerUseCase(this._repository);

  final BannerRepository _repository;

  Future<void> call(String id) => _repository.deleteBanner(id);
}
