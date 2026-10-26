import 'package:admin_app/features/kitchen/data/repositories/admin_kitchen_repository.dart';
import 'package:admin_app/features/kitchen/domain/repositories/kitchen_repository.dart';

/// نقطة تركيب اعتمادات فيتشر المطبخ داخل الفيتشر نفسه،
/// فلا تستورد طبقة العرض `data/repositories` مباشرة.
abstract final class KitchenDependencies {
  KitchenDependencies._();

  static KitchenRepository? _repository;

  /// نسخة مشتركة من العقد تُبنى عند أول استخدام.
  static KitchenRepository get repository =>
      _repository ??= AdminKitchenRepository();
}
