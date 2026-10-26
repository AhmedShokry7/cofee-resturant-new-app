import 'package:admin_app/features/bundles/data/repositories/admin_bundle_repository.dart';
import 'package:admin_app/features/bundles/domain/repositories/bundle_repository.dart';

/// نقطة تركيب اعتمادات فيتشر الباقات داخل الفيتشر نفسه،
/// فلا تستورد طبقة العرض `data/repositories` مباشرة.
abstract final class BundlesDependencies {
  BundlesDependencies._();

  static BundleRepository? _repository;

  /// نسخة مشتركة من العقد تُبنى عند أول استخدام.
  static BundleRepository get repository =>
      _repository ??= AdminBundleRepository();
}
