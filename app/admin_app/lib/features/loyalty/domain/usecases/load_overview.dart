import 'package:admin_app/features/loyalty/domain/entities/admin_loyalty_overview.dart';
import 'package:admin_app/features/loyalty/domain/repositories/loyalty_repository.dart';

/// قراءة ملخص برنامج الولاء.
class LoadOverviewUseCase {
  const LoadOverviewUseCase(this._repository);

  final LoyaltyRepository _repository;

  Future<AdminLoyaltyOverview> call() => _repository.loadOverview();
}
