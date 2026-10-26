import 'package:admin_app/features/banners/domain/entities/admin_banner.dart';
import 'package:admin_app/features/banners/domain/repositories/banner_repository.dart';

/// إنشاء بنر جديد.
class CreateBannerUseCase {
  const CreateBannerUseCase(this._repository);

  final BannerRepository _repository;

  Future<AdminBanner> call(AdminBanner banner) =>
      _repository.createBanner(banner);
}
