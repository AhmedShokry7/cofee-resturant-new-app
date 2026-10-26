import 'package:admin_app/features/banners/domain/repositories/banner_repository.dart';

/// نشر البنر أو إخفاؤه.
class SetPublishedUseCase {
  const SetPublishedUseCase(this._repository);

  final BannerRepository _repository;

  Future<void> call(String id, bool value) =>
      _repository.setPublished(id, value);
}
