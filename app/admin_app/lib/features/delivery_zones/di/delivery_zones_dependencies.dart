import 'package:admin_app/features/delivery_zones/data/repositories/admin_delivery_zone_repository.dart';
import 'package:admin_app/features/delivery_zones/domain/repositories/zone_repository.dart';

/// نقطة تركيب اعتمادات فيتشر مناطق التوصيل داخل الفيتشر نفسه،
/// فلا تستورد طبقة العرض `data/repositories` مباشرة.
abstract final class DeliveryZonesDependencies {
  DeliveryZonesDependencies._();

  static ZoneRepository? _repository;

  /// نسخة مشتركة من العقد تُبنى عند أول استخدام.
  static ZoneRepository get repository =>
      _repository ??= AdminDeliveryZoneRepository();
}
