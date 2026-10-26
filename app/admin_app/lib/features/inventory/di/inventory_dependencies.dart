import 'package:admin_app/features/inventory/data/repositories/admin_inventory_repository.dart';
import 'package:admin_app/features/inventory/domain/repositories/inventory_repository.dart';

/// نقطة تركيب اعتمادات فيتشر المخزون داخل الفيتشر نفسه،
/// فلا تستورد طبقة العرض `data/repositories` مباشرة.
abstract final class InventoryDependencies {
  InventoryDependencies._();

  static InventoryRepository? _repository;

  /// نسخة مشتركة من العقد تُبنى عند أول استخدام.
  static InventoryRepository get repository =>
      _repository ??= AdminInventoryRepository();
}
