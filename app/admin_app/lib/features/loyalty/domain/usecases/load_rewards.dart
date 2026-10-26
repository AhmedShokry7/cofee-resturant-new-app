import 'package:admin_app/features/loyalty/domain/entities/admin_loyalty_reward.dart';
import 'package:admin_app/features/loyalty/domain/repositories/loyalty_repository.dart';

/// قراءة كل مكافآت الولاء.
class LoadRewardsUseCase {
  const LoadRewardsUseCase(this._repository);

  final LoyaltyRepository _repository;

  Future<List<AdminLoyaltyReward>> call() => _repository.loadRewards();
}
