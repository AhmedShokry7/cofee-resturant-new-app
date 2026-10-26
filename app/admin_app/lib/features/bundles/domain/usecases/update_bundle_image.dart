import 'package:admin_app/features/bundles/domain/repositories/bundle_repository.dart';

/// ربط الباقة بصورة أخرى.
class UpdateBundleImageUseCase {
  const UpdateBundleImageUseCase(this._repository);

  final BundleRepository _repository;

  Future<void> call(String bundleId, String? imageUrl) =>
      _repository.updateBundleImage(bundleId, imageUrl);
}
