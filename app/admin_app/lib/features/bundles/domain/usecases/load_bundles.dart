import 'package:admin_app/features/bundles/domain/entities/admin_bundle.dart';
import 'package:admin_app/features/bundles/domain/repositories/bundle_repository.dart';

/// قراءة كل الباقات مع مكوّناتها.
class LoadBundlesUseCase {
  const LoadBundlesUseCase(this._repository);

  final BundleRepository _repository;

  Future<List<AdminBundle>> call() => _repository.loadBundles();
}
