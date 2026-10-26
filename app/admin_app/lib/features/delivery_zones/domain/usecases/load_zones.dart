import 'package:admin_app/core/models/admin_delivery_zone.dart';
import 'package:admin_app/features/delivery_zones/domain/repositories/zone_repository.dart';

/// قراءة كل مناطق التوصيل.
class LoadZonesUseCase {
  const LoadZonesUseCase(this._repository);

  final ZoneRepository _repository;

  Future<List<AdminDeliveryZone>> call() => _repository.loadZones();
}
