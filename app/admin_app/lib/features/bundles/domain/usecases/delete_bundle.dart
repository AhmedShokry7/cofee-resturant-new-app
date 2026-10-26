import 'package:admin_app/features/bundles/domain/repositories/bundle_repository.dart';

/// حذف باقة بعد فحص القاعدة.
class DeleteBundleUseCase {
  const DeleteBundleUseCase(this._repository);

  final BundleRepository _repository;

  Future<void> call(String bundleId) => _repository.deleteBundle(bundleId);
}
