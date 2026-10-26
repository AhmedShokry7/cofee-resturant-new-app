import 'package:admin_app/core/models/admin_delivery_zone.dart';
import 'package:admin_app/features/delivery_zones/domain/repositories/zone_repository.dart';

/// حفظ منطقة توصيل وربطها بفرع.
class SaveZoneForBranchUseCase {
  const SaveZoneForBranchUseCase(this._repository);

  final ZoneRepository _repository;

  Future<AdminDeliveryZone> call({
    required String branchId,
    required AdminDeliveryZone zone,
  }) => _repository.saveForBranch(branchId: branchId, zone: zone);
}
