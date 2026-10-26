import 'package:admin_app/features/banners/domain/entities/admin_banner.dart';
import 'package:admin_app/features/banners/domain/repositories/banner_repository.dart';

/// تعديل بيانات بنر قائم.
class UpdateBannerUseCase {
  const UpdateBannerUseCase(this._repository);

  final BannerRepository _repository;

  Future<void> call(AdminBanner banner) => _repository.updateBanner(banner);
}
