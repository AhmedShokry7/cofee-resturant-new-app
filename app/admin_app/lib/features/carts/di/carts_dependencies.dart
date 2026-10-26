import 'package:admin_app/features/carts/data/repositories/admin_cart_repository.dart';
import 'package:admin_app/features/carts/domain/repositories/cart_repository.dart';

/// نقطة تركيب اعتمادات فيتشر السلات داخل الفيتشر نفسه،
/// فلا تستورد طبقة العرض `data/repositories` مباشرة.
abstract final class CartsDependencies {
  CartsDependencies._();

  static CartRepository? _repository;

  /// نسخة مشتركة من العقد تُبنى عند أول استخدام.
  static CartRepository get repository => _repository ??= AdminCartRepository();
}
