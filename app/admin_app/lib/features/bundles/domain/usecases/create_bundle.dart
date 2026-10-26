import 'package:admin_app/features/bundles/domain/entities/admin_bundle.dart';
import 'package:admin_app/features/bundles/domain/repositories/bundle_repository.dart';

/// إنشاء باقة جديدة.
class CreateBundleUseCase {
  const CreateBundleUseCase(this._repository);

  final BundleRepository _repository;

  Future<AdminBundle> call(AdminBundle bundle) =>
      _repository.createBundle(bundle);
}
