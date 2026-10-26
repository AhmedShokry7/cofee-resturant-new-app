import 'package:admin_app/features/loyalty/data/repositories/admin_loyalty_repository.dart';
import 'package:admin_app/features/loyalty/domain/repositories/loyalty_repository.dart';

/// نقطة تركيب اعتمادات فيتشر الولاء داخل الفيتشر نفسه،
/// فلا تستورد طبقة العرض `data/repositories` مباشرة.
abstract final class LoyaltyDependencies {
  LoyaltyDependencies._();

  static LoyaltyRepository? _repository;

  /// نسخة مشتركة من العقد تُبنى عند أول استخدام.
  static LoyaltyRepository get repository =>
      _repository ??= AdminLoyaltyRepository();
}
