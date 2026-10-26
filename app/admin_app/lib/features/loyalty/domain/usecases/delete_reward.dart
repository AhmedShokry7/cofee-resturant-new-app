import 'package:admin_app/features/loyalty/domain/repositories/loyalty_repository.dart';

/// حذف مكافأة ولاء بعد فحص القاعدة.
class DeleteRewardUseCase {
  const DeleteRewardUseCase(this._repository);

  final LoyaltyRepository _repository;

  Future<LoyaltyRewardMutationOutcome> call(String rewardId) =>
      _repository.deleteReward(rewardId);
}
