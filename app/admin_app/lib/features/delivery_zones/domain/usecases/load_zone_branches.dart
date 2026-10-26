import 'package:admin_app/features/delivery_zones/domain/repositories/zone_repository.dart';

/// قراءة ربط المناطق بالفروع.
class LoadZoneBranchesUseCase {
  const LoadZoneBranchesUseCase(this._repository);

  final ZoneRepository _repository;

  Future<List<Map<String, dynamic>>> call() => _repository.loadZoneBranches();
}
