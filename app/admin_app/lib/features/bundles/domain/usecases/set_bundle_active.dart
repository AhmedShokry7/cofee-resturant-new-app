import 'package:admin_app/features/bundles/domain/repositories/bundle_repository.dart';

/// تنشيط الباقة أو إيقافها.
class SetBundleActiveUseCase {
  const SetBundleActiveUseCase(this._repository);

  final BundleRepository _repository;

  Future<void> call(String bundleId, bool isActive) =>
      _repository.setBundleActive(bundleId, isActive);
}
