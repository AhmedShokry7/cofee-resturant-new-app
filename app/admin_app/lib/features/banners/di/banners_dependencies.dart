import 'package:admin_app/features/banners/data/repositories/admin_banner_repository.dart';
import 'package:admin_app/features/banners/domain/repositories/banner_repository.dart';

/// نقطة تركيب اعتمادات فيتشر البنرات داخل الفيتشر نفسه،
/// فلا تستورد طبقة العرض `data/repositories` مباشرة.
abstract final class BannersDependencies {
  BannersDependencies._();

  static BannerRepository? _repository;

  /// نسخة مشتركة من العقد تُبنى عند أول استخدام.
  static BannerRepository get repository =>
      _repository ??= AdminBannerRepository();
}
