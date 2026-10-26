import 'package:admin_app/features/loyalty/domain/repositories/loyalty_repository.dart';

/// تنشيط المكافأة أو إيقافها بعد فحص القاعدة.
class SetRewardActiveUseCase {
  const SetRewardActiveUseCase(this._repository);

  final LoyaltyRepository _repository;

  Future<LoyaltyRewardMutationOutcome> call(String rewardId, bool active) =>
      _repository.setRewardActive(rewardId, active);
}
