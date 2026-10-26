import 'package:admin_app/features/banners/domain/entities/admin_banner.dart';
import 'package:admin_app/features/banners/domain/repositories/banner_repository.dart';

/// قراءة كل البنرات.
class LoadBannersUseCase {
  const LoadBannersUseCase(this._repository);

  final BannerRepository _repository;

  Future<List<AdminBanner>> call() => _repository.loadBanners();
}
